import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SshConnectionSettings {
  final String host;
  final int port;
  final String username;
  final String kubeconfigPath;
  final bool useK3s;

  const SshConnectionSettings(
      {required this.host,
      required this.port,
      required this.username,
      required this.kubeconfigPath,
      this.useK3s = false});

  String get remoteCommand => 'exec ${useK3s ? 'k3s kubectl' : 'kubectl'} '
      '--kubeconfig=${shellQuote(kubeconfigPath)} proxy '
      '--address=127.0.0.1 --port=0';

  static String shellQuote(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";

  void validate() {
    if (host.trim().isEmpty ||
        username.trim().isEmpty ||
        !kubeconfigPath.startsWith('/') ||
        kubeconfigPath.contains('\x00') ||
        port < 1 ||
        port > 65535) {
      throw const FormatException(
          'Enter a host, username, valid SSH port, and absolute remote kubeconfig path.');
    }
  }
}

typedef VerifySshHost = Future<bool> Function(String host, String fingerprint);

typedef SshClientFactory = Future<SSHClient> Function(
    SshConnectionSettings settings,
    String password,
    SSHHostkeyVerifyHandler verifyHost);

/// Owns a remote kubectl proxy and a loopback-only SSH forwarding listener.
/// Credentials are never written to disk or included in command arguments.
class SshTunnelService extends ChangeNotifier {
  final SshClientFactory _clientFactory;
  SshTunnelService({SshClientFactory? clientFactory})
      : _clientFactory = clientFactory ?? _openClient;

  static Future<SSHClient> _openClient(SshConnectionSettings settings,
      String password, SSHHostkeyVerifyHandler verifyHost) async {
    final socket = await SSHSocket.connect(settings.host, settings.port,
        timeout: const Duration(seconds: 15));
    return SSHClient(socket,
        username: settings.username,
        onPasswordRequest: () => password,
        onVerifyHostKey: verifyHost);
  }

  SSHClient? _client;
  SSHSession? _session;
  ServerSocket? _server;
  Directory? _directory;
  final _sockets = <Socket>{};
  final _channels = <SSHForwardChannel>{};
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _disposed = false;
  int _epoch = 0;
  bool connecting = false;
  String? kubeconfigPath;
  String? error;
  SshConnectionSettings? settings;
  bool get connected => kubeconfigPath != null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> connect(SshConnectionSettings configuration, String password,
      {required VerifySshHost verifyHost}) async {
    configuration.validate();
    if (connecting || connected) {
      throw StateError('Disconnect before opening another tunnel.');
    }
    final epoch = ++_epoch;
    void ensureActive() {
      if (_disposed || epoch != _epoch) {
        throw StateError('SSH connection cancelled.');
      }
    }

    connecting = true;
    error = null;
    _notify();
    try {
      final preferences = await SharedPreferences.getInstance();
      final pinKey = 'sshHostKey:${configuration.host}:${configuration.port}';
      final client =
          await _clientFactory(configuration, password, (type, bytes) async {
        final fingerprint = utf8.decode(bytes);
        final trusted = preferences.getString(pinKey);
        if (trusted != null) {
          if (trusted != fingerprint) {
            throw StateError(
                'SSH host key changed. Verify the server identity before reconnecting.');
          }
          return true;
        }
        if (!await verifyHost(configuration.host, '$type $fingerprint')) {
          return false;
        }
        await preferences.setString(pinKey, fingerprint);
        return true;
      });
      if (_disposed || epoch != _epoch) {
        await client.close();
        throw StateError('SSH connection cancelled.');
      }
      _client = client;
      unawaited(client.done.then((_) => _connectionLost(client),
          onError: (Object _) => _connectionLost(client)));
      await client.authenticated.timeout(const Duration(seconds: 90));
      ensureActive();
      final session = _session = await client
          .execute(configuration.remoteCommand)
          .timeout(const Duration(seconds: 15));
      ensureActive();
      final ready = Completer<int>();
      var proxyExited = false;
      final output = StringBuffer();
      void readOutput(String line) {
        if (output.length < 4096) output.writeln(line);
        final match =
            RegExp(r'Starting to serve on 127\.0\.0\.1:(\d+)').firstMatch(line);
        if (match != null && !ready.isCompleted) {
          ready.complete(int.parse(match[1]!));
        }
      }

      _subscriptions.add(session.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(readOutput));
      _subscriptions.add(session.stderr
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(readOutput));
      unawaited(session.done.then((_) {
        proxyExited = true;
        if (!ready.isCompleted) {
          ready.completeError(StateError(
              'Remote proxy could not start. Check kubectl, kubeconfig permissions and context. ${output.toString().trim()}'));
        }
        if (connected) _connectionLost(client);
      }));
      final remotePort =
          await ready.future.timeout(const Duration(seconds: 20));
      ensureActive();
      final server =
          _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _subscriptions.add(server.listen((socket) {
        unawaited(_forward(client, socket, remotePort));
      }));
      _directory = await Directory.systemTemp.createTemp('kubegrandson-ssh-');
      final file = File('${_directory!.path}/config.yaml');
      await file.writeAsString(localKubeconfig(server.port));
      // Check the tunnel before exposing it to Kubernetes consumers.
      final http = HttpClient()..findProxy = (_) => 'DIRECT';
      try {
        final request = await http
            .getUrl(Uri.parse('http://127.0.0.1:${server.port}/version'))
            .timeout(const Duration(seconds: 10));
        final response =
            await request.close().timeout(const Duration(seconds: 10));
        await response.drain<void>().timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw StateError(
              'Kubernetes API returned HTTP ${response.statusCode}.');
        }
      } finally {
        http.close(force: true);
      }
      if (proxyExited || client.isClosed) {
        throw StateError('SSH connection closed.');
      }
      ensureActive();
      settings = configuration;
      kubeconfigPath = file.path;
    } catch (failure) {
      error = failure.toString();
      await _close();
      rethrow;
    } finally {
      connecting = false;
      _notify();
    }
  }

  Future<void> _forward(SSHClient client, Socket socket, int port) async {
    _sockets.add(socket);
    SSHForwardChannel? channel;
    try {
      channel = await client
          .forwardLocal('127.0.0.1', port)
          .timeout(const Duration(seconds: 10));
      _channels.add(channel);
      await Future.wait([
        socket.cast<List<int>>().pipe(channel.sink),
        channel.stream.cast<List<int>>().pipe(socket),
      ]);
    } catch (_) {
      socket.destroy();
    } finally {
      socket.destroy();
      _sockets.remove(socket);
      if (channel != null) {
        _channels.remove(channel);
        unawaited(channel.close());
      }
    }
  }

  void _connectionLost(SSHClient client) {
    if (_client != client || connecting) return;
    error = 'SSH connection closed. Reconnect to continue reading logs.';
    unawaited(disconnect(clearError: false));
  }

  Future<void> disconnect({bool clearError = true}) async {
    if (clearError) error = null;
    await _close();
    _notify();
  }

  Future<void> _close() async {
    _epoch++;
    kubeconfigPath = null;
    final client = _client;
    _client = null;
    try {
      _session?.kill(SSHSignal.TERM);
    } catch (_) {/* Already closed. */}
    _session?.close();
    _session = null;
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
    _sockets.clear();
    for (final channel in _channels.toList()) {
      unawaited(channel.close());
    }
    _channels.clear();
    await _server?.close();
    _server = null;
    await client?.close();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final directory = _directory;
    _directory = null;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  static String localKubeconfig(int port) => '''apiVersion: v1
kind: Config
clusters:
  - name: remote-ssh
    cluster:
      server: http://127.0.0.1:$port
users:
  - name: remote-ssh
    user: {}
contexts:
  - name: remote-ssh
    context:
      cluster: remote-ssh
      user: remote-ssh
      namespace: default
current-context: remote-ssh
''';

  @override
  void dispose() {
    _disposed = true;
    unawaited(_close());
    super.dispose();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
import 'package:kubegrandson/domain/services/ssh_tunnel_service.dart';
import 'package:kubegrandson/core/utils/app_logger.dart';
import 'package:kubegrandson/domain/services/kubernetes_service.dart';

class MockSshClient extends Mock implements SSHClient {}

class MockSshSession extends Mock implements SSHSession {}

class SocketForwardChannel extends Fake implements SSHForwardChannel {
  final Socket socket;
  SocketForwardChannel(this.socket);
  @override
  StreamSink<List<int>> get sink => socket;
  @override
  Stream<Uint8List> get stream => socket.map(Uint8List.fromList);
  @override
  Future<void> close() async => socket.destroy();
}

const settings = SshConnectionSettings(
    host: 'cluster.example',
    port: 22,
    username: 'operator',
    kubeconfigPath: '/home/operator/.kube/config');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  AppLogger.init();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('quotes remote paths without shell expansion', () async {
    final path = "/tmp/a'b \$(echo unsafe); config";
    final result = await Process.run('/bin/sh',
        ['-c', 'printf %s ${SshConnectionSettings.shellQuote(path)}']);
    expect(result.exitCode, 0);
    expect(result.stdout, path);
    expect(settings.remoteCommand, startsWith('exec kubectl --kubeconfig='));
    expect(settings.remoteCommand, contains('--address=127.0.0.1 --port=0'));
    expect(
        const SshConnectionSettings(
                host: 'h',
                port: 22,
                username: 'u',
                kubeconfigPath: '/etc/rancher/k3s/k3s.yaml',
                useK3s: true)
            .remoteCommand,
        startsWith('exec k3s kubectl'));
  });

  test('rejects invalid connection details before opening a socket', () {
    expect(
        () => const SshConnectionSettings(
                host: 'h', port: 0, username: 'u', kubeconfigPath: '/config')
            .validate(),
        throwsFormatException);
    expect(
        () => const SshConnectionSettings(
                host: 'h',
                port: 22,
                username: 'u',
                kubeconfigPath: 'relative/config')
            .validate(),
        throwsFormatException);
  });

  test(
      'forwards API requests, produces usable kubeconfig, and cleans up on disconnect',
      () async {
    final remote = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    remote.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(request.uri.path == '/version'
          ? '{"gitVersion":"v1.30.0"}'
          : '{"message":"pod log"}');
      await request.response.close();
    });
    addTearDown(() => remote.close(force: true));
    final client = MockSshClient();
    final session = MockSshSession();
    final closed = Completer<void>();
    final exited = Completer<void>();
    when(() => client.authenticated).thenAnswer((_) async {});
    when(() => client.done).thenAnswer((_) => closed.future);
    when(() => client.isClosed).thenReturn(false);
    when(() => client.execute(settings.remoteCommand))
        .thenAnswer((_) async => session);
    when(() => session.stdout).thenAnswer((_) => Stream.value(
        Uint8List.fromList(
            utf8.encode('Starting to serve on 127.0.0.1:${remote.port}\n'))));
    when(() => session.stderr).thenAnswer((_) => const Stream.empty());
    when(() => session.done).thenAnswer((_) => exited.future);
    when(() => session.close()).thenAnswer((_) {
      if (!exited.isCompleted) exited.complete();
    });
    when(() => client.close()).thenAnswer((_) async {
      if (!closed.isCompleted) closed.complete();
    });
    when(() => client.forwardLocal('127.0.0.1', remote.port))
        .thenAnswer((_) async {
      final target =
          await Socket.connect(InternetAddress.loopbackIPv4, remote.port);
      return SocketForwardChannel(target);
    });
    var approvals = 0;
    final service = SshTunnelService(
        clientFactory: (configuration, password, verify) async {
      expect(password, 'secret');
      expect(
          await verify(
              'ssh-ed25519', Uint8List.fromList(utf8.encode('SHA256:test'))),
          isTrue);
      return client;
    });
    addTearDown(service.dispose);
    await service.connect(settings, 'secret', verifyHost: (_, __) async {
      approvals++;
      return true;
    });
    expect(service.connected, isTrue);
    expect(approvals, 1);
    final path = service.kubeconfigPath!;
    final config = loadYaml(await File(path).readAsString());
    final url = config['clusters'][0]['cluster']['server'] as String;
    final http = HttpClient();
    final response = await (await http
            .getUrl(Uri.parse('$url/api/v1/namespaces/default/pods/api/log')))
        .close();
    expect(await utf8.decoder.bind(response).join(), contains('pod log'));
    http.close(force: true);
    final kubernetes = KubernetesService();
    await kubernetes.initialize(
        kubeconfigPath: path,
        verifyConnection: false,
        proxyUrl: '',
        noProxy: '127.0.0.1,localhost');
    expect((await kubernetes.fetchContexts()).single.name, 'remote-ssh');
    kubernetes.dispose();
    await service.disconnect();
    expect(service.connected, isFalse);
    expect(await File(path).exists(), isFalse);
    verify(() => session.kill(SSHSignal.TERM)).called(1);
    final preferences = await SharedPreferences.getInstance();
    expect(
        preferences.getString('sshHostKey:cluster.example:22'), 'SHA256:test');
    expect(
        preferences
            .getKeys()
            .any((key) => key.toLowerCase().contains('password')),
        isFalse);
  });

  test('rejects a changed host key without asking to trust it again', () async {
    SharedPreferences.setMockInitialValues(
        {'sshHostKey:cluster.example:22': 'SHA256:old'});
    final service = SshTunnelService(clientFactory: (_, __, verify) async {
      await verify(
          'ssh-ed25519', Uint8List.fromList(utf8.encode('SHA256:changed')));
      throw StateError('Should not authenticate');
    });
    addTearDown(service.dispose);
    await expectLater(
        service.connect(settings, 'secret', verifyHost: (_, __) async {
          fail('A changed key must not be silently replaced');
        }),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('host key changed'))));
    expect(service.connected, isFalse);
    expect(service.connecting, isFalse);
  });

  test('reports remote proxy startup failures and closes SSH', () async {
    final client = MockSshClient();
    final session = MockSshSession();
    when(() => client.done).thenAnswer((_) => Completer<void>().future);
    when(() => client.authenticated).thenAnswer((_) async {});
    when(() => client.execute(settings.remoteCommand))
        .thenAnswer((_) async => session);
    when(() => session.stdout).thenAnswer((_) => const Stream.empty());
    when(() => session.stderr).thenAnswer((_) =>
        Stream.value(Uint8List.fromList(utf8.encode('kubectl: not found\n'))));
    when(() => session.done).thenAnswer((_) async {});
    when(() => client.close()).thenAnswer((_) async {});
    final service =
        SshTunnelService(clientFactory: (_, __, ___) async => client);
    addTearDown(service.dispose);
    await expectLater(
        service.connect(settings, 'secret', verifyHost: (_, __) async => true),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('Remote proxy could not start'))));
    expect(service.connected, isFalse);
    expect(service.connecting, isFalse);
    verify(() => client.close()).called(1);
  });
}

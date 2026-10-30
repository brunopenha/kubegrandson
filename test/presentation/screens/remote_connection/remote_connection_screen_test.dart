import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kubegrandson/domain/services/ssh_tunnel_service.dart';
import 'package:kubegrandson/presentation/providers/kubernetes_provider.dart';
import 'package:kubegrandson/presentation/providers/ssh_tunnel_provider.dart';
import 'package:kubegrandson/presentation/screens/remote_connection/remote_connection_screen.dart';

class FakeTunnelService extends SshTunnelService {
  SshConnectionSettings? received;
  String? receivedPassword;

  @override
  Future<void> connect(SshConnectionSettings configuration, String password,
      {required VerifySshHost verifyHost}) async {
    if (!await verifyHost(configuration.host, 'ssh-ed25519 SHA256:test')) {
      throw StateError('Host not trusted');
    }
    received = settings = configuration;
    receivedPassword = password;
    kubeconfigPath = '/temporary/config';
    notifyListeners();
  }

  @override
  Future<void> disconnect({bool clearError = true}) async {
    kubeconfigPath = null;
    notifyListeners();
  }
}

void main() {
  testWidgets(
      'connects with form details, confirms host, clears password and disconnects',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tunnel = FakeTunnelService();
    final container = ProviderContainer(overrides: [
      sshTunnelProvider.overrideWith((_) => tunnel),
      initializeProvider.overrideWith((_) async {}),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const RemoteConnectionScreen())));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'remote.example');
    await tester.enterText(fields.at(1), '2222');
    await tester.enterText(fields.at(2), 'operator');
    await tester.enterText(fields.at(3), 'secret');
    await tester.enterText(fields.at(4), '/etc/rancher/k3s/k3s.yaml');
    await tester.ensureVisible(find.text('Connect'));
    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Trust SSH host?'), findsOneWidget);
    await tester.tap(find.text('Trust and connect'));
    await tester.pumpAndSettle();
    expect(tunnel.received!.host, 'remote.example');
    expect(tunnel.received!.port, 2222);
    expect(tunnel.received!.username, 'operator');
    expect(tunnel.received!.kubeconfigPath, '/etc/rancher/k3s/k3s.yaml');
    expect(tunnel.receivedPassword, 'secret');
    expect(find.text('Connected to remote.example'), findsOneWidget);
    expect(
        tester.widget<TextFormField>(fields.at(3)).controller!.text, isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('sshHost'), 'remote.example');
    expect(
        preferences.getKeys().any((key) => key.contains('password')), isFalse);
    await tester.ensureVisible(find.text('Disconnect'));
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(tunnel.connected, isFalse);
    expect(find.text('Disconnected'), findsOneWidget);
    await tester.ensureVisible(find.text('Connection instructions'));
    await tester.tap(find.text('Connection instructions'));
    await tester.pumpAndSettle();
    expect(tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data,
        contains('Connect from the application'));
  });
}

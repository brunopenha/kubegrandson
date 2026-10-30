import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/services/ssh_tunnel_service.dart';
import '../../providers/kubernetes_provider.dart';
import '../../providers/ssh_tunnel_provider.dart';

class RemoteConnectionScreen extends ConsumerStatefulWidget {
  const RemoteConnectionScreen({super.key});

  @override
  ConsumerState<RemoteConnectionScreen> createState() =>
      _RemoteConnectionScreenState();
}

class _RemoteConnectionScreenState
    extends ConsumerState<RemoteConnectionScreen> {
  final _form = GlobalKey<FormState>();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '22');
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _path = TextEditingController(text: '/home/user/.kube/config');
  late final Future<String> _help =
      rootBundle.loadString('documentation/remote-cluster-ssh.md');
  bool _useK3s = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final active = ref.read(sshTunnelProvider).settings;
    setState(() {
      _host.text = active?.host ?? preferences.getString('sshHost') ?? '';
      _port.text =
          active?.port.toString() ?? preferences.getString('sshPort') ?? '22';
      _username.text =
          active?.username ?? preferences.getString('sshUsername') ?? '';
      _path.text = active?.kubeconfigPath ??
          preferences.getString('sshKubeconfig') ??
          '/home/user/.kube/config';
      _useK3s = active?.useK3s ?? preferences.getBool('sshUseK3s') ?? false;
    });
  }

  @override
  void dispose() {
    for (final controller in [_host, _port, _username, _password, _path]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> _verifyHost(String host, String fingerprint) async {
    if (!mounted) return false;
    return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
                  title: const Text('Trust SSH host?'),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Verify this fingerprint with the administrator of $host before connecting.'),
                        const SizedBox(height: 16),
                        SelectableText(fingerprint)
                      ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Trust and connect')),
                  ],
                )) ??
        false;
  }

  Future<void> _connect() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final tunnel = ref.read(sshTunnelProvider);
    try {
      final configuration = SshConnectionSettings(
          host: _host.text.trim(),
          port: int.parse(_port.text),
          username: _username.text.trim(),
          kubeconfigPath: _path.text.trim(),
          useK3s: _useK3s);
      await tunnel.connect(configuration, _password.text,
          verifyHost: _verifyHost);
      await ref.read(initializeProvider.future);
      ref.read(selectedNamespaceProvider.notifier).state = 'default';
      ref.read(selectedPodNamesProvider.notifier).state = {};
      clearPodLogSearch(ref);
      refreshKubernetesResources(ref);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('sshHost', configuration.host);
      await preferences.setString('sshPort', configuration.port.toString());
      await preferences.setString('sshUsername', configuration.username);
      await preferences.setString(
          'sshKubeconfig', configuration.kubeconfigPath);
      await preferences.setBool('sshUseK3s', configuration.useK3s);
    } catch (error) {
      await tunnel.disconnect();
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sshTunnelProvider).disconnect();
      ref.read(selectedPodNamesProvider.notifier).state = {};
      clearPodLogSearch(ref);
      refreshKubernetesResources(ref);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tunnel = ref.watch(sshTunnelProvider);
    final enabled = !_busy && !tunnel.connected;
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(
              title: const Text('Remote cluster over SSH'),
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _busy ? null : () => context.go('/'))),
          body: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const Text(
                  'Connect to a remote Minikube or k3s environment. The app creates the SSH tunnel and uses the remote kubeconfig to access pods and logs.'),
              const SizedBox(height: 16),
              Text(
                  tunnel.connected
                      ? 'Connected to ${tunnel.settings?.host}'
                      : (_busy ? 'Connecting…' : 'Disconnected'),
                  style: Theme.of(context).textTheme.titleMedium),
              if ((_error ?? tunnel.error) != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SelectableText(_error ?? tunnel.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              const SizedBox(height: 16),
              Form(
                  key: _form,
                  child: Column(children: [
                    _field(_host, 'SSH host', enabled: enabled),
                    _field(_port, 'SSH port', enabled: enabled,
                        validator: (value) {
                      final port = int.tryParse(value ?? '');
                      return port == null || port < 1 || port > 65535
                          ? 'Enter a port between 1 and 65535.'
                          : null;
                    }),
                    _field(_username, 'SSH username', enabled: enabled),
                    _field(_password, 'SSH password',
                        enabled: enabled, obscure: true),
                    _field(_path, 'Remote kubeconfig path',
                        enabled: enabled,
                        validator: (value) => value != null &&
                                value.trim().startsWith('/') &&
                                !value.contains('\x00')
                            ? null
                            : 'Enter an absolute path on the remote server.'),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Use k3s kubectl'),
                        subtitle: const Text(
                            'Enable if the remote server provides kubectl through k3s.'),
                        value: _useK3s,
                        onChanged: enabled
                            ? (value) => setState(() => _useK3s = value)
                            : null),
                  ])),
              const Text(
                  'The server needs kubectl (or k3s kubectl), a readable kubeconfig, and SSH forwarding enabled. The password is not saved. Connection details are remembered.'),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                FilledButton.icon(
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.lan_outlined),
                    onPressed: enabled ? _connect : null,
                    label: const Text('Connect')),
                OutlinedButton.icon(
                    icon: const Icon(Icons.link_off),
                    onPressed: !_busy && tunnel.connected ? _disconnect : null,
                    label: const Text('Disconnect')),
                if (tunnel.connected)
                  TextButton(
                      onPressed: () => context.go('/'),
                      child: const Text('View pods and logs')),
              ]),
              const SizedBox(height: 16),
              const Text(
                  'Disconnect restores your configured local kubeconfig. The tunnel stays active when you leave this screen.'),
              const SizedBox(height: 16),
              ExpansionTile(
                  title: const Text('Connection instructions'),
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: FutureBuilder<String>(
                            future: _help,
                            builder: (context, snapshot) => snapshot.hasData
                                ? MarkdownBody(
                                    data: snapshot.data!, selectable: true)
                                : const Text(
                                    'Loading connection instructions…'))),
                  ]),
            ]),
          )),
        ));
  }

  Widget _field(TextEditingController controller, String label,
      {required bool enabled,
      bool obscure = false,
      String? Function(String?)? validator}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: !obscure,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          validator: validator ??
              (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
        ));
  }
}

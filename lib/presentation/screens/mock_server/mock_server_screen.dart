import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/mock_service.dart';
import '../../../domain/services/mock_configuration_service.dart';
import '../../../domain/services/mock_server_service.dart';
import '../../../domain/services/json_analysis_service.dart';
import '../../../domain/services/json_response_generator.dart';
import '../../../domain/services/xml_analysis_service.dart';
import '../../providers/mock_server_provider.dart';

class MockServerScreen extends ConsumerStatefulWidget {
  const MockServerScreen({super.key});

  @override
  ConsumerState<MockServerScreen> createState() => _MockServerScreenState();
}

class _MockServerScreenState extends ConsumerState<MockServerScreen> {
  static const _endpointsPerPage = 4;
  final Map<String, int> _serverPages = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockServerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Return to main screen',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Mock microservices (offline)'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addService(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New service'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
                onPressed: () => _import(context, ref),
                icon: const Icon(Icons.file_open),
                label: const Text('Import JSON')),
            OutlinedButton.icon(
                onPressed: state.services.isEmpty
                    ? null
                    : () => _export(context, state.services),
                icon: const Icon(Icons.save_alt),
                label: const Text('Export JSON')),
            OutlinedButton.icon(
                onPressed: state.logs.isEmpty
                    ? null
                    : () => ref.read(mockServerProvider.notifier).clearLogs(),
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear requests')),
            OutlinedButton.icon(
                onPressed: () => _showHttpsHelp(context),
                icon: const Icon(Icons.https_outlined),
                label: const Text('HTTPS instructions')),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _serviceList(context, ref, state)),
              const VerticalDivider(),
              Expanded(child: _requestList(state.logs)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _serviceList(
      BuildContext context, WidgetRef ref, MockServerState state) {
    final groups = _groupServices(state.services);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mock servers', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Expanded(
          child: groups.isEmpty
              ? const Center(
                  child: Text('Create or import a simulated server.'))
              : ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    return _serverCard(context, ref, state, groups[index]);
                  },
                ),
        ),
      ],
    );
  }

  List<_MockServerGroup> _groupServices(List<MockServiceConfig> services) {
    final groups = <String, _MockServerGroup>{};
    for (final service in services) {
      final key = '${service.useHttps}:${service.port}';
      groups
          .putIfAbsent(key, () => _MockServerGroup(key, service))
          .endpoints
          .add(service);
    }
    return groups.values.toList();
  }

  Widget _serverCard(BuildContext context, WidgetRef ref, MockServerState state,
      _MockServerGroup group) {
    final pageCount = (group.endpoints.length / _endpointsPerPage).ceil();
    final page = (_serverPages[group.key] ?? 0).clamp(0, pageCount - 1).toInt();
    final first = page * _endpointsPerPage;
    final visible = group.endpoints
        .skip(first)
        .take(_endpointsPerPage)
        .toList(growable: false);
    final runningCount = group.endpoints
        .where((endpoint) => state.runningIds.contains(endpoint.id))
        .length;
    final scheme = group.template.useHttps ? 'HTTPS' : 'HTTP';
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(Icons.dns, color: runningCount > 0 ? Colors.green : null),
        title: Row(children: [
          Expanded(child: Text('$scheme server • port ${group.template.port}')),
          IconButton(
            tooltip: runningCount > 0
                ? 'Stop server and all endpoints'
                : 'Start server and all endpoints',
            icon: Icon(runningCount > 0 ? Icons.stop : Icons.play_arrow),
            onPressed: () =>
                _toggleServer(context, ref, group, runningCount > 0),
          ),
          IconButton(
            tooltip: 'Add endpoint on this server',
            icon: const Icon(Icons.add_link),
            onPressed: () =>
                _showServiceForm(context, ref, serverTemplate: group.template),
          ),
          IconButton(
            tooltip: 'Edit server settings',
            icon: const Icon(Icons.settings_ethernet),
            onPressed: () => _showServerSettings(context, ref, group),
          ),
        ]),
        subtitle: Text(
            '${group.endpoints.length} endpoint(s) • $runningCount running'),
        children: [
          const Divider(height: 1),
          ...visible.map((endpoint) =>
              _endpointTile(context, ref, state, endpoint, group.template)),
          if (pageCount > 1)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  tooltip: 'Previous endpoint page',
                  onPressed: page == 0
                      ? null
                      : () =>
                          setState(() => _serverPages[group.key] = page - 1),
                  icon: const Icon(Icons.chevron_left)),
              Text('Page ${page + 1} of $pageCount'),
              IconButton(
                  tooltip: 'Next endpoint page',
                  onPressed: page >= pageCount - 1
                      ? null
                      : () =>
                          setState(() => _serverPages[group.key] = page + 1),
                  icon: const Icon(Icons.chevron_right)),
            ]),
        ],
      ),
    );
  }

  Widget _endpointTile(
      BuildContext context,
      WidgetRef ref,
      MockServerState state,
      MockServiceConfig endpoint,
      MockServiceConfig serverTemplate) {
    final running = state.runningIds.contains(endpoint.id);
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 24, right: 8),
      leading: Icon(running ? Icons.play_circle_fill : Icons.circle_outlined,
          color: running ? Colors.green : null, size: 20),
      title: Text(endpoint.name),
      subtitle:
          Text('${endpoint.method} ${endpoint.path} → ${endpoint.statusCode}'),
      trailing: Wrap(children: [
        IconButton(
            tooltip: running ? 'Stop endpoint' : 'Start endpoint',
            icon: Icon(running ? Icons.stop : Icons.play_arrow),
            onPressed: () => _toggleEndpoint(context, ref, endpoint, running)),
        IconButton(
            tooltip: 'Edit endpoint',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showServiceForm(context, ref,
                existing: endpoint, serverTemplate: serverTemplate)),
        IconButton(
            tooltip: 'Delete endpoint',
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                ref.read(mockServerProvider.notifier).remove(endpoint.id)),
      ]),
    );
  }

  Future<void> _toggleEndpoint(BuildContext context, WidgetRef ref,
      MockServiceConfig endpoint, bool running) async {
    try {
      final notifier = ref.read(mockServerProvider.notifier);
      running
          ? await notifier.stop(endpoint.id)
          : await notifier.start(endpoint);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start endpoint: $error')));
      }
    }
  }

  Future<void> _toggleServer(BuildContext context, WidgetRef ref,
      _MockServerGroup group, bool running) async {
    final notifier = ref.read(mockServerProvider.notifier);
    try {
      if (running) {
        for (final endpoint in group.endpoints) {
          await notifier.stop(endpoint.id);
        }
      } else {
        for (final endpoint in group.endpoints) {
          await notifier.start(endpoint);
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not change server state: $error')));
      }
    }
  }

  Widget _requestList(List<MockRequestLog> logs) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Received requests',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Expanded(
            child: logs.isEmpty
                ? const Center(
                    child:
                        Text('Requests will appear here without Kubernetes.'))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isHttpError = log.responseStatus >= 400;
                      final errorColor = Theme.of(context).colorScheme.error;
                      return SelectionArea(
                          child: Card(
                              color:
                                  isHttpError ? errorColor.withAlpha(18) : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isHttpError
                                    ? BorderSide(
                                        color: errorColor.withAlpha(90))
                                    : BorderSide.none,
                              ),
                              child: ExpansionTile(
                                leading: isHttpError
                                    ? Icon(Icons.error_outline,
                                        color: errorColor, size: 20)
                                    : null,
                                title: Row(children: [
                                  Expanded(
                                      child: Text('${log.method} ${log.uri}')),
                                  IconButton(
                                    tooltip: 'Copy complete request',
                                    icon: const Icon(Icons.copy, size: 18),
                                    onPressed: () async {
                                      await Clipboard.setData(ClipboardData(
                                          text: _requestText(log)));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content:
                                                    Text('Request copied')));
                                      }
                                    },
                                  ),
                                ]),
                                subtitle: Text(
                                    '${log.timestamp.toIso8601String()} • HTTP ${log.responseStatus} • ${log.message}',
                                    style: isHttpError
                                        ? TextStyle(color: errorColor)
                                        : null),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SelectableText(
                                            'Headers:\n${const JsonEncoder.withIndent('  ').convert(log.headers)}\n\nRaw body:\n${log.body.isEmpty ? '(empty)' : log.body}'),
                                        if (log.pathParameters.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          SelectableText(
                                              'Path parameters:\n${const JsonEncoder.withIndent('  ').convert(log.pathParameters)}'),
                                        ],
                                        if (log.body.trim().isNotEmpty) ...[
                                          const Divider(height: 28),
                                          _structuredBody(log.body),
                                        ],
                                      ],
                                    ),
                                  )
                                ],
                              )));
                    })),
      ]);

  String _requestText(MockRequestLog log) {
    final buffer = StringBuffer()
      ..writeln('${log.method} ${log.uri}')
      ..writeln('HTTP response: ${log.responseStatus}')
      ..writeln('Message: ${log.message}');
    if (log.pathParameters.isNotEmpty) {
      buffer
        ..writeln('Path parameters:')
        ..writeln(
            const JsonEncoder.withIndent('  ').convert(log.pathParameters));
    }
    buffer
      ..writeln('Headers:')
      ..writeln(const JsonEncoder.withIndent('  ').convert(log.headers))
      ..writeln('Body:')
      ..write(log.body);
    return buffer.toString();
  }

  Widget _structuredBody(String body) {
    final trimmed = body.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      final result = JsonAnalysisService().analyze(body);
      if (!result.isValid) {
        return SelectableText('Invalid JSON: ${result.error}');
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Received JSON values',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ...result.fields.map((field) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: SelectableText(field.path),
              subtitle: Text(field.type),
              trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: SelectableText(field.value)),
            )),
      ]);
    }
    if (trimmed.startsWith('<')) {
      final result = XmlAnalysisService().analyze(body);
      if (!result.isValid) {
        return SelectableText('Invalid XML: ${result.error}');
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Received XML values',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ...result.values.map((field) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: SelectableText(field.path),
              trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: SelectableText(field.value)),
            )),
      ]);
    }
    return const Text('Body is plain text.');
  }

  Future<void> _addService(BuildContext context, WidgetRef ref) =>
      _showServiceForm(context, ref);

  Future<void> _showServerSettings(
      BuildContext context, WidgetRef ref, _MockServerGroup group) async {
    final port = TextEditingController(text: group.template.port.toString());
    final certificate =
        TextEditingController(text: group.template.certificatePath);
    final privateKey =
        TextEditingController(text: group.template.privateKeyPath);
    var useHttps = group.template.useHttps;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Server settings'),
                  content: SizedBox(
                    width: 680,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: port,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Server port')),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Serve with HTTPS'),
                        subtitle: const Text(
                            'This setting is shared by every endpoint.'),
                        value: useHttps,
                        onChanged: (value) =>
                            setDialogState(() => useHttps = value),
                      ),
                      if (useHttps) ...[
                        _filePathField(
                            context: context,
                            controller: certificate,
                            label: 'Certificate chain (.pem/.crt)'),
                        const SizedBox(height: 12),
                        _filePathField(
                            context: context,
                            controller: privateKey,
                            label: 'Private key (.pem/.key)'),
                      ],
                    ])),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Save server')),
                  ],
                )));
    if (accepted != true) return;
    try {
      final newPort = int.parse(port.text);
      final candidate = group.template.copyWithServer(
          port: newPort,
          useHttps: useHttps,
          certificatePath: certificate.text.trim(),
          privateKeyPath: privateKey.text.trim());
      MockServerService.validate(candidate);
      final ids = group.endpoints.map((endpoint) => endpoint.id).toSet();
      final previouslyRunning =
          ref.read(mockServerProvider).runningIds.intersection(ids);
      final notifier = ref.read(mockServerProvider.notifier);
      await notifier.updateServer(ids,
          port: newPort,
          useHttps: useHttps,
          certificatePath: certificate.text.trim(),
          privateKeyPath: privateKey.text.trim());
      for (final endpoint in ref.read(mockServerProvider).services) {
        if (previouslyRunning.contains(endpoint.id)) {
          await notifier.start(endpoint);
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid server configuration: $error')));
      }
    }
  }

  Future<void> _showServiceForm(BuildContext context, WidgetRef ref,
      {MockServiceConfig? existing, MockServiceConfig? serverTemplate}) async {
    final template = existing ?? serverTemplate;
    final name = TextEditingController(
        text: existing?.name ??
            (serverTemplate == null ? 'Login service' : 'New endpoint'));
    final port =
        TextEditingController(text: (template?.port ?? 8081).toString());
    final path = TextEditingController(text: existing?.path ?? '/');
    final status =
        TextEditingController(text: (existing?.statusCode ?? 200).toString());
    final headers = TextEditingController(
        text: const JsonEncoder.withIndent('  ').convert(existing?.headers ??
            const {'content-type': 'application/json; charset=utf-8'}));
    final body = TextEditingController(
        text: existing?.body ??
            '{"token":"fixed-token","message":"Login successful"}');
    final log = TextEditingController(
        text: existing?.logMessage ?? 'Simulated login completed');
    final certificate =
        TextEditingController(text: template?.certificatePath ?? '');
    final privateKey =
        TextEditingController(text: template?.privateKeyPath ?? '');
    var method = existing?.method ?? 'POST';
    var useHttps = template?.useHttps ?? false;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  title: Text(existing != null
                      ? serverTemplate != null
                          ? 'Edit endpoint'
                          : 'Edit simulated service'
                      : serverTemplate != null
                          ? 'New endpoint on port ${serverTemplate.port}'
                          : 'New simulated service'),
                  insetPadding: const EdgeInsets.all(24),
                  content: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: 760,
                          maxHeight: MediaQuery.sizeOf(context).height * .72),
                      child: SingleChildScrollView(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Endpoint',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            TextField(
                                controller: name,
                                decoration:
                                    const InputDecoration(labelText: 'Name')),
                            const SizedBox(height: 12),
                            if (serverTemplate != null) ...[
                              Card(
                                  child: ListTile(
                                leading: const Icon(Icons.dns),
                                title: Text(
                                    '${serverTemplate.useHttps ? 'HTTPS' : 'HTTP'} server • port ${serverTemplate.port}'),
                                subtitle: const Text(
                                    'TLS and certificate are inherited from the server.'),
                              )),
                              const SizedBox(height: 12),
                            ],
                            Row(children: [
                              if (serverTemplate == null) ...[
                                Expanded(
                                    child: TextField(
                                        controller: port,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            labelText: 'Server port'))),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                  child: DropdownButtonFormField(
                                      initialValue: method,
                                      decoration: const InputDecoration(
                                          labelText: 'Endpoint method'),
                                      items: [
                                        'ANY',
                                        'GET',
                                        'POST',
                                        'PUT',
                                        'PATCH',
                                        'DELETE'
                                      ]
                                          .map((item) => DropdownMenuItem(
                                              value: item, child: Text(item)))
                                          .toList(),
                                      onChanged: (value) =>
                                          setState(() => method = value!)))
                            ]),
                            const SizedBox(height: 12),
                            TextField(
                                controller: path,
                                decoration: const InputDecoration(
                                    labelText: 'Path',
                                    hintText:
                                        '/api/v1/credentialRequests/:id')),
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                  'Use :name or {name} in path or query values, for example /requests/:id?status=:status. Query order does not matter.'),
                            ),
                            if (serverTemplate == null) ...[
                              const SizedBox(height: 16),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Serve with HTTPS'),
                                subtitle: const Text(
                                    'Requires a PEM certificate chain and private key.'),
                                value: useHttps,
                                onChanged: (value) =>
                                    setState(() => useHttps = value),
                              ),
                              if (useHttps) ...[
                                const SizedBox(height: 8),
                                _filePathField(
                                  context: context,
                                  controller: certificate,
                                  label: 'Certificate chain (.pem/.crt)',
                                ),
                                const SizedBox(height: 12),
                                _filePathField(
                                  context: context,
                                  controller: privateKey,
                                  label: 'Private key (.pem/.key)',
                                ),
                              ],
                            ],
                            const SizedBox(height: 20),
                            Row(children: [
                              Expanded(
                                  child: Text('Simulated response',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium)),
                              OutlinedButton.icon(
                                  onPressed: () => _showJsonGenerator(
                                      context, body, headers),
                                  icon: const Icon(Icons.data_object),
                                  label: const Text('Generate JSON')),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              SizedBox(
                                  width: 180,
                                  child: TextField(
                                      controller: status,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                          labelText: 'HTTP status'))),
                              const SizedBox(width: 12),
                              const Expanded(
                                  child: Text(
                                      'The request body may be JSON, XML, form data, or plain text and is always captured in the request log.')),
                            ]),
                            const SizedBox(height: 12),
                            TextField(
                                controller: headers,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                    labelText: 'Response headers (JSON)')),
                            const SizedBox(height: 12),
                            TextField(
                                controller: body,
                                minLines: 4,
                                maxLines: 8,
                                decoration: const InputDecoration(
                                    labelText:
                                        'Response body (JSON, XML or text)')),
                            const SizedBox(height: 12),
                            TextField(
                                controller: log,
                                decoration: const InputDecoration(
                                    labelText: 'Log message')),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(existing == null ? 'Create' : 'Save'))
                  ],
                )));
    if (accepted != true) return;
    try {
      final config = MockServiceConfig(
          id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          name: name.text.trim(),
          port: int.parse(port.text),
          method: method,
          path: path.text.trim(),
          statusCode: int.parse(status.text),
          headers: Map<String, String>.from(jsonDecode(headers.text)),
          body: body.text,
          logMessage: log.text,
          useHttps: useHttps,
          certificatePath: certificate.text.trim(),
          privateKeyPath: privateKey.text.trim());
      MockServerService.validate(config);
      final notifier = ref.read(mockServerProvider.notifier);
      if (existing == null) {
        notifier.add(config);
        if (serverTemplate != null &&
            ref
                .read(mockServerProvider)
                .runningIds
                .contains(serverTemplate.id)) {
          await notifier.start(config);
        }
      } else {
        final wasRunning =
            ref.read(mockServerProvider).runningIds.contains(existing.id);
        await notifier.update(config);
        if (wasRunning) await notifier.start(config);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid configuration: $error')));
      }
    }
  }

  Widget _filePathField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
  }) {
    return Row(children: [
      Expanded(
          child: TextField(
              controller: controller,
              readOnly: true,
              decoration: InputDecoration(labelText: label))),
      const SizedBox(width: 8),
      OutlinedButton.icon(
          onPressed: () async {
            final picked = await FilePicker.platform.pickFiles(
                dialogTitle: 'Select $label',
                type: FileType.custom,
                allowedExtensions: const ['pem', 'crt', 'cer', 'key']);
            final path = picked?.files.single.path;
            if (path != null) controller.text = path;
          },
          icon: const Icon(Icons.file_open),
          label: const Text('Browse')),
    ]);
  }

  Future<void> _showJsonGenerator(
      BuildContext context,
      TextEditingController bodyController,
      TextEditingController headersController) async {
    var preset = JsonResponsePreset.orders;
    final jsonPath = TextEditingController(text: r'$.data[*].orderId');
    final values =
        TextEditingController(text: 'ORDER-10001\nORDER-10002\nORDER-10003');
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('JSON response generator'),
                  content: SizedBox(
                    width: 620,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<JsonResponsePreset>(
                        initialValue: preset,
                        decoration:
                            const InputDecoration(labelText: 'Response shape'),
                        items: const [
                          DropdownMenuItem(
                              value: JsonResponsePreset.orders,
                              child: Text(r'Orders — $.data[*].orderId')),
                          DropdownMenuItem(
                              value: JsonResponsePreset.batches,
                              child: Text(r'Batches — $.batches[*].batch_id')),
                          DropdownMenuItem(
                              value: JsonResponsePreset.custom,
                              child: Text('Custom JSONPath')),
                        ],
                        onChanged: (value) => setDialogState(() {
                          preset = value!;
                          if (preset == JsonResponsePreset.orders) {
                            jsonPath.text = r'$.data[*].orderId';
                          } else if (preset == JsonResponsePreset.batches) {
                            jsonPath.text = r'$.batches[*].batch_id';
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: jsonPath,
                        enabled: preset == JsonResponsePreset.custom,
                        decoration:
                            const InputDecoration(labelText: 'JSONPath'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: values,
                        minLines: 5,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          labelText: 'Values (one per line)',
                          hintText: 'ORDER-10001\nORDER-10002',
                        ),
                      ),
                    ]),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Generate')),
                  ],
                )));
    if (accepted != true) return;
    try {
      bodyController.text = JsonResponseGenerator().generate(
          preset: preset,
          values: const LineSplitter().convert(values.text),
          jsonPath: jsonPath.text);
      Map<String, dynamic> responseHeaders;
      try {
        responseHeaders = Map<String, dynamic>.from(
            jsonDecode(headersController.text) as Map);
      } catch (_) {
        responseHeaders = {};
      }
      responseHeaders['content-type'] = 'application/json; charset=utf-8';
      headersController.text =
          const JsonEncoder.withIndent('  ').convert(responseHeaders);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not generate JSON: $error')));
      }
    }
  }

  Future<void> _showHttpsHelp(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('Mocking an HTTPS service'),
            content: const SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: SelectableText('''
1. Create or obtain a PEM certificate and its private key. For local development, a self-signed certificate can be generated with OpenSSL:

openssl req -x509 -newkey rsa:2048 -nodes -days 365 -keyout mock-key.pem -out mock-cert.pem -subj "/CN=mock.bruno.penha.nom.br" -addext "subjectAltName=DNS:mock.bruno.penha.nom.br,IP:127.0.0.1"

Map the local name before running the client:

127.0.0.1 mock.bruno.penha.nom.br

On Linux/macOS this line belongs in /etc/hosts. On Windows it belongs in C:\Windows\System32\drivers\etc\hosts and must be edited as Administrator.

2. Create a service, enable “Serve with HTTPS”, select both files, and use the full token route as its Path. Select POST and the desired port.

3. Configure the application under test to call this computer, for example:

https://mock.bruno.penha.nom.br:1313/auth/realms/bruno/protocol/openid-connect/token

The server accepts and records application/x-www-form-urlencoded bodies such as client_id, grant_type, client_secret, and scope without extra configuration.

4. A self-signed certificate is not trusted automatically. Import mock-cert.pem into the test client's trust store. For a temporary command-line test only, curl can use --insecure:

curl --insecure --request POST \
  --header "content-type: application/x-www-form-urlencoded" \
  --data "client_id=example-client&grant_type=client_credentials&client_secret=REPLACE_ME&scope=example.write" \
  https://mock.bruno.penha.nom.br:1313/auth/realms/bruno/protocol/openid-connect/token

Important: an IP such as 192.168.99.100 works only if it is assigned/routed to the computer running Kubegrandson. Otherwise, change the client URL, add the IP to a local interface, or configure an appropriate proxy. A literal remote IP cannot be redirected through the hosts file.

Do not export real client secrets in shared mock configuration files.
'''),
              ),
            ),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ],
          ));

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
    final path = picked?.files.single.path;
    if (path == null) return;
    try {
      final services =
          MockConfigurationService().import(await File(path).readAsString());
      await ref.read(mockServerProvider.notifier).replaceAll(services);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not import: $error')));
      }
    }
  }

  Future<void> _export(
      BuildContext context, List<MockServiceConfig> services) async {
    final path = await FilePicker.platform.saveFile(
        fileName: 'mock-services.json',
        type: FileType.custom,
        allowedExtensions: const ['json']);
    if (path == null) return;
    await File(path).writeAsString(MockConfigurationService().export(services));
  }
}

class _MockServerGroup {
  _MockServerGroup(this.key, this.template);

  final String key;
  final MockServiceConfig template;
  final List<MockServiceConfig> endpoints = [];
}

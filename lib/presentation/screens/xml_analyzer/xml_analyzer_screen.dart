import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/services/json_analysis_service.dart';
import '../../../domain/services/xml_analysis_service.dart';

enum DocumentType { json, xml }

const analyzerFileExtensions = ['json', 'jmx', 'xml', 'txt'];

const _editorFontSize = 14.0;
const _editorLineHeight = 20.0;
const _editorPadding = 12.0;

class XmlAnalyzerScreen extends StatefulWidget {
  const XmlAnalyzerScreen({super.key});

  @override
  State<XmlAnalyzerScreen> createState() => _XmlAnalyzerScreenState();
}

class _XmlAnalyzerScreenState extends State<XmlAnalyzerScreen> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  final _editorFocusNode = FocusNode();
  final _editorScrollController = ScrollController();
  DocumentType _type = DocumentType.json;
  JsonAnalysisResult? _jsonResult;
  XmlAnalysisResult? _xmlResult;
  double _editorFraction = 0.6;
  int _lineCount = 1;
  Timer? _lineCountDebounce;
  Timer? _searchDebounce;
  List<int>? _jsonMatchIndexes;
  List<int>? _xmlMatchIndexes;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scheduleLineCountUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_scheduleLineCountUpdate);
    _lineCountDebounce?.cancel();
    _searchDebounce?.cancel();
    _controller.dispose();
    _searchController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Return to main screen',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: const Text('JSON and XML analyzer'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(builder: (context, constraints) {
            const dividerWidth = 20.0;
            final availableWidth = constraints.maxWidth - dividerWidth;
            final minimumEditorWidth =
                availableWidth < 900 ? availableWidth * 0.6 : 620.0;
            final maximumEditorWidth = availableWidth < 700
                ? availableWidth * 0.75
                : availableWidth - 280.0;
            final editorWidth = (availableWidth * _editorFraction)
                .clamp(minimumEditorWidth, maximumEditorWidth);
            return Row(children: [
              SizedBox(
                  width: editorWidth,
                  child: Column(children: [
                    Row(children: [
                      SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<DocumentType>(
                              initialValue: _type,
                              decoration:
                                  const InputDecoration(labelText: 'File type'),
                              items: DocumentType.values
                                  .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type.name.toUpperCase())))
                                  .toList(),
                              onChanged: (type) => setState(() {
                                    _type = type!;
                                    _jsonResult = null;
                                    _xmlResult = null;
                                    _jsonMatchIndexes = null;
                                    _xmlMatchIndexes = null;
                                  }))),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                          onPressed: _open,
                          icon: const Icon(Icons.file_open),
                          label: const Text('Open file')),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                          onPressed: _analyze,
                          icon: const Icon(Icons.analytics),
                          label: const Text('Analyze')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Find tag or value...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _runSearch();
                                    },
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => _scheduleSearch(),
                          onSubmitted: (_) => _runSearch(),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Expanded(child: _buildEditor()),
                  ])),
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) => setState(() {
                    final nextWidth = (editorWidth + details.delta.dx)
                        .clamp(minimumEditorWidth, maximumEditorWidth);
                    _editorFraction = nextWidth / availableWidth;
                  }),
                  child: const SizedBox(
                    width: dividerWidth,
                    child: Center(child: VerticalDivider(thickness: 2)),
                  ),
                ),
              ),
              Expanded(child: _results()),
            ]);
          }),
        ),
      );

  Widget _buildEditor() {
    final digits = _lineCount.toString().length;
    final gutterWidth = 24.0 + digits * 9.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(children: [
        SizedBox(
          width: gutterWidth,
          child: AnimatedBuilder(
            animation: _editorScrollController,
            builder: (context, child) => CustomPaint(
              painter: _LineNumberPainter(
                lineCount: _lineCount,
                scrollOffset: _editorScrollController.hasClients
                    ? _editorScrollController.offset
                    : 0,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _editorFocusNode,
            scrollController: _editorScrollController,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: _editorFontSize,
              height: _editorLineHeight / _editorFontSize,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(_editorPadding),
              hintText: 'Paste ${_type.name.toUpperCase()} here...',
            ),
          ),
        ),
      ]),
    );
  }

  void _scheduleLineCountUpdate() {
    _lineCountDebounce?.cancel();
    _lineCountDebounce = Timer(const Duration(milliseconds: 120), () {
      var count = 1;
      final text = _controller.text;
      for (var index = 0; index < text.length; index++) {
        if (text.codeUnitAt(index) == 10) count++;
      }
      if (mounted && count != _lineCount) {
        setState(() => _lineCount = count);
      }
    });
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), _runSearch);
  }

  void _runSearch() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    final normalizedQuery = query.toLowerCase();
    final jsonMatches = <int>[];
    final xmlMatches = <int>[];

    if (query.isNotEmpty) {
      final jsonFields = _jsonResult?.fields ?? const <JsonFieldValue>[];
      for (var index = 0; index < jsonFields.length; index++) {
        final field = jsonFields[index];
        if (field.path.toLowerCase().contains(normalizedQuery) ||
            field.value.toLowerCase().contains(normalizedQuery)) {
          jsonMatches.add(index);
        }
      }
      final xmlValues = _xmlResult?.values ?? const <XmlFieldValue>[];
      for (var index = 0; index < xmlValues.length; index++) {
        final field = xmlValues[index];
        if (field.path.toLowerCase().contains(normalizedQuery) ||
            field.value.toLowerCase().contains(normalizedQuery)) {
          xmlMatches.add(index);
        }
      }

      // Use an exact search in the source to avoid allocating a second,
      // lower-cased copy of a potentially very large document.
      final sourceIndex = _controller.text.indexOf(query);
      if (sourceIndex >= 0) {
        _controller.selection = TextSelection(
          baseOffset: sourceIndex,
          extentOffset: sourceIndex + query.length,
        );
        _editorFocusNode.requestFocus();
      }
    }

    if (!mounted) return;
    setState(() {
      _jsonMatchIndexes = query.isEmpty ? null : jsonMatches;
      _xmlMatchIndexes = query.isEmpty ? null : xmlMatches;
    });
  }

  Widget _results() {
    if (_type == DocumentType.json) return _jsonResults();
    return _xmlResults();
  }

  Widget _jsonResults() {
    final result = _jsonResult;
    if (result == null)
      return const Center(
          child: Text('Analyze a JSON document to see every field and value.'));
    if (!result.isValid)
      return _errorCard(
          'Invalid JSON', result.error, result.line, result.column);
    final indexes = _jsonMatchIndexes;
    final visibleCount = indexes?.length ?? result.fields.length;
    return ListView.builder(
      itemCount: visibleCount + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          final summary = indexes == null
              ? '${result.fields.length} values'
              : '$visibleCount matching values';
          return _validCard('Valid JSON', summary);
        }
        final fieldIndex = indexes?[index - 1] ?? index - 1;
        final field = result.fields[fieldIndex];
        return ListTile(
            dense: true,
            title: SelectableText(field.path),
            subtitle: Text(field.type),
            trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: SelectableText(field.value)));
      },
    );
  }

  Widget _xmlResults() {
    final result = _xmlResult;
    if (result == null)
      return const Center(
          child: Text('Analyze an XML document to see its tags and values.'));
    if (!result.isValid)
      return _errorCard(
          'Invalid XML', result.error, result.line, result.column);
    final indexes = _xmlMatchIndexes;
    final sortedTotals = indexes == null
        ? (result.tagsByName.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        : const <MapEntry<String, int>>[];
    final visibleValueCount = indexes?.length ?? result.values.length;
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _validCard(
            'Valid XML',
            indexes == null
                ? '${result.totalTags} tags • ${result.values.length} values'
                : '$visibleValueCount matching values'),
        Text('Tag values', style: Theme.of(context).textTheme.titleMedium),
      ])),
      SliverList.builder(
        itemCount: visibleValueCount,
        itemBuilder: (context, index) {
          final field = result.values[indexes?[index] ?? index];
          return ListTile(
              dense: true,
              title: SelectableText(field.path),
              trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: SelectableText(field.value)));
        },
      ),
      if (indexes == null)
        SliverToBoxAdapter(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Divider(),
          Text('Tags by name', style: Theme.of(context).textTheme.titleMedium),
        ])),
      if (indexes == null)
        SliverList.builder(
          itemCount: sortedTotals.length,
          itemBuilder: (context, index) {
            final entry = sortedTotals[index];
            return ListTile(
                dense: true,
                title: Text(entry.key),
                trailing: Text('${entry.value}'));
          },
        ),
      if (indexes == null)
        SliverToBoxAdapter(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Divider(),
          Text('Direct child tags by parent',
              style: Theme.of(context).textTheme.titleMedium),
        ])),
      if (indexes == null)
        SliverList.builder(
          itemCount: result.groups.length,
          itemBuilder: (context, index) {
            final group = result.groups[index];
            return ExpansionTile(
                title: Text(group.parentPath),
                children: group.children.entries
                    .map((entry) => ListTile(
                        dense: true,
                        title: Text(entry.key),
                        trailing: Text('${entry.value}')))
                    .toList());
          },
        ),
    ]);
  }

  Widget _validCard(String title, String subtitle) => Card(
      child: ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(title),
          subtitle: Text(subtitle)));

  Widget _errorCard(String title, String? error, int? line, int? column) {
    final location = line == null ? '' : ' at line $line, column $column';
    return Align(
        alignment: Alignment.topLeft,
        child: Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText('$title$location\n$error'))));
  }

  void _analyze() {
    setState(() {
      if (_type == DocumentType.json) {
        _jsonResult = JsonAnalysisService().analyze(_controller.text);
      } else {
        _xmlResult = XmlAnalysisService().analyze(_controller.text);
      }
    });
    _runSearch();
  }

  Future<void> _open() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open a file to analyze as ${_type.name.toUpperCase()}',
      type: FileType.custom,
      allowedExtensions: analyzerFileExtensions,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    _controller.text = await File(path).readAsString();
    _analyze();
  }
}

class _LineNumberPainter extends CustomPainter {
  const _LineNumberPainter({
    required this.lineCount,
    required this.scrollOffset,
    required this.color,
  });

  final int lineCount;
  final double scrollOffset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final firstLine = (scrollOffset / _editorLineHeight).floor() + 1;
    final visibleLines = (size.height / _editorLineHeight).ceil() + 1;
    final lastLine = (firstLine + visibleLines).clamp(1, lineCount);
    final firstLineTop = _editorPadding - (scrollOffset % _editorLineHeight);
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    for (var line = firstLine; line <= lastLine; line++) {
      painter.text = TextSpan(
        text: '$line',
        style: TextStyle(
          color: color,
          fontFamily: 'RobotoMono',
          fontSize: _editorFontSize,
          height: _editorLineHeight / _editorFontSize,
        ),
      );
      painter.layout(maxWidth: size.width - 8);
      final y = firstLineTop + (line - firstLine) * _editorLineHeight;
      painter.paint(canvas, Offset(size.width - painter.width - 8, y));
    }
  }

  @override
  bool shouldRepaint(covariant _LineNumberPainter oldDelegate) =>
      oldDelegate.lineCount != lineCount ||
      oldDelegate.scrollOffset != scrollOffset ||
      oldDelegate.color != color;
}

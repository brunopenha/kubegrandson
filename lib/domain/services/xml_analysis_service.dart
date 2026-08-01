import 'package:xml/xml.dart';

class XmlTagSummary {
  const XmlTagSummary(this.parentPath, this.children);
  final String parentPath;
  final Map<String, int> children;
}

class XmlAnalysisResult {
  const XmlAnalysisResult(
      {required this.isValid,
      required this.totalTags,
      required this.tagsByName,
      required this.groups,
      required this.values,
      this.error,
      this.line,
      this.column});
  final bool isValid;
  final int totalTags;
  final Map<String, int> tagsByName;
  final List<XmlTagSummary> groups;
  final List<XmlFieldValue> values;
  final String? error;
  final int? line;
  final int? column;
}

class XmlFieldValue {
  const XmlFieldValue(this.path, this.value);
  final String path;
  final String value;
}

class XmlAnalysisService {
  XmlAnalysisResult analyze(String source) {
    try {
      final document = XmlDocument.parse(source);
      final all = document.descendants.whereType<XmlElement>().toList();
      final totals = <String, int>{};
      for (final element in all) {
        totals.update(element.name.qualified, (value) => value + 1,
            ifAbsent: () => 1);
      }
      final groups = <XmlTagSummary>[];
      final values = <XmlFieldValue>[];
      void visit(
          XmlElement element, String parentPath, int index, int siblingCount) {
        final suffix = siblingCount > 1 ? '[$index]' : '';
        final path = '$parentPath/${element.name.qualified}$suffix';
        final counts = <String, int>{};
        for (final child in element.childElements) {
          counts.update(child.name.qualified, (value) => value + 1,
              ifAbsent: () => 1);
        }
        if (counts.isNotEmpty) groups.add(XmlTagSummary(path, counts));
        if (element.childElements.isEmpty) {
          values.add(XmlFieldValue(path, element.innerText));
        }
        final indexes = <String, int>{};
        for (final child in element.childElements) {
          final name = child.name.qualified;
          indexes[name] = (indexes[name] ?? 0) + 1;
          visit(child, path, indexes[name]!, counts[name]!);
        }
      }

      visit(document.rootElement, '', 1, 1);
      return XmlAnalysisResult(
          isValid: true,
          totalTags: all.length,
          tagsByName: totals,
          groups: groups,
          values: values);
    } on FormatException catch (error) {
      final location = error.offset == null
          ? (null, null)
          : _location(source, error.offset!);
      return XmlAnalysisResult(
          isValid: false,
          totalTags: 0,
          tagsByName: const {},
          groups: const [],
          values: const [],
          error: error.message,
          line: location.$1,
          column: location.$2);
    } catch (error) {
      return XmlAnalysisResult(
          isValid: false,
          totalTags: 0,
          tagsByName: const {},
          groups: const [],
          values: const [],
          error: error.toString());
    }
  }

  (int, int) _location(String source, int position) {
    final safe = position.clamp(0, source.length);
    final before = source.substring(0, safe);
    final lines = before.split('\n');
    return (lines.length, lines.last.length + 1);
  }
}

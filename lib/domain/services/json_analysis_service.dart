import 'dart:convert';

class JsonFieldValue {
  const JsonFieldValue(this.path, this.value, this.type);
  final String path;
  final String value;
  final String type;
}

class JsonAnalysisResult {
  const JsonAnalysisResult({
    required this.isValid,
    required this.fields,
    this.error,
    this.line,
    this.column,
  });

  final bool isValid;
  final List<JsonFieldValue> fields;
  final String? error;
  final int? line;
  final int? column;
}

class JsonAnalysisService {
  JsonAnalysisResult analyze(String source) {
    try {
      final decoded = jsonDecode(source);
      final fields = <JsonFieldValue>[];
      void visit(Object? value, String path) {
        if (value is Map) {
          for (final entry in value.entries) {
            visit(
                entry.value,
                path.isEmpty
                    ? r'$.' + entry.key.toString()
                    : '$path.${entry.key}');
          }
        } else if (value is List) {
          for (var index = 0; index < value.length; index++) {
            visit(value[index], '$path[$index]');
          }
        } else {
          fields.add(JsonFieldValue(path.isEmpty ? r'$' : path,
              value?.toString() ?? 'null', _typeOf(value)));
        }
      }

      visit(decoded, '');
      return JsonAnalysisResult(isValid: true, fields: fields);
    } on FormatException catch (error) {
      final location = error.offset == null
          ? (null, null)
          : _location(source, error.offset!);
      return JsonAnalysisResult(
          isValid: false,
          fields: const [],
          error: error.message,
          line: location.$1,
          column: location.$2);
    }
  }

  String _typeOf(Object? value) {
    if (value == null) return 'null';
    if (value is bool) return 'boolean';
    if (value is num) return 'number';
    return 'string';
  }

  (int, int) _location(String source, int position) {
    final before = source.substring(0, position.clamp(0, source.length));
    final lines = before.split('\n');
    return (lines.length, lines.last.length + 1);
  }
}

import 'dart:convert';

/// Emits YAML without changing string types or multiline content.
String formatYaml(Object? value) => '${_formatYaml(value, 0)}\n';

String _formatYaml(Object? value, int indent) {
  final padding = ' ' * indent;
  if (value is Map) {
    if (value.isEmpty) return '$padding{}';
    return value.entries.map((entry) {
      final key = jsonEncode(entry.key.toString());
      return '$padding$key:${_yamlValue(entry.value, indent)}';
    }).join('\n');
  }
  if (value is List) {
    if (value.isEmpty) return '$padding[]';
    return value
        .map((item) => '$padding-${_yamlValue(item, indent)}')
        .join('\n');
  }
  return '$padding${jsonEncode(value)}';
}

String _yamlValue(Object? value, int indent) {
  if (value is Map && value.isNotEmpty || value is List && value.isNotEmpty) {
    return '\n${_formatYaml(value, indent + 2)}';
  }
  if (value is Map) return ' {}';
  if (value is List) return ' []';
  if (value is String &&
      value.contains('\n') &&
      !value.contains('\r') &&
      value.trim().isNotEmpty) {
    // An explicit indentation indicator also preserves leading spaces.
    final trailing = RegExp(r'\n+$').firstMatch(value)?.group(0)?.length ?? 0;
    final chomping = trailing == 0 ? '-' : (trailing == 1 ? '' : '+');
    final lines = value.endsWith('\n')
        ? value.substring(0, value.length - 1).split('\n')
        : value.split('\n');
    return ' |2$chomping\n${lines.map((line) => '${' ' * (indent + 2)}$line').join('\n')}';
  }
  return ' ${jsonEncode(value)}';
}

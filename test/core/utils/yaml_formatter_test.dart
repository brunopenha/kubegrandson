import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/core/utils/yaml_formatter.dart';
import 'package:yaml/yaml.dart';

void main() {
  test(
      'preserves scalar types, special keys, empty collections and nested lists',
      () {
    final value = {
      'a: b': '123',
      'enabled': 'true',
      'null': 'null',
      'number': 3,
      'boolean': true,
      'items': [
        {'name': 'api', 'args': <String>[]},
        <String, Object>{}
      ],
    };
    expect(loadYaml(formatYaml(value)), value);
  });

  test('preserves multiline content and trailing newlines', () {
    for (final text in [
      'a\nb',
      'a\nb\n',
      'a\nb\n\n',
      '  a\n b\n',
      '\n',
      '\n\n'
    ]) {
      final value = {'config': text, 'next': 'value'};
      expect(loadYaml(formatYaml(value)), value, reason: 'Input: $text');
      expect(loadYaml(formatYaml({'config': text})), {'config': text});
    }
  });
}

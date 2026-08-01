import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/domain/services/xml_analysis_service.dart';

void main() {
  final analyzer = XmlAnalysisService();

  test('validates and counts tags globally and inside each parent', () {
    final result = analyzer.analyze('''
<catalog>
  <book><title>One</title></book>
  <book><title>Two</title><author>A</author></book>
</catalog>
''');

    expect(result.isValid, isTrue);
    expect(result.totalTags, 6);
    expect(
        result.tagsByName, {'catalog': 1, 'book': 2, 'title': 2, 'author': 1});
    expect(result.values.map((field) => '${field.path}=${field.value}'), [
      '/catalog/book[1]/title=One',
      '/catalog/book[2]/title=Two',
      '/catalog/book[2]/author=A',
    ]);
    final catalog =
        result.groups.firstWhere((group) => group.parentPath == '/catalog');
    expect(catalog.children, {'book': 2});
  });

  test('reports line and column for invalid XML', () {
    final result = analyzer.analyze('<root>\n  <item>\n</root>');

    expect(result.isValid, isFalse);
    expect(result.error, isNotEmpty);
    expect(result.line, isNotNull);
    expect(result.column, isNotNull);
  });
}

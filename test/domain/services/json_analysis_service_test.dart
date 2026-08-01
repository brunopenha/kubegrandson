import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/domain/services/json_analysis_service.dart';

void main() {
  final analyzer = JsonAnalysisService();

  test('lists values, paths and types from objects and arrays', () {
    final result = analyzer.analyze('''
{
  "token": "fixed-token",
  "success": true,
  "users": [{"id": 10}, {"id": 20}],
  "optional": null
}
''');

    expect(result.isValid, isTrue);
    expect(
        result.fields
            .map((field) => '${field.path}:${field.type}=${field.value}'),
        [
          r'$.token:string=fixed-token',
          r'$.success:boolean=true',
          r'$.users[0].id:number=10',
          r'$.users[1].id:number=20',
          r'$.optional:null=null',
        ]);
  });

  test('reports line and column for invalid JSON', () {
    final result = analyzer.analyze('{\n  "token": }');

    expect(result.isValid, isFalse);
    expect(result.error, isNotEmpty);
    expect(result.line, 2);
    expect(result.column, isNotNull);
  });
}

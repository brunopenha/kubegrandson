import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/domain/services/json_response_generator.dart';

void main() {
  final generator = JsonResponseGenerator();

  test(r'generates values for $.data[*].orderId', () {
    final result = jsonDecode(generator.generate(
        preset: JsonResponsePreset.orders, values: ['ORDER-1', 'ORDER-2']));

    expect(result, {
      'data': [
        {'orderId': 'ORDER-1'},
        {'orderId': 'ORDER-2'}
      ]
    });
  });

  test(r'generates values for $.batches[*].batch_id', () {
    final result = jsonDecode(generator.generate(
        preset: JsonResponsePreset.batches, values: ['PP20000000014']));

    expect(result['nb_batch_created'], 1);
    expect(result['batches'][0]['batch_id'], 'PP20000000014');
    expect(result['batches'][0]['orders'], isEmpty);
    expect(result['unbatched'], isEmpty);
  });

  test('generates a custom simple array JSONPath', () {
    final result = jsonDecode(generator.generate(
        preset: JsonResponsePreset.custom,
        values: ['A', 'B'],
        jsonPath: r'$.items[*].code'));

    expect(result, {
      'items': [
        {'code': 'A'},
        {'code': 'B'}
      ]
    });
  });
}

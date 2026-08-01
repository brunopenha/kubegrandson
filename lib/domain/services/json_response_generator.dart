import 'dart:convert';

enum JsonResponsePreset { orders, batches, custom }

class JsonResponseGenerator {
  String generate({
    required JsonResponsePreset preset,
    required List<String> values,
    String jsonPath = r'$.data[*].id',
  }) {
    final cleaned = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) {
      throw const FormatException('Provide at least one generated value');
    }
    late final Map<String, Object?> response;
    switch (preset) {
      case JsonResponsePreset.orders:
        response = {
          'data': cleaned.map((value) => {'orderId': value}).toList()
        };
        break;
      case JsonResponsePreset.batches:
        response = {
          'nb_batch_created': cleaned.length,
          'batches': cleaned
              .map((value) => {'batch_id': value, 'orders': <Object>[]})
              .toList(),
          'unbatched': <Object>[],
        };
        break;
      case JsonResponsePreset.custom:
        final match =
            RegExp(r'^\$\.([A-Za-z_][\w-]*)\[\*\]\.([A-Za-z_][\w-]*)$')
                .firstMatch(jsonPath.trim());
        if (match == null) {
          throw const FormatException(
              r'Custom JSONPath must look like $.data[*].id');
        }
        response = {
          match.group(1)!:
              cleaned.map((value) => {match.group(2)!: value}).toList(),
        };
        break;
    }
    return const JsonEncoder.withIndent('  ').convert(response);
  }
}

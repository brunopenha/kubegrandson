import 'dart:convert';

import '../../data/models/mock_service.dart';

class MockConfigurationService {
  String export(List<MockServiceConfig> services) =>
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'services': services.map((service) => service.toJson()).toList(),
      });

  List<MockServiceConfig> import(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['services'] is! List) {
      throw const FormatException(
          'Configuration must contain a services array');
    }
    return (decoded['services'] as List)
        .map((item) =>
            MockServiceConfig.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}

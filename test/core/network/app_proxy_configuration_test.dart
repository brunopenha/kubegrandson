import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/core/network/app_proxy_configuration.dart';

void main() {
  group('AppProxyConfiguration', () {
    test('bypasses an exact IP and an IPv4 CIDR range', () {
      const configuration = AppProxyConfiguration(
        proxyUrl: 'http://corporate.proxy:8080',
        noProxy: 'localhost,192.168.0.0/16',
      );

      expect(
        configuration.findProxy(Uri.parse('https://192.168.99.100:8443')),
        'DIRECT',
      );
      expect(
        configuration.findProxy(Uri.parse('https://192.169.0.1')),
        'PROXY corporate.proxy:8080',
      );
    });

    test('bypasses domain suffixes without bypassing similar domains', () {
      const configuration = AppProxyConfiguration(
        proxyUrl: 'http://corporate.proxy:8080',
        noProxy: '.example.com',
      );

      expect(
        configuration.findProxy(Uri.parse('https://api.example.com')),
        'DIRECT',
      );
      expect(
        configuration.findProxy(Uri.parse('https://notexample.com')),
        'PROXY corporate.proxy:8080',
      );
    });

    test('uses the default port for a configured proxy', () {
      const configuration = AppProxyConfiguration(
        proxyUrl: 'http://corporate.proxy',
      );

      expect(
        configuration.findProxy(Uri.parse('https://cluster.example.com')),
        'PROXY corporate.proxy:80',
      );
    });
  });
}

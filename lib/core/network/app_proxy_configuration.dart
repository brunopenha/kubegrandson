import 'dart:io';

class AppProxyConfiguration {
  final String proxyUrl;
  final String noProxy;

  const AppProxyConfiguration({
    this.proxyUrl = '',
    this.noProxy = '',
  });

  String findProxy(Uri uri) {
    if (_bypasses(uri.host)) {
      return 'DIRECT';
    }

    final configuredProxy = proxyUrl.trim();
    if (configuredProxy.isEmpty) {
      return HttpClient.findProxyFromEnvironment(uri);
    }

    final parsed = Uri.tryParse(configuredProxy);
    if (parsed == null || parsed.host.isEmpty) {
      return 'DIRECT';
    }
    final port = parsed.hasPort
        ? parsed.port
        : (parsed.scheme.toLowerCase() == 'https' ? 443 : 80);
    return 'PROXY ${parsed.host}:$port';
  }

  bool _bypasses(String host) {
    final normalizedHost = host.toLowerCase();
    for (final rawEntry in noProxy.split(',')) {
      var entry = rawEntry.trim().toLowerCase();
      if (entry.isEmpty) continue;
      if (entry == '*') return true;

      // A port is optional in no-proxy entries.
      if (!entry.contains('/') && entry.split(':').length == 2) {
        entry = entry.split(':').first;
      }
      if (entry.contains('/') && _isIpv4InCidr(normalizedHost, entry)) {
        return true;
      }

      final suffix = entry.startsWith('*.')
          ? entry.substring(1)
          : entry.startsWith('.')
              ? entry
              : '.$entry';
      if (normalizedHost == entry.replaceFirst(RegExp(r'^\*?\.'), '') ||
          normalizedHost.endsWith(suffix)) {
        return true;
      }
    }
    return false;
  }

  static bool _isIpv4InCidr(String host, String cidr) {
    final parts = cidr.split('/');
    if (parts.length != 2) return false;
    final prefix = int.tryParse(parts[1]);
    final hostValue = _ipv4Value(host);
    final networkValue = _ipv4Value(parts[0]);
    if (prefix == null ||
        prefix < 0 ||
        prefix > 32 ||
        hostValue == null ||
        networkValue == null) {
      return false;
    }
    final mask = prefix == 0 ? 0 : (0xffffffff << (32 - prefix)) & 0xffffffff;
    return (hostValue & mask) == (networkValue & mask);
  }

  static int? _ipv4Value(String value) {
    final octets = value.split('.').map(int.tryParse).toList();
    if (octets.length != 4 ||
        octets.any((part) => part == null || part > 255)) {
      return null;
    }
    return octets.fold<int>(0, (result, part) => (result << 8) | part!);
  }
}

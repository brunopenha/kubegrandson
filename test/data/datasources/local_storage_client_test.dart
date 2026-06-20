import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/core/constants/app_constants.dart';
import 'package:kubegrandson/data/datasources/local_storage_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorageClient.resetInstance();
  });

  test('returns defaults when preferences were not saved', () async {
    final storage = await LocalStorageClient.getInstance();

    expect(await storage.getFontSize(), AppConstants.defaultFontSize);
    expect(await storage.getMaxLogLines(), AppConstants.defaultMaxLogLines);
    expect(await storage.getAutoScroll(), AppConstants.defaultAutoScroll);
    expect(
      await storage.getLogNavigationUpShortcut(),
      AppConstants.defaultLogNavigationUpShortcut,
    );
    expect(
      await storage.getLogNavigationDownShortcut(),
      AppConstants.defaultLogNavigationDownShortcut,
    );
    expect(await storage.getDefaultNamespace(), AppConstants.defaultNamespace);
    expect(
      await storage.getAutoRefreshIntervalSeconds(),
      AppConstants.defaultAutoRefreshIntervalSeconds,
    );
  });

  test('saves and loads log viewer preferences', () async {
    final storage = await LocalStorageClient.getInstance();

    await storage.setFontSize(18);
    await storage.setMaxLogLines(5000);
    await storage.setAutoScroll(false);
    await storage.setLogNavigationUpShortcut('keyW');
    await storage.setLogNavigationDownShortcut('keyS');

    expect(await storage.getFontSize(), 18);
    expect(await storage.getMaxLogLines(), 5000);
    expect(await storage.getAutoScroll(), isFalse);
    expect(await storage.getLogNavigationUpShortcut(), 'keyW');
    expect(await storage.getLogNavigationDownShortcut(), 'keyS');
  });

  test('saves and loads kubernetes settings', () async {
    final storage = await LocalStorageClient.getInstance();

    await storage.setDefaultNamespace('kube-system');
    await storage.setAutoRefreshIntervalSeconds(30);

    expect(await storage.getDefaultNamespace(), 'kube-system');
    expect(await storage.getAutoRefreshIntervalSeconds(), 30);
  });

  test('saves and loads GCP settings', () async {
    final storage = await LocalStorageClient.getInstance();

    await storage.setGcpProjectId('team-project');
    await storage.setGcpLocation('europe-west1');
    await storage.setGcpLocationType('region');
    await storage.setGcpClusterName('dev-cluster');
    await storage.setGcpAccount('dev@example.com');

    expect(await storage.getGcpProjectId(), 'team-project');
    expect(await storage.getGcpLocation(), 'europe-west1');
    expect(await storage.getGcpLocationType(), 'region');
    expect(await storage.getGcpClusterName(), 'dev-cluster');
    expect(await storage.getGcpAccount(), 'dev@example.com');
  });

  test('saves and loads theme preference', () async {
    final storage = await LocalStorageClient.getInstance();

    await storage.setThemePreference('system');

    expect(await storage.getThemePreference(), 'system');
  });

  test('loads legacy isDarkMode theme preference', () async {
    SharedPreferences.setMockInitialValues({'isDarkMode': false});
    LocalStorageClient.resetInstance();

    final storage = await LocalStorageClient.getInstance();

    expect(await storage.getThemePreference(), 'light');
  });
}

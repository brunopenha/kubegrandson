import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/data/datasources/local_storage_client.dart';
import 'package:kubegrandson/presentation/providers/settings_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorageClient.resetInstance();
  });

  test('updates and persists log font size', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).setLogFontSize(18);

    expect(container.read(settingsProvider).logFontSize, 18);

    final storage = await LocalStorageClient.getInstance();
    expect(await storage.getFontSize(), 18);
  });

  test('updates and persists auto scroll', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).setAutoScroll(false);

    expect(container.read(settingsProvider).autoScroll, isFalse);

    final storage = await LocalStorageClient.getInstance();
    expect(await storage.getAutoScroll(), isFalse);
  });

  test('updates and persists log navigation shortcuts', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(settingsProvider.notifier)
        .setLogNavigationUpShortcut('keyW');
    await container
        .read(settingsProvider.notifier)
        .setLogNavigationDownShortcut('keyS');

    final settings = container.read(settingsProvider);
    expect(settings.logNavigationUpShortcut, 'keyW');
    expect(settings.logNavigationDownShortcut, 'keyS');

    final storage = await LocalStorageClient.getInstance();
    expect(await storage.getLogNavigationUpShortcut(), 'keyW');
    expect(await storage.getLogNavigationDownShortcut(), 'keyS');
  });

  test('updates and persists max log lines', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).setMaxLogLines(2500);

    expect(container.read(settingsProvider).maxLogLines, 2500);

    final storage = await LocalStorageClient.getInstance();
    expect(await storage.getMaxLogLines(), 2500);
  });

  test('updates and persists namespace and auto refresh interval', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(settingsProvider.notifier)
        .setDefaultNamespace('kube-system');
    await container.read(settingsProvider.notifier).setAutoRefreshInterval(30);

    final settings = container.read(settingsProvider);
    expect(settings.defaultNamespace, 'kube-system');
    expect(settings.autoRefreshIntervalSeconds, 30);

    final storage = await LocalStorageClient.getInstance();
    expect(await storage.getDefaultNamespace(), 'kube-system');
    expect(await storage.getAutoRefreshIntervalSeconds(), 30);
  });
}

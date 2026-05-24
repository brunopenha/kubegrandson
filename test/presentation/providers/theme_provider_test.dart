import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/data/datasources/local_storage_client.dart';
import 'package:kubegrandson/presentation/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorageClient.resetInstance();
  });

  test('loads dark theme by default', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).loadThemeMode();

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('persists selected theme mode through LocalStorageClient', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).setThemeMode(
          ThemeMode.system,
        );

    expect(container.read(themeModeProvider), ThemeMode.system);

    final storage = await LocalStorageClient.getInstance();
    expect(await storage.getThemePreference(), 'system');
  });

  test('loads saved theme preference', () async {
    SharedPreferences.setMockInitialValues({'theme_preference': 'light'});
    LocalStorageClient.resetInstance();

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(themeModeProvider.notifier).loadThemeMode();

    expect(container.read(themeModeProvider), ThemeMode.light);
  });
}

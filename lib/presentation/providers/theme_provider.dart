import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local_storage_client.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  bool _hasLocalChanges = false;

  ThemeModeNotifier() : super(ThemeMode.dark) {
    loadThemeMode();
  }

  Future<void> loadThemeMode() async {
    final storage = await LocalStorageClient.getInstance();
    final preference = await storage.getThemePreference();
    if (mounted && !_hasLocalChanges) {
      state = _themeModeFromStorage(preference);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _hasLocalChanges = true;
    state = mode;
    final storage = await LocalStorageClient.getInstance();
    await storage.setThemePreference(mode.name);
  }

  Future<void> toggleTheme() async {
    await setThemeMode(
      state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  ThemeMode _themeModeFromStorage(String? value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.dark,
    );
  }
}

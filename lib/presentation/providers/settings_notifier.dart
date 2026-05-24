import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kubegrandson/data/datasources/local_storage_client.dart';
import 'package:kubegrandson/core/config/settings_state.dart';

import '../../core/constants/app_constants.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  bool _hasLocalChanges = false;

  SettingsNotifier()
      : super(
          const SettingsState(
            logFontSize: AppConstants.defaultFontSize,
            maxLogLines: AppConstants.defaultMaxLogLines,
            autoScroll: AppConstants.defaultAutoScroll,
            defaultNamespace: AppConstants.defaultNamespace,
            autoRefreshIntervalSeconds:
                AppConstants.defaultAutoRefreshIntervalSeconds,
          ),
        ) {
    load();
  }

  Future<void> load() async {
    final storage = await LocalStorageClient.getInstance();

    final loadedState = state.copyWith(
      logFontSize: await storage.getFontSize(),
      maxLogLines: await storage.getMaxLogLines(),
      autoScroll: await storage.getAutoScroll(),
      defaultNamespace:
          await storage.getDefaultNamespace() ?? AppConstants.defaultNamespace,
      autoRefreshIntervalSeconds: await storage.getAutoRefreshIntervalSeconds(),
    );

    if (mounted && !_hasLocalChanges) {
      state = loadedState;
    }
  }

  Future<void> setLogFontSize(double size) async {
    _hasLocalChanges = true;
    state = state.copyWith(logFontSize: size);
    final storage = await LocalStorageClient.getInstance();
    await storage.setFontSize(size);
  }

  Future<void> setMaxLogLines(int max) async {
    _hasLocalChanges = true;
    state = state.copyWith(maxLogLines: max);
    final storage = await LocalStorageClient.getInstance();
    await storage.setMaxLogLines(max);
  }

  Future<void> setAutoScroll(bool enabled) async {
    _hasLocalChanges = true;
    state = state.copyWith(autoScroll: enabled);
    final storage = await LocalStorageClient.getInstance();
    await storage.setAutoScroll(enabled);
  }

  Future<void> setDefaultNamespace(String namespaceName) async {
    _hasLocalChanges = true;
    state = state.copyWith(defaultNamespace: namespaceName);
    final storage = await LocalStorageClient.getInstance();
    await storage.setDefaultNamespace(namespaceName);
  }

  Future<void> setAutoRefreshInterval(int refreshInSeconds) async {
    _hasLocalChanges = true;
    state = state.copyWith(autoRefreshIntervalSeconds: refreshInSeconds);
    final storage = await LocalStorageClient.getInstance();
    await storage.setAutoRefreshIntervalSeconds(refreshInSeconds);
  }
}

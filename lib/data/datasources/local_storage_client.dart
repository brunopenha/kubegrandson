
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';

class LocalStorageClient {
  static LocalStorageClient? _instance;
  SharedPreferences? _prefs;

  LocalStorageClient._();

  static Future<LocalStorageClient> getInstance() async {
    _instance ??= LocalStorageClient._();
    _instance!._prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Current Context
  Future<String?> getCurrentContext() async {
    try {
      return _prefs?.getString(AppConstants.currentContextKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get current context', e, stackTrace);
      return null;
    }
  }

  Future<bool> setCurrentContext(String context) async {
    try {
      return await _prefs?.setString(AppConstants.currentContextKey, context) ?? false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set current context', e, stackTrace);
      return false;
    }
  }

  // Kubeconfig Path
  Future<String?> getKubeConfigPath() async {
    try {
      return _prefs?.getString(AppConstants.kubeConfigPathKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get kubeconfig path', e, stackTrace);
      return null;
    }
  }

  Future<bool> setKubeConfigPath(String path) async {
    try {
      return await _prefs?.setString(AppConstants.kubeConfigPathKey, path) ?? false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set kubeconfig path', e, stackTrace);
      return false;
    }
  }

  // Theme Preference
  Future<String?> getThemePreference() async {
    try {
      return _prefs?.getString(AppConstants.themePreferenceKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get theme preference', e, stackTrace);
      return null;
    }
  }

  Future<bool> setThemePreference(String theme) async {
    try {
      return await _prefs?.setString(AppConstants.themePreferenceKey, theme) ?? false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set theme preference', e, stackTrace);
      return false;
    }
  }

  // Default Namespace
  Future<String?> getDefaultNamespace() async {
    try {
      return _prefs?.getString(AppConstants.defaultNamespaceKey) ?? AppConstants.defaultNamespace;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get default namespace', e, stackTrace);
      return AppConstants.defaultNamespace;
    }
  }

  Future<bool> setDefaultNamespace(String namespace) async {
    try {
      return await _prefs?.setString(AppConstants.defaultNamespaceKey, namespace) ?? false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set default namespace', e, stackTrace);
      return false;
    }
  }

  // Font Size
  Future<double> getFontSize() async {
    try {
      return _prefs?.getDouble(AppConstants.fontSizeKey) ?? AppConstants.defaultFontSize;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get font size', e, stackTrace);
      return AppConstants.defaultFontSize;
    }
  }

  Future<bool> setFontSize(double size) async {
    try {
      return await _prefs?.setDouble(AppConstants.fontSizeKey, size) ?? false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set font size', e, stackTrace);
      return false;
    }
  }

  // Max Log Lines
  Future<int> getMaxLogLines() async {
    try {
      return _prefs?.getInt(AppConstants.maxLogLinesKey) ?? AppConstants.defaultMaxLogLines;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get max log lines', e, stackTrace);
      return AppConstants.defaultMaxLogLines;
    }
  }

  Future<bool> setMaxLogLines(int lines) async {
    try {
      return await _prefs?.setInt(AppConstants.maxLogLinesKey, lines) ?? false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set max log lines', e, stackTrace);
      return false;
    }
  }

  // Auto Scroll
  Future<bool> getAutoScroll() async {
    try {
      return _prefs?.getBool(AppConstants.autoScrollKey) ?? AppConstants.defaultAutoScroll;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get auto scroll', e, stackTrace);
      return AppConstants.defaultAutoScroll;
    }
  }

  Future<bool> setAutoScroll(bool enabled) async {
    try {
      return await _prefs?.setBool(AppConstants.autoScrollKey, enabled) ?? false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set auto scroll', e, stackTrace);
      return false;
    }
  }

  // Clear all data
  Future<bool> clearAll() async {
    try {
      return await _prefs?.clear() ?? false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear storage', e, stackTrace);
      return false;
    }
  }
}
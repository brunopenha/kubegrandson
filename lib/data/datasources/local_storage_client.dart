import 'package:flutter/foundation.dart';
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

  @visibleForTesting
  static void resetInstance() {
    _instance = null;
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
      return await _prefs?.setString(AppConstants.currentContextKey, context) ??
          false;
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
      return await _prefs?.setString(AppConstants.kubeConfigPathKey, path) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set kubeconfig path', e, stackTrace);
      return false;
    }
  }

  // Theme Preference
  Future<String?> getThemePreference() async {
    try {
      final theme = _prefs?.getString(AppConstants.themePreferenceKey);
      if (theme != null) return theme;

      final legacyIsDarkMode = _prefs?.getBool('isDarkMode');
      if (legacyIsDarkMode != null) {
        return legacyIsDarkMode ? 'dark' : 'light';
      }

      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get theme preference', e, stackTrace);
      return null;
    }
  }

  Future<bool> setThemePreference(String theme) async {
    try {
      return await _prefs?.setString(AppConstants.themePreferenceKey, theme) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set theme preference', e, stackTrace);
      return false;
    }
  }

  // Default Namespace
  Future<String?> getDefaultNamespace() async {
    try {
      return _prefs?.getString(AppConstants.defaultNamespaceKey) ??
          AppConstants.defaultNamespace;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get default namespace', e, stackTrace);
      return AppConstants.defaultNamespace;
    }
  }

  Future<bool> setDefaultNamespace(String namespace) async {
    try {
      return await _prefs?.setString(
              AppConstants.defaultNamespaceKey, namespace) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set default namespace', e, stackTrace);
      return false;
    }
  }

  // Font Size
  Future<double> getFontSize() async {
    try {
      return _prefs?.getDouble(AppConstants.fontSizeKey) ??
          AppConstants.defaultFontSize;
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
      return _prefs?.getInt(AppConstants.maxLogLinesKey) ??
          AppConstants.defaultMaxLogLines;
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
      return _prefs?.getBool(AppConstants.autoScrollKey) ??
          AppConstants.defaultAutoScroll;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get auto scroll', e, stackTrace);
      return AppConstants.defaultAutoScroll;
    }
  }

  Future<bool> setAutoScroll(bool enabled) async {
    try {
      return await _prefs?.setBool(AppConstants.autoScrollKey, enabled) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set auto scroll', e, stackTrace);
      return false;
    }
  }

  // Log Navigation Shortcuts
  Future<String> getLogNavigationUpShortcut() async {
    try {
      return _prefs?.getString(AppConstants.logNavigationUpShortcutKey) ??
          AppConstants.defaultLogNavigationUpShortcut;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get log navigation up shortcut',
        e,
        stackTrace,
      );
      return AppConstants.defaultLogNavigationUpShortcut;
    }
  }

  Future<bool> setLogNavigationUpShortcut(String shortcut) async {
    try {
      return await _prefs?.setString(
            AppConstants.logNavigationUpShortcutKey,
            shortcut,
          ) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to set log navigation up shortcut',
        e,
        stackTrace,
      );
      return false;
    }
  }

  Future<String> getLogNavigationDownShortcut() async {
    try {
      return _prefs?.getString(AppConstants.logNavigationDownShortcutKey) ??
          AppConstants.defaultLogNavigationDownShortcut;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get log navigation down shortcut',
        e,
        stackTrace,
      );
      return AppConstants.defaultLogNavigationDownShortcut;
    }
  }

  Future<bool> setLogNavigationDownShortcut(String shortcut) async {
    try {
      return await _prefs?.setString(
            AppConstants.logNavigationDownShortcutKey,
            shortcut,
          ) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to set log navigation down shortcut',
        e,
        stackTrace,
      );
      return false;
    }
  }

  // Auto Refresh Interval Seconds
  Future<int> getAutoRefreshIntervalSeconds() async {
    try {
      return _prefs?.getInt(AppConstants.autoRefreshIntervalSecondsKey) ??
          AppConstants.defaultAutoRefreshIntervalSeconds;
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to get auto refresh interval seconds', e, stackTrace);
      return AppConstants.defaultAutoRefreshIntervalSeconds;
    }
  }

  Future<bool> setAutoRefreshIntervalSeconds(int seconds) async {
    try {
      return await _prefs?.setInt(
            AppConstants.autoRefreshIntervalSecondsKey,
            seconds,
          ) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to set auto refresh interval seconds', e, stackTrace);
      return false;
    }
  }

  // AWS auth settings
  Future<String?> getAwsProfile() async {
    try {
      return _prefs?.getString(AppConstants.awsProfileKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get AWS profile', e, stackTrace);
      return null;
    }
  }

  Future<bool> setAwsProfile(String profile) async {
    try {
      return await _prefs?.setString(AppConstants.awsProfileKey, profile) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set AWS profile', e, stackTrace);
      return false;
    }
  }

  Future<String?> getAwsRegion() async {
    try {
      return _prefs?.getString(AppConstants.awsRegionKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get AWS region', e, stackTrace);
      return null;
    }
  }

  Future<bool> setAwsRegion(String region) async {
    try {
      return await _prefs?.setString(AppConstants.awsRegionKey, region) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set AWS region', e, stackTrace);
      return false;
    }
  }

  Future<String?> getAwsClusterName() async {
    try {
      return _prefs?.getString(AppConstants.awsClusterNameKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get AWS cluster name', e, stackTrace);
      return null;
    }
  }

  Future<bool> setAwsClusterName(String clusterName) async {
    try {
      return await _prefs?.setString(
            AppConstants.awsClusterNameKey,
            clusterName,
          ) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set AWS cluster name', e, stackTrace);
      return false;
    }
  }

  Future<String?> getAwsAccountId() async {
    try {
      return _prefs?.getString(AppConstants.awsAccountIdKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get AWS account id', e, stackTrace);
      return null;
    }
  }

  Future<bool> setAwsAccountId(String accountId) async {
    try {
      return await _prefs?.setString(AppConstants.awsAccountIdKey, accountId) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set AWS account id', e, stackTrace);
      return false;
    }
  }

  Future<String?> getAwsSsoStartUrl() async {
    try {
      return _prefs?.getString(AppConstants.awsSsoStartUrlKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get AWS SSO start URL', e, stackTrace);
      return null;
    }
  }

  Future<bool> setAwsSsoStartUrl(String value) async {
    try {
      return await _prefs?.setString(AppConstants.awsSsoStartUrlKey, value) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set AWS SSO start URL', e, stackTrace);
      return false;
    }
  }

  Future<String?> getAwsSsoRegion() async {
    try {
      return _prefs?.getString(AppConstants.awsSsoRegionKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get AWS SSO region', e, stackTrace);
      return null;
    }
  }

  Future<bool> setAwsSsoRegion(String value) async {
    try {
      return await _prefs?.setString(AppConstants.awsSsoRegionKey, value) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set AWS SSO region', e, stackTrace);
      return false;
    }
  }

  // GCP GKE auth settings
  Future<String?> getGcpProjectId() async {
    try {
      return _prefs?.getString(AppConstants.gcpProjectIdKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get GCP project id', e, stackTrace);
      return null;
    }
  }

  Future<bool> setGcpProjectId(String projectId) async {
    try {
      return await _prefs?.setString(
            AppConstants.gcpProjectIdKey,
            projectId,
          ) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set GCP project id', e, stackTrace);
      return false;
    }
  }

  Future<String?> getGcpLocation() async {
    try {
      return _prefs?.getString(AppConstants.gcpLocationKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get GCP location', e, stackTrace);
      return null;
    }
  }

  Future<bool> setGcpLocation(String location) async {
    try {
      return await _prefs?.setString(AppConstants.gcpLocationKey, location) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set GCP location', e, stackTrace);
      return false;
    }
  }

  Future<String?> getGcpLocationType() async {
    try {
      return _prefs?.getString(AppConstants.gcpLocationTypeKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get GCP location type', e, stackTrace);
      return null;
    }
  }

  Future<bool> setGcpLocationType(String locationType) async {
    try {
      return await _prefs?.setString(
            AppConstants.gcpLocationTypeKey,
            locationType,
          ) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set GCP location type', e, stackTrace);
      return false;
    }
  }

  Future<String?> getGcpClusterName() async {
    try {
      return _prefs?.getString(AppConstants.gcpClusterNameKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get GCP cluster name', e, stackTrace);
      return null;
    }
  }

  Future<bool> setGcpClusterName(String clusterName) async {
    try {
      return await _prefs?.setString(
            AppConstants.gcpClusterNameKey,
            clusterName,
          ) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set GCP cluster name', e, stackTrace);
      return false;
    }
  }

  Future<String?> getGcpAccount() async {
    try {
      return _prefs?.getString(AppConstants.gcpAccountKey);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get GCP account', e, stackTrace);
      return null;
    }
  }

  Future<bool> setGcpAccount(String account) async {
    try {
      return await _prefs?.setString(AppConstants.gcpAccountKey, account) ??
          false;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to set GCP account', e, stackTrace);
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

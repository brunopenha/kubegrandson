class AppConstants {
  static const String appName = 'KubeGrandson';
  static const String appVersion = '2.3.2';
  static const String appDescription = 'Kubernetes Log Viewer - Son of Kubeson';

  // Storage keys
  static const String kubeconfigPathKey = 'kubeconfig_path';
  static const String kubeConfigPathKey = 'kubeconfig_path'; // Alias for consistency
  static const String currentContextKey = 'current_context';
  static const String defaultNamespaceKey = 'default_namespace';
  static const String themeKey = 'theme_mode';
  static const String themePreferenceKey = 'theme_preference'; // Alias
  static const String fontSizeKey = 'font_size';
  static const String maxLogLinesKey = 'max_log_lines';
  static const String autoScrollKey = 'auto_scroll';

  // Default values
  static const int defaultMaxLogLines = 1000;
  static const double defaultFontSize = 14.0;
  static const bool defaultAutoScroll = true;
  static const String defaultNamespace = 'default';

  // API
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration defaultTimeout = Duration(seconds: 30); // Alias
  static const int maxRetries = 3;
}
class SettingsState {
  final double logFontSize;
  final int maxLogLines;
  final bool autoScroll;
  final String logNavigationUpShortcut;
  final String logNavigationDownShortcut;
  final String defaultNamespace;
  final int autoRefreshIntervalSeconds;

  const SettingsState({
    required this.logFontSize,
    required this.maxLogLines,
    required this.autoScroll,
    required this.logNavigationUpShortcut,
    required this.logNavigationDownShortcut,
    required this.defaultNamespace,
    required this.autoRefreshIntervalSeconds,
  });

  SettingsState copyWith({
    double? logFontSize,
    int? maxLogLines,
    bool? autoScroll,
    String? logNavigationUpShortcut,
    String? logNavigationDownShortcut,
    String? defaultNamespace,
    int? autoRefreshIntervalSeconds,
  }) {
    return SettingsState(
      logFontSize: logFontSize ?? this.logFontSize,
      maxLogLines: maxLogLines ?? this.maxLogLines,
      autoScroll: autoScroll ?? this.autoScroll,
      logNavigationUpShortcut:
          logNavigationUpShortcut ?? this.logNavigationUpShortcut,
      logNavigationDownShortcut:
          logNavigationDownShortcut ?? this.logNavigationDownShortcut,
      defaultNamespace: defaultNamespace ?? this.defaultNamespace,
      autoRefreshIntervalSeconds:
          autoRefreshIntervalSeconds ?? this.autoRefreshIntervalSeconds,
    );
  }
}

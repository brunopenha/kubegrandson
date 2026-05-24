class SettingsState {
  final double logFontSize;
  final int maxLogLines;
  final bool autoScroll;
  final String defaultNamespace;
  final int autoRefreshIntervalSeconds;

  const SettingsState({
    required this.logFontSize,
    required this.maxLogLines,
    required this.autoScroll,
    required this.defaultNamespace,
    required this.autoRefreshIntervalSeconds,
  });

  SettingsState copyWith({
    double? logFontSize,
    int? maxLogLines,
    bool? autoScroll,
    String? defaultNamespace,
    int? autoRefreshIntervalSeconds,
  }) {
    return SettingsState(
      logFontSize: logFontSize ?? this.logFontSize,
      maxLogLines: maxLogLines ?? this.maxLogLines,
      autoScroll: autoScroll ?? this.autoScroll,
      defaultNamespace: defaultNamespace ?? this.defaultNamespace,
      autoRefreshIntervalSeconds:
          autoRefreshIntervalSeconds ?? this.autoRefreshIntervalSeconds,
    );
  }
}

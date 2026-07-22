import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/services/kubernetes_service.dart';
import 'kubernetes_provider.dart';
import 'settings_notifier.dart';

class LogEntry {
  final String text;
  final DateTime timestamp;
  final int lineNumber;
  final Map<String, dynamic>? metadata;
  final String? source;
  final String? level;

  LogEntry({
    required this.text,
    required this.timestamp,
    required this.lineNumber,
    this.metadata,
    this.source,
    this.level,
  });

  factory LogEntry.fromRaw(String raw, int lineNumber, {String? source}) {
    String? prefix;
    Map<String, dynamic>? parsed;
    String? level;
    DateTime? timestamp;

    // Split into prefix and JSON
    final regex = RegExp(r'^\[(.*?)\]\s*(\{.*\})$');
    final match = regex.firstMatch(raw);

    if (match != null) {
      prefix = '[${match.group(1)}]';
      try {
        parsed = jsonDecode(match.group(2)!);
        level = _normalizeLogLevel(parsed?['level']?.toString());
        final rawTimestamp = parsed?['timestamp']?.toString();
        timestamp =
            rawTimestamp == null ? null : DateTime.tryParse(rawTimestamp);
      } catch (_) {
        parsed = null;
      }
    }
    level ??= _inferLogLevel(raw);

    return LogEntry(
      text: raw,
      timestamp: timestamp ?? DateTime.now(),
      lineNumber: lineNumber,
      metadata: parsed,
      source: source ?? prefix,
      level: level,
    );
  }
}

class LogState {
  final List<LogEntry> logs;
  final bool isLoading;
  final String? error;
  final bool autoScroll;
  final String searchQuery;
  final LogEntry? selectedLogEntry;
  final bool traceOnly;
  final bool debugOnly;
  final bool warnOnly;
  final bool infoOnly;
  final bool errorOnly;
  final bool fatalOnly;
  final bool unknowOnly;
  final bool showTimestamps;
  final bool showPodNames;
  final int selectedSearchMatchIndex;

  LogState({
    this.logs = const [],
    this.isLoading = false,
    this.error,
    this.autoScroll = true,
    this.searchQuery = '',
    this.selectedLogEntry,
    this.traceOnly = false,
    this.debugOnly = false,
    this.infoOnly = false,
    this.warnOnly = false,
    this.errorOnly = false,
    this.fatalOnly = false,
    this.unknowOnly = false,
    this.showTimestamps = false,
    this.showPodNames = false,
    this.selectedSearchMatchIndex = -1,
  });

  LogState copyWith({
    List<LogEntry>? logs,
    bool? isLoading,
    String? error,
    bool? autoScroll,
    String? searchQuery,
    Object? selectedLogEntry = _unset,
    bool? traceOnly,
    bool? debugOnly,
    bool? infoOnly,
    bool? warnOnly,
    bool? errorOnly,
    bool? fatalOnly,
    bool? unknowOnly,
    bool? showTimestamps,
    bool? showPodNames,
    int? selectedSearchMatchIndex,
  }) {
    return LogState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      autoScroll: autoScroll ?? this.autoScroll,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedLogEntry: selectedLogEntry == _unset
          ? this.selectedLogEntry
          : selectedLogEntry as LogEntry?,
      traceOnly: traceOnly ?? this.traceOnly,
      debugOnly: debugOnly ?? this.debugOnly,
      infoOnly: infoOnly ?? this.infoOnly,
      warnOnly: warnOnly ?? this.warnOnly,
      errorOnly: errorOnly ?? this.errorOnly,
      fatalOnly: fatalOnly ?? this.fatalOnly,
      unknowOnly: unknowOnly ?? this.unknowOnly,
      showTimestamps: showTimestamps ?? this.showTimestamps,
      showPodNames: showPodNames ?? this.showPodNames,
      selectedSearchMatchIndex:
          selectedSearchMatchIndex ?? this.selectedSearchMatchIndex,
    );
  }
}

const Object _unset = Object();

class LogNotifier extends StateNotifier<LogState> {
  static const markerLine = '----------------------------------------';

  final KubernetesService _kubernetesService;
  final int _maxLogLines;
  final BehaviorSubject<List<LogEntry>> _logsController =
      BehaviorSubject<List<LogEntry>>.seeded([]);
  final List<StreamSubscription<String>> _subscriptions = [];
  final Set<String> _streamingPodNames = {};
  final List<LogEntry> _pendingLogEntries = [];
  Timer? _logFlushTimer;
  int _lineNumber = 0;
  int _streamGeneration = 0;

  LogNotifier(
    this._kubernetesService, {
    required bool defaultAutoScroll,
    required int maxLogLines,
  })  : _maxLogLines = maxLogLines,
        super(LogState(autoScroll: defaultAutoScroll));

  Future<void> startStreaming({
    required String namespace,
    required String podName,
    String? containerName,
    int tailLines = 100,
  }) async {
    await startStreamingForPods(
      namespace: namespace,
      podNames: [podName],
      containerName: containerName,
      tailLines: tailLines,
    );
  }

  Future<void> startStreamingForPods({
    required String namespace,
    required List<String> podNames,
    String? sourceLabel,
    String? containerName,
    int tailLines = 100,
    bool clearExistingLogs = true,
    bool markPodStoppedOnDone = false,
    bool retryInitialConnection = false,
  }) async {
    await _cancelSubscriptions();
    final streamGeneration = _streamGeneration;
    if (clearExistingLogs) {
      _discardPendingLogs();
      _lineNumber = 0;
    } else {
      _flushPendingLogs();
    }
    state = state.copyWith(
      logs: clearExistingLogs ? [] : state.logs,
      isLoading: true,
      error: null,
    );

    try {
      for (final podName in podNames) {
        _streamingPodNames.add(podName);
        _connectPodStream(
          namespace: namespace,
          podName: podName,
          sourceLabel: sourceLabel,
          containerName: containerName,
          tailLines: tailLines,
          markPodStoppedOnDone: markPodStoppedOnDone,
          retryInitialConnection: retryInitialConnection,
          streamGeneration: streamGeneration,
        );
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void addStreamingPods({
    required String namespace,
    required Iterable<String> podNames,
    String? containerName,
    int tailLines = 100,
    bool markPodStoppedOnDone = true,
    bool retryInitialConnection = true,
  }) {
    final streamGeneration = _streamGeneration;
    for (final podName in podNames) {
      if (!_streamingPodNames.add(podName)) continue;
      _connectPodStream(
        namespace: namespace,
        podName: podName,
        containerName: containerName,
        tailLines: tailLines,
        markPodStoppedOnDone: markPodStoppedOnDone,
        retryInitialConnection: retryInitialConnection,
        streamGeneration: streamGeneration,
      );
    }
  }

  void _connectPodStream({
    required String namespace,
    required String podName,
    required int tailLines,
    required bool markPodStoppedOnDone,
    required bool retryInitialConnection,
    required int streamGeneration,
    String? sourceLabel,
    String? containerName,
    int attempt = 0,
  }) {
    if (streamGeneration != _streamGeneration || !mounted) return;

    var receivedLogs = false;
    var retryScheduled = false;
    final subscription = _kubernetesService
        .streamLogs(
      namespace: namespace,
      podName: podName,
      containerName: containerName,
      tailLines: tailLines,
      follow: true,
    )
        .listen(
      (logLine) {
        if (streamGeneration != _streamGeneration) return;
        receivedLogs = true;
        final entry = LogEntry.fromRaw(
          logLine,
          ++_lineNumber,
          source: podName,
        );

        _enqueueLogEntry(entry);
      },
      onError: (Object error) {
        if (streamGeneration != _streamGeneration) return;
        if (retryInitialConnection && !receivedLogs && attempt < 29) {
          retryScheduled = true;
          Future<void>.delayed(const Duration(seconds: 2), () {
            _connectPodStream(
              namespace: namespace,
              podName: podName,
              sourceLabel: sourceLabel,
              containerName: containerName,
              tailLines: tailLines,
              markPodStoppedOnDone: markPodStoppedOnDone,
              retryInitialConnection: retryInitialConnection,
              streamGeneration: streamGeneration,
              attempt: attempt + 1,
            );
          });
          return;
        }
        _streamingPodNames.remove(podName);
        addStreamErrorMarker(podName, error);
      },
      onDone: () {
        if (streamGeneration != _streamGeneration || retryScheduled) return;
        _streamingPodNames.remove(podName);
        if (markPodStoppedOnDone) addPodStoppedMarker(podName);
      },
    );
    _subscriptions.add(subscription);
  }

  void _enqueueLogEntry(LogEntry entry) {
    _pendingLogEntries.add(entry);
    _logFlushTimer ??= Timer(
      const Duration(milliseconds: 100),
      _flushPendingLogs,
    );
  }

  void _flushPendingLogs() {
    _logFlushTimer?.cancel();
    _logFlushTimer = null;
    if (_pendingLogEntries.isEmpty || !mounted) return;

    final entries = List<LogEntry>.from(_pendingLogEntries);
    _pendingLogEntries.clear();
    final currentLogs = List<LogEntry>.from(state.logs)..addAll(entries);
    if (currentLogs.length > _maxLogLines) {
      currentLogs.removeRange(0, currentLogs.length - _maxLogLines);
    }
    state = state.copyWith(logs: currentLogs, isLoading: false);
    _logsController.add(currentLogs);
  }

  void _discardPendingLogs() {
    _logFlushTimer?.cancel();
    _logFlushTimer = null;
    _pendingLogEntries.clear();
  }

  void toggleAutoScroll() {
    state = state.copyWith(autoScroll: !state.autoScroll);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query,
      selectedSearchMatchIndex: -1,
      selectedLogEntry: null,
    );
  }

  @visibleForTesting
  void replaceLogs(List<LogEntry> logs) {
    _discardPendingLogs();
    state = state.copyWith(
      logs: logs,
      isLoading: false,
      error: null,
      searchQuery: '',
      traceOnly: false,
      debugOnly: false,
      infoOnly: false,
      warnOnly: false,
      errorOnly: false,
      fatalOnly: false,
      selectedLogEntry: null,
      selectedSearchMatchIndex: -1,
    );
    _logsController.add(logs);
  }

  Future<void> loadImportedLogs(List<LogEntry> logs) async {
    await _cancelSubscriptions();
    _lineNumber = logs.length;
    replaceLogs(logs);
  }

  void clearLogs() {
    _discardPendingLogs();
    state = state.copyWith(logs: []);
    _logsController.add([]);
  }

  void addMarker() {
    _flushPendingLogs();
    final now = DateTime.now();
    final text = '$markerLine ${now.toIso8601String()} $markerLine';
    final entry = LogEntry(
      text: text,
      timestamp: now,
      lineNumber: ++_lineNumber,
      metadata: null,
      source: 'marker',
      level: 'marker',
    );

    final currentLogs = List<LogEntry>.from(state.logs)..add(entry);
    if (currentLogs.length > _maxLogLines) {
      currentLogs.removeRange(0, currentLogs.length - _maxLogLines);
    }

    state = state.copyWith(logs: currentLogs, selectedLogEntry: entry);
    _logsController.add(currentLogs);
  }

  void addPodStoppedMarker(String podName) {
    _flushPendingLogs();
    final entry = LogEntry(
      text: '-------- pod "$podName" stopped --------',
      timestamp: DateTime.now(),
      lineNumber: ++_lineNumber,
      metadata: null,
      source: 'marker',
      level: 'marker',
    );

    final currentLogs = List<LogEntry>.from(state.logs)..add(entry);
    if (currentLogs.length > _maxLogLines) {
      currentLogs.removeRange(0, currentLogs.length - _maxLogLines);
    }
    state = state.copyWith(logs: currentLogs);
    _logsController.add(currentLogs);
  }

  void addPodStartingMarker(String podName) {
    _flushPendingLogs();
    final entry = LogEntry(
      text: '---- Pod starting $podName ----',
      timestamp: DateTime.now(),
      lineNumber: ++_lineNumber,
      metadata: null,
      source: 'marker',
      level: 'marker',
    );

    final currentLogs = List<LogEntry>.from(state.logs)..add(entry);
    if (currentLogs.length > _maxLogLines) {
      currentLogs.removeRange(0, currentLogs.length - _maxLogLines);
    }
    state = state.copyWith(logs: currentLogs);
    _logsController.add(currentLogs);
  }

  void addStreamErrorMarker(String podName, Object error) {
    _flushPendingLogs();
    final entry = LogEntry(
      text: '---- Failed to stream pod "$podName": $error ----',
      timestamp: DateTime.now(),
      lineNumber: ++_lineNumber,
      metadata: null,
      source: 'marker',
      level: 'marker',
    );

    final currentLogs = List<LogEntry>.from(state.logs)..add(entry);
    if (currentLogs.length > _maxLogLines) {
      currentLogs.removeRange(0, currentLogs.length - _maxLogLines);
    }
    state = state.copyWith(logs: currentLogs, isLoading: false);
    _logsController.add(currentLogs);
  }

  List<LogEntry> get filteredLogs {
    var logs = state.logs;

    final selectedLevels = <String>[];
    if (state.traceOnly) selectedLevels.add('trace');
    if (state.debugOnly) selectedLevels.add('debug');
    if (state.infoOnly) selectedLevels.add('info');
    if (state.warnOnly) selectedLevels.add('warn');
    if (state.errorOnly) selectedLevels.add('error');
    if (state.fatalOnly) selectedLevels.add('fatal');

    if (selectedLevels.isNotEmpty) {
      logs = logs.where((log) {
        return selectedLevels.contains(_levelForFiltering(log));
      }).toList();
    }

    if (state.searchQuery.isEmpty) return logs;

    return logs
        .where((log) =>
            log.text.toLowerCase().contains(state.searchQuery.toLowerCase()))
        .toList();
  }

  List<LogEntry> get searchMatches {
    if (state.searchQuery.isEmpty) return const [];

    return filteredLogs;
  }

  int get searchMatchCount => searchMatches.length;

  int get searchHitCount {
    final query = state.searchQuery.toLowerCase();
    if (query.isEmpty) return 0;

    return state.logs.fold<int>(0, (count, log) {
      final text = log.text.toLowerCase();
      var start = 0;
      var hits = 0;

      while (true) {
        final index = text.indexOf(query, start);
        if (index < 0) break;

        hits++;
        start = index + query.length;
      }

      return count + hits;
    });
  }

  int get selectedSearchMatchNumber {
    if (state.selectedSearchMatchIndex < 0 || searchMatchCount == 0) {
      return 0;
    }

    return state.selectedSearchMatchIndex + 1;
  }

  @override
  void dispose() {
    _discardPendingLogs();
    _cancelSubscriptions();
    _logsController.close();
    super.dispose();
  }

  void selectLog(LogEntry? logEntry) {
    state = state.copyWith(selectedLogEntry: logEntry);
  }

  void selectAdjacentLog(int direction) {
    if (direction == 0) return;

    final logs = filteredLogs;
    if (logs.isEmpty) return;

    final selected = state.selectedLogEntry;
    final currentIndex = selected == null ? -1 : logs.indexOf(selected);
    final nextIndex = currentIndex < 0
        ? (direction > 0 ? 0 : logs.length - 1)
        : (currentIndex + direction).clamp(0, logs.length - 1);

    state = state.copyWith(selectedLogEntry: logs[nextIndex]);
  }

  void setTraceFilter(bool enabled) {
    state = state.copyWith(traceOnly: enabled);
  }

  void setDebugFilter(bool enabled) {
    state = state.copyWith(debugOnly: enabled);
  }

  void setInfoFilter(bool enabled) {
    state = state.copyWith(infoOnly: enabled);
  }

  void setErrorFilter(bool enabled) {
    state = state.copyWith(errorOnly: enabled);
  }

  void setWarnFilter(bool enabled) {
    state = state.copyWith(warnOnly: enabled);
  }

  void setFatalFilter(bool enabled) {
    state = state.copyWith(fatalOnly: enabled);
  }

  void clearLevelFilters() {
    state = state.copyWith(
      traceOnly: false,
      debugOnly: false,
      infoOnly: false,
      warnOnly: false,
      errorOnly: false,
      fatalOnly: false,
    );
  }

  void setShowTimestamps(bool enabled) {
    state = state.copyWith(showTimestamps: enabled);
  }

  void setShowPodNames(bool enabled) {
    state = state.copyWith(showPodNames: enabled);
  }

  Future<void> _cancelSubscriptions() async {
    _streamGeneration++;
    _streamingPodNames.clear();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  void goToNextSearchMatch() {
    final matches = filteredLogs;

    if (state.searchQuery.isEmpty || matches.isEmpty) {
      return;
    }

    final nextIndex = (state.selectedSearchMatchIndex + 1) % matches.length;

    state = state.copyWith(
      selectedSearchMatchIndex: nextIndex,
      selectedLogEntry: matches[nextIndex],
    );
  }

  void goToPreviousSearchMatch() {
    final matches = filteredLogs;

    if (state.searchQuery.isEmpty || matches.isEmpty) {
      return;
    }

    final previousIndex = state.selectedSearchMatchIndex <= 0
        ? matches.length - 1
        : state.selectedSearchMatchIndex - 1;

    state = state.copyWith(
      selectedSearchMatchIndex: previousIndex,
      selectedLogEntry: matches[previousIndex],
    );
  }
}

String? _levelForFiltering(LogEntry log) {
  return _normalizeLogLevel(log.level) ?? _inferLogLevel(log.text);
}

String? logLevelForDisplay(LogEntry log) {
  return _levelForFiltering(log);
}

String? _inferLogLevel(String text) {
  final lowerText = text.toLowerCase();
  final levelPattern = RegExp(
    r'(^|[^a-z])(trace|debug|info|warn|warning|error|fatal)([^a-z]|$)',
    caseSensitive: false,
  );
  final match = levelPattern.firstMatch(lowerText);
  return _normalizeLogLevel(match?.group(2));
}

String? _normalizeLogLevel(String? level) {
  switch (level?.toLowerCase()) {
    case 'trace':
      return 'trace';
    case 'debug':
      return 'debug';
    case 'info':
      return 'info';
    case 'warn':
    case 'warning':
      return 'warn';
    case 'error':
      return 'error';
    case 'fatal':
      return 'fatal';
    default:
      return null;
  }
}

final logProvider = StateNotifierProvider.family<LogNotifier, LogState, String>(
  (ref, podKey) {
    final service = ref.watch(kubernetesServiceProvider);
    final settings = ref.watch(settingsProvider);
    return LogNotifier(
      service,
      defaultAutoScroll: settings.autoScroll,
      maxLogLines: settings.maxLogLines,
    );
  },
);
String prettyJson(String line) {
  try {
    final jsonObj = jsonDecode(line);
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(jsonObj);
  } catch (_) {
    return line; // not JSON
  }
}

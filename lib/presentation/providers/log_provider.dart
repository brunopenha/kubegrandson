import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/services/kubernetes_service.dart';
import 'kubernetes_provider.dart';

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

  factory LogEntry.fromRaw(String raw, int lineNumber) {
    String? prefix;
    Map<String, dynamic>? parsed;
    String? level;

    // Split into prefix and JSON
    final regex = RegExp(r'^\[(.*?)\]\s*(\{.*\})$');
    final match = regex.firstMatch(raw);

    if (match != null) {
      prefix = '[${match.group(1)}]';
      try {
        parsed = jsonDecode(match.group(2)!);
        level = parsed?['level']?.toString();
      } catch (_) {
        parsed = null;
      }
    }

    return LogEntry(
      text: raw,
      timestamp: DateTime.now(),
      lineNumber: lineNumber,
      metadata: parsed,
      source: prefix,
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

  LogState({
    this.logs = const [],
    this.isLoading = false,
    this.error,
    this.autoScroll = true,
    this.searchQuery = '',
    this.selectedLogEntry,
  });

  LogState copyWith({
    List<LogEntry>? logs,
    bool? isLoading,
    String? error,
    bool? autoScroll,
    String? searchQuery,
    LogEntry? selectedLogEntry,
  }) {
    return LogState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      autoScroll: autoScroll ?? this.autoScroll,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedLogEntry: selectedLogEntry ?? this.selectedLogEntry,
    );
  }
}

class LogNotifier extends StateNotifier<LogState> {
  final KubernetesService _kubernetesService;
  final BehaviorSubject<List<LogEntry>> _logsController =
  BehaviorSubject<List<LogEntry>>.seeded([]);

  LogNotifier(this._kubernetesService) : super(LogState());

  Future<void> startStreaming({
    required String namespace,
    required String podName,
    String? containerName,
    int tailLines = 100,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final logStream = _kubernetesService.streamLogs(
        namespace: namespace,
        podName: podName,
        containerName: containerName,
        tailLines: tailLines,
        follow: true,
      );

      int lineNumber = 0;
      await for (final logLine in logStream) {
        final entry = LogEntry.fromRaw(logLine, ++lineNumber);

        final currentLogs = List<LogEntry>.from(state.logs)..add(entry);
        state = state.copyWith(logs: currentLogs, isLoading: false);
        _logsController.add(currentLogs);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void toggleAutoScroll() {
    state = state.copyWith(autoScroll: !state.autoScroll);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
    _logsController.add([]);
  }

  List<LogEntry> get filteredLogs {
    if (state.searchQuery.isEmpty) return state.logs;

    return state.logs
        .where((log) =>
        log.text.toLowerCase().contains(state.searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _logsController.close();
    super.dispose();
  }

  void selectLog(LogEntry? logEntry) {
    state = state.copyWith(selectedLogEntry: logEntry);
  }

}

final logProvider =
StateNotifierProvider.family<LogNotifier, LogState, String>(
      (ref, podKey) {
    final service = ref.watch(kubernetesServiceProvider);
    return LogNotifier(service);
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
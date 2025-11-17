import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/services/kubernetes_service.dart';
import 'kubernetes_provider.dart';

class LogEntry {
  final String text;
  final DateTime timestamp;
  final int lineNumber;

  LogEntry({
    required this.text,
    required this.timestamp,
    required this.lineNumber,
  });
}

class LogState {
  final List<LogEntry> logs;
  final bool isLoading;
  final String? error;
  final bool autoScroll;
  final String searchQuery;

  LogState({
    this.logs = const [],
    this.isLoading = false,
    this.error,
    this.autoScroll = true,
    this.searchQuery = '',
  });

  LogState copyWith({
    List<LogEntry>? logs,
    bool? isLoading,
    String? error,
    bool? autoScroll,
    String? searchQuery,
  }) {
    return LogState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      autoScroll: autoScroll ?? this.autoScroll,
      searchQuery: searchQuery ?? this.searchQuery,
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
        final entry = LogEntry(
          text: logLine,
          timestamp: DateTime.now(),
          lineNumber: ++lineNumber,
        );

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
}

final logProvider =
StateNotifierProvider.family<LogNotifier, LogState, String>(
      (ref, podKey) {
    final service = ref.watch(kubernetesServiceProvider);
    return LogNotifier(service);
  },
);
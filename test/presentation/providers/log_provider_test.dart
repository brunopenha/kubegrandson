import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/domain/services/kubernetes_service.dart';
import 'package:kubegrandson/presentation/providers/log_provider.dart';
import 'package:mocktail/mocktail.dart';

class MockKubernetesService extends Mock implements KubernetesService {}

LogEntry _entry(String text, int lineNumber) {
  return LogEntry(
    text: text,
    timestamp: DateTime(2026),
    lineNumber: lineNumber,
  );
}

void main() {
  late LogNotifier notifier;
  late MockKubernetesService service;

  setUp(() {
    service = MockKubernetesService();
    notifier = LogNotifier(
      service,
      defaultAutoScroll: true,
      maxLogLines: 1000,
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  test('setSearchQuery filters logs case-insensitively', () {
    notifier.replaceLogs([
      _entry('INFO request accepted', 1),
      _entry('ERROR request failed', 2),
      _entry('DEBUG cache warmup', 3),
    ]);

    notifier.setSearchQuery('request');

    expect(notifier.searchMatchCount, 2);
    expect(notifier.filteredLogs.map((log) => log.lineNumber), [1, 2]);
  });

  test('searchHitCount counts every occurrence across logs', () {
    notifier.replaceLogs([
      _entry('error: first error', 1),
      _entry('no match here', 2),
      _entry('ERROR again', 3),
    ]);

    notifier.setSearchQuery('error');

    expect(notifier.searchMatchCount, 2);
    expect(notifier.searchHitCount, 3);
  });

  test('goToNextSearchMatch selects matches circularly', () {
    notifier.replaceLogs([
      _entry('alpha one', 1),
      _entry('beta', 2),
      _entry('alpha two', 3),
    ]);
    notifier.setSearchQuery('alpha');

    notifier.goToNextSearchMatch();
    expect(notifier.state.selectedSearchMatchIndex, 0);
    expect(notifier.selectedSearchMatchNumber, 1);
    expect(notifier.state.selectedLogEntry?.lineNumber, 1);

    notifier.goToNextSearchMatch();
    expect(notifier.state.selectedSearchMatchIndex, 1);
    expect(notifier.selectedSearchMatchNumber, 2);
    expect(notifier.state.selectedLogEntry?.lineNumber, 3);

    notifier.goToNextSearchMatch();
    expect(notifier.state.selectedSearchMatchIndex, 0);
    expect(notifier.selectedSearchMatchNumber, 1);
    expect(notifier.state.selectedLogEntry?.lineNumber, 1);
  });

  test('goToPreviousSearchMatch selects matches circularly', () {
    notifier.replaceLogs([
      _entry('alpha one', 1),
      _entry('beta', 2),
      _entry('alpha two', 3),
    ]);
    notifier.setSearchQuery('alpha');

    notifier.goToPreviousSearchMatch();

    expect(notifier.state.selectedSearchMatchIndex, 1);
    expect(notifier.selectedSearchMatchNumber, 2);
    expect(notifier.state.selectedLogEntry?.lineNumber, 3);
  });

  test('empty search clears selected match', () {
    notifier.replaceLogs([
      _entry('alpha one', 1),
      _entry('alpha two', 2),
    ]);
    notifier.setSearchQuery('alpha');
    notifier.goToNextSearchMatch();

    notifier.setSearchQuery('');

    expect(notifier.searchMatchCount, 0);
    expect(notifier.selectedSearchMatchNumber, 0);
    expect(notifier.state.selectedLogEntry, isNull);
    expect(notifier.state.selectedSearchMatchIndex, -1);
  });

  test('selectAdjacentLog moves selection through filtered logs', () {
    notifier.replaceLogs([
      _entry('alpha one', 1),
      _entry('beta', 2),
      _entry('alpha two', 3),
    ]);
    notifier.setSearchQuery('alpha');

    notifier.selectAdjacentLog(1);
    expect(notifier.state.selectedLogEntry?.lineNumber, 1);

    notifier.selectAdjacentLog(1);
    expect(notifier.state.selectedLogEntry?.lineNumber, 3);

    notifier.selectAdjacentLog(1);
    expect(notifier.state.selectedLogEntry?.lineNumber, 3);

    notifier.selectAdjacentLog(-1);
    expect(notifier.state.selectedLogEntry?.lineNumber, 1);
  });

  test('addMarker appends a plain marker log entry and selects it', () {
    notifier.replaceLogs([
      _entry('before marker', 1),
    ]);

    notifier.addMarker();

    final marker = notifier.state.logs.last;
    expect(notifier.state.logs, hasLength(2));
    expect(marker.level, 'marker');
    expect(marker.source, 'marker');
    expect(marker.text, contains(LogNotifier.markerLine));
    expect(marker.text, isNot(contains('manual-log-marker')));
    expect(marker.metadata, isNull);
    expect(notifier.state.selectedLogEntry, marker);
  });

  test('addPodStoppedMarker appends an English pod stop marker', () {
    notifier.replaceLogs([_entry('last pod log', 1)]);

    notifier.addPodStoppedMarker('demo-api-abc-123');

    final marker = notifier.state.logs.last;
    expect(
      marker.text,
      '-------- pod "demo-api-abc-123" stopped --------',
    );
    expect(marker.source, 'marker');
    expect(marker.level, 'marker');
  });

  test('addPodStartingMarker appends an English pod start marker', () {
    notifier.replaceLogs([_entry('previous pod log', 1)]);

    notifier.addPodStartingMarker('demo-quarkus-k8s-97c6548f7-7pd7k');

    final marker = notifier.state.logs.last;
    expect(
      marker.text,
      '---- Pod starting demo-quarkus-k8s-97c6548f7-7pd7k ----',
    );
    expect(marker.source, 'marker');
    expect(marker.level, 'marker');
  });

  test('setShowPodNames toggles pod name visibility', () {
    expect(notifier.state.showPodNames, isFalse);

    notifier.setShowPodNames(true);

    expect(notifier.state.showPodNames, isTrue);
  });

  test('batches streamed log lines before updating state', () async {
    when(
      () => service.streamLogs(
        namespace: any(named: 'namespace'),
        podName: any(named: 'podName'),
        containerName: any(named: 'containerName'),
        tailLines: any(named: 'tailLines'),
        follow: any(named: 'follow'),
      ),
    ).thenAnswer((_) => Stream.fromIterable(['first', 'second', 'third']));

    await notifier.startStreamingForPods(
      namespace: 'default',
      podNames: ['api-123'],
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(notifier.state.logs.map((log) => log.text), [
      'first',
      'second',
      'third',
    ]);
  });

  test('log level filters match plain text logs', () {
    notifier.replaceLogs([
      _entry('[2026-05-28T21:55:59] INFO application started', 1),
      _entry('WARN retrying request', 2),
      _entry('plain line without level', 3),
      _entry('ERROR request failed', 4),
    ]);

    notifier.setInfoFilter(true);
    expect(notifier.filteredLogs.map((log) => log.lineNumber), [1]);

    notifier.setInfoFilter(false);
    notifier.setWarnFilter(true);
    expect(notifier.filteredLogs.map((log) => log.lineNumber), [2]);

    notifier.setWarnFilter(false);
    notifier.setErrorFilter(true);
    expect(notifier.filteredLogs.map((log) => log.lineNumber), [4]);

    notifier.clearLevelFilters();
    expect(notifier.filteredLogs.map((log) => log.lineNumber), [1, 2, 3, 4]);
  });

  test('log level filters match JSON logs', () {
    notifier.replaceLogs([
      LogEntry.fromRaw(
        '[2026-05-28T21:55:59] {"level":"WARNING","message":"careful"}',
        1,
      ),
      LogEntry.fromRaw(
        '[2026-05-28T21:56:00] {"level":"DEBUG","message":"details"}',
        2,
      ),
    ]);

    notifier.setWarnFilter(true);
    expect(notifier.filteredLogs.map((log) => log.lineNumber), [1]);

    notifier.setWarnFilter(false);
    notifier.setDebugFilter(true);
    expect(notifier.filteredLogs.map((log) => log.lineNumber), [2]);
  });
}

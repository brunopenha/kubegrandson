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

  setUp(() {
    notifier = LogNotifier(
      MockKubernetesService(),
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
}

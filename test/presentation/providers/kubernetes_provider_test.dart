// test/presentation/providers/kubernetes_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kubegrandson/data/models/kubernetes/pod.dart';
import 'package:kubegrandson/presentation/providers/kubernetes_provider.dart';

Future<List<KubePod>> _readFilteredPods(ProviderContainer container) async {
  await container.read(currentPodsProvider.future);
  await Future<void>.delayed(Duration.zero);

  final asyncValue = container.read(filteredPodsProvider);
  expect(asyncValue, isA<AsyncData<List<KubePod>>>());

  return (asyncValue as AsyncData<List<KubePod>>).value;
}

void main() {
  group('PodFilterNotifier', () {
    test('setSearchQuery atualiza query', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(podFilterProvider.notifier);
      notifier.setSearchQuery('api');

      final state = container.read(podFilterProvider);
      expect(state.searchQuery, 'api');
    });

    test('togglePhase adiciona e remove phase', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(podFilterProvider.notifier);

      notifier.togglePhase('Running');
      expect(
        container.read(podFilterProvider).selectedPhases.contains('Running'),
        isTrue,
      );

      notifier.togglePhase('Running');
      expect(
        container.read(podFilterProvider).selectedPhases.contains('Running'),
        isFalse,
      );
    });

    test('toggleErrorFilter alterna flag', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(podFilterProvider.notifier);

      expect(container.read(podFilterProvider).showOnlyWithErrors, isFalse);
      notifier.toggleErrorFilter();
      expect(container.read(podFilterProvider).showOnlyWithErrors, isTrue);
    });

    test('reset volta ao default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(podFilterProvider.notifier);
      notifier.setSearchQuery('x');
      notifier.togglePhase('Failed');
      notifier.toggleErrorFilter();

      notifier.reset();

      final state = container.read(podFilterProvider);
      expect(state.searchQuery, '');
      expect(state.selectedPhases, isEmpty);
      expect(state.showOnlyWithErrors, isFalse);
    });
  });

  group('filteredPodsProvider', () {
    test('filtra por searchQuery (case-insensitive)', () async {
      final pods = [
        KubePod(name: 'api-1', namespace: 'default', phase: 'Running', restartCount: 0),
        KubePod(name: 'web-1', namespace: 'default', phase: 'Running', restartCount: 0),
      ];

      final container = ProviderContainer(
        overrides: [
          currentPodsProvider.overrideWith((ref) async => pods),
        ],
      );
      addTearDown(container.dispose);

      container.read(podFilterProvider.notifier).setSearchQuery('API');

      final filtered = await _readFilteredPods(container);
      expect(filtered.map((e) => e.name).toList(), ['api-1']);
    });

    test('filtra por phase', () async {
      final pods = [
        KubePod(name: 'p1', namespace: 'default', phase: 'Running', restartCount: 0),
        KubePod(name: 'p2', namespace: 'default', phase: 'Pending', restartCount: 0),
      ];

      final container = ProviderContainer(
        overrides: [
          currentPodsProvider.overrideWith((ref) async => pods),
        ],
      );
      addTearDown(container.dispose);

      container.read(podFilterProvider.notifier).togglePhase('Pending');

      final filtered = await _readFilteredPods(container);
      expect(filtered.single.name, 'p2');
    });

    test('showOnlyWithErrors filtra por restartCount>0 ou isFailed', () async {
      final pods = [
        KubePod(name: 'ok', namespace: 'default', phase: 'Running', restartCount: 0),
        KubePod(name: 'restarts', namespace: 'default', phase: 'Running', restartCount: 2),
        KubePod(name: 'failed', namespace: 'default', phase: 'Failed', restartCount: 0),
      ];

      final container = ProviderContainer(
        overrides: [
          currentPodsProvider.overrideWith((ref) async => pods),
        ],
      );
      addTearDown(container.dispose);

      container.read(podFilterProvider.notifier).toggleErrorFilter();

      final filtered = await _readFilteredPods(container);
      final names = filtered.map((e) => e.name).toSet();

      expect(names.contains('ok'), isFalse);
      expect(names.contains('restarts'), isTrue);
      expect(names.contains('failed'), isTrue);
    });
  });
}
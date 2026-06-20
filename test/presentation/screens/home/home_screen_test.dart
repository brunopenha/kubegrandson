import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/data/models/kubernetes/pod.dart';
import 'package:kubegrandson/presentation/screens/home/home_screen.dart';

KubePod _pod({
  required String name,
  String phase = 'Running',
  Map<String, String>? labels,
}) {
  return KubePod(
    name: name,
    namespace: 'default',
    phase: phase,
    labels: labels,
  );
}

void main() {
  test('groupPodsByLabel groups replicas by app label', () {
    final groups = groupPodsByLabel([
      _pod(name: 'api-abc-123', labels: {'app': 'api'}),
      _pod(name: 'api-def-456', labels: {'app': 'api'}),
      _pod(name: 'worker-abc-123', labels: {'app': 'worker'}),
    ]);

    expect(groups, hasLength(2));

    final apiGroup = groups.singleWhere((group) => group.title == 'api');
    expect(apiGroup.pods.map((pod) => pod.name), [
      'api-abc-123',
      'api-def-456',
    ]);
  });

  test('groupPodsByLabel falls back to replicaset-style pod prefix', () {
    final groups = groupPodsByLabel([
      _pod(name: 'api-7df786b7c9-a1b2c'),
      _pod(name: 'api-7df786b7c9-d3e4f'),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.title, 'api');
    expect(groups.single.pods, hasLength(2));
  });

  test('logViewerTitleForPods uses grouped labels for multiple pods', () {
    final title = logViewerTitleForPods([
      _pod(name: 'api-abc-123', labels: {'app': 'api'}),
      _pod(name: 'api-def-456', labels: {'app': 'api'}),
      _pod(name: 'worker-abc-123', labels: {'app': 'worker'}),
    ]);

    expect(title, 'api, worker');
  });
}

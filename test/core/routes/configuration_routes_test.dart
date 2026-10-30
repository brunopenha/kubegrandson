import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:kubegrandson/core/routes/app_router.dart';
import 'package:kubegrandson/data/models/kubernetes/config_map.dart';
import 'package:kubegrandson/data/models/kubernetes/deployment.dart';
import 'package:kubegrandson/data/models/kubernetes/pod.dart';
import 'package:kubegrandson/domain/services/kubernetes_service.dart';
import 'package:kubegrandson/presentation/providers/kubernetes_provider.dart';

class MockKubernetesService extends Mock implements KubernetesService {}

void main() {
  testWidgets('opens Deployment spec separately from ConfigMap data',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockKubernetesService();
    when(() => service.readDeploymentSpec(namespace: 'default', name: 'api'))
        .thenAnswer((_) async => {'replicas': 3});
    final container = ProviderContainer(overrides: [
      kubernetesServiceProvider.overrideWithValue(service),
      podsProvider('default').overrideWith((_) async => [
            KubePod(
                name: 'api-1', namespace: 'default', labels: {'app': 'api'}),
          ]),
      configMapsProvider('default').overrideWith((_) async => [
            KubeConfigMap(
                name: 'api-config',
                namespace: 'default',
                labels: {'app': 'api'},
                data: {'setting': 'config-value'}),
          ]),
      deploymentsProvider('default').overrideWith((_) async => [
            KubeDeployment(
                name: 'api',
                namespace: 'default',
                selectorLabels: {'app': 'api'},
                updatedReplicas: 3),
          ]),
    ]);
    addTearDown(container.dispose);
    final router = AppRouter.router;
    router.go('/configmaps/default/api?pods=api-1');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ConfigMap: api'), findsOneWidget);
    expect(find.text('Save ConfigMap'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        contains('config-value'));

    router.go('/deployments/default/api?pods=api-1');
    await tester.pumpAndSettle();
    expect(find.text('Deployment: api'), findsOneWidget);
    expect(find.text('Save Deployment'), findsOneWidget);
    expect(find.text('Save ConfigMap'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        contains('"replicas": 3'));
    verify(() => service.readDeploymentSpec(namespace: 'default', name: 'api'))
        .called(1);
  });
}

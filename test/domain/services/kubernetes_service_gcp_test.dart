import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k8s/k8s.dart' as k8s;
import 'package:mocktail/mocktail.dart';

import 'package:kubegrandson/core/utils/app_logger.dart';
import 'package:kubegrandson/domain/services/kubernetes_service.dart';

class MockKubernetes extends Mock implements k8s.Kubernetes {}

class MockApiClient extends Mock implements k8s.ApiClient {}

void main() {
  setUpAll(() {
    AppLogger.init();
  });

  group('KubernetesService GCP', () {
    test('initialize parses current GKE context', () async {
      final tempDir = await Directory.systemTemp.createTemp('kg-gcp-init-');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final kubeconfigPath =
          File('${tempDir.path}${Platform.pathSeparator}config');
      await kubeconfigPath.writeAsString(_kubeconfigWithGcpContext(
        contextName: 'gke_team-project_us-central1-a_dev-cluster',
      ));

      final kubernetes = MockKubernetes();
      final client = MockApiClient();
      final dio = Dio();

      when(
        () => kubernetes.initFromFile(
          any(),
          validateConfig: any(named: 'validateConfig'),
          throwExceptions: any(named: 'throwExceptions'),
        ),
      ).thenAnswer((_) async {});
      when(() => kubernetes.client).thenReturn(client);
      when(() => client.dio).thenReturn(dio);

      final service = KubernetesService(
        kubernetesFactory: () => kubernetes,
      );

      await service.initialize(
        kubeconfigPath: kubeconfigPath.path,
        verifyConnection: false,
      );

      final info = service.currentGcpGkeContextInfo;
      expect(info, isNotNull);
      expect(info!.projectId, 'team-project');
      expect(info.location, 'us-central1-a');
      expect(info.clusterName, 'dev-cluster');
    });

    test('refreshGcpCredentials runs auth login and get-credentials', () async {
      final tempDir = await Directory.systemTemp.createTemp('kg-gcp-refresh-');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final kubeconfigPath =
          File('${tempDir.path}${Platform.pathSeparator}config');
      await kubeconfigPath.writeAsString(_kubeconfigWithGcpContext(
        contextName: 'gke_team-project_us-central1-a_dev-cluster',
      ));

      final kubernetes = MockKubernetes();
      final client = MockApiClient();
      final dio = Dio();
      final commands = <List<String>>[];

      when(
        () => kubernetes.initFromFile(
          any(),
          validateConfig: any(named: 'validateConfig'),
          throwExceptions: any(named: 'throwExceptions'),
        ),
      ).thenAnswer((_) async {});
      when(() => kubernetes.client).thenReturn(client);
      when(() => client.dio).thenReturn(dio);

      Future<ProcessResult> processRunner(
        String executable,
        List<String> arguments,
      ) async {
        commands.add([executable, ...arguments]);
        return ProcessResult(1, 0, '', '');
      }

      final service = KubernetesService(
        kubernetesFactory: () => kubernetes,
        processRunner: processRunner,
      );

      await service.initialize(
        kubeconfigPath: kubeconfigPath.path,
        verifyConnection: false,
      );
      commands.clear();

      await service.refreshGcpCredentials(
        projectId: 'team-project',
        location: 'us-central1-a',
        locationType: 'zone',
        clusterName: 'dev-cluster',
        account: 'dev@example.com',
      );

      expect(
        commands.any(
          (entry) =>
              entry.length >= 4 &&
              entry[0] == 'gcloud' &&
              entry[1] == 'auth' &&
              entry[2] == 'login' &&
              entry[3] == 'dev@example.com',
        ),
        isTrue,
      );
      expect(
        commands.any(
          (entry) =>
              entry.length >= 5 &&
              entry[0] == 'gcloud' &&
              entry[1] == 'config' &&
              entry[2] == 'set' &&
              entry[3] == 'project' &&
              entry[4] == 'team-project',
        ),
        isTrue,
      );
      expect(
        commands.any(
          (entry) =>
              entry.length >= 9 &&
              entry[0] == 'gcloud' &&
              entry[1] == 'container' &&
              entry[2] == 'clusters' &&
              entry[3] == 'get-credentials' &&
              entry[4] == 'dev-cluster' &&
              entry[5] == '--zone' &&
              entry[6] == 'us-central1-a' &&
              entry[7] == '--project' &&
              entry[8] == 'team-project',
        ),
        isTrue,
      );
    });
  });
}

String _kubeconfigWithGcpContext({
  required String contextName,
}) {
  return '''
apiVersion: v1
kind: Config
clusters:
  - name: gcp-cluster
    cluster:
      server: https://example.com
      certificate-authority-data: Zm9v
contexts:
  - name: $contextName
    context:
      cluster: gcp-cluster
      user: gcp-user
current-context: $contextName
users:
  - name: gcp-user
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        command: gke-gcloud-auth-plugin
''';
}

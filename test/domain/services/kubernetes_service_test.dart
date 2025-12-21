import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k8s/k8s.dart' as k8s;
import 'package:mocktail/mocktail.dart';

import 'package:kubegrandson/domain/services/kubernetes_service.dart';
import 'package:kubegrandson/data/models/kubernetes/pod.dart' as models;
import 'package:kubegrandson/core/utils/app_logger.dart';


class MockKubernetes extends Mock implements k8s.Kubernetes {}

class MockApiClient extends Mock implements k8s.ApiClient {}

class MockDio extends Mock implements Dio {}

class MockVersionApi extends Mock implements k8s.VersionApi {}

class MockCoreV1Api extends Mock implements k8s.CoreV1Api {}

class FakeRequestOptions extends Fake implements RequestOptions {}

// Update Fakes to implement the real k8s types
class _FakeVersionInfo extends Fake implements k8s.VersionInfo {
  @override
  final String gitVersion;

  _FakeVersionInfo({required this.gitVersion});
}

class _FakeObjectMeta extends Fake implements k8s.V1ObjectMeta {
  @override
  final String? name;
  @override
  final String? namespace;

  _FakeObjectMeta({
    this.name,
    this.namespace,
  });
}

class _FakeContainerStatus extends Fake implements k8s.V1ContainerStatus {
  @override
  final String name;
  @override
  final bool ready;
  @override
  final int restartCount;
  @override
  final String image;
  @override
  final k8s.V1ContainerState? state;

  _FakeContainerStatus({
    this.state,
    required this.name,
    required this.ready,
    this.restartCount = 0,
    required this.image,
  });
}

class _FakePodStatus extends Fake implements k8s.V1PodStatus {
  @override
  final String? phase;
  @override
  final List<k8s.V1ContainerStatus>? containerStatuses;

  _FakePodStatus({
    this.phase,
    this.containerStatuses,
  });
}


class _FakePod extends Fake implements k8s.V1Pod {
  @override
  final k8s.V1ObjectMeta? metadata;
  @override
  final k8s.V1PodStatus? status;

  _FakePod({this.metadata, this.status});
}

class _FakePodList extends Fake implements k8s.V1PodList {
  @override
  final List<k8s.V1Pod> items;

  _FakePodList({required this.items});
}

class _FakeNamespace extends Fake implements k8s.V1Namespace {
  @override
  final k8s.V1ObjectMeta? metadata;

  _FakeNamespace({this.metadata});
}

class _FakeNamespaceList extends Fake implements k8s.V1NamespaceList {
  @override
  final List<k8s.V1Namespace> items;

  _FakeNamespaceList({required this.items});
}

class _FakeContainerState extends Fake implements k8s.V1ContainerState {}

void main() {
  setUpAll(() {
    // Initialize the logger to prevent LateInitializationError during tests
    AppLogger.init();

    registerFallbackValue(FakeRequestOptions());
    registerFallbackValue(Options());
    registerFallbackValue(Uri());
  });

  group('KubernetesService.initialize', () {
    test('usa kubeconfigPath fornecido e configura timeouts', () async {
      final kubernetes = MockKubernetes();
      final client = MockApiClient();
      final dio = Dio(); // real pra validar options
      final versionApi = MockVersionApi();

      when(() => kubernetes.initFromFile('/tmp/kubeconfig',
              validateConfig: any(named: 'validateConfig'),
              throwExceptions: any(named: 'throwExceptions')))
          .thenAnswer((_) async {});
      when(() => kubernetes.client).thenReturn(client);
      when(() => client.dio).thenReturn(dio);

      when(() => versionApi.getCode()).thenAnswer((_) async {
        return Response<k8s.VersionInfo>(
          data: _FakeVersionInfo(gitVersion: 'v1.29.0'),
          requestOptions: RequestOptions(path: '/version'),
        );
      });

      final service = KubernetesService(
        kubernetesFactory: () => kubernetes,
        versionApiFactory: (_) => versionApi,
      );

      await service.initialize(kubeconfigPath: '/tmp/kubeconfig');

      expect(dio.options.connectTimeout, const Duration(seconds: 30));
      expect(dio.options.receiveTimeout, Duration.zero);

      verify(() => kubernetes.initFromFile('/tmp/kubeconfig',
          validateConfig: any(named: 'validateConfig'),
          throwExceptions: any(named: 'throwExceptions'))).called(1);
      verify(() => versionApi.getCode()).called(1);
    });

    test('quando kubeconfigPath null usa ~/.kube/config via homeDirResolver',
        () async {
      final kubernetes = MockKubernetes();
      final client = MockApiClient();
      final dio = Dio();
      final versionApi = MockVersionApi();

      when(() => kubernetes.initFromFile(any(),
              validateConfig: any(named: 'validateConfig'),
              throwExceptions: any(named: 'throwExceptions')))
          .thenAnswer((_) async {});
      when(() => kubernetes.client).thenReturn(client);
      when(() => client.dio).thenReturn(dio);

      when(() => versionApi.getCode()).thenAnswer((_) async {
        return Response<k8s.VersionInfo>(
          data: _FakeVersionInfo(gitVersion: 'v1.29.0'),
          requestOptions: RequestOptions(path: '/version'),
        );
      });

      final service = KubernetesService(
        kubernetesFactory: () => kubernetes,
        versionApiFactory: (_) => versionApi,
        homeDirResolver: () => '/home/test',
      );

      await service.initialize();

      verifyNever(() => kubernetes.initFromFile('/home/test/.kube/config',
          validateConfig: any(named: 'validateConfig'),
          throwExceptions: any(named: 'throwExceptions')))
          .called(0);
    });

    test('rethrow em caso de erro', () async {
      final kubernetes = MockKubernetes();
      when(() => kubernetes.initFromFile(any(),
              validateConfig: any(named: 'validateConfig'),
              throwExceptions: any(named: 'throwExceptions')))
          .thenThrow(Exception('boom'));

      final service = KubernetesService(
        kubernetesFactory: () => kubernetes,
        homeDirResolver: () => '/home/test',
      );

      expect(
        () => service.initialize(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('KubernetesService.fetchPods', () {
    test('namespace=all chama listPodForAllNamespaces e mapeia defaults',
        () async {
          final core = MockCoreV1Api();
          final client = MockApiClient();
          final dio = Dio();

          when(() => client.dio).thenReturn(dio);

          final podList = _FakePodList(items: [
            _FakePod(
              metadata: _FakeObjectMeta(),
              status: _FakePodStatus(),
            ),
          ]);

          when(() => core.listPodForAllNamespaces()).thenAnswer((_) async {
            return Response<k8s.V1PodList>(
              data: podList,
              requestOptions: RequestOptions(path: '/api/v1/pods'),
            );
          });

          final service = KubernetesService(
        client: client,
        coreV1ApiFactory: (_) => core,
      );

      final pods = await service.fetchPods('all');

      expect(pods, hasLength(1));
      expect(pods.first.name, 'Unknown');
      expect(pods.first.phase, 'Unknown');

      verify(() => core.listPodForAllNamespaces()).called(1);
      verifyNever(
          () => core.listNamespacedPod(namespace: any(named: 'namespace')));
    });

    test('namespace!=all chama listNamespacedPod e usa namespace fallback',
        () async {
      final core = MockCoreV1Api();
      final client = MockApiClient();
      final dio = Dio();

      when(() => client.dio).thenReturn(dio);

      final podList = _FakePodList(items: [
        _FakePod(
          metadata: _FakeObjectMeta(name: 'p1', namespace: null),
          status: _FakePodStatus(phase: 'Running'),
        ),
      ]);

      when(() => core.listNamespacedPod(namespace: 'dev'))
          .thenAnswer((_) async {
        return Response<k8s.V1PodList>(
          data: podList,
          requestOptions: RequestOptions(path: '/api/v1/namespaces/dev/pods'),
        );
      } as dynamic);

      final service = KubernetesService(
        client: client,
        coreV1ApiFactory: (_) => core,
      );

      final pods = await service.fetchPods('dev');

      expect(pods, hasLength(1));
      expect(pods.first.name, 'p1');
      expect(pods.first.namespace, 'dev'); // fallback
      expect(pods.first.phase, 'Running');

      verify(() => core.listNamespacedPod(namespace: 'dev')).called(1);
    });

    test('soma restartCount a partir de containerStatuses', () async {
      final core = MockCoreV1Api();
      final client = MockApiClient();
      final dio = Dio();

      when(() => client.dio).thenReturn(dio);

      final podList = _FakePodList(items: [
        _FakePod(
          metadata: _FakeObjectMeta(name: 'p1', namespace: 'dev'),
          status: _FakePodStatus(
            phase: 'Running',
            containerStatuses: [
              _FakeContainerStatus(
                name: 'c1',
                ready: true,
                restartCount: 2,
                image: 'img1',
                state: _FakeContainerState(),
              ),
              _FakeContainerStatus(
                name: 'c2',
                ready: false,
                restartCount: 3,
                image: 'img2',
                state: _FakeContainerState(),
              ),
            ],
          ),
        ),
      ]);

      when(() => core.listNamespacedPod(namespace: 'dev'))
          .thenAnswer((_) async {
        return Response<k8s.V1PodList>(
          data: podList,
          requestOptions: RequestOptions(path: '/api/v1/namespaces/dev/pods'),
        );
      } as dynamic);

      final service = KubernetesService(
        client: client,
        coreV1ApiFactory: (_) => core,
      );

      final pods = await service.fetchPods('dev');

      expect(pods.single.restartCount, 5);
      expect(pods.single.containerStatuses, hasLength(2));
      expect(
          pods.single.containerStatuses!.first, isA<models.ContainerStatus>());
    });
  });

  group('KubernetesService.readPodLogs/deletePod/fetchNamespaces', () {
    test('readPodLogs retorna string (fallback vazio)', () async {
      final core = MockCoreV1Api();
      final client = MockApiClient();
      final dio = Dio();

      when(() => client.dio).thenReturn(dio);
      when(
        () => core.readNamespacedPodLog(
          name: 'p1',
          namespace: 'dev',
          follow: true,
        ),
      ).thenAnswer((_) async {
        return Response<String>(
          data: '',
          requestOptions:
              RequestOptions(path: '/api/v1/namespaces/dev/pods/p1/log'),
        );
      });

      final service = KubernetesService(
        client: client,
        coreV1ApiFactory: (_) => core,
      );

      final logs = await service.readPodLogs('dev', 'p1');
      expect(logs, '');
    });

    test('deletePod chama deleteNamespacedPod', () async {
      final core = MockCoreV1Api();
      final client = MockApiClient();
      final dio = Dio();

      when(() => client.dio).thenReturn(dio);
      when(() => core.deleteNamespacedPod(name: 'p1', namespace: 'dev'))
          .thenAnswer((_) async {
        return Response<k8s.V1Pod>(
          data: k8s.V1Pod(),
          requestOptions:
              RequestOptions(path: '/api/v1/namespaces/dev/pods/p1'),
        );
      });

      final service = KubernetesService(
        client: client,
        coreV1ApiFactory: (_) => core,
      );

      await service.deletePod('dev', 'p1');

      verify(() => core.deleteNamespacedPod(name: 'p1', namespace: 'dev'))
          .called(1);
    });

    test('fetchNamespaces retorna lista de nomes', () async {
      final client = MockApiClient();
      final core = MockCoreV1Api();

      when(() => client.getCoreV1Api()).thenReturn(core);
      when(() => core.listNamespace()).thenAnswer((_) async {
        return Response<k8s.V1NamespaceList>(
          data: _FakeNamespaceList(items: [
            _FakeNamespace(metadata: _FakeObjectMeta(name: 'default')),
            _FakeNamespace(metadata: _FakeObjectMeta(name: 'kube-system')),
          ]),
          requestOptions: RequestOptions(path: '/api/v1/namespaces'),
        );
      } as dynamic);

          final service = KubernetesService(client: client);

      final names = await service.fetchNamespaces();

      expect(names, ['default', 'kube-system']);
    });
  });

  group('KubernetesService.streamLogs', () {
    test('emite linhas com timestamp prefixado', () async {
      final client = MockApiClient();
      final dio = MockDio();

      when(() => client.dio).thenReturn(dio);

      final controller = StreamController<Uint8List>();
      addTearDown(() => controller.close());

      final responseBody = ResponseBody(
        controller.stream,
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
        },
      );

      when(
        () => dio.get<ResponseBody>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async {
        return Response<ResponseBody>(
          data: responseBody,
          requestOptions: RequestOptions(path: '/'),
        );
      });

      final service = KubernetesService(client: client);

      final emitted = <String>[];
      final done = Completer<void>();
      
      final sub = service
          .streamLogs(namespace: 'dev', podName: 'p1', follow: true)
          .listen(
            emitted.add,
            onDone: done.complete,
          );

      controller.add(Uint8List.fromList(utf8.encode('line1\nli')));
      controller.add(Uint8List.fromList(utf8.encode('ne2\n')));
      
      // Close the controller to signal the end of the stream
      await controller.close();

      // Wait for the stream subscription to process the 'onDone' event
      await done.future;
      await sub.cancel();

      expect(emitted, hasLength(2));
      expect(emitted[0], contains('line1'));
      expect(emitted[1], contains('line2'));
      expect(emitted[0].startsWith('['), isTrue);
    });
  });
}

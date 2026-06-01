import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k8s/k8s.dart' as k8s;
import 'package:kubeconfig/kubeconfig.dart' as kubeconfig;
import 'package:mocktail/mocktail.dart';

import 'package:kubegrandson/core/utils/app_logger.dart';
import 'package:kubegrandson/domain/services/kubernetes_service.dart';

class MockKubernetes extends Mock implements k8s.Kubernetes {}

class MockApiClient extends Mock implements k8s.ApiClient {}

void main() {
  setUpAll(() {
    AppLogger.init();
  });

  group('KubernetesService AWS', () {
    test('initialize normalizes EKS exec env and profile args', () async {
      final tempDir = await Directory.systemTemp.createTemp('kg-aws-init-');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final kubeconfigPath =
          File('${tempDir.path}${Platform.pathSeparator}config');
      await kubeconfigPath.writeAsString(_kubeconfigWithAwsExec(
        contextName: 'arn:aws:eks:eu-west-1:123456789012:cluster/dev-cluster',
        profileArg: null,
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

      Future<ProcessResult> processRunner(
        String executable,
        List<String> arguments,
      ) async {
        if (arguments.length >= 2 &&
            arguments[0] == 'configure' &&
            arguments[1] == 'list-profiles') {
          return ProcessResult(1, 0, 'dev-profile\nsandbox\n', '');
        }
        if (arguments.length >= 4 &&
            arguments[0] == 'sts' &&
            arguments[1] == 'get-caller-identity' &&
            arguments[2] == '--profile' &&
            arguments[3] == 'dev-profile') {
          return ProcessResult(1, 0, '{"Account":"123456789012"}', '');
        }
        return ProcessResult(1, 1, '', 'unexpected command');
      }

      final service = KubernetesService(
        kubernetesFactory: () => kubernetes,
        processRunner: processRunner,
      );

      await service.initialize(
        kubeconfigPath: kubeconfigPath.path,
        verifyConnection: false,
      );

      final updated =
          kubeconfig.Kubeconfig.fromYaml(await kubeconfigPath.readAsString());
      final exec = _currentExecForContext(
        updated,
        'arn:aws:eks:eu-west-1:123456789012:cluster/dev-cluster',
      );
      expect(exec, isNotNull);

      final args = exec!.args ?? const <String>[];
      expect(args.take(2).toList(), ['--profile', 'dev-profile']);
      expect(args, containsAll(['eks', 'get-token']));

      final envMap = <String, String>{};
      for (final entry in exec.env ?? const <kubeconfig.ExecEnv>[]) {
        if (entry.name != null && entry.value != null) {
          envMap[entry.name!] = entry.value!;
        }
      }

      expect(envMap['AWS_PROFILE'], 'dev-profile');
      expect(envMap['AWS_DEFAULT_PROFILE'], 'dev-profile');
      expect(envMap.containsKey('AWS_ACCESS_KEY_ID'), isFalse);
      expect(envMap.containsKey('AWS_SECRET_ACCESS_KEY'), isFalse);
      expect(envMap.containsKey('AWS_SESSION_TOKEN'), isFalse);
    });

    test('getCurrentAwsProfile reads profile from kubeconfig exec args',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('kg-aws-profile-read-');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final kubeconfigPath =
          File('${tempDir.path}${Platform.pathSeparator}config');
      await kubeconfigPath.writeAsString(_kubeconfigWithAwsExec(
        contextName: 'arn:aws:eks:eu-west-1:123456789012:cluster/dev-cluster',
        profileArg: 'team-profile',
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
        processRunner: (_, __) async => ProcessResult(1, 1, '', 'skip'),
      );

      await service.initialize(
        kubeconfigPath: kubeconfigPath.path,
        verifyConnection: false,
      );

      expect(await service.getCurrentAwsProfile(), 'team-profile');
    });

    test('refreshAwsSsoCredentials runs aws sso and update-kubeconfig',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('kg-aws-refresh-');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final kubeconfigPath =
          File('${tempDir.path}${Platform.pathSeparator}config');
      await kubeconfigPath.writeAsString(_kubeconfigWithAwsExec(
        contextName: 'arn:aws:eks:eu-west-1:123456789012:cluster/dev-cluster',
        profileArg: null,
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
        if (arguments.length >= 2 &&
            arguments[0] == 'configure' &&
            arguments[1] == 'list-profiles') {
          return ProcessResult(1, 0, 'team-profile\n', '');
        }
        if (arguments.length >= 4 &&
            arguments[0] == 'sts' &&
            arguments[1] == 'get-caller-identity' &&
            arguments[2] == '--profile') {
          return ProcessResult(1, 0, '{"Account":"123456789012"}', '');
        }
        if (arguments.length >= 2 &&
            arguments[0] == 'sso' &&
            arguments[1] == 'login') {
          return ProcessResult(1, 0, '', '');
        }
        if (arguments.length >= 2 &&
            arguments[0] == 'eks' &&
            arguments[1] == 'update-kubeconfig') {
          return ProcessResult(1, 0, '', '');
        }
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

      await service.refreshAwsSsoCredentials(
        profile: 'team-profile',
        region: 'eu-west-1',
        clusterName: 'dev-cluster',
        accountId: '123456789012',
      );

      expect(
        commands.any(
          (entry) =>
              entry.length >= 5 &&
              entry[0] == 'aws' &&
              entry[1] == 'sso' &&
              entry[2] == 'login' &&
              entry[3] == '--profile' &&
              entry[4] == 'team-profile',
        ),
        isTrue,
      );
      expect(
        commands.any(
          (entry) =>
              entry.length >= 9 &&
              entry[0] == 'aws' &&
              entry[1] == 'eks' &&
              entry[2] == 'update-kubeconfig' &&
              entry[3] == '--region' &&
              entry[4] == 'eu-west-1' &&
              entry[5] == '--name' &&
              entry[6] == 'dev-cluster' &&
              entry[7] == '--profile' &&
              entry[8] == 'team-profile',
        ),
        isTrue,
      );
    });
  });
}

kubeconfig.Exec? _currentExecForContext(
  kubeconfig.Kubeconfig config,
  String contextName,
) {
  final contexts = config.contexts ?? const <kubeconfig.NamedContext>[];
  final authInfos = config.authInfos ?? const <kubeconfig.NamedAuthInfo>[];

  final userName =
      contexts.firstWhere((ctx) => ctx.name == contextName).context?.authInfo;
  if (userName == null) {
    return null;
  }

  for (final authInfo in authInfos) {
    if (authInfo.name == userName) {
      return authInfo.user?.exec;
    }
  }
  return null;
}

String _kubeconfigWithAwsExec({
  required String contextName,
  required String? profileArg,
}) {
  final argsLines = <String>[
    '          - eks',
    '          - get-token',
    '          - --cluster-name',
    '          - dev-cluster',
    if (profileArg != null) '          - --profile',
    if (profileArg != null) '          - $profileArg',
  ].join('\n');

  return '''
apiVersion: v1
kind: Config
clusters:
  - name: aws-cluster
    cluster:
      server: https://example.com
      certificate-authority-data: Zm9v
contexts:
  - name: $contextName
    context:
      cluster: aws-cluster
      user: aws-user
current-context: $contextName
users:
  - name: aws-user
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        command: aws
        args:
$argsLines
        env:
          - name: AWS_PROFILE
          - name: AWS_ACCESS_KEY_ID
            value: stale-key
          - name: AWS_SECRET_ACCESS_KEY
            value: stale-secret
          - name: AWS_SESSION_TOKEN
            value: stale-session
''';
}

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:k8s/k8s.dart' as k8s;
import 'package:kubeconfig/kubeconfig.dart' as kubeconfig;
import 'package:path/path.dart' as p;

// dart run .\check_k8s_auth.dart
Future<void> main(List<String> args) async {
  final kubeconfigPath = _resolveKubeconfigPath(args);
  final contextName = _readContextArg(args);
  final awsProfile = _readOptionArg(args, '--aws-profile');
  final awsRegion = _readOptionArg(args, '--aws-region');
  final eksCluster = _readOptionArg(args, '--eks-cluster');
  final loginSso = args.contains('--aws-sso-login');

  if (loginSso) {
    await _runAwsSsoLogin(awsProfile: awsProfile);
  }

  if (eksCluster != null) {
    await _runAwsEksUpdateKubeconfig(
      clusterName: eksCluster,
      awsRegion: awsRegion,
      awsProfile: awsProfile,
    );
  }

  if (contextName != null) {
    await _switchContext(kubeconfigPath, contextName);
  }

  final kube = k8s.Kubernetes();
  await kube.initFromFile(
    kubeconfigPath,
    validateConfig: true,
    throwExceptions: true,
  );

  final version = await k8s.VersionApi(kube.client.dio).getCode();
  final currentContext = await _readCurrentContext(kubeconfigPath);
  print('Using kubeconfig: $kubeconfigPath');
  print('Current context: $currentContext');
  print('Connected. Version: ${version.data?.gitVersion}');

  final ns = await k8s.CoreV1Api(kube.client.dio).listNamespace();
  final names = (ns.data?.items ?? []).map((e) => e.metadata?.name).toList();
  print('Namespaces: $names');
}

String _resolveKubeconfigPath(List<String> args) {
  final fromArg =
      _readOptionArg(args, '--kubeconfig') ?? _readOptionArg(args, '-k');
  if (fromArg != null && fromArg.trim().isNotEmpty) {
    return fromArg.trim();
  }

  final kubeconfigEnv = Platform.environment['KUBECONFIG'];
  if (kubeconfigEnv != null && kubeconfigEnv.trim().isNotEmpty) {
    final separator = Platform.isWindows ? ';' : ':';
    final firstPath = kubeconfigEnv
        .split(separator)
        .map((value) => value.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (firstPath.isNotEmpty) {
      return firstPath;
    }
  }

  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null || home.isEmpty) {
    throw Exception(
      'Unable to resolve kubeconfig path. Use --kubeconfig or define KUBECONFIG.',
    );
  }

  return p.join(home, '.kube', 'config');
}

String? _readContextArg(List<String> args) {
  final long = _readOptionArg(args, '--context');
  if (long != null) {
    return long;
  }

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '-c' && i + 1 < args.length) {
      return args[i + 1];
    }
  }
  return null;
}

String? _readOptionArg(List<String> args, String optionName) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == optionName && i + 1 < args.length) {
      return args[i + 1];
    }
  }
  return null;
}

Future<void> _runAwsSsoLogin({String? awsProfile}) async {
  final command = <String>['sso', 'login'];
  if (awsProfile != null && awsProfile.isNotEmpty) {
    command.addAll(<String>['--profile', awsProfile]);
  }
  await _runProcess(
    executable: 'aws',
    arguments: command,
    operationName: 'aws sso login',
  );
}

Future<void> _runAwsEksUpdateKubeconfig({
  required String clusterName,
  String? awsRegion,
  String? awsProfile,
}) async {
  final command = <String>[
    'eks',
    'update-kubeconfig',
    '--name',
    clusterName,
  ];
  if (awsRegion != null && awsRegion.isNotEmpty) {
    command.addAll(<String>['--region', awsRegion]);
  }
  if (awsProfile != null && awsProfile.isNotEmpty) {
    command.addAll(<String>['--profile', awsProfile]);
  }

  await _runProcess(
    executable: 'aws',
    arguments: command,
    operationName: 'aws eks update-kubeconfig',
  );
}

Future<void> _runProcess({
  required String executable,
  required List<String> arguments,
  required String operationName,
}) async {
  final result = await Process.run(executable, arguments);
  if (result.stdout.toString().trim().isNotEmpty) {
    print(result.stdout.toString().trim());
  }
  if (result.exitCode != 0) {
    final stderrText = result.stderr.toString().trim();
    throw Exception(
      '$operationName failed with exit code ${result.exitCode}'
      '${stderrText.isEmpty ? '' : ': $stderrText'}',
    );
  }
}

Future<void> _switchContext(String kubeconfigPath, String contextName) async {
  final content = await File(kubeconfigPath).readAsString();
  final config = kubeconfig.Kubeconfig.fromYaml(content);
  final contexts = config.contexts ?? <kubeconfig.NamedContext>[];

  final contextExists = contexts.any((named) => named.name == contextName);
  if (!contextExists) {
    final knownContexts = contexts.map((named) => named.name).toList();
    throw Exception(
      'Context "$contextName" not found. Known contexts: $knownContexts',
    );
  }

  final updated = config.copyWith(currentContext: contextName);
  await File(kubeconfigPath).writeAsString(updated.toYaml());
  print('Switched context to "$contextName"');
}

Future<String?> _readCurrentContext(String kubeconfigPath) async {
  final content = await File(kubeconfigPath).readAsString();
  return kubeconfig.Kubeconfig.fromYaml(content).currentContext;
}

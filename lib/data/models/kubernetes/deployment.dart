import 'package:json_annotation/json_annotation.dart';

part 'deployment.g.dart';

@JsonSerializable()
class KubeDeployment {
  final String name;
  final String namespace;
  final String? uid;
  final int replicas;
  final int readyReplicas;
  final int availableReplicas;
  final int unavailableReplicas;
  final DateTime? creationTimestamp;
  final Map<String, String>? labels;
  final Map<String, String>? annotations;
  final DeploymentStrategy? strategy;

  KubeDeployment({
    required this.name,
    required this.namespace,
    this.uid,
    this.replicas = 0,
    this.readyReplicas = 0,
    this.availableReplicas = 0,
    this.unavailableReplicas = 0,
    this.creationTimestamp,
    this.labels,
    this.annotations,
    this.strategy, required updatedReplicas,
  });

  factory KubeDeployment.fromJson(Map<String, dynamic> json) =>
      _$KubeDeploymentFromJson(json);

  Map<String, dynamic> toJson() => _$KubeDeploymentToJson(this);

  bool get isFullyAvailable => readyReplicas == replicas && unavailableReplicas == 0;

  String get statusText => '$readyReplicas/$replicas';

  double get readinessPercentage {
    if (replicas == 0) return 0.0;
    return (readyReplicas / replicas) * 100;
  }
}

@JsonSerializable()
class DeploymentStrategy {
  final String type;
  final RollingUpdateStrategy? rollingUpdate;

  DeploymentStrategy({
    required this.type,
    this.rollingUpdate,
  });

  factory DeploymentStrategy.fromJson(Map<String, dynamic> json) =>
      _$DeploymentStrategyFromJson(json);

  Map<String, dynamic> toJson() => _$DeploymentStrategyToJson(this);
}

@JsonSerializable()
class RollingUpdateStrategy {
  final int maxSurge;
  final int maxUnavailable;

  RollingUpdateStrategy({
    this.maxSurge = 1,
    this.maxUnavailable = 0,
  });

  factory RollingUpdateStrategy.fromJson(Map<String, dynamic> json) =>
      _$RollingUpdateStrategyFromJson(json);

  Map<String, dynamic> toJson() => _$RollingUpdateStrategyToJson(this);
}
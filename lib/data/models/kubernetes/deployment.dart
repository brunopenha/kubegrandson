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
  final Map<String, String>? selectorLabels;
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
    this.selectorLabels,
    this.strategy,
    required updatedReplicas,
  });

  factory KubeDeployment.fromJson(Map<String, dynamic> json) =>
      _$KubeDeploymentFromJson(json);

  Map<String, dynamic> toJson() => _$KubeDeploymentToJson(this);

  static List<KubeDeployment> fromList(List<dynamic> data, String namespace) {
    return data.map((json) {
      final metadata = json['metadata'] as Map<String, dynamic>? ?? const {};
      final spec = json['spec'] as Map<String, dynamic>? ?? const {};
      final selector = spec['selector'] as Map<String, dynamic>? ?? const {};
      final status = json['status'] as Map<String, dynamic>? ?? const {};
      return KubeDeployment(
        name: metadata['name']?.toString() ?? 'Unknown',
        namespace: metadata['namespace']?.toString() ?? namespace,
        uid: metadata['uid']?.toString(),
        replicas: spec['replicas'] as int? ?? 0,
        readyReplicas: status['readyReplicas'] as int? ?? 0,
        availableReplicas: status['availableReplicas'] as int? ?? 0,
        unavailableReplicas: status['unavailableReplicas'] as int? ?? 0,
        creationTimestamp: metadata['creationTimestamp'] == null
            ? null
            : DateTime.tryParse(metadata['creationTimestamp'].toString()),
        labels: (metadata['labels'] as Map?)?.cast<String, String>(),
        annotations: (metadata['annotations'] as Map?)?.cast<String, String>(),
        selectorLabels:
            (selector['matchLabels'] as Map?)?.cast<String, String>(),
        updatedReplicas: status['updatedReplicas'] as int? ?? 0,
      );
    }).toList();
  }

  bool get isFullyAvailable =>
      readyReplicas == replicas && unavailableReplicas == 0;

  bool matchesPodLabels(Map<String, String>? podLabels) {
    final selector = selectorLabels;
    if (selector == null || selector.isEmpty) return false;
    final labels = podLabels ?? const <String, String>{};
    return selector.entries.every((entry) => labels[entry.key] == entry.value);
  }

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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deployment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KubeDeployment _$KubeDeploymentFromJson(Map<String, dynamic> json) =>
    KubeDeployment(
      name: json['name'] as String,
      namespace: json['namespace'] as String,
      uid: json['uid'] as String?,
      replicas: (json['replicas'] as num?)?.toInt() ?? 0,
      readyReplicas: (json['readyReplicas'] as num?)?.toInt() ?? 0,
      availableReplicas: (json['availableReplicas'] as num?)?.toInt() ?? 0,
      unavailableReplicas: (json['unavailableReplicas'] as num?)?.toInt() ?? 0,
      creationTimestamp: json['creationTimestamp'] == null
          ? null
          : DateTime.parse(json['creationTimestamp'] as String),
      labels: (json['labels'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      annotations: (json['annotations'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      strategy: json['strategy'] == null
          ? null
          : DeploymentStrategy.fromJson(
              json['strategy'] as Map<String, dynamic>), updatedReplicas: null,
    );

Map<String, dynamic> _$KubeDeploymentToJson(KubeDeployment instance) =>
    <String, dynamic>{
      'name': instance.name,
      'namespace': instance.namespace,
      'uid': instance.uid,
      'replicas': instance.replicas,
      'readyReplicas': instance.readyReplicas,
      'availableReplicas': instance.availableReplicas,
      'unavailableReplicas': instance.unavailableReplicas,
      'creationTimestamp': instance.creationTimestamp?.toIso8601String(),
      'labels': instance.labels,
      'annotations': instance.annotations,
      'strategy': instance.strategy,
    };

DeploymentStrategy _$DeploymentStrategyFromJson(Map<String, dynamic> json) =>
    DeploymentStrategy(
      type: json['type'] as String,
      rollingUpdate: json['rollingUpdate'] == null
          ? null
          : RollingUpdateStrategy.fromJson(
              json['rollingUpdate'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeploymentStrategyToJson(DeploymentStrategy instance) =>
    <String, dynamic>{
      'type': instance.type,
      'rollingUpdate': instance.rollingUpdate,
    };

RollingUpdateStrategy _$RollingUpdateStrategyFromJson(
        Map<String, dynamic> json) =>
    RollingUpdateStrategy(
      maxSurge: (json['maxSurge'] as num?)?.toInt() ?? 1,
      maxUnavailable: (json['maxUnavailable'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RollingUpdateStrategyToJson(
        RollingUpdateStrategy instance) =>
    <String, dynamic>{
      'maxSurge': instance.maxSurge,
      'maxUnavailable': instance.maxUnavailable,
    };

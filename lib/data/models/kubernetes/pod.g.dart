// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pod.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KubePod _$KubePodFromJson(Map<String, dynamic> json) => KubePod(
      name: json['name'] as String,
      namespace: json['namespace'] as String,
      uid: json['uid'] as String?,
      phase: json['phase'] as String? ?? 'Unknown',
      podIP: json['podIP'] as String?,
      nodeName: json['nodeName'] as String?,
      creationTimestamp: json['creationTimestamp'] == null
          ? null
          : DateTime.parse(json['creationTimestamp'] as String),
      labels: (json['labels'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      annotations: (json['annotations'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      containerStatuses: (json['containerStatuses'] as List<dynamic>?)
          ?.map((e) => ContainerStatus.fromJson(e as Map<String, dynamic>))
          .toList(),
      restartCount: (json['restartCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$KubePodToJson(KubePod instance) => <String, dynamic>{
      'name': instance.name,
      'namespace': instance.namespace,
      'uid': instance.uid,
      'phase': instance.phase,
      'podIP': instance.podIP,
      'nodeName': instance.nodeName,
      'creationTimestamp': instance.creationTimestamp?.toIso8601String(),
      'labels': instance.labels,
      'annotations': instance.annotations,
      'containerStatuses': instance.containerStatuses,
      'restartCount': instance.restartCount,
    };

ContainerStatus _$ContainerStatusFromJson(Map<String, dynamic> json) =>
    ContainerStatus(
      name: json['name'] as String,
      ready: json['ready'] as bool,
      restartCount: (json['restartCount'] as num?)?.toInt() ?? 0,
      image: json['image'] as String?,
    );

Map<String, dynamic> _$ContainerStatusToJson(ContainerStatus instance) =>
    <String, dynamic>{
      'name': instance.name,
      'ready': instance.ready,
      'restartCount': instance.restartCount,
      'image': instance.image,
    };

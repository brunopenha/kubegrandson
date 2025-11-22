// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'namespace.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KubeNamespace _$KubeNamespaceFromJson(Map<String, dynamic> json) =>
    KubeNamespace(
      name: json['name'] as String,
      uid: json['uid'] as String?,
      phase: json['phase'] as String? ?? 'Active',
      creationTimestamp: json['creationTimestamp'] == null
          ? null
          : DateTime.parse(json['creationTimestamp'] as String),
      labels: (json['labels'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      annotations: (json['annotations'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ), status: null,
    );

Map<String, dynamic> _$KubeNamespaceToJson(KubeNamespace instance) =>
    <String, dynamic>{
      'name': instance.name,
      'uid': instance.uid,
      'phase': instance.phase,
      'creationTimestamp': instance.creationTimestamp?.toIso8601String(),
      'labels': instance.labels,
      'annotations': instance.annotations,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KubeService _$KubeServiceFromJson(Map<String, dynamic> json) => KubeService(
      name: json['name'] as String,
      namespace: json['namespace'] as String,
      uid: json['uid'] as String?,
      type: json['type'] as String? ?? 'ClusterIP',
      clusterIP: json['clusterIP'] as String?,
      externalIPs: (json['externalIPs'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      ports: (json['ports'] as List<dynamic>?)
          ?.map((e) => ServicePort.fromJson(e as Map<String, dynamic>))
          .toList(),
      creationTimestamp: json['creationTimestamp'] == null
          ? null
          : DateTime.parse(json['creationTimestamp'] as String),
      labels: (json['labels'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      annotations: (json['annotations'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      selector: (json['selector'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$KubeServiceToJson(KubeService instance) =>
    <String, dynamic>{
      'name': instance.name,
      'namespace': instance.namespace,
      'uid': instance.uid,
      'type': instance.type,
      'clusterIP': instance.clusterIP,
      'externalIPs': instance.externalIPs,
      'ports': instance.ports,
      'creationTimestamp': instance.creationTimestamp?.toIso8601String(),
      'labels': instance.labels,
      'annotations': instance.annotations,
      'selector': instance.selector,
    };

ServicePort _$ServicePortFromJson(Map<String, dynamic> json) => ServicePort(
      name: json['name'] as String,
      port: (json['port'] as num).toInt(),
      targetPort: (json['targetPort'] as num).toInt(),
      protocol: json['protocol'] as String? ?? 'TCP',
      nodePort: (json['nodePort'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ServicePortToJson(ServicePort instance) =>
    <String, dynamic>{
      'name': instance.name,
      'port': instance.port,
      'targetPort': instance.targetPort,
      'protocol': instance.protocol,
      'nodePort': instance.nodePort,
    };

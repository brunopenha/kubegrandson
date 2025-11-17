// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cluster_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClusterContext _$ClusterContextFromJson(Map<String, dynamic> json) =>
    ClusterContext(
      name: json['name'] as String,
      cluster: json['cluster'] as String?,
      user: json['user'] as String?,
      namespace: json['namespace'] as String?,
      isActive: json['isActive'] as bool? ?? false,
    );

Map<String, dynamic> _$ClusterContextToJson(ClusterContext instance) =>
    <String, dynamic>{
      'name': instance.name,
      'cluster': instance.cluster,
      'user': instance.user,
      'namespace': instance.namespace,
      'isActive': instance.isActive,
    };

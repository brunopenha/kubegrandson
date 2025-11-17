import 'package:json_annotation/json_annotation.dart';

part 'cluster_context.g.dart';

@JsonSerializable()
class ClusterContext {
  final String name;
  final String? cluster;
  final String? user;
  final String? namespace;
  final bool isActive;

  ClusterContext({
    required this.name,
    this.cluster,
    this.user,
    this.namespace,
    this.isActive = false,
  });

  factory ClusterContext.fromJson(Map<String, dynamic> json) =>
      _$ClusterContextFromJson(json);

  Map<String, dynamic> toJson() => _$ClusterContextToJson(this);

  ClusterContext copyWith({
    String? name,
    String? cluster,
    String? user,
    String? namespace,
    bool? isActive,
  }) {
    return ClusterContext(
      name: name ?? this.name,
      cluster: cluster ?? this.cluster,
      user: user ?? this.user,
      namespace: namespace ?? this.namespace,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() => name;
}
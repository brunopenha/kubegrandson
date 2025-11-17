import 'package:json_annotation/json_annotation.dart';

part 'namespace.g.dart';

@JsonSerializable()
class KubeNamespace {
  final String name;
  final String? uid;
  final String phase;
  final DateTime? creationTimestamp;
  final Map<String, String>? labels;
  final Map<String, String>? annotations;

  KubeNamespace({
    required this.name,
    this.uid,
    this.phase = 'Active',
    this.creationTimestamp,
    this.labels,
    this.annotations,
  });

  factory KubeNamespace.fromJson(Map<String, dynamic> json) =>
      _$KubeNamespaceFromJson(json);

  Map<String, dynamic> toJson() => _$KubeNamespaceToJson(this);

  bool get isActive => phase == 'Active';
  bool get isTerminating => phase == 'Terminating';
}
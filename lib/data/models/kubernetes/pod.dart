import 'package:json_annotation/json_annotation.dart';

part 'pod.g.dart';

@JsonSerializable()
class KubePod {
  final String name;
  final String namespace;
  final String? uid;
  final String phase;
  final String? podIP;
  final String? nodeName;
  final DateTime? creationTimestamp;
  final Map<String, String>? labels;
  final Map<String, String>? annotations;
  final List<ContainerStatus>? containerStatuses;
  final int restartCount;

  KubePod({
    required this.name,
    required this.namespace,
    this.uid,
    this.phase = 'Unknown',
    this.podIP,
    this.nodeName,
    this.creationTimestamp,
    this.labels,
    this.annotations,
    this.containerStatuses,
    this.restartCount = 0,
  });

  factory KubePod.fromJson(Map<String, dynamic> json) =>
      _$KubePodFromJson(json);

  Map<String, dynamic> toJson() => _$KubePodToJson(this);

  bool get isRunning => phase == 'Running';
  bool get isPending => phase == 'Pending';
  bool get isFailed => phase == 'Failed';
  bool get isSucceeded => phase == 'Succeeded';

  String get statusText {
    if (containerStatuses != null && containerStatuses!.isNotEmpty) {
      final ready = containerStatuses!.where((c) => c.ready).length;
      return '$ready/${containerStatuses!.length}';
    }
    return phase;
  }
}

@JsonSerializable()
class ContainerStatus {
  final String name;
  final bool ready;
  final int restartCount;
  final String? image;

  ContainerStatus({
    required this.name,
    required this.ready,
    this.restartCount = 0,
    this.image,
    required state,
  });

  factory ContainerStatus.fromJson(Map<String, dynamic> json) =>
      _$ContainerStatusFromJson(json);

  Map<String, dynamic> toJson() => _$ContainerStatusToJson(this);
}

import 'package:json_annotation/json_annotation.dart';

part 'service.g.dart';

@JsonSerializable()
class KubeService {
  final String name;
  final String namespace;
  final String? uid;
  final String type;
  final String? clusterIP;
  final List<String>? externalIPs;
  final List<ServicePort>? ports;
  final DateTime? creationTimestamp;
  final Map<String, String>? labels;
  final Map<String, String>? annotations;
  final Map<String, String>? selector;

  KubeService({
    required this.name,
    required this.namespace,
    this.uid,
    this.type = 'ClusterIP',
    this.clusterIP,
    this.externalIPs,
    this.ports,
    this.creationTimestamp,
    this.labels,
    this.annotations,
    this.selector,
  });

  factory KubeService.fromJson(Map<String, dynamic> json) =>
      _$KubeServiceFromJson(json);

  Map<String, dynamic> toJson() => _$KubeServiceToJson(this);

  bool get isLoadBalancer => type == 'LoadBalancer';
  bool get isNodePort => type == 'NodePort';
  bool get isClusterIP => type == 'ClusterIP';
  bool get isExternalName => type == 'ExternalName';

  String get portsText {
    if (ports == null || ports!.isEmpty) return 'None';
    return ports!.map((p) => '${p.port}:${p.targetPort}/${p.protocol}').join(', ');
  }
}

@JsonSerializable()
class ServicePort {
  final String name;
  final int port;
  final int targetPort;
  final String protocol;
  final int? nodePort;

  ServicePort({
    required this.name,
    required this.port,
    required this.targetPort,
    this.protocol = 'TCP',
    this.nodePort,
  });

  factory ServicePort.fromJson(Map<String, dynamic> json) =>
      _$ServicePortFromJson(json);

  Map<String, dynamic> toJson() => _$ServicePortToJson(this);
}
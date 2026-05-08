class KubeConfigMap {
  final String name;
  final String namespace;
  final String? uid;
  final DateTime? creationTimestamp;
  final Map<String, String>? labels;
  final Map<String, String>? annotations;
  final Map<String, String>? data;
  final Map<String, String>? binaryData;

  KubeConfigMap({
    required this.name,
    required this.namespace,
    this.uid,
    this.creationTimestamp,
    this.labels,
    this.annotations,
    this.data,
    this.binaryData,
  });
}

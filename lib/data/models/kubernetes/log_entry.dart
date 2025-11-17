import 'package:json_annotation/json_annotation.dart';

part 'log_entry.g.dart';

@JsonSerializable()
class LogEntry {
  final String text;
  final DateTime timestamp;
  final String? level;
  final String? source;
  final Map<String, dynamic>? metadata;

  LogEntry({
    required this.text,
    required this.timestamp,
    this.level,
    this.source,
    this.metadata,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) =>
      _$LogEntryFromJson(json);

  Map<String, dynamic> toJson() => _$LogEntryToJson(this);

  bool get isError => level?.toLowerCase() == 'error' || text.toLowerCase().contains('error');
  bool get isWarning => level?.toLowerCase() == 'warn' || text.toLowerCase().contains('warn');
  bool get isInfo => level?.toLowerCase() == 'info';
  bool get isDebug => level?.toLowerCase() == 'debug';
}
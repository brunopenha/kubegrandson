// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LogEntry _$LogEntryFromJson(Map<String, dynamic> json) => LogEntry(
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: json['level'] as String?,
      source: json['source'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$LogEntryToJson(LogEntry instance) => <String, dynamic>{
      'text': instance.text,
      'timestamp': instance.timestamp.toIso8601String(),
      'level': instance.level,
      'source': instance.source,
      'metadata': instance.metadata,
    };

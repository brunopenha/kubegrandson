import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../presentation/providers/log_provider.dart';

class LogImportService {
  Future<List<LogEntry>> parseJsonLogFilePath(
    String path, {
    int? maxEntries,
  }) async {
    final file = File(path);
    final prefix = await _readPrefix(file);
    final trimmedPrefix = prefix.trimLeft();

    if (trimmedPrefix.startsWith('[') ||
        _looksLikeMultilineJsonObject(prefix)) {
      return parseJsonLogFile(
        await file.readAsString(),
        maxEntries: maxEntries,
      );
    }

    final logs = <LogEntry>[];
    var lineNumber = 0;

    await for (final line in file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      logs.add(_entryFromLine(trimmed, ++lineNumber));
      _trimToMaxEntries(logs, maxEntries);
    }

    return logs;
  }

  List<LogEntry> parseJsonLogFile(
    String content, {
    int? maxEntries,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return const [];

    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        final entries = _entriesFromDecodedJson(decoded);

        final start = _startIndexForLimit(entries.length, maxEntries);
        return [
          for (var index = start; index < entries.length; index++)
            _entryFromJsonValue(entries[index], index - start + 1),
        ];
      } on FormatException {
        // Fall back to line-by-line logs below.
      }
    }

    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        final entries = _entriesFromDecodedJson(decoded);
        final start = _startIndexForLimit(entries.length, maxEntries);
        return [
          for (var index = start; index < entries.length; index++)
            _entryFromJsonValue(entries[index], index - start + 1),
        ];
      } on FormatException {
        // Fall back to JSON Lines below.
      }
    }

    final logs = <LogEntry>[];
    for (final line in const LineSplitter().convert(content)) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      logs.add(_entryFromLine(trimmedLine, logs.length + 1));
      _trimToMaxEntries(logs, maxEntries);
    }

    return logs;
  }

  LogEntry _entryFromLine(String line, int lineNumber) {
    try {
      return _entryFromJsonValue(jsonDecode(line), lineNumber);
    } on FormatException {
      return LogEntry.fromRaw(line, lineNumber);
    }
  }

  bool _looksLikeMultilineJsonObject(String prefix) {
    final trimmed = prefix.trimLeft();
    if (!trimmed.startsWith('{')) return false;

    return trimmed.contains('\n') || trimmed.contains('\r');
  }

  List<Object?> _entriesFromDecodedJson(Object? decoded) {
    if (decoded is List) return decoded;

    if (decoded is Map) {
      for (final key in const ['logs', 'items', 'entries', 'data', 'records']) {
        final value = decoded[key];
        if (value is List) return value;
      }

      return [decoded];
    }

    throw const FormatException(
      'Expected a JSON array, object, or object containing a log array',
    );
  }

  Future<String> _readPrefix(File file) async {
    final bytes = <int>[];
    await for (final chunk in file.openRead(0, 4096)) {
      bytes.addAll(chunk);
      break;
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  LogEntry _entryFromJsonValue(Object? value, int lineNumber) {
    if (value is String) {
      return LogEntry.fromRaw(value, lineNumber);
    }

    if (value is! Map) {
      throw FormatException('Log entry $lineNumber must be a JSON object');
    }

    final metadata = Map<String, dynamic>.from(value);
    final message = _firstString(metadata, const [
          'message',
          'msg',
          'log',
          'text',
          'body',
        ]) ??
        jsonEncode(metadata);
    final timestampText = _firstString(metadata, const [
      'timestamp',
      'time',
      '@timestamp',
      'ts',
      'date',
    ]);
    final timestamp = timestampText == null
        ? DateTime.now()
        : DateTime.tryParse(timestampText) ?? DateTime.now();
    final level = _firstString(metadata, const [
      'level',
      'severity',
      'logLevel',
    ]);
    final source = _firstString(metadata, const [
      'source',
      'pod',
      'container',
      'service',
      'logger',
    ]);

    return LogEntry(
      text: message,
      timestamp: timestamp,
      lineNumber: lineNumber,
      metadata: metadata,
      source: source,
      level: level,
    );
  }

  String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return value.toString();
    }
    return null;
  }

  int _startIndexForLimit(int length, int? maxEntries) {
    if (maxEntries == null || maxEntries <= 0 || length <= maxEntries) {
      return 0;
    }
    return length - maxEntries;
  }

  void _trimToMaxEntries(List<LogEntry> logs, int? maxEntries) {
    if (maxEntries == null || maxEntries <= 0 || logs.length <= maxEntries) {
      return;
    }

    logs.removeRange(0, logs.length - maxEntries);
    for (var index = 0; index < logs.length; index++) {
      final log = logs[index];
      logs[index] = LogEntry(
        text: log.text,
        timestamp: log.timestamp,
        lineNumber: index + 1,
        metadata: log.metadata,
        source: log.source,
        level: log.level,
      );
    }
  }
}

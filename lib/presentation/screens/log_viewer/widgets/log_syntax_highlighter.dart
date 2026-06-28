import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../providers/log_provider.dart';

const jsonLogKeyColor = Color(0xff7dcfff);
const jsonLogStringColor = Color(0xff9ece6a);
const jsonLogNumberColor = Color(0xffff9e64);
const jsonLogBoolColor = Color(0xffbb9af7);
const jsonLogNullColor = Color(0xfff7768e);
const jsonLogPunctuationColor = Color(0xff565f89);
const jsonLogTimestampColor = Color(0xff6b7280);
const searchHighlightColor = Color(0xffffd84a);
const logTraceColor = Color(0xff2dd4bf);
const logDebugColor = Color(0xff8ab4f8);
const logInfoColor = Color(0xffd7d7d7);
const logWarnColor = Color(0xffffd84a);
const logErrorColor = Color(0xffff5f56);
const logFatalColor = Color(0xffff2d75);
const shellTimestampColor = Color(0xff8a9099);
const shellCommandColor = Color(0xff7dcfff);
const shellOptionColor = Color(0xffbb9af7);
const shellStringColor = Color(0xff9ece6a);
const shellPathColor = Color(0xffff9e64);

final _jsonTokenPattern = RegExp(
  r'"(?:\\.|[^"\\])*"|true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?|[{}\[\]:,]|\s+',
);
final _shellTokenPattern = RegExp(
  r'"(?:\\.|[^"\\])*"|'
  r"'(?:\\.|[^'\\])*'|"
  r'\[[^\]\r\n]+\]|'
  r'-D[\w.]+(?:=[^\s]+)?|'
  r'--?[\w.+-]+(?:=[^\s]+)?|'
  r'/[^\s"]+|'
  r'\b(?:TRACE|DEBUG|INFO|WARN|WARNING|ERROR|FATAL)\b|'
  r'\b(?:bash|sh|zsh|java|kubectl|docker|podman|helm|exec|sudo)\b',
  caseSensitive: false,
);

class _LogTextSegment {
  final String text;
  final TextStyle style;

  const _LogTextSegment(this.text, this.style);
}

TextSpan buildHighlightedLogLine({
  required LogEntry log,
  required bool showTimestamp,
  required String searchQuery,
  required TextStyle baseStyle,
}) {
  final segments = _plainLogSegments(
    log: log,
    showTimestamp: showTimestamp,
    baseStyle: baseStyle,
  );

  return TextSpan(
    style: baseStyle,
    children: _applySearchHighlight(segments, searchQuery),
  );
}

TextSpan buildHighlightedJsonText({
  required String jsonText,
  required String searchQuery,
  required TextStyle baseStyle,
}) {
  return TextSpan(
    style: baseStyle,
    children: _applySearchHighlight(
      _jsonSegments(jsonText: jsonText, baseStyle: baseStyle),
      searchQuery,
    ),
  );
}

TextSpan buildHighlightedShellText({
  required String shellText,
  required String searchQuery,
  required TextStyle baseStyle,
}) {
  return TextSpan(
    style: baseStyle,
    children: _applySearchHighlight(
      _shellSegments(shellText: shellText, baseStyle: baseStyle),
      searchQuery,
    ),
  );
}

Color logLevelColor(String? level) {
  switch (level) {
    case 'trace':
      return logTraceColor;
    case 'debug':
      return logDebugColor;
    case 'info':
      return logInfoColor;
    case 'warn':
      return logWarnColor;
    case 'error':
      return logErrorColor;
    case 'fatal':
      return logFatalColor;
    default:
      return const Color(0xffbdbdbd);
  }
}

List<_LogTextSegment> _plainLogSegments({
  required LogEntry log,
  required bool showTimestamp,
  required TextStyle baseStyle,
}) {
  final segments = <_LogTextSegment>[];

  if (showTimestamp) {
    segments.add(
      _LogTextSegment(
        '${log.timestamp.toIso8601String()} ',
        baseStyle.copyWith(color: jsonLogTimestampColor),
      ),
    );
  }

  final message = log.metadata == null ? log.text : jsonEncode(log.metadata);
  segments.add(_LogTextSegment(message, baseStyle));
  return segments;
}

List<_LogTextSegment> _jsonSegments({
  required String jsonText,
  required TextStyle baseStyle,
}) {
  final segments = <_LogTextSegment>[];
  var cursor = 0;

  for (final match in _jsonTokenPattern.allMatches(jsonText)) {
    if (match.start > cursor) {
      segments.add(
        _LogTextSegment(
          jsonText.substring(cursor, match.start),
          baseStyle,
        ),
      );
    }

    final token = match.group(0)!;
    segments.add(
      _LogTextSegment(
        token,
        _jsonTokenStyle(jsonText, match, token, baseStyle),
      ),
    );
    cursor = match.end;
  }

  if (cursor < jsonText.length) {
    segments.add(_LogTextSegment(jsonText.substring(cursor), baseStyle));
  }

  return segments;
}

List<_LogTextSegment> _shellSegments({
  required String shellText,
  required TextStyle baseStyle,
}) {
  final segments = <_LogTextSegment>[];
  var cursor = 0;

  for (final match in _shellTokenPattern.allMatches(shellText)) {
    if (match.start > cursor) {
      segments.add(
        _LogTextSegment(shellText.substring(cursor, match.start), baseStyle),
      );
    }

    final token = match.group(0)!;
    segments.add(_LogTextSegment(token, _shellTokenStyle(token, baseStyle)));
    cursor = match.end;
  }

  if (cursor < shellText.length) {
    segments.add(_LogTextSegment(shellText.substring(cursor), baseStyle));
  }

  return segments;
}

TextStyle _shellTokenStyle(String token, TextStyle baseStyle) {
  final normalizedLevel = _normalizeLevelToken(token);
  if (normalizedLevel != null) {
    return baseStyle.copyWith(
      color: logLevelColor(normalizedLevel),
      fontWeight: FontWeight.w700,
    );
  }

  if (token.startsWith('[') && token.endsWith(']')) {
    return baseStyle.copyWith(color: shellTimestampColor);
  }

  if (token.startsWith('"') || token.startsWith("'")) {
    return baseStyle.copyWith(color: shellStringColor);
  }

  if (token.startsWith('-')) {
    return baseStyle.copyWith(color: shellOptionColor);
  }

  if (token.startsWith('/')) {
    return baseStyle.copyWith(color: shellPathColor);
  }

  return baseStyle.copyWith(
    color: shellCommandColor,
    fontWeight: FontWeight.w700,
  );
}

String? _normalizeLevelToken(String token) {
  switch (token.toLowerCase()) {
    case 'trace':
      return 'trace';
    case 'debug':
      return 'debug';
    case 'info':
      return 'info';
    case 'warn':
    case 'warning':
      return 'warn';
    case 'error':
      return 'error';
    case 'fatal':
      return 'fatal';
    default:
      return null;
  }
}

TextStyle _jsonTokenStyle(
  String jsonText,
  RegExpMatch match,
  String token,
  TextStyle baseStyle,
) {
  if (token.trim().isEmpty) return baseStyle;

  if ('{}[]:,'.contains(token)) {
    return baseStyle.copyWith(color: jsonLogPunctuationColor);
  }

  if (token.startsWith('"')) {
    final next = _nextNonWhitespace(jsonText, match.end);
    return baseStyle.copyWith(
      color: next == ':' ? jsonLogKeyColor : jsonLogStringColor,
      fontWeight: next == ':' ? FontWeight.w700 : baseStyle.fontWeight,
    );
  }

  if (token == 'true' || token == 'false') {
    return baseStyle.copyWith(color: jsonLogBoolColor);
  }

  if (token == 'null') {
    return baseStyle.copyWith(color: jsonLogNullColor);
  }

  return baseStyle.copyWith(color: jsonLogNumberColor);
}

String? _nextNonWhitespace(String text, int start) {
  for (var i = start; i < text.length; i++) {
    final char = text[i];
    if (char.trim().isNotEmpty) return char;
  }
  return null;
}

List<TextSpan> _applySearchHighlight(
  List<_LogTextSegment> segments,
  String searchQuery,
) {
  if (searchQuery.isEmpty) {
    return [
      for (final segment in segments)
        TextSpan(text: segment.text, style: segment.style),
    ];
  }

  final text = segments.map((segment) => segment.text).join();
  final ranges = _searchRanges(text, searchQuery);
  if (ranges.isEmpty) {
    return [
      for (final segment in segments)
        TextSpan(text: segment.text, style: segment.style),
    ];
  }

  final spans = <TextSpan>[];
  var offset = 0;
  var rangeIndex = 0;

  for (final segment in segments) {
    var localStart = 0;
    final segmentStart = offset;
    final segmentEnd = offset + segment.text.length;

    while (
        rangeIndex < ranges.length && ranges[rangeIndex].end <= segmentStart) {
      rangeIndex++;
    }

    var currentRangeIndex = rangeIndex;
    while (currentRangeIndex < ranges.length) {
      final range = ranges[currentRangeIndex];
      if (range.start >= segmentEnd) break;

      final highlightStart = range.start.clamp(segmentStart, segmentEnd);
      final highlightEnd = range.end.clamp(segmentStart, segmentEnd);
      final localHighlightStart = highlightStart - segmentStart;
      final localHighlightEnd = highlightEnd - segmentStart;

      if (localHighlightStart > localStart) {
        spans.add(
          TextSpan(
            text: segment.text.substring(localStart, localHighlightStart),
            style: segment.style,
          ),
        );
      }

      if (localHighlightEnd > localHighlightStart) {
        spans.add(
          TextSpan(
            text: segment.text.substring(
              localHighlightStart,
              localHighlightEnd,
            ),
            style: segment.style.copyWith(
              color: Colors.black,
              backgroundColor: searchHighlightColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }

      localStart = localHighlightEnd;
      if (range.end <= segmentEnd) currentRangeIndex++;
      if (range.end > segmentEnd) break;
    }

    if (localStart < segment.text.length) {
      spans.add(
        TextSpan(
          text: segment.text.substring(localStart),
          style: segment.style,
        ),
      );
    }

    offset = segmentEnd;
  }

  return spans;
}

List<TextRange> _searchRanges(String text, String searchQuery) {
  final lowerText = text.toLowerCase();
  final lowerQuery = searchQuery.toLowerCase();
  final ranges = <TextRange>[];
  var start = 0;

  while (true) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index < 0) break;

    final end = index + searchQuery.length;
    ranges.add(TextRange(start: index, end: end));
    start = end;
  }

  return ranges;
}

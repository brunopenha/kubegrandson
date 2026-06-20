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

final _jsonTokenPattern = RegExp(
  r'"(?:\\.|[^"\\])*"|true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?|[{}\[\]:,]|\s+',
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
  final segments = _logSegments(
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

List<_LogTextSegment> _logSegments({
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

  final metadata = log.metadata;
  if (metadata == null) {
    segments.add(_LogTextSegment(log.text, baseStyle));
    return segments;
  }

  final jsonText = jsonEncode(metadata);
  segments.addAll(_jsonSegments(jsonText: jsonText, baseStyle: baseStyle));
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

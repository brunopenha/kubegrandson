import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/presentation/providers/log_provider.dart';
import 'package:kubegrandson/presentation/screens/log_viewer/widgets/log_syntax_highlighter.dart';

void main() {
  const baseStyle = TextStyle(
    color: Color(0xffbdbdbd),
    fontSize: 12,
    fontFamily: 'RobotoMono',
  );

  List<TextSpan> flatten(TextSpan span) {
    final spans = <TextSpan>[];

    void visit(TextSpan current) {
      if (current.text != null) spans.add(current);
      final children = current.children;
      if (children == null) return;

      for (final child in children.whereType<TextSpan>()) {
        visit(child);
      }
    }

    visit(span);
    return spans;
  }

  test('colors JSON keys and value types independently', () {
    final span = buildHighlightedLogLine(
      log: LogEntry(
        text: 'started',
        timestamp: DateTime(2026),
        lineNumber: 1,
        metadata: const {
          'level': 'info',
          'status': 200,
          'ok': true,
          'missing': null,
        },
      ),
      showTimestamp: false,
      searchQuery: '',
      baseStyle: baseStyle,
    );

    final spans = flatten(span);
    TextSpan token(String text) =>
        spans.singleWhere((span) => span.text == text);

    expect(token('"level"').style?.color, jsonLogKeyColor);
    expect(token('"info"').style?.color, jsonLogStringColor);
    expect(token('200').style?.color, jsonLogNumberColor);
    expect(token('true').style?.color, jsonLogBoolColor);
    expect(token('null').style?.color, jsonLogNullColor);
  });

  test('keeps search highlight across JSON token boundaries', () {
    final span = buildHighlightedLogLine(
      log: LogEntry(
        text: 'started',
        timestamp: DateTime(2026),
        lineNumber: 1,
        metadata: const {'level': 'info'},
      ),
      showTimestamp: false,
      searchQuery: '":"',
      baseStyle: baseStyle,
    );

    final highlightedText = flatten(span)
        .where((span) => span.style?.backgroundColor == searchHighlightColor)
        .map((span) => span.text)
        .join();

    expect(highlightedText, '":"');
  });

  test('colors formatted JSON details', () {
    final span = buildHighlightedJsonText(
      jsonText: const JsonEncoder.withIndent('  ').convert({
        'level': 'warn',
        'count': 3,
      }),
      searchQuery: '',
      baseStyle: baseStyle,
    );

    final spans = flatten(span);
    TextSpan token(String text) =>
        spans.singleWhere((span) => span.text == text);

    expect(token('"level"').style?.color, jsonLogKeyColor);
    expect(token('"warn"').style?.color, jsonLogStringColor);
    expect(token('3').style?.color, jsonLogNumberColor);
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/presentation/shortcuts/log_navigation_shortcuts.dart';

void main() {
  test('matches legacy and captured shortcut ids', () {
    expect(
      shortcutMatchesKey('arrowUp', LogicalKeyboardKey.arrowUp),
      isTrue,
    );

    final capturedW = shortcutIdForKey(LogicalKeyboardKey.keyW);

    expect(shortcutMatchesKey(capturedW, LogicalKeyboardKey.keyW), isTrue);
    expect(shortcutLabel(capturedW), 'W');
  });
}

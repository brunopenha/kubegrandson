import 'package:flutter/services.dart';

String shortcutIdForKey(LogicalKeyboardKey key) {
  return key.keyId.toString();
}

bool shortcutMatchesKey(String shortcut, LogicalKeyboardKey key) {
  final shortcutKey = keyForShortcut(shortcut);
  return shortcutKey != null && shortcutKey == key;
}

LogicalKeyboardKey? keyForShortcut(String shortcut) {
  switch (shortcut) {
    case 'arrowUp':
      return LogicalKeyboardKey.arrowUp;
    case 'arrowDown':
      return LogicalKeyboardKey.arrowDown;
    case 'keyW':
      return LogicalKeyboardKey.keyW;
    case 'keyS':
      return LogicalKeyboardKey.keyS;
  }

  final keyId = int.tryParse(shortcut);
  if (keyId == null) return null;

  return LogicalKeyboardKey.findKeyByKeyId(keyId);
}

String shortcutLabel(String shortcut) {
  final key = keyForShortcut(shortcut);
  if (key == null) return 'Unassigned';

  if (key == LogicalKeyboardKey.arrowUp) return 'Arrow Up';
  if (key == LogicalKeyboardKey.arrowDown) return 'Arrow Down';
  if (key == LogicalKeyboardKey.arrowLeft) return 'Arrow Left';
  if (key == LogicalKeyboardKey.arrowRight) return 'Arrow Right';
  if (key == LogicalKeyboardKey.space) return 'Space';
  if (key == LogicalKeyboardKey.enter) return 'Enter';
  if (key == LogicalKeyboardKey.escape) return 'Esc';
  if (key == LogicalKeyboardKey.tab) return 'Tab';
  if (key == LogicalKeyboardKey.backspace) return 'Backspace';
  if (key == LogicalKeyboardKey.delete) return 'Delete';

  final label = key.keyLabel.trim();
  if (label.isNotEmpty) return label.toUpperCase();

  return key.debugName ?? 'Key ${key.keyId}';
}

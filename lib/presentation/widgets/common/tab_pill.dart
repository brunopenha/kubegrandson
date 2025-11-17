import 'package:flutter/material.dart';

import '../../providers/theme/app_colors.dart';

enum TabPillOrientation { horizontal, vertical }

abstract class TabPillButtonConfig {
  String get text;
  String? get styleClass;
  IconData? get icon;
}

class TabPill<T extends TabPillButtonConfig> extends StatefulWidget {
  final List<T> buttons;
  final TabPillOrientation orientation;
  final double minButtonWidth;
  final Function(T key, bool selected)? onButtonToggled;
  final Map<T, TabPill>? popups;

  const TabPill({
    super.key,
    required this.buttons,
    this.orientation = TabPillOrientation.horizontal,
    this.minButtonWidth = 70,
    this.onButtonToggled,
    this.popups,
  });

  @override
  State<TabPill<T>> createState() => _TabPillState<T>();
}

class _TabPillState<T extends TabPillButtonConfig> extends State<TabPill<T>> {
  final Map<T, bool> _buttonStates = {};
  OverlayEntry? _currentOverlay;
  T? _currentPopupKey;

  @override
  void initState() {
    super.initState();
    for (var button in widget.buttons) {
      _buttonStates[button] = false;
    }
  }

  void _handleButtonPressed(T button) {
    setState(() {
      _buttonStates[button] = !_buttonStates[button]!;
    });
    widget.onButtonToggled?.call(button, _buttonStates[button]!);
  }

  bool get _isAnySelected {
    return _buttonStates.values.any((selected) => selected);
  }

  void _showPopup(BuildContext context, T button, GlobalKey buttonKey) {
    if (widget.popups == null || !widget.popups!.containsKey(button)) return;

    final popup = widget.popups![button]!;
    final RenderBox renderBox =
    buttonKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _currentPopupKey = button;
    _currentOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent barrier
          Positioned.fill(
            child: GestureDetector(
              onTap: _hidePopup,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Popup content
          Positioned(
            left: position.dx,
            top: position.dy + size.height + 8,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: AppColors.surfaceDark,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: popup,
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  void _hidePopup() {
    _currentOverlay?.remove();
    _currentOverlay = null;
    _currentPopupKey = null;
  }

  Widget _buildButton(T button, int index) {
    final GlobalKey buttonKey = GlobalKey();
    final isFirst = index == 0;
    final isLast = index == widget.buttons.length - 1;
    final isSelected = _buttonStates[button] ?? false;
    final hasPopup = widget.popups?.containsKey(button) ?? false;

    String pillClass;
    if (widget.orientation == TabPillOrientation.horizontal) {
      if (isFirst) {
        pillClass = 'left-pill-horizontal';
      } else if (isLast) {
        pillClass = 'right-pill-horizontal';
      } else {
        pillClass = 'center-pill-horizontal';
      }
    } else {
      if (isFirst) {
        pillClass = 'left-pill-vertical';
      } else if (isLast) {
        pillClass = 'right-pill-vertical';
      } else {
        pillClass = 'center-pill-vertical';
      }
    }

    return MouseRegion(
      key: buttonKey,
      onEnter: hasPopup
          ? (_) => _showPopup(context, button, buttonKey)
          : null,
      onExit: hasPopup ? (_) => _hidePopup() : null,
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleButtonPressed(button),
            borderRadius: _getBorderRadius(isFirst, isLast),
            child: Container(
              constraints: BoxConstraints(
                minWidth: widget.minButtonWidth,
                minHeight: 45,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surfaceDark,
                borderRadius: _getBorderRadius(isFirst, isLast),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Center(
                child: button.icon != null
                    ? Tooltip(
                  message: button.text,
                  child: Icon(
                    button.icon,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                )
                    : Text(
                  button.text,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BorderRadius _getBorderRadius(bool isFirst, bool isLast) {
    if (widget.orientation == TabPillOrientation.horizontal) {
      if (isFirst) {
        return const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        );
      } else if (isLast) {
        return const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        );
      }
    }
    return BorderRadius.zero;
  }

  @override
  Widget build(BuildContext context) {
    final buttons = widget.buttons
        .asMap()
        .entries
        .map((entry) => _buildButton(entry.value, entry.key))
        .toList();

    if (widget.orientation == TabPillOrientation.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: buttons,
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: buttons,
      );
    }
  }

  @override
  void dispose() {
    _hidePopup();
    super.dispose();
  }
}
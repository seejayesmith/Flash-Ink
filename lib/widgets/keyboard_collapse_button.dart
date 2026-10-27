import 'package:flutter/material.dart';

/// A standardized button that collapses the software keyboard across modal
/// bottom sheets, sheets, and dialogs.
///
/// Tapping this button unfocuses the current [FocusNode] across both the local
/// [FocusScope] and [FocusManager.primaryFocus], reliably dismissing the
/// software keyboard.
class KeyboardCollapseButton extends StatelessWidget {
  /// Optional callback invoked after the keyboard is unfocused.
  final VoidCallback? onPressed;

  /// Icon color. Defaults to #8C9191 (muted text/icon color in Flash.Ink theme).
  final Color? color;

  /// Icon size. Defaults to 20.0.
  final double size;

  /// Button padding. Defaults to EdgeInsets.all(8.0).
  final EdgeInsetsGeometry padding;

  /// Explicit widget key. Defaults to [Key('collapse_keyboard_button')].
  final Key? buttonKey;

  /// Custom tooltip message. Defaults to 'Collapse keyboard'.
  final String tooltip;

  const KeyboardCollapseButton({
    super.key,
    this.buttonKey = const Key('collapse_keyboard_button'),
    this.onPressed,
    this.color,
    this.size = 20.0,
    this.padding = const EdgeInsets.all(8.0),
    this.tooltip = 'Collapse keyboard',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      padding: padding,
      constraints: const BoxConstraints(),
      icon: Icon(
        Icons.keyboard_hide_rounded,
        color: color ?? const Color(0xFF8C9191),
        size: size,
      ),
      onPressed: () {
        FocusManager.instance.primaryFocus?.unfocus();
        FocusScope.of(context).unfocus();
        onPressed?.call();
      },
    );
  }
}

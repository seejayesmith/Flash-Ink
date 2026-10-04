import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import '../theme/app_theme.dart';

/// Standardized toggle switch for Flash.Ink reflecting the iOS Cupertino design
/// with a vibrant green active track ([AppTheme.switchActive], #34C759), dark charcoal
/// inactive track ([AppTheme.switchInactive], #39393D), and a smooth white thumb.
class FlashSwitch extends StatelessWidget {
  /// Whether this switch is turned on or off.
  final bool value;

  /// Called when the user toggles the switch.
  final ValueChanged<bool>? onChanged;

  /// Optional active track color override; defaults to [AppTheme.switchActive].
  final Color? activeColor;

  /// Optional inactive track color override; defaults to [AppTheme.switchInactive].
  final Color? trackColor;

  /// Optional drag start behavior.
  final DragStartBehavior dragStartBehavior;

  const FlashSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.trackColor,
    this.dragStartBehavior = DragStartBehavior.start,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeColor: activeColor ?? AppTheme.switchActive,
      trackColor: trackColor ?? AppTheme.switchInactive,
      dragStartBehavior: dragStartBehavior,
    );
  }
}

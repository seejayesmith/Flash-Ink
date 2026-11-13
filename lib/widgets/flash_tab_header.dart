import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A standardized sticky top header component for primary navigation tabs.
///
/// Ensures uniform height, 30pt bold typography, padding, and alignment
/// across client-side screens (Feed, Explore, Appointments, Messages).
class FlashTabHeader extends StatelessWidget {
  /// Optional leading widget displayed to the left of the title (e.g. back button).
  final Widget? leading;

  /// The primary title text (e.g. 'Browse Artists', 'Explore', 'Appointments', 'Messages').
  final String title;

  /// Optional custom title style. Defaults to [AppTypography.tabHeaderTitle].
  final TextStyle? titleStyle;

  /// Optional widget displayed immediately after the title (e.g. location badge, unread counter).
  final Widget? titleAccessory;

  /// Optional action widgets aligned on the trailing side (e.g. profile avatar, icon buttons).
  final List<Widget>? actions;

  /// Optional single trailing action widget.
  final Widget? action;

  /// Padding around the header. Defaults to horizontal [AppSpacing.screenGutter] and vertical [AppSpacing.spaceSm].
  final EdgeInsetsGeometry padding;

  const FlashTabHeader({
    super.key,
    this.leading,
    required this.title,
    this.titleStyle,
    this.titleAccessory,
    this.actions,
    this.action,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.screenGutter,
      vertical: AppSpacing.spaceSm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActions = actions ?? (action != null ? [action!] : null);

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle ?? AppTypography.tabHeaderTitle,
                  ),
                ),
                if (titleAccessory != null) ...[
                  const SizedBox(width: 10),
                  Flexible(child: titleAccessory!),
                ],
              ],
            ),
          ),
          if (effectiveActions != null && effectiveActions.isNotEmpty) ...[
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: effectiveActions,
            ),
          ],
        ],
      ),
    );
  }
}

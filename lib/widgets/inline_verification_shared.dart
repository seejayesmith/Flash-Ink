import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Manages the 30-second resend cooldown timer shared by inline phone and
/// email verification tiles.
class InlineResendCooldownController {
  int _secondsRemaining = 0;
  Timer? _timer;

  int get secondsRemaining => _secondsRemaining;
  bool get isActive => _secondsRemaining > 0;

  void start(VoidCallback onTick, {int durationSeconds = 30}) {
    _timer?.cancel();
    _secondsRemaining = durationSeconds;
    onTick();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _secondsRemaining = 0;
      } else {
        _secondsRemaining -= 1;
      }
      onTick();
    });
  }

  void cancel({bool resetSeconds = false}) {
    _timer?.cancel();
    if (resetSeconds) {
      _secondsRemaining = 0;
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Compact pill badge used to display `VERIFIED` or `PENDING` status in
/// inline account verification tiles.
class InlineVerificationStatusBadge extends StatelessWidget {
  final Key badgeKey;
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final EdgeInsetsGeometry padding;
  final double borderWidth;
  final double fontSize;
  final FontWeight fontWeight;
  final double? letterSpacing;

  const InlineVerificationStatusBadge({
    super.key,
    required this.badgeKey,
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.borderWidth = 1.0,
    this.fontSize = 9,
    this.fontWeight = FontWeight.w800,
    this.letterSpacing = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: badgeKey,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: textColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }
}

/// Compact pill button used for trailing tile actions (`Add`, `Change`,
/// `Verify`, `Close`).
class InlineVerificationActionPill extends StatelessWidget {
  final Key buttonKey;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  const InlineVerificationActionPill({
    super.key,
    required this.buttonKey,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: highlighted
              ? AppTheme.gold.withAlpha(30)
              : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlighted
                ? AppTheme.gold.withAlpha(120)
                : Colors.white.withAlpha(30),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: highlighted ? AppTheme.gold : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Inline validation/error message text shared across verification steps.
class InlineVerificationErrorText extends StatelessWidget {
  final Key errorKey;
  final String message;
  final Color color;

  const InlineVerificationErrorText({
    super.key,
    required this.errorKey,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      key: errorKey,
      style: GoogleFonts.plusJakartaSans(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Builds the dark onyx [InputDecoration] used by inline phone, OTP, and
/// email text fields.
InputDecoration buildInlineVerificationInputDecoration({
  required String hintText,
  required TextStyle hintStyle,
  required double borderRadius,
  required Color borderColor,
  required EdgeInsetsGeometry contentPadding,
  bool includeBaseBorder = false,
  String? counterText,
  Widget? prefixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    borderSide: BorderSide(color: borderColor),
  );
  return InputDecoration(
    counterText: counterText,
    hintText: hintText,
    hintStyle: hintStyle,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: AppTheme.onyxSurface,
    contentPadding: contentPadding,
    border: includeBaseBorder ? border : null,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
    ),
  );
}

/// Gold elevated submit button with an inline loading spinner.
class InlineVerificationSubmitButton extends StatelessWidget {
  final Key buttonKey;
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const InlineVerificationSubmitButton({
    super.key,
    required this.buttonKey,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: buttonKey,
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.onyxBackground,
        disabledBackgroundColor: AppTheme.gold.withAlpha(110),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.onyxBackground,
              ),
            )
          : Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
    );
  }
}

/// Footer row pairing a secondary edit action (`Change Number` / `Change Email`)
/// with a cooldown-aware resend button (`Resend Code` / `Resend Link`).
class InlineVerificationFooterActions extends StatelessWidget {
  final Key editKey;
  final String editLabel;
  final Color editColor;
  final FontWeight? editFontWeight;
  final VoidCallback? onEdit;
  final Key resendKey;
  final String resendLabel;
  final int cooldownSeconds;
  final Color disabledCooldownColor;
  final VoidCallback? onResend;

  const InlineVerificationFooterActions({
    super.key,
    required this.editKey,
    required this.editLabel,
    required this.editColor,
    this.editFontWeight,
    required this.onEdit,
    required this.resendKey,
    required this.resendLabel,
    required this.cooldownSeconds,
    required this.disabledCooldownColor,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          key: editKey,
          onPressed: onEdit,
          child: Text(
            editLabel,
            style: GoogleFonts.plusJakartaSans(
              color: editColor,
              fontSize: 12,
              fontWeight: editFontWeight,
            ),
          ),
        ),
        TextButton(
          key: resendKey,
          onPressed: onResend,
          child: Text(
            cooldownSeconds > 0
                ? 'Resend in ${cooldownSeconds}s'
                : resendLabel,
            style: GoogleFonts.plusJakartaSans(
              color: cooldownSeconds > 0
                  ? disabledCooldownColor
                  : AppTheme.gold,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

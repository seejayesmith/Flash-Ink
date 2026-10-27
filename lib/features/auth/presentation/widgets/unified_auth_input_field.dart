import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';

/// Represents the detected identifier type in the unified authentication field.
enum AuthInputType {
  phone,
  email,
  unknown,
}

/// Classifies the raw user input into [AuthInputType.email], [AuthInputType.phone],
/// or [AuthInputType.unknown].
///
/// Classification rules:
/// 1. If the input contains `@` or any alphabetic character (`[a-zA-Z]`), it is
///    unambiguously classified as [AuthInputType.email] — even if the string begins
///    with a phone number or digits (e.g. `5551234567@gmail.com` or `2024artist@studio.com`).
/// 2. If the input consists solely of digits and standard phone punctuation
///    (`+`, `-`, `(`, `)`, `.`, spaces), it is classified as [AuthInputType.phone].
/// 3. Otherwise, returns [AuthInputType.unknown].
AuthInputType detectAuthInputType(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return AuthInputType.unknown;

  if (trimmed.contains('@') || RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
    return AuthInputType.email;
  }

  if (RegExp(r'^\+?[0-9\s\-\(\)\.]+$').hasMatch(trimmed) &&
      RegExp(r'\d').hasMatch(trimmed)) {
    return AuthInputType.phone;
  }

  return AuthInputType.unknown;
}

/// Validates the unified email or phone input string.
String? validateUnifiedAuthInput(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Please enter your email or phone number';
  }

  final type = detectAuthInputType(trimmed);
  switch (type) {
    case AuthInputType.email:
      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!emailRegex.hasMatch(trimmed)) {
        return 'Please enter a valid email address';
      }
      return null;
    case AuthInputType.phone:
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 10) {
        return 'Please enter a valid 10-digit phone number';
      }
      return null;
    case AuthInputType.unknown:
      return 'Please enter a valid email or 10-digit phone number';
  }
}

/// A unified input field that accepts either an email address or a mobile phone number
/// without destructive phone masking that would corrupt numeric-prefixed emails.
class UnifiedAuthInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;

  const UnifiedAuthInputField({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
  });

  @override
  State<UnifiedAuthInputField> createState() => _UnifiedAuthInputFieldState();
}

class _UnifiedAuthInputFieldState extends State<UnifiedAuthInputField> {
  late AuthInputType _detectedType;

  @override
  void initState() {
    super.initState();
    _detectedType = detectAuthInputType(widget.controller.text);
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant UnifiedAuthInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
      _detectedType = detectAuthInputType(widget.controller.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  void _handleControllerChange() {
    final nextType = detectAuthInputType(widget.controller.text);
    if (nextType != _detectedType && mounted) {
      setState(() {
        _detectedType = nextType;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email or Phone Number',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        AppGaps.gapXs,
        TextFormField(
          key: const Key('unified_auth_input_field'),
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          // Always use emailAddress keyboard so letters, digits, '@' and '.' remain accessible
          // even when an email starts with a phone number or digits.
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 15,
          ),
          validator: widget.validator ?? validateUnifiedAuthInput,
          onChanged: (value) {
            _handleControllerChange();
            widget.onChanged?.call(value);
          },
          onFieldSubmitted: widget.onFieldSubmitted,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: InputDecoration(
            hintText: 'Email or mobile number',
            hintStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF4D5252),
              fontSize: 15,
            ),
            suffixIcon: widget.controller.text.isNotEmpty && widget.enabled
                ? IconButton(
                    key: const Key('unified_auth_clear_button'),
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF919696),
                      size: 18,
                    ),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged?.call('');
                      setState(() {
                        _detectedType = AuthInputType.unknown;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: AppTheme.onyxBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spaceMd,
              vertical: AppSpacing.spaceMd,
            ),
            border: OutlineInputBorder(
              borderRadius: AppBorderRadius.md,
              borderSide: const BorderSide(color: Color(0xFF262929)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.md,
              borderSide: const BorderSide(color: Color(0xFF262929)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.md,
              borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.md,
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.md,
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

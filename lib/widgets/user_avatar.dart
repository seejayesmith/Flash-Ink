import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'flash_image.dart';

/// Circular user avatar that renders a profile photo when [imageUrl] is valid,
/// and falls back cleanly to a non-`@` initial or person icon when unavailable.
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final String fallbackInitial;
  final double? initialFontSize;
  final bool usePersonIconFallback;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.displayName = '',
    this.radius = 20,
    this.backgroundColor = const Color(0xFF262929),
    this.foregroundColor = const Color(0xFFEEC200),
    this.fallbackInitial = '?',
    this.initialFontSize,
    this.usePersonIconFallback = false,
  });

  /// Returns `true` when [url] is a non-empty, non-local image path or URL.
  static bool isValidUrl(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    return trimmed.isNotEmpty && !trimmed.startsWith('local://');
  }

  /// Extracts a clean, uppercase initial from [name], stripping any leading `@`.
  static String resolveInitial(String? name, {String fallback = '?'}) {
    if (name != null) {
      final cleaned = name.trim().replaceFirst(RegExp(r'^@+'), '').trim();
      if (cleaned.isNotEmpty) {
        return cleaned[0].toUpperCase();
      }
    }
    return fallback;
  }

  Widget _buildFallback() {
    if (usePersonIconFallback) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        color: backgroundColor,
        alignment: Alignment.center,
        child: Icon(
          Icons.person,
          color: foregroundColor,
          size: radius * 1.05,
        ),
      );
    }

    final initial = resolveInitial(displayName, fallback: fallbackInitial);
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: backgroundColor,
      alignment: Alignment.center,
      child: Text(
        initial,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: foregroundColor,
          fontWeight: FontWeight.bold,
          fontSize: initialFontSize ?? (radius * 0.85),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl?.trim();
    final hasValidImage = isValidUrl(trimmedUrl);

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: hasValidImage
            ? FlashImage(
                urlOrPath: trimmedUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorWidget: _buildFallback(),
              )
            : _buildFallback(),
      ),
    );
  }
}

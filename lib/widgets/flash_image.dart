import 'package:flutter/material.dart';

/// Renders either a bundled asset image or a remote network image
/// with uniform loading and error fallback behaviors.
class FlashImage extends StatelessWidget {
  final String urlOrPath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? color;
  final BlendMode? colorBlendMode;

  const FlashImage({
    super.key,
    required this.urlOrPath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.color,
    this.colorBlendMode,
  });

  bool get _isNetwork =>
      urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (urlOrPath.isEmpty) {
      return _buildErrorPlaceholder();
    }

    final targetCacheWidth = width != null ? (width! * 2.5).round().clamp(200, 1200) : 800;

    if (_isNetwork) {
      return Image.network(
        urlOrPath,
        fit: fit,
        width: width,
        height: height,
        cacheWidth: targetCacheWidth,
        color: color,
        colorBlendMode: colorBlendMode,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ?? _buildLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? _buildErrorPlaceholder();
        },
      );
    }

    return Image.asset(
      urlOrPath,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: targetCacheWidth,
      color: color,
      colorBlendMode: colorBlendMode,
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? _buildErrorPlaceholder();
      },
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: const Color(0xFF262929),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4D5252)),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2D2D),
            Color(0xFF1E2020),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.draw_outlined,
          color: Color(0xFF4D5252),
          size: 26,
        ),
      ),
    );
  }
}

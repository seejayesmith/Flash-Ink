import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// An interactive favorite heart button with a micro-scale bounce pulse animation.
class AnimatedFavoriteButton extends StatefulWidget {
  final bool isFavorited;
  final VoidCallback? onToggle;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color inactiveBorderColor;
  final Color activeColor;

  const AnimatedFavoriteButton({
    super.key,
    required this.isFavorited,
    this.onToggle,
    this.size = 42.0,
    this.iconSize = 20.0,
    this.backgroundColor = const Color(0xFF1E2020),
    this.inactiveBorderColor = const Color(0xFF4D5252),
    this.activeColor = AppTheme.favoriteActive,
  });

  @override
  State<AnimatedFavoriteButton> createState() => _AnimatedFavoriteButtonState();
}

class _AnimatedFavoriteButtonState extends State<AnimatedFavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant AnimatedFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isFavorited && widget.isFavorited) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.backgroundColor,
            border: Border.all(
              color: widget.isFavorited
                  ? widget.activeColor
                  : widget.inactiveBorderColor,
              width: 1.5,
            ),
          ),
          child: Icon(
            widget.isFavorited ? Icons.favorite : Icons.favorite_border,
            color: widget.isFavorited
                ? widget.activeColor
                : const Color(0xFFF9FAFA),
            size: widget.iconSize,
          ),
        ),
      ),
    );
  }
}

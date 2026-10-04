import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pixel-perfect vector painter for the official 4-color Google "G" logo.
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Normalization scale from 48x48 viewport to target widget size
    final double scale = size.width / 48.0;
    canvas.scale(scale, scale);

    final Paint paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    // Red (Top arc)
    paint.color = const Color(0xFFEA4335);
    final Path redPath = Path()
      ..moveTo(24, 9.5)
      ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
      ..lineTo(40.06, 6.25)
      ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
      ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
      ..lineTo(10.54, 19.41)
      ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
      ..close();
    canvas.drawPath(redPath, paint);

    // Blue (Horizontal bar and right quadrant)
    paint.color = const Color(0xFF4285F4);
    final Path bluePath = Path()
      ..moveTo(46.98, 24.55)
      ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20)
      ..lineTo(24, 20)
      ..lineTo(24, 29.02)
      ..lineTo(36.94, 29.02)
      ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
      ..lineTo(39.89, 42.2)
      ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
      ..close();
    canvas.drawPath(bluePath, paint);

    // Yellow (Bottom-left curve)
    paint.color = const Color(0xFFFBBC05);
    final Path yellowPath = Path()
      ..moveTo(10.53, 28.59)
      ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24)
      ..cubicTo(9.77, 22.4, 10.05, 20.86, 10.53, 19.41)
      ..lineTo(2.56, 13.22)
      ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
      ..cubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78)
      ..lineTo(10.53, 28.59)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // Green (Bottom arc)
    paint.color = const Color(0xFF34A853);
    final Path greenPath = Path()
      ..moveTo(24, 48)
      ..cubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.19)
      ..lineTo(32.16, 36.19)
      ..cubicTo(30.01, 37.64, 27.24, 38.5, 24, 38.5)
      ..cubicTo(17.74, 38.5, 12.43, 34.28, 10.53, 28.59)
      ..lineTo(2.56, 34.78)
      ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
      ..close();
    canvas.drawPath(greenPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A standalone Google Logo widget rendered at the specified size.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

/// Standard circular icon button base for OAuth providers.
class CircularSocialIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final Color backgroundColor;
  final Color borderColor;
  final double size;
  final bool isLoading;
  final Color loadingColor;
  final String semanticsLabel;
  final String tooltip;
  final Key? buttonKey;

  const CircularSocialIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.backgroundColor,
    this.borderColor = Colors.transparent,
    this.size = 52.0,
    this.isLoading = false,
    this.loadingColor = Colors.white,
    required this.semanticsLabel,
    required this.tooltip,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null || isLoading;

    return Semantics(
      button: true,
      label: semanticsLabel,
      enabled: !disabled,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: size,
          height: size,
          child: Material(
            key: buttonKey,
            color: backgroundColor,
            shape: CircleBorder(
              side: BorderSide(
                color: borderColor,
                width: 1.0,
              ),
            ),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: disabled ? null : onPressed,
              customBorder: const CircleBorder(),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(loadingColor),
                        ),
                      )
                    : icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Industry-standard circular Google sign-in button.
class CircularGoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final double size;

  const CircularGoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.size = 52.0,
  });

  @override
  Widget build(BuildContext context) {
    return CircularSocialIconButton(
      buttonKey: const Key('google_sign_in_button'),
      onPressed: onPressed,
      size: size,
      isLoading: isLoading,
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFD6DADA),
      loadingColor: const Color(0xFF4285F4),
      semanticsLabel: 'Sign in with Google',
      tooltip: 'Continue with Google',
      icon: const GoogleLogo(size: 22),
    );
  }
}

/// Industry-standard circular Apple sign-in button.
class CircularAppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final double size;

  const CircularAppleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.size = 52.0,
  });

  @override
  Widget build(BuildContext context) {
    return CircularSocialIconButton(
      buttonKey: const Key('apple_sign_in_button'),
      onPressed: onPressed,
      size: size,
      isLoading: isLoading,
      backgroundColor: const Color(0xFF000000),
      borderColor: const Color(0xFF383C3C),
      loadingColor: Colors.white,
      semanticsLabel: 'Sign in with Apple',
      tooltip: 'Continue with Apple',
      icon: const Icon(
        Icons.apple,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

/// Visual divider separating standard form/auth and social sign-in.
class SocialAuthDivider extends StatelessWidget {
  final String label;

  const SocialAuthDivider({
    super.key,
    this.label = 'OR CONTINUE WITH',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFF2B2E2E), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: const Color(0xFF6C7272),
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFF2B2E2E), thickness: 1)),
      ],
    );
  }
}

/// Centered row containing both circular Google and Apple sign-in buttons.
class SocialAuthRow extends StatelessWidget {
  final VoidCallback? onGooglePressed;
  final VoidCallback? onApplePressed;
  final bool isGoogleLoading;
  final bool isAppleLoading;
  final bool isLoading;
  final double gap;
  final double buttonSize;

  const SocialAuthRow({
    super.key,
    required this.onGooglePressed,
    required this.onApplePressed,
    this.isGoogleLoading = false,
    this.isAppleLoading = false,
    this.isLoading = false,
    this.gap = 20.0,
    this.buttonSize = 52.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularGoogleSignInButton(
          onPressed: isLoading ? null : onGooglePressed,
          isLoading: isGoogleLoading,
          size: buttonSize,
        ),
        SizedBox(width: gap),
        CircularAppleSignInButton(
          onPressed: isLoading ? null : onApplePressed,
          isLoading: isAppleLoading,
          size: buttonSize,
        ),
      ],
    );
  }
}

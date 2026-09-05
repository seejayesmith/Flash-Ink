import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flash_ink/theme/app_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('AppTypography Foundation Tests', () {
    test('Title token matches 40/50 Bold', () {
      final style = AppTypography.title;
      expect(style.fontSize, 40);
      expect(style.height, 50 / 40);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('H1 token matches 36/50 Bold', () {
      final style = AppTypography.h1;
      expect(style.fontSize, 36);
      expect(style.height, 50 / 36);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('H2 token matches 32/50 Regular', () {
      final style = AppTypography.h2;
      expect(style.fontSize, 32);
      expect(style.height, 50 / 32);
      expect(style.fontWeight, FontWeight.normal);
    });

    test('H3 token matches 28/50 Regular', () {
      final style = AppTypography.h3;
      expect(style.fontSize, 28);
      expect(style.height, 50 / 28);
      expect(style.fontWeight, FontWeight.normal);
    });

    test('H4 token matches 24/50 Regular', () {
      final style = AppTypography.h4;
      expect(style.fontSize, 24);
      expect(style.height, 50 / 24);
      expect(style.fontWeight, FontWeight.normal);
    });

    test('H5 token matches 20/50 Regular', () {
      final style = AppTypography.h5;
      expect(style.fontSize, 20);
      expect(style.height, 50 / 20);
      expect(style.fontWeight, FontWeight.normal);
    });

    test('Body Large token matches 18/24 Regular', () {
      final style = AppTypography.bodyLarge;
      expect(style.fontSize, 18);
      expect(style.height, 24 / 18);
      expect(style.fontWeight, FontWeight.normal);
    });

    test('Body Large Bold token matches 18/50 Bold', () {
      final style = AppTypography.bodyLargeBold;
      expect(style.fontSize, 18);
      expect(style.height, 50 / 18);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('Body Med token matches 16/24 Regular', () {
      final style = AppTypography.bodyMed;
      expect(style.fontSize, 16);
      expect(style.height, 24 / 16);
      expect(style.fontWeight, FontWeight.normal);
    });

    test('Body Med Bold token matches 16/50 Bold', () {
      final style = AppTypography.bodyMedBold;
      expect(style.fontSize, 16);
      expect(style.height, 50 / 16);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('Body Small token matches 12/14 Regular', () {
      final style = AppTypography.bodySmall;
      expect(style.fontSize, 12);
      expect(style.height, 14 / 12);
      expect(style.fontWeight, FontWeight.normal);
    });

    test('Body Small Bold token matches 12/16 Bold', () {
      final style = AppTypography.bodySmallBold;
      expect(style.fontSize, 12);
      expect(style.height, 16 / 12);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('Label token matches 10/12 Regular', () {
      final style = AppTypography.label;
      expect(style.fontSize, 10);
      expect(style.height, 12 / 10);
      expect(style.fontWeight, FontWeight.normal);
    });

    test('Label Bold token matches 10/50 Bold', () {
      final style = AppTypography.labelBold;
      expect(style.fontSize, 10);
      expect(style.height, 50 / 10);
      expect(style.fontWeight, FontWeight.bold);
    });

    test('Logo token matches 32/50', () {
      final style = AppTypography.logo;
      expect(style.fontSize, 32);
      expect(style.height, 50 / 32);
    });

    test('textTheme produces valid TextTheme with Plus Jakarta Sans', () {
      final theme = AppTypography.textTheme();
      expect(theme.displayLarge?.fontSize, 40);
      expect(theme.displayMedium?.fontSize, 36);
      expect(theme.displaySmall?.fontSize, 32);
      expect(theme.headlineLarge?.fontSize, 32);
      expect(theme.headlineMedium?.fontSize, 28);
      expect(theme.headlineSmall?.fontSize, 24);
      expect(theme.bodyLarge?.fontSize, 18);
      expect(theme.bodyMedium?.fontSize, 16);
      expect(theme.bodySmall?.fontSize, 12);
      expect(theme.labelMedium?.fontSize, 10);
    });
  });
}

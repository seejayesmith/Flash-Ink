import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flash_ink/widgets/profile_avatar_placeholder.dart';

final samplePngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  group('ProfileAvatarPlaceholder Widget Tests', () {
    testWidgets('renders empty state with dashed ring, silhouette, and plus badge', (tester) async {
      bool tappedAvatar = false;
      bool tappedBadge = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProfileAvatarPlaceholder(
                imageBytes: null,
                onTap: () => tappedAvatar = true,
                onBadgeTap: () => tappedBadge = true,
              ),
            ),
          ),
        ),
      );

      // Verify CustomPaint with DashedCirclePainter is present
      final dashedCircleFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DashedCirclePainter,
      );
      expect(dashedCircleFinder, findsOneWidget);

      // Verify camera icon placeholder is present
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);

      // Verify Plus badge is present
      expect(find.byIcon(Icons.add), findsOneWidget);

      // Tap badge
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(tappedBadge, isTrue);

      // Tap avatar area
      await tester.tap(find.byIcon(Icons.camera_alt_outlined));
      await tester.pump();
      expect(tappedAvatar, isTrue);
    });

    testWidgets('renders selected state with photo, solid border, and edit badge', (tester) async {
      bool tappedAvatar = false;
      bool tappedBadge = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProfileAvatarPlaceholder(
                imageBytes: samplePngBytes,
                onTap: () => tappedAvatar = true,
                onBadgeTap: () => tappedBadge = true,
              ),
            ),
          ),
        ),
      );

      // Verify dashed ring is NOT rendered
      final dashedCircleFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DashedCirclePainter,
      );
      expect(dashedCircleFinder, findsNothing);

      // Verify Image.memory is rendered
      expect(find.byType(Image), findsOneWidget);

      // Verify Edit badge is rendered
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      // Tap badge
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();
      expect(tappedBadge, isTrue);

      // Tap image
      await tester.tap(find.byType(Image));
      await tester.pump();
      expect(tappedAvatar, isTrue);
    });
  });
}

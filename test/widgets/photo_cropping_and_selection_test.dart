import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

import 'package:flash_ink/widgets/photo_crop_screen.dart';
import 'package:flash_ink/widgets/photo_source_bottom_sheet.dart';
import 'package:flash_ink/screens/client_account_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_account_screen.dart';
import 'package:flash_ink/screens/artist_onboarding/artist_flash_upload_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

final samplePngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class MockTestUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;
  @override
  final String? photoURL;

  MockTestUser({
    this.uid = 'test_user_id',
    this.email = 'client@flash.ink',
    this.displayName = 'Flash Client',
    this.photoURL,
  });

  @override
  Future<void> updatePhotoURL(String? photoUri) async {}
}

class FakeTestAuthService extends AuthService {
  final MockTestUser? testUser;
  FakeTestAuthService({this.testUser});

  @override
  User? get currentUser => testUser ?? MockTestUser();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('PhotoCropScreen Widget Tests', () {
    testWidgets('Renders PhotoCropScreen with controls, titles, and action button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoCropScreen(
            imageBytes: samplePngBytes,
            title: 'TEST CROP',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TEST CROP'), findsOneWidget);
      expect(find.byKey(const Key('photo_crop_cancel_button')), findsOneWidget);
      expect(find.byKey(const Key('photo_crop_reset_button')), findsNothing);
      expect(find.byKey(const Key('photo_crop_rotate_button')), findsNothing);
      expect(find.byKey(const Key('confirm_crop_button')), findsOneWidget);
      expect(find.text('Apply & Use Photo'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('Configures InteractiveViewer with auto-fill constraints and cover sizing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoCropScreen(
            imageBytes: samplePngBytes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final viewerFinder = find.byType(InteractiveViewer);
      expect(viewerFinder, findsOneWidget);
      final viewer = tester.widget<InteractiveViewer>(viewerFinder);

      expect(viewer.constrained, isFalse);
      expect(viewer.boundaryMargin, equals(EdgeInsets.zero));
      expect(viewer.minScale, equals(1.0));
      expect(viewer.maxScale, equals(4.0));

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(image.fit, equals(BoxFit.cover));
    });

    testWidgets('Tapping cancel button pops navigator with null', (tester) async {
      Uint8List? returnedBytes = samplePngBytes;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push<Uint8List?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoCropScreen(imageBytes: samplePngBytes),
                  ),
                );
                returnedBytes = result;
              },
              child: const Text('Open Cropper'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Cropper'));
      await tester.pumpAndSettle();

      final cancelBtn = find.byKey(const Key('photo_crop_cancel_button'));
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(returnedBytes, isNull);
    });

    testWidgets('Photo fills circle crop area without empty margins', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoCropScreen(
            imageBytes: samplePngBytes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clipOvalFinder = find.byType(ClipOval);
      expect(clipOvalFinder, findsOneWidget);

      final imageSizedBox = find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.byType(SizedBox),
      );
      expect(imageSizedBox, findsOneWidget);
      final renderedSizedBox = tester.widget<SizedBox>(imageSizedBox);
      expect(renderedSizedBox.width, isNotNull);
      expect(renderedSizedBox.height, isNotNull);
      expect(renderedSizedBox.width!, greaterThanOrEqualTo(240.0));
      expect(renderedSizedBox.height!, greaterThanOrEqualTo(240.0));
    });

    testWidgets('Tapping APPLY & USE PHOTO pops navigator with bytes', (tester) async {
      Uint8List? returnedBytes;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push<Uint8List?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoCropScreen(imageBytes: samplePngBytes),
                  ),
                );
                returnedBytes = result;
              },
              child: const Text('Open Cropper'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Cropper'));
      await tester.pumpAndSettle();

      final applyBtn = find.byKey(const Key('confirm_crop_button'));
      expect(applyBtn, findsOneWidget);
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      expect(returnedBytes, isNotNull);
    });
  });

  group('PhotoSourceBottomSheet Widget Tests', () {
    testWidgets('Renders modern card options: Camera, Gallery, Sample Flash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoSourceBottomSheet(
              hasExistingPhoto: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_source_sheet_title')), findsOneWidget);
      expect(find.byKey(const Key('photo_source_camera')), findsOneWidget);
      expect(find.byKey(const Key('photo_source_gallery')), findsOneWidget);
      expect(find.byKey(const Key('photo_source_sample')), findsOneWidget);
      expect(find.byKey(const Key('photo_source_remove')), findsNothing);
    });

    testWidgets('Renders Remove Photo option when hasExistingPhoto is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoSourceBottomSheet(
              hasExistingPhoto: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_source_remove')), findsOneWidget);
      expect(find.text('Remove Photo'), findsOneWidget);
    });

    testWidgets('Tapping Remove Photo returns ProfilePhotoResult.removed()', (tester) async {
      ProfilePhotoResult? sheetResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await PhotoSourceBottomSheet.show(
                  context: context,
                  hasExistingPhoto: true,
                );
                sheetResult = result;
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final removeOption = find.byKey(const Key('photo_source_remove'));
      expect(removeOption, findsOneWidget);
      await tester.tap(removeOption);
      await tester.pumpAndSettle();

      expect(sheetResult, isNotNull);
      expect(sheetResult!.isRemoved, isTrue);
      expect(sheetResult!.croppedBytes, isNull);
    });

    testWidgets('Opens CupertinoActionSheet on iOS platform', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => PhotoSourceBottomSheet.show(
                context: context,
                hasExistingPhoto: true,
              ),
              child: const Text('Open iOS Sheet'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open iOS Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.text('Take a Picture'), findsOneWidget);
      expect(find.text('Upload a Photo'), findsOneWidget);
      expect(find.text('Remove Photo'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('Account Screens Avatar Fallback and Editing Tests', () {
    testWidgets('ClientAccountScreen renders gold silhouette icon when photoURL is null', (tester) async {
      final fakeAuth = FakeTestAuthService(
        testUser: MockTestUser(photoURL: null),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAccountScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      // Check silhouette person outline icon
      expect(find.byIcon(Icons.person_outline), findsWidgets);
      // Check avatar edit camera badge is present
      expect(find.byKey(const Key('client_account_avatar_edit')), findsOneWidget);
    });

    testWidgets('ArtistAccountScreen renders gold silhouette icon when photoURL is null', (tester) async {
      final fakeAuth = FakeTestAuthService(
        testUser: MockTestUser(photoURL: null),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistAccountScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      // Check silhouette person outline icon
      expect(find.byIcon(Icons.person_outline), findsWidgets);
      // Check avatar edit camera badge is present
      expect(find.byKey(const Key('artist_account_avatar_edit')), findsOneWidget);
    });

    testWidgets('Tapping avatar edit badge on ClientAccountScreen opens PhotoSourceBottomSheet', (tester) async {
      final fakeAuth = FakeTestAuthService(
        testUser: MockTestUser(photoURL: null),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAccountScreen(authService: fakeAuth),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('client_account_avatar_edit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_source_sheet_title')), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Library'), findsOneWidget);
    });
  });

  group('PhotoCropScreen Rectangular Flash Artwork Tests', () {
    testWidgets('Renders rectangular cropper with aspect ratio chips and ClipRRect', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoCropScreen(
            imageBytes: samplePngBytes,
            title: 'CROP & RESIZE FLASH',
            cropShape: CropShape.rectangle,
            subtitle: 'Pinch to zoom • Drag to frame your flash artwork',
            ctaText: 'Apply & Use Flash',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CROP & RESIZE FLASH'), findsOneWidget);
      expect(find.text('Pinch to zoom • Drag to frame your flash artwork'), findsOneWidget);
      expect(find.text('Apply & Use Flash'), findsOneWidget);

      // Check aspect ratio selector chips
      expect(find.byKey(const Key('aspect_ratio_4_3')), findsOneWidget);
      expect(find.byKey(const Key('aspect_ratio_1_1')), findsOneWidget);
      expect(find.byKey(const Key('aspect_ratio_4_5')), findsOneWidget);
      expect(find.byKey(const Key('aspect_ratio_3_2')), findsOneWidget);

      // Rectangular clipping uses ClipRRect instead of ClipOval
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(ClipOval), findsNothing);

      // InteractiveViewer is configured for zooming and pan framing
      final viewerFinder = find.byType(InteractiveViewer);
      expect(viewerFinder, findsOneWidget);
      final viewer = tester.widget<InteractiveViewer>(viewerFinder);
      expect(viewer.constrained, isFalse);
      expect(viewer.minScale, equals(1.0));
      expect(viewer.maxScale, equals(4.0));
      expect(viewer.boundaryMargin, equals(EdgeInsets.zero));
    });

    testWidgets('Tapping aspect ratio chips switches active framing ratio', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoCropScreen(
            imageBytes: samplePngBytes,
            title: 'CROP & RESIZE FLASH',
            cropShape: CropShape.rectangle,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 1:1 Square
      await tester.tap(find.byKey(const Key('aspect_ratio_1_1')));
      await tester.pumpAndSettle();

      // Tap 4:5 Portrait
      await tester.tap(find.byKey(const Key('aspect_ratio_4_5')));
      await tester.pumpAndSettle();

      // Tap 3:2 Wide
      await tester.tap(find.byKey(const Key('aspect_ratio_3_2')));
      await tester.pumpAndSettle();

      // Tap back to 4:3 Card
      await tester.tap(find.byKey(const Key('aspect_ratio_4_3')));
      await tester.pumpAndSettle();

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('Tapping APPLY & USE FLASH in rectangular mode pops navigator with bytes', (tester) async {
      Uint8List? returnedBytes;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push<Uint8List?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoCropScreen(
                      imageBytes: samplePngBytes,
                      cropShape: CropShape.rectangle,
                      title: 'CROP & RESIZE FLASH',
                      ctaText: 'Apply & Use Flash',
                    ),
                  ),
                );
                returnedBytes = result;
              },
              child: const Text('Open Flash Cropper'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Flash Cropper'));
      await tester.pumpAndSettle();

      final applyBtn = find.byKey(const Key('confirm_crop_button'));
      expect(applyBtn, findsOneWidget);
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      expect(returnedBytes, isNotNull);
    });
  });

  group('ArtistFlashUploadScreen Cropping & Framing Tests', () {
    testWidgets('Renders Resize & Crop button and edit button on flash preview', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistFlashUploadScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
            minDeposit: 100,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open upload source picker
      await tester.tap(find.byKey(const Key('upload_flash_trigger')));
      await tester.pumpAndSettle();

      // Load sample flash
      await tester.tap(find.text('Use Sample Flash: Traditional Panther'));
      await tester.pumpAndSettle();

      // Details card is now visible
      expect(find.text('Upload Flash: Item Details'), findsOneWidget);

      // Verify Resize & Crop button is present on the preview card
      expect(find.byKey(const Key('crop_flash_image_button')), findsOneWidget);
      expect(find.text('Resize & Crop'), findsOneWidget);

      // Verify edit pencil button is present
      expect(find.byKey(const Key('edit_flash_image_button')), findsOneWidget);
    });

    testWidgets('Tapping Resize & Crop button opens PhotoCropScreen in rectangular mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistFlashUploadScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
            minDeposit: 100,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open upload source picker & load sample flash
      await tester.tap(find.byKey(const Key('upload_flash_trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use Sample Flash: Traditional Panther'));
      await tester.pumpAndSettle();

      // Tap Resize & Crop button
      await tester.tap(find.byKey(const Key('crop_flash_image_button')));
      await tester.pumpAndSettle();

      // Verifies PhotoCropScreen opened with rectangular controls
      expect(find.text('CROP & RESIZE FLASH'), findsOneWidget);
      expect(find.text('Apply & Use Flash'), findsOneWidget);
      expect(find.byKey(const Key('aspect_ratio_4_3')), findsOneWidget);
      expect(find.byKey(const Key('aspect_ratio_1_1')), findsOneWidget);

      // Confirm crop to return to item details
      await tester.tap(find.byKey(const Key('confirm_crop_button')));
      await tester.pumpAndSettle();

      expect(find.text('Upload Flash: Item Details'), findsOneWidget);
    });

    testWidgets('Tapping edit pencil button opens options sheet with Resize & Crop Framing option', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ArtistFlashUploadScreen(
            artistName: 'OddMaree',
            instagramHandle: '@OddMaree',
            minDeposit: 100,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open upload source picker & load sample flash
      await tester.tap(find.byKey(const Key('upload_flash_trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use Sample Flash: Traditional Panther'));
      await tester.pumpAndSettle();

      // Tap pencil edit button
      await tester.tap(find.byKey(const Key('edit_flash_image_button')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Flash Photo'), findsOneWidget);
      expect(find.byKey(const Key('photo_option_crop')), findsOneWidget);
      expect(find.text('Resize & Crop Framing'), findsOneWidget);

      // Tap Resize & Crop Framing from sheet
      await tester.tap(find.byKey(const Key('photo_option_crop')));
      await tester.pumpAndSettle();

      expect(find.text('CROP & RESIZE FLASH'), findsOneWidget);

      // Close cropper
      await tester.tap(find.byKey(const Key('photo_crop_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.text('Upload Flash: Item Details'), findsOneWidget);
    });
  });
}

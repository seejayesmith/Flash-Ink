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
    testWidgets('Renders PhotoCropScreen with controls, titles, and action buttons', (tester) async {
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
      expect(find.byKey(const Key('photo_crop_reset_button')), findsOneWidget);
      expect(find.byKey(const Key('photo_crop_rotate_button')), findsOneWidget);
      expect(find.byKey(const Key('confirm_crop_button')), findsOneWidget);
      expect(find.text('APPLY & USE PHOTO'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('Tapping Rotate 90° button updates rotation quarterTurns', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoCropScreen(
            imageBytes: samplePngBytes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rotateBtn = find.byKey(const Key('photo_crop_rotate_button'));
      expect(rotateBtn, findsOneWidget);

      await tester.tap(rotateBtn);
      await tester.pumpAndSettle();

      // Find RotatedBox and verify 1 quarterTurn
      final rotatedBoxFinder = find.byType(RotatedBox);
      expect(rotatedBoxFinder, findsOneWidget);
      final rotatedBox = tester.widget<RotatedBox>(rotatedBoxFinder);
      expect(rotatedBox.quarterTurns, 1);

      // Tap Reset button
      final resetBtn = find.byKey(const Key('photo_crop_reset_button'));
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      final resetRotatedBox = tester.widget<RotatedBox>(rotatedBoxFinder);
      expect(resetRotatedBox.quarterTurns, 0);
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
}

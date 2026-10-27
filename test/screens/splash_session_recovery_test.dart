import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:flash_ink/screens/splash_screen.dart';
import 'package:flash_ink/screens/role_selection_screen.dart';
import 'package:flash_ink/screens/main_feed_screen.dart';
import 'package:flash_ink/screens/email_verification_screen.dart';
import 'package:flash_ink/services/auth_service.dart';

class TestMockUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final bool isAnonymous;
  @override
  final bool emailVerified;

  TestMockUser({
    required this.uid,
    this.email,
    this.isAnonymous = false,
    this.emailVerified = true,
  });

  @override
  Future<void> reload() async {}
}

class TestAuthService extends AuthService {
  User? mockUser;

  TestAuthService({this.mockUser});

  @override
  User? get currentUser => mockUser;

  @override
  Stream<User?> get authStateChanges => Stream.value(mockUser);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('SplashScreen Session Recovery Tests', () {
    testWidgets('Routes to RoleSelectionScreen when no user is authenticated', (WidgetTester tester) async {
      final auth = TestAuthService(mockUser: null);

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            delay: Duration.zero,
            authService: auth,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(RoleSelectionScreen), findsOneWidget);
    });

    testWidgets('Routes guest (anonymous) user directly to MainFeedScreen', (WidgetTester tester) async {
      final guestUser = TestMockUser(
        uid: 'guest_123',
        isAnonymous: true,
      );
      final auth = TestAuthService(mockUser: guestUser);

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            delay: Duration.zero,
            authService: auth,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(MainFeedScreen), findsOneWidget);
    });

    testWidgets('Routes unverified email user to EmailVerificationScreen', (WidgetTester tester) async {
      final unverifiedUser = TestMockUser(
        uid: 'unverified_123',
        email: 'test@example.com',
        isAnonymous: false,
        emailVerified: false,
      );
      final auth = TestAuthService(mockUser: unverifiedUser);

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            delay: Duration.zero,
            authService: auth,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
    });
  });
}

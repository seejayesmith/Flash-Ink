import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import 'email_verification_screen.dart';
import 'artist_dashboard/artist_dashboard_screen.dart';
import 'artist_onboarding/artist_info_screen.dart';
import 'profile_setup_screen.dart';
import 'aesthetics_selection_screen.dart';
import 'main_feed_screen.dart';

class AuthRouting {
  static Future<void> routeUserAfterAuth(
    BuildContext context, 
    User user, 
    {
      String? defaultRole, 
      AuthService? authService,
      bool bypassEmailVerification = false,
    }
  ) async {
    // Check if email requires verification
    if (!bypassEmailVerification &&
        !user.isAnonymous &&
        user.email != null &&
        user.email!.isNotEmpty &&
        !user.emailVerified) {
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            authService: authService,
            role: defaultRole,
          ),
        ),
        (route) => false,
      );
      return;
    }

    // Anonymous guests jump directly to main feed
    if (user.isAnonymous) {
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainFeedScreen()),
        (route) => false,
      );
      return;
    }

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userDocRef.get();
    final data = userDoc.data();

    bool profileCompleted = false;
    String role = defaultRole ?? 'client';
    bool hasAesthetics = false;

    if (data != null && data['role'] != null) {
      // Existing user, use their data
      role = data['role'];
      profileCompleted = data['profileCompleted'] == true;
      final aesthetics = data['aesthetics'];
      hasAesthetics = aesthetics is List && aesthetics.isNotEmpty;
    } else {
      // New user (or missing role)
      try {
        await userDocRef.set({'role': role}, SetOptions(merge: true));
      } catch (_) {}
    }

    if (!context.mounted) return;

    Widget nextScreen;
    if (role == 'artist') {
      if (profileCompleted) {
        nextScreen = ArtistDashboardScreen(authService: authService);
      } else {
        nextScreen = ArtistInfoScreen(
          authService: authService,
          initialName: user.displayName,
          initialEmail: user.email,
        );
      }
    } else {
      if (!profileCompleted) {
        nextScreen = const ProfileSetupScreen();
      } else if (!hasAesthetics) {
        nextScreen = const AestheticsSelectionScreen();
      } else {
        nextScreen = const MainFeedScreen();
      }
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
      (route) => false,
    );
  }
}

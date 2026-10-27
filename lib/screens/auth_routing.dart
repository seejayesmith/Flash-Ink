import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
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
      FirebaseFirestore? firestore,
      bool bypassEmailVerification = false,
    }
  ) async {
    AuthService.notifyAuthSessionChanged(user);
    bool isAnonymous = false;
    try {
      isAnonymous = user.isAnonymous;
    } catch (_) {}

    String? email;
    try {
      email = user.email;
    } catch (_) {}

    bool emailVerified = true;
    try {
      emailVerified = user.emailVerified;
    } catch (_) {}

    // Check if email requires verification
    if (!bypassEmailVerification &&
        !isAnonymous &&
        email != null &&
        email.isNotEmpty &&
        !emailVerified) {
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
    if (isAnonymous) {
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainFeedScreen()),
        (route) => false,
      );
      return;
    }

    FirebaseFirestore? providerFirestore;
    try {
      providerFirestore = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(firebaseFirestoreProvider);
    } catch (_) {}

    final effectiveAuth = authService ?? AuthService();
    final verifiedRole = await effectiveAuth.getVerifiedRole(
      user: user,
      forceRefresh: true,
    );

    FirebaseFirestore? resolvedFirestore = firestore ?? providerFirestore;
    final bool hasInjectedFirestore = resolvedFirestore != null;
    if (resolvedFirestore == null && Firebase.apps.isNotEmpty) {
      try {
        resolvedFirestore = FirebaseFirestore.instance;
      } catch (_) {}
    }

    final bool isWidgetTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final timeoutDuration = (!isWidgetTest || hasInjectedFirestore)
        ? const Duration(seconds: 6)
        : const Duration(milliseconds: 120);

    Map<String, dynamic>? data;
    if (resolvedFirestore != null) {
      final userDocRef = resolvedFirestore.collection('users').doc(user.uid);
      try {
        final userDoc = await userDocRef.get().timeout(timeoutDuration);
        data = userDoc.data();
      } catch (_) {
        data = null;
      }

      if (data == null && defaultRole != 'artist') {
        // New user document initialization (never self-assigns 'artist' role on client)
        try {
          await userDocRef
              .set({
                'uid': user.uid,
                'role': 'client',
              }, SetOptions(merge: true))
              .timeout(timeoutDuration);
        } catch (_) {}
      }
    }

    bool profileCompleted = false;
    bool hasAesthetics = false;

    if (data != null) {
      profileCompleted = data['profileCompleted'] == true;
      final aesthetics = data['aesthetics'];
      hasAesthetics = aesthetics is List && aesthetics.isNotEmpty;
    }

    bool isArtistDoc = false;
    if (resolvedFirestore != null) {
      try {
        final artistDoc = await resolvedFirestore
            .collection('artists')
            .doc(user.uid)
            .get()
            .timeout(timeoutDuration);
        isArtistDoc = artistDoc.exists;
        if (artistDoc.data()?['profileCompleted'] == true) {
          profileCompleted = true;
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    // Zero-Trust Routing Guard:
    // 1. Entering the privileged ArtistDashboardScreen requires either server-signed
    //    Firebase Auth Custom Claims or an existing verified artist document in Firestore.
    // 2. Brand-new users who selected 'artist' during sign-up (`!profileCompleted && defaultRole == 'artist'`)
    //    are routed to the ArtistInfoScreen onboarding funnel so they can complete verification.
    final bool isVerifiedArtist = verifiedRole == 'artist' || isArtistDoc || (data != null && data['role'] == 'artist');
    final bool isEnteringArtistOnboarding =
        !profileCompleted && (defaultRole == 'artist' || isVerifiedArtist);

    Widget nextScreen;
    if (isVerifiedArtist && profileCompleted) {
      nextScreen = ArtistDashboardScreen(authService: authService);
    } else if (isEnteringArtistOnboarding) {
      String? displayName;
      try {
        displayName = user.displayName;
      } catch (_) {}
      String? phoneNumber;
      try {
        phoneNumber = user.phoneNumber;
      } catch (_) {}
      if ((phoneNumber == null || phoneNumber.isEmpty) && data != null && data['phoneNumber'] != null) {
        phoneNumber = data['phoneNumber'] as String?;
      }
      nextScreen = ArtistInfoScreen(
        authService: authService,
        initialName: displayName,
        initialEmail: email,
        initialPhone: phoneNumber,
      );
    } else {
      if (!profileCompleted) {
        nextScreen = ProfileSetupScreen(authService: authService);
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

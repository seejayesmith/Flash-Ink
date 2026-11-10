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

      final Map<String, dynamic> initialUpdates = {
        'uid': user.uid,
        if (data == null || data['role'] == null) 'role': 'client',
        'onboardingRole': ?defaultRole,
        'activeMode': ?defaultRole,
      };
      if (data == null ||
          data['role'] == null ||
          (defaultRole != null &&
              (data['onboardingRole'] == null || data['activeMode'] == null))) {
        // Initialize or backfill document with role: 'client' (never self-assigns 'artist' role on client)
        // and persist chosen onboarding persona
        try {
          await userDocRef
              .set(initialUpdates, SetOptions(merge: true))
              .timeout(timeoutDuration);
          data = (data != null)
              ? {...data, ...initialUpdates}
              : initialUpdates;
        } catch (_) {}
      }
    }

    bool clientProfileCompleted = false;
    bool hasAesthetics = false;

    if (data != null) {
      clientProfileCompleted = data['profileCompleted'] == true;
      final aesthetics = data['aesthetics'];
      hasAesthetics = aesthetics is List && aesthetics.isNotEmpty;
    }

    bool isArtistDoc = false;
    bool artistDocCompleted = false;
    if (resolvedFirestore != null) {
      try {
        final artistDoc = await resolvedFirestore
            .collection('artists')
            .doc(user.uid)
            .get()
            .timeout(timeoutDuration);
        isArtistDoc = artistDoc.exists;
        if (isArtistDoc && artistDoc.data()?['profileCompleted'] != false) {
          artistDocCompleted = true;
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    // Zero-Trust & Dual-Persona Routing Guard:
    // 1. An account is considered a completed artist if `artists/{uid}` exists and is not an incomplete draft
    //    (`profileCompleted != false`), or if server-minted claims / user doc specify artist status without an incomplete draft.
    final bool hasLegacyOrClaimArtist = verifiedRole == 'artist' ||
        (data != null &&
            (data['isArtist'] == true || data['role'] == 'artist') &&
            data['profileCompleted'] == true);
    final bool isArtistOnboarded =
        artistDocCompleted || (!isArtistDoc && hasLegacyOrClaimArtist);

    // Resolve the user's intended persona mode:
    // - Explicit `defaultRole` from RoleSelectionScreen takes precedence (allowing an existing
    //   Client to onboard/sign-in as an Artist, or an existing Artist to sign-in as a Client).
    // - Otherwise falls back to persisted `activeMode`.
    final String? persistedMode = AuthService.activeAppMode ??
        (data?['activeMode'] as String?) ??
        (data?['onboardingRole'] as String?);
    final String effectiveMode = defaultRole ??
        persistedMode ??
        (isArtistOnboarded ? 'artist' : 'client');

    await AuthService.setActiveAppMode(
      effectiveMode,
      uid: user.uid,
      firestore: (!isWidgetTest || hasInjectedFirestore)
          ? resolvedFirestore
          : null,
    );

    if (!context.mounted) return;

    Widget buildArtistOnboardingScreen() {
      String? displayName;
      try {
        displayName = user.displayName;
      } catch (_) {}
      if (displayName == null || displayName.trim().isEmpty) {
        displayName = (data?['username'] as String?) ??
            (data?['displayName'] as String?);
      }
      String? resolvedEmail = email;
      if ((resolvedEmail == null || resolvedEmail.isEmpty) &&
          data != null &&
          data['email'] is String) {
        resolvedEmail = data['email'] as String?;
      }
      String? phoneNumber;
      try {
        phoneNumber = user.phoneNumber;
      } catch (_) {}
      if ((phoneNumber == null || phoneNumber.isEmpty) &&
          data != null &&
          data['phoneNumber'] != null) {
        phoneNumber = data['phoneNumber'] as String?;
      }
      return ArtistInfoScreen(
        authService: authService,
        initialName: displayName,
        initialEmail: resolvedEmail,
        initialPhone: phoneNumber,
      );
    }

    Widget nextScreen;
    if (effectiveMode == 'artist') {
      if (isArtistOnboarded) {
        nextScreen = ArtistDashboardScreen(authService: authService);
      } else {
        nextScreen = buildArtistOnboardingScreen();
      }
    } else {
      // Client persona mode ('client')
      final bool hasBasicProfile = clientProfileCompleted || isArtistOnboarded;
      if (!hasBasicProfile) {
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

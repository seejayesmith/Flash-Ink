import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/flash_logo.dart';
import 'role_selection_screen.dart';
import 'main_feed_screen.dart';
import 'profile_setup_screen.dart';
import 'aesthetics_selection_screen.dart';
import 'artist_dashboard/artist_dashboard_screen.dart';
import 'email_verification_screen.dart';

class SplashScreen extends StatefulWidget {
  /// The duration to keep the splash screen visible before routing.
  /// Defaults to Duration.zero so secondary navigations and tests do not leak timers.
  final Duration delay;
  final AuthService? authService;
  final FirebaseFirestore? firestore;

  const SplashScreen({
    super.key,
    this.delay = Duration.zero,
    this.authService,
    this.firestore,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _delayTimer;
  Completer<void>? _delayCompleter;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppAndRoute();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    if (_delayCompleter != null && !_delayCompleter!.isCompleted) {
      _delayCompleter!.complete();
    }
    super.dispose();
  }

  Future<void> _initializeAppAndRoute() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    Widget nextScreen = RoleSelectionScreen(authService: widget.authService);

    try {
      // 1. Wait for auth state to be restored rather than reading synchronously
      User? user;
      try {
        final authStream = (widget.authService?.authStateChanges ?? FirebaseAuth.instance.authStateChanges());
        user = await authStream.first.timeout(
          const Duration(seconds: 4),
          onTimeout: () => (widget.authService?.currentUser ?? FirebaseAuth.instance.currentUser),
        );
      } catch (_) {
        user = widget.authService?.currentUser ?? FirebaseAuth.instance.currentUser;
      }

      if (user != null) {
        // Anonymous guests bypass profile setup directly to MainFeed
        if (user.isAnonymous) {
          nextScreen = const MainFeedScreen();
        } else {
          // Check for unverified email accounts
          if (user.email != null && user.email!.isNotEmpty && !user.emailVerified) {
            try {
              await user.reload();
            } catch (_) {}
            final refreshedUser = FirebaseAuth.instance.currentUser ?? user;
            if (!refreshedUser.emailVerified) {
              nextScreen = EmailVerificationScreen(authService: widget.authService);
              await _routeWithDelay(nextScreen);
              return;
            }
          }

          // Verify role from server-minted Firebase Auth Custom Claims (JWT)
          final effectiveAuth = widget.authService ?? AuthService();
          final verifiedRole = await effectiveAuth.getVerifiedRole(
            user: user,
            forceRefresh: true,
          );

          // Fetch user document from Firestore for onboarding progress
          final firestore = widget.firestore ?? FirebaseFirestore.instance;
          final doc = await firestore
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 6));
          final data = doc.data();

          final profileCompleted = data?['profileCompleted'] == true;

          // Check if artist document exists
          bool isArtist = verifiedRole == 'artist';
          if (!isArtist) {
            try {
              final artistDoc = await firestore
                  .collection('artists')
                  .doc(user.uid)
                  .get()
                  .timeout(const Duration(seconds: 3));
              if (artistDoc.exists) {
                isArtist = true;
              }
            } catch (_) {}
          }

          // If role was missing in Firestore and not an artist, backfill default 'client' role
          if (!isArtist && (data == null || data['role'] == null)) {
            try {
              await firestore
                  .collection('users')
                  .doc(user.uid)
                  .set({
                    'uid': user.uid,
                    'role': 'client',
                  }, SetOptions(merge: true));
            } catch (_) {}
          }

          // Route to ArtistDashboardScreen if verified custom claims or artist document exists
          if (isArtist) {
            nextScreen = const ArtistDashboardScreen();
          } else {
            final aesthetics = data?['aesthetics'];
            final hasAesthetics = aesthetics is List && aesthetics.isNotEmpty;

            if (!profileCompleted) {
              nextScreen = const ProfileSetupScreen();
            } else if (!hasAesthetics) {
              nextScreen = const AestheticsSelectionScreen();
            } else {
              nextScreen = const MainFeedScreen();
            }
          }
        }
      }
    } catch (e, st) {
      debugPrint('SplashScreen Error: $e\n$st');
      // Firestore or network failure for authenticated user: show inline retry UI
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Unable to connect to service. Please check your connection. ($e)';
        });
      }
      return;
    }

    await _routeWithDelay(nextScreen);
  }

  Future<void> _routeWithDelay(Widget nextScreen) async {
    if (widget.delay > Duration.zero && mounted) {
      final completer = Completer<void>();
      _delayCompleter = completer;
      _delayTimer = Timer(widget.delay, () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      await completer.future;
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Splash background image pinned to full screen
          Positioned(
            top: 0,
            left: 0,
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/tattoo_setup.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black87,
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FlashLogo(
                    fontSize: 76,
                    shadows: [
                      Shadow(
                        color: Colors.black.withAlpha(200),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  AppGaps.gapXs,
                  Text(
                    'TATTOO DISCOVERY & BOOKING',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF919696),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3.5,
                    ),
                  ),
                  if (_hasError) ...[
                    AppGaps.gapXl,
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceXl),
                      padding: const EdgeInsets.all(AppSpacing.spaceLg),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2020),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withAlpha(120),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: Color(0xFFEF4444),
                            size: 32,
                          ),
                          AppGaps.gapSm,
                          Text(
                            _errorMessage ?? 'Unable to connect to service. Please check your connection.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFD8DDDD),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          AppGaps.gapMd,
                          ElevatedButton.icon(
                            key: const Key('splash_retry_button'),
                            onPressed: _initializeAppAndRoute,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEEC200),
                              foregroundColor: const Color(0xFF121414),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              textStyle: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isLoading && !_hasError)
            Positioned(
              bottom: AppSpacing.spaceXxl,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFFEEC200).withAlpha(200),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

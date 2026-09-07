import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_spacing.dart';
import 'role_selection_screen.dart';
import 'main_feed_screen.dart';
import 'profile_setup_screen.dart';
import 'aesthetics_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppAndRoute();
    });
  }

  Future<void> _initializeAppAndRoute() async {
    Widget nextScreen = const RoleSelectionScreen();

    try {
      // Execute background initialization, auth check, and config retrieval
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data();

        // Route based on onboarding progress
        if (data != null && data['role'] != null) {
          final profileCompleted = data['profileCompleted'] == true;
          final aesthetics = data['aesthetics'];
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
    } catch (_) {
      // If error or offline, fallback to RoleSelectionScreen
      nextScreen = const RoleSelectionScreen();
    }

    if (mounted) {
      // Smooth fade transition to next screen replacing the splash stack
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
      body: Stack(
        children: [
          // Splash background image
          Container(
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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Flash',
                      style: GoogleFonts.kaushanScript(
                        fontSize: 76,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEEC200),
                        shadows: [
                          Shadow(
                            color: Colors.black.withAlpha(200),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    AppGaps.gapXs,
                    const Icon(
                      Icons.electric_bolt,
                      color: Color(0xFFEEC200),
                      size: 42,
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
              ],
            ),
          ),
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

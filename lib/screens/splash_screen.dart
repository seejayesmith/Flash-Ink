import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role_selection_screen.dart';
import 'main_feed_screen.dart';

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

        // If user already has a complete profile, route to MainFeedScreen
        if (data != null &&
            data['role'] != null &&
            data['aesthetics'] != null &&
            (data['aesthetics'] as List).isNotEmpty) {
          nextScreen = const MainFeedScreen();
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
          // Splash background placeholder
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80',
                ),
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
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.electric_bolt,
                      color: Color(0xFFEEC200),
                      size: 42,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'TATTOO DISCOVERY & BOOKING',
                  style: GoogleFonts.epilogue(
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
            bottom: 48,
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

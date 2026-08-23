import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_buttons.dart';
import 'splash_screen.dart';

class MainFeedScreen extends StatefulWidget {
  const MainFeedScreen({super.key});

  @override
  State<MainFeedScreen> createState() => _MainFeedScreenState();
}

class _MainFeedScreenState extends State<MainFeedScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _showAuthWallModal(String actionName) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2020),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.topLg,
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.spaceLg,
            right: AppSpacing.spaceLg,
            top: AppSpacing.spaceLg,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + AppSpacing.spaceXl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF4D5252),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              AppGaps.gapLg,
              const Icon(
                Icons.lock_person_outlined,
                color: Color(0xFFEEC200),
                size: 48,
              ),
              AppGaps.gapMd,
              Text(
                'Create an account to $actionName',
                textAlign: TextAlign.center,
                style: GoogleFonts.epilogue(
                  color: const Color(0xFFF9FAFA),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppGaps.gapSm,
              Text(
                'Save your collection, claim one-of-a-kind flash, and connect directly with verified tattoo artists.',
                textAlign: TextAlign.center,
                style: GoogleFonts.epilogue(
                  color: const Color(0xFF919696),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              AppGaps.gapXl,
              AppButtons.primaryCTA(
                icon: Icons.g_mobiledata,
                text: 'Upgrade with Google',
                onPressed: () async {
                  nav.pop();
                  setState(() => _isLoading = true);
                  try {
                    await _authService.linkWithGoogle();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Account upgraded successfully!'),
                        backgroundColor: Color(0xFF22C55E),
                      ),
                    );
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Upgrade failed: $e'),
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                    );
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                backgroundColor: const Color(0xFFF9FAFA),
                foregroundColor: const Color(0xFF121414),
              ),
              AppGaps.gapSm,
              AppButtons.primaryCTA(
                icon: Icons.apple,
                text: 'Upgrade with Apple',
                onPressed: () async {
                  nav.pop();
                  setState(() => _isLoading = true);
                  try {
                    await _authService.linkWithApple();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Account upgraded successfully!'),
                        backgroundColor: Color(0xFF22C55E),
                      ),
                    );
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Upgrade failed: $e'),
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                    );
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                backgroundColor: const Color(0xFF121414),
                foregroundColor: const Color(0xFFF9FAFA),
              ),
              AppGaps.gapXs,
            ],
          ),
        );
      },
    );
  }

  void _handleRestrictedAction(String actionName) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      _showAuthWallModal(actionName);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$actionName action completed!'),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user?.isAnonymous ?? true;

    return PopScope(
      canPop: false, // Root feed screen
      child: Scaffold(
        backgroundColor: const Color(0xFF121414),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E2020),
          elevation: 0,
          title: Text(
            'Flash Feed',
            style: GoogleFonts.epilogue(
              color: const Color(0xFFF9FAFA),
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (isGuest)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.spaceXs),
                child: Chip(
                  label: const Text(
                    'Guest',
                    style: TextStyle(
                      color: Color(0xFF121414),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: const Color(0xFFEEC200),
                  padding: EdgeInsets.zero,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFFF9FAFA)),
              tooltip: 'Sign Out',
              onPressed: _handleSignOut,
            ),
          ],
        ),
        body: Stack(
          children: [
            Padding(
              padding: AppPadding.screenHorizontal.add(const EdgeInsets.symmetric(vertical: AppSpacing.spaceLg)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.spaceLg),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2020),
                      borderRadius: AppBorderRadius.lg,
                      border: Border.all(color: const Color(0xFF262929)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Color(0xFFEEC200),
                          size: 48,
                        ),
                        AppGaps.gapMd,
                        Text(
                          'Welcome to Flash.Ink',
                          style: GoogleFonts.epilogue(
                            color: const Color(0xFFF9FAFA),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppGaps.gapXs,
                        Text(
                          isGuest
                              ? 'Browsing as Guest. Certain features are locked behind an Auth Wall.'
                              : 'You are signed in as ${user?.email ?? user?.displayName ?? 'Verified Member'}.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.epilogue(
                            color: const Color(0xFF919696),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppGaps.gapXl,
                  AppButtons.primaryCTA(
                    icon: Icons.bookmark_add,
                    text: 'Claim Flash Piece (Deposit)',
                    onPressed: () => _handleRestrictedAction('claim a flash piece'),
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: const Color(0xFFF9FAFA),
                  ),
                  AppGaps.gapMd,
                  AppButtons.primaryCTA(
                    icon: Icons.person_add,
                    text: 'Follow Artist',
                    onPressed: () => _handleRestrictedAction('follow an artist'),
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: const Color(0xFFF9FAFA),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEEC200)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

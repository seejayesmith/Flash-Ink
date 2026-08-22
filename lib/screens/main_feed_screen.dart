import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 20.0,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 32.0,
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
              const SizedBox(height: 24),
              const Icon(
                Icons.lock_person_outlined,
                color: Color(0xFFEEC200),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Create an account to $actionName',
                textAlign: TextAlign.center,
                style: GoogleFonts.epilogue(
                  color: const Color(0xFFF9FAFA),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Save your collection, claim one-of-a-kind flash, and connect directly with verified tattoo artists.',
                textAlign: TextAlign.center,
                style: GoogleFonts.epilogue(
                  color: const Color(0xFF919696),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text(
                  'Upgrade with Google',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9FAFA),
                  foregroundColor: const Color(0xFF121414),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.apple, size: 24),
                label: const Text(
                  'Upgrade with Apple',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF121414),
                  foregroundColor: const Color(0xFFF9FAFA),
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: Color(0xFF4D5252)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
                padding: const EdgeInsets.only(right: 8.0),
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
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2020),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF262929)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Color(0xFFEEC200),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to Flash.Ink',
                          style: GoogleFonts.epilogue(
                            color: const Color(0xFFF9FAFA),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text('Claim Flash Piece (Deposit)'),
                    onPressed: () => _handleRestrictedAction('claim a flash piece'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: const Color(0xFFF9FAFA),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Follow Artist'),
                    onPressed: () => _handleRestrictedAction('follow an artist'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: const Color(0xFFF9FAFA),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                    ),
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

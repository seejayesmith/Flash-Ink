import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_buttons.dart';
import 'aesthetics_selection_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _nameController.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': _nameController.text.trim(),
          'username': _usernameController.text.trim().replaceAll('@', ''),
          'bio': _bioController.text.trim(),
          'profileCompleted': true,
        }, SetOptions(merge: true));

        if (user.displayName == null || user.displayName!.isEmpty) {
          await user.updateDisplayName(_nameController.text.trim());
        }
      }

      if (mounted) {
        // Destructive navigation to Style Preferences (Aesthetics)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AestheticsSelectionScreen(isGuest: false),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back navigation from bypassing profile setup
      child: Scaffold(
        backgroundColor: const Color(0xFF121414),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Profile Setup',
            style: TextStyle(
              color: Color(0xFFF9FAFA),
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: AppPadding.screenHorizontal,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppGaps.gapMd,
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFF1E2020),
                          child: const Icon(
                            Icons.person,
                            size: 52,
                            color: Color(0xFFEEC200),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEC200),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Color(0xFF121414),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppGaps.gapXl,
                  Text(
                    'Full Name',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFF9FAFA),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  AppGaps.gapXs,
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Color(0xFFF9FAFA)),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                    decoration: InputDecoration(
                      hintText: 'e.g. Alex Morgan',
                      hintStyle: const TextStyle(color: Color(0xFF4D5252)),
                      filled: true,
                      fillColor: const Color(0xFF1E2020),
                      border: OutlineInputBorder(
                        borderRadius: AppBorderRadius.md,
                        borderSide: const BorderSide(color: Color(0xFF262929)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppBorderRadius.md,
                        borderSide: const BorderSide(color: Color(0xFF262929)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppBorderRadius.md,
                        borderSide: const BorderSide(color: Color(0xFFEEC200)),
                      ),
                    ),
                  ),
                  AppGaps.gapLg,
                  Text(
                    'Username',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFF9FAFA),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  AppGaps.gapXs,
                  TextFormField(
                    controller: _usernameController,
                    style: const TextStyle(color: Color(0xFFF9FAFA)),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please choose a username'
                        : null,
                    decoration: InputDecoration(
                      prefixText: '@ ',
                      prefixStyle: const TextStyle(
                        color: Color(0xFFEEC200),
                        fontWeight: FontWeight.bold,
                      ),
                      hintText: 'alex_ink',
                      hintStyle: const TextStyle(color: Color(0xFF4D5252)),
                      filled: true,
                      fillColor: const Color(0xFF1E2020),
                      border: OutlineInputBorder(
                        borderRadius: AppBorderRadius.md,
                        borderSide: const BorderSide(color: Color(0xFF262929)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppBorderRadius.md,
                        borderSide: const BorderSide(color: Color(0xFF262929)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppBorderRadius.md,
                        borderSide: const BorderSide(color: Color(0xFFEEC200)),
                      ),
                    ),
                  ),
                  AppGaps.gapLg,
                  Text(
                    'Bio / City (Optional)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFF9FAFA),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  AppGaps.gapXs,
                  TextFormField(
                    controller: _bioController,
                    maxLines: 3,
                    style: const TextStyle(color: Color(0xFFF9FAFA)),
                    decoration: InputDecoration(
                      hintText: 'Tattoo enthusiast based in Austin, TX...',
                      hintStyle: const TextStyle(color: Color(0xFF4D5252)),
                      filled: true,
                      fillColor: const Color(0xFF1E2020),
                      border: OutlineInputBorder(
                        borderRadius: AppBorderRadius.md,
                        borderSide: const BorderSide(color: Color(0xFF262929)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppBorderRadius.md,
                        borderSide: const BorderSide(color: Color(0xFF262929)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppBorderRadius.md,
                        borderSide: const BorderSide(color: Color(0xFFEEC200)),
                      ),
                    ),
                  ),
                  AppGaps.gapXl,
                  AppButtons.primaryCTA(
                    isLoading: _isLoading,
                    onPressed: _saveProfile,
                    text: 'CONTINUE',
                  ),
                  AppGaps.gapLg,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

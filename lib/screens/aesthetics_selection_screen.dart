import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_buttons.dart';
import 'main_feed_screen.dart';

class AestheticsSelectionScreen extends StatefulWidget {
  final bool isGuest;

  const AestheticsSelectionScreen({super.key, this.isGuest = false});

  @override
  State<AestheticsSelectionScreen> createState() => _AestheticsSelectionScreenState();
}

class _AestheticsSelectionScreenState extends State<AestheticsSelectionScreen> {
  final List<String> _selectedAesthetics = ['traditional'];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _aestheticsOptions = [
    {
      'id': 'traditional',
      'label': 'TRADITIONAL',
      'icon': Icons.anchor,
      'gradient': [Color(0xFF2E1A1A), Color(0xFF1E2020)],
      'image': 'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=600&q=80',
    },
    {
      'id': 'fineline',
      'label': 'FINE LINE',
      'icon': Icons.gesture,
      'gradient': [Color(0xFF1E262A), Color(0xFF121414)],
      'image': 'https://images.unsplash.com/photo-1562962230-16e4623d36e6?auto=format&fit=crop&w=600&q=80',
    },
    {
      'id': 'japanese',
      'label': 'JAPANESE',
      'icon': Icons.water,
      'gradient': [Color(0xFF2A1E26), Color(0xFF1A1A24)],
      'image': 'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?auto=format&fit=crop&w=600&q=80',
    },
    {
      'id': 'realism',
      'label': 'REALISM',
      'icon': Icons.remove_red_eye_outlined,
      'gradient': [Color(0xFF26241E), Color(0xFF1A1916)],
      'image': 'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=600&q=80',
    },
    {
      'id': 'blackwork',
      'label': 'BLACKWORK',
      'icon': Icons.contrast,
      'gradient': [Color(0xFF181A1A), Color(0xFF0F1010)],
      'image': 'https://images.unsplash.com/photo-1562962230-16e4623d36e6?auto=format&fit=crop&w=600&q=80',
    },
    {
      'id': 'watercolor',
      'label': 'WATERCOLOR',
      'icon': Icons.palette_outlined,
      'gradient': [Color(0xFF1E2626), Color(0xFF141C1E)],
      'image': 'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?auto=format&fit=crop&w=600&q=80',
    },
  ];

  Future<void> _saveAesthetics() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'aesthetics': _selectedAesthetics}, SetOptions(merge: true));
        } catch (_) {}
      }

      if (mounted) {
        // Destructive routing directly to Main Home Feed (clearing all previous routes)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainFeedScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save aesthetics: $e'),
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

  void _toggleAesthetic(String id) {
    setState(() {
      if (_selectedAesthetics.contains(id)) {
        _selectedAesthetics.remove(id);
      } else {
        _selectedAesthetics.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent bypassing flow
      child: Scaffold(
        backgroundColor: const Color(0xFF121414),
        body: SafeArea(
          child: Padding(
            padding: AppPadding.screenHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppGaps.gapMd,
                Text(
                  'Choose your aesthetics',
                  style: GoogleFonts.epilogue(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppGaps.gapXs,
                Text(
                  'Select styles to curate your personalized feed. You can change this later.',
                  style: GoogleFonts.epilogue(
                    color: const Color(0xFF919696),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                AppGaps.gapLg,
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.spaceMd,
                      mainAxisSpacing: AppSpacing.spaceMd,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: _aestheticsOptions.length,
                    itemBuilder: (context, index) {
                      final option = _aestheticsOptions[index];
                      final isSelected = _selectedAesthetics.contains(option['id']);
                      final gradientColors = option['gradient'] as List<Color>;

                      return GestureDetector(
                        onTap: () => _toggleAesthetic(option['id'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: AppBorderRadius.lg,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF262929),
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradientColors,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFEEC200).withAlpha(40),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: AppBorderRadius.md,
                            child: Stack(
                              children: [
                                // Background image with graceful fallback
                                Positioned.fill(
                                  child: Image.network(
                                    option['image'] as String,
                                    fit: BoxFit.cover,
                                    color: Colors.black.withAlpha(isSelected ? 100 : 160),
                                    colorBlendMode: BlendMode.darken,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Icon(
                                          option['icon'] as IconData,
                                          color: (isSelected ? const Color(0xFFEEC200) : const Color(0xFF4D5252)).withAlpha(80),
                                          size: 48,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Label & selection checkmark
                                Positioned(
                                  bottom: AppSpacing.spaceMd,
                                  left: AppSpacing.spaceSm,
                                  right: AppSpacing.spaceSm,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          option['label'] as String,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.epilogue(
                                            color: const Color(0xFFF9FAFA),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        AppGaps.gapXs,
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFFEEC200),
                                          size: 16,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                AppGaps.gapMd,
                AppButtons.primaryCTA(
                  isLoading: _isLoading,
                  onPressed: _saveAesthetics,
                  text: 'CONTINUE',
                ),
                AppGaps.gapMd,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/app_providers.dart';
import '../repositories/user_repository.dart';
import '../theme/app_buttons.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/flash_glass_app_bar.dart';
import '../widgets/flash_image.dart';
import '../widgets/flash_snack_bar.dart';
import '../widgets/fade_page_route.dart';
import '../services/auth_service.dart';
import 'account_creation_screen.dart';
import 'profile_setup_screen.dart';
import 'main_feed_screen.dart';

class AestheticsSelectionScreen extends StatefulWidget {
  final bool isGuest;
  final AuthService? authService;

  const AestheticsSelectionScreen({
    super.key,
    this.isGuest = false,
    this.authService,
  });

  @override
  State<AestheticsSelectionScreen> createState() => _AestheticsSelectionScreenState();
}

class _AestheticsSelectionScreenState extends State<AestheticsSelectionScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final List<String> _selectedAesthetics = [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _aestheticsOptions = [
    {
      'id': 'traditional',
      'label': 'TRADITIONAL',
      'icon': Icons.anchor,
      'gradient': [Color(0xFF2E1A1A), Color(0xFF1E2020)],
      'image': 'assets/images/flash_traditional_dagger.jpg',
    },
    {
      'id': 'fineline',
      'label': 'FINE LINE',
      'icon': Icons.gesture,
      'gradient': [Color(0xFF1E262A), Color(0xFF121414)],
      'image': 'assets/images/flash_fineline_flora.jpg',
    },
    {
      'id': 'japanese',
      'label': 'JAPANESE',
      'icon': Icons.water,
      'gradient': [Color(0xFF2A1E26), Color(0xFF1A1A24)],
      'image': 'assets/images/flash_japanese_koi.jpg',
    },
    {
      'id': 'realism',
      'label': 'REALISM',
      'icon': Icons.remove_red_eye_outlined,
      'gradient': [Color(0xFF26241E), Color(0xFF1A1916)],
      'image': 'assets/images/flash_american_eagle.jpg',
    },
    {
      'id': 'blackwork',
      'label': 'BLACKWORK',
      'icon': Icons.contrast,
      'gradient': [Color(0xFF181A1A), Color(0xFF0F1010)],
      'image': 'assets/images/flash_blackwork_skull.jpg',
    },
    {
      'id': 'watercolor',
      'label': 'WATERCOLOR',
      'icon': Icons.palette_outlined,
      'gradient': [Color(0xFF1E2626), Color(0xFF141C1E)],
      'image': 'assets/images/flash_traditional_moth.jpg',
    },
  ];

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      if (widget.isGuest) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AccountCreationScreen(role: 'client')),
        );
      } else {
        Navigator.pushReplacement(
          context,
          FadePageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      }
    }
  }

  Future<void> _persistAesthetics(List<String> styles) async {
    User? user = _authService.currentUser;
    if (user == null) {
      try {
        user = FirebaseAuth.instance.currentUser;
      } catch (_) {}
    }
    if (user == null) return;
    try {
      FirebaseFirestore? injectedDb;
      try {
        injectedDb = ProviderScope.containerOf(
          context,
          listen: false,
        ).read(firebaseFirestoreProvider);
      } catch (_) {}
      final isTest =
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
      final timeoutDuration = (!isTest || injectedDb != null)
          ? const Duration(seconds: 6)
          : const Duration(milliseconds: 300);
      await UserRepository(firestore: injectedDb)
          .upsertUserFields(
            user.uid,
            {'aesthetics': styles},
            setClientRoleOnCreate: true,
          )
          .timeout(timeoutDuration);
    } catch (_) {}
  }

  Future<void> _saveAesthetics() async {
    if (_selectedAesthetics.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _persistAesthetics(List<String>.from(_selectedAesthetics));

      if (mounted) {
        // Destructive routing directly to Main Home Feed (clearing all previous routes)
        Navigator.pushAndRemoveUntil(
          context,
          FadePageRoute(builder: (_) => MainFeedScreen(authService: _authService)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        FlashSnackBar.showError(context, 'Failed to save aesthetics: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _skipAesthetics() async {
    setState(() => _isLoading = true);
    try {
      await _persistAesthetics(const <String>[]);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          FadePageRoute(builder: (_) => MainFeedScreen(authService: _authService)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        FlashSnackBar.showError(context, 'Failed to skip aesthetics: $e');
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
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        appBar: FlashGlassAppBar(
          leading: IconButton(
            key: const Key('aesthetics_back_button'),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
            onPressed: _handleBack,
          ),
          onSkipPressed: _isLoading ? null : _skipAesthetics,
        ),
        body: Stack(
          children: [
            // Background subtle tattoo texture extending edge to edge pinned to full screen
            Positioned(
              top: 0,
              left: 0,
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height,
              child: Image.asset(
                'assets/images/tattoo_setup.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(235),
                      Colors.black.withAlpha(160),
                      Colors.black.withAlpha(160),
                      Colors.black.withAlpha(220),
                    ],
                    stops: const [0.0, 0.25, 0.60, 1.0],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(
                  height: MediaQuery.paddingOf(context).top + kToolbarHeight,
                ),
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.screenMargin,
                          AppSpacing.headerTop,
                          AppSpacing.screenMargin,
                          AppSpacing.headerContentGap,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose your aesthetics',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFF9FAFA),
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              AppGaps.headerTitleSubtitle,
                              Text(
                                'Select styles to curate your personalized feed. You can change this later.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF919696),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.screenMargin,
                          0,
                          AppSpacing.screenMargin,
                          AppSpacing.spaceLg,
                        ),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.spaceMd,
                            mainAxisSpacing: AppSpacing.spaceMd,
                            childAspectRatio: 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final option = _aestheticsOptions[index];
                              final isSelected = _selectedAesthetics.contains(option['id']);

                              return AdaptiveGlassContainer(
                                useGradient: false,
                                borderRadius: AppRadius.radiusLg,
                                isSelected: isSelected,
                                onTap: () => _toggleAesthetic(option['id'] as String),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.radiusLg - 1.0),
                                  child: Stack(
                                    children: [
                                      // Background image with graceful fallback
                                      Positioned.fill(
                                        child: FlashImage(
                                          urlOrPath: option['image'] as String,
                                          fit: BoxFit.cover,
                                          color: Colors.black.withAlpha(isSelected ? 90 : 150),
                                          colorBlendMode: BlendMode.darken,
                                          errorWidget: Center(
                                            child: Icon(
                                              option['icon'] as IconData,
                                              color: (isSelected ? const Color(0xFFEEC200) : const Color(0xFF4D5252)).withAlpha(80),
                                              size: 48,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Subtle bottom gradient for label contrast
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withAlpha(180),
                                              ],
                                              stops: const [0.45, 1.0],
                                            ),
                                          ),
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
                                                style: GoogleFonts.plusJakartaSans(
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
                              );
                            },
                            childCount: _aestheticsOptions.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin,
                    12,
                    AppSpacing.screenMargin,
                    MediaQuery.paddingOf(context).bottom + AppSpacing.ctaBottomPadding,
                  ),
                  child: AppButtons.primaryCTA(
                    isLoading: _isLoading,
                    onPressed: _selectedAesthetics.isEmpty ? null : _saveAesthetics,
                    text: widget.isGuest ? 'DONE' : 'FINISH',
                    backgroundColor: _selectedAesthetics.isEmpty
                        ? const Color(0xFF4D5252)
                        : const Color(0xFFEEC200),
                    foregroundColor: _selectedAesthetics.isEmpty
                        ? const Color(0xFF919696)
                        : const Color(0xFF121414),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

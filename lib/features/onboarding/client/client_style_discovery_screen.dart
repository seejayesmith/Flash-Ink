import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../providers/app_providers.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/adaptive_glass_container.dart';
import '../../../widgets/fade_page_route.dart';
import '../shared/onboarding_step_scaffold.dart';
import 'client_placement_preferences_screen.dart';

/// Client Onboarding Step 1: Style Discovery Tags
class ClientStyleDiscoveryScreen extends StatefulWidget {
  final AuthService? authService;
  final List<String>? initialSelected;

  const ClientStyleDiscoveryScreen({
    super.key,
    this.authService,
    this.initialSelected,
  });

  @override
  State<ClientStyleDiscoveryScreen> createState() => _ClientStyleDiscoveryScreenState();
}

class _ClientStyleDiscoveryScreenState extends State<ClientStyleDiscoveryScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late final List<String> _selectedStyles;
  bool _isLoading = false;

  static const List<Map<String, dynamic>> _availableStyles = [
    {'id': 'traditional', 'label': 'Traditional', 'icon': Icons.anchor},
    {'id': 'fineline', 'label': 'Fine Line', 'icon': Icons.gesture},
    {'id': 'japanese', 'label': 'Japanese', 'icon': Icons.water},
    {'id': 'realism', 'label': 'Realism', 'icon': Icons.visibility_outlined},
    {'id': 'blackwork', 'label': 'Blackwork', 'icon': Icons.contrast},
    {'id': 'watercolor', 'label': 'Watercolor', 'icon': Icons.palette_outlined},
    {'id': 'neotraditional', 'label': 'Neo-Traditional', 'icon': Icons.auto_awesome_outlined},
    {'id': 'illustrative', 'label': 'Illustrative', 'icon': Icons.brush_outlined},
    {'id': 'geometric', 'label': 'Geometric', 'icon': Icons.category_outlined},
    {'id': 'tribal', 'label': 'Tribal / Ornate', 'icon': Icons.flare_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _selectedStyles = List<String>.from(widget.initialSelected ?? []);
  }

  void _toggleStyle(String id) {
    setState(() {
      if (_selectedStyles.contains(id)) {
        _selectedStyles.remove(id);
      } else {
        _selectedStyles.add(id);
      }
    });
  }

  Future<void> _persistSelectionAndProceed([List<String>? stylesToSave]) async {
    setState(() => _isLoading = true);
    final chosen = stylesToSave ?? _selectedStyles;
    try {
      User? user = _authService.currentUser;
      if (user == null) {
        try {
          user = FirebaseAuth.instance.currentUser;
        } catch (_) {}
      }
      if (user != null) {
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
              {'aesthetics': chosen},
              setClientRoleOnCreate: true,
            )
            .timeout(timeoutDuration);
      }
    } catch (_) {
      // Proceed even in offline / unauthenticated states
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.push(
          context,
          FadePageRoute(
            builder: (_) => ClientPlacementPreferencesScreen(
              authService: _authService,
              selectedStyles: chosen,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      currentStep: 1,
      totalSteps: 4,
      title: 'Discover your style',
      subtitle: 'Pick the styles you love. We\'ll tailor your feed and artist recommendations.',
      ctaText: 'CONTINUE',
      ctaKey: const Key('client_styles_continue_button'),
      isCtaLoading: _isLoading,
      isCtaEnabled: _selectedStyles.isNotEmpty,
      onBack: Navigator.canPop(context)
          ? () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context);
            }
          : null,
      onSkip: () => _persistSelectionAndProceed([]),
      onCtaPressed: _selectedStyles.isNotEmpty ? () => _persistSelectionAndProceed() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableStyles.map((style) {
              final id = style['id'] as String;
              final label = style['label'] as String;
              final icon = style['icon'] as IconData;
              final isSelected = _selectedStyles.contains(id);

              return GestureDetector(
                key: Key('style_tag_$id'),
                onTap: () => _toggleStyle(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.gold.withAlpha(35)
                        : const Color(0xFF181A1A),
                    borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                    border: Border.all(
                      color: isSelected ? AppTheme.gold : const Color(0xFF2C3030),
                      width: isSelected ? 1.6 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isSelected ? AppTheme.gold : AppTheme.navInactive,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppTheme.textPrimary : const Color(0xFFB5BABA),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check,
                          size: 16,
                          color: AppTheme.gold,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          AdaptiveGlassContainer(
            borderRadius: 16,
            padding: const EdgeInsets.all(16),
            useGradient: false,
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: AppTheme.gold,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You can always refine your aesthetic preferences later in account settings.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF8C9191),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

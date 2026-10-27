import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/onboarding/shared/onboarding_step_scaffold.dart';
import '../../models/artist.dart';
import '../../models/studio_information.dart';
import '../../services/auth_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/fade_page_route.dart';
import '../../widgets/flash_switch.dart';
import '../../widgets/keyboard_collapse_button.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import 'artist_set_price_screen.dart';

class ArtistPoliciesScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String? instagramHandle;
  final AuthService? authService;
  final StudioInformation? studioInformation;
  final String? artistBio;
  final List<StudioPolicy>? initialPolicies;

  const ArtistPoliciesScreen({
    super.key,
    required this.artistName,
    this.photoBytes,
    this.photoUrl,
    this.instagramHandle,
    this.authService,
    this.studioInformation,
    this.artistBio,
    this.initialPolicies,
  });

  @override
  State<ArtistPoliciesScreen> createState() => _ArtistPoliciesScreenState();
}

class _ArtistPoliciesScreenState extends State<ArtistPoliciesScreen> {
  late List<StudioPolicy> _policies;

  static const List<StudioPolicy> _defaultStandardPolicies = [
    StudioPolicy(
      title: 'Deposits & Cancellations',
      description:
          'Non-refundable deposits applied toward final piece. Minimum 48-hour notice required to reschedule your appointment.',
      iconKey: 'deposit',
      isEnabled: true,
    ),
    StudioPolicy(
      title: 'Health & Day-of Prep',
      description:
          'Valid 18+ government photo ID required. Be well rested, nourished, and hydrated. No alcohol or blood thinners 24 hours prior.',
      iconKey: 'health',
      isEnabled: true,
    ),
    StudioPolicy(
      title: 'Studio Etiquette & Guests',
      description:
          '1 support guest is welcome. Silent appointments are gladly honored upon request at booking.',
      iconKey: 'etiquette',
      isEnabled: true,
    ),
    StudioPolicy(
      title: 'Touch-ups',
      description:
          'Free touch-up within 6 months of healing (excluding high-friction placements such as hands and feet).',
      iconKey: 'touchup',
      isEnabled: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _policies = widget.initialPolicies != null && widget.initialPolicies!.isNotEmpty
        ? List<StudioPolicy>.from(widget.initialPolicies!)
        : List<StudioPolicy>.from(_defaultStandardPolicies);
  }

  bool get _hasActivePolicy => _policies.any((p) => p.isEnabled);

  void _togglePolicy(int index, bool isEnabled) {
    setState(() {
      _policies[index] = _policies[index].copyWith(isEnabled: isEnabled);
    });
  }

  IconData _getPolicyIcon(String iconKey) {
    switch (iconKey.toLowerCase()) {
      case 'deposit':
        return Icons.payments_outlined;
      case 'health':
        return Icons.health_and_safety_outlined;
      case 'etiquette':
        return Icons.groups_outlined;
      case 'touchup':
        return Icons.healing_outlined;
      default:
        return Icons.policy_outlined;
    }
  }

  void _showEditPolicyModal(int index) {
    final policy = _policies[index];
    final titleController = TextEditingController(text: policy.title);
    final descController = TextEditingController(text: policy.description);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AdaptiveGlassContainer.bottomSheet(
          useGradient: false,
          topRadius: AppRadius.radiusSheet,
          padding: EdgeInsets.only(
            left: AppSpacing.screenGutter,
            right: AppSpacing.screenGutter,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Policy',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const KeyboardCollapseButton(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF919696)),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Policy Title',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFCCCCCC),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('edit_policy_title_field'),
                controller: titleController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                scrollPadding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                ),
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E2020),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    borderSide: const BorderSide(color: AppTheme.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    borderSide: const BorderSide(color: AppTheme.darkBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Policy Details & Rules',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFCCCCCC),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('edit_policy_desc_field'),
                controller: descController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                scrollPadding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                ),
                maxLines: 4,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14, height: 1.4),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E2020),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    borderSide: const BorderSide(color: AppTheme.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    borderSide: const BorderSide(color: AppTheme.darkBorder),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('save_policy_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                  ),
                ),
                onPressed: () {
                  final newTitle = titleController.text.trim();
                  final newDesc = descController.text.trim();
                  if (newTitle.isNotEmpty && newDesc.isNotEmpty) {
                    setState(() {
                      _policies[index] = _policies[index].copyWith(
                        title: newTitle,
                        description: newDesc,
                      );
                    });
                  }
                  Navigator.pop(sheetContext);
                },
                child: Text(
                  'SAVE CHANGES',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCustomPolicyModal() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedIcon = 'general';

    final icons = [
      {'key': 'deposit', 'label': 'Deposit', 'icon': Icons.payments_outlined},
      {'key': 'health', 'label': 'Health', 'icon': Icons.health_and_safety_outlined},
      {'key': 'etiquette', 'label': 'Etiquette', 'icon': Icons.groups_outlined},
      {'key': 'touchup', 'label': 'Touch-up', 'icon': Icons.healing_outlined},
      {'key': 'general', 'label': 'General', 'icon': Icons.policy_outlined},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AdaptiveGlassContainer.bottomSheet(
              useGradient: false,
              topRadius: AppRadius.radiusSheet,
              padding: EdgeInsets.only(
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Custom Policy',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const KeyboardCollapseButton(),
                            IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFF919696)),
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                    child: Text(
                      'Policy Category Icon',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFCCCCCC),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                    child: Row(
                      children: icons.map((item) {
                        final isSelected = selectedIcon == item['key'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            key: Key('policy_icon_chip_${item['key']}'),
                            onTap: () {
                              setSheetState(() => selectedIcon = item['key'] as String);
                            },
                            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.goldBadgeBackground : const Color(0xFF1E2020),
                                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                                border: Border.all(
                                  color: isSelected ? AppTheme.gold : AppTheme.darkBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    size: 16,
                                    color: isSelected ? AppTheme.gold : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    item['label'] as String,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: isSelected ? AppTheme.gold : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Policy Title *',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFCCCCCC),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: const Key('custom_policy_title_field'),
                          controller: titleController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          scrollPadding: EdgeInsets.only(
                            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                          ),
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1E2020),
                            hintText: 'e.g. Design Changes & Artwork Approval',
                            hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6B7280), fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                              borderSide: const BorderSide(color: AppTheme.darkBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                              borderSide: const BorderSide(color: AppTheme.darkBorder),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Policy Description *',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFCCCCCC),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: const Key('custom_policy_desc_field'),
                          controller: descController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          scrollPadding: EdgeInsets.only(
                            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                          ),
                          maxLines: 3,
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14, height: 1.4),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1E2020),
                            hintText: 'Explain the policy so clients understand what to expect...',
                            hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6B7280), fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                              borderSide: const BorderSide(color: AppTheme.darkBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                              borderSide: const BorderSide(color: AppTheme.darkBorder),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          key: const Key('add_custom_policy_submit_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                            ),
                          ),
                          onPressed: () {
                            final title = titleController.text.trim();
                            final desc = descController.text.trim();
                            if (title.isNotEmpty && desc.isNotEmpty) {
                              setState(() {
                                _policies.add(
                                  StudioPolicy(
                                    title: title,
                                    description: desc,
                                    iconKey: selectedIcon,
                                    isEnabled: true,
                                  ),
                                );
                              });
                              Navigator.pop(sheetContext);
                            }
                          },
                          child: Text(
                            'ADD POLICY',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleContinue() {
    if (!_hasActivePolicy) return;

    final activePolicies = _policies.where((p) => p.isEnabled).toList();

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(
      FadePageRoute(
        builder: (_) => ArtistSetPriceScreen(
          artistName: widget.artistName,
          photoBytes: widget.photoBytes,
          photoUrl: widget.photoUrl,
          instagramHandle: widget.instagramHandle ?? '',
          authService: widget.authService,
          studioInformation: widget.studioInformation,
          artistBio: widget.artistBio,
          policies: activePolicies,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      currentStep: 4,
      totalSteps: 9,
      title: 'Studio Policies & Rules',
      subtitle: 'Review industry-standard client rules or tailor them to match your workflow.',
      ctaText: 'CONTINUE',
      isCtaEnabled: _hasActivePolicy,
      onCtaPressed: _handleContinue,
      onBack: () {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(context).pop();
      },
      backgroundOverlay: const TattooBackgroundWrapper(child: SizedBox.expand()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            if (!_hasActivePolicy) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C1919),
                  borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Enable at least one studio policy to protect both you and your clients.',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Policy Cards List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _policies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final policy = _policies[index];
                return AdaptiveGlassContainer(
                  key: Key('policy_card_$index'),
                  useGradient: false,
                  borderRadius: AppRadius.radiusMd,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: policy.isEnabled ? AppTheme.goldBadgeBackground : const Color(0xFF242626),
                              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                            ),
                            child: Center(
                              child: Icon(
                                _getPolicyIcon(policy.iconKey),
                                color: policy.isEnabled ? AppTheme.gold : const Color(0xFF6B7280),
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              policy.title,
                              key: Key('policy_title_$index'),
                              style: GoogleFonts.plusJakartaSans(
                                color: policy.isEnabled ? AppTheme.textPrimary : const Color(0xFF6B7280),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          FlashSwitch(
                            key: Key('policy_switch_$index'),
                            value: policy.isEnabled,
                            onChanged: (val) => _togglePolicy(index, val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        policy.description,
                        key: Key('policy_desc_$index'),
                        style: GoogleFonts.plusJakartaSans(
                          color: policy.isEnabled ? const Color(0xFF919696) : const Color(0xFF555858),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      if (policy.isEnabled) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            key: Key('edit_policy_btn_$index'),
                            onTap: () => _showEditPolicyModal(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_outlined, size: 13, color: AppTheme.gold),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Edit text',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppTheme.gold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Add Custom Policy Button
            OutlinedButton.icon(
              key: const Key('add_custom_policy_button'),
              onPressed: _showAddCustomPolicyModal,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.gold, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.gold, size: 18),
              label: Text(
                'ADD CUSTOM POLICY',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      );
  }
}

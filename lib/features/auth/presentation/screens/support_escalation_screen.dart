import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../providers/app_providers.dart';
import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/flash_glass_app_bar.dart';
import '../../../../widgets/flash_snack_bar.dart';
import '../../../../widgets/pinned_bottom_action_scaffold.dart';
import '../controllers/auth_troubleshooting_controller.dart';

/// Screen allowing users to submit a manual concierge escalation ticket
/// when automated login recovery mechanisms cannot resolve their issue.
class SupportEscalationScreen extends ConsumerStatefulWidget {
  final String? initialEmail;
  final String? initialPhone;

  const SupportEscalationScreen({
    super.key,
    this.initialEmail,
    this.initialPhone,
  });

  @override
  ConsumerState<SupportEscalationScreen> createState() =>
      _SupportEscalationScreenState();
}

class _SupportEscalationScreenState
    extends ConsumerState<SupportEscalationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedCategory = 'Lost access to phone number';

  final List<String> _categories = const [
    'Lost access to phone number',
    'Verification code never arrived',
    'Account collision / linking conflict',
    'Account locked or disabled',
    'Other authentication issue',
  ];

  @override
  void initState() {
    super.initState();
    final candidateEmail = widget.initialEmail ??
        ref.read(authTroubleshootingControllerProvider).value?.email ??
        ref.read(authServiceProvider).currentUser?.email ??
        '';
    _emailController = TextEditingController(text: candidateEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _resolveMaskedIdentifier() {
    final phone = widget.initialPhone ??
        ref.read(authTroubleshootingControllerProvider).value?.phoneNumber ??
        ref.read(authServiceProvider).currentUser?.phoneNumber;
    if (phone != null && phone.isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        final last4 = digits.substring(digits.length - 4);
        return '+1 (•••) •••-$last4';
      }
      return phone;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty && email.contains('@')) {
      final parts = email.split('@');
      final name = parts[0];
      final domain = parts[1];
      if (name.length <= 2) {
        return '${name[0]}*@$domain';
      }
      return '${name.substring(0, 2)}••••@$domain';
    }

    return 'Guest / Unauthenticated';
  }

  String _resolvePlatformName() {
    if (kIsWeb) return 'Web Client';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'Apple iOS';
      case TargetPlatform.android:
        return 'Google Android';
      case TargetPlatform.macOS:
        return 'Apple macOS';
      case TargetPlatform.windows:
        return 'Microsoft Windows';
      case TargetPlatform.linux:
        return 'Linux Desktop';
      case TargetPlatform.fuchsia:
        return 'Fuchsia OS';
    }
  }

  Future<void> _submitEscalation() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final contactEmail = _emailController.text.trim();
    final description = _descriptionController.text.trim();
    final platform = _resolvePlatformName();
    final maskedId = _resolveMaskedIdentifier();

    final diagnostics = <String, dynamic>{
      'platform': platform,
      'appVersion': '1.0.0+1',
      'category': _selectedCategory,
      'maskedIdentifier': maskedId,
      'submittedAt': DateTime.now().toIso8601String(),
    };

    final ticketId = await ref
        .read(authTroubleshootingControllerProvider.notifier)
        .submitSupportEscalation(
          contactEmail: contactEmail,
          reason: '[$_selectedCategory] $description',
          diagnostics: diagnostics,
        );

    if (ticketId != null && mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.onyxSurface,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.md,
            side: const BorderSide(color: AppTheme.goldBorder, width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.spaceSm),
                decoration: BoxDecoration(
                  color: AppTheme.goldContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.gold),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.gold,
                  size: 20,
                ),
              ),
              AppGaps.gapSm,
              Expanded(
                child: Text(
                  'Ticket Received',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your account recovery escalation ticket has been dispatched to Flash.Ink Concierge.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.navInactive,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              AppGaps.gapMd,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.spaceSm),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: AppBorderRadius.md,
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TICKET REFERENCE',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.navInactive,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    AppGaps.gapXxs,
                    Text(
                      ticketId,
                      key: const Key('support_ticket_id_text'),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            AppButtons.primaryCTA(
              key: const Key('support_ticket_done_button'),
              text: 'Done',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
                FlashSnackBar.showSuccess(
                  context,
                  'Ticket $ticketId opened. We will contact you within 24 hours.',
                );
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authTroubleshootingControllerProvider);
    final status = state.value?.status ?? AuthTroubleshootingStatus.idle;
    final isBusy = status == AuthTroubleshootingStatus.verifying;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PinnedBottomActionScaffold(
        appBar: const FlashGlassAppBar(
          title: Text('Contact Support'),
          showBackButton: true,
        ),
        backgroundColor: AppTheme.onyxBackground,
        ctaText: 'Submit Escalation Ticket',
        ctaKey: const Key('support_submit_button'),
        isCtaLoading: isBusy,
        isCtaEnabled: !isBusy,
        onCtaPressed: _submitEscalation,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Account Concierge',
                  style: AppTypography.heroTitle.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                AppGaps.gapXs,
                Text(
                  'If you have lost access to your primary phone and backup email, our security team can manually verify your identity.',
                  style: AppTypography.heroSubtitle.copyWith(
                    color: AppTheme.navInactive,
                  ),
                ),
                AppGaps.gapLg,

                // Non-editable diagnostic badges card
                Container(
                  key: const Key('support_diagnostics_card'),
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: AppBorderRadius.md,
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.phonelink_setup_rounded,
                            color: AppTheme.gold,
                            size: 16,
                          ),
                          AppGaps.gapXs,
                          Text(
                            'ATTACHED SYSTEM DIAGNOSTICS',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      AppGaps.gapSm,
                      Wrap(
                        spacing: AppSpacing.spaceSm,
                        runSpacing: AppSpacing.spaceXs,
                        children: [
                          _buildDiagnosticBadge(
                            label: 'App',
                            value: 'v1.0.0+1',
                            icon: Icons.apps_rounded,
                          ),
                          _buildDiagnosticBadge(
                            label: 'Platform',
                            value: _resolvePlatformName(),
                            icon: Icons.devices_rounded,
                          ),
                          _buildDiagnosticBadge(
                            label: 'Target',
                            value: _resolveMaskedIdentifier(),
                            icon: Icons.fingerprint_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AppGaps.gapLg,

                // Contact Email field
                Text(
                  'Contact Email Address',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppGaps.gapXs,
                TextFormField(
                  key: const Key('support_contact_email_field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  validator: (v) {
                    final trimmed = v?.trim() ?? '';
                    if (trimmed.isEmpty || !trimmed.contains('@')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Where can our concierge team reach you?',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: AppTheme.gold,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: AppTheme.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: AppBorderRadius.md,
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppBorderRadius.md,
                      borderSide: const BorderSide(
                        color: AppTheme.gold,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                AppGaps.gapMd,

                // Issue Category Dropdown
                Text(
                  'Issue Category',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppGaps.gapXs,
                DropdownButtonFormField<String>(
                  key: const Key('support_category_dropdown'),
                  initialValue: _selectedCategory,
                  dropdownColor: AppTheme.onyxSurface,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: AppBorderRadius.md,
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppBorderRadius.md,
                      borderSide: const BorderSide(
                        color: AppTheme.gold,
                        width: 1.5,
                      ),
                    ),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                    }
                  },
                ),
                AppGaps.gapMd,

                // Issue Description textarea
                Text(
                  'Description & Context',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppGaps.gapXs,
                TextFormField(
                  key: const Key('support_description_field'),
                  controller: _descriptionController,
                  minLines: 4,
                  maxLines: 6,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  validator: (v) {
                    final trimmed = v?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Please describe the issue you are experiencing';
                    }
                    if (trimmed.length < 10) {
                      return 'Please provide a little more detail (at least 10 characters)';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Explain your issue, prior phone number, and any associated booking/artist references...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppTheme.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: AppBorderRadius.md,
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppBorderRadius.md,
                      borderSide: const BorderSide(
                        color: AppTheme.gold,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                AppGaps.gapLg,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticBadge({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceSm,
        vertical: AppSpacing.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.onyxContainer,
        borderRadius: AppBorderRadius.md,
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.navInactive, size: 14),
          AppGaps.gapXxs,
          Text(
            '$label: ',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.navInactive,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

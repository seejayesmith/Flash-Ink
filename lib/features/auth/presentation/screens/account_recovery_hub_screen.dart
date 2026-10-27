import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/adaptive_glass_container.dart';
import '../../../../widgets/fade_page_route.dart';
import '../../../../widgets/flash_glass_app_bar.dart';
import '../../../../widgets/flash_snack_bar.dart';
import '../controllers/auth_troubleshooting_controller.dart';
import 'support_escalation_screen.dart';

/// Standalone hub presenting triage options for users encountering sign-in,
/// phone number loss, OTP delivery, or authentication method issues.
class AccountRecoveryHubScreen extends ConsumerStatefulWidget {
  const AccountRecoveryHubScreen({super.key});

  @override
  ConsumerState<AccountRecoveryHubScreen> createState() =>
      _AccountRecoveryHubScreenState();
}

class _AccountRecoveryHubScreenState
    extends ConsumerState<AccountRecoveryHubScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPhoneController = TextEditingController();
  final TextEditingController _lookupController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPhoneController.dispose();
    _lookupController.dispose();
    super.dispose();
  }

  void _showChangedPhoneNumberFlow() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
        ),
        child: Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(authTroubleshootingControllerProvider);
            final status = state.value?.status ?? AuthTroubleshootingStatus.idle;
            final isBusy = status == AuthTroubleshootingStatus.sendingCode ||
                status == AuthTroubleshootingStatus.verifying;

            return AdaptiveGlassContainer.bottomSheet(
              key: const Key('recovery_phone_update_sheet'),
              glassEnabled: false,
              androidSurfaceColor: AppTheme.onyxSurface,
              selectedBorderColor: AppTheme.gold,
              unselectedBorderColor: AppTheme.goldBorder,
              selectedBorderWidth: 1.5,
              unselectedBorderWidth: 1.5,
              topRadius: AppRadius.radiusSheet,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin,
                    AppSpacing.spaceSm,
                    AppSpacing.screenMargin,
                    AppSpacing.ctaBottomPadding,
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFF333838),
                              borderRadius: BorderRadius.circular(AppRadius.dragHandle),
                            ),
                          ),
                        ),
                        AppGaps.gapMd,
                        Text(
                          'Update Phone Number',
                          style: AppTypography.h4.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppGaps.gapXxs,
                        Text(
                          status == AuthTroubleshootingStatus.accountMatched
                              ? 'Account matched! Enter your new mobile phone number.'
                              : 'Verify ownership using your backup email to link your new mobile number.',
                          style: AppTypography.heroSubtitle.copyWith(
                            color: AppTheme.navInactive,
                            fontSize: 13,
                          ),
                        ),
                        AppGaps.gapMd,

                        if (state.value?.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.spaceSm),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withAlpha(25),
                              borderRadius: AppBorderRadius.md,
                              border: Border.all(
                                color: const Color(0xFFEF4444).withAlpha(120),
                              ),
                            ),
                            child: Text(
                              state.value!.errorMessage!,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFEF4444),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          AppGaps.gapSm,
                        ],

                        if (status == AuthTroubleshootingStatus.accountMatched) ...[
                          TextFormField(
                            key: const Key('recovery_new_phone_field'),
                            controller: _newPhoneController,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'New phone number (e.g. +1 555 019 2834)',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: AppTheme.navInactive,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.phone_android,
                                color: AppTheme.gold,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: AppTheme.cardBackground,
                              border: OutlineInputBorder(
                                borderRadius: AppBorderRadius.md,
                                borderSide: const BorderSide(
                                  color: AppTheme.cardBorder,
                                ),
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
                          AppButtons.primaryCTA(
                            key: const Key('recovery_submit_new_phone_button'),
                            text: 'Save & Update Number',
                            isLoading: isBusy,
                            onPressed: isBusy
                                ? null
                                : () async {
                                    final phone = _newPhoneController.text.trim();
                                    if (phone.isEmpty) return;
                                    await ref
                                        .read(
                                          authTroubleshootingControllerProvider
                                              .notifier,
                                        )
                                        .updateUserPhoneNumber(phoneNumber: phone);
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                      FlashSnackBar.showSuccess(
                                        context,
                                        'Phone number updated successfully.',
                                      );
                                    }
                                  },
                          ),
                        ] else if (status ==
                                AuthTroubleshootingStatus.codeSent ||
                            _otpController.text.isNotEmpty) ...[
                          TextFormField(
                            key: const Key('recovery_otp_field'),
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              letterSpacing: 4,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Enter 6-digit OTP',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: AppTheme.navInactive,
                                fontSize: 13,
                                letterSpacing: 0,
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_clock_outlined,
                                color: AppTheme.gold,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: AppTheme.cardBackground,
                              border: OutlineInputBorder(
                                borderRadius: AppBorderRadius.md,
                                borderSide: const BorderSide(
                                  color: AppTheme.cardBorder,
                                ),
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
                          AppButtons.primaryCTA(
                            key: const Key('recovery_verify_otp_button'),
                            text: 'Verify Code',
                            isLoading: isBusy,
                            onPressed: isBusy
                                ? null
                                : () async {
                                    await ref
                                        .read(
                                          authTroubleshootingControllerProvider
                                              .notifier,
                                        )
                                        .verifySecondaryEmailOtp(
                                          email: _emailController.text.trim(),
                                          code: _otpController.text.trim(),
                                        );
                                  },
                          ),
                        ] else ...[
                          TextFormField(
                            key: const Key('recovery_email_field'),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Secondary or recovery email',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: AppTheme.navInactive,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.alternate_email,
                                color: AppTheme.gold,
                                size: 18,
                              ),
                              filled: true,
                              fillColor: AppTheme.cardBackground,
                              border: OutlineInputBorder(
                                borderRadius: AppBorderRadius.md,
                                borderSide: const BorderSide(
                                  color: AppTheme.cardBorder,
                                ),
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
                          AppButtons.primaryCTA(
                            key: const Key('recovery_send_otp_button'),
                            text: 'Send Verification OTP',
                            isLoading: isBusy,
                            onPressed: isBusy
                                ? null
                                : () async {
                                    final email = _emailController.text.trim();
                                    if (email.isEmpty) return;
                                    await ref
                                        .read(
                                          authTroubleshootingControllerProvider
                                              .notifier,
                                        )
                                        .sendSecondaryEmailOtp(email);
                                  },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showForgotLoginMethodDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: AdaptiveGlassContainer.bottomSheet(
          key: const Key('recovery_forgot_method_sheet'),
          glassEnabled: false,
          androidSurfaceColor: AppTheme.onyxSurface,
          topRadius: AppRadius.radiusSheet,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                AppSpacing.spaceSm,
                AppSpacing.screenMargin,
                AppSpacing.ctaBottomPadding,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF333838),
                          borderRadius: BorderRadius.circular(AppRadius.dragHandle),
                        ),
                      ),
                    ),
                    AppGaps.gapMd,
                    Text(
                      'Find Your Account',
                      style: AppTypography.h4.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppGaps.gapXxs,
                    Text(
                      'Enter any email or phone number you may have used with Flash.Ink.',
                      style: AppTypography.heroSubtitle.copyWith(
                        color: AppTheme.navInactive,
                        fontSize: 13,
                      ),
                    ),
                    AppGaps.gapMd,
                    TextFormField(
                      key: const Key('recovery_lookup_field'),
                      controller: _lookupController,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Email or phone number',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: AppTheme.navInactive,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppTheme.gold,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: AppTheme.cardBackground,
                        border: OutlineInputBorder(
                          borderRadius: AppBorderRadius.md,
                          borderSide: const BorderSide(
                            color: AppTheme.cardBorder,
                          ),
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
                    AppButtons.primaryCTA(
                      key: const Key('recovery_lookup_button'),
                      text: 'Check Account Identifier',
                      onPressed: () {
                        final val = _lookupController.text.trim();
                        Navigator.of(sheetContext).pop();
                        if (val.isNotEmpty) {
                          FlashSnackBar.showSuccess(
                            context,
                            'Lookup submitted for "$val". If an account matches, a sign-in link or instructions have been dispatched.',
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showShortCodeDiagnosticModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AdaptiveGlassContainer.bottomSheet(
        key: const Key('recovery_diagnostic_sheet'),
        glassEnabled: false,
        androidSurfaceColor: AppTheme.onyxSurface,
        topRadius: AppRadius.radiusSheet,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenMargin,
              AppSpacing.spaceSm,
              AppSpacing.screenMargin,
              AppSpacing.ctaBottomPadding,
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF333838),
                        borderRadius: BorderRadius.circular(AppRadius.dragHandle),
                      ),
                    ),
                  ),
                  AppGaps.gapMd,
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.spaceSm),
                        decoration: BoxDecoration(
                          color: AppTheme.goldContainer,
                          borderRadius: AppBorderRadius.md,
                          border: Border.all(
                            color: AppTheme.goldBorder,
                            width: 1.0,
                          ),
                        ),
                        child: const Icon(
                          Icons.network_check_rounded,
                          color: AppTheme.gold,
                          size: 22,
                        ),
                      ),
                      AppGaps.gapSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carrier Short-Code Diagnostics',
                              style: AppTypography.h4.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            AppGaps.gapXxs,
                            Text(
                              'Common SMS blocking issues & troubleshooting checklist',
                              style: AppTypography.heroSubtitle.copyWith(
                                color: AppTheme.navInactive,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  AppGaps.gapMd,
                  _buildDiagnosticCheckItem(
                    title: 'Short-Code Blocking Active',
                    description:
                        'Some mobile carriers (T-Mobile, Verizon, AT&T) block automated verification short-codes by default. Text "HELP" or "ALLOW" to 22395 or call your carrier to unblock.',
                  ),
                  AppGaps.gapSm,
                  _buildDiagnosticCheckItem(
                    title: 'Do Not Disturb & Spam Filtering',
                    description:
                        'Check your messaging app spam / blocked numbers folder or third-party spam call blocker apps (Truecaller, RoboKiller).',
                  ),
                  AppGaps.gapSm,
                  _buildDiagnosticCheckItem(
                    title: 'Roaming / International Plans',
                    description:
                        'If traveling abroad or using VoIP/Google Voice numbers, automated SMS delivery may fail. Use secondary email verification instead.',
                  ),
                  AppGaps.gapLg,
                  AppButtons.primaryCTA(
                    key: const Key('recovery_diagnostic_done_button'),
                    text: 'Understood',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticCheckItem({
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: AppBorderRadius.md,
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppTheme.gold,
            size: 20,
          ),
          AppGaps.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppGaps.gapXxs,
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.navInactive,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.onyxBackground,
        appBar: const FlashGlassAppBar(
          title: Text('Account Recovery'),
        ),
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenMargin,
            AppSpacing.headerTop,
            AppSpacing.screenMargin,
            AppSpacing.ctaBottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Trouble Signing In?',
                style: AppTypography.heroTitle.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              AppGaps.gapXs,
              Text(
                'Select the issue you are experiencing to recover your Flash.Ink account.',
                style: AppTypography.heroSubtitle.copyWith(
                  color: AppTheme.navInactive,
                ),
              ),
              AppGaps.gapLg,

              // Option 1: Changed phone number
              _buildRecoveryMenuCard(
                key: const Key('hub_changed_phone_option'),
                icon: Icons.phonelink_setup_rounded,
                title: 'Changed phone number',
                subtitle:
                    'Verify your identity via secondary email and update your primary mobile number.',
                onTap: _showChangedPhoneNumberFlow,
              ),
              AppGaps.gapMd,

              // Option 2: Forgot login method
              _buildRecoveryMenuCard(
                key: const Key('hub_forgot_method_option'),
                icon: Icons.person_search_rounded,
                title: 'Forgot login method',
                subtitle:
                    'Check which email, phone, Google, or Apple ID is linked to your account.',
                onTap: _showForgotLoginMethodDialog,
              ),
              AppGaps.gapMd,

              // Option 3: Code never arrived
              _buildRecoveryMenuCard(
                key: const Key('hub_code_never_arrived_option'),
                icon: Icons.sms_failed_outlined,
                title: 'Code never arrived',
                subtitle:
                    'Carrier short-code diagnostic tool and troubleshooting checklist.',
                onTap: _showShortCodeDiagnosticModal,
              ),
              AppGaps.gapMd,

              // Option 4: Contact support
              _buildRecoveryMenuCard(
                key: const Key('hub_contact_support_option'),
                icon: Icons.support_agent_rounded,
                title: 'Contact Support',
                subtitle:
                    'Submit an escalation ticket to Flash.Ink Concierge for manual account verification.',
                onTap: () {
                  Navigator.of(context).push(
                    FadePageRoute(
                      builder: (_) => const SupportEscalationScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecoveryMenuCard({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: AppBorderRadius.md,
        border: Border.all(color: AppTheme.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.onyxContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.goldBorder),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.gold,
                    size: 22,
                  ),
                ),
                AppGaps.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppGaps.gapXxs,
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.navInactive,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppTheme.navInactive,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/adaptive_glass_container.dart';
import '../../../../widgets/fade_page_route.dart';
import '../screens/account_recovery_hub_screen.dart';

/// Modal bottom sheet invoked from the verification screen when an OTP code
/// has not arrived or cooldown has elapsed.
class DeliveryTroubleshootingSheet extends ConsumerWidget {
  final String destination;
  final bool isPhone;
  final VoidCallback? onEditDestination;
  final VoidCallback? onResendSms;
  final VoidCallback? onWhatsAppVoice;
  final VoidCallback? onSwitchToEmail;

  const DeliveryTroubleshootingSheet({
    super.key,
    required this.destination,
    this.isPhone = true,
    this.onEditDestination,
    this.onResendSms,
    this.onWhatsAppVoice,
    this.onSwitchToEmail,
  });

  /// Displays the delivery troubleshooting modal bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required String destination,
    bool isPhone = true,
    VoidCallback? onEditDestination,
    VoidCallback? onResendSms,
    VoidCallback? onWhatsAppVoice,
    VoidCallback? onSwitchToEmail,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DeliveryTroubleshootingSheet(
          destination: destination,
          isPhone: isPhone,
          onEditDestination: onEditDestination,
          onResendSms: onResendSms,
          onWhatsAppVoice: onWhatsAppVoice,
          onSwitchToEmail: onSwitchToEmail,
        ),
      ),
    );
  }

  String _maskDestination(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'your destination';
    if (!isPhone && trimmed.contains('@')) {
      final parts = trimmed.split('@');
      final name = parts[0];
      final domain = parts[1];
      if (name.length <= 2) {
        return '${name[0]}*@$domain';
      }
      return '${name.substring(0, 2)}••••@$domain';
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final last4 = digits.substring(digits.length - 4);
      final area = digits.length == 11 && digits.startsWith('1')
          ? digits.substring(1, 4)
          : digits.substring(0, 3);
      return '+1 ($area) •••-$last4';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdaptiveGlassContainer.bottomSheet(
      key: const Key('delivery_troubleshooting_sheet'),
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
                // Drag handle
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

                // Header icon & titles
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        Icons.mark_email_unread_outlined,
                        color: AppTheme.gold,
                        size: 24,
                      ),
                    ),
                    AppGaps.gapSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Didn't receive a code?",
                            style: AppTypography.h4.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AppGaps.gapXxs,
                          Text(
                            'Choose an alternative delivery channel or verify your contact info.',
                            style: AppTypography.heroSubtitle.copyWith(
                              color: AppTheme.navInactive,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                AppGaps.gapMd,

                // Destination Card with inline Edit action
                Container(
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: AppBorderRadius.md,
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPhone ? Icons.phone_iphone : Icons.alternate_email,
                        color: AppTheme.navInactive,
                        size: 20,
                      ),
                      AppGaps.gapSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPhone ? 'Sent to mobile number' : 'Sent to email',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.navInactive,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            AppGaps.gapXxs,
                            Text(
                              _maskDestination(destination),
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        key: const Key('delivery_edit_destination_button'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onEditDestination?.call();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.gold,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.spaceSm,
                            vertical: AppSpacing.spaceXxs,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Edit',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppGaps.gapMd,

                // Channel Options List
                _buildChannelTile(
                  key: const Key('delivery_resend_sms_option'),
                  icon: Icons.sms_outlined,
                  title: 'Resend SMS code',
                  subtitle: 'Send a fresh 6-digit text message to this device',
                  onTap: () {
                    Navigator.of(context).pop();
                    onResendSms?.call();
                  },
                ),
                AppGaps.gapSm,
                _buildChannelTile(
                  key: const Key('delivery_voice_option'),
                  icon: Icons.phone_in_talk_outlined,
                  title: 'Voice Call verification',
                  subtitle: 'Receive an automated phone call dictating your code',
                  onTap: () {
                    Navigator.of(context).pop();
                    onWhatsAppVoice?.call();
                  },
                ),
                AppGaps.gapSm,
                _buildChannelTile(
                  key: const Key('delivery_switch_email_option'),
                  icon: Icons.mail_outline_rounded,
                  title: 'Switch to backup email',
                  subtitle: 'Verify using your linked recovery email address',
                  onTap: () {
                    Navigator.of(context).pop();
                    onSwitchToEmail?.call();
                  },
                ),
                AppGaps.gapLg,

                // Triage link to Account Recovery Hub
                Center(
                  child: TextButton.icon(
                    key: const Key('delivery_recovery_hub_link'),
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.push(
                        FadePageRoute(
                          builder: (_) => const AccountRecoveryHubScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      color: AppTheme.gold,
                      size: 16,
                    ),
                    label: Text(
                      'I no longer have access to this number',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.gold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelTile({
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
        border: Border.all(color: AppTheme.cardBorder),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.onyxContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.textPrimary,
                    size: 18,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppGaps.gapXxs,
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.navInactive,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.navInactive,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/adaptive_glass_container.dart';
import '../../../../widgets/flash_snack_bar.dart';
import '../controllers/auth_troubleshooting_controller.dart';

/// Modal bottom sheet presented when an authentication provider collision is
/// detected (Firebase `account-exists-with-different-credential`).
class AccountCollisionSheet extends ConsumerWidget {
  final String email;
  final String existingProvider;
  final String newProvider;
  final AuthCredential? pendingCredential;
  final AuthCredential? existingCredential;
  final VoidCallback? onCollisionResolved;

  const AccountCollisionSheet({
    super.key,
    required this.email,
    required this.existingProvider,
    required this.newProvider,
    this.pendingCredential,
    this.existingCredential,
    this.onCollisionResolved,
  });

  /// Displays the account collision resolution sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required String email,
    required String existingProvider,
    required String newProvider,
    AuthCredential? pendingCredential,
    AuthCredential? existingCredential,
    VoidCallback? onCollisionResolved,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AccountCollisionSheet(
          email: email,
          existingProvider: existingProvider,
          newProvider: newProvider,
          pendingCredential: pendingCredential,
          existingCredential: existingCredential,
          onCollisionResolved: onCollisionResolved,
        ),
      ),
    );
  }

  String _formatProviderName(String provider) {
    final lower = provider.toLowerCase();
    if (lower.contains('google')) return 'Google';
    if (lower.contains('apple')) return 'Apple';
    if (lower.contains('phone')) return 'Phone Number';
    if (lower.contains('password') || lower.contains('email')) {
      return 'Email & Password';
    }
    return provider;
  }

  IconData _providerIcon(String provider) {
    final lower = provider.toLowerCase();
    if (lower.contains('google')) return Icons.g_mobiledata_rounded;
    if (lower.contains('apple')) return Icons.apple;
    if (lower.contains('phone')) return Icons.phone_iphone_rounded;
    return Icons.lock_outline_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authTroubleshootingControllerProvider);
    final status = state.value?.status ?? AuthTroubleshootingStatus.idle;
    final isBusy = status == AuthTroubleshootingStatus.verifying;

    final formattedExisting = _formatProviderName(existingProvider);
    final formattedNew = _formatProviderName(newProvider);

    return AdaptiveGlassContainer.bottomSheet(
      key: const Key('account_collision_sheet'),
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

                // Collision warning icon & header
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
                        Icons.link_rounded,
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
                            'Account Already Exists',
                            key: const Key('account_collision_title'),
                            style: AppTypography.h4.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AppGaps.gapXxs,
                          Text(
                            'Link your credentials to merge both sign-in methods.',
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

                // Explicit required collision copy
                Container(
                  key: const Key('account_collision_message_card'),
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: AppBorderRadius.md,
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'An account with '),
                            TextSpan(
                              text: email,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.gold,
                              ),
                            ),
                            const TextSpan(text: ' already exists using '),
                            TextSpan(
                              text: formattedExisting,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const TextSpan(text: '. Sign in with '),
                            TextSpan(
                              text: formattedExisting,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.gold,
                              ),
                            ),
                            const TextSpan(text: ' to link your '),
                            TextSpan(
                              text: formattedNew,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const TextSpan(text: ' credentials.'),
                          ],
                        ),
                      ),
                      AppGaps.gapMd,

                      // Visual link illustration between providers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildProviderPill(formattedExisting),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.spaceSm,
                            ),
                            child: Icon(
                              Icons.sync_alt_rounded,
                              color: AppTheme.gold,
                              size: 20,
                            ),
                          ),
                          _buildProviderPill(formattedNew),
                        ],
                      ),
                    ],
                  ),
                ),
                AppGaps.gapMd,

                // Error banner if linking failed
                if (state.value?.errorMessage != null) ...[
                  Container(
                    key: const Key('account_collision_error_banner'),
                    padding: const EdgeInsets.all(AppSpacing.spaceSm),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withAlpha(25),
                      borderRadius: AppBorderRadius.md,
                      border: Border.all(
                        color: const Color(0xFFEF4444).withAlpha(120),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFEF4444),
                          size: 18,
                        ),
                        AppGaps.gapSm,
                        Expanded(
                          child: Text(
                            state.value!.errorMessage!,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFEF4444),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppGaps.gapMd,
                ],

                // Primary CTA: Sign in with [Provider] and link
                AppButtons.primaryCTA(
                  key: const Key('account_collision_primary_cta'),
                  text: 'Sign in with $formattedExisting to Link',
                  icon: _providerIcon(existingProvider),
                  isLoading: isBusy,
                  onPressed: isBusy
                      ? null
                      : () async {
                          if (pendingCredential != null) {
                            final result = await ref
                                .read(
                                  authTroubleshootingControllerProvider.notifier,
                                )
                                .resolveAccountCollision(
                                  credential: pendingCredential!,
                                  existingCredential: existingCredential,
                                );
                            if (result != null && context.mounted) {
                              try {
                                FlashSnackBar.showSuccess(
                                  context,
                                  'Accounts linked successfully!',
                                );
                              } catch (_) {}
                              Navigator.of(context).pop(true);
                              onCollisionResolved?.call();
                            }
                          } else {
                            Navigator.of(context).pop(true);
                            onCollisionResolved?.call();
                          }
                        },
                ),
                AppGaps.gapSm,

                // Secondary CTA: Cancel
                Center(
                  child: TextButton(
                    key: const Key('account_collision_cancel_button'),
                    onPressed: isBusy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(
                      'Use a different account',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.navInactive,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

  Widget _buildProviderPill(String providerName) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceSm,
        vertical: AppSpacing.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.onyxContainer,
        borderRadius: AppBorderRadius.pill,
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _providerIcon(providerName),
            color: AppTheme.gold,
            size: 16,
          ),
          AppGaps.gapXxs,
          Text(
            providerName,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

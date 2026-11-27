import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../repositories/artist_dashboard_repository.dart';
import '../../services/stripe_service.dart';
import '../../theme/app_buttons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_snack_bar.dart';

/// Bottom sheet displayed whenever an artist attempts to open their books or
/// launch a Book Drop before completing Stripe Connect payout verification.
class StripePayoutGateSheet extends StatefulWidget {
  final StripeService? stripeService;
  final String? artistName;
  final String? artistEmail;
  final VoidCallback? onVerified;

  const StripePayoutGateSheet({
    super.key,
    this.stripeService,
    this.artistName,
    this.artistEmail,
    this.onVerified,
  });

  static Future<bool?> show(
    BuildContext context, {
    StripeService? stripeService,
    String? artistName,
    String? artistEmail,
    VoidCallback? onVerified,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StripePayoutGateSheet(
        stripeService: stripeService,
        artistName: artistName,
        artistEmail: artistEmail,
        onVerified: onVerified,
      ),
    );
  }

  @override
  State<StripePayoutGateSheet> createState() => _StripePayoutGateSheetState();
}

class _StripePayoutGateSheetState extends State<StripePayoutGateSheet>
    with WidgetsBindingObserver {
  late final StripeService _stripeService =
      widget.stripeService ?? StripeService();

  bool _isLoading = false;
  bool _awaitingBrowserReturn = false;
  bool _hasLaunchedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingBrowserReturn) {
      _awaitingBrowserReturn = false;
      _checkVerificationStatus();
    }
  }

  Future<void> _launchConnect() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final result = await _stripeService.launchStripeConnectOnboarding(
        email: widget.artistEmail,
        artistName: widget.artistName,
      );
      if (!mounted) return;

      if (result.hasError) {
        FlashSnackBar.showError(
          context,
          result.errorMessage ?? 'Could not open Stripe setup right now.',
        );
        return;
      }

      if (result.stripePayoutsReady) {
        ArtistDashboardRepository.stripePayoutsReady = true;
        Navigator.pop(context, true);
        widget.onVerified?.call();
        return;
      }

      setState(() {
        _hasLaunchedOnce = true;
        _awaitingBrowserReturn = !result.isSimulated;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkVerificationStatus() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final status = await _stripeService.syncStripeConnectStatus();
      if (!mounted) return;

      if (status.hasError) {
        FlashSnackBar.showError(
          context,
          status.errorMessage ?? 'Unable to verify Stripe status right now.',
        );
        return;
      }

      if (status.stripePayoutsReady) {
        ArtistDashboardRepository.stripePayoutsReady = true;
        FlashSnackBar.showSuccess(
          context,
          'Stripe payouts verified! You can now open your books.',
        );
        Navigator.pop(context, true);
        widget.onVerified?.call();
      } else if (status.isPendingVerification) {
        FlashSnackBar.showInfo(
          context,
          'Stripe received your details and is finishing verification.',
        );
      } else {
        FlashSnackBar.showInfo(
          context,
          'Stripe setup is not complete yet. Tap Connect Stripe Account to finish.',
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
    return AdaptiveGlassContainer.bottomSheet(
      key: const Key('stripe_payout_gate_sheet'),
      glassEnabled: false,
      androidSurfaceColor: const Color(0xFF181A1A),
      topRadius: AppRadius.radiusSheet,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF333737),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF262112),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.gold.withAlpha(120)),
                    ),
                    child: const Icon(
                      Icons.lock_clock_outlined,
                      color: AppTheme.gold,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Connect Stripe to Open Your Books',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Clients pay booking deposits through Stripe Connect when claiming flash or confirming appointments. Link an existing Stripe account or create a new one first to open your books.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  color: const Color(0xFFB0B6B6),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              AppButtons.primaryCTA(
                key: const Key('gate_connect_stripe_button'),
                text: _hasLaunchedOnce
                    ? 'Continue Stripe Setup'
                    : 'Connect Stripe Account',
                icon: Icons.open_in_new_rounded,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _launchConnect,
                backgroundColor: AppTheme.gold,
                foregroundColor: const Color(0xFF121414),
              ),
              const SizedBox(height: 10),
              AppButtons.secondaryCTA(
                key: const Key('gate_refresh_stripe_button'),
                text: 'I finished — Check Status',
                onPressed: _isLoading ? null : _checkVerificationStatus,
                borderColor: const Color(0xFF383C3C),
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF1F2222),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  key: const Key('gate_dismiss_button'),
                  onPressed:
                      _isLoading ? null : () => Navigator.pop(context, false),
                  child: Text(
                    'Not now',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C9191),
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
    );
  }
}

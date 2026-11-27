import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/onboarding/shared/onboarding_step_scaffold.dart';
import '../../models/artist.dart';
import '../../models/studio_information.dart';
import '../../repositories/artist_dashboard_repository.dart';
import '../../services/auth_service.dart';
import '../../services/stripe_service.dart';
import '../../theme/app_buttons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/fade_page_route.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import 'artist_share_link_screen.dart';

/// Step 9 of 10 in Artist Onboarding: Connect or create a live Stripe Express
/// payout account, or defer setup until later (with explicit notice that books
/// remain locked closed until Stripe verification is completed).
class ArtistStripeSetupScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String? instagramHandle;
  final int? minDeposit;
  final List<FlashArtwork> flashArtworks;
  final List<String> identityTags;
  final List<String> styleTags;
  final AuthService? authService;
  final FirebaseFirestore? firestore;
  final StudioInformation? studioInformation;
  final String? artistBio;
  final List<StudioPolicy>? policies;
  final StripeService? stripeService;

  const ArtistStripeSetupScreen({
    super.key,
    required this.artistName,
    this.photoBytes,
    this.photoUrl,
    this.instagramHandle,
    this.minDeposit,
    this.flashArtworks = const [],
    this.identityTags = const [],
    this.styleTags = const [],
    this.authService,
    this.firestore,
    this.studioInformation,
    this.artistBio,
    this.policies,
    this.stripeService,
  });

  @override
  State<ArtistStripeSetupScreen> createState() =>
      _ArtistStripeSetupScreenState();
}

class _ArtistStripeSetupScreenState extends State<ArtistStripeSetupScreen>
    with WidgetsBindingObserver {
  late final StripeService _stripeService =
      widget.stripeService ?? StripeService();

  StripeConnectAccountStatus _status = const StripeConnectAccountStatus();
  bool _isLaunchingOrChecking = false;
  bool _awaitingBrowserReturn = false;

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
      _refreshStripeStatus();
    }
  }

  String? _resolveArtistEmail() {
    try {
      final effectiveAuth = widget.authService ?? AuthService();
      final email = effectiveAuth.currentUser?.email?.trim();
      if (email != null && email.isNotEmpty) return email;
    } catch (_) {}
    return null;
  }

  Future<void> _handleConnectStripe() async {
    if (_isLaunchingOrChecking) return;
    setState(() => _isLaunchingOrChecking = true);

    try {
      final result = await _stripeService.launchStripeConnectOnboarding(
        email: _resolveArtistEmail(),
        artistName: widget.artistName,
      );

      if (!mounted) return;

      if (result.hasError) {
        FlashSnackBar.showError(
          context,
          result.errorMessage ?? 'Unable to open Stripe setup right now.',
        );
        return;
      }

      setState(() {
        _status = result;
        _awaitingBrowserReturn = !result.isSimulated;
      });

      if (result.stripePayoutsReady) {
        ArtistDashboardRepository.stripePayoutsReady = true;
        FlashSnackBar.showSuccess(
          context,
          'Stripe account connected! Your payouts are ready.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunchingOrChecking = false);
      }
    }
  }

  Future<void> _refreshStripeStatus() async {
    if (_isLaunchingOrChecking) return;
    setState(() => _isLaunchingOrChecking = true);

    try {
      final refreshed = await _stripeService.syncStripeConnectStatus();
      if (!mounted) return;

      if (refreshed.hasError) {
        FlashSnackBar.showError(
          context,
          refreshed.errorMessage ?? 'Could not verify Stripe status.',
        );
        return;
      }

      setState(() => _status = refreshed);
      if (refreshed.stripePayoutsReady) {
        FlashSnackBar.showSuccess(
          context,
          'Stripe verified! You will be able to open your books right away.',
        );
      } else if (refreshed.isPendingVerification) {
        FlashSnackBar.showInfo(
          context,
          'Details received — Stripe is finishing verification.',
        );
      } else if (refreshed.isIncomplete) {
        FlashSnackBar.showInfo(
          context,
          'Stripe setup is still incomplete. Tap Continue Stripe Setup to finish.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunchingOrChecking = false);
      }
    }
  }

  void _proceedToShareScreen({required bool stripeConnected}) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(
      context,
      FadePageRoute(
        builder: (_) => ArtistShareLinkScreen(
          artistName: widget.artistName,
          photoBytes: widget.photoBytes,
          photoUrl: widget.photoUrl,
          instagramHandle: widget.instagramHandle,
          minDeposit: widget.minDeposit,
          flashArtworks: widget.flashArtworks,
          identityTags: widget.identityTags,
          styleTags: widget.styleTags,
          authService: widget.authService,
          firestore: widget.firestore,
          studioInformation: widget.studioInformation,
          artistBio: widget.artistBio,
          policies: widget.policies,
          stripePayoutsReady: stripeConnected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _status.stripePayoutsReady;

    return OnboardingStepScaffold(
      currentStep: 9,
      totalSteps: 10,
      onBack: Navigator.canPop(context)
          ? () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context);
            }
          : null,
      onSkip: () => _proceedToShareScreen(stripeConnected: isReady),
      skipKey: const Key('skip_stripe_setup_button'),
      skipText: 'Skip',
      title: 'Connect Stripe\nto get paid',
      subtitle:
          'Link an existing Stripe account or create a new one so clients can securely pay booking deposits.',
      backgroundOverlay:
          const TattooBackgroundWrapper(child: SizedBox.expand()),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isReady)
            AppButtons.primaryCTA(
              key: const Key('continue_stripe_connected_button'),
              text: 'Continue',
              onPressed: () => _proceedToShareScreen(stripeConnected: true),
              backgroundColor: AppTheme.gold,
              foregroundColor: const Color(0xFF121414),
            )
          else ...[
            AppButtons.primaryCTA(
              key: const Key('connect_stripe_onboarding_button'),
              text: _status.hasAccount
                  ? 'Continue Stripe Setup'
                  : 'Connect or Create Stripe Account',
              icon: Icons.open_in_new_rounded,
              isLoading: _isLaunchingOrChecking,
              onPressed: _isLaunchingOrChecking ? null : _handleConnectStripe,
              backgroundColor: AppTheme.gold,
              foregroundColor: const Color(0xFF121414),
            ),
            const SizedBox(height: 10),
            AppButtons.secondaryCTA(
              key: const Key('do_stripe_later_button'),
              text: 'Do this later',
              onPressed: _isLaunchingOrChecking
                  ? null
                  : () => _proceedToShareScreen(stripeConnected: false),
              borderColor: const Color(0xFF383C3C),
              foregroundColor: const Color(0xFFE2E4E4),
              backgroundColor: const Color(0xFF161818),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdaptiveGlassContainer(
            useGradient: false,
            borderRadius: AppRadius.radiusLg,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF635BFF).withAlpha(36),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF635BFF).withAlpha(110),
                        ),
                      ),
                      child: const Icon(
                        Icons.account_balance_outlined,
                        color: Color(0xFFA5A0FF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Powered by Stripe Connect',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bank-grade payouts & tax reporting',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              color: const Color(0xFF919696),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildBenefitRow(
                  icon: Icons.link_rounded,
                  title: 'Link existing or create new',
                  description:
                      'Already use Stripe? Sign in to link it, or create a new Express account in ~3 minutes.',
                ),
                const SizedBox(height: 14),
                _buildBenefitRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Protected deposit escrow',
                  description:
                      'Client deposits are held safely and sent directly to your bank or debit card.',
                ),
                const SizedBox(height: 14),
                _buildBenefitRow(
                  icon: Icons.bolt_rounded,
                  title: '0% fee on your first 2 bookings',
                  description:
                      'Keep 100% of your platform fee allowance on your first two Flash.Ink bookings.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (isReady)
            _buildConnectedCard()
          else ...[
            if (_status.hasAccount) ...[
              _buildInProgressCard(),
              const SizedBox(height: 12),
            ],
            _buildBooksLockedNotice(),
          ],
        ],
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF262312),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: AppTheme.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF9FAFA),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: const Color(0xFF919696),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedCard() {
    return Container(
      key: const Key('stripe_connected_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13261B),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: const Color(0xFF22C55E).withAlpha(140)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF22C55E),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stripe Payouts Active',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _status.externalAccountLabel.isNotEmpty
                      ? 'Connected to ${_status.externalAccountLabel}. Your books are ready to open!'
                      : 'Your Stripe account is verified and ready to accept client deposits.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: const Color(0xFFB7E4C7),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInProgressCard() {
    return Container(
      key: const Key('stripe_pending_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: const Color(0xFF383C3C)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: AppTheme.gold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _status.isPendingVerification
                  ? 'Stripe is reviewing your details. Tap Refresh once complete.'
                  : 'Finished in your browser? Tap Refresh to verify your payout status.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: const Color(0xFFD0D5D5),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('refresh_stripe_status_button'),
            onPressed: _isLaunchingOrChecking ? null : _refreshStripeStatus,
            child: Text(
              'Refresh',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksLockedNotice() {
    return Container(
      key: const Key('stripe_books_locked_notice'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF262112),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppTheme.gold.withAlpha(110)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.lock_clock_outlined,
              color: AppTheme.gold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Books stay closed until Stripe is linked',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You can skip this for now to finish your profile and upload flash, '
                  'but you will not be able to open your books or launch a Book Drop without connecting Stripe.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: const Color(0xFFE2E4E4),
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
}

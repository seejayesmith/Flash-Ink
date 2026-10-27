import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist.dart';
import '../../models/studio_information.dart';
import '../../services/auth_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/fade_page_route.dart';
import '../../widgets/flow_page_layout.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import '../../features/onboarding/shared/onboarding_step_scaffold.dart';
import 'artist_flash_upload_screen.dart';

class ArtistSetPriceScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String instagramHandle;
  final AuthService? authService;
  final StudioInformation? studioInformation;
  final String? artistBio;
  final List<StudioPolicy>? policies;

  const ArtistSetPriceScreen({
    super.key,
    required this.artistName,
    this.photoBytes,
    this.photoUrl,
    this.instagramHandle = '',
    this.authService,
    this.studioInformation,
    this.artistBio,
    this.policies,
  });

  @override
  State<ArtistSetPriceScreen> createState() => _ArtistSetPriceScreenState();
}

class _ArtistSetPriceScreenState extends State<ArtistSetPriceScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  int get _depositAmount => int.tryParse(_controller.text) ?? 100;

  void _proceedToFlashUpload([int? depositOverride]) {
    FocusManager.instance.primaryFocus?.unfocus();
    final deposit = depositOverride ?? (_depositAmount > 0 ? _depositAmount : 100);
    Navigator.push(
      context,
      FadePageRoute(
        builder: (_) => ArtistFlashUploadScreen(
          artistName: widget.artistName,
          photoBytes: widget.photoBytes,
          photoUrl: widget.photoUrl,
          instagramHandle: widget.instagramHandle,
          minDeposit: deposit,
          authService: widget.authService,
          studioInformation: widget.studioInformation,
          artistBio: widget.artistBio,
          policies: widget.policies,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasInput = _controller.text.isNotEmpty;

    return OnboardingStepScaffold(
      currentStep: 5,
      totalSteps: 9,
      onBack: Navigator.canPop(context)
          ? () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context);
            }
          : null,
      onSkip: () => _proceedToFlashUpload(100),
      skipKey: const Key('skip_price_button'),
      skipText: 'Skip',
      title: 'Set your price',
      subtitle: 'Set your minimum deposit. This will be displayed on your profile.',
      ctaText: 'CONTINUE',
      ctaKey: const Key('continue_price_button'),
      onCtaPressed: () => _proceedToFlashUpload(),
      backgroundOverlay: const TattooBackgroundWrapper(child: SizedBox.expand()),
      child: FlowPageLayout(
        title: 'Set your price',
        subtitle: 'Set your minimum deposit. This will be displayed on your profile.',
        ctaText: 'CONTINUE',
        ctaKey: const Key('continue_price_button'),
        onCtaPressed: () => _proceedToFlashUpload(),
        renderInternalHeaderAndCTA: false,
        child: AdaptiveGlassContainer(
          useGradient: false,
          key: const Key('price_display_card'),
          borderRadius: 16,
          isSelected: _isFocused,
          onTap: () => _focusNode.requestFocus(),
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: AppSpacing.cardPadding),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '\$',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: hasInput ? const Color(0xFFF9FAFA) : const Color(0xFF505555),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasInput ? _controller.text : '100',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 68,
                      fontWeight: FontWeight.w800,
                      color: hasInput ? const Color(0xFFF9FAFA) : const Color(0xFF505555),
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0.0,
                  child: TextField(
                    key: const Key('price_text_field'),
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    scrollPadding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    autofocus: false,
                    enableInteractiveSelection: false,
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

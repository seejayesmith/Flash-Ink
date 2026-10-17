import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/artist_stepper_header.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import '../../widgets/skip_pill_button.dart';
import 'artist_flash_upload_screen.dart';

class ArtistSetPriceScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String instagramHandle;
  final AuthService? authService;

  const ArtistSetPriceScreen({
    super.key,
    required this.artistName,
    this.photoBytes,
    this.photoUrl,
    required this.instagramHandle,
    this.authService,
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
    FocusScope.of(context).unfocus();
    final deposit = depositOverride ?? (_depositAmount > 0 ? _depositAmount : 100);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistFlashUploadScreen(
          artistName: widget.artistName,
          photoBytes: widget.photoBytes,
          photoUrl: widget.photoUrl,
          instagramHandle: widget.instagramHandle,
          minDeposit: deposit,
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasInput = _controller.text.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: SkipPillButton(
                key: const Key('skip_price_button'),
                onPressed: () => _proceedToFlashUpload(100),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: TattooBackgroundWrapper(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ArtistStepperHeader(currentStep: 2),
                        const SizedBox(height: 24),

                        Text(
                          'Set your price',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF9FAFA),
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'Set your minimum deposit. This will be displayed on your profile.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            color: const Color(0xFF919696),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Price Display Card
                        AdaptiveGlassContainer(
                          key: const Key('price_display_card'),
                          borderRadius: 16,
                          isSelected: _isFocused,
                          onTap: () => _focusNode.requestFocus(),
                          padding: const EdgeInsets.symmetric(vertical: 28),
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
                        const SizedBox(height: 20),

                        // Continue Action
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            key: const Key('continue_price_button'),
                            onPressed: () => _proceedToFlashUpload(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEEC200),
                              foregroundColor: const Color(0xFF121414),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            child: Text(
                              'CONTINUE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
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
}

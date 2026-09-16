import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/dev_config.dart';
import '../../services/auth_service.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/artist_stepper_header.dart';
import '../../widgets/tattoo_background_wrapper.dart';
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
  String _priceInput = '100';

  int get _depositAmount => int.tryParse(_priceInput) ?? 100;

  void _onKeyPress(String value) {
    setState(() {
      if (_priceInput == '0' || _priceInput.isEmpty) {
        _priceInput = value;
      } else if (_priceInput.length < 5) {
        _priceInput += value;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_priceInput.isNotEmpty) {
        _priceInput = _priceInput.substring(0, _priceInput.length - 1);
      }
    });
  }

  void _proceedToFlashUpload([int? depositOverride]) {
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
    final hasInput = _priceInput.isNotEmpty && _priceInput != '0';

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (kEnableDevBypass)
            TextButton(
              key: const Key('dev_skip_price'),
              onPressed: () => _proceedToFlashUpload(100),
              child: Text(
                'Skip (Dev)',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEEC200),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: TattooBackgroundWrapper(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        isSelected: hasInput,
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '\$',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFF9FAFA),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _priceInput.isEmpty ? '0' : _priceInput,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 68,
                              fontWeight: FontWeight.w800,
                              color: hasInput ? const Color(0xFFF9FAFA) : const Color(0xFF505555),
                              letterSpacing: -1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Continue and Skip Actions
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
                    const SizedBox(height: 12),

                    Center(
                      child: TextButton(
                        key: const Key('skip_price_button'),
                        onPressed: () => _proceedToFlashUpload(100),
                        child: Text(
                          'SKIP',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEEC200),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // On-screen Numeric Keypad
            _buildCustomKeypad(),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildCustomKeypad() {
    return Container(
      color: const Color(0xFF8E9398), // Keypad background matching iOS style design
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildKey(number: '1', letters: ''),
              const SizedBox(width: 8),
              _buildKey(number: '2', letters: 'ABC'),
              const SizedBox(width: 8),
              _buildKey(number: '3', letters: 'DEF'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildKey(number: '4', letters: 'GHI'),
              const SizedBox(width: 8),
              _buildKey(number: '5', letters: 'JKL'),
              const SizedBox(width: 8),
              _buildKey(number: '6', letters: 'MNO'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildKey(number: '7', letters: 'PQRS'),
              const SizedBox(width: 8),
              _buildKey(number: '8', letters: 'TUV'),
              const SizedBox(width: 8),
              _buildKey(number: '9', letters: 'WXYZ'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: SizedBox(height: 48)),
              const SizedBox(width: 8),
              _buildKey(number: '0', letters: ''),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  key: const Key('keypad_backspace'),
                  onTap: _onBackspace,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.backspace_outlined,
                      size: 22,
                      color: Color(0xFF1E2124),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey({required String number, required String letters}) {
    return Expanded(
      child: InkWell(
        key: Key('keypad_$number'),
        onTap: () => _onKeyPress(number),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                number,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF121414),
                  height: 1.0,
                ),
              ),
              if (letters.isNotEmpty)
                Text(
                  letters,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: const Color(0xFF4A4E50),
                    height: 1.1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

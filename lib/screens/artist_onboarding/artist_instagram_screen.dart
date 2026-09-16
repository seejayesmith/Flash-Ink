import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/dev_config.dart';
import '../../services/auth_service.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/artist_stepper_header.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import 'artist_set_price_screen.dart';

class ArtistInstagramScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final AuthService? authService;

  const ArtistInstagramScreen({
    super.key,
    required this.artistName,
    this.photoBytes,
    this.photoUrl,
    this.authService,
  });

  @override
  State<ArtistInstagramScreen> createState() => _ArtistInstagramScreenState();
}

class _ArtistInstagramScreenState extends State<ArtistInstagramScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final defaultHandle = widget.artistName.isNotEmpty
        ? '@${widget.artistName.replaceAll(RegExp(r'\s+'), '')}'
        : '@OddMaree';
    _controller = TextEditingController(text: defaultHandle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _handle {
    final text = _controller.text.trim();
    if (text.isEmpty) return '@OddMaree';
    return text.startsWith('@') ? text : '@$text';
  }

  void _proceedToSetPrice([String? handleOverride]) {
    final handle = handleOverride ?? _handle;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistSetPriceScreen(
          artistName: widget.artistName,
          photoBytes: widget.photoBytes,
          photoUrl: widget.photoUrl,
          instagramHandle: handle,
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              key: const Key('dev_skip_instagram'),
              onPressed: () => _proceedToSetPrice('@OddMaree'),
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ArtistStepperHeader(currentStep: 2),
                const SizedBox(height: 24),

                Text(
                  'Keep your\naudience',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF9FAFA),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Add your instagram handle to your artist profile',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: const Color(0xFF919696),
                  ),
                ),
                const SizedBox(height: 28),

                // Instagram Input Card
                AdaptiveGlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                  children: [
                    TextField(
                      key: const Key('instagram_handle_field'),
                      controller: _controller,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF232626),
                        hintText: '@OddMaree',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF636767),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2E3232)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2E3232)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEEC200), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        key: const Key('continue_to_price_button'),
                        onPressed: () => _proceedToSetPrice(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEC200),
                          foregroundColor: const Color(0xFF121414),
                          elevation: 4,
                          shadowColor: const Color(0x66EEC200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'CONTINUE',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Mockup Phone/Profile Card Preview
              _buildMockupPreviewCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildMockupPreviewCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1D2020),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(color: const Color(0xFF323636), width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with avatar and pill bars
          Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE2E4E4),
                ),
                child: ClipOval(
                  child: widget.photoBytes != null
                      ? Image.memory(widget.photoBytes!, fit: BoxFit.cover)
                      : (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
                          ? Image.network(widget.photoUrl!, fit: BoxFit.cover)
                          : const Icon(Icons.person, size: 40, color: Color(0xFF8C9191)),
                ),
              ),
              const SizedBox(width: 16),
              // Pill bars representing handle/bio lines
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E4E4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E4E4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E4E4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E4E4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3-column Flash Grid Mockup with bottom gradient fade
          Stack(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6D8D8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                },
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.45, 1.0],
                      colors: [
                        Colors.transparent,
                        Color(0x771D2020),
                        Color(0xFF1D2020),
                      ],
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
}

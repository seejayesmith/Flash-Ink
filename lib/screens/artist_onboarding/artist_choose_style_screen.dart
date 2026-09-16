import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/dev_config.dart';
import '../../models/artist.dart';
import '../../services/auth_service.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/artist_stepper_header.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import 'artist_share_link_screen.dart';

class ArtistChooseStyleScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String instagramHandle;
  final int minDeposit;
  final List<FlashArtwork> flashArtworks;
  final List<String> identityTags;
  final AuthService? authService;

  const ArtistChooseStyleScreen({
    super.key,
    required this.artistName,
    this.photoBytes,
    this.photoUrl,
    required this.instagramHandle,
    required this.minDeposit,
    this.flashArtworks = const [],
    this.identityTags = const [],
    this.authService,
  });

  @override
  State<ArtistChooseStyleScreen> createState() => _ArtistChooseStyleScreenState();
}

class _ArtistChooseStyleScreenState extends State<ArtistChooseStyleScreen> {
  final List<String> _availableStyles = [
    'Vegan Inks',
    'Stick and poke',
    'Fine-line',
    'Tribal',
    'Neo-traditional',
    'Blackwork',
    'Portrait',
    'Realism',
    'Traditional',
    'Japanese',
  ];

  final Set<String> _selectedStyles = {
    'Vegan Inks',
    'Fine-line',
    'Traditional',
  };

  void _toggleStyle(String style) {
    setState(() {
      if (_selectedStyles.contains(style)) {
        _selectedStyles.remove(style);
      } else {
        _selectedStyles.add(style);
      }
    });
  }

  void _showAddStyleDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2121),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Add a Style',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            key: const Key('custom_style_input'),
            controller: textController,
            autofocus: true,
            style: GoogleFonts.plusJakartaSans(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Cyber Sigilism',
              hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6B7280)),
              filled: true,
              fillColor: const Color(0xFF262929),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF333636)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191)),
              ),
            ),
            ElevatedButton(
              key: const Key('submit_custom_style_button'),
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    if (!_availableStyles.contains(text)) {
                      _availableStyles.add(text);
                    }
                    _selectedStyles.add(text);
                  });
                }
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEC200),
                foregroundColor: const Color(0xFF121414),
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _proceedToShareScreen([List<String>? stylesOverride]) {
    final styles = stylesOverride ?? _selectedStyles.toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistShareLinkScreen(
          artistName: widget.artistName,
          photoBytes: widget.photoBytes,
          photoUrl: widget.photoUrl,
          instagramHandle: widget.instagramHandle,
          minDeposit: widget.minDeposit,
          flashArtworks: widget.flashArtworks,
          identityTags: widget.identityTags,
          styleTags: styles,
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
              key: const Key('dev_skip_styles'),
              onPressed: () => _proceedToShareScreen(),
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
                'Choose your\nstyle',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF9FAFA),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Pick the styles you specialize in so clients searching for your specific aesthetic can easily find your profile and flash',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: const Color(0xFF919696),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Styles Chips Container
              AdaptiveGlassContainer(
                borderRadius: 16,
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                  ..._availableStyles.map((style) {
                    final isSelected = _selectedStyles.contains(style);
                    return InkWell(
                      key: Key('style_$style'),
                      onTap: () => _toggleStyle(style),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF262312) : const Color(0xFF1A1C1C),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF2E3232),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check, size: 14, color: Color(0xFFEEC200)),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              style,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? const Color(0xFFEEC200) : const Color(0xFFE2E4E4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // "+ Add a style" button
                  InkWell(
                    key: const Key('add_custom_style_trigger'),
                    onTap: _showAddStyleDialog,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1C1C),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2E3232)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, size: 14, color: Color(0xFF919696)),
                          const SizedBox(width: 6),
                          Text(
                            'Add a style',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF919696),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

              // DONE Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const Key('done_styles_button'),
                  onPressed: () => _proceedToShareScreen(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEC200),
                    foregroundColor: const Color(0xFF121414),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    'DONE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // SKIP Button
              Center(
                child: TextButton(
                  key: const Key('skip_styles_button'),
                  onPressed: () => _proceedToShareScreen(const []),
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
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
  );
}
}

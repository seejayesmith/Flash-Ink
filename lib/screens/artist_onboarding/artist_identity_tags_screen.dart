import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/dev_config.dart';
import '../../models/artist.dart';
import '../../services/auth_service.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/artist_stepper_header.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import 'artist_choose_style_screen.dart';

class ArtistIdentityTagsScreen extends StatefulWidget {
  final String artistName;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String instagramHandle;
  final int minDeposit;
  final List<FlashArtwork> flashArtworks;
  final AuthService? authService;

  const ArtistIdentityTagsScreen({
    super.key,
    required this.artistName,
    this.photoBytes,
    this.photoUrl,
    required this.instagramHandle,
    required this.minDeposit,
    this.flashArtworks = const [],
    this.authService,
  });

  @override
  State<ArtistIdentityTagsScreen> createState() => _ArtistIdentityTagsScreenState();
}

class _ArtistIdentityTagsScreenState extends State<ArtistIdentityTagsScreen> {
  final Set<String> _selectedTags = {
    'Vegan Inks',
    'Queer-Owned',
    'Private Studio',
    'Deep Skin Experienced',
    'Scent-Free',
  };

  static const Map<String, List<String>> _sections = {
    'STYLE': [
      'Vegan Inks',
      'Eco-Friendly',
      'Hand-Poke',
      'Machine Free',
      'Cruelty-Free',
    ],
    'COMMUNITY & IDENTITY': [
      'Queer-Owned',
      'Women-Owned',
      'BIPOC-Owned',
      'LGBTQ+ Friendly',
      'Trans-Friendly',
      'Indigenous Artist',
    ],
    'THE SPACE': [
      'Private Studio',
      'Sensory-Friendly',
      'Open Shop',
      'Music Choice',
    ],
    'INCLUSIVITY': [
      'All Bodies',
      'Deep Skin Experienced',
      'Trauma-Informed',
      'Size Inclusive',
      'Scar Cover-Up',
    ],
    'ACCESSIBILITY': [
      'Wheelchair Accessible',
      'Gender-Neutral Restrooms',
      'Ground Floor',
      'Scent-Free',
      'Service Animals Welcome',
    ],
  };

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _proceedToChooseStyle() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistChooseStyleScreen(
          artistName: widget.artistName,
          photoBytes: widget.photoBytes,
          photoUrl: widget.photoUrl,
          instagramHandle: widget.instagramHandle,
          minDeposit: widget.minDeposit,
          flashArtworks: widget.flashArtworks,
          identityTags: _selectedTags.toList(),
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
              key: const Key('dev_skip_identity'),
              onPressed: _proceedToChooseStyle,
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
                  'Tell them who\nyou are',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF9FAFA),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Help clients find a space where they feel welcome by tagging your identity, vibe, and accommodations',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: const Color(0xFF919696),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Categories List Container
                AdaptiveGlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._sections.entries.map((entry) => _buildSection(entry.key, entry.value)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // DONE Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    key: const Key('done_identity_button'),
                    onPressed: _proceedToChooseStyle,
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
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String categoryTitle, List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          categoryTitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8C9191),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return InkWell(
              key: Key('tag_$tag'),
              onTap: () => _toggleTag(tag),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      tag,
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
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFF242727), thickness: 1),
        const SizedBox(height: 12),
      ],
    );
  }
}

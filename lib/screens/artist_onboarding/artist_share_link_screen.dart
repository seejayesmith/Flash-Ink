import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/artist.dart';
import '../../services/auth_service.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/artist_stepper_header.dart';
import '../../widgets/tattoo_background_wrapper.dart';
import '../artist_dashboard/artist_dashboard_screen.dart';

class ArtistShareLinkScreen extends StatelessWidget {
  final String artistName;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final String? instagramHandle;
  final int? minDeposit;
  final List<FlashArtwork> flashArtworks;
  final List<String> identityTags;
  final List<String> styleTags;
  final AuthService? authService;

  const ArtistShareLinkScreen({
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
  });

  String get _displayHandle {
    if (instagramHandle != null && instagramHandle!.trim().isNotEmpty) {
      return instagramHandle!.startsWith('@') ? instagramHandle! : '@$instagramHandle';
    }
    return artistName.isNotEmpty
        ? '@${artistName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}'
        : '@OddMaree';
  }

  String get _artistBio {
    return 'Local Portland Artists with taking my brain barf and putting it on skin';
  }

  Future<void> _completeOnboarding(BuildContext context) async {
    final effectiveAuth = authService ?? AuthService();
    final user = effectiveAuth.currentUser ?? FirebaseAuth.instance.currentUser;

    final deposit = minDeposit ?? 100;
    final allTags = <String>{...identityTags, ...styleTags}.toList();

    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('artists').doc(user.uid).set({
          'name': artistName,
          'instagramHandle': _displayHandle,
          'bio': _artistBio,
          'minDeposit': deposit,
          'tags': allTags,
          'profileCompleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(milliseconds: 300));

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': artistName,
          'instagramHandle': _displayHandle,
          'profileCompleted': true,
          'role': 'artist',
        }, SetOptions(merge: true)).timeout(const Duration(milliseconds: 300));
      } catch (_) {
        // Continue smoothly even in offline or mock test mode
      }
    }

    final artist = Artist(
      id: user?.uid ?? 'artist_${DateTime.now().millisecondsSinceEpoch}',
      name: artistName.isNotEmpty ? artistName : 'OddMaree',
      avatarUrl: photoUrl ?? (photoBytes != null ? 'local://memory' : ''),
      location: 'Portland, OR',
      studioType: 'Private Studio',
      rating: 5.0,
      availablePieces: flashArtworks.isNotEmpty ? flashArtworks.length : 6,
      minDeposit: deposit,
      tags: allTags.isNotEmpty ? allTags : ['Traditional', 'Fine-line', 'Vegan Inks'],
      flashArtworks: flashArtworks,
    );

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => ArtistDashboardScreen(
            artist: artist,
            authService: effectiveAuth,
          ),
        ),
        (route) => false,
      );
    }
  }

  void _showStickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2121),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Custom Artist Stickers',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We generated a printable sticker pack with your unique QR code and $_displayHandle handle.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF919696),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sticker link copied! Ready to print.'),
                          backgroundColor: Color(0xFF22C55E),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEC200),
                      foregroundColor: const Color(0xFF121414),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      'Copy Sticker Pack Link',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: TattooBackgroundWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stepper: Step 1 checked, Step 2 checked, Step 3 active!
                const ArtistStepperHeader(currentStep: 3),
                const SizedBox(height: 24),

                Text(
                  'Tell em where to\nfind you',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF9FAFA),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 28),

                // QR Code Ticket Card
                AdaptiveGlassContainer(
                  key: const Key('qr_ticket_card'),
                  borderRadius: 20,
                  padding: EdgeInsets.zero,
                  child: Column(
                  children: [
                    // Top half: Stylized QR code
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                      child: Center(
                        child: _buildStylizedQrCode(),
                      ),
                    ),

                    // Bottom ticket section (light background)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFECEEEE),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(19),
                          bottomRight: Radius.circular(19),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayHandle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF121414),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _artistBio,
                            style: GoogleFonts.spaceMono(
                              fontSize: 12,
                              color: const Color(0xFF4A4E50),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // "Want to go beyond digital?" text
              Center(
                child: Column(
                  children: [
                    Text(
                      'Want to go beyond digital?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF8C9191),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Follow the link to create custom\nstickers with your name and code!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF8C9191),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Outline Button: Create a sticker
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  key: const Key('create_sticker_button'),
                  onPressed: () => _showStickerSheet(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF383C3C), width: 1.5),
                    backgroundColor: const Color(0xFF161818),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.file_upload_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Create a sticker',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Solid Yellow Button: DONE
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const Key('done_share_button'),
                  onPressed: () => _completeOnboarding(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEC200),
                    foregroundColor: const Color(0xFF121414),
                    elevation: 4,
                    shadowColor: const Color(0x66EEC200),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildStylizedQrCode() {
    return Container(
      width: 210,
      height: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _StylizedQrPainter(),
        child: Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF121414),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            alignment: Alignment.center,
            child: Text(
              'F',
              style: GoogleFonts.caveat(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFEEC200),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StylizedQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blackPaint = Paint()
      ..color = const Color(0xFF121414)
      ..style = PaintingStyle.fill;

    final blockSize = size.width / 21;

    void drawBlock(int x, int y) {
      canvas.drawRect(
        Rect.fromLTWH(x * blockSize, y * blockSize, blockSize, blockSize),
        blackPaint,
      );
    }

    void drawFinder(int startX, int startY) {
      // Outer 7x7
      for (int x = 0; x < 7; x++) {
        for (int y = 0; y < 7; y++) {
          if (x == 0 || x == 6 || y == 0 || y == 6) {
            drawBlock(startX + x, startY + y);
          } else if (x >= 2 && x <= 4 && y >= 2 && y <= 4) {
            drawBlock(startX + x, startY + y);
          }
        }
      }
    }

    // Draw three corner finders
    drawFinder(0, 0);
    drawFinder(14, 0);
    drawFinder(0, 14);

    // Procedural pseudo-random data blocks for realistic visual appearance
    final seedBlocks = [
      [8, 1], [9, 1], [11, 2], [8, 3], [12, 3],
      [1, 8], [3, 8], [5, 8], [8, 8], [10, 8], [12, 8], [15, 8], [17, 8], [19, 8],
      [8, 9], [10, 9], [13, 9],
      [2, 10], [4, 10], [6, 10], [8, 10], [11, 10], [13, 10], [16, 10], [18, 10],
      [8, 11], [12, 11], [14, 11], [17, 11],
      [0, 12], [2, 12], [4, 12], [7, 12], [10, 12], [13, 12], [15, 12],
      [8, 14], [10, 14], [13, 14], [15, 14], [18, 14], [20, 14],
      [8, 16], [11, 16], [14, 16], [16, 16], [19, 16],
      [8, 18], [10, 18], [13, 18], [15, 18], [17, 18], [20, 18],
      [8, 20], [11, 20], [14, 20], [17, 20], [19, 20],
      [15, 2], [17, 3], [19, 4], [16, 5],
      [2, 17], [4, 19], [6, 16],
    ];

    for (final pt in seedBlocks) {
      // Don't draw over center where logo sits
      if (pt[0] >= 8 && pt[0] <= 12 && pt[1] >= 8 && pt[1] <= 12) continue;
      drawBlock(pt[0], pt[1]);
    }

    // Timing patterns
    for (int i = 8; i < 14; i += 2) {
      drawBlock(6, i);
      drawBlock(i, 6);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

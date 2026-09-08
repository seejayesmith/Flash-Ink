import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../widgets/artist_stepper_header.dart';
import '../main_feed_screen.dart';

class ArtistShareLinkScreen extends StatelessWidget {
  final String artistName;
  final Uint8List? photoBytes;
  final String? photoUrl;
  final AuthService? authService;

  const ArtistShareLinkScreen({
    super.key,
    required this.artistName,
    this.photoBytes,
    this.photoUrl,
    this.authService,
  });

  String get _artistHandle {
    return artistName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  String get _shareUrl => 'flash.ink/@$_artistHandle';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stepper: Steps 1 & 2 completed with checkmarks, Step 3 active
              const ArtistStepperHeader(currentStep: 3),
              const SizedBox(height: 24),

              Text(
                'Share your\nlink',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF9FAFA),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your artist profile is ready. Share your link with clients to book flash and browse your work.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: const Color(0xFF919696),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Card Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1C1C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2B2E2E)),
                ),
                child: Column(
                  children: [
                    // Profile Avatar
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFEEC200), width: 2),
                        color: const Color(0xFF242727),
                      ),
                      child: ClipOval(
                        child: photoBytes != null
                            ? Image.memory(
                                photoBytes!,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              )
                            : (photoUrl != null && photoUrl!.isNotEmpty)
                                ? Image.network(
                                    photoUrl!,
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Text(
                                      artistName.isNotEmpty ? artistName[0].toUpperCase() : 'A',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFEEC200),
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Artist Name
                    Text(
                      artistName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF9FAFA),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tattoo Artist',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF919696),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Link Container Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242727),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF383C3C)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link,
                            color: Color(0xFFEEC200),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _shareUrl,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFF9FAFA),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.copy,
                              color: Color(0xFFEEC200),
                              size: 20,
                            ),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: 'https://$_shareUrl'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Link copied to clipboard!'),
                                  backgroundColor: Color(0xFF22C55E),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            tooltip: 'Copy link',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ENTER APP / EXPLORE Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const MainFeedScreen()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEC200),
                          foregroundColor: const Color(0xFF121414),
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'GO TO FLASH.INK',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: const Color(0xFF121414),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: Color(0xFF121414),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

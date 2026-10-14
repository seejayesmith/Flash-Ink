import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/artist.dart';
import '../../../../models/artist_dashboard_data.dart';
import '../../../../models/waitlist_entry.dart';
import '../../../../screens/artist_profile_screen.dart';
import '../../../../screens/custom_request_screen.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../widgets/flash_image.dart';
import '../../../../widgets/guest_auth_prompt_bottom_sheet.dart';

/// Exclusive VIP Early Access Invitation card displayed in the client's inbox/messages.
class VipWaitlistInvitationCard extends StatelessWidget {
  final WaitlistEntry entry;
  final VoidCallback? onDismiss;

  const VipWaitlistInvitationCard({
    super.key,
    required this.entry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = ArtistDashboardRepository.booksSchedule;
    final remaining = schedule.earlyAccessTimeRemaining;
    final remainingStr = remaining != null
        ? '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m left'
        : 'Limited Time';

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.spaceLg, 12, AppSpacing.spaceLg, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF262214), // Warm dark gold tint
            Color(0xFF161818),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFEEC200),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEEC200).withAlpha(30),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Star Icon + VIP Badge + Expiry Timer
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEC200).withAlpha(35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.stars_rounded, color: Color(0xFFEEC200), size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'EXCLUSIVE VIP EARLY ACCESS',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEEC200),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF121414),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFEEC200).withAlpha(100)),
                ),
                child: Text(
                  remainingStr,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEEC200),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Artist Info Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEEC200), width: 1.5),
                ),
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFF242828),
                  child: ClipOval(
                    child: FlashImage(
                      urlOrPath: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OddMaree opened books for you!',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Priority access for friends & family before public release.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Waitlist Concept Spec Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141616),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF262A2A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bookmark_outline_rounded, color: Color(0xFFEEC200), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'YOUR SAVED WAITLIST REQUEST',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEEC200),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.conceptDescription,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${entry.placement} • ${entry.availabilityPreference}',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11,
                      ),
                    ),
                    if (entry.budget != null) ...[
                      const Spacer(),
                      Text(
                        'Budget: \$${entry.budget}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF22C55E),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Action Buttons: Book Custom Request OR Browse Flash
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final authenticated = await GuestAuthPromptBottomSheet.ensureAuthenticated(
                      context,
                      actionType: AuthActionPromptType.waitlist,
                    );
                    if (!authenticated) return;

                    final artist = Artist.mockArtists.first;
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomRequestScreen(
                          artist: artist,
                          initialDescription: entry.conceptDescription,
                          initialPlacement: entry.placement,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEC200),
                    foregroundColor: const Color(0xFF121414),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Book My Request',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final artist = Artist.mockArtists.first;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArtistProfileScreen(
                          artist: artist,
                          isVipEarlyAccess: true,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEEC200)),
                    foregroundColor: const Color(0xFFEEC200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Browse Flash Pieces',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
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

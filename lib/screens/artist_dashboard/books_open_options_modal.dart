import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist_dashboard_data.dart';
import '../../theme/app_radius.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_switch.dart';

/// Modal dialog presented when an artist opens their books, offering the choice
/// between an exclusive Early Access VIP window for waitlist members or immediate public opening.
class BooksOpenOptionsModal extends StatefulWidget {
  final VoidCallback onEarlyAccessSelected;
  final VoidCallback onPublicOpenSelected;

  const BooksOpenOptionsModal({
    super.key,
    required this.onEarlyAccessSelected,
    required this.onPublicOpenSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onEarlyAccessSelected,
    required VoidCallback onPublicOpenSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BooksOpenOptionsModal(
        onEarlyAccessSelected: onEarlyAccessSelected,
        onPublicOpenSelected: onPublicOpenSelected,
      ),
    );
  }

  @override
  State<BooksOpenOptionsModal> createState() => _BooksOpenOptionsModalState();
}

class _BooksOpenOptionsModalState extends State<BooksOpenOptionsModal> {
  int _selectedHours = 24;
  bool _notifyWaitlistOnPublic = true;

  int get _waitingCount {
    return ArtistDashboardRepository.waitlistEntries
        .where((e) => e.status.name == 'waiting')
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveGlassContainer.bottomSheet(
      glassEnabled: false,
      androidSurfaceColor: const Color(0xFF161818),
      selectedBorderColor: const Color(0xFFEEC200),
      unselectedBorderColor: const Color(0xFFEEC200),
      selectedBorderWidth: 1.5,
      unselectedBorderWidth: 1.5,
      topRadius: AppRadius.radiusSheet,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333838),
                borderRadius: BorderRadius.circular(AppRadius.dragHandle),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEC200).withAlpha(28),
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  border: Border.all(
                    color: const Color(0xFFEEC200).withAlpha(120),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Color(0xFFEEC200),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to Open Books?',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose how you want to release your booking schedule.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Option 1: Exclusive Early Access to Waitlist
          _buildOptionCard(
            title: 'Send Early Access to Waitlist',
            badgeText: 'RECOMMENDED • VIP FIRST',
            badgeColor: const Color(0xFFEEC200),
            icon: Icons.star_rounded,
            description:
                'Give your friends, family, and VIP waitlist ($_waitingCount waiting) exclusive first dibs before anyone else can see or book slots.',
            extraContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Exclusive VIP Window Duration:',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFC7CDCD),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildHourPill(24, '24 Hours'),
                    const SizedBox(width: 8),
                    _buildHourPill(48, '48 Hours'),
                    const SizedBox(width: 8),
                    _buildHourPill(72, '72 Hours'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '• Flash app users get instant priority push notifications.\n• Non-app friends get personalized VIP booking links you can text in 1 tap.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            buttonLabel: 'Launch Early Access Window',
            buttonColor: const Color(0xFFEEC200),
            buttonTextColor: const Color(0xFF121414),
            onTap: () {
              Navigator.pop(context);
              ArtistDashboardRepository.sendEarlyAccessToWaitlist(hours: _selectedHours);
              widget.onEarlyAccessSelected();
            },
          ),

          const SizedBox(height: 16),

          // Option 2: Open to Public Immediately
          _buildOptionCard(
            title: 'Open to Public Immediately',
            badgeText: 'PUBLIC RELEASE',
            badgeColor: const Color(0xFF38BDF8),
            icon: Icons.public_rounded,
            description:
                'Make books visible to everyone on Flash immediately. All clients can claim flash or submit requests.',
            extraContent: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  FlashSwitch(
                    value: _notifyWaitlistOnPublic,
                    onChanged: (val) {
                      setState(() => _notifyWaitlistOnPublic = val);
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Also send priority blast alert to waitlist',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFC7CDCD),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            buttonLabel: 'Open to Public Now',
            buttonColor: const Color(0xFF262A2A),
            buttonTextColor: Colors.white,
            borderSideColor: const Color(0xFF38BDF8).withAlpha(120),
            onTap: () {
              Navigator.pop(context);
              ArtistDashboardRepository.openBooksPublicly();
              widget.onPublicOpenSelected();
            },
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildHourPill(int hours, String label) {
    final isSelected = _selectedHours == hours;
    return InkWell(
      onTap: () => setState(() => _selectedHours = hours),
      borderRadius: BorderRadius.circular(AppRadius.radiusFull),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEEC200)
              : const Color(0xFF1E2222),
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFEEC200)
                : const Color(0xFF363B3B),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? const Color(0xFF121414) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required String description,
    required Widget extraContent,
    required String buttonLabel,
    required Color buttonColor,
    required Color buttonTextColor,
    Color? borderSideColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D1D),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(
          color: borderSideColor ?? badgeColor.withAlpha(80),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: badgeColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(
                    color: badgeColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          extraContent,
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: buttonTextColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
              ),
              child: Text(
                buttonLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

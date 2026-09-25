import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/models/appointment_item.dart';
import '../widgets/appointment_card.dart';

/// AppointmentsScreen:
/// Manages bookings with segmented control for "Upcoming" and "Past" appointments.
class AppointmentsScreen extends StatefulWidget {
  final List<ClientAppointment>? mockUpcoming;
  final List<ClientAppointment>? mockPast;
  final VoidCallback? onExploreTap;

  const AppointmentsScreen({
    super.key,
    this.mockUpcoming,
    this.mockPast,
    this.onExploreTap,
  });

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  int _selectedTabIndex = 0; // 0: Upcoming, 1: Past
  late List<ClientAppointment> _upcoming;
  late List<ClientAppointment> _past;

  @override
  void initState() {
    super.initState();
    _upcoming = widget.mockUpcoming ?? List.from(ClientAppointment.mockUpcoming);
    _past = widget.mockPast ?? List.from(ClientAppointment.mockPast);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final currentList = _selectedTabIndex == 0 ? _upcoming : _past;

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.onyxBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Appointments',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Segmented Control (Upcoming vs Past)
            _buildSegmentedControl(),
            const SizedBox(height: 16),

            // Appointments List or Empty State
            Expanded(
              child: currentList.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.spaceLg,
                        0,
                        AppSpacing.spaceLg,
                        AppSpacing.spaceXxl + AppTheme.navBarHeight + bottomInset,
                      ),
                      itemCount: currentList.length,
                      itemBuilder: (context, index) {
                        return AppointmentCard(appointment: currentList[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.onyxContainer,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildSegmentButton(
                index: 0,
                label: 'Upcoming (${_upcoming.length})',
              ),
            ),
            Expanded(
              child: _buildSegmentButton(
                index: 1,
                label: 'Past (${_past.length})',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({required int index, required String label}) {
    final isSelected = _selectedTabIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isSelected ? AppTheme.onyxBackground : AppTheme.navInactive,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isUpcoming = _selectedTabIndex == 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.onyxContainer,
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                color: AppTheme.gold,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No Upcoming Appointments' : 'No Past Sessions',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isUpcoming
                  ? 'Ready for your next tattoo? Explore available flash drops from top artists.'
                  : 'Your completed tattoo sessions and receipts will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.navInactive,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (isUpcoming) ...[
              const SizedBox(height: 20),
              AppButtons.primaryCTA(
                onPressed: widget.onExploreTap,
                text: 'BROWSE FLASH DESIGNS',
                width: 220,
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.onyxBackground,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

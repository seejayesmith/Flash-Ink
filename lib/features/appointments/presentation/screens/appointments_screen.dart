import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/client_empty_state.dart';
import '../../../../widgets/flash_tab_header.dart';
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

  List<ClientAppointment> get _upcoming =>
      widget.mockUpcoming ?? ClientAppointment.activeUpcoming;
  List<ClientAppointment> get _past =>
      widget.mockPast ?? ClientAppointment.activePast;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final currentList = _selectedTabIndex == 0 ? _upcoming : _past;

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FlashTabHeader(
              title: 'Appointments',
            ),
            // Segmented Control (Upcoming vs Past)
            _buildSegmentedControl(),
            const SizedBox(height: 16),

            // Appointments List or Empty State
            Expanded(
              child: currentList.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.screenGutter,
                        0,
                        AppSpacing.screenGutter,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(AppSpacing.spaceXxs),
        decoration: BoxDecoration(
          color: AppTheme.onyxContainer,
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
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
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
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

    return ClientEmptyState(
      icon: Icons.calendar_today_outlined,
      title: isUpcoming ? 'No Upcoming Appointments' : 'No Past Sessions',
      subtitle: isUpcoming
          ? 'Ready for your next tattoo? Explore available flash drops from top artists.'
          : 'Your completed tattoo sessions and receipts will appear here.',
      action: isUpcoming
          ? AppButtons.primaryCTA(
              onPressed: widget.onExploreTap,
              text: 'Browse Flash Designs',
              width: 220,
              backgroundColor: AppTheme.gold,
              foregroundColor: AppTheme.onyxBackground,
            )
          : null,
      reserveActionSpace: !isUpcoming,
      minTitleHeight: 52.0,
      minSubtitleHeight: 72.0,
    );
  }
}

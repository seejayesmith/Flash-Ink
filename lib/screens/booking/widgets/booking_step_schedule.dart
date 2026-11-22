import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/artist.dart';
import '../../../models/artist_dashboard/artist_books_schedule.dart';
import '../../../repositories/artist_dashboard_repository.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/adaptive_glass_container.dart';
import '../../../widgets/flash_image.dart';
import '../../../widgets/flash_switch.dart';

/// Step 1 of the flash booking flow: artwork recap, calendar date picker,
/// time slot chips, placement selector, and silent appointment toggle.
class BookingStepSchedule extends StatelessWidget {
  final FlashArtwork flash;
  final String artistName;
  final String? artistId;
  final ArtistBooksSchedule schedule;
  final DateTime currentMonth;
  final DateTime selectedDate;
  final String selectedTimeSlot;
  final String selectedPlacement;
  final bool isSilentSession;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<String> onTimeSlotSelected;
  final VoidCallback onPlacementTap;
  final ValueChanged<bool> onSilentChanged;

  const BookingStepSchedule({
    super.key,
    required this.flash,
    required this.artistName,
    required this.artistId,
    required this.schedule,
    required this.currentMonth,
    required this.selectedDate,
    required this.selectedTimeSlot,
    required this.selectedPlacement,
    required this.isSilentSession,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onDateSelected,
    required this.onTimeSlotSelected,
    required this.onPlacementTap,
    required this.onSilentChanged,
  });

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _weekdays = [
    'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildArtworkSummaryBanner(),
        const SizedBox(height: 20),
        Text(
          'SELECT DATE',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.navInactive,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _buildCalendarCard(),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SELECT TIME SLOT',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.navInactive,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'Session Est. ${flash.estimatedTime}',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.gold,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTimeSlotsGrid(),
        const SizedBox(height: 24),
        Text(
          'BODY PLACEMENT',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.navInactive,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        _buildPlacementSelector(),
        const SizedBox(height: 20),
        _buildSilentSessionTile(),
      ],
    );
  }

  Widget _buildArtworkSummaryBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            child: SizedBox(
              width: 58,
              height: 58,
              child: FlashImage(
                urlOrPath: flash.imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flash.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'by $artistName',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Deposit: \$${flash.deposit} • Full: \$${flash.price}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.navInactive,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    final daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(currentMonth.year, currentMonth.month, 1).weekday % 7;
    final totalCells = firstWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: const Color(0xFF38352A), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon:
                    const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                onPressed: onPrevMonth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                '${_monthNames[currentMonth.month - 1]} ${currentMonth.year}',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: AppTheme.textPrimary),
                onPressed: onNextMonth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekdays.map((day) {
              return SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    day,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF6B7272),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Column(
            children: List.generate(rowCount, (rowIndex) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (colIndex) {
                    final cellIndex = rowIndex * 7 + colIndex;
                    final dayNum = cellIndex - firstWeekday + 1;

                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const SizedBox(width: 34, height: 34);
                    }

                    final cellDate = DateTime(
                      currentMonth.year,
                      currentMonth.month,
                      dayNum,
                    );
                    final isPast = cellDate.isBefore(today);
                    final isBookableDate = !isPast &&
                        ArtistDashboardRepository.isDateBookable(
                          date: cellDate,
                          schedule: schedule,
                          artistId: artistId,
                        );
                    final isDisabled = !isBookableDate;
                    final isSelected = cellDate.year == selectedDate.year &&
                        cellDate.month == selectedDate.month &&
                        cellDate.day == selectedDate.day;

                    return GestureDetector(
                      key: Key('flash_booking_day_$dayNum'),
                      onTap: isDisabled ? null : () => onDateSelected(cellDate),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppTheme.gold
                              : Colors.transparent,
                          border: isSelected
                              ? Border.all(color: AppTheme.gold, width: 1.5)
                              : (cellDate.day == today.day &&
                                      cellDate.month == today.month
                                  ? Border.all(
                                      color: const Color(0xFF4D5252),
                                      width: 1,
                                    )
                                  : null),
                        ),
                        child: Center(
                          child: Text(
                            '$dayNum',
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? AppTheme.onyxBackground
                                  : (isDisabled
                                      ? const Color(0xFF424747)
                                      : AppTheme.textPrimary),
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotsGrid() {
    final slots = schedule.generateTimeSlots();
    if (slots.isEmpty) {
      return Text(
        'No available time slots configured.',
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.navInactiveAlt,
          fontSize: 13,
        ),
      );
    }

    final now = DateTime.now();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isBooked = ArtistDashboardRepository.isTimeSlotBooked(
          date: selectedDate,
          timeSlot: slot.time,
          schedule: schedule,
          artistId: artistId,
        );
        final isHeld = !isBooked &&
            ArtistDashboardRepository.hasActiveHoldForSlot(
              date: selectedDate,
              timeSlot: slot.time,
              schedule: schedule,
              now: now,
            );
        final isAvailable = ArtistDashboardRepository.isSlotBookable(
          date: selectedDate,
          timeSlot: slot.time,
          schedule: schedule,
          artistId: artistId,
          now: now,
        );
        final isDisabled = isBooked || isHeld || !isAvailable;
        final isSelected = !isDisabled && selectedTimeSlot == slot.time;

        final chipLabel = isBooked
            ? '${slot.time} (Booked)'
            : (isHeld ? '${slot.time} (Held)' : slot.time);

        return ChoiceChip(
          label: Text(chipLabel),
          selected: isSelected,
          showCheckmark: false,
          onSelected: isDisabled
              ? null
              : (selected) {
                  if (selected) onTimeSlotSelected(slot.time);
                },
          selectedColor: AppTheme.gold,
          backgroundColor:
              isDisabled ? AppTheme.onyxSurface : AppTheme.onyxContainer,
          disabledColor: AppTheme.onyxSurface,
          labelStyle: GoogleFonts.plusJakartaSans(
            color: isDisabled
                ? const Color(0xFF555A5A)
                : (isSelected
                    ? AppTheme.onyxBackground
                    : AppTheme.textPrimary),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            decoration: isDisabled ? TextDecoration.lineThrough : null,
          ),
          side: BorderSide(
            color: isSelected
                ? AppTheme.gold
                : (isDisabled
                    ? const Color(0xFF222525)
                    : AppTheme.actionButtonBorder),
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusFull),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlacementSelector() {
    return AdaptiveGlassContainer(
      key: const Key('placement_selector_trigger'),
      borderRadius: 14.0,
      onTap: onPlacementTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      useGradient: true,
      child: Row(
        children: [
          const Icon(
            Icons.accessibility_new_rounded,
            color: AppTheme.gold,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              selectedPlacement,
              key: const Key('placement_selector_text'),
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.gold,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildSilentSessionTile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_off_outlined, color: AppTheme.gold, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Silent Appointment',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Minimal chatter during session. Perfect for resting or reading.',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.navInactive,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          FlashSwitch(
            value: isSilentSession,
            onChanged: onSilentChanged,
          ),
        ],
      ),
    );
  }
}

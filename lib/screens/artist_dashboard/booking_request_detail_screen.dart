import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/messages/domain/models/message_thread.dart';
import '../../models/artist_dashboard/artist_books_schedule.dart';
import '../../models/artist_dashboard/auto_response_preset.dart';
import '../../models/artist_dashboard/book_drop.dart';
import '../../models/artist_dashboard/booking_request.dart';
import '../../repositories/artist_dashboard_repository.dart';
import '../../models/booking.dart';
import '../../services/scheduling/booking_slot_profile.dart';
import '../../services/scheduling/slot_availability_engine.dart';
import '../../theme/app_buttons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/pinned_bottom_action_scaffold.dart';
import '../../widgets/user_avatar.dart';

/// Full-screen view presenting comprehensive booking request details and actions.
class BookingRequestDetailScreen extends StatefulWidget {
  final BookingRequest request;

  const BookingRequestDetailScreen({
    super.key,
    required this.request,
  });

  @override
  State<BookingRequestDetailScreen> createState() => _BookingRequestDetailScreenState();
}

class _BookingRequestDetailScreenState extends State<BookingRequestDetailScreen> {
  late DateTime _selectedDate;
  late String _selectedTimeSlot;
  late int _estimatedPrice;
  late int _deposit;

  @override
  void initState() {
    super.initState();
    _estimatedPrice = widget.request.estimatedPrice;
    _deposit = widget.request.deposit;

    DateTime candidate = widget.request.preferredDate ??
        DateTime.now().add(const Duration(days: 3));
    int guard = 0;
    while (!ArtistDashboardRepository.isDateBookable(
          date: candidate,
          slotType: BookingSlotType.custom,
        ) &&
        guard < 60) {
      candidate = candidate.add(const Duration(days: 1));
      guard++;
    }
    _selectedDate = DateTime(candidate.year, candidate.month, candidate.day);

    final slots = ArtistDashboardRepository.booksSchedule.generateTimeSlots();
    if (widget.request.preferredTimeSlot != null &&
        widget.request.preferredTimeSlot!.isNotEmpty) {
      _selectedTimeSlot = widget.request.preferredTimeSlot!;
    } else {
      final firstOpen = slots.firstWhere(
        (s) => ArtistDashboardRepository.isSlotBookable(
          date: _selectedDate,
          timeSlot: s.time,
        ),
        orElse: () => const BookingTimeSlot(time: '1:00 PM', period: 'Afternoon'),
      );
      _selectedTimeSlot = firstOpen.time;
    }
  }

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const List<String> _weekdays = [
    'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa',
  ];

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${days[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }

  void _openProposeTimeModal() {
    DateTime tempDate = _selectedDate;
    DateTime displayMonth = DateTime(tempDate.year, tempDate.month, 1);
    int tempDurationMinutes =
        ArtistDashboardRepository.booksSchedule.slotDurationMinutes;
    int tempPrice = _estimatedPrice;
    int tempDeposit = _deposit;
    String? limitHint;

    final scheduleAtOpen = ArtistDashboardRepository.booksSchedule;
    final openNow = DateTime.now();
    final initialSlots = SlotAvailabilityEngine.generateAvailableSlots(
      date: tempDate,
      schedule: scheduleAtOpen,
      slotType: BookingSlotType.custom,
      requestedDurationMinutes: tempDurationMinutes,
      localAppointments: ArtistDashboardRepository.calendarAppointments,
      localHolds: ArtistDashboardRepository.customHolds,
      now: openNow,
      enforceLeadTime:
          ArtistDashboardRepository.bookingMode == BookingMode.alwaysOpen,
      hasBookingOrHoldOnDay: ArtistDashboardRepository.isDateOccupied(
        tempDate,
        now: openNow,
      ),
    );
    final List<ProposedTimeOption> selectedOptions = [];
    final matchingDefault =
        initialSlots.where((s) => s.time == _selectedTimeSlot).toList();
    if (matchingDefault.isNotEmpty) {
      final s = matchingDefault.first;
      selectedOptions.add(
        ProposedTimeOption(
          date: tempDate,
          timeSlot: s.time,
          startMinutes: s.startMinutes,
          durationMinutes: tempDurationMinutes,
        ),
      );
    } else if (initialSlots.isNotEmpty) {
      final optimalFirst = initialSlots.firstWhere(
        (s) => s.isOptimal,
        orElse: () => initialSlots.first,
      );
      selectedOptions.add(
        ProposedTimeOption(
          date: tempDate,
          timeSlot: optimalFirst.time,
          startMinutes: optimalFirst.startMinutes,
          durationMinutes: tempDurationMinutes,
        ),
      );
    }

    const durationPresets = [60, 120, 180, 240, 300, 360];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final schedule = ArtistDashboardRepository.booksSchedule;
            final now = DateTime.now();
            final slots = SlotAvailabilityEngine.generateAvailableSlots(
              date: tempDate,
              schedule: schedule,
              slotType: BookingSlotType.custom,
              requestedDurationMinutes: tempDurationMinutes,
              localAppointments: ArtistDashboardRepository.calendarAppointments,
              localHolds: ArtistDashboardRepository.customHolds,
              now: now,
              enforceLeadTime: ArtistDashboardRepository.bookingMode ==
                  BookingMode.alwaysOpen,
              hasBookingOrHoldOnDay: ArtistDashboardRepository.isDateOccupied(
                tempDate,
                now: now,
              ),
              includeConflicted: true,
            );
            final canSend = selectedOptions.isNotEmpty;
            final today = DateTime(now.year, now.month, now.day);
            final firstOfCurrentMonth = DateTime(now.year, now.month, 1);
            final daysInMonth =
                DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
            final firstWeekday =
                DateTime(displayMonth.year, displayMonth.month, 1).weekday % 7;
            final rowCount = ((firstWeekday + daysInMonth) / 7).ceil();

            void toggleOption(DateTime day, AvailableSlot slot) {
              final dayKey = ArtistBooksSchedule.dateKey(day);
              final existingIdx = selectedOptions.indexWhere(
                (o) =>
                    ArtistBooksSchedule.dateKey(o.date) == dayKey &&
                    o.startMinutes == slot.startMinutes,
              );
              setModalState(() {
                limitHint = null;
                if (existingIdx != -1) {
                  selectedOptions.removeAt(existingIdx);
                } else if (selectedOptions.length >= 3) {
                  limitHint =
                      'You can propose up to 3 times. Remove one to pick another.';
                } else {
                  selectedOptions.add(
                    ProposedTimeOption(
                      date: day,
                      timeSlot: slot.time,
                      startMinutes: slot.startMinutes,
                      durationMinutes: tempDurationMinutes,
                    ),
                  );
                  selectedOptions.sort((a, b) {
                    final cmp = a.date.compareTo(b.date);
                    if (cmp != 0) return cmp;
                    return a.startMinutes.compareTo(b.startMinutes);
                  });
                }
              });
            }

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
              ),
              child: AdaptiveGlassContainer.bottomSheet(
                glassEnabled: true,
                androidSurfaceColor: const Color(0xFF171A1A),
                topRadius: AppRadius.radiusSheet,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.viewInsetsOf(ctx).bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF333838),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Propose Session Time & Quote',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pick up to 3 open dates & times for ${widget.request.clientName}. Availability is re-checked live when they choose.',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C9191),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected Proposed Options Summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PROPOSED OPTIONS (${selectedOptions.length}/3)',
                            key: const Key('proposed_options_counter'),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFEEC200),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (selectedOptions.isNotEmpty)
                            GestureDetector(
                              onTap: () => setModalState(() {
                                selectedOptions.clear();
                                limitHint = null;
                              }),
                              child: Text(
                                'Clear',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF8C9191),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (selectedOptions.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2121),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF2C2F30)),
                          ),
                          child: Text(
                            'Tap an open date below, then select 1–3 time slots to send.',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8C9191),
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedOptions.asMap().entries.map((entry) {
                            final opt = entry.value;
                            return Container(
                              key: Key('selected_proposal_chip_${entry.key}'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x24EEC200),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFEEC200),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_formatShortDate(opt.date)} • ${opt.timeSlot}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFFEEC200),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    key: Key('remove_proposal_chip_${entry.key}'),
                                    onTap: () => setModalState(() {
                                      selectedOptions.removeAt(entry.key);
                                      limitHint = null;
                                    }),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Color(0xFFEEC200),
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      if (limitHint != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          limitHint!,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFF59E0B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Interactive Calendar Picker
                      Text(
                        'SELECT AVAILABLE DATE',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEEC200),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141616),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF2C2F30)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  key: const Key('proposal_calendar_prev_month'),
                                  icon: Icon(
                                    Icons.chevron_left,
                                    color: displayMonth.isAfter(firstOfCurrentMonth)
                                        ? Colors.white
                                        : const Color(0xFF444848),
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: displayMonth.isAfter(firstOfCurrentMonth)
                                      ? () => setModalState(() {
                                            displayMonth = DateTime(
                                              displayMonth.year,
                                              displayMonth.month - 1,
                                              1,
                                            );
                                          })
                                      : null,
                                ),
                                Text(
                                  '${_monthNames[displayMonth.month - 1]} ${displayMonth.year}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  key: const Key('proposal_calendar_next_month'),
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => setModalState(() {
                                    displayMonth = DateTime(
                                      displayMonth.year,
                                      displayMonth.month + 1,
                                      1,
                                    );
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: _weekdays
                                  .map(
                                    (d) => SizedBox(
                                      width: 30,
                                      child: Center(
                                        child: Text(
                                          d,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: const Color(0xFF6B7272),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 6),
                            Column(
                              children: List.generate(rowCount, (rowIndex) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: List.generate(7, (colIndex) {
                                      final dayNum =
                                          rowIndex * 7 + colIndex - firstWeekday + 1;
                                      if (dayNum < 1 || dayNum > daysInMonth) {
                                        return const SizedBox(
                                          width: 32,
                                          height: 32,
                                        );
                                      }
                                      final cellDate = DateTime(
                                        displayMonth.year,
                                        displayMonth.month,
                                        dayNum,
                                      );
                                      final isPast = cellDate.isBefore(today);
                                      final isBookable = !isPast &&
                                          ArtistDashboardRepository.isDateBookable(
                                            date: cellDate,
                                            durationMinutes: tempDurationMinutes,
                                            slotType: BookingSlotType.custom,
                                          );
                                      final isSelectedDay =
                                          cellDate.year == tempDate.year &&
                                              cellDate.month == tempDate.month &&
                                              cellDate.day == tempDate.day;
                                      final hasPickedOption = selectedOptions.any(
                                        (o) =>
                                            o.date.year == cellDate.year &&
                                            o.date.month == cellDate.month &&
                                            o.date.day == cellDate.day,
                                      );

                                      return GestureDetector(
                                        key: Key('proposal_calendar_day_$dayNum'),
                                        onTap: !isBookable
                                            ? null
                                            : () => setModalState(() {
                                                  tempDate = cellDate;
                                                  limitHint = null;
                                                }),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelectedDay
                                                ? const Color(0xFFEEC200)
                                                : Colors.transparent,
                                            border: hasPickedOption && !isSelectedDay
                                                ? Border.all(
                                                    color: const Color(0xFFEEC200),
                                                    width: 1.2,
                                                  )
                                                : null,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$dayNum',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: isSelectedDay
                                                    ? const Color(0xFF121414)
                                                    : (!isBookable
                                                        ? const Color(0xFF424747)
                                                        : Colors.white),
                                                fontSize: 12,
                                                fontWeight: isSelectedDay ||
                                                        hasPickedOption
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
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'SELECT TIME SLOTS FOR ${_formatShortDate(tempDate).toUpperCase()}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEEC200),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: slots.map((slot) {
                          final isBooked = slot.isBookedConflict;
                          final isHeld = slot.isHeldConflict;
                          final isUnavailable = slot.isConflicted;
                          final dayKey = ArtistBooksSchedule.dateKey(tempDate);
                          final isSelected = !isUnavailable &&
                              selectedOptions.any(
                                (o) =>
                                    ArtistBooksSchedule.dateKey(o.date) ==
                                        dayKey &&
                                    o.startMinutes == slot.startMinutes,
                              );
                          final isGapWarning =
                              !isUnavailable && slot.createsDeadGap;
                          final label = isBooked
                              ? '${slot.time} (Booked)'
                              : (isHeld
                                  ? '${slot.time} (Held 24h)'
                                  : slot.time);

                          return ChoiceChip(
                            key: Key('proposal_slot_${slot.time}'),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(label),
                                if (isGapWarning) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 13,
                                    color: isSelected
                                        ? AppTheme.onyxBackground
                                        : const Color(0xFFF59E0B),
                                  ),
                                ],
                              ],
                            ),
                            selected: isSelected,
                            showCheckmark: false,
                            selectedColor: AppTheme.gold,
                            backgroundColor: const Color(0xFF1E2121),
                            disabledColor: const Color(0xFF141616),
                            side: BorderSide(
                              color: isSelected
                                  ? AppTheme.gold
                                  : (isUnavailable
                                      ? const Color(0xFF222525)
                                      : (isGapWarning
                                          ? const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.55)
                                          : AppTheme.gold
                                              .withValues(alpha: 0.6))),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                            labelStyle: GoogleFonts.plusJakartaSans(
                              color: isUnavailable
                                  ? const Color(0xFF555A5A)
                                  : (isSelected
                                      ? AppTheme.onyxBackground
                                      : AppTheme.textPrimary),
                              fontSize: 12,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.w600,
                            ),
                            onSelected: isUnavailable
                                ? null
                                : (_) => toggleOption(tempDate, slot),
                          );
                        }).toList(),
                      ),
                      if (slots.any((s) => !s.isConflicted && s.createsDeadGap)) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 13,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Gold-bordered times avoid dead gaps; amber-flagged times leave an awkward <2h hole.',
                                key: const Key('proposal_dead_gap_hint'),
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF8C9191),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Session Duration Selector
                      Text(
                        'ESTIMATED SESSION DURATION',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: durationPresets.map((mins) {
                          final hrs = mins ~/ 60;
                          final isSel = tempDurationMinutes == mins;
                          return ChoiceChip(
                            key: Key('proposal_duration_$mins'),
                            label: Text('$hrs ${hrs == 1 ? 'hr' : 'hrs'}'),
                            selected: isSel,
                            showCheckmark: false,
                            selectedColor: AppTheme.gold,
                            backgroundColor: const Color(0xFF1E2121),
                            labelStyle: GoogleFonts.plusJakartaSans(
                              color: isSel
                                  ? AppTheme.onyxBackground
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight:
                                  isSel ? FontWeight.bold : FontWeight.w500,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  tempDurationMinutes = mins;
                                  final retained = <ProposedTimeOption>[];
                                  int droppedCount = 0;
                                  for (final opt in selectedOptions) {
                                    if (ArtistDashboardRepository.isSlotBookable(
                                      date: opt.date,
                                      timeSlot: opt.timeSlot,
                                      startMinutes: opt.startMinutes,
                                      durationMinutes: mins,
                                    )) {
                                      retained.add(
                                        opt.copyWith(durationMinutes: mins),
                                      );
                                    } else {
                                      droppedCount++;
                                    }
                                  }
                                  selectedOptions
                                    ..clear()
                                    ..addAll(retained);
                                  if (droppedCount > 0) {
                                    limitHint =
                                        'Removed $droppedCount ${droppedCount == 1 ? 'option' : 'options'} that no longer fit a ${mins ~/ 60}h session.';
                                  }
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'QUOTE & DEPOSIT',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEEC200),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2121),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2C2F30)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Estimated Price',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFFC7CDCD),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Color(0xFF8C9191),
                                        size: 18,
                                      ),
                                      onPressed: tempPrice > 50
                                          ? () => setModalState(() => tempPrice -= 25)
                                          : null,
                                    ),
                                    Text(
                                      '\$$tempPrice',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        color: Color(0xFFEEC200),
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          setModalState(() => tempPrice += 25),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(color: Color(0xFF2C2F30), height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Fixed Deposit',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFFC7CDCD),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Color(0xFF8C9191),
                                        size: 18,
                                      ),
                                      onPressed: tempDeposit > 20
                                          ? () => setModalState(
                                                () => tempDeposit -= 10,
                                              )
                                          : null,
                                    ),
                                    Text(
                                      '\$$tempDeposit',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFEEC200),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        color: Color(0xFFEEC200),
                                        size: 18,
                                      ),
                                      onPressed: tempDeposit + 10 <= tempPrice
                                          ? () => setModalState(
                                                () => tempDeposit += 10,
                                              )
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppButtons.primaryCTA(
                        key: const Key('confirm_proposal_button'),
                        onPressed: !canSend
                            ? null
                            : () {
                                ArtistDashboardRepository.sendCustomTimeProposal(
                                  widget.request,
                                  proposedSlots: List.of(selectedOptions),
                                  durationMinutes: tempDurationMinutes,
                                  estimatedPrice: tempPrice,
                                  deposit: tempDeposit,
                                );

                                final primary = selectedOptions.first;
                                setState(() {
                                  _selectedDate = primary.date;
                                  _selectedTimeSlot = primary.timeSlot;
                                  _estimatedPrice = tempPrice;
                                  _deposit = tempDeposit;
                                });
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                Navigator.pop(modalContext);
                                final count = selectedOptions.length;
                                FlashSnackBar.showSuccess(
                                  context,
                                  '$count proposed ${count == 1 ? 'time' : 'times'} sent to ${widget.request.clientName}.',
                                );
                              },
                        text: canSend
                            ? 'Send ${selectedOptions.length} Proposed ${selectedOptions.length == 1 ? 'Time' : 'Times'}'
                            : 'Select at Least 1 Open Time',
                        backgroundColor: const Color(0xFFEEC200),
                        foregroundColor: const Color(0xFF121414),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openAskInfoSheet() {
    final selectedPresetIds = <String>{'ask_size', 'ask_references'};
    final presets = AutoResponsePreset.defaultAskInfoPresets;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            String previewMessage = 'Hey ${widget.request.clientName}! To help me plan your design, could you please send over:\n';
            for (final p in presets.where((p) => selectedPresetIds.contains(p.id))) {
              previewMessage += '${p.messageTemplate}\n';
            }

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
              ),
              child: AdaptiveGlassContainer.bottomSheet(
                glassEnabled: true,
                androidSurfaceColor: const Color(0xFF171A1A),
                topRadius: AppRadius.radiusSheet,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.viewInsetsOf(ctx).bottom + 24,
                  ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF333838),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ask for More Details',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap presets to quickly request the missing details you need.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presets.map((preset) {
                        final isSelected = selectedPresetIds.contains(preset.id);
                        return FilterChip(
                          label: Text(preset.title),
                          selected: isSelected,
                          selectedColor: const Color(0xFFEEC200),
                          backgroundColor: const Color(0xFF1E2121),
                          checkmarkColor: const Color(0xFF121414),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            color: isSelected ? const Color(0xFF121414) : Colors.white,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            setSheetState(() {
                              if (val) {
                                selectedPresetIds.add(preset.id);
                              } else {
                                selectedPresetIds.remove(preset.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MESSAGE PREVIEW',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121414),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2C2F30)),
                      ),
                      child: Text(
                        selectedPresetIds.isEmpty
                            ? 'Select at least one detail preset above.'
                            : previewMessage.trim(),
                        style: GoogleFonts.plusJakartaSans(
                          color: selectedPresetIds.isEmpty
                              ? const Color(0xFF6B7272)
                              : const Color(0xFFC7CDCD),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AppButtons.primaryCTA(
                            key: const Key('send_ask_info_message_button'),
                            onPressed: selectedPresetIds.isEmpty
                                ? null
                                : () {
                                    Navigator.pop(modalContext);
                                    FlashSnackBar.showSuccess(
                                      context,
                                      'Follow-up message sent to ${widget.request.clientName}.',
                                    );
                                  },
                            text: 'Send Message',
                            backgroundColor: const Color(0xFFEEC200),
                            foregroundColor: const Color(0xFF121414),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openPassSheet() {
    String selectedReasonId = 'pass_style';
    final presets = AutoResponsePreset.defaultPassPresets;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final activePreset = presets.firstWhere((p) => p.id == selectedReasonId);

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
              ),
              child: AdaptiveGlassContainer.bottomSheet(
                glassEnabled: true,
                androidSurfaceColor: const Color(0xFF171A1A),
                topRadius: AppRadius.radiusSheet,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.viewInsetsOf(ctx).bottom + 24,
                  ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF333838),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pass on this Request',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Zero penalty on your profile. A courteous message will be sent to ${widget.request.clientName}.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SELECT REASON',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presets.map((preset) {
                        final isSelected = selectedReasonId == preset.id;
                        return ChoiceChip(
                          label: Text(preset.title),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2C3030),
                          backgroundColor: const Color(0xFF1E2121),
                          side: BorderSide(color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF2C2F30)),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            color: isSelected ? const Color(0xFFEEC200) : Colors.white,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            if (val) setSheetState(() => selectedReasonId = preset.id);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'MESSAGE PREVIEW',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121414),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2C2F30)),
                      ),
                      child: Text(
                        activePreset.messageTemplate,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFC7CDCD),
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (activePreset.connectedActionTitle != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.explore_outlined, color: Color(0xFF38BDF8), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Flash.Ink will guide client to: ${activePreset.connectedActionTitle}',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF38BDF8),
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    AppButtons.primaryCTA(
                      key: const Key('confirm_pass_button'),
                      onPressed: () {
                        ArtistDashboardRepository.declineBookingRequest(widget.request.id);
                        Navigator.pop(modalContext);
                        FlashSnackBar.showInfo(
                          context,
                          'Passed on request. Friendly response sent to ${widget.request.clientName}.',
                        );
                        Navigator.pop(context, true);
                      },
                      text: 'Confirm Pass',
                      backgroundColor: const Color(0xFF262A2A),
                      foregroundColor: Colors.white,
                    ),
                  ],
                ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return PinnedBottomActionScaffold(
      backgroundColor: const Color(0xFF121414),
      inlineCTA: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF121414),
        elevation: 0,
        leading: IconButton(
          key: const Key('request_back_button'),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request Details',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      ctaKey: const Key('accept_request_button'),
      ctaText: 'Accept Request',
      onCtaPressed: () {
        ArtistDashboardRepository.acceptBookingRequest(
          request,
          scheduledDate: _selectedDate,
          timeSlot: _selectedTimeSlot,
          customPrice: _estimatedPrice,
          customDeposit: _deposit,
        );
        FlashSnackBar.showSuccess(
          context,
          'Booking request from ${request.clientName} accepted!',
        );
        Navigator.pop(context, true);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2020),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2E3232),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    imageUrl: request.clientAvatar,
                    displayName: request.clientName,
                    radius: 26,
                    fallbackInitial: 'C',
                    initialFontSize: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.clientName,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.history, size: 14, color: Color(0xFF8C9191)),
                            const SizedBox(width: 4),
                            Text(
                              'Submitted ${request.timeAgo}',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF8C9191),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Reference Artwork & Placement Card
            Text(
              'CONCEPT & REFERENCE',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C9191),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2020),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2E3232),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (request.sketchImageUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: FlashImage(
                          urlOrPath: request.sketchImageUrl,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: const Color(0xFF262929),
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_not_supported, color: Color(0xFF8C9191)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (request.referenceImageUrls.length > 1) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final extraUrl in request.referenceImageUrls.skip(1)) ...[
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: FlashImage(
                                    urlOrPath: extraUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: Container(
                                      color: const Color(0xFF262929),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Color(0xFF8C9191),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Client Description',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    request.conceptDescription,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFECEEEE),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(color: Color(0xFF2C2F30), height: 1),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildDetailBadge('Placement', request.placement)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDetailBadge('Category', request.category)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Budget Estimate Card
            Text(
              'FINANCIAL ESTIMATE',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C9191),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2020),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2E3232),
                  width: 1.0,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Scheduled Slot',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF919696),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${_formatShortDate(_selectedDate)} • $_selectedTimeSlot',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Estimated Service Price',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF919696),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$$_estimatedPrice',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Required Deposit',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF919696),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$$_deposit',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEEC200),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Secondary Actions: Propose & Ask Details
            Row(
              children: [
                Expanded(
                  child: AppButtons.secondaryCTA(
                    key: const Key('propose_time_button'),
                    onPressed: () {
                      _openProposeTimeModal();
                    },
                    text: 'Propose New Time',
                    borderColor: const Color(0xFF383C3C),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButtons.secondaryCTA(
                    key: const Key('ask_info_button'),
                    onPressed: () {
                      _openAskInfoSheet();
                    },
                    text: 'Ask Details',
                    borderColor: const Color(0xFF383C3C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    key: const Key('pass_request_button'),
                    onPressed: () {
                      _openPassSheet();
                    },
                    icon: const Icon(Icons.back_hand_outlined, size: 15, color: Color(0xFF8C9191)),
                    label: Text(
                      'Pass with Presets',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('decline_request_button'),
                    onPressed: () {
                      ArtistDashboardRepository.declineBookingRequest(request.id);
                      FlashSnackBar.showError(
                        context,
                        'Declined request from ${request.clientName}.',
                      );
                      Navigator.pop(context, true);
                    },
                    child: Text(
                      'Decline Request',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildDetailBadge(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8C9191),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

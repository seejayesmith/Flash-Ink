import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist_dashboard_data.dart';
import '../../models/booking.dart';
import '../../theme/app_buttons.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/pinned_bottom_action_scaffold.dart';

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
    while (!ArtistDashboardRepository.booksSchedule.isWorkingDay(candidate) &&
        guard < 14) {
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
        (s) => !ArtistDashboardRepository.isTimeSlotBooked(
          date: _selectedDate,
          timeSlot: s.time,
        ),
        orElse: () => const BookingTimeSlot(time: '1:30 PM', period: 'Afternoon'),
      );
      _selectedTimeSlot = firstOpen.time;
    }
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${days[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }

  List<DateTime> _getUpcomingWorkingDays({int count = 6}) {
    final List<DateTime> result = [];
    DateTime cursor = DateTime.now().add(const Duration(days: 1));
    int attempts = 0;
    while (result.length < count && attempts < 30) {
      if (ArtistDashboardRepository.booksSchedule.isWorkingDay(cursor)) {
        result.add(DateTime(cursor.year, cursor.month, cursor.day));
      }
      cursor = cursor.add(const Duration(days: 1));
      attempts++;
    }
    if (result.isEmpty) {
      result.add(_selectedDate);
    }
    return result;
  }

  void _openProposeTimeModal() {
    final workingDays = _getUpcomingWorkingDays();
    DateTime tempDate = _selectedDate;
    String tempSlot = _selectedTimeSlot;
    int tempPrice = _estimatedPrice;
    int tempDeposit = _deposit;

    bool isSlotUnavailable(DateTime day, String slotTime) {
      return ArtistDashboardRepository.isTimeSlotBooked(date: day, timeSlot: slotTime) ||
          ArtistDashboardRepository.hasActiveHoldForSlot(date: day, timeSlot: slotTime);
    }

    String firstAvailableSlotFor(DateTime day, List<BookingTimeSlot> slots, String fallback) {
      for (final s in slots) {
        if (!isSlotUnavailable(day, s.time)) return s.time;
      }
      return fallback;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final slots = ArtistDashboardRepository.booksSchedule.generateTimeSlots();
            final canSend = slots.any((s) => s.time == tempSlot && !isSlotUnavailable(tempDate, s.time));

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
              ),
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
                      'Select an open studio slot and finalize quote for ${widget.request.clientName}.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'SELECT WORKING DAY',
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
                      children: workingDays.map((day) {
                        final isSelected = day.year == tempDate.year &&
                            day.month == tempDate.month &&
                            day.day == tempDate.day;
                        return ChoiceChip(
                          label: Text(_formatShortDate(day)),
                          selected: isSelected,
                          showCheckmark: false,
                          selectedColor: const Color(0xFFEEC200),
                          backgroundColor: const Color(0xFF1E2121),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            color: isSelected ? const Color(0xFF121414) : Colors.white,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                tempDate = day;
                                if (isSlotUnavailable(day, tempSlot)) {
                                  tempSlot = firstAvailableSlotFor(day, slots, tempSlot);
                                }
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SELECT TIME SLOT',
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
                        final isBooked = ArtistDashboardRepository.isTimeSlotBooked(
                          date: tempDate,
                          timeSlot: slot.time,
                        );
                        final isHeld = !isBooked &&
                            ArtistDashboardRepository.hasActiveHoldForSlot(
                              date: tempDate,
                              timeSlot: slot.time,
                            );
                        final isUnavailable = isBooked || isHeld;
                        final isSelected = !isUnavailable && tempSlot == slot.time;
                        final label = isBooked
                            ? '${slot.time} (Booked)'
                            : (isHeld ? '${slot.time} (Held 24h)' : slot.time);

                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          showCheckmark: false,
                          selectedColor: const Color(0xFFEEC200),
                          backgroundColor: const Color(0xFF1E2121),
                          disabledColor: const Color(0xFF141616),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            color: isUnavailable
                                ? const Color(0xFF555A5A)
                                : (isSelected ? const Color(0xFF121414) : Colors.white),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: isUnavailable
                              ? null
                              : (val) {
                                  if (val) {
                                    setModalState(() => tempSlot = slot.time);
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFFC7CDCD), fontSize: 13),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF8C9191), size: 18),
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
                                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFFEEC200), size: 18),
                                    onPressed: () => setModalState(() => tempPrice += 25),
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
                                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFFC7CDCD), fontSize: 13),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF8C9191), size: 18),
                                    onPressed: tempDeposit > 20
                                        ? () => setModalState(() => tempDeposit -= 10)
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
                                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFFEEC200), size: 18),
                                    onPressed: tempDeposit + 10 <= tempPrice
                                        ? () => setModalState(() => tempDeposit += 10)
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
                              final hold = CustomHold(
                                id: 'hold_${DateTime.now().millisecondsSinceEpoch}',
                                requestId: widget.request.id,
                                clientName: widget.request.clientName,
                                date: tempDate,
                                timeSlot: tempSlot,
                                durationMinutes: 180,
                                estimatedPrice: tempPrice,
                                deposit: tempDeposit,
                                createdAt: DateTime.now(),
                                expiresAt: DateTime.now().add(const Duration(hours: 24)),
                              );
                              ArtistDashboardRepository.addCustomHold(hold);

                              setState(() {
                                _selectedDate = tempDate;
                                _selectedTimeSlot = tempSlot;
                                _estimatedPrice = tempPrice;
                                _deposit = tempDeposit;
                              });
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              Navigator.pop(modalContext);
                              FlashSnackBar.showSuccess(
                                context,
                                'Slot held for 24h & proposal sent to ${widget.request.clientName}.',
                              );
                            },
                      text: canSend ? 'Send Proposal & Hold Slot (24h)' : 'No Open Slots on Date',
                      backgroundColor: const Color(0xFFEEC200),
                      foregroundColor: const Color(0xFF121414),
                    ),
                  ],
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
      backgroundColor: const Color(0xFF171A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
      backgroundColor: const Color(0xFF171A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final activePreset = presets.firstWhere((p) => p.id == selectedReasonId);

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
              ),
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
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF262929),
                    child: Text(
                      request.clientName.isNotEmpty ? request.clientName[0] : 'C',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEEC200),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

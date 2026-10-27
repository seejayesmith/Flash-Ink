import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist_dashboard_data.dart';
import '../../models/booking.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/pinned_bottom_action_scaffold.dart';

/// Full-screen view presenting comprehensive appointment details,
/// including interactive Reschedule and Cancellation flows.
class AppointmentDetailScreen extends StatefulWidget {
  final DashboardAppointment appointment;

  const AppointmentDetailScreen({
    super.key,
    required this.appointment,
  });

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late DashboardAppointment _appointment;

  @override
  void initState() {
    super.initState();
    _appointment = widget.appointment;
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  List<DateTime> _getUpcomingWorkingDays() {
    final List<DateTime> days = [];
    DateTime cursor = _appointment.scheduledDate ?? DateTime.now().add(const Duration(days: 1));
    int guard = 0;
    while (days.length < 6 && guard < 28) {
      if (ArtistDashboardRepository.booksSchedule.isWorkingDay(cursor)) {
        days.add(DateTime(cursor.year, cursor.month, cursor.day));
      }
      cursor = cursor.add(const Duration(days: 1));
      guard++;
    }
    if (days.isEmpty) {
      days.add(DateTime.now().add(const Duration(days: 2)));
    }
    return days;
  }

  Future<void> _openRescheduleSheet() async {
    final workingDays = _getUpcomingWorkingDays();
    DateTime selectedDate = workingDays.first;
    final slots = ArtistDashboardRepository.booksSchedule.generateTimeSlots();
    String selectedSlot = slots.firstWhere(
      (s) => !ArtistDashboardRepository.isTimeSlotBooked(
        date: selectedDate,
        timeSlot: s.time,
      ),
      orElse: () => BookingTimeSlot.defaultSlots.first,
    ).time;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reschedule Appointment',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a new working day and open slot for ${_appointment.clientName}. Their \$${_appointment.depositPaid} deposit transfers automatically.',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF919696),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SELECT WORKING DAY',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C9191),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: workingDays.map((day) {
                      final isSelected = day.year == selectedDate.year &&
                          day.month == selectedDate.month &&
                          day.day == selectedDate.day;
                      return ChoiceChip(
                        label: Text(_formatShortDate(day)),
                        selected: isSelected,
                        selectedColor: const Color(0xFFEEC200),
                        backgroundColor: const Color(0xFF262929),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: isSelected ? const Color(0xFF121414) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          setModalState(() {
                            selectedDate = day;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SELECT TIME SLOT',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C9191),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: slots.map((slot) {
                      final isBooked = ArtistDashboardRepository.isTimeSlotBooked(
                        date: selectedDate,
                        timeSlot: slot.time,
                      );
                      final isSelected = selectedSlot == slot.time;
                      return ChoiceChip(
                        label: Text(isBooked ? '${slot.time} (Booked)' : slot.time),
                        selected: isSelected,
                        selectedColor: const Color(0xFFEEC200),
                        backgroundColor: const Color(0xFF262929),
                        disabledColor: const Color(0xFF161818),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: isBooked
                              ? const Color(0xFF555959)
                              : (isSelected ? const Color(0xFF121414) : Colors.white),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: isBooked
                            ? null
                            : (_) {
                                setModalState(() {
                                  selectedSlot = slot.time;
                                });
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      key: const Key('confirm_reschedule_button'),
                      onPressed: () {
                        final updated = ArtistDashboardRepository.rescheduleAppointment(
                          _appointment.id,
                          newDate: selectedDate,
                          newTimeSlot: selectedSlot,
                        );
                        if (updated != null) {
                          setState(() {
                            _appointment = updated;
                          });
                        }
                        Navigator.pop(sheetContext);
                        FlashSnackBar.showSuccess(
                          this.context,
                          'Rescheduled ${_appointment.clientName} to ${_appointment.date} at ${_appointment.time}.',
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
                        'Confirm Reschedule',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCancelConfirmationSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cancel Appointment?',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cancelling ${_appointment.clientName}\'s ${_appointment.serviceType} session on ${_appointment.date} at ${_appointment.time} will release the slot on your calendar and notify the client.',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF262929),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFFEEC200), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Deposit Policy: \$${_appointment.depositPaid} deposit paid is recorded on the client receipt.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('confirm_cancel_appointment_button'),
                  onPressed: () {
                    ArtistDashboardRepository.cancelAppointment(
                      _appointment.id,
                      reason: 'Artist schedule adjustment',
                    );
                    Navigator.pop(sheetContext);
                    FlashSnackBar.showError(
                      context,
                      'Appointment with ${_appointment.clientName} cancelled.',
                    );
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    'Confirm Cancellation',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PinnedBottomActionScaffold(
      backgroundColor: const Color(0xFF121414),
      inlineCTA: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF121414),
        elevation: 0,
        leading: IconButton(
          key: const Key('appointment_back_button'),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Appointment Details',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      ctaKey: const Key('message_client_button'),
      ctaText: 'Message Client',
      onCtaPressed: () {
        FlashSnackBar.showSuccess(
          context,
          'Message sent to ${_appointment.clientName}.',
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status & Time Header Card
            Container(
              padding: const EdgeInsets.all(20),
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
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEC200).withAlpha(30),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEEC200).withAlpha(80)),
                    ),
                    child: const Icon(
                      Icons.access_time_filled,
                      color: Color(0xFFEEC200),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _appointment.time,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _appointment.dotColor.withAlpha(40),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _appointment.dotColor.withAlpha(120)),
                              ),
                              child: Text(
                                _appointment.isConsultation ? 'Consultation' : 'Confirmed',
                                style: GoogleFonts.plusJakartaSans(
                                  color: _appointment.dotColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_appointment.date} • ${_appointment.duration}',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF919696),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Client Info Card
            Text(
              'CLIENT',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C9191),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
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
                    radius: 24,
                    backgroundColor: const Color(0xFF262929),
                    child: Center(
                      child: Text(
                        _appointment.clientName.isNotEmpty ? _appointment.clientName[0] : 'C',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEEC200),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _appointment.clientName,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Verified Client',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF22C55E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      FlashSnackBar.showInfo(
                        context,
                        'Opening chat with ${_appointment.clientName}...',
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFEEC200)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tattoo Service / Artwork Details
            Text(
              'PIECE DETAILS',
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
                  if (_appointment.artworkImageUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: FlashImage(
                          urlOrPath: _appointment.artworkImageUrl,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: const Color(0xFF262929),
                            alignment: Alignment.center,
                            child: const Icon(Icons.brush, color: Color(0xFF8C9191)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    _appointment.serviceType,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF8C9191)),
                      const SizedBox(width: 4),
                      Text(
                        _appointment.placement,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C9191),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF8C9191)),
                      const SizedBox(width: 4),
                      Text(
                        _appointment.duration,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C9191),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (_appointment.notes.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(color: Color(0xFF2C2F30), height: 1),
                    ),
                    Text(
                      'Session Notes',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _appointment.notes,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Financial Summary
            Text(
              'PAYMENT BREAKDOWN',
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
                  _buildPaymentRow('Total Service Estimate', '\$${_appointment.fullPrice}'),
                  const SizedBox(height: 10),
                  _buildPaymentRow('Deposit Received', '-\$${_appointment.depositPaid}', valueColor: const Color(0xFF22C55E)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Color(0xFF2C2F30), height: 1),
                  ),
                  _buildPaymentRow(
                    'Balance Due Upon Completion',
                    '\$${_appointment.balanceDue}',
                    isBold: true,
                    valueColor: const Color(0xFFEEC200),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Secondary Action Buttons
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                key: const Key('reschedule_appointment_button'),
                onPressed: _openRescheduleSheet,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF383C3C), width: 1.5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'Reschedule Appointment',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                key: const Key('cancel_appointment_button'),
                onPressed: _openCancelConfirmationSheet,
                child: Text(
                  'Cancel Appointment',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildPaymentRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isBold ? Colors.white : const Color(0xFF919696),
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: valueColor ?? Colors.white,
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

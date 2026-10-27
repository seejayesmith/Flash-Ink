import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist_dashboard_data.dart';
import '../../models/booking.dart';
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
            return Padding(
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
                            setModalState(() => tempDate = day);
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
                      final isSelected = !isBooked && tempSlot == slot.time;
                      return ChoiceChip(
                        label: Text(isBooked ? '${slot.time} (Booked)' : slot.time),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: const Color(0xFFEEC200),
                        backgroundColor: const Color(0xFF1E2121),
                        disabledColor: const Color(0xFF141616),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: isBooked
                              ? const Color(0xFF555A5A)
                              : (isSelected ? const Color(0xFF121414) : Colors.white),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        onSelected: isBooked
                            ? null
                            : (val) {
                                if (val) {
                                  setModalState(() => tempSlot = slot.time);
                                }
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      key: const Key('confirm_proposal_button'),
                      onPressed: () {
                        setState(() {
                          _selectedDate = tempDate;
                          _selectedTimeSlot = tempSlot;
                          _estimatedPrice = tempPrice;
                          _deposit = tempDeposit;
                        });
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        Navigator.pop(modalContext);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEEC200),
                        foregroundColor: const Color(0xFF121414),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Apply Proposed Slot',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDetailBadge('Placement', request.placement),
                      _buildDetailBadge('Category', request.category),
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
                      Text(
                        'Scheduled Slot',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF919696),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${_formatShortDate(_selectedDate)} • $_selectedTimeSlot',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimated Service Price',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF919696),
                          fontSize: 14,
                        ),
                      ),
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
                      Text(
                        'Required Deposit',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF919696),
                          fontSize: 14,
                        ),
                      ),
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

            // Secondary Actions
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                key: const Key('propose_time_button'),
                onPressed: () {
                  FlashSnackBar.showInfo(
                    context,
                    'Proposal modal opened.',
                  );
                  _openProposeTimeModal();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF383C3C), width: 1.5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'Propose New Time',
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
                    fontSize: 14,
                  ),
                ),
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

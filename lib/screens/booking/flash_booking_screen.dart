import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard_data.dart';
import '../../models/booking.dart';
import '../../features/appointments/domain/models/appointment_item.dart';
import '../../theme/app_buttons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/flash_switch.dart';
import '../../widgets/keyboard_collapse_button.dart';
import '../../services/booking_sync_service.dart';
import '../../services/stripe_service.dart';


/// Full-flow booking screen for claiming a flash artwork piece.
///
/// Features 4 sequential steps:
/// 1. Schedule (Interactive Calendar & Time Slot Picker + Preferences)
/// 2. Client Details & Studio Policy Agreement
/// 3. Order Breakdown & Deposit Payment
/// 4. Celebratory Booking Confirmation & Session Preparation
class FlashBookingScreen extends StatefulWidget {
  final FlashArtwork flash;
  final Artist? artist;

  const FlashBookingScreen({
    super.key,
    required this.flash,
    this.artist,
  });

  @override
  State<FlashBookingScreen> createState() => _FlashBookingScreenState();
}

class _FlashBookingScreenState extends State<FlashBookingScreen> {
  int _currentStep = 0; // 0: Schedule, 1: Details, 2: Payment, 3: Confirmed

  // Step 1 State: Date & Time
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  String _selectedTimeSlot = '1:30 PM';
  late String _selectedPlacement;
  bool _isSilentSession = false;

  // Step 2 State: Details & Policies
  final _nameController = TextEditingController(text: 'Alex Rivers');
  final _phoneController = TextEditingController(text: '(555) 234-5678');
  final _emailController = TextEditingController(text: 'alex.rivers@example.com');
  final _notesController = TextEditingController();
  bool _agreedToPolicies = true;

  // Step 3 State: Payment
  String _selectedPaymentMethod = 'Apple Pay';
  bool _isProcessingPayment = false;
  late final TextEditingController _cardNumberController;
  late final TextEditingController _cardExpiryController;
  late final TextEditingController _cardCvcController;
  late final TextEditingController _cardZipController;

  // Step 4 State: Confirmation
  late final String _confirmationCode;

  final List<String> _placementOptions = [
    'Forearm',
    'Upper Arm',
    'Thigh',
    'Calf',
    'Shoulder / Back',
    'Ribs',
    'Other',
  ];

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  void initState() {
    super.initState();
    // Default to next valid upcoming working date in current/next month
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = now.add(const Duration(days: 2));
    int workingDayGuard = 0;
    while (!ArtistDashboardRepository.booksSchedule.isWorkingDay(_selectedDate) &&
        workingDayGuard < 14) {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      workingDayGuard++;
    }
    if (_selectedDate.month != _currentMonth.month) {
      _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    }

    final initialSlots = ArtistDashboardRepository.booksSchedule.generateTimeSlots();
    if (initialSlots.isNotEmpty &&
        !initialSlots.any((s) => s.time == _selectedTimeSlot)) {
      _selectedTimeSlot = initialSlots.first.time;
    }

    _selectedPlacement = widget.flash.location.split('/').first.trim();
    if (!_placementOptions.contains(_selectedPlacement)) {
      _selectedPlacement = _placementOptions.first;
    }

    final codeNum = (10000 + (_selectedDate.millisecondsSinceEpoch % 89999)).toString();
    _confirmationCode = 'INK-$codeNum';

    _cardNumberController = TextEditingController(text: '4242 4242 4242 4242');
    _cardExpiryController = TextEditingController(text: '12/28');
    _cardCvcController = TextEditingController(text: '123');
    _cardZipController = TextEditingController(text: '90210');
    _cardNumberController.addListener(_onCardFieldChanged);
    _cardExpiryController.addListener(_onCardFieldChanged);
    _cardCvcController.addListener(_onCardFieldChanged);
    _cardZipController.addListener(_onCardFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    });
  }

  void _onCardFieldChanged() {
    setState(() {});
  }

  void _autoFillTestCard() {
    setState(() {
      _selectedPaymentMethod = 'Credit Card (•••• 4242)';
      _cardNumberController.text = '4242 4242 4242 4242';
      _cardExpiryController.text = '12/28';
      _cardCvcController.text = '123';
      _cardZipController.text = '90210';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _cardNumberController.removeListener(_onCardFieldChanged);
    _cardExpiryController.removeListener(_onCardFieldChanged);
    _cardCvcController.removeListener(_onCardFieldChanged);
    _cardZipController.removeListener(_onCardFieldChanged);
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvcController.dispose();
    _cardZipController.dispose();
    super.dispose();
  }

  String get _artistName =>
      widget.artist?.name ?? widget.flash.artistName ?? 'Featured Artist';

  String get _artistLocation =>
      widget.artist?.location ?? widget.flash.location;

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final weekday = days[date.weekday % 7];
    return '$weekday, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _prevMonth() {
    final now = DateTime.now();
    final firstOfCurrent = DateTime(now.year, now.month, 1);
    final prev = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    if (prev.isBefore(firstOfCurrent)) return;
    setState(() {
      _currentMonth = prev;
    });
  }

  void _processPaymentAndConfirm() async {
    setState(() {
      _isProcessingPayment = true;
    });

    final stripeService = StripeService();
    final paymentResult = await stripeService.presentDepositPaymentSheet(
      amountInDollars: widget.flash.deposit.toDouble(),
      flashTitle: widget.flash.title,
      customerEmail: _emailController.text.trim(),
      customerName: _nameController.text.trim(),
      artistStripeAccountId: widget.artist?.id,
      bookingId: _confirmationCode,
      selectedDate: _selectedDate.toIso8601String(),
      selectedTimeSlot: _selectedTimeSlot,
      placement: _selectedPlacement,
    );

    if (!mounted) return;

    setState(() {
      _isProcessingPayment = false;
    });

    if (paymentResult.isSuccess) {
      BookingSyncService.claimedFlashPieceIds.add(widget.flash.id);

      // 1. Instantiate domain FlashBooking record
      final booking = FlashBooking(
        id: _confirmationCode,
        flash: widget.flash,
        artist: widget.artist,
        selectedDate: _selectedDate,
        selectedTimeSlot: _selectedTimeSlot,
        clientName: _nameController.text.trim(),
        clientPhone: _phoneController.text.trim(),
        clientEmail: _emailController.text.trim(),
        placement: _selectedPlacement,
        clientNotes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        isSilentAppointment: _isSilentSession,
        depositAmount: widget.flash.deposit,
        totalAmount: widget.flash.price,
        paymentMethod: _selectedPaymentMethod,
        createdAt: DateTime.now(),
      );

      // 2. Synchronize to Artist Calendar schedule
      final calendarApt = DashboardAppointment(
        id: 'cal_${booking.id}',
        clientName: booking.clientName,
        serviceType: 'Flash: ${widget.flash.title}',
        duration: widget.flash.estimatedTime,
        time: booking.selectedTimeSlot,
        scheduledDate: booking.selectedDate,
        date: _formatDate(booking.selectedDate),
        placement: booking.placement,
        notes: booking.clientNotes ?? (booking.isSilentAppointment ? 'Silent appointment requested.' : ''),
        depositPaid: booking.depositAmount,
        fullPrice: booking.totalAmount,
        artworkImageUrl: widget.flash.imageUrl,
        visitType: 'Flash Tattoo',
        dotColor: const Color(0xFF22C55E),
      );
      ArtistDashboardRepository.addCalendarAppointment(calendarApt);

      // 3. Synchronize to Client Upcoming Appointments list
      final clientApt = ClientAppointment(
        id: booking.id,
        artistName: _artistName,
        artistAvatar: widget.artist?.avatarUrl ?? '',
        studioName: widget.artist?.studioType ?? 'Obsidian Atelier',
        studioAddress: _artistLocation,
        flashTitle: widget.flash.title,
        flashImageUrl: widget.flash.imageUrl,
        dateTime: DateTime(
          booking.selectedDate.year,
          booking.selectedDate.month,
          booking.selectedDate.day,
        ),
        timeSlot: '${booking.selectedTimeSlot} (${widget.flash.estimatedTime})',
        placement: booking.placement,
        depositAmount: booking.depositAmount,
        totalPrice: booking.totalAmount,
        status: AppointmentStatus.confirmed,
        isSilentAppointment: booking.isSilentAppointment,
        notes: booking.clientNotes,
      );
      ClientAppointment.addUpcomingAppointment(clientApt);

      setState(() {
        _currentStep = 3;
      });
    } else if (!paymentResult.isCanceled) {
      FlashSnackBar.showError(
        context,
        paymentResult.errorMessage ?? 'Payment failed. Please try again.',
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentStep == 3) {
          Navigator.of(context).pop(true);
        } else if (_currentStep > 0) {
          setState(() {
            _currentStep--;
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121414),
        appBar: _buildAppBar(),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Progress Indicator
              _buildProgressStepper(),

              // Step Content + Inline CTA
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenGutter,
                    vertical: AppSpacing.spaceMd,
                  ),
                  child: Column(
                    children: [
                      _buildCurrentStepContent(),
                      if (_currentStep < 3) ...[
                        const SizedBox(height: AppSpacing.spaceXl),
                        _buildBottomActionBar(),
                        const SizedBox(height: AppSpacing.spaceMd),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF121414),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          _currentStep == 3 ? Icons.close : Icons.arrow_back,
          color: const Color(0xFFF9FAFA),
        ),
        onPressed: () {
          if (_currentStep == 3) {
            Navigator.of(context).pop(true);
          } else if (_currentStep > 0) {
            setState(() {
              _currentStep--;
            });
          } else {
            Navigator.of(context).pop(false);
          }
        },
      ),
      title: Text(
        _currentStep == 3 ? 'Booking Confirmed' : 'Claim & Book Flash',
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFFF9FAFA),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProgressStepper() {
    final steps = ['Date & Time', 'Details', 'Payment', 'Confirmed'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF171A1A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF262929), width: 1),
        ),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isPast = index < _currentStep;
          final isCurrent = index == _currentStep;
          final isLast = index == steps.length - 1;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isPast || isCurrent
                              ? const Color(0xFFEEC200)
                              : const Color(0xFF2E3333),
                          borderRadius: BorderRadius.circular(AppRadius.dragHandle),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: isCurrent
                              ? const Color(0xFFEEC200)
                              : (isPast ? const Color(0xFFF9FAFA) : const Color(0xFF6B7272)),
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepSchedule();
      case 1:
        return _buildStepDetails();
      case 2:
        return _buildStepPayment();
      case 3:
        return _buildStepConfirmation();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 1: SCHEDULE (Date, Time, Placement, Silent Toggle)
  // ---------------------------------------------------------------------------
  Widget _buildStepSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Artwork Recap Header
        _buildArtworkSummaryBanner(),
        const SizedBox(height: 20),

        // Section Title: Select Date
        Text(
          'SELECT DATE',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        // Calendar Card
        _buildCalendarCard(),
        const SizedBox(height: 24),

        // Section Title: Select Time Slot
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SELECT TIME SLOT',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF919696),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'Session Est. ${widget.flash.estimatedTime}',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEEC200),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Time Slot Chips
        _buildTimeSlotsGrid(),
        const SizedBox(height: 24),

        // Placement Selection
        Text(
          'BODY PLACEMENT',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        _buildPlacementSelector(),
        const SizedBox(height: 20),

        // Silent Session Preference Switch
        _buildSilentSessionTile(),
      ],
    );
  }

  Widget _buildArtworkSummaryBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1A),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: const Color(0xFF262929)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            child: SizedBox(
              width: 58,
              height: 58,
              child: FlashImage(
                urlOrPath: widget.flash.imageUrl,
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
                  widget.flash.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'by $_artistName',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEEC200),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Deposit: \$${widget.flash.deposit} • Full: \$${widget.flash.price}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
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
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    final totalCells = firstWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1A),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: const Color(0xFF38352A), width: 1.2),
      ),
      child: Column(
        children: [
          // Month Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Color(0xFFF9FAFA)),
                onPressed: _prevMonth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF9FAFA),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Color(0xFFF9FAFA)),
                onPressed: _nextMonth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Day of week headers
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

          // Calendar Grid
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

                    final cellDate = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
                    final isPast = cellDate.isBefore(today);
                    final isWorkingDay = ArtistDashboardRepository.booksSchedule.isWorkingDay(cellDate);
                    final isDisabled = isPast || !isWorkingDay;
                    final isSelected = cellDate.year == _selectedDate.year &&
                        cellDate.month == _selectedDate.month &&
                        cellDate.day == _selectedDate.day;

                    return GestureDetector(
                      onTap: isDisabled
                          ? null
                          : () {
                              setState(() {
                                _selectedDate = cellDate;
                              });
                            },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFFEEC200)
                              : Colors.transparent,
                          border: isSelected
                              ? Border.all(color: const Color(0xFFEEC200), width: 1.5)
                              : (cellDate.day == today.day && cellDate.month == today.month
                                  ? Border.all(color: const Color(0xFF4D5252), width: 1)
                                  : null),
                        ),
                        child: Center(
                          child: Text(
                            '$dayNum',
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? const Color(0xFF121414)
                                  : (isDisabled
                                      ? const Color(0xFF424747)
                                      : const Color(0xFFF9FAFA)),
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
    final slots = ArtistDashboardRepository.booksSchedule.generateTimeSlots();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isBooked = ArtistDashboardRepository.isTimeSlotBooked(
          date: _selectedDate,
          timeSlot: slot.time,
          artistId: widget.artist?.id,
        );
        final isSelected = !isBooked && _selectedTimeSlot == slot.time;

        return ChoiceChip(
          label: Text(
            isBooked ? '${slot.time} (Booked)' : slot.time,
          ),
          selected: isSelected,
          showCheckmark: false,
          onSelected: isBooked
              ? null
              : (selected) {
                  if (selected) {
                    setState(() {
                      _selectedTimeSlot = slot.time;
                    });
                  }
                },
          selectedColor: const Color(0xFFEEC200),
          backgroundColor: isBooked ? const Color(0xFF141616) : const Color(0xFF1E2020),
          disabledColor: const Color(0xFF141616),
          labelStyle: GoogleFonts.plusJakartaSans(
            color: isBooked
                ? const Color(0xFF555A5A)
                : (isSelected ? const Color(0xFF121414) : const Color(0xFFF9FAFA)),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            decoration: isBooked ? TextDecoration.lineThrough : null,
          ),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFFEEC200)
                : (isBooked ? const Color(0xFF222525) : const Color(0xFF333737)),
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
      onTap: _showPlacementBottomSheet,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      useGradient: true,
      child: Row(
        children: [
          const Icon(
            Icons.accessibility_new_rounded,
            color: Color(0xFFEEC200),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedPlacement,
              key: const Key('placement_selector_text'),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFF9FAFA),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFFEEC200),
            size: 22,
          ),
        ],
      ),
    );
  }

  void _showPlacementBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _PlacementSelectionBottomSheet(
          initialPlacement: _selectedPlacement,
          options: _placementOptions,
          onSelected: (newPlacement) {
            setState(() {
              _selectedPlacement = newPlacement;
            });
          },
        );
      },
    );
  }

  Widget _buildSilentSessionTile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1A),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: const Color(0xFF262929)),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_off_outlined, color: Color(0xFFEEC200), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Silent Appointment',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Minimal chatter during session. Perfect for resting or reading.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          FlashSwitch(
            value: _isSilentSession,
            onChanged: (val) {
              setState(() {
                _isSilentSession = val;
              });
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: DETAILS & STUDIO POLICIES
  // ---------------------------------------------------------------------------
  Widget _buildStepDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLIENT INFORMATION',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),

        _buildInputField(
          controller: _nameController,
          label: 'Full Legal Name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),

        _buildInputField(
          controller: _phoneController,
          label: 'Phone Number (for SMS reminders)',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),

        _buildInputField(
          controller: _emailController,
          label: 'Email Address (for receipt & prep guide)',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),

        _buildInputField(
          controller: _notesController,
          label: 'Special Notes or Allergies (optional)',
          icon: Icons.note_outlined,
          maxLines: 2,
        ),
        const SizedBox(height: 24),

        Text(
          'STUDIO POLICIES & TERMS',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        _buildPoliciesCard(),
        const SizedBox(height: 16),

        // Policy Agreement Checkbox
        GestureDetector(
          onTap: () {
            setState(() {
              _agreedToPolicies = !_agreedToPolicies;
            });
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreedToPolicies,
                onChanged: (val) {
                  setState(() {
                    _agreedToPolicies = val ?? false;
                  });
                },
                activeColor: const Color(0xFFEEC200),
                checkColor: const Color(0xFF121414),
                side: const BorderSide(color: Color(0xFF4D5252), width: 1.5),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'I confirm I am 18+ years old and agree to the studio deposit and cancellation policies.',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF9FAFA),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(
        color: const Color(0xFFF9FAFA),
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF919696),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFEEC200), size: 20),
        filled: true,
        fillColor: const Color(0xFF171A1A),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
          borderSide: const BorderSide(color: Color(0xFF262929)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
          borderSide: const BorderSide(color: Color(0xFFEEC200), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildPoliciesCard() {
    final policies = [
      'Deposits are non-refundable and credited toward your session balance.',
      '48-hour advance notice is required to reschedule your appointment.',
      'A valid government-issued photo ID (18+) is required at the studio.',
      'Please arrive well-rested, hydrated, and within 10 minutes of start time.',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1A),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: const Color(0xFF2B2F2F)),
      ),
      child: Column(
        children: policies.map((policy) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF4ADE80), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    policy,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFC0C5C5),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: REVIEW & PAYMENT
  // ---------------------------------------------------------------------------
  Widget _buildStepPayment() {
    final deposit = widget.flash.deposit;
    final total = widget.flash.price;
    final balance = total - deposit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Appointment Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF171A1A),
            borderRadius: BorderRadius.circular(AppRadius.radiusLg),
            border: Border.all(color: const Color(0xFF38352A), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: FlashImage(
                        urlOrPath: widget.flash.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.flash.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFF9FAFA),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'by $_artistName',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEEC200),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF262929), height: 24),

              _buildSummaryRow('Date', _formatDate(_selectedDate)),
              const SizedBox(height: 6),
              _buildSummaryRow('Time', '$_selectedTimeSlot (${widget.flash.estimatedTime})'),
              const SizedBox(height: 6),
              _buildSummaryRow('Placement', _selectedPlacement),
              if (_isSilentSession) ...[
                const SizedBox(height: 6),
                _buildSummaryRow('Atmosphere', 'Silent Appointment requested'),
              ],
              const SizedBox(height: 6),
              _buildSummaryRow('Studio', _artistLocation),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Cost Breakdown Card
        Text(
          'PAYMENT BREAKDOWN',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2020),
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(color: const Color(0xFF2B2F2F)),
          ),
          child: Column(
            children: [
              _buildPriceLine('Total Flash Price', '\$$total', isBold: false),
              const SizedBox(height: 8),
              _buildPriceLine(
                'Deposit Due Today',
                '\$$deposit',
                isBold: true,
                color: const Color(0xFFEEC200),
              ),
              const Divider(color: Color(0xFF333737), height: 20),
              _buildPriceLine('Balance Due at Studio', '\$$balance', isBold: false),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Payment Method Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SELECT PAYMENT METHOD',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF919696),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            GestureDetector(
              onTap: _autoFillTestCard,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEC200).withAlpha(30),
                  borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                  border: Border.all(color: const Color(0xFFEEC200), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flash_on, color: Color(0xFFEEC200), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Auto-fill Test Card',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEEC200),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildPaymentMethodTile('Apple Pay', Icons.phone_iphone),
        const SizedBox(height: 8),
        _buildPaymentMethodTile('Credit Card (•••• 4242)', Icons.credit_card),
        if (_selectedPaymentMethod == 'Credit Card (•••• 4242)') ...[
          const SizedBox(height: 8),
          _buildCreditCardForm(),
        ],
        const SizedBox(height: 8),
        _buildPaymentMethodTile('Cash App Pay', Icons.attach_money),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF9FAFA),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceLine(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: color ?? const Color(0xFFC0C5C5),
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: color ?? const Color(0xFFF9FAFA),
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(String method, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF171A1A),
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          border: Border.all(
            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF262929),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF919696),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                method,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF9FAFA),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFEEC200), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCardForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF191C1C),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: const Color(0xFF38352A), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.credit_card, color: Color(0xFFEEC200), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'CARD DETAILS',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF9FAFA),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withAlpha(35),
                  borderRadius: BorderRadius.circular(AppRadius.radiusXs),
                  border: Border.all(color: const Color(0xFF22C55E), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, color: Color(0xFF22C55E), size: 10),
                    const SizedBox(width: 3),
                    Text(
                      'Test Card Ready',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF22C55E),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Card Number Field
          _buildCardField(
            label: 'CARD NUMBER',
            controller: _cardNumberController,
            hintText: 'Card number (16 digits)',
            icon: Icons.lock_outline,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          // Expiry, CVC, Zip Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildCardField(
                  label: 'EXPIRES',
                  controller: _cardExpiryController,
                  hintText: 'MM/YY',
                  keyboardType: TextInputType.datetime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildCardField(
                  label: 'CVC',
                  controller: _cardCvcController,
                  hintText: 'CVC',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _buildCardField(
                  label: 'ZIP',
                  controller: _cardZipController,
                  hintText: 'ZIP Code',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Notice badge
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF919696), size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Stripe mock test card auto-filled. You can proceed without actual charges.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF141616),
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            border: Border.all(color: const Color(0xFF2E3333)),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: const Color(0xFF919696), size: 16),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: hintText,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF6B7272),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 4: CONFIRMATION & PREP GUIDE
  // ---------------------------------------------------------------------------
  Widget _buildStepConfirmation() {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Golden Badge
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF38351F),
            border: Border.all(color: const Color(0xFFEEC200), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEEC200).withAlpha(40),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.check, color: Color(0xFFEEC200), size: 44),
          ),
        ),
        const SizedBox(height: 18),

        Text(
          'Flash Claimed & Booked!',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF9FAFA),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ref: $_confirmationCode',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFEEC200),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'A confirmation email and SMS receipt have been sent.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),

        // Appointment Recap Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF171A1A),
            borderRadius: BorderRadius.circular(AppRadius.radiusLg),
            border: Border.all(color: const Color(0xFF262929)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: FlashImage(
                        urlOrPath: widget.flash.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.flash.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFF9FAFA),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Artist: $_artistName',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEEC200),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF262929), height: 20),
              _buildSummaryRow('Date', _formatDate(_selectedDate)),
              const SizedBox(height: 6),
              _buildSummaryRow('Time Slot', _selectedTimeSlot),
              const SizedBox(height: 6),
              _buildSummaryRow('Placement', _selectedPlacement),
              const SizedBox(height: 6),
              _buildSummaryRow('Studio Location', _artistLocation),
              const SizedBox(height: 6),
              _buildSummaryRow('Deposit Paid', '\$${widget.flash.deposit} ($_selectedPaymentMethod)'),
              const SizedBox(height: 6),
              _buildSummaryRow(
                'Balance at Appointment',
                '\$${widget.flash.price - widget.flash.deposit}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Add to calendar action button
        OutlinedButton.icon(
          onPressed: () {
            FlashSnackBar.showSuccess(
              context,
              'Appointment saved to your device calendar!',
              duration: const Duration(seconds: 2),
            );
          },
          icon: const Icon(Icons.calendar_month, color: Color(0xFFEEC200), size: 18),
          label: Text(
            'ADD TO CALENDAR',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFEEC200),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFEEC200)),
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.radiusMd)),
          ),
        ),
        const SizedBox(height: 20),

        // Session Preparation Guidelines
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D1D),
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(color: const Color(0xFF2A2E2E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SESSION PREPARATION TIPS',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEEC200),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              _buildPrepItem('Hydrate thoroughly & eat a solid meal 1-2 hours before.'),
              _buildPrepItem('Bring valid 18+ government photo ID to the studio.'),
              _buildPrepItem('Avoid alcohol or blood thinners for 24 hours prior.'),
              _buildPrepItem('Wear loose, comfortable clothes for easy placement access.'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Done button
        AppButtons.primaryCTA(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          text: 'DONE',
          backgroundColor: const Color(0xFFEEC200),
          foregroundColor: const Color(0xFF121414),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPrepItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, color: Color(0xFFEEC200), size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFC0C5C5),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM ACTION BAR
  // ---------------------------------------------------------------------------
  Widget _buildBottomActionBar() {
    String buttonText;
    VoidCallback? onPressed;

    if (_currentStep == 0) {
      buttonText = 'CONTINUE TO DETAILS';
      onPressed = () {
        setState(() {
          _currentStep = 1;
        });
      };
    } else if (_currentStep == 1) {
      buttonText = 'CONTINUE TO PAYMENT';
      final isFormValid = _nameController.text.trim().isNotEmpty &&
          _phoneController.text.trim().isNotEmpty &&
          _emailController.text.trim().isNotEmpty &&
          _agreedToPolicies;

      onPressed = isFormValid
          ? () {
              setState(() {
                _currentStep = 2;
              });
            }
          : null;
    } else {
      final isCardMethod = _selectedPaymentMethod == 'Credit Card (•••• 4242)';
      final isCardValid = !isCardMethod ||
          (_cardNumberController.text.trim().isNotEmpty &&
              _cardExpiryController.text.trim().isNotEmpty &&
              _cardCvcController.text.trim().isNotEmpty);

      buttonText = 'PAY \$${widget.flash.deposit} DEPOSIT & CONFIRM';
      onPressed = (_isProcessingPayment || !isCardValid)
          ? null
          : _processPaymentAndConfirm;
    }

    return AppButtons.primaryCTA(
      onPressed: onPressed,
      text: buttonText,
      isLoading: _isProcessingPayment,
      backgroundColor: const Color(0xFFEEC200),
      foregroundColor: const Color(0xFF121414),
    );
  }
}

class _PlacementSelectionBottomSheet extends StatefulWidget {
  final String initialPlacement;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _PlacementSelectionBottomSheet({
    required this.initialPlacement,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_PlacementSelectionBottomSheet> createState() =>
      _PlacementSelectionBottomSheetState();
}

class _PlacementSelectionBottomSheetState
    extends State<_PlacementSelectionBottomSheet> {
  late String _currentSelection;
  late final TextEditingController _customController;
  bool _isCustomActive = false;

  @override
  void initState() {
    super.initState();
    _currentSelection = widget.initialPlacement;
    final isPreset = widget.options
        .where((opt) => opt != 'Other')
        .contains(widget.initialPlacement);

    if (!isPreset && widget.initialPlacement.isNotEmpty) {
      _isCustomActive = true;
      _customController = TextEditingController(
        text: widget.initialPlacement == 'Other' ? '' : widget.initialPlacement,
      );
    } else {
      _customController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _selectPreset(String option) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentSelection = option;
      _isCustomActive = false;
    });
    widget.onSelected(option);
    Navigator.of(context).pop();
  }

  void _activateCustom() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentSelection = 'Other';
      _isCustomActive = true;
    });
  }

  void _submitCustom() {
    final text = _customController.text.trim();
    final chosen = text.isNotEmpty ? text : 'Other';
    HapticFeedback.selectionClick();
    widget.onSelected(chosen);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AdaptiveGlassContainer.bottomSheet(
        glassEnabled: true,
        androidSurfaceColor: const Color(0xFF171A1A),
        topRadius: AppRadius.radiusSheet,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4D5252),
                    borderRadius: BorderRadius.circular(AppRadius.dragHandle),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header & Close Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Body Placement',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF9FAFA),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const KeyboardCollapseButton(
                        size: 22,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        key: const Key('close_placement_sheet'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF919696),
                          size: 22,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Choose where you want this flash piece tattooed',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF919696),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF262929), height: 1),

              // Minimalist list rows
              ...widget.options.map((option) {
                final isOther = option == 'Other';
                final isSelected = isOther
                    ? (_isCustomActive ||
                        !widget.options
                            .where((o) => o != 'Other')
                            .contains(_currentSelection))
                    : (_currentSelection == option && !_isCustomActive);

                return Column(
                  children: [
                    InkWell(
                      key: Key('placement_option_$option'),
                      onTap: () {
                        if (isOther) {
                          _activateCustom();
                        } else {
                          _selectPreset(option);
                        }
                      },
                      splashColor: const Color(0xFFEEC200).withAlpha(20),
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option,
                                style: GoogleFonts.plusJakartaSans(
                                  color: isSelected
                                      ? const Color(0xFFEEC200)
                                      : const Color(0xFFF9FAFA),
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_rounded,
                                color: Color(0xFFEEC200),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                    // If Other is active and this is the Other row, show inline input
                    if (isOther && _isCustomActive) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('custom_placement_field'),
                                controller: _customController,
                                autofocus: true,
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFF9FAFA),
                                  fontSize: 14,
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submitCustom(),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Behind ear, Ankle, Ribs',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF6B7280),
                                    fontSize: 13,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF121414),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF262929),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFEEC200),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                key: const Key('confirm_custom_placement_btn'),
                                onPressed: _submitCustom,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEEC200),
                                  foregroundColor: const Color(0xFF121414),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                                child: Text(
                                  'Set',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(color: Color(0xFF262929), height: 1),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}


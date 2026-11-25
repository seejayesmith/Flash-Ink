import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/mock/mock_data_config.dart';
import '../../core/utils/calendar_event_launcher.dart';
import '../../features/appointments/domain/models/appointment_item.dart';
import '../../features/messages/domain/models/message_thread.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard/artist_books_schedule.dart';
import '../../models/artist_dashboard/book_drop.dart';
import '../../models/artist_dashboard/dashboard_appointment.dart';
import '../../models/booking.dart';
import '../../repositories/artist_availability_calculator.dart';
import '../../repositories/artist_dashboard_repository.dart';
import '../../services/booking_sync_service.dart';
import '../../services/scheduling/booking_slot_profile.dart';
import '../../services/scheduling/slot_availability_engine.dart';
import '../../services/stripe_service.dart';
import '../../theme/app_buttons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_snack_bar.dart';
import '../client_account_screen.dart';
import 'widgets/booking_progress_stepper.dart';
import 'widgets/booking_step_confirmation.dart';
import 'widgets/booking_step_details.dart';
import 'widgets/booking_step_payment.dart';
import 'widgets/booking_step_schedule.dart';
import 'widgets/placement_selection_bottom_sheet.dart';

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
  final FirebaseFirestore? firestore;
  final StripeService? stripeService;

  const FlashBookingScreen({
    super.key,
    required this.flash,
    this.artist,
    this.firestore,
    this.stripeService,
  });

  @override
  State<FlashBookingScreen> createState() => _FlashBookingScreenState();
}

class _FlashBookingScreenState extends State<FlashBookingScreen> {
  int _currentStep = 0; // 0: Schedule, 1: Details, 2: Payment, 3: Confirmed

  ArtistBooksSchedule? _remoteArtistSchedule;
  ArtistBooksSchedule get _effectiveSchedule =>
      _remoteArtistSchedule ?? ArtistDashboardRepository.booksSchedule;

  String get _effectiveArtistId {
    final fromArtist = widget.artist?.id.trim() ?? '';
    if (fromArtist.isNotEmpty) return fromArtist;
    return widget.flash.artistId.trim();
  }

  int get _flashDurationMinutes => SlotAvailabilityEngine.parseDurationMinutes(
        widget.flash.estimatedTime,
        fallbackMinutes: _effectiveSchedule.slotDurationMinutes,
      );

  bool _addedToCalendar = false;
  bool _isAddingToCalendar = false;

  // Step 1 State: Date & Time
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  String _selectedTimeSlot = '10:00 AM';
  late String _selectedPlacement;
  bool _isSilentSession = false;

  // Step 2 State: Details & Policies
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  final _notesController = TextEditingController();
  bool _agreedToPolicies = true;

  // Step 3 State: Payment
  final String _selectedPaymentMethod = 'Stripe';
  bool _isProcessingPayment = false;

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

  bool _isUserPhoneVerified = false;
  String _clientAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    String defaultName = MockDataConfig.isEnabled ? 'Alex Rivers' : '';
    String defaultPhone = MockDataConfig.isEnabled ? '(555) 234-5678' : '';
    String defaultEmail =
        MockDataConfig.isEnabled ? 'alex.rivers@example.com' : '';
    bool userPhoneVerified = MockDataConfig.isEnabled;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          defaultName = user.displayName!.trim();
        }
        String? uPhone;
        try {
          uPhone = user.phoneNumber;
        } catch (_) {}
        if (uPhone != null && uPhone.trim().isNotEmpty) {
          defaultPhone = uPhone.trim();
          userPhoneVerified = true;
        } else if (!MockDataConfig.isEnabled) {
          defaultPhone = '';
          userPhoneVerified = false;
        }
        if (user.email != null && user.email!.trim().isNotEmpty) {
          defaultEmail = user.email!.trim();
        }
      }
    } catch (_) {}
    _isUserPhoneVerified = userPhoneVerified;
    _nameController = TextEditingController(text: defaultName);
    _phoneController = TextEditingController(text: defaultPhone);
    _emailController = TextEditingController(text: defaultEmail);
    _checkPhoneVerificationStatus();

    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = now.add(const Duration(days: 2));
    _syncDefaultSelectionForSchedule(now: now);

    _selectedPlacement = widget.flash.location.split('/').first.trim();
    if (!_placementOptions.contains(_selectedPlacement)) {
      _selectedPlacement = _placementOptions.first;
    }

    final codeNum =
        (10000 + (_selectedDate.millisecondsSinceEpoch % 89999)).toString();
    _confirmationCode = 'INK-$codeNum';

    _loadRemoteArtistSchedule();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    });
  }

  void _syncDefaultSelectionForSchedule({DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final schedule = _effectiveSchedule;
    final repoSchedule = ArtistDashboardRepository.booksSchedule;
    final artistId = _effectiveArtistId.isNotEmpty ? _effectiveArtistId : null;
    final durationMins = _flashDurationMinutes;

    DateTime candidate = DateTime(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day + 2,
    );
    int guard = 0;
    while (!ArtistDashboardRepository.isDateBookable(
          date: candidate,
          schedule: schedule,
          artistId: artistId,
          now: effectiveNow,
          durationMinutes: durationMins,
          slotType: BookingSlotType.flash,
        ) &&
        guard < 60) {
      candidate = DateTime(candidate.year, candidate.month, candidate.day + 1);
      guard++;
    }
    if (ArtistDashboardRepository.isDateBookable(
      date: candidate,
      schedule: schedule,
      artistId: artistId,
      now: effectiveNow,
      durationMinutes: durationMins,
      slotType: BookingSlotType.flash,
    )) {
      _selectedDate = candidate;
    }
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);

    final openSlots = SlotAvailabilityEngine.generateAvailableSlots(
      date: _selectedDate,
      schedule: schedule,
      slotType: BookingSlotType.flash,
      requestedDurationMinutes: durationMins,
      localAppointments: ArtistAvailabilityCalculator.matchingAppointments(
        schedule: schedule,
        repoSchedule: repoSchedule,
        calendarAppointments: ArtistDashboardRepository.calendarAppointments,
        artistId: artistId,
      ),
      localHolds: ArtistAvailabilityCalculator.activeLocalHolds(
        schedule: schedule,
        repoSchedule: repoSchedule,
        customHolds: ArtistDashboardRepository.customHolds,
        now: effectiveNow,
      ),
      now: effectiveNow,
      enforceLeadTime:
          ArtistDashboardRepository.bookingMode == BookingMode.alwaysOpen,
      hasBookingOrHoldOnDay: ArtistDashboardRepository.isDateOccupied(
        _selectedDate,
        schedule: schedule,
        artistId: artistId,
        now: effectiveNow,
      ),
    );
    if (openSlots.isNotEmpty &&
        !openSlots.any((s) => s.time == _selectedTimeSlot)) {
      _selectedTimeSlot = openSlots.first.time;
    }
  }

  Future<void> _loadRemoteArtistSchedule() async {
    final artistId = _effectiveArtistId;
    if (artistId.isEmpty) return;
    if (MockDataConfig.isEnabled && widget.firestore == null) return;

    final fetched = await BookingSyncService.fetchArtistScheduleFromCloud(
      artistId,
      firestore: widget.firestore,
    );
    if (!mounted || fetched == null) return;
    setState(() {
      _remoteArtistSchedule = fetched;
      _syncDefaultSelectionForSchedule();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkPhoneVerificationStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final authPhoto = user.photoURL?.trim() ?? '';
        if (authPhoto.isNotEmpty && !authPhoto.startsWith('local://')) {
          _clientAvatarUrl = authPhoto;
        }
        String? uPhone;
        try {
          uPhone = user.phoneNumber;
        } catch (_) {}
        if (uPhone != null && uPhone.trim().isNotEmpty && mounted) {
          setState(() {
            _isUserPhoneVerified = true;
            _phoneController.text = uPhone!.trim();
          });
        }
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null && mounted) {
          final data = doc.data()!;
          final docPhoto = BookingSyncService.extractPhotoUrl(data);
          if (docPhoto.isNotEmpty) {
            _clientAvatarUrl = docPhoto;
          }
          final isVerified = data['phoneVerified'] == true &&
              data['phoneNumber'] != null &&
              (data['phoneNumber'] as String).trim().isNotEmpty;
          if (isVerified && !_isUserPhoneVerified) {
            setState(() {
              _isUserPhoneVerified = true;
              _phoneController.text = data['phoneNumber'] as String;
            });
          }
        }
      }
    } catch (_) {}
  }

  void _showVerifiedPhoneRequiredSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AdaptiveGlassContainer.bottomSheet(
          topRadius: AppRadius.radiusSheet,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0x1AEEC200),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.gold, width: 1.5),
                ),
                child: const Icon(
                  Icons.phone_iphone_outlined,
                  color: AppTheme.gold,
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Verified Phone Required',
                key: const Key('phone_required_sheet_title'),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'To protect artists and receive SMS appointment reminders, Flash.Ink requires a verified phone number on your account.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.navInactive,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              AppButtons.primaryCTA(
                key: const Key('go_to_account_settings_button'),
                text: 'Add Phone in Settings',
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ClientAccountScreen(),
                    ),
                  ).then((_) {
                    _checkPhoneVerificationStatus();
                  });
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('dismiss_phone_required_sheet_button'),
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.navInactive,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String get _artistName =>
      widget.artist?.name ?? widget.flash.artistName ?? 'Featured Artist';

  String get _artistLocation => widget.artist?.location ?? widget.flash.location;

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

  void _handleDateSelected(DateTime cellDate) {
    final artistId = _effectiveArtistId.isNotEmpty ? _effectiveArtistId : null;
    final schedule = _effectiveSchedule;
    final repoSchedule = ArtistDashboardRepository.booksSchedule;
    final now = DateTime.now();
    setState(() {
      _selectedDate = cellDate;
      final openSlots = SlotAvailabilityEngine.generateAvailableSlots(
        date: cellDate,
        schedule: schedule,
        slotType: BookingSlotType.flash,
        requestedDurationMinutes: _flashDurationMinutes,
        localAppointments: ArtistAvailabilityCalculator.matchingAppointments(
          schedule: schedule,
          repoSchedule: repoSchedule,
          calendarAppointments: ArtistDashboardRepository.calendarAppointments,
          artistId: artistId,
        ),
        localHolds: ArtistAvailabilityCalculator.activeLocalHolds(
          schedule: schedule,
          repoSchedule: repoSchedule,
          customHolds: ArtistDashboardRepository.customHolds,
          now: now,
        ),
        now: now,
        enforceLeadTime:
            ArtistDashboardRepository.bookingMode == BookingMode.alwaysOpen,
        hasBookingOrHoldOnDay: ArtistDashboardRepository.isDateOccupied(
          cellDate,
          schedule: schedule,
          artistId: artistId,
          now: now,
        ),
      );
      if (openSlots.isNotEmpty &&
          !openSlots.any((s) => s.time == _selectedTimeSlot)) {
        _selectedTimeSlot = openSlots.first.time;
      }
    });
  }

  void _showPlacementBottomSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return PlacementSelectionBottomSheet(
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

  Future<void> _handleAddToCalendar() async {
    if (_isAddingToCalendar) return;
    setState(() => _isAddingToCalendar = true);

    final event = CalendarEventLauncher.buildTattooAppointmentEvent(
      date: _selectedDate,
      timeSlot: _selectedTimeSlot,
      durationLabel: widget.flash.estimatedTime,
      flashTitle: widget.flash.title,
      artistName: _artistName,
      studioName: widget.artist?.studioType,
      studioAddress: _artistLocation,
      placement: _selectedPlacement,
      depositAmount: widget.flash.deposit,
      totalPrice: widget.flash.price,
      notes: _notesController.text.trim(),
    );

    final added =
        await CalendarEventLauncher.addEventToCalendar(context, event);
    if (!mounted) return;
    setState(() {
      _isAddingToCalendar = false;
      if (added) {
        _addedToCalendar = true;
      }
    });
  }

  void _processPaymentAndConfirm() async {
    setState(() {
      _isProcessingPayment = true;
    });

    final selectedStartMinutes =
        ScheduleSlotEntry.parseTimeLabelToMinutes(_selectedTimeSlot);
    final selectedDurationMinutes = _flashDurationMinutes;
    final selectedBufferMinutes = _effectiveSchedule.bufferDurationMinutes;

    if (_effectiveArtistId.isNotEmpty &&
        (!MockDataConfig.isEnabled || widget.firestore != null)) {
      final check = await BookingSyncService.verifySlotAvailableInCloud(
        artistId: _effectiveArtistId,
        date: _selectedDate,
        timeSlot: _selectedTimeSlot,
        startMinutes: selectedStartMinutes,
        durationMinutes: selectedDurationMinutes,
        bufferMinutes: selectedBufferMinutes,
        firestore: widget.firestore,
      );
      if (!mounted) return;
      if (!check.available) {
        setState(() {
          _isProcessingPayment = false;
          if (check.schedule != null) {
            _remoteArtistSchedule = check.schedule;
          }
          _syncDefaultSelectionForSchedule();
          _currentStep = 0;
        });
        FlashSnackBar.showError(
          context,
          'That time slot was just booked. Please select another available time.',
        );
        return;
      }
    }

    final stripeService = widget.stripeService ?? StripeService();
    final paymentResult = await stripeService.presentDepositPaymentSheet(
      amountInDollars: widget.flash.deposit.toDouble(),
      flashTitle: widget.flash.title,
      flashId: widget.flash.id,
      customerEmail: _emailController.text.trim(),
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      artistId: _effectiveArtistId.isNotEmpty ? _effectiveArtistId : null,
      bookingId: _confirmationCode,
      selectedDate: _selectedDate.toIso8601String(),
      selectedTimeSlot: _selectedTimeSlot,
      startMinutes: selectedStartMinutes,
      durationMinutes: selectedDurationMinutes,
      bufferMinutes: selectedBufferMinutes,
      placement: _selectedPlacement,
      clientNotes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      isSilentAppointment: _isSilentSession,
    );

    if (!mounted) return;

    setState(() {
      _isProcessingPayment = false;
    });

    if (paymentResult.isSuccess) {
      BookingSyncService.claimedFlashPieceIds.add(widget.flash.id);

      String clientId;
      try {
        clientId = FirebaseAuth.instance.currentUser!.uid;
      } catch (_) {
        clientId = BookingSyncService.resolveCurrentUid();
      }
      final artistId = _effectiveArtistId.isNotEmpty
          ? _effectiveArtistId
          : 'artist_unknown';

      final clientAvatar = _clientAvatarUrl.isNotEmpty
          ? _clientAvatarUrl
          : await BookingSyncService.resolveCurrentUserPhotoUrl(uid: clientId);
      if (!mounted) return;

      final booking = FlashBooking(
        id: _confirmationCode,
        clientId: clientId,
        artistId: artistId,
        flash: widget.flash,
        artist: widget.artist,
        selectedDate: _selectedDate,
        selectedTimeSlot: _selectedTimeSlot,
        clientName: _nameController.text.trim(),
        clientPhone: _phoneController.text.trim(),
        clientEmail: _emailController.text.trim(),
        placement: _selectedPlacement,
        clientNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        isSilentAppointment: _isSilentSession,
        depositAmount: widget.flash.deposit,
        totalAmount: widget.flash.price,
        paymentMethod: _selectedPaymentMethod,
        createdAt: DateTime.now(),
      );

      // In live mode, `createPaymentIntent` + `stripeConnectWebhook` write
      // authoritative booking/appointment/chat documents on the server so
      // clients never overwrite server-verified payment status.
      if (paymentResult.isSimulated || widget.firestore != null) {
        BookingSyncService.syncBookingToCloud(
          bookingId: booking.id,
          flashId: widget.flash.id,
          artistId: artistId,
          clientId: clientId,
          depositAmount: booking.depositAmount,
          totalAmount: booking.totalAmount,
          flashTitle: widget.flash.title,
          flashImageUrl: widget.flash.imageUrl,
          selectedDate: booking.selectedDate.toIso8601String(),
          selectedTimeSlot: booking.selectedTimeSlot,
          startMinutes: selectedStartMinutes,
          durationMinutes: selectedDurationMinutes,
          bufferMinutes: selectedBufferMinutes,
          placement: booking.placement,
          clientName: booking.clientName,
          clientAvatar: clientAvatar,
          clientEmail: booking.clientEmail,
          clientPhone: booking.clientPhone,
          clientNotes: booking.clientNotes,
          isSilentAppointment: booking.isSilentAppointment,
          status: 'pending',
          firestore: widget.firestore,
        );
      }

      final calendarApt = DashboardAppointment(
        id: 'cal_${booking.id}',
        clientId: clientId,
        artistId: artistId,
        clientName: booking.clientName,
        clientAvatar: clientAvatar,
        serviceType: 'Flash: ${widget.flash.title}',
        duration: widget.flash.estimatedTime,
        time: booking.selectedTimeSlot,
        scheduledDate: booking.selectedDate,
        date: _formatDate(booking.selectedDate),
        placement: booking.placement,
        notes: booking.clientNotes ??
            (booking.isSilentAppointment
                ? 'Silent appointment requested.'
                : ''),
        depositPaid: booking.depositAmount,
        fullPrice: booking.totalAmount,
        artworkImageUrl: widget.flash.imageUrl,
        visitType: 'Flash Tattoo',
        dotColor: const Color(0xFF22C55E),
      );
      ArtistDashboardRepository.addCalendarAppointment(calendarApt);
      if (widget.firestore != null) {
        BookingSyncService.syncAppointmentToCloud(
          calendarApt,
          clientId: clientId,
          artistId: artistId,
          status: 'confirmed',
          firestore: widget.firestore,
        );
      }
      if (_remoteArtistSchedule != null) {
        final newEntry = ScheduleSlotEntry(
          dateKey: ArtistBooksSchedule.dateKey(booking.selectedDate),
          timeSlot: booking.selectedTimeSlot,
          startMinutes: selectedStartMinutes,
          durationMinutes: selectedDurationMinutes,
          bufferMinutes: selectedBufferMinutes,
        );
        _remoteArtistSchedule = _remoteArtistSchedule!.copyWith(
          bookedSlots: [..._remoteArtistSchedule!.bookedSlots, newEntry],
        );
      }

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

      final receiptText =
          'Flash piece "${widget.flash.title}" claimed for ${_formatDate(booking.selectedDate)} at ${booking.selectedTimeSlot}. Deposit of \$${booking.depositAmount} received.';
      final appointmentStartDateTime =
          ArtistBooksSchedule.parseSlotDateTime(
                booking.selectedDate,
                booking.selectedTimeSlot,
              ) ??
              booking.selectedDate;
      final receiptThread = MessageThread(
        id: 'thread_booking_${booking.id}',
        artistId: artistId,
        clientId: clientId,
        clientName: booking.clientName,
        clientAvatar: clientAvatar,
        artistName: _artistName,
        artistAvatar: widget.artist?.avatarUrl ?? '',
        studioName: widget.artist?.studioType ?? 'Studio',
        lastMessage: receiptText,
        lastMessageTime: DateTime.now(),
        unreadCount: 1,
        isOnline: true,
        flashTitleContext: widget.flash.title,
        messages: [
          ChatMessage(
            id: 'msg_${booking.id}_receipt',
            senderId: clientId,
            senderName: booking.clientName,
            text: receiptText,
            timestamp: DateTime.now(),
            isFromArtist: false,
            type: ChatMessageType.receipt,
            receiptAmount: booking.depositAmount.toDouble(),
            appointmentDate: appointmentStartDateTime,
            appointmentTimeSlot: booking.selectedTimeSlot,
            appointmentDurationMinutes:
                ArtistDashboardRepository.parseDurationMinutes(
              widget.flash.estimatedTime,
            ),
            artistName: _artistName,
            studioLocation: _artistLocation,
            flashTitle: widget.flash.title,
            placement: booking.placement,
            flashImageUrl: widget.flash.imageUrl,
          ),
        ],
      );
      MessageThread.addThread(receiptThread);
      if (paymentResult.isSimulated || widget.firestore != null) {
        BookingSyncService.syncChatThreadToCloud(
          receiptThread,
          clientId: clientId,
          artistId: artistId,
          clientName: booking.clientName,
          clientAvatar: clientAvatar,
          artistAvatar: widget.artist?.avatarUrl,
        );
      }
      ArtistDashboardRepository.notifyPendingRequestsChanged();

      setState(() {
        _currentStep = 3;
      });
    } else if (!paymentResult.isCanceled) {
      if (paymentResult.isSlotConflict) {
        setState(() {
          _currentStep = 0;
        });
        _loadRemoteArtistSchedule();
      }
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
        backgroundColor: AppTheme.onyxBackground,
        appBar: _buildAppBar(),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              BookingProgressStepper(currentStep: _currentStep),
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
      backgroundColor: AppTheme.onyxBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          _currentStep == 3 ? Icons.close : Icons.arrow_back,
          color: AppTheme.textPrimary,
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
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    final artistId = _effectiveArtistId.isNotEmpty ? _effectiveArtistId : null;
    switch (_currentStep) {
      case 0:
        return BookingStepSchedule(
          flash: widget.flash,
          flashDurationMinutes: _flashDurationMinutes,
          artistName: _artistName,
          artistId: artistId,
          schedule: _effectiveSchedule,
          currentMonth: _currentMonth,
          selectedDate: _selectedDate,
          selectedTimeSlot: _selectedTimeSlot,
          selectedPlacement: _selectedPlacement,
          isSilentSession: _isSilentSession,
          onPrevMonth: _prevMonth,
          onNextMonth: _nextMonth,
          onDateSelected: _handleDateSelected,
          onTimeSlotSelected: (time) =>
              setState(() => _selectedTimeSlot = time),
          onPlacementTap: _showPlacementBottomSheet,
          onSilentChanged: (val) => setState(() => _isSilentSession = val),
        );
      case 1:
        return BookingStepDetails(
          nameController: _nameController,
          phoneController: _phoneController,
          emailController: _emailController,
          notesController: _notesController,
          isUserPhoneVerified: _isUserPhoneVerified,
          agreedToPolicies: _agreedToPolicies,
          onFieldChanged: () => setState(() {}),
          onVerifyPhoneTap: _showVerifiedPhoneRequiredSheet,
          onAgreedChanged: (val) => setState(() => _agreedToPolicies = val),
        );
      case 2:
        return BookingStepPayment(
          flash: widget.flash,
          artistName: _artistName,
          artistLocation: _artistLocation,
          formattedDate: _formatDate(_selectedDate),
          selectedTimeSlot: _selectedTimeSlot,
          selectedPlacement: _selectedPlacement,
          isSilentSession: _isSilentSession,
        );
      case 3:
        return BookingStepConfirmation(
          flash: widget.flash,
          artistName: _artistName,
          artistLocation: _artistLocation,
          confirmationCode: _confirmationCode,
          formattedDate: _formatDate(_selectedDate),
          selectedTimeSlot: _selectedTimeSlot,
          selectedPlacement: _selectedPlacement,
          selectedPaymentMethod: _selectedPaymentMethod,
          addedToCalendar: _addedToCalendar,
          isAddingToCalendar: _isAddingToCalendar,
          onAddToCalendar: _handleAddToCalendar,
          onDone: () => Navigator.of(context).pop(true),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomActionBar() {
    String buttonText;
    VoidCallback? onPressed;

    if (_currentStep == 0) {
      buttonText = 'Continue to Details';
      onPressed = () {
        setState(() {
          _currentStep = 1;
        });
      };
    } else if (_currentStep == 1) {
      buttonText = 'Continue to Payment';
      final isFormValid = _nameController.text.trim().isNotEmpty &&
          _emailController.text.trim().isNotEmpty &&
          _agreedToPolicies;

      onPressed = isFormValid
          ? () {
              FocusManager.instance.primaryFocus?.unfocus();
              if (!_isUserPhoneVerified) {
                _showVerifiedPhoneRequiredSheet();
                return;
              }
              setState(() {
                _currentStep = 2;
              });
            }
          : null;
    } else {
      buttonText = 'Pay \$${widget.flash.deposit} Deposit & Confirm';
      onPressed = _isProcessingPayment ? null : _processPaymentAndConfirm;
    }

    return AppButtons.primaryCTA(
      onPressed: onPressed,
      text: buttonText,
      isLoading: _isProcessingPayment,
      backgroundColor: AppTheme.gold,
      foregroundColor: AppTheme.onyxBackground,
    );
  }
}

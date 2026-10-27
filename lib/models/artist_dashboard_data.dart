import 'package:flutter/material.dart';
import 'booking.dart';
import 'waitlist_entry.dart';
import '../features/appointments/domain/models/appointment_item.dart';
import '../features/messages/domain/models/message_thread.dart';
import '../services/booking_sync_service.dart';

/// Represents a scheduled appointment for an artist.
class DashboardAppointment {
  final String id;
  final String clientName;
  final String serviceType;
  final String duration;
  final String time;
  final String date;
  final String placement;
  final String notes;
  final int depositPaid;
  final int fullPrice;
  final String artworkImageUrl;
  final bool isConsultation;
  final Color dotColor;
  final DateTime? scheduledDate;
  final String? visitType;

  const DashboardAppointment({
    required this.id,
    required this.clientName,
    required this.serviceType,
    required this.duration,
    required this.time,
    this.date = 'Today',
    this.placement = 'Forearm',
    this.notes = '',
    this.depositPaid = 50,
    this.fullPrice = 250,
    this.artworkImageUrl = '',
    this.isConsultation = false,
    this.dotColor = const Color(0xFF22C55E),
    this.scheduledDate,
    this.visitType,
  });

  DashboardAppointment copyWith({
    String? id,
    String? clientName,
    String? serviceType,
    String? duration,
    String? time,
    String? date,
    String? placement,
    String? notes,
    int? depositPaid,
    int? fullPrice,
    String? artworkImageUrl,
    bool? isConsultation,
    Color? dotColor,
    DateTime? scheduledDate,
    String? visitType,
  }) {
    return DashboardAppointment(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      serviceType: serviceType ?? this.serviceType,
      duration: duration ?? this.duration,
      time: time ?? this.time,
      date: date ?? this.date,
      placement: placement ?? this.placement,
      notes: notes ?? this.notes,
      depositPaid: depositPaid ?? this.depositPaid,
      fullPrice: fullPrice ?? this.fullPrice,
      artworkImageUrl: artworkImageUrl ?? this.artworkImageUrl,
      isConsultation: isConsultation ?? this.isConsultation,
      dotColor: dotColor ?? this.dotColor,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      visitType: visitType ?? this.visitType,
    );
  }

  int get balanceDue => fullPrice - depositPaid;

  String get effectiveVisitType {
    if (visitType != null && visitType!.trim().isNotEmpty) {
      return visitType!.trim();
    }
    if (isConsultation) {
      return 'Consultation';
    }
    final lower = serviceType.toLowerCase();
    if (lower.contains('cover-up') || lower.contains('cover up')) {
      return 'Cover-up';
    }
    if (lower.contains('touch-up') || lower.contains('touch up')) {
      return 'Touch-up';
    }
    if (lower.contains('flash')) {
      return 'Flash Tattoo';
    }
    if (lower.contains('custom')) {
      return 'Custom Tattoo';
    }
    if (lower.contains('fine line') || lower.contains('fineline')) {
      return 'Fine Line';
    }
    if (lower.contains('traditional')) {
      return 'Traditional';
    }
    if (lower.contains('session')) {
      return 'Session Inking';
    }
    return 'Tattoo Session';
  }
}

/// Represents an incoming booking / custom request waiting for artist review.
class BookingRequest {
  final String id;
  final String clientName;
  final String timeAgo;
  final String conceptDescription;
  final String placement;
  final String category;
  final String sketchImageUrl;
  final int estimatedPrice;
  final int deposit;
  final String size;
  final bool isSilentAppointment;
  final String artistName;
  final DateTime? preferredDate;
  final String? preferredTimeSlot;

  const BookingRequest({
    required this.id,
    required this.clientName,
    required this.timeAgo,
    required this.conceptDescription,
    this.placement = 'Outer Thigh',
    this.category = 'Neo-traditional',
    required this.sketchImageUrl,
    this.estimatedPrice = 300,
    this.deposit = 80,
    this.size = 'Medium (4"-7")',
    this.isSilentAppointment = false,
    this.artistName = 'OddMaree',
    this.preferredDate,
    this.preferredTimeSlot,
  });

  BookingRequest copyWith({
    String? id,
    String? clientName,
    String? timeAgo,
    String? conceptDescription,
    String? placement,
    String? category,
    String? sketchImageUrl,
    int? estimatedPrice,
    int? deposit,
    String? size,
    bool? isSilentAppointment,
    String? artistName,
    DateTime? preferredDate,
    String? preferredTimeSlot,
  }) {
    return BookingRequest(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      timeAgo: timeAgo ?? this.timeAgo,
      conceptDescription: conceptDescription ?? this.conceptDescription,
      placement: placement ?? this.placement,
      category: category ?? this.category,
      sketchImageUrl: sketchImageUrl ?? this.sketchImageUrl,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      deposit: deposit ?? this.deposit,
      size: size ?? this.size,
      isSilentAppointment: isSilentAppointment ?? this.isSilentAppointment,
      artistName: artistName ?? this.artistName,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTimeSlot: preferredTimeSlot ?? this.preferredTimeSlot,
    );
  }
}

/// Top-level metrics displayed on the artist dashboard.
class ArtistDashboardStats {
  final int bookingsThisWeek;
  final int newRequests;
  final int pendingCount;

  const ArtistDashboardStats({
    this.bookingsThisWeek = 12,
    this.newRequests = 2,
    this.pendingCount = 4,
  });
}

/// Earnings metrics and payout information for the artist.
class ArtistEarningsData {
  final double nextPayoutAmount;
  double get availableFundsAmount => nextPayoutAmount;
  final int mtdAmount;
  final int ytdAmount;
  final String ytdYear;

  const ArtistEarningsData({
    this.nextPayoutAmount = 1256.09,
    this.mtdAmount = 3467,
    this.ytdAmount = 16987,
    this.ytdYear = '2026',
  });
}

/// Represents the configuration for an artist's booking schedule ("Books").
class ArtistBooksSchedule {
  final bool isBooksOpen;
  final bool isEarlyAccessOnly;
  final DateTime? earlyAccessEndsAt;
  final int earlyAccessHours;
  final DateTime bookingWindowStart;
  final DateTime bookingWindowEnd;
  final Set<int> workingDays; // 1 = Mon, 7 = Sun (DateTime weekday constants)
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int slotDurationMinutes; // e.g. 60, 120, 180
  final int bufferDurationMinutes; // e.g. 15, 30, 45, 60
  final int defaultDepositAmount; // e.g. 50, 80, 100
  final bool acceptFlash;
  final bool acceptCustom;
  final bool acceptTouchUps;
  final String locationNote;

  const ArtistBooksSchedule({
    this.isBooksOpen = true,
    this.isEarlyAccessOnly = false,
    this.earlyAccessEndsAt,
    this.earlyAccessHours = 24,
    required this.bookingWindowStart,
    required this.bookingWindowEnd,
    this.workingDays = const {2, 3, 4, 5, 6}, // Tue - Sat
    this.startTime = const TimeOfDay(hour: 11, minute: 0),
    this.endTime = const TimeOfDay(hour: 19, minute: 0),
    this.slotDurationMinutes = 120,
    this.bufferDurationMinutes = 30,
    this.defaultDepositAmount = 80,
    this.acceptFlash = true,
    this.acceptCustom = true,
    this.acceptTouchUps = true,
    this.locationNote = 'OddMaree Studio • Portland, OR',
  });

  /// Returns true if the artist's books are open and the given date falls on a configured working weekday.
  bool isWorkingDay(DateTime date) {
    if (!isBooksOpen) return false;
    return workingDays.contains(date.weekday);
  }

  /// Generates available time slots from the artist's configured working hours,
  /// session duration, and buffer time.
  List<BookingTimeSlot> generateTimeSlots({bool forceDynamic = false}) {
    if (!isBooksOpen) return const [];
    final isDefaultConfig = !forceDynamic &&
        startTime.hour == 11 &&
        startTime.minute == 0 &&
        endTime.hour == 19 &&
        endTime.minute == 0 &&
        slotDurationMinutes == 120 &&
        bufferDurationMinutes == 30;
    if (isDefaultConfig) {
      return BookingTimeSlot.defaultSlots;
    }

    final startTotalMinutes = startTime.hour * 60 + startTime.minute;
    final endTotalMinutes = endTime.hour * 60 + endTime.minute;
    final step = (slotDurationMinutes + bufferDurationMinutes).clamp(15, 720);
    final List<BookingTimeSlot> slots = [];

    int currentMinutes = startTotalMinutes;
    while (currentMinutes + slotDurationMinutes <= endTotalMinutes) {
      final hour24 = currentMinutes ~/ 60;
      final minute = currentMinutes % 60;
      final periodLabel = hour24 < 12
          ? 'Morning'
          : (hour24 < 17 ? 'Afternoon' : 'Evening');
      final suffix = hour24 >= 12 ? 'PM' : 'AM';
      final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
      final minStr = minute.toString().padLeft(2, '0');
      slots.add(
        BookingTimeSlot(
          time: '$hour12:$minStr $suffix',
          period: periodLabel,
        ),
      );
      currentMinutes += step;
    }

    return slots.isEmpty ? BookingTimeSlot.defaultSlots : slots;
  }

  bool get isEffectiveBooksOpen {
    if (!isBooksOpen) return false;
    if (isEarlyAccessOnly) {
      if (earlyAccessEndsAt != null && DateTime.now().isAfter(earlyAccessEndsAt!)) {
        return true; // Auto-transitioned to public open!
      }
      return false; // Still exclusive early access
    }
    return true;
  }

  bool get isEarlyAccessActive {
    if (!isBooksOpen || !isEarlyAccessOnly) return false;
    if (earlyAccessEndsAt != null && DateTime.now().isAfter(earlyAccessEndsAt!)) {
      return false; // Expired
    }
    return true;
  }

  Duration? get earlyAccessTimeRemaining {
    if (!isEarlyAccessActive || earlyAccessEndsAt == null) return null;
    final diff = earlyAccessEndsAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  ArtistBooksSchedule copyWith({
    bool? isBooksOpen,
    bool? isEarlyAccessOnly,
    DateTime? earlyAccessEndsAt,
    int? earlyAccessHours,
    DateTime? bookingWindowStart,
    DateTime? bookingWindowEnd,
    Set<int>? workingDays,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? slotDurationMinutes,
    int? bufferDurationMinutes,
    int? defaultDepositAmount,
    bool? acceptFlash,
    bool? acceptCustom,
    bool? acceptTouchUps,
    String? locationNote,
  }) {
    return ArtistBooksSchedule(
      isBooksOpen: isBooksOpen ?? this.isBooksOpen,
      isEarlyAccessOnly: isEarlyAccessOnly ?? this.isEarlyAccessOnly,
      earlyAccessEndsAt: earlyAccessEndsAt ?? this.earlyAccessEndsAt,
      earlyAccessHours: earlyAccessHours ?? this.earlyAccessHours,
      bookingWindowStart: bookingWindowStart ?? this.bookingWindowStart,
      bookingWindowEnd: bookingWindowEnd ?? this.bookingWindowEnd,
      workingDays: workingDays ?? this.workingDays,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      bufferDurationMinutes: bufferDurationMinutes ?? this.bufferDurationMinutes,
      defaultDepositAmount: defaultDepositAmount ?? this.defaultDepositAmount,
      acceptFlash: acceptFlash ?? this.acceptFlash,
      acceptCustom: acceptCustom ?? this.acceptCustom,
      acceptTouchUps: acceptTouchUps ?? this.acceptTouchUps,
      locationNote: locationNote ?? this.locationNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isBooksOpen': isBooksOpen,
      'isEarlyAccessOnly': isEarlyAccessOnly,
      'earlyAccessEndsAt': earlyAccessEndsAt?.toIso8601String(),
      'earlyAccessHours': earlyAccessHours,
      'bookingWindowStart': bookingWindowStart.toIso8601String(),
      'bookingWindowEnd': bookingWindowEnd.toIso8601String(),
      'workingDays': workingDays.toList(),
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'slotDurationMinutes': slotDurationMinutes,
      'bufferDurationMinutes': bufferDurationMinutes,
      'defaultDepositAmount': defaultDepositAmount,
      'acceptFlash': acceptFlash,
      'acceptCustom': acceptCustom,
      'acceptTouchUps': acceptTouchUps,
      'locationNote': locationNote,
    };
  }

  factory ArtistBooksSchedule.fromMap(Map<String, dynamic> map) {
    return ArtistBooksSchedule(
      isBooksOpen: map['isBooksOpen'] as bool? ?? true,
      isEarlyAccessOnly: map['isEarlyAccessOnly'] as bool? ?? false,
      earlyAccessEndsAt: map['earlyAccessEndsAt'] != null
          ? DateTime.tryParse(map['earlyAccessEndsAt'] as String)
          : null,
      earlyAccessHours: (map['earlyAccessHours'] as num?)?.toInt() ?? 24,
      bookingWindowStart: map['bookingWindowStart'] != null
          ? DateTime.tryParse(map['bookingWindowStart'] as String) ?? DateTime(2026, 10, 1)
          : DateTime(2026, 10, 1),
      bookingWindowEnd: map['bookingWindowEnd'] != null
          ? DateTime.tryParse(map['bookingWindowEnd'] as String) ?? DateTime(2026, 12, 31)
          : DateTime(2026, 12, 31),
      workingDays: map['workingDays'] != null
          ? (map['workingDays'] as List).map((e) => (e as num).toInt()).toSet()
          : const {2, 3, 4, 5, 6},
      startTime: TimeOfDay(
        hour: (map['startHour'] as num?)?.toInt() ?? 11,
        minute: (map['startMinute'] as num?)?.toInt() ?? 0,
      ),
      endTime: TimeOfDay(
        hour: (map['endHour'] as num?)?.toInt() ?? 19,
        minute: (map['endMinute'] as num?)?.toInt() ?? 0,
      ),
      slotDurationMinutes: (map['slotDurationMinutes'] as num?)?.toInt() ?? 120,
      bufferDurationMinutes: (map['bufferDurationMinutes'] as num?)?.toInt() ?? 30,
      defaultDepositAmount: (map['defaultDepositAmount'] as num?)?.toInt() ?? 80,
      acceptFlash: map['acceptFlash'] as bool? ?? true,
      acceptCustom: map['acceptCustom'] as bool? ?? true,
      acceptTouchUps: map['acceptTouchUps'] as bool? ?? true,
      locationNote: map['locationNote'] as String? ?? 'OddMaree Studio • Portland, OR',
    );
  }
}

/// Mock data repository for the artist dashboard matching the visual design.
class ArtistDashboardRepository {
  static ArtistBooksSchedule booksSchedule = ArtistBooksSchedule(
    isBooksOpen: true,
    isEarlyAccessOnly: false,
    bookingWindowStart: DateTime(2026, 10, 1),
    bookingWindowEnd: DateTime(2026, 12, 31),
    workingDays: const {2, 3, 4, 5, 6},
    startTime: const TimeOfDay(hour: 11, minute: 0),
    endTime: const TimeOfDay(hour: 19, minute: 0),
    slotDurationMinutes: 120,
    bufferDurationMinutes: 30,
    defaultDepositAmount: 80,
    acceptFlash: true,
    acceptCustom: true,
    acceptTouchUps: true,
    locationNote: 'OddMaree Studio • Portland, OR',
  );

  static void updateBooksSchedule(ArtistBooksSchedule updated) {
    booksSchedule = updated;
    BookingSyncService.syncBooksScheduleToCloud(updated);
  }

  /// In-memory VIP waitlist entries
  static List<WaitlistEntry> waitlistEntries = List.from(WaitlistEntry.mockWaitlistEntries);

  static void addWaitlistEntry(WaitlistEntry entry) {
    waitlistEntries = [entry, ...waitlistEntries];
  }

  static void updateWaitlistEntry(WaitlistEntry entry) {
    final idx = waitlistEntries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      final updated = List<WaitlistEntry>.from(waitlistEntries);
      updated[idx] = entry;
      waitlistEntries = updated;
    }
  }

  static void removeWaitlistEntry(String id) {
    waitlistEntries = waitlistEntries.where((e) => e.id != id).toList();
  }

  /// Triggers exclusive early access to all waiting contacts on the waitlist
  static void sendEarlyAccessToWaitlist({int hours = 24}) {
    final endsAt = DateTime.now().add(Duration(hours: hours));
    booksSchedule = booksSchedule.copyWith(
      isBooksOpen: true,
      isEarlyAccessOnly: true,
      earlyAccessEndsAt: endsAt,
      earlyAccessHours: hours,
    );

    // Update entries that are waiting -> earlyAccessSent
    waitlistEntries = waitlistEntries.map((e) {
      if (e.status == WaitlistStatus.waiting) {
        return e.copyWith(
          status: WaitlistStatus.earlyAccessSent,
          invitedAt: DateTime.now(),
        );
      }
      return e;
    }).toList();
  }

  /// Transitions books to completely open to the general public
  static void openBooksPublicly() {
    booksSchedule = booksSchedule.copyWith(
      isBooksOpen: true,
      isEarlyAccessOnly: false,
      earlyAccessEndsAt: null,
    );
  }

  /// Closes books
  static void closeBooks() {
    booksSchedule = booksSchedule.copyWith(
      isBooksOpen: false,
      isEarlyAccessOnly: false,
      earlyAccessEndsAt: null,
    );
  }


  static const ArtistEarningsData earningsData = ArtistEarningsData();
  static const DashboardAppointment nextAppointment = DashboardAppointment(
    id: 'apt_hero_tiger',
    clientName: 'Sarah Jenkins',
    serviceType: 'Neo-traditional TIGER',
    duration: '3 hrs',
    time: '10:00 AM',
    date: 'Today',
    placement: 'Upper Thigh',
    notes: 'Custom neo-traditional tiger head. Client requested bold color saturation on gold fur and teal waves.',
    depositPaid: 100,
    fullPrice: 400,
    artworkImageUrl: 'assets/images/flash_tiger_tattoo.jpg',
    dotColor: Color(0xFF22C55E),
  );

  static const List<DashboardAppointment> _defaultTodaySchedule = [
    DashboardAppointment(
      id: 'apt_sally',
      clientName: 'Sally McField',
      serviceType: 'Consultation',
      duration: '1hr',
      time: '12:30 PM',
      date: 'Today',
      placement: 'Backpiece Discussion',
      notes: 'Initial consultation to map out placement, flow, and references for full back dragon.',
      depositPaid: 0,
      fullPrice: 50,
      isConsultation: true,
      dotColor: Color(0xFF919696),
    ),
    DashboardAppointment(
      id: 'apt_tom',
      clientName: 'Tom Hanks',
      serviceType: 'Traditional',
      duration: '3hrs',
      time: '2:00 PM',
      date: 'Today',
      placement: 'Forearm',
      notes: 'Traditional anchor & swallow flash piece with red banner.',
      depositPaid: 60,
      fullPrice: 280,
      artworkImageUrl: 'assets/images/flash_anchor.jpg',
      dotColor: Color(0xFF22C55E),
    ),
    DashboardAppointment(
      id: 'apt_jennie',
      clientName: 'Jennie Banks',
      serviceType: 'Fine Line',
      duration: '2hr',
      time: '6:30 PM',
      date: 'Today',
      placement: 'Collarbone',
      notes: 'Delicate fine line floral botanical branch with single needle shading.',
      depositPaid: 50,
      fullPrice: 220,
      artworkImageUrl: 'assets/images/flash_fineline_flora.jpg',
      dotColor: Color(0xFF22C55E),
    ),
  ];

  static List<DashboardAppointment> todaySchedule = List.from(_defaultTodaySchedule);

  static const List<BookingRequest> _defaultPendingRequests = [
    BookingRequest(
      id: 'req_sarah_1',
      clientName: 'Sarah Jenkins',
      timeAgo: '2 days ago',
      conceptDescription: 'Neo-traditional panther head on outer thigh. Looking for heavy blackwork.',
      placement: 'Outer Thigh',
      category: 'Neo-traditional',
      sketchImageUrl: 'assets/images/flash_traditional_panther.jpg',
      estimatedPrice: 350,
      deposit: 90,
    ),
    BookingRequest(
      id: 'req_elena_1',
      clientName: 'Elena Rostova',
      timeAgo: '3 days ago',
      conceptDescription: 'Japanese traditional Hannya mask, half sleeve cover-up.',
      placement: 'Upper Arm / Half Sleeve',
      category: 'Japanese Traditional',
      sketchImageUrl: 'assets/images/flash_japanese_oni.jpg',
      estimatedPrice: 420,
      deposit: 120,
    ),
    BookingRequest(
      id: 'req_elena_2',
      clientName: 'Elena Rostova',
      timeAgo: '3 days ago',
      conceptDescription: 'Japanese traditional Hannya mask, half sleeve cover-up.',
      placement: 'Upper Arm / Half Sleeve',
      category: 'Japanese Traditional',
      sketchImageUrl: 'assets/images/flash_japanese_oni.jpg',
      estimatedPrice: 420,
      deposit: 120,
    ),
    BookingRequest(
      id: 'req_elena_3',
      clientName: 'Elena Rostova',
      timeAgo: '3 days ago',
      conceptDescription: 'Japanese traditional Hannya mask, half sleeve cover-up.',
      placement: 'Upper Arm / Half Sleeve',
      category: 'Japanese Traditional',
      sketchImageUrl: 'assets/images/flash_japanese_oni.jpg',
      estimatedPrice: 420,
      deposit: 120,
    ),
  ];

  static List<BookingRequest> pendingRequests = List.from(_defaultPendingRequests);

  /// Notifier triggered whenever pending requests or dashboard stats change in real time.
  static final ValueNotifier<int> pendingRequestsNotifier = ValueNotifier<int>(0);

  static void notifyPendingRequestsChanged() {
    pendingRequestsNotifier.value++;
  }

  static ArtistDashboardStats _stats = ArtistDashboardStats(
    bookingsThisWeek: 12,
    newRequests: 2,
    pendingCount: _defaultPendingRequests.length,
  );

  static ArtistDashboardStats get stats => ArtistDashboardStats(
    bookingsThisWeek: _stats.bookingsThisWeek,
    newRequests: _stats.newRequests,
    pendingCount: pendingRequests.length,
  );

  static set stats(ArtistDashboardStats value) {
    _stats = value;
    notifyPendingRequestsChanged();
  }

  /// Resets pending requests and dashboard stats back to defaults (useful for test isolation).
  static void resetMockData() {
    pendingRequests = List.from(_defaultPendingRequests);
    todaySchedule = List.from(_defaultTodaySchedule);
    _stats = ArtistDashboardStats(
      bookingsThisWeek: 12,
      newRequests: 2,
      pendingCount: pendingRequests.length,
    );
    booksSchedule = ArtistBooksSchedule(
      isBooksOpen: true,
      isEarlyAccessOnly: false,
      bookingWindowStart: DateTime(2026, 10, 1),
      bookingWindowEnd: DateTime(2026, 12, 31),
      workingDays: const {2, 3, 4, 5, 6},
      startTime: const TimeOfDay(hour: 11, minute: 0),
      endTime: const TimeOfDay(hour: 19, minute: 0),
      slotDurationMinutes: 120,
      bufferDurationMinutes: 30,
      defaultDepositAmount: 80,
      acceptFlash: true,
      acceptCustom: true,
      acceptTouchUps: true,
      locationNote: 'OddMaree Studio • Portland, OR',
    );
    BookingSyncService.resetSyncState();
    notifyPendingRequestsChanged();
  }

  /// Adds a newly submitted custom tattoo brief to the artist's pending requests queue.
  static void addPendingRequest(BookingRequest request) {
    pendingRequests = [request, ...pendingRequests];
    _stats = ArtistDashboardStats(
      bookingsThisWeek: _stats.bookingsThisWeek,
      newRequests: _stats.newRequests + 1,
      pendingCount: pendingRequests.length,
    );
    notifyPendingRequestsChanged();
    BookingSyncService.syncCustomRequestToCloud(request, status: 'pending');
    BookingSyncService.sendBookingNotification(
      recipientName: request.artistName,
      title: 'New Custom Request • ${request.clientName}',
      body: '${request.category} (${request.placement}) • Est. \$${request.estimatedPrice}',
      category: 'custom_request',
      appointmentId: request.id,
    );
  }

  /// Accepts a custom booking request, schedules it on the artist calendar,
  /// adds it to the client's upcoming appointments, and posts a chat receipt.
  static DashboardAppointment acceptBookingRequest(
    BookingRequest request, {
    DateTime? scheduledDate,
    String? timeSlot,
    int? customPrice,
    int? customDeposit,
  }) {
    // 1. Determine working date
    DateTime effectiveDate = scheduledDate ??
        request.preferredDate ??
        DateTime.now().add(const Duration(days: 3));
    if (scheduledDate == null && request.preferredDate == null) {
      int guard = 0;
      while (!booksSchedule.isWorkingDay(effectiveDate) && guard < 14) {
        effectiveDate = effectiveDate.add(const Duration(days: 1));
        guard++;
      }
    }
    effectiveDate = DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day);

    // 2. Determine available time slot on that date
    String effectiveTimeSlot = timeSlot ?? request.preferredTimeSlot ?? '';
    if (effectiveTimeSlot.isEmpty) {
      final candidateSlots = booksSchedule.generateTimeSlots();
      final available = candidateSlots.firstWhere(
        (s) => !isTimeSlotBooked(date: effectiveDate, timeSlot: s.time),
        orElse: () => const BookingTimeSlot(time: '1:30 PM', period: 'Afternoon'),
      );
      effectiveTimeSlot = available.time;
    }

    final effectivePrice = customPrice ?? request.estimatedPrice;
    final effectiveDeposit = customDeposit ?? request.deposit;
    final durationHrs = (booksSchedule.slotDurationMinutes / 60.0);
    final durationLabel = durationHrs == durationHrs.roundToDouble()
        ? '${durationHrs.toInt()} hrs'
        : '${durationHrs.toStringAsFixed(1)} hrs';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final formattedDate = '${months[effectiveDate.month - 1]} ${effectiveDate.day}, ${effectiveDate.year}';

    // 3. Remove from pending requests and update stats
    pendingRequests = pendingRequests.where((r) => r.id != request.id).toList();
    _stats = ArtistDashboardStats(
      bookingsThisWeek: _stats.bookingsThisWeek + 1,
      newRequests: _stats.newRequests > 0 ? _stats.newRequests - 1 : 0,
      pendingCount: pendingRequests.length,
    );
    notifyPendingRequestsChanged();

    // 4. Create & register Artist Calendar appointment
    final calendarApt = DashboardAppointment(
      id: 'cal_custom_${request.id}',
      clientName: request.clientName,
      serviceType: 'Custom: ${request.category}',
      duration: durationLabel,
      time: effectiveTimeSlot,
      scheduledDate: effectiveDate,
      date: formattedDate,
      placement: request.placement,
      notes: request.conceptDescription,
      depositPaid: effectiveDeposit,
      fullPrice: effectivePrice,
      artworkImageUrl: request.sketchImageUrl,
      visitType: 'Custom Tattoo',
      dotColor: const Color(0xFF22C55E),
    );
    addCalendarAppointment(calendarApt);
    BookingSyncService.syncCustomRequestToCloud(request, status: 'accepted');
    BookingSyncService.sendBookingNotification(
      recipientName: request.clientName,
      title: 'Custom Request Confirmed!',
      body: '${request.artistName} scheduled your ${request.category} session on $formattedDate at $effectiveTimeSlot.',
      category: 'booking_confirmed',
      appointmentId: calendarApt.id,
    );

    // 5. Create & register Client Upcoming appointment
    final clientApt = ClientAppointment(
      id: 'CUST-${request.id.hashCode.abs() % 90000 + 10000}',
      artistName: request.artistName,
      artistAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      studioName: 'Obsidian Atelier',
      studioAddress: booksSchedule.locationNote,
      flashTitle: 'Custom ${request.category} (${request.placement})',
      flashImageUrl: request.sketchImageUrl.isNotEmpty
          ? request.sketchImageUrl
          : 'assets/images/flash_traditional_panther.jpg',
      dateTime: effectiveDate,
      timeSlot: '$effectiveTimeSlot ($durationLabel)',
      placement: request.placement,
      depositAmount: effectiveDeposit,
      totalPrice: effectivePrice,
      status: AppointmentStatus.confirmed,
      isSilentAppointment: request.isSilentAppointment,
      notes: request.conceptDescription,
    );
    ClientAppointment.addUpcomingAppointment(clientApt);

    // 6. Post booking receipt message to client/artist message thread
    final receiptMessage = ChatMessage(
      id: 'receipt_${request.id}',
      senderId: 'system',
      senderName: request.artistName,
      text: 'Custom Request Approved • Deposit Confirmed (\$$effectiveDeposit)',
      timestamp: DateTime.now(),
      isFromArtist: true,
      type: ChatMessageType.receipt,
      receiptAmount: effectiveDeposit.toDouble(),
      appointmentDate: effectiveDate,
      flashImageUrl: request.sketchImageUrl.isNotEmpty
          ? request.sketchImageUrl
          : 'assets/images/flash_traditional_panther.jpg',
    );
    final followUpMessage = ChatMessage(
      id: 'msg_accept_${request.id}',
      senderId: 'artist_1',
      senderName: request.artistName,
      text: 'I accepted your custom tattoo brief for $formattedDate at $effectiveTimeSlot! Estimated total: \$$effectivePrice (\$$effectiveDeposit deposit).',
      timestamp: DateTime.now(),
      isFromArtist: true,
    );

    MessageThread.addThread(
      MessageThread(
        id: 'thread_custom_${request.id}',
        artistId: 'artist_1',
        artistName: request.artistName,
        artistAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
        studioName: 'Obsidian Atelier',
        lastMessage: followUpMessage.text,
        lastMessageTime: DateTime.now(),
        unreadCount: 1,
        isOnline: true,
        flashTitleContext: 'Custom: ${request.category}',
        messages: [receiptMessage, followUpMessage],
      ),
    );

    return calendarApt;
  }

  /// Declines a pending booking request and removes it from the active queue.
  static void declineBookingRequest(String requestId) {
    final matching = pendingRequests.where((r) => r.id == requestId).toList();
    final beforeLen = pendingRequests.length;
    pendingRequests = pendingRequests.where((r) => r.id != requestId).toList();
    if (pendingRequests.length < beforeLen) {
      _stats = ArtistDashboardStats(
        bookingsThisWeek: _stats.bookingsThisWeek,
        newRequests: _stats.newRequests > 0 ? _stats.newRequests - 1 : 0,
        pendingCount: pendingRequests.length,
      );
      notifyPendingRequestsChanged();
      if (matching.isNotEmpty) {
        BookingSyncService.syncCustomRequestToCloud(matching.first, status: 'declined');
      }
    }
  }

  /// Mock appointments for the interactive artist calendar, matching the visual mockup.
  static final List<DashboardAppointment> calendarAppointments = [
    // --- September 9, 2026 (Selected Day in Figma / Mockup) ---
    const DashboardAppointment(
      id: 'cal_apt_marcus_1',
      clientName: 'Marcus Cole',
      serviceType: 'Consultation',
      duration: '1 hr',
      time: '2:00 PM',
      scheduledDate: null, // Initialized below or via DateTime
      date: 'Sep 9, 2026',
      placement: 'Forearm',
      notes: 'Initial sizing and custom script lettering discussion.',
      depositPaid: 0,
      fullPrice: 50,
      artworkImageUrl: 'assets/images/flash_traditional_dagger.jpg',
      isConsultation: true,
      visitType: 'Consultation',
      dotColor: Color(0xFF919696),
    ),
    DashboardAppointment(
      id: 'cal_apt_marcus_2',
      clientName: 'Marcus Cole',
      serviceType: 'Consultation',
      duration: '1 hr',
      time: '2:00 PM',
      scheduledDate: DateTime(2026, 9, 9),
      date: 'Sep 9, 2026',
      placement: 'Forearm Consultation',
      notes: 'Design review and stencil placement check.',
      depositPaid: 0,
      fullPrice: 50,
      artworkImageUrl: 'assets/images/flash_traditional_dagger.jpg',
      isConsultation: true,
      visitType: 'Consultation',
      dotColor: const Color(0xFF919696),
    ),
    DashboardAppointment(
      id: 'cal_apt_elena_1',
      clientName: 'Elena Rostova',
      serviceType: 'Hannya mask cover-up',
      duration: '2.5 hrs',
      time: '3:30 PM',
      scheduledDate: DateTime(2026, 9, 9),
      date: 'Sep 9, 2026',
      placement: 'Upper Arm / Half Sleeve',
      notes: 'Japanese traditional Oni/Hannya mask dark cover-up session.',
      depositPaid: 120,
      fullPrice: 420,
      artworkImageUrl: 'assets/images/flash_japanese_oni.jpg',
      isConsultation: false,
      visitType: 'Cover-up',
      dotColor: const Color(0xFF22C55E),
    ),
    DashboardAppointment(
      id: 'cal_apt_jennie_1',
      clientName: 'Jennie Banks',
      serviceType: 'Consultation',
      duration: '1 hr',
      time: '6:30 PM',
      scheduledDate: DateTime(2026, 9, 9),
      date: 'Sep 9, 2026',
      placement: 'Collarbone',
      notes: 'Botanical branch placement and delicate needle selection.',
      depositPaid: 50,
      fullPrice: 150,
      artworkImageUrl: 'assets/images/flash_fineline_flora.jpg',
      isConsultation: true,
      visitType: 'Consultation',
      dotColor: const Color(0xFF22C55E),
    ),
    DashboardAppointment(
      id: 'cal_apt_jennie_2',
      clientName: 'Jennie Banks',
      serviceType: 'Consultation',
      duration: '1 hr',
      time: '6:30 PM',
      scheduledDate: null,
      date: 'Sep 9, 2026',
      placement: 'Collarbone Session',
      notes: 'Consultation follow-up and appointment finalization.',
      depositPaid: 50,
      fullPrice: 150,
      artworkImageUrl: 'assets/images/flash_fineline_flora.jpg',
      isConsultation: true,
      visitType: 'Flash Tattoo',
      dotColor: const Color(0xFF22C55E),
    ),

    // --- Additional Dotted Days in September 2026 ---
    DashboardAppointment(
      id: 'cal_apt_sarah_12',
      clientName: 'Sarah Jenkins',
      serviceType: 'Neo-traditional TIGER',
      duration: '3 hrs',
      time: '1:00 PM',
      scheduledDate: DateTime(2026, 9, 12),
      date: 'Sep 12, 2026',
      placement: 'Upper Thigh',
      notes: 'Full color tiger with gold fur and teal waves.',
      depositPaid: 100,
      fullPrice: 400,
      artworkImageUrl: 'assets/images/flash_tiger_tattoo.jpg',
      visitType: 'Custom Tattoo',
      dotColor: const Color(0xFF22C55E),
    ),
    DashboardAppointment(
      id: 'cal_apt_tom_13',
      clientName: 'Tom Hanks',
      serviceType: 'Traditional Anchor',
      duration: '2.5 hrs',
      time: '11:00 AM',
      scheduledDate: DateTime(2026, 9, 13),
      date: 'Sep 13, 2026',
      placement: 'Forearm',
      notes: 'Traditional anchor & swallow flash piece.',
      depositPaid: 60,
      fullPrice: 280,
      artworkImageUrl: 'assets/images/flash_anchor.jpg',
      visitType: 'Flash Tattoo',
      dotColor: const Color(0xFF22C55E),
    ),
    DashboardAppointment(
      id: 'cal_apt_sally_16',
      clientName: 'Sally McField',
      serviceType: 'Backpiece Discussion',
      duration: '1.5 hrs',
      time: '2:00 PM',
      scheduledDate: DateTime(2026, 9, 16),
      date: 'Sep 16, 2026',
      placement: 'Full Back',
      notes: 'Mapping out dragon flow across back and ribs.',
      depositPaid: 0,
      fullPrice: 75,
      artworkImageUrl: 'assets/images/flash_dragon_snake.jpg',
      isConsultation: true,
      visitType: 'Consultation',
      dotColor: const Color(0xFF919696),
    ),
    DashboardAppointment(
      id: 'cal_apt_alex_17',
      clientName: 'Alex Vance',
      serviceType: 'Blackwork Skull',
      duration: '4 hrs',
      time: '12:00 PM',
      scheduledDate: DateTime(2026, 9, 17),
      date: 'Sep 17, 2026',
      placement: 'Calf',
      notes: 'Heavy blackwork skull with stippling.',
      depositPaid: 150,
      fullPrice: 500,
      artworkImageUrl: 'assets/images/flash_blackwork_skull.jpg',
      visitType: 'Custom Tattoo',
      dotColor: const Color(0xFF22C55E),
    ),
    DashboardAppointment(
      id: 'cal_apt_maya_18',
      clientName: 'Maya Lin',
      serviceType: 'American Traditional Eagle',
      duration: '3.5 hrs',
      time: '3:00 PM',
      scheduledDate: DateTime(2026, 9, 18),
      date: 'Sep 18, 2026',
      placement: 'Chest',
      notes: 'Classic eagle clutching arrows banner.',
      depositPaid: 120,
      fullPrice: 450,
      artworkImageUrl: 'assets/images/flash_american_eagle.jpg',
      visitType: 'Flash Tattoo',
      dotColor: const Color(0xFF22C55E),
    ),
    DashboardAppointment(
      id: 'cal_apt_liam_19',
      clientName: 'Liam Gallagher',
      serviceType: 'Clipper Ship',
      duration: '4 hrs',
      time: '1:30 PM',
      scheduledDate: DateTime(2026, 9, 19),
      date: 'Sep 19, 2026',
      placement: 'Outer Arm',
      notes: 'Full sails clipper ship in stormy seas.',
      depositPaid: 140,
      fullPrice: 480,
      artworkImageUrl: 'assets/images/flash_clipper_ship.jpg',
      visitType: 'Custom Tattoo',
      dotColor: const Color(0xFF22C55E),
    ),
    DashboardAppointment(
      id: 'cal_apt_zoe_21',
      clientName: 'Zoe Kravitz',
      serviceType: 'Japanese Koi',
      duration: '3 hrs',
      time: '2:00 PM',
      scheduledDate: DateTime(2026, 9, 21),
      date: 'Sep 21, 2026',
      placement: 'Forearm',
      notes: 'Swimming koi upstream with lotus petals.',
      depositPaid: 100,
      fullPrice: 360,
      artworkImageUrl: 'assets/images/flash_japanese_koi.jpg',
      visitType: 'Custom Tattoo',
      dotColor: const Color(0xFF22C55E),
    ),
    DashboardAppointment(
      id: 'cal_apt_marcus_22',
      clientName: 'Marcus Cole',
      serviceType: 'Sleeve Inking Session 1',
      duration: '4 hrs',
      time: '11:30 AM',
      scheduledDate: DateTime(2026, 9, 22),
      date: 'Sep 22, 2026',
      placement: 'Full Forearm',
      notes: 'Primary lines and black shading.',
      depositPaid: 100,
      fullPrice: 450,
      artworkImageUrl: 'assets/images/flash_traditional_panther.jpg',
      visitType: 'Session Inking',
      dotColor: const Color(0xFF22C55E),
    ),
    DashboardAppointment(
      id: 'cal_apt_jennie_23',
      clientName: 'Jennie Banks',
      serviceType: 'Floral Inking & Shading',
      duration: '2.5 hrs',
      time: '4:00 PM',
      scheduledDate: DateTime(2026, 9, 23),
      date: 'Sep 23, 2026',
      placement: 'Collarbone',
      notes: 'Final fine line botanical needlework.',
      depositPaid: 80,
      fullPrice: 300,
      artworkImageUrl: 'assets/images/flash_fineline_flora.jpg',
      visitType: 'Fine Line',
      dotColor: const Color(0xFF22C55E),
    ),
  ];

  /// Returns appointments scheduled for a given date.
  static List<DashboardAppointment> getAppointmentsForDate(DateTime date) {
    return calendarAppointments.where((apt) {
      if (apt.scheduledDate != null) {
        return apt.scheduledDate!.year == date.year &&
            apt.scheduledDate!.month == date.month &&
            apt.scheduledDate!.day == date.day;
      }
      return false;
    }).toList();
  }

  /// Returns the set of day numbers with scheduled appointments for a year/month.
  static Set<int> getDaysWithAppointments(int year, int month) {
    return calendarAppointments
        .where((apt) =>
            apt.scheduledDate != null &&
            apt.scheduledDate!.year == year &&
            apt.scheduledDate!.month == month)
        .map((apt) => apt.scheduledDate!.day)
        .toSet();
  }

  /// Checks if a time slot is already booked for an artist on a given date.
  static bool isTimeSlotBooked({
    required DateTime date,
    required String timeSlot,
    String? artistId,
  }) {
    final cleanSlot = timeSlot.trim().toUpperCase();
    return calendarAppointments.any((apt) {
      if (apt.scheduledDate == null) return false;
      final sameDay = apt.scheduledDate!.year == date.year &&
          apt.scheduledDate!.month == date.month &&
          apt.scheduledDate!.day == date.day;
      if (!sameDay) return false;

      // Extract base time e.g. "1:30 PM" from "1:30 PM (3.0 hrs)" if applicable
      final aptTime = apt.time.split('(').first.trim().toUpperCase();
      final targetTime = cleanSlot.split('(').first.trim().toUpperCase();
      return aptTime == targetTime;
    });
  }

  /// Adds a confirmed booking appointment to the artist's calendar schedule.
  static void addCalendarAppointment(DashboardAppointment appointment) {
    calendarAppointments.add(appointment);
    BookingSyncService.syncAppointmentToCloud(appointment, status: 'confirmed');
    final alreadyNotified = BookingSyncService.sentNotifications.any(
      (n) => n.appointmentId == appointment.id && n.category == 'booking_confirmed',
    );
    if (!alreadyNotified) {
      BookingSyncService.sendBookingNotification(
        recipientName: appointment.clientName,
        title: 'Booking Confirmed!',
        body: '${appointment.serviceType} scheduled for ${appointment.date} at ${appointment.time}.',
        category: 'booking_confirmed',
        appointmentId: appointment.id,
      );
    }
  }

  /// Reschedules an existing appointment to [newDate] and [newTimeSlot],
  /// updating the artist's calendar, today's schedule, client upcoming appointments,
  /// chat messages, and Cloud Firestore sync.
  static DashboardAppointment? rescheduleAppointment(
    String appointmentId, {
    required DateTime newDate,
    required String newTimeSlot,
  }) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final normalizedDate = DateTime(newDate.year, newDate.month, newDate.day);
    final formattedDate = '${months[normalizedDate.month - 1]} ${normalizedDate.day}, ${normalizedDate.year}';

    DashboardAppointment? updatedApt;

    // 1. Update in calendarAppointments if present
    final calIdx = calendarAppointments.indexWhere((a) => a.id == appointmentId);
    if (calIdx != -1) {
      updatedApt = calendarAppointments[calIdx].copyWith(
        scheduledDate: normalizedDate,
        date: formattedDate,
        time: newTimeSlot,
      );
      calendarAppointments[calIdx] = updatedApt;
    }

    // 2. Update in todaySchedule if present
    final todayIdx = todaySchedule.indexWhere((a) => a.id == appointmentId);
    if (todayIdx != -1) {
      final baseApt = updatedApt ?? todaySchedule[todayIdx];
      updatedApt = baseApt.copyWith(
        scheduledDate: normalizedDate,
        date: formattedDate,
        time: newTimeSlot,
      );
      final mutableToday = List<DashboardAppointment>.from(todaySchedule);
      mutableToday[todayIdx] = updatedApt;
      todaySchedule = mutableToday;
      // Ensure it is also tracked in calendarAppointments for the target date
      if (calIdx == -1) {
        calendarAppointments.add(updatedApt);
      }
    }

    // 3. Fallback if appointment was passed directly (e.g. nextAppointment or custom instance)
    if (updatedApt == null && nextAppointment.id == appointmentId) {
      updatedApt = nextAppointment.copyWith(
        scheduledDate: normalizedDate,
        date: formattedDate,
        time: newTimeSlot,
      );
      calendarAppointments.add(updatedApt);
    }

    if (updatedApt == null) return null;

    // 4. Sync with ClientAppointment.activeUpcoming if matching service/placement/date
    final activeClientApts = ClientAppointment.activeUpcoming;
    for (int i = 0; i < activeClientApts.length; i++) {
      final clientApt = activeClientApts[i];
      if (clientApt.placement == updatedApt.placement ||
          clientApt.flashTitle.contains(updatedApt.serviceType)) {
        activeClientApts[i] = ClientAppointment(
          id: clientApt.id,
          artistName: clientApt.artistName,
          artistAvatar: clientApt.artistAvatar,
          studioName: clientApt.studioName,
          studioAddress: clientApt.studioAddress,
          flashTitle: clientApt.flashTitle,
          flashImageUrl: clientApt.flashImageUrl,
          dateTime: normalizedDate,
          timeSlot: '$newTimeSlot (${updatedApt.duration})',
          placement: clientApt.placement,
          depositAmount: clientApt.depositAmount,
          totalPrice: clientApt.totalPrice,
          status: AppointmentStatus.confirmed,
          isSilentAppointment: clientApt.isSilentAppointment,
          notes: clientApt.notes,
        );
        break;
      }
    }

    // 5. Post reschedule notice to active message threads
    final msg = ChatMessage(
      id: 'msg_resched_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'artist_1',
      senderName: 'OddMaree',
      text: 'Your appointment for ${updatedApt.serviceType} has been rescheduled to $formattedDate at $newTimeSlot. Your \$${updatedApt.depositPaid} deposit automatically transfers to the new slot.',
      timestamp: DateTime.now(),
      isFromArtist: true,
    );
    MessageThread.addThread(
      MessageThread(
        id: 'thread_resched_$appointmentId',
        artistId: 'artist_1',
        artistName: 'OddMaree',
        artistAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
        studioName: 'Obsidian Atelier',
        lastMessage: msg.text,
        lastMessageTime: DateTime.now(),
        unreadCount: 1,
        isOnline: true,
        flashTitleContext: updatedApt.serviceType,
        messages: [msg],
      ),
    );

    // 6. Sync to Cloud Firestore & send notification
    BookingSyncService.syncAppointmentToCloud(updatedApt, status: 'rescheduled');
    BookingSyncService.sendBookingNotification(
      recipientName: updatedApt.clientName,
      title: 'Appointment Rescheduled',
      body: '${updatedApt.serviceType} moved to $formattedDate at $newTimeSlot.',
      category: 'rescheduled',
      appointmentId: updatedApt.id,
    );

    return updatedApt;
  }

  /// Cancels an appointment by [appointmentId], freeing the calendar slot,
  /// updating client appointments, posting a cancellation notice, and syncing to Cloud Firestore.
  static bool cancelAppointment(
    String appointmentId, {
    String? reason,
  }) {
    DashboardAppointment? removedApt;

    final calIdx = calendarAppointments.indexWhere((a) => a.id == appointmentId);
    if (calIdx != -1) {
      removedApt = calendarAppointments.removeAt(calIdx);
    }

    final todayIdx = todaySchedule.indexWhere((a) => a.id == appointmentId);
    if (todayIdx != -1) {
      final mutableToday = List<DashboardAppointment>.from(todaySchedule);
      removedApt ??= mutableToday[todayIdx];
      mutableToday.removeAt(todayIdx);
      todaySchedule = mutableToday;
    }

    if (removedApt == null && nextAppointment.id == appointmentId) {
      removedApt = nextAppointment;
    }

    if (removedApt == null) return false;

    // Update matching ClientAppointment status to cancelled
    final activeClientApts = ClientAppointment.activeUpcoming;
    for (int i = 0; i < activeClientApts.length; i++) {
      final clientApt = activeClientApts[i];
      if (clientApt.placement == removedApt.placement ||
          clientApt.flashTitle.contains(removedApt.serviceType)) {
        activeClientApts[i] = ClientAppointment(
          id: clientApt.id,
          artistName: clientApt.artistName,
          artistAvatar: clientApt.artistAvatar,
          studioName: clientApt.studioName,
          studioAddress: clientApt.studioAddress,
          flashTitle: clientApt.flashTitle,
          flashImageUrl: clientApt.flashImageUrl,
          dateTime: clientApt.dateTime,
          timeSlot: clientApt.timeSlot,
          placement: clientApt.placement,
          depositAmount: clientApt.depositAmount,
          totalPrice: clientApt.totalPrice,
          status: AppointmentStatus.cancelled,
          isSilentAppointment: clientApt.isSilentAppointment,
          notes: clientApt.notes,
        );
        break;
      }
    }

    final reasonNote = (reason != null && reason.trim().isNotEmpty)
        ? ' Reason: ${reason.trim()}.'
        : '';
    final msg = ChatMessage(
      id: 'msg_cancel_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'artist_1',
      senderName: 'OddMaree',
      text: 'Appointment for ${removedApt.serviceType} (${removedApt.date} at ${removedApt.time}) has been cancelled.$reasonNote',
      timestamp: DateTime.now(),
      isFromArtist: true,
    );
    MessageThread.addThread(
      MessageThread(
        id: 'thread_cancel_$appointmentId',
        artistId: 'artist_1',
        artistName: 'OddMaree',
        artistAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
        studioName: 'Obsidian Atelier',
        lastMessage: msg.text,
        lastMessageTime: DateTime.now(),
        unreadCount: 1,
        isOnline: true,
        flashTitleContext: removedApt.serviceType,
        messages: [msg],
      ),
    );

    BookingSyncService.syncAppointmentToCloud(removedApt, status: 'cancelled');
    BookingSyncService.sendBookingNotification(
      recipientName: removedApt.clientName,
      title: 'Appointment Cancelled',
      body: 'Your ${removedApt.serviceType} session on ${removedApt.date} at ${removedApt.time} was cancelled.',
      category: 'cancelled',
      appointmentId: removedApt.id,
    );

    return true;
  }
}

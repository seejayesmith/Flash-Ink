import 'package:flutter/material.dart';
import '../core/mock/mock_data_config.dart';
import 'booking.dart';
import 'waitlist_entry.dart';
import '../features/appointments/domain/models/appointment_item.dart';
import '../features/messages/domain/models/message_thread.dart';
import '../services/booking_sync_service.dart';

/// Represents a scheduled appointment for an artist.
class DashboardAppointment {
  final String id;
  final String? clientId;
  final String? artistId;
  final String clientName;
  final String? clientAvatar;
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
    this.clientId,
    this.artistId,
    required this.clientName,
    this.clientAvatar,
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
    String? clientId,
    String? artistId,
    String? clientName,
    String? clientAvatar,
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
      clientId: clientId ?? this.clientId,
      artistId: artistId ?? this.artistId,
      clientName: clientName ?? this.clientName,
      clientAvatar: clientAvatar ?? this.clientAvatar,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'artistId': artistId,
      'clientName': clientName,
      if (clientAvatar != null && clientAvatar!.isNotEmpty) 'clientAvatar': clientAvatar,
      'serviceType': serviceType,
      'duration': duration,
      'time': time,
      'date': date,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'placement': placement,
      'notes': notes,
      'depositPaid': depositPaid,
      'fullPrice': fullPrice,
      'artworkImageUrl': artworkImageUrl,
      'isConsultation': isConsultation,
      'visitType': effectiveVisitType,
    };
  }

  factory DashboardAppointment.fromMap(Map<String, dynamic> map, [String? docId]) {
    final isConsult = map['isConsultation'] == true;
    final parsedDate = map['scheduledDate'] is String
        ? DateTime.tryParse(map['scheduledDate'] as String)
        : null;
    return DashboardAppointment(
      id: (docId != null && docId.isNotEmpty)
          ? docId
          : (map['id']?.toString() ?? 'apt_${DateTime.now().millisecondsSinceEpoch}'),
      clientId: map['clientId']?.toString(),
      artistId: map['artistId']?.toString(),
      clientName: map['clientName']?.toString() ?? 'Client',
      clientAvatar: (map['clientAvatar'] ??
              map['clientPhotoUrl'] ??
              map['clientPhotoURL'])
          ?.toString(),
      serviceType: map['serviceType']?.toString() ?? 'Tattoo Session',
      duration: map['duration']?.toString() ?? '2 hrs',
      time: map['time']?.toString() ?? '1:00 PM',
      date: map['date']?.toString() ?? 'Today',
      scheduledDate: parsedDate,
      placement: map['placement']?.toString() ?? 'Forearm',
      notes: map['notes']?.toString() ?? '',
      depositPaid: (map['depositPaid'] as num?)?.toInt() ?? 50,
      fullPrice: (map['fullPrice'] as num?)?.toInt() ?? 250,
      artworkImageUrl: (map['artworkImageUrl'] ??
              map['flashImageUrl'] ??
              map['imageUrl'] ??
              map['sketchImageUrl'] ??
              '')
          .toString()
          .trim(),
      isConsultation: isConsult,
      visitType: map['visitType']?.toString(),
      dotColor: isConsult ? const Color(0xFF919696) : const Color(0xFF22C55E),
    );
  }
}

/// Represents an incoming booking / custom request waiting for artist review.
class BookingRequest {
  final String id;
  final String? clientId;
  final String? artistId;
  final String clientName;
  final String? clientAvatar;
  final String timeAgo;
  final String conceptDescription;
  final String placement;
  final String category;
  final String sketchImageUrl;
  final List<String> referenceImageUrls;
  final int estimatedPrice;
  final int deposit;
  final String size;
  final bool isSilentAppointment;
  final String artistName;
  final DateTime? preferredDate;
  final String? preferredTimeSlot;

  const BookingRequest({
    required this.id,
    this.clientId,
    this.artistId,
    required this.clientName,
    this.clientAvatar,
    required this.timeAgo,
    required this.conceptDescription,
    this.placement = 'Outer Thigh',
    this.category = 'Neo-traditional',
    required this.sketchImageUrl,
    this.referenceImageUrls = const [],
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
    String? clientId,
    String? artistId,
    String? clientName,
    String? clientAvatar,
    String? timeAgo,
    String? conceptDescription,
    String? placement,
    String? category,
    String? sketchImageUrl,
    List<String>? referenceImageUrls,
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
      clientId: clientId ?? this.clientId,
      artistId: artistId ?? this.artistId,
      clientName: clientName ?? this.clientName,
      clientAvatar: clientAvatar ?? this.clientAvatar,
      timeAgo: timeAgo ?? this.timeAgo,
      conceptDescription: conceptDescription ?? this.conceptDescription,
      placement: placement ?? this.placement,
      category: category ?? this.category,
      sketchImageUrl: sketchImageUrl ?? this.sketchImageUrl,
      referenceImageUrls: referenceImageUrls ?? this.referenceImageUrls,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      deposit: deposit ?? this.deposit,
      size: size ?? this.size,
      isSilentAppointment: isSilentAppointment ?? this.isSilentAppointment,
      artistName: artistName ?? this.artistName,
      preferredDate: preferredDate ?? this.preferredDate,
      preferredTimeSlot: preferredTimeSlot ?? this.preferredTimeSlot,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'artistId': artistId,
      'clientName': clientName,
      if (clientAvatar != null && clientAvatar!.isNotEmpty) 'clientAvatar': clientAvatar,
      'timeAgo': timeAgo,
      'conceptDescription': conceptDescription,
      'placement': placement,
      'category': category,
      'sketchImageUrl': sketchImageUrl,
      'referenceImageUrls': referenceImageUrls,
      'estimatedPrice': estimatedPrice,
      'deposit': deposit,
      'size': size,
      'isSilentAppointment': isSilentAppointment,
      'artistName': artistName,
      'preferredDate': preferredDate?.toIso8601String(),
      'preferredTimeSlot': preferredTimeSlot,
    };
  }

  factory BookingRequest.fromMap(Map<String, dynamic> map, [String? docId]) {
    final parsedDate = map['preferredDate'] is String
        ? DateTime.tryParse(map['preferredDate'] as String)
        : null;
    final rawRefs = map['referenceImageUrls'];
    final parsedRefs = rawRefs is List
        ? rawRefs.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    return BookingRequest(
      id: (docId != null && docId.isNotEmpty)
          ? docId
          : (map['id']?.toString() ?? 'req_${DateTime.now().millisecondsSinceEpoch}'),
      clientId: map['clientId']?.toString(),
      artistId: map['artistId']?.toString(),
      clientName: map['clientName']?.toString() ?? 'Client',
      clientAvatar: (map['clientAvatar'] ??
              map['clientPhotoUrl'] ??
              map['clientPhotoURL'])
          ?.toString(),
      timeAgo: map['timeAgo']?.toString() ?? 'Recently',
      conceptDescription: map['conceptDescription']?.toString() ?? '',
      placement: map['placement']?.toString() ?? 'Forearm',
      category: map['category']?.toString() ?? 'Custom Design',
      sketchImageUrl: map['sketchImageUrl']?.toString() ?? '',
      referenceImageUrls: parsedRefs,
      estimatedPrice: (map['estimatedPrice'] as num?)?.toInt() ?? 300,
      deposit: (map['deposit'] as num?)?.toInt() ?? 80,
      size: map['size']?.toString() ?? 'Medium (4"-7")',
      isSilentAppointment: map['isSilentAppointment'] == true,
      artistName: map['artistName']?.toString() ?? 'Artist',
      preferredDate: parsedDate,
      preferredTimeSlot: map['preferredTimeSlot']?.toString(),
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

enum BookingMode {
  alwaysOpen,
  drops,
}

enum BookDropStatus {
  scheduled,
  earlyAccess,
  open,
  full,
  closed,
}

/// Represents an intentional booking release or drop window.
class BookDrop {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final BookDropStatus status;
  final Set<int> selectedDays; // Month day numbers or timestamps
  final bool acceptFlash;
  final bool acceptCustom;
  final bool acceptTouchUps;
  final int? requestCap;
  final int requestCount;
  final DateTime? opensAt;
  final int earlyAccessHours;
  final DateTime? earlyAccessEndsAt;

  const BookDrop({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.status = BookDropStatus.open,
    this.selectedDays = const {},
    this.acceptFlash = true,
    this.acceptCustom = true,
    this.acceptTouchUps = true,
    this.requestCap,
    this.requestCount = 0,
    this.opensAt,
    this.earlyAccessHours = 24,
    this.earlyAccessEndsAt,
  });

  BookDrop copyWith({
    String? id,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    BookDropStatus? status,
    Set<int>? selectedDays,
    bool? acceptFlash,
    bool? acceptCustom,
    bool? acceptTouchUps,
    int? requestCap,
    int? requestCount,
    DateTime? opensAt,
    int? earlyAccessHours,
    DateTime? earlyAccessEndsAt,
  }) {
    return BookDrop(
      id: id ?? this.id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      selectedDays: selectedDays ?? this.selectedDays,
      acceptFlash: acceptFlash ?? this.acceptFlash,
      acceptCustom: acceptCustom ?? this.acceptCustom,
      acceptTouchUps: acceptTouchUps ?? this.acceptTouchUps,
      requestCap: requestCap ?? this.requestCap,
      requestCount: requestCount ?? this.requestCount,
      opensAt: opensAt ?? this.opensAt,
      earlyAccessHours: earlyAccessHours ?? this.earlyAccessHours,
      earlyAccessEndsAt: earlyAccessEndsAt ?? this.earlyAccessEndsAt,
    );
  }
}

/// Represents a 24-hour temporary hold created when an artist proposes slots for a custom request.
class CustomHold {
  final String id;
  final String requestId;
  final String clientName;
  final DateTime date;
  final String timeSlot;
  final int durationMinutes;
  final int estimatedPrice;
  final int deposit;
  final DateTime createdAt;
  final DateTime expiresAt;

  const CustomHold({
    required this.id,
    required this.requestId,
    required this.clientName,
    required this.date,
    required this.timeSlot,
    this.durationMinutes = 180,
    required this.estimatedPrice,
    required this.deposit,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get remainingTime => isExpired ? Duration.zero : expiresAt.difference(DateTime.now());

  CustomHold copyWith({
    String? id,
    String? requestId,
    String? clientName,
    DateTime? date,
    String? timeSlot,
    int? durationMinutes,
    int? estimatedPrice,
    int? deposit,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return CustomHold(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      clientName: clientName ?? this.clientName,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      deposit: deposit ?? this.deposit,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

enum PresetCategory { pass, askInfo, followUp }

/// Reusable preset message template for custom request interactions.
class AutoResponsePreset {
  final String id;
  final String title;
  final PresetCategory category;
  final String messageTemplate;
  final String? connectedActionTitle;

  const AutoResponsePreset({
    required this.id,
    required this.title,
    required this.category,
    required this.messageTemplate,
    this.connectedActionTitle,
  });

  static const List<AutoResponsePreset> defaultPassPresets = [
    AutoResponsePreset(
      id: 'pass_style',
      title: 'Outside my style',
      category: PresetCategory.pass,
      messageTemplate:
          "Thanks so much for thinking of me! This idea isn't really my style, and you deserve someone who specializes in it.",
      connectedActionTitle: 'Recommend other Flash artists',
    ),
    AutoResponsePreset(
      id: 'pass_capacity',
      title: 'Too big for current books',
      category: PresetCategory.pass,
      messageTemplate:
          "I love this idea, but I can't fit a piece this size into my current booking window.",
      connectedActionTitle: 'Join waitlist for next drop',
    ),
    AutoResponsePreset(
      id: 'pass_booked',
      title: 'Books filled up',
      category: PresetCategory.pass,
      messageTemplate:
          "My books filled up before I could take this on. I'd love to get you in next time!",
      connectedActionTitle: 'Join waitlist + available flash',
    ),
    AutoResponsePreset(
      id: 'pass_placement',
      title: 'Placement not done',
      category: PresetCategory.pass,
      messageTemplate:
          "I don't tattoo this placement, but I'd be happy to discuss a different placement.",
      connectedActionTitle: 'Resubmit with different placement',
    ),
    AutoResponsePreset(
      id: 'pass_flash_only',
      title: 'Flash-only right now',
      category: PresetCategory.pass,
      messageTemplate:
          "I'm only accepting flash at the moment. Take a look at my available pieces!",
      connectedActionTitle: 'Browse available flash',
    ),
  ];

  static const List<AutoResponsePreset> defaultAskInfoPresets = [
    AutoResponsePreset(
      id: 'ask_size',
      title: 'Size in inches',
      category: PresetCategory.askInfo,
      messageTemplate: '• Approximate size in inches',
    ),
    AutoResponsePreset(
      id: 'ask_placement',
      title: 'Exact placement',
      category: PresetCategory.askInfo,
      messageTemplate: '• Exact placement on your body',
    ),
    AutoResponsePreset(
      id: 'ask_references',
      title: 'Reference photos',
      category: PresetCategory.askInfo,
      messageTemplate: '• 1–2 reference photos of the style/elements you have in mind',
    ),
    AutoResponsePreset(
      id: 'ask_color',
      title: 'Color vs B&G',
      category: PresetCategory.askInfo,
      messageTemplate: '• Whether you are picturing this in color or black & grey',
    ),
    AutoResponsePreset(
      id: 'ask_budget',
      title: 'Budget range',
      category: PresetCategory.askInfo,
      messageTemplate: '• Your target budget range for this piece',
    ),
    AutoResponsePreset(
      id: 'ask_coverup',
      title: 'Existing tattoos / cover-up',
      category: PresetCategory.askInfo,
      messageTemplate: '• Whether this will go over or next to any existing tattoos or scars',
    ),
  ];
}

enum DayCapacityStatus {
  open,
  filling,
  full,
  blocked,
  closed,
}

/// Represents the configuration for an artist's booking schedule ("Books").
/// Compact anonymized slot entry stored on `artist_schedules` so clients
/// can enforce booked/held capacity without reading private `/appointments`.
class ScheduleSlotEntry {
  final String dateKey;
  final String timeSlot;
  final DateTime? expiresAt;

  const ScheduleSlotEntry({
    required this.dateKey,
    required this.timeSlot,
    this.expiresAt,
  });

  bool isActiveAt(DateTime now) =>
      expiresAt == null || now.isBefore(expiresAt!);

  Map<String, dynamic> toMap() => {
        'date': dateKey,
        'time': timeSlot,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };

  factory ScheduleSlotEntry.fromMap(Map<String, dynamic> map) {
    return ScheduleSlotEntry(
      dateKey: (map['date'] ?? '').toString(),
      timeSlot: (map['time'] ?? '').toString(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'].toString())
          : null,
    );
  }
}

class ArtistBooksSchedule {
  final bool isBooksOpen;
  final bool isEarlyAccessOnly;
  final DateTime? earlyAccessEndsAt;
  final int earlyAccessHours;
  final DateTime bookingWindowStart;
  final DateTime bookingWindowEnd;
  final Set<int> workingDays; // 1 = Mon, 7 = Sun (DateTime weekday constants)
  final Set<String> blockedDates; // YYYY-MM-DD explicit day-off overrides
  final Set<String> openOverrideDates; // YYYY-MM-DD forced-open overrides
  final int minLeadTimeHours; // 0, 24, 48, 72, 168 (applies to empty days only)
  final int? maxWorkingDaysPerWeek; // Sun-Sat distinct occupied day cap
  final List<ScheduleSlotEntry> bookedSlots; // Server-maintained occupancy
  final List<ScheduleSlotEntry> heldSlots; // Unexpired 24h artist holds
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
    this.blockedDates = const {},
    this.openOverrideDates = const {},
    this.minLeadTimeHours = 0,
    this.maxWorkingDaysPerWeek,
    this.bookedSlots = const [],
    this.heldSlots = const [],
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

  /// Formats [dt] into a canonical `YYYY-MM-DD` local calendar date key.
  static String dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Normalizes display slot labels such as `"1:30 PM (3.0 hrs)"` to `"1:30 PM"`.
  static String normalizeTimeLabel(String timeSlot) =>
      timeSlot.split('(').first.trim().toUpperCase();

  /// Returns local midnight of the Sunday starting the Sun–Sat week containing [date].
  static DateTime weekStartSunday(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return DateTime(
      normalized.year,
      normalized.month,
      normalized.day - (normalized.weekday % 7),
    );
  }

  /// Parses [timeSlot] on [date] into a local [DateTime], or `null` if invalid.
  static DateTime? parseSlotDateTime(DateTime date, String timeSlot) {
    final cleaned = normalizeTimeLabel(timeSlot);
    final match12 = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(cleaned);
    if (match12 != null) {
      var hour = int.tryParse(match12.group(1)!) ?? 0;
      final minute = int.tryParse(match12.group(2)!) ?? 0;
      final meridiem = match12.group(3)!;
      if (meridiem == 'PM' && hour != 12) hour += 12;
      if (meridiem == 'AM' && hour == 12) hour = 0;
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(cleaned);
    if (match24 != null) {
      final hour = int.tryParse(match24.group(1)!) ?? 0;
      final minute = int.tryParse(match24.group(2)!) ?? 0;
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
    return null;
  }

  bool isDateBlocked(DateTime date) => blockedDates.contains(dateKey(date));

  bool isDateForceOpened(DateTime date) =>
      openOverrideDates.contains(dateKey(date));

  /// Returns true if [date] falls inside `[bookingWindowStart, bookingWindowEnd]` (inclusive).
  bool isWithinBookingWindow(DateTime date) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(
      bookingWindowStart.year,
      bookingWindowStart.month,
      bookingWindowStart.day,
    );
    final endOnly = DateTime(
      bookingWindowEnd.year,
      bookingWindowEnd.month,
      bookingWindowEnd.day,
    );
    if (endOnly.isBefore(startOnly)) return true;
    return !dayOnly.isBefore(startOnly) && !dayOnly.isAfter(endOnly);
  }

  /// Returns true if books are open and [date] is either force-opened or an
  /// unblocked configured working weekday.
  bool isWorkingDay(DateTime date) {
    if (!isBooksOpen) return false;
    final key = dateKey(date);
    if (blockedDates.contains(key)) return false;
    if (openOverrideDates.contains(key)) return true;
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
    bool clearEarlyAccessEndsAt = false,
    int? earlyAccessHours,
    DateTime? bookingWindowStart,
    DateTime? bookingWindowEnd,
    Set<int>? workingDays,
    Set<String>? blockedDates,
    Set<String>? openOverrideDates,
    int? minLeadTimeHours,
    int? maxWorkingDaysPerWeek,
    bool clearMaxWorkingDaysPerWeek = false,
    List<ScheduleSlotEntry>? bookedSlots,
    List<ScheduleSlotEntry>? heldSlots,
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
      earlyAccessEndsAt: clearEarlyAccessEndsAt
          ? null
          : (earlyAccessEndsAt ?? this.earlyAccessEndsAt),
      earlyAccessHours: earlyAccessHours ?? this.earlyAccessHours,
      bookingWindowStart: bookingWindowStart ?? this.bookingWindowStart,
      bookingWindowEnd: bookingWindowEnd ?? this.bookingWindowEnd,
      workingDays: workingDays ?? this.workingDays,
      blockedDates: blockedDates ?? this.blockedDates,
      openOverrideDates: openOverrideDates ?? this.openOverrideDates,
      minLeadTimeHours: minLeadTimeHours ?? this.minLeadTimeHours,
      maxWorkingDaysPerWeek: clearMaxWorkingDaysPerWeek
          ? null
          : (maxWorkingDaysPerWeek ?? this.maxWorkingDaysPerWeek),
      bookedSlots: bookedSlots ?? this.bookedSlots,
      heldSlots: heldSlots ?? this.heldSlots,
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
      'workingDays': workingDays.toList()..sort(),
      'blockedDates': blockedDates.toList()..sort(),
      'openOverrideDates': openOverrideDates.toList()..sort(),
      'minLeadTimeHours': minLeadTimeHours,
      'maxWorkingDaysPerWeek': maxWorkingDaysPerWeek,
      'heldSlots': heldSlots.map((e) => e.toMap()).toList(),
      // Omit bookedSlots so client writes preserve server-maintained Cloud Function data.
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
      blockedDates: (map['blockedDates'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toSet() ??
          const {},
      openOverrideDates: (map['openOverrideDates'] as List?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toSet() ??
          const {},
      minLeadTimeHours: (map['minLeadTimeHours'] as num?)?.toInt() ?? 0,
      maxWorkingDaysPerWeek: (map['maxWorkingDaysPerWeek'] as num?)?.toInt(),
      bookedSlots: (map['bookedSlots'] as List?)
              ?.whereType<Map>()
              .map((e) => ScheduleSlotEntry.fromMap(Map<String, dynamic>.from(e)))
              .where((e) => e.dateKey.isNotEmpty && e.timeSlot.isNotEmpty)
              .toList() ??
          const [],
      heldSlots: (map['heldSlots'] as List?)
              ?.whereType<Map>()
              .map((e) => ScheduleSlotEntry.fromMap(Map<String, dynamic>.from(e)))
              .where((e) => e.dateKey.isNotEmpty && e.timeSlot.isNotEmpty)
              .toList() ??
          const [],
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
      locationNote: map['locationNote'] as String? ??
          (MockDataConfig.isEnabled ? 'OddMaree Studio • Portland, OR' : ''),
    );
  }
}

/// Repository for the artist dashboard, calendar, books, waitlist, and earnings.
///
/// Quarantines all Figma/demo mock datasets strictly behind [MockDataConfig.isEnabled].
/// In live runtime mode (`MockDataConfig.isEnabled == false`), exposes live Firestore-synced
/// and session-scoped collections (defaulting to empty lists and zeroed metrics).
class ArtistDashboardRepository {
  static ArtistBooksSchedule _mockBooksSchedule = ArtistBooksSchedule(
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

  static ArtistBooksSchedule _liveBooksSchedule = ArtistBooksSchedule(
    isBooksOpen: true,
    isEarlyAccessOnly: false,
    bookingWindowStart: DateTime(DateTime.now().year, DateTime.now().month, 1),
    bookingWindowEnd: DateTime(DateTime.now().year, DateTime.now().month + 3, 0),
    workingDays: const {2, 3, 4, 5, 6},
    startTime: const TimeOfDay(hour: 11, minute: 0),
    endTime: const TimeOfDay(hour: 19, minute: 0),
    slotDurationMinutes: 120,
    bufferDurationMinutes: 30,
    defaultDepositAmount: 80,
    acceptFlash: true,
    acceptCustom: true,
    acceptTouchUps: true,
    locationNote: '',
  );

  static ArtistBooksSchedule get booksSchedule =>
      MockDataConfig.isEnabled ? _mockBooksSchedule : _liveBooksSchedule;

  static set booksSchedule(ArtistBooksSchedule value) {
    if (MockDataConfig.isEnabled) {
      _mockBooksSchedule = value;
    } else {
      _liveBooksSchedule = value;
    }
    notifyPendingRequestsChanged();
  }

  static void updateBooksSchedule(
    ArtistBooksSchedule updated, {
    required String artistId,
  }) {
    booksSchedule = updated;
    BookingSyncService.syncBooksScheduleToCloud(
      updated,
      artistId: artistId,
    );
  }

  /// Quarantined mock VIP waitlist entries vs live waitlist entries.
  static List<WaitlistEntry> _mockWaitlistEntries =
      List.from(WaitlistEntry.mockWaitlistEntries);
  static List<WaitlistEntry> liveWaitlistEntries = [];

  static BookingMode _mockBookingMode = BookingMode.alwaysOpen;
  static BookingMode _liveBookingMode = BookingMode.alwaysOpen;
  static BookingMode get bookingMode =>
      MockDataConfig.isEnabled ? _mockBookingMode : _liveBookingMode;
  static set bookingMode(BookingMode mode) {
    if (MockDataConfig.isEnabled) {
      _mockBookingMode = mode;
    } else {
      _liveBookingMode = mode;
    }
    notifyPendingRequestsChanged();
  }

  static bool _mockIsPaused = false;
  static bool _liveIsPaused = false;
  static bool get isPaused =>
      MockDataConfig.isEnabled ? _mockIsPaused : _liveIsPaused;
  static set isPaused(bool paused) {
    if (MockDataConfig.isEnabled) {
      _mockIsPaused = paused;
    } else {
      _liveIsPaused = paused;
    }
    notifyPendingRequestsChanged();
  }
  static void pauseInquiries() => isPaused = true;
  static void resumeInquiries() => isPaused = false;

  static BookDrop? _mockBookDrop = BookDrop(
    id: 'drop_dec_2026',
    title: 'December Booking Drop',
    startDate: DateTime(2026, 12, 1),
    endDate: DateTime(2026, 12, 31),
    status: BookDropStatus.open,
    selectedDays: const {1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 15, 16, 17, 18, 19},
    acceptFlash: true,
    acceptCustom: true,
    acceptTouchUps: true,
    requestCap: 25,
    requestCount: 14,
    earlyAccessHours: 24,
  );
  static BookDrop? _liveBookDrop;
  static BookDrop? get currentBookDrop =>
      MockDataConfig.isEnabled ? _mockBookDrop : _liveBookDrop;
  static set currentBookDrop(BookDrop? drop) {
    if (MockDataConfig.isEnabled) {
      _mockBookDrop = drop;
    } else {
      _liveBookDrop = drop;
    }
    notifyPendingRequestsChanged();
  }

  static List<CustomHold> _mockCustomHolds = [
    CustomHold(
      id: 'hold_dragon_1',
      requestId: 'req_dragon_sarah',
      clientName: 'Sarah M.',
      date: DateTime(2026, 12, 4),
      timeSlot: '2:00 PM',
      durationMinutes: 180,
      estimatedPrice: 450,
      deposit: 80,
      createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      expiresAt: DateTime.now().add(const Duration(hours: 16)),
    ),
  ];
  static List<CustomHold> _liveCustomHolds = [];
  static List<CustomHold> get customHolds =>
      MockDataConfig.isEnabled ? _mockCustomHolds : _liveCustomHolds;
  static set customHolds(List<CustomHold> value) {
    if (MockDataConfig.isEnabled) {
      _mockCustomHolds = value;
    } else {
      _liveCustomHolds = value;
    }
    notifyPendingRequestsChanged();
  }

  static void addCustomHold(CustomHold hold, {String? artistId}) {
    customHolds = [...customHolds, hold];
    _syncHeldSlots(artistId: artistId);
  }

  static void releaseCustomHold(String id, {String? artistId}) {
    customHolds = customHolds.where((h) => h.id != id).toList();
    _syncHeldSlots(artistId: artistId);
  }

  static void _syncHeldSlots({String? artistId}) {
    final now = DateTime.now();
    final activeEntries = customHolds
        .where((h) => !now.isAfter(h.expiresAt))
        .map(
          (h) => ScheduleSlotEntry(
            dateKey: ArtistBooksSchedule.dateKey(h.date),
            timeSlot: h.timeSlot,
            expiresAt: h.expiresAt,
          ),
        )
        .toList();
    booksSchedule = booksSchedule.copyWith(heldSlots: activeEntries);
    final resolvedId = (artistId ?? BookingSyncService.resolveCurrentUid('')).trim();
    if (resolvedId.isNotEmpty) {
      BookingSyncService.syncHeldSlotsToCloud(activeEntries, artistId: resolvedId);
    }
  }

  static bool isDateBlocked(DateTime date, {ArtistBooksSchedule? schedule}) =>
      (schedule ?? booksSchedule).isDateBlocked(date);

  static bool isDateForceOpened(DateTime date, {ArtistBooksSchedule? schedule}) =>
      (schedule ?? booksSchedule).isDateForceOpened(date);

  static void _updateDateOverrides({
    required Set<String> blockedDates,
    required Set<String> openOverrideDates,
    String? artistId,
  }) {
    final updated = booksSchedule.copyWith(
      blockedDates: Set<String>.unmodifiable(blockedDates),
      openOverrideDates: Set<String>.unmodifiable(openOverrideDates),
    );
    booksSchedule = updated;
    final resolvedId = (artistId ?? BookingSyncService.resolveCurrentUid('')).trim();
    if (resolvedId.isNotEmpty) {
      BookingSyncService.syncBooksScheduleToCloud(updated, artistId: resolvedId);
    }
  }

  static void blockDate(DateTime date, {String? artistId}) =>
      blockDates([date], artistId: artistId);

  static void unblockDate(DateTime date, {String? artistId}) =>
      unblockDates([date], artistId: artistId);

  static void forceOpenDate(DateTime date, {String? artistId}) =>
      forceOpenDates([date], artistId: artistId);

  static void revertForceOpenDate(DateTime date, {String? artistId}) {
    final key = ArtistBooksSchedule.dateKey(date);
    final nextOpen = Set<String>.from(booksSchedule.openOverrideDates)..remove(key);
    _updateDateOverrides(
      blockedDates: Set<String>.from(booksSchedule.blockedDates),
      openOverrideDates: nextOpen,
      artistId: artistId,
    );
  }

  /// Marks [dates] as blocked days off and removes any conflicting force-open overrides.
  static void blockDates(Iterable<DateTime> dates, {String? artistId}) {
    final nextBlocked = Set<String>.from(booksSchedule.blockedDates);
    final nextOpen = Set<String>.from(booksSchedule.openOverrideDates);
    for (final d in dates) {
      final key = ArtistBooksSchedule.dateKey(d);
      nextBlocked.add(key);
      nextOpen.remove(key);
    }
    _updateDateOverrides(
      blockedDates: nextBlocked,
      openOverrideDates: nextOpen,
      artistId: artistId,
    );
  }

  /// Removes [dates] from the explicit blocked-dates override set.
  static void unblockDates(Iterable<DateTime> dates, {String? artistId}) {
    final nextBlocked = Set<String>.from(booksSchedule.blockedDates);
    for (final d in dates) {
      nextBlocked.remove(ArtistBooksSchedule.dateKey(d));
    }
    _updateDateOverrides(
      blockedDates: nextBlocked,
      openOverrideDates: Set<String>.from(booksSchedule.openOverrideDates),
      artistId: artistId,
    );
  }

  /// Force-opens [dates] (even on weekly off-days) and clears any conflicting block.
  static void forceOpenDates(Iterable<DateTime> dates, {String? artistId}) {
    final nextBlocked = Set<String>.from(booksSchedule.blockedDates);
    final nextOpen = Set<String>.from(booksSchedule.openOverrideDates);
    for (final d in dates) {
      final key = ArtistBooksSchedule.dateKey(d);
      nextOpen.add(key);
      nextBlocked.remove(key);
    }
    _updateDateOverrides(
      blockedDates: nextBlocked,
      openOverrideDates: nextOpen,
      artistId: artistId,
    );
  }

  /// Clears all explicit blocked dates while preserving force-opened overrides.
  static void clearAllBlockedDates({String? artistId}) {
    if (booksSchedule.blockedDates.isEmpty) return;
    _updateDateOverrides(
      blockedDates: const {},
      openOverrideDates: Set<String>.from(booksSchedule.openOverrideDates),
      artistId: artistId,
    );
  }

  /// Clears all force-opened off-weekday overrides while preserving blocked dates.
  static void clearAllOpenOverrides({String? artistId}) {
    if (booksSchedule.openOverrideDates.isEmpty) return;
    _updateDateOverrides(
      blockedDates: Set<String>.from(booksSchedule.blockedDates),
      openOverrideDates: const {},
      artistId: artistId,
    );
  }

  /// Clears both blocked-date and force-open overrides.
  static void clearAllDateOverrides({String? artistId}) {
    if (booksSchedule.blockedDates.isEmpty &&
        booksSchedule.openOverrideDates.isEmpty) {
      return;
    }
    _updateDateOverrides(
      blockedDates: const {},
      openOverrideDates: const {},
      artistId: artistId,
    );
  }

  /// Parses duration strings like "1 hr", "2.5 hrs", "3hrs", "90 mins" into minutes.
  static int parseDurationMinutes(String duration) {
    final lower = duration.toLowerCase().trim();
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower);
    if (match == null) return booksSchedule.slotDurationMinutes;
    final val = double.tryParse(match.group(1)!) ?? 2.0;
    if (lower.contains('min')) {
      return val.round().clamp(15, 720);
    }
    return (val * 60).round().clamp(15, 720);
  }

  static Iterable<DashboardAppointment> _matchingAppointments(
    ArtistBooksSchedule s,
    String? artistId,
  ) {
    final includeLocalRepo = identical(s, booksSchedule);
    return calendarAppointments.where((apt) {
      if (includeLocalRepo) {
        return artistId == null || apt.artistId == null || apt.artistId == artistId;
      }
      return artistId != null && apt.artistId == artistId;
    });
  }

  static Iterable<CustomHold> _activeLocalHolds(
    ArtistBooksSchedule s,
    DateTime now,
  ) {
    if (!identical(s, booksSchedule)) return const [];
    return customHolds.where((h) => !now.isAfter(h.expiresAt));
  }

  /// Returns canonical `YYYY-MM-DD` date keys that have at least one confirmed
  /// appointment or unexpired 24h custom hold.
  static Set<String> getOccupiedDateKeys({
    ArtistBooksSchedule? schedule,
    String? artistId,
    DateTime? now,
  }) {
    final s = schedule ?? booksSchedule;
    final effectiveNow = now ?? DateTime.now();
    final keys = <String>{};

    for (final apt in _matchingAppointments(s, artistId)) {
      if (apt.scheduledDate != null) {
        keys.add(ArtistBooksSchedule.dateKey(apt.scheduledDate!));
      }
    }
    for (final entry in s.bookedSlots) {
      if (entry.dateKey.isNotEmpty) keys.add(entry.dateKey);
    }
    for (final entry in s.heldSlots) {
      if (entry.dateKey.isNotEmpty && entry.isActiveAt(effectiveNow)) {
        keys.add(entry.dateKey);
      }
    }
    for (final hold in _activeLocalHolds(s, effectiveNow)) {
      keys.add(ArtistBooksSchedule.dateKey(hold.date));
    }
    return keys;
  }

  static bool isDateOccupied(
    DateTime date, {
    ArtistBooksSchedule? schedule,
    String? artistId,
    DateTime? now,
  }) {
    return getOccupiedDateKeys(
      schedule: schedule,
      artistId: artistId,
      now: now,
    ).contains(ArtistBooksSchedule.dateKey(date));
  }

  /// Counts distinct occupied dates in the Sunday–Saturday week containing [date].
  static int countBookedDaysInWeek(
    DateTime date, {
    ArtistBooksSchedule? schedule,
    String? artistId,
    DateTime? now,
  }) {
    final occupied = getOccupiedDateKeys(
      schedule: schedule,
      artistId: artistId,
      now: now,
    );
    if (occupied.isEmpty) return 0;

    final sun = ArtistBooksSchedule.weekStartSunday(date);
    int count = 0;
    for (int i = 0; i < 7; i++) {
      final day = DateTime(sun.year, sun.month, sun.day + i);
      if (occupied.contains(ArtistBooksSchedule.dateKey(day))) {
        count++;
      }
    }
    return count;
  }

  /// Returns true when [date] is an unbooked working day closed because the
  /// artist reached their configured Sun–Sat [maxWorkingDaysPerWeek] cap.
  static bool isClosedByWeeklyCap(
    DateTime date, {
    ArtistBooksSchedule? schedule,
    String? artistId,
    BookingMode? mode,
    DateTime? now,
  }) {
    if ((mode ?? bookingMode) != BookingMode.alwaysOpen || isPaused) {
      return false;
    }
    final s = schedule ?? booksSchedule;
    final cap = s.maxWorkingDaysPerWeek;
    if (cap == null || cap <= 0 || !s.isWorkingDay(date)) return false;

    final effectiveNow = now ?? DateTime.now();
    final occupied = getOccupiedDateKeys(
      schedule: s,
      artistId: artistId,
      now: effectiveNow,
    );
    final key = ArtistBooksSchedule.dateKey(date);
    if (occupied.contains(key)) return false;

    final sun = ArtistBooksSchedule.weekStartSunday(date);
    int weekCount = 0;
    for (int i = 0; i < 7; i++) {
      final day = DateTime(sun.year, sun.month, sun.day + i);
      if (occupied.contains(ArtistBooksSchedule.dateKey(day))) {
        weekCount++;
      }
    }
    return weekCount >= cap;
  }

  /// Checks whether a time slot currently has an active (non-expired) 24h custom hold.
  static bool hasActiveHoldForSlot({
    required DateTime date,
    required String timeSlot,
    ArtistBooksSchedule? schedule,
    DateTime? now,
  }) {
    final s = schedule ?? booksSchedule;
    final effectiveNow = now ?? DateTime.now();
    final key = ArtistBooksSchedule.dateKey(date);
    final targetTime = ArtistBooksSchedule.normalizeTimeLabel(timeSlot);

    if (s.heldSlots.any((entry) =>
        entry.dateKey == key &&
        entry.isActiveAt(effectiveNow) &&
        ArtistBooksSchedule.normalizeTimeLabel(entry.timeSlot) == targetTime)) {
      return true;
    }

    return _activeLocalHolds(s, effectiveNow).any((hold) {
      return ArtistBooksSchedule.dateKey(hold.date) == key &&
          ArtistBooksSchedule.normalizeTimeLabel(hold.timeSlot) == targetTime;
    });
  }

  static bool _isSlotBookableOnPrevalidatedDay({
    required DateTime dayOnly,
    required String timeSlot,
    required ArtistBooksSchedule schedule,
    required String? artistId,
    required BookingMode mode,
    required DateTime now,
    required bool hasBookingOrHoldOnDay,
  }) {
    if (isTimeSlotBooked(
      date: dayOnly,
      timeSlot: timeSlot,
      schedule: schedule,
      artistId: artistId,
    )) {
      return false;
    }
    if (hasActiveHoldForSlot(
      date: dayOnly,
      timeSlot: timeSlot,
      schedule: schedule,
      now: now,
    )) {
      return false;
    }

    final slotDt = ArtistBooksSchedule.parseSlotDateTime(dayOnly, timeSlot);
    if (slotDt != null) {
      if (!slotDt.isAfter(now)) return false;
      if (mode == BookingMode.alwaysOpen &&
          schedule.minLeadTimeHours > 0 &&
          !hasBookingOrHoldOnDay) {
        final cutoff = now.add(Duration(hours: schedule.minLeadTimeHours));
        if (slotDt.isBefore(cutoff)) return false;
      }
    }
    return true;
  }

  /// Returns true if [timeSlot] on [date] can currently be booked by a client.
  static bool isSlotBookable({
    required DateTime date,
    required String timeSlot,
    ArtistBooksSchedule? schedule,
    String? artistId,
    BookingMode? mode,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final effectiveMode = mode ?? bookingMode;
    final s = schedule ?? booksSchedule;
    if (!s.isBooksOpen) return false;

    final dayOnly = DateTime(date.year, date.month, date.day);
    final today = DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);
    if (dayOnly.isBefore(today)) return false;

    if (effectiveMode == BookingMode.alwaysOpen) {
      if (!s.isWorkingDay(dayOnly)) return false;
      if (!s.isDateForceOpened(dayOnly) && !s.isWithinBookingWindow(dayOnly)) {
        return false;
      }
      if (isClosedByWeeklyCap(
        dayOnly,
        schedule: s,
        artistId: artistId,
        mode: effectiveMode,
        now: effectiveNow,
      )) {
        return false;
      }
    } else {
      if (!s.workingDays.contains(dayOnly.weekday)) return false;
    }

    final hasBookingOrHoldOnDay = isDateOccupied(
      dayOnly,
      schedule: s,
      artistId: artistId,
      now: effectiveNow,
    );
    return _isSlotBookableOnPrevalidatedDay(
      dayOnly: dayOnly,
      timeSlot: timeSlot,
      schedule: s,
      artistId: artistId,
      mode: effectiveMode,
      now: effectiveNow,
      hasBookingOrHoldOnDay: hasBookingOrHoldOnDay,
    );
  }

  /// Returns true if [date] has at least one client-bookable time slot under the
  /// artist's working days, two-way overrides, weekly cap, and empty-day lead time.
  static bool isDateBookable({
    required DateTime date,
    ArtistBooksSchedule? schedule,
    String? artistId,
    BookingMode? mode,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final effectiveMode = mode ?? bookingMode;
    final s = schedule ?? booksSchedule;
    if (!s.isBooksOpen) return false;

    final dayOnly = DateTime(date.year, date.month, date.day);
    final today = DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);
    if (dayOnly.isBefore(today)) return false;

    if (effectiveMode == BookingMode.alwaysOpen) {
      if (!s.isWorkingDay(dayOnly)) return false;
      if (!s.isDateForceOpened(dayOnly) && !s.isWithinBookingWindow(dayOnly)) {
        return false;
      }
      if (isClosedByWeeklyCap(
        dayOnly,
        schedule: s,
        artistId: artistId,
        mode: effectiveMode,
        now: effectiveNow,
      )) {
        return false;
      }
    } else {
      if (!s.workingDays.contains(dayOnly.weekday)) return false;
    }

    final slots = s.generateTimeSlots();
    if (slots.isEmpty) return false;

    final hasBookingOrHoldOnDay = isDateOccupied(
      dayOnly,
      schedule: s,
      artistId: artistId,
      now: effectiveNow,
    );

    return slots.any(
      (slot) => _isSlotBookableOnPrevalidatedDay(
        dayOnly: dayOnly,
        timeSlot: slot.time,
        schedule: s,
        artistId: artistId,
        mode: effectiveMode,
        now: effectiveNow,
        hasBookingOrHoldOnDay: hasBookingOrHoldOnDay,
      ),
    );
  }

  /// Computes the remaining factual open minutes on [date], accounting for
  /// scheduled appointments, active 24h holds, and session buffers.
  static int getRemainingOpenMinutes(DateTime date) {
    if (isPaused) return 0;

    if (bookingMode == BookingMode.drops) {
      final drop = currentBookDrop;
      if (drop == null || drop.status == BookDropStatus.closed) return 0;
      final dateOnly = DateTime(date.year, date.month, date.day);
      final startOnly = DateTime(drop.startDate.year, drop.startDate.month, drop.startDate.day);
      final endOnly = DateTime(drop.endDate.year, drop.endDate.month, drop.endDate.day);
      if (dateOnly.isBefore(startOnly) || dateOnly.isAfter(endOnly)) return 0;
      if (!drop.selectedDays.contains(date.day)) return 0;
    } else {
      if (!booksSchedule.isWorkingDay(date) || isClosedByWeeklyCap(date)) {
        return 0;
      }
    }

    final apts = getAppointmentsForDate(date);
    final holds = customHolds.where((h) =>
        !h.isExpired &&
        h.date.year == date.year &&
        h.date.month == date.month &&
        h.date.day == date.day);

    int busyMinutes = 0;
    for (final apt in apts) {
      busyMinutes += parseDurationMinutes(apt.duration) + booksSchedule.bufferDurationMinutes;
    }
    for (final hold in holds) {
      busyMinutes += hold.durationMinutes + booksSchedule.bufferDurationMinutes;
    }

    final totalDayMinutes = (booksSchedule.endTime.hour * 60 + booksSchedule.endTime.minute) -
        (booksSchedule.startTime.hour * 60 + booksSchedule.startTime.minute);
    return (totalDayMinutes - busyMinutes).clamp(0, totalDayMinutes);
  }

  /// Calculates the visual capacity status for a given calendar date
  static DayCapacityStatus getDayCapacityStatus(DateTime date) {
    if (bookingMode == BookingMode.drops) {
      if (isPaused) return DayCapacityStatus.closed;
      final drop = currentBookDrop;
      if (drop == null || drop.status == BookDropStatus.closed) {
        return DayCapacityStatus.closed;
      }
      final dateOnly = DateTime(date.year, date.month, date.day);
      final startOnly = DateTime(drop.startDate.year, drop.startDate.month, drop.startDate.day);
      final endOnly = DateTime(drop.endDate.year, drop.endDate.month, drop.endDate.day);
      if (dateOnly.isBefore(startOnly) || dateOnly.isAfter(endOnly)) {
        return DayCapacityStatus.closed;
      }
      if (!drop.selectedDays.contains(date.day)) {
        return DayCapacityStatus.closed;
      }
    } else {
      if (isDateBlocked(date)) {
        return DayCapacityStatus.blocked;
      }
      if (isPaused ||
          !booksSchedule.isWorkingDay(date) ||
          isClosedByWeeklyCap(date)) {
        return DayCapacityStatus.closed;
      }
    }

    final remainingMinutes = getRemainingOpenMinutes(date);
    final totalDayMinutes = (booksSchedule.endTime.hour * 60 + booksSchedule.endTime.minute) -
        (booksSchedule.startTime.hour * 60 + booksSchedule.startTime.minute);
    if (totalDayMinutes <= 0) return DayCapacityStatus.closed;

    final busyMinutes = totalDayMinutes - remainingMinutes;
    if (remainingMinutes <= 30) {
      return DayCapacityStatus.full;
    }
    if (busyMinutes >= (totalDayMinutes * 0.4).toInt()) {
      return DayCapacityStatus.filling;
    }
    return DayCapacityStatus.open;
  }

  static List<WaitlistEntry> get waitlistEntries =>
      MockDataConfig.isEnabled ? _mockWaitlistEntries : liveWaitlistEntries;

  static set waitlistEntries(List<WaitlistEntry> value) {
    if (MockDataConfig.isEnabled) {
      _mockWaitlistEntries = value;
    } else {
      liveWaitlistEntries = value;
    }
    notifyPendingRequestsChanged();
  }

  static void addWaitlistEntry(WaitlistEntry entry) {
    final resolvedArtistId = entry.artistId.isNotEmpty && entry.artistId != 'artist_odd_maree'
        ? entry.artistId
        : BookingSyncService.resolveCurrentUid(entry.artistId);
    final enriched = entry.copyWith(artistId: resolvedArtistId);
    waitlistEntries = [enriched, ...waitlistEntries];
    BookingSyncService.syncWaitlistToCloud(
      waitlistEntries,
      artistId: resolvedArtistId,
    );
  }

  static void updateWaitlistEntry(WaitlistEntry entry) {
    final idx = waitlistEntries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      final updated = List<WaitlistEntry>.from(waitlistEntries);
      updated[idx] = entry;
      waitlistEntries = updated;
      final resolvedArtistId = entry.artistId.isNotEmpty && entry.artistId != 'artist_odd_maree'
          ? entry.artistId
          : BookingSyncService.resolveCurrentUid(entry.artistId);
      BookingSyncService.syncWaitlistToCloud(
        waitlistEntries,
        artistId: resolvedArtistId,
      );
    }
  }

  static void removeWaitlistEntry(String id) {
    waitlistEntries = waitlistEntries.where((e) => e.id != id).toList();
    final resolvedArtistId = BookingSyncService.resolveCurrentUid('artist_unknown');
    BookingSyncService.syncWaitlistToCloud(
      waitlistEntries,
      artistId: resolvedArtistId,
    );
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

    final resolvedArtistId = BookingSyncService.resolveCurrentUid('artist_unknown');
    BookingSyncService.syncBooksScheduleToCloud(
      booksSchedule,
      artistId: resolvedArtistId,
    );
    BookingSyncService.syncWaitlistToCloud(
      waitlistEntries,
      artistId: resolvedArtistId,
    );
  }

  /// Transitions books to completely open to the general public
  static void openBooksPublicly() {
    if (MockDataConfig.isEnabled) {
      _mockIsPaused = false;
      if (_mockBookingMode == BookingMode.drops && _mockBookDrop != null) {
        _mockBookDrop = _mockBookDrop!.copyWith(status: BookDropStatus.open);
      }
    } else {
      _liveIsPaused = false;
      if (_liveBookingMode == BookingMode.drops && _liveBookDrop != null) {
        _liveBookDrop = _liveBookDrop!.copyWith(status: BookDropStatus.open);
      }
    }
    booksSchedule = booksSchedule.copyWith(
      isBooksOpen: true,
      isEarlyAccessOnly: false,
      earlyAccessEndsAt: null,
    );
    final resolvedArtistId = BookingSyncService.resolveCurrentUid('');
    if (resolvedArtistId.isNotEmpty) {
      BookingSyncService.syncBooksScheduleToCloud(
        booksSchedule,
        artistId: resolvedArtistId,
      );
    }
  }

  /// Closes books
  static void closeBooks() {
    if (MockDataConfig.isEnabled) {
      _mockIsPaused = false;
      if (_mockBookingMode == BookingMode.drops && _mockBookDrop != null) {
        _mockBookDrop = _mockBookDrop!.copyWith(status: BookDropStatus.closed);
      }
    } else {
      _liveIsPaused = false;
      if (_liveBookingMode == BookingMode.drops && _liveBookDrop != null) {
        _liveBookDrop = _liveBookDrop!.copyWith(status: BookDropStatus.closed);
      }
    }
    booksSchedule = booksSchedule.copyWith(
      isBooksOpen: false,
      isEarlyAccessOnly: false,
      earlyAccessEndsAt: null,
    );
    final resolvedArtistId = BookingSyncService.resolveCurrentUid('');
    if (resolvedArtistId.isNotEmpty) {
      BookingSyncService.syncBooksScheduleToCloud(
        booksSchedule,
        artistId: resolvedArtistId,
      );
    }
  }

  static const ArtistEarningsData _mockEarningsData = ArtistEarningsData();

  /// Computes live earnings from confirmed/completed appointments when running in live mode,
  /// or returns the quarantined [_mockEarningsData] when [MockDataConfig.isEnabled] is true.
  static ArtistEarningsData get earningsData {
    if (MockDataConfig.isEnabled) {
      return _mockEarningsData;
    }
    final now = DateTime.now();
    final uniqueById = <String, DashboardAppointment>{};
    for (final apt in liveTodaySchedule) {
      uniqueById[apt.id] = apt;
    }
    for (final apt in liveCalendarAppointments) {
      uniqueById[apt.id] = apt;
    }

    double available = 0.0;
    int mtd = 0;
    int ytd = 0;

    for (final apt in uniqueById.values) {
      final earned = apt.depositPaid > 0 ? apt.depositPaid : apt.fullPrice;
      available += earned.toDouble();
      final dt = apt.scheduledDate ?? now;
      if (dt.year == now.year) {
        ytd += apt.fullPrice;
        if (dt.month == now.month) {
          mtd += apt.fullPrice;
        }
      }
    }

    return ArtistEarningsData(
      nextPayoutAmount: available,
      mtdAmount: mtd,
      ytdAmount: ytd,
      ytdYear: '${now.year}',
    );
  }

  static const DashboardAppointment _mockNextAppointment = DashboardAppointment(
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

  /// Active next appointment for the current runtime mode (`null` when live and no appointments exist).
  static DashboardAppointment? get activeNextAppointment {
    if (MockDataConfig.isEnabled) {
      return _mockNextAppointment;
    }
    final todayList = todaySchedule;
    if (todayList.isNotEmpty) {
      return todayList.first;
    }
    if (liveCalendarAppointments.isEmpty) {
      return null;
    }
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final upcoming = liveCalendarAppointments.where((apt) {
      if (apt.scheduledDate == null) return true;
      return !apt.scheduledDate!.isBefore(todayStart);
    }).toList();
    if (upcoming.isEmpty) {
      return liveCalendarAppointments.first;
    }
    upcoming.sort((a, b) {
      final da = a.scheduledDate ?? todayStart;
      final db = b.scheduledDate ?? todayStart;
      return da.compareTo(db);
    });
    return upcoming.first;
  }

  /// Legacy non-nullable getter preserved for compatibility; prefer [activeNextAppointment] in UI.
  static DashboardAppointment get nextAppointment =>
      activeNextAppointment ?? _mockNextAppointment;

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

  static List<DashboardAppointment> _mockTodaySchedule =
      List.from(_defaultTodaySchedule);
  static List<DashboardAppointment> liveTodaySchedule = [];

  static List<DashboardAppointment> get todaySchedule {
    if (MockDataConfig.isEnabled) {
      return _mockTodaySchedule;
    }
    final now = DateTime.now();
    final merged = <String, DashboardAppointment>{};
    for (final apt in liveTodaySchedule) {
      merged[apt.id] = apt;
    }
    for (final apt in liveCalendarAppointments) {
      if (apt.scheduledDate != null &&
          apt.scheduledDate!.year == now.year &&
          apt.scheduledDate!.month == now.month &&
          apt.scheduledDate!.day == now.day) {
        merged[apt.id] = apt;
      } else if (apt.date.toLowerCase() == 'today') {
        merged[apt.id] = apt;
      }
    }
    return merged.values.toList();
  }

  static set todaySchedule(List<DashboardAppointment> value) {
    if (MockDataConfig.isEnabled) {
      _mockTodaySchedule = value;
    } else {
      liveTodaySchedule = value;
    }
    notifyPendingRequestsChanged();
  }

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

  static List<BookingRequest> _mockPendingRequests =
      List.from(_defaultPendingRequests);
  static List<BookingRequest> livePendingRequests = [];

  static List<BookingRequest> get pendingRequests =>
      MockDataConfig.isEnabled ? _mockPendingRequests : livePendingRequests;

  static set pendingRequests(List<BookingRequest> value) {
    if (MockDataConfig.isEnabled) {
      _mockPendingRequests = value;
    } else {
      livePendingRequests = value;
    }
    notifyPendingRequestsChanged();
  }

  /// Notifier triggered whenever pending requests or dashboard stats change in real time.
  static final ValueNotifier<int> pendingRequestsNotifier = ValueNotifier<int>(0);

  static void notifyPendingRequestsChanged() {
    pendingRequestsNotifier.value++;
  }

  static ArtistDashboardStats _mockStats = ArtistDashboardStats(
    bookingsThisWeek: 12,
    newRequests: _defaultPendingRequests.length,
    pendingCount: _defaultPendingRequests.length,
  );
  static ArtistDashboardStats? _liveStatsOverride;

  static ArtistDashboardStats get stats {
    if (MockDataConfig.isEnabled) {
      return ArtistDashboardStats(
        bookingsThisWeek: _mockStats.bookingsThisWeek,
        newRequests: _mockPendingRequests.length,
        pendingCount: _mockPendingRequests.length,
      );
    }
    if (_liveStatsOverride != null) {
      return ArtistDashboardStats(
        bookingsThisWeek: _liveStatsOverride!.bookingsThisWeek,
        newRequests: livePendingRequests.length,
        pendingCount: livePendingRequests.length,
      );
    }
    return ArtistDashboardStats(
      bookingsThisWeek: liveCalendarAppointments.length,
      newRequests: livePendingRequests.length,
      pendingCount: livePendingRequests.length,
    );
  }

  static set stats(ArtistDashboardStats value) {
    if (MockDataConfig.isEnabled) {
      _mockStats = value;
    } else {
      _liveStatsOverride = value;
    }
    notifyPendingRequestsChanged();
  }

  /// Resets pending requests and dashboard stats back to defaults (useful for test isolation).
  static void resetMockData() {
    _mockPendingRequests = List.from(_defaultPendingRequests);
    _mockTodaySchedule = List.from(_defaultTodaySchedule);
    _mockWaitlistEntries = List.from(WaitlistEntry.mockWaitlistEntries);
    _mockCalendarAppointments = List.from(_defaultCalendarAppointments);
    _mockStats = ArtistDashboardStats(
      bookingsThisWeek: 12,
      newRequests: _mockPendingRequests.length,
      pendingCount: _mockPendingRequests.length,
    );
    _mockBooksSchedule = ArtistBooksSchedule(
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
    livePendingRequests = [];
    liveTodaySchedule = [];
    liveWaitlistEntries = [];
    liveCalendarAppointments = [];
    _liveStatsOverride = null;
    _liveBooksSchedule = ArtistBooksSchedule(
      isBooksOpen: true,
      isEarlyAccessOnly: false,
      bookingWindowStart: DateTime(DateTime.now().year, DateTime.now().month, 1),
      bookingWindowEnd: DateTime(DateTime.now().year, DateTime.now().month + 3, 0),
      workingDays: const {2, 3, 4, 5, 6},
      startTime: const TimeOfDay(hour: 11, minute: 0),
      endTime: const TimeOfDay(hour: 19, minute: 0),
      slotDurationMinutes: 120,
      bufferDurationMinutes: 30,
      defaultDepositAmount: 80,
      acceptFlash: true,
      acceptCustom: true,
      acceptTouchUps: true,
      locationNote: '',
    );
    _mockBookingMode = BookingMode.alwaysOpen;
    _liveBookingMode = BookingMode.alwaysOpen;
    _mockIsPaused = false;
    _liveIsPaused = false;
    _mockBookDrop = BookDrop(
      id: 'drop_dec_2026',
      title: 'December Booking Drop',
      startDate: DateTime(2026, 12, 1),
      endDate: DateTime(2026, 12, 31),
      status: BookDropStatus.open,
      selectedDays: const {1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 15, 16, 17, 18, 19},
      acceptFlash: true,
      acceptCustom: true,
      acceptTouchUps: true,
      requestCap: 25,
      requestCount: 14,
      earlyAccessHours: 24,
    );
    _liveBookDrop = null;
    _mockCustomHolds = [
      CustomHold(
        id: 'hold_dragon_1',
        requestId: 'req_dragon_sarah',
        clientName: 'Sarah M.',
        date: DateTime(2026, 12, 4),
        timeSlot: '2:00 PM',
        durationMinutes: 180,
        estimatedPrice: 450,
        deposit: 80,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        expiresAt: DateTime.now().add(const Duration(hours: 16)),
      ),
    ];
    _liveCustomHolds = [];
    BookingSyncService.resetSyncState();
    notifyPendingRequestsChanged();
  }

  /// Adds a newly submitted custom tattoo brief to the artist's pending requests queue.
  static void addPendingRequest(BookingRequest request) {
    final resolvedClientId = request.clientId ?? BookingSyncService.resolveCurrentUid();
    final resolvedArtistId = request.artistId ?? 'artist_unknown';
    final enrichedRequest = request.copyWith(
      clientId: resolvedClientId,
      artistId: resolvedArtistId,
    );
    final currentStats = stats;
    pendingRequests = [enrichedRequest, ...pendingRequests];
    stats = ArtistDashboardStats(
      bookingsThisWeek: currentStats.bookingsThisWeek,
      newRequests: currentStats.newRequests + 1,
      pendingCount: pendingRequests.length,
    );
    notifyPendingRequestsChanged();
    BookingSyncService.syncCustomRequestToCloud(
      enrichedRequest,
      clientId: resolvedClientId,
      artistId: resolvedArtistId,
      status: 'pending',
    );
    BookingSyncService.sendBookingNotification(
      senderId: resolvedClientId,
      recipientId: resolvedArtistId,
      recipientName: enrichedRequest.artistName,
      title: 'New Custom Request • ${enrichedRequest.clientName}',
      body: '${enrichedRequest.category} (${enrichedRequest.placement}) • Est. \$${enrichedRequest.estimatedPrice}',
      category: 'custom_request',
      appointmentId: enrichedRequest.id,
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
      while ((!booksSchedule.isWorkingDay(effectiveDate) ||
              isClosedByWeeklyCap(effectiveDate)) &&
          guard < 30) {
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
    final currentStats = stats;
    pendingRequests = pendingRequests.where((r) => r.id != request.id).toList();
    stats = ArtistDashboardStats(
      bookingsThisWeek: currentStats.bookingsThisWeek + 1,
      newRequests: currentStats.newRequests > 0 ? currentStats.newRequests - 1 : 0,
      pendingCount: pendingRequests.length,
    );
    notifyPendingRequestsChanged();

    // 4. Create & register Artist Calendar appointment
    final resolvedArtistId = request.artistId ?? BookingSyncService.resolveCurrentUid('artist_1');
    final resolvedClientId = request.clientId ?? 'client_unknown';
    final calendarApt = DashboardAppointment(
      id: 'cal_custom_${request.id}',
      clientId: resolvedClientId,
      artistId: resolvedArtistId,
      clientName: request.clientName,
      clientAvatar: request.clientAvatar,
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
    BookingSyncService.syncCustomRequestToCloud(
      request,
      clientId: resolvedClientId,
      artistId: resolvedArtistId,
      status: 'accepted',
    );
    BookingSyncService.sendBookingNotification(
      senderId: resolvedArtistId,
      recipientId: resolvedClientId,
      recipientName: request.clientName,
      title: 'Custom Request Confirmed!',
      body: '${request.artistName} scheduled your ${request.category} session on $formattedDate at $effectiveTimeSlot.',
      category: 'booking_confirmed',
      appointmentId: calendarApt.id,
    );

    // 5. Create & register Client Upcoming appointment
    final liveArtistAvatar = BookingSyncService.resolveCurrentUserPhotoUrlSync();
    final effectiveAvatar = MockDataConfig.isEnabled
        ? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80'
        : liveArtistAvatar;
    final effectiveStudio = booksSchedule.locationNote.isNotEmpty
        ? booksSchedule.locationNote
        : (MockDataConfig.isEnabled ? 'Obsidian Atelier' : request.artistName);
    final clientApt = ClientAppointment(
      id: 'CUST-${request.id.hashCode.abs() % 90000 + 10000}',
      artistName: request.artistName,
      artistAvatar: effectiveAvatar,
      studioName: effectiveStudio,
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
    final receiptDateTime =
        ArtistBooksSchedule.parseSlotDateTime(effectiveDate, effectiveTimeSlot) ??
            effectiveDate;
    final receiptMessage = ChatMessage(
      id: 'receipt_${request.id}',
      senderId: 'system',
      senderName: request.artistName,
      text: 'Custom Request Approved • Deposit Confirmed (\$$effectiveDeposit)',
      timestamp: DateTime.now(),
      isFromArtist: true,
      type: ChatMessageType.receipt,
      receiptAmount: effectiveDeposit.toDouble(),
      appointmentDate: receiptDateTime,
      appointmentTimeSlot: effectiveTimeSlot,
      appointmentDurationMinutes: booksSchedule.slotDurationMinutes,
      artistName: request.artistName,
      studioLocation: effectiveStudio,
      flashTitle: 'Custom: ${request.category}',
      placement: request.placement,
      flashImageUrl: request.sketchImageUrl.isNotEmpty
          ? request.sketchImageUrl
          : 'assets/images/flash_traditional_panther.jpg',
    );
    final followUpMessage = ChatMessage(
      id: 'msg_accept_${request.id}',
      senderId: resolvedArtistId,
      senderName: request.artistName,
      text: 'I accepted your custom tattoo brief for $formattedDate at $effectiveTimeSlot! Estimated total: \$$effectivePrice (\$$effectiveDeposit deposit).',
      timestamp: DateTime.now(),
      isFromArtist: true,
    );

    final thread = MessageThread(
      id: 'thread_custom_${request.id}',
      artistId: resolvedArtistId,
      clientId: resolvedClientId,
      clientName: request.clientName,
      clientAvatar: request.clientAvatar ?? '',
      artistName: request.artistName,
      artistAvatar: effectiveAvatar,
      studioName: effectiveStudio,
      lastMessage: followUpMessage.text,
      lastMessageTime: DateTime.now(),
      unreadCount: 1,
      isOnline: true,
      flashTitleContext: 'Custom: ${request.category}',
      messages: [receiptMessage, followUpMessage],
    );
    MessageThread.addThread(thread);
    BookingSyncService.syncChatThreadToCloud(
      thread,
      clientId: resolvedClientId,
      artistId: resolvedArtistId,
      clientName: request.clientName,
      clientAvatar: request.clientAvatar,
      artistAvatar: effectiveAvatar,
    );

    return calendarApt;
  }

  /// Declines a pending booking request and removes it from the active queue.
  static void declineBookingRequest(String requestId) {
    final matching = pendingRequests.where((r) => r.id == requestId).toList();
    final beforeLen = pendingRequests.length;
    final currentStats = stats;
    pendingRequests = pendingRequests.where((r) => r.id != requestId).toList();
    if (pendingRequests.length < beforeLen) {
      stats = ArtistDashboardStats(
        bookingsThisWeek: currentStats.bookingsThisWeek,
        newRequests: currentStats.newRequests > 0 ? currentStats.newRequests - 1 : 0,
        pendingCount: pendingRequests.length,
      );
      notifyPendingRequestsChanged();
      if (matching.isNotEmpty) {
        BookingSyncService.syncCustomRequestToCloud(
          matching.first,
          clientId: matching.first.clientId,
          artistId: matching.first.artistId,
          status: 'declined',
        );
      }
    }
  }

  /// Quarantined mock appointments for the interactive artist calendar.
  static final List<DashboardAppointment> _defaultCalendarAppointments = [
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

  static List<DashboardAppointment> _mockCalendarAppointments =
      List.from(_defaultCalendarAppointments);
  static List<DashboardAppointment> liveCalendarAppointments = [];

  static List<DashboardAppointment> get calendarAppointments =>
      MockDataConfig.isEnabled ? _mockCalendarAppointments : liveCalendarAppointments;

  static const List<DashboardAppointment> _mockHistoryAppointments = [
    DashboardAppointment(
      id: 'hist_alex_m',
      clientName: 'Alex M.',
      serviceType: 'Full Sleeve Session',
      duration: '4 hrs',
      time: '1:00 PM',
      date: 'Oct 24, 2023',
      placement: 'Full Right Arm',
      notes: 'Japanese dragon sleeve completion session. Shading and background waves finalized.',
      depositPaid: 150,
      fullPrice: 800,
      artworkImageUrl: 'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=400&q=80',
      visitType: 'Session Inking',
    ),
    DashboardAppointment(
      id: 'hist_sarah_t',
      clientName: 'Sarah T.',
      serviceType: 'Custom Flash',
      duration: '1.5 hrs',
      time: '3:30 PM',
      date: 'Oct 22, 2023',
      placement: 'Forearm',
      notes: 'Floral flash with fine line botanicals.',
      depositPaid: 50,
      fullPrice: 250,
      artworkImageUrl: 'https://images.unsplash.com/photo-1562962230-16e4623d36e6?auto=format&fit=crop&w=400&q=80',
      visitType: 'Flash Tattoo',
    ),
    DashboardAppointment(
      id: 'hist_marcus_k',
      clientName: 'Marcus K.',
      serviceType: 'Fine Line Floral',
      duration: '2 hrs',
      time: '11:00 AM',
      date: 'Oct 15, 2023',
      placement: 'Ribs',
      notes: 'Delicate fine line peony.',
      depositPaid: 60,
      fullPrice: 320,
      artworkImageUrl: 'https://images.unsplash.com/photo-1543852786-1cf6624b9987?auto=format&fit=crop&w=400&q=80',
      visitType: 'Fine Line',
    ),
    DashboardAppointment(
      id: 'hist_elena_r',
      clientName: 'Elena R.',
      serviceType: 'Micro Realism Eye',
      duration: '2.5 hrs',
      time: '4:00 PM',
      date: 'Oct 10, 2023',
      placement: 'Bicep',
      notes: 'Realistic eye portrait with geometric framing.',
      depositPaid: 90,
      fullPrice: 450,
      artworkImageUrl: 'https://images.unsplash.com/photo-1568515045052-f9a854d70bfd?auto=format&fit=crop&w=400&q=80',
      visitType: 'Custom Tattoo',
    ),
    DashboardAppointment(
      id: 'hist_dave_l',
      clientName: 'Dave L.',
      serviceType: 'Traditional Dagger',
      duration: '2 hrs',
      time: '2:30 PM',
      date: 'Sep 29, 2023',
      placement: 'Calf',
      notes: 'Classic bold line dagger piercing a black rose.',
      depositPaid: 60,
      fullPrice: 300,
      artworkImageUrl: 'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?auto=format&fit=crop&w=400&q=80',
      visitType: 'Traditional',
    ),
  ];

  /// Active transaction history appointments for the Earnings screen.
  static List<DashboardAppointment> get historyAppointments {
    if (MockDataConfig.isEnabled) {
      return [
        ..._mockCalendarAppointments,
        ..._mockHistoryAppointments,
      ];
    }
    final uniqueById = <String, DashboardAppointment>{};
    for (final apt in liveTodaySchedule) {
      uniqueById[apt.id] = apt;
    }
    for (final apt in liveCalendarAppointments) {
      uniqueById[apt.id] = apt;
    }
    return uniqueById.values.toList();
  }

  /// Quarantined mock Flash users for the waitlist quick-search sheet.
  static const List<Map<String, String>> _mockFlashUsers = [
    {
      'id': 'user_chloe_b',
      'name': 'Chloe Bennett',
      'handle': '@chloeb_ink',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
      'email': 'chloe.bennett@example.com',
      'phone': '(503) 555-0192',
    },
    {
      'id': 'user_julian_a',
      'name': 'Julian Alvarez',
      'handle': '@julian_arts',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
      'email': 'julian.ink@example.com',
      'phone': '(503) 555-0841',
    },
    {
      'id': 'user_marcus_c',
      'name': 'Marcus Cole',
      'handle': '@marcus_tats',
      'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
      'email': 'marcus.cole@example.com',
      'phone': '(503) 555-9923',
    },
    {
      'id': 'user_elena_r',
      'name': 'Elena Rostova',
      'handle': '@elena_pnw',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      'email': 'elena.rostova@example.com',
      'phone': '(503) 555-4412',
    },
  ];

  /// Returns searchable Flash clients for the waitlist sheet.
  /// In live mode, derives known clients from the artist's real appointments, custom requests, and chat threads.
  static List<Map<String, String>> get searchableFlashClients {
    if (MockDataConfig.isEnabled) {
      return _mockFlashUsers;
    }
    final byKey = <String, Map<String, String>>{};
    for (final apt in [...liveTodaySchedule, ...liveCalendarAppointments]) {
      final name = apt.clientName.trim();
      if (name.isEmpty) continue;
      final id = (apt.clientId != null && apt.clientId!.trim().isNotEmpty)
          ? apt.clientId!.trim()
          : 'client_${name.toLowerCase().replaceAll(' ', '_')}';
      byKey[id] = {
        'id': id,
        'name': name,
        'handle': '@${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        'avatar': '',
        'email': '',
        'phone': '',
      };
    }
    for (final req in livePendingRequests) {
      final name = req.clientName.trim();
      if (name.isEmpty) continue;
      final id = (req.clientId != null && req.clientId!.trim().isNotEmpty)
          ? req.clientId!.trim()
          : 'client_${name.toLowerCase().replaceAll(' ', '_')}';
      byKey.putIfAbsent(id, () => {
        'id': id,
        'name': name,
        'handle': '@${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
        'avatar': '',
        'email': '',
        'phone': '',
      });
    }
    return byKey.values.toList();
  }

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
    ArtistBooksSchedule? schedule,
    String? artistId,
  }) {
    final s = schedule ?? booksSchedule;
    final key = ArtistBooksSchedule.dateKey(date);
    final targetTime = ArtistBooksSchedule.normalizeTimeLabel(timeSlot);

    if (s.bookedSlots.any((entry) =>
        entry.dateKey == key &&
        ArtistBooksSchedule.normalizeTimeLabel(entry.timeSlot) == targetTime)) {
      return true;
    }

    return _matchingAppointments(s, artistId).any((apt) {
      if (apt.scheduledDate == null) return false;
      if (ArtistBooksSchedule.dateKey(apt.scheduledDate!) != key) return false;
      return ArtistBooksSchedule.normalizeTimeLabel(apt.time) == targetTime;
    });
  }

  /// Adds a confirmed booking appointment to the artist's calendar schedule.
  static void addCalendarAppointment(DashboardAppointment appointment) {
    final resolvedClientId = appointment.clientId ?? BookingSyncService.resolveCurrentUid();
    final resolvedArtistId = appointment.artistId ?? BookingSyncService.resolveCurrentUid('artist_unknown');
    final enrichedApt = appointment.copyWith(
      clientId: resolvedClientId,
      artistId: resolvedArtistId,
    );
    calendarAppointments.add(enrichedApt);
    notifyPendingRequestsChanged();
    BookingSyncService.syncAppointmentToCloud(
      enrichedApt,
      clientId: resolvedClientId,
      artistId: resolvedArtistId,
      status: 'confirmed',
    );
    final alreadyNotified = BookingSyncService.sentNotifications.any(
      (n) => n.appointmentId == enrichedApt.id && n.category == 'booking_confirmed',
    );
    if (!alreadyNotified) {
      BookingSyncService.sendBookingNotification(
        senderId: resolvedClientId,
        recipientId: resolvedArtistId,
        recipientName: enrichedApt.clientName,
        title: 'Booking Confirmed!',
        body: '${enrichedApt.serviceType} scheduled for ${enrichedApt.date} at ${enrichedApt.time}.',
        category: 'booking_confirmed',
        appointmentId: enrichedApt.id,
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
    notifyPendingRequestsChanged();

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
    final resolvedArtistId = updatedApt.artistId ?? BookingSyncService.resolveCurrentUid('artist_1');
    final resolvedArtistName = MockDataConfig.isEnabled
        ? 'OddMaree'
        : BookingSyncService.resolveCurrentUserDisplayNameSync('Artist');
    final effectiveAvatar = MockDataConfig.isEnabled
        ? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80'
        : BookingSyncService.resolveCurrentUserPhotoUrlSync();
    final effectiveStudio = booksSchedule.locationNote.isNotEmpty
        ? booksSchedule.locationNote
        : (MockDataConfig.isEnabled ? 'Obsidian Atelier' : 'Studio');
    final msg = ChatMessage(
      id: 'msg_resched_${DateTime.now().millisecondsSinceEpoch}',
      senderId: resolvedArtistId,
      senderName: resolvedArtistName,
      text: 'Your appointment for ${updatedApt.serviceType} has been rescheduled to $formattedDate at $newTimeSlot. Your \$${updatedApt.depositPaid} deposit automatically transfers to the new slot.',
      timestamp: DateTime.now(),
      isFromArtist: true,
    );
    final thread = MessageThread(
      id: 'thread_resched_$appointmentId',
      artistId: resolvedArtistId,
      clientId: updatedApt.clientId,
      clientName: updatedApt.clientName,
      clientAvatar: updatedApt.clientAvatar ?? '',
      artistName: resolvedArtistName,
      artistAvatar: effectiveAvatar,
      studioName: effectiveStudio,
      lastMessage: msg.text,
      lastMessageTime: DateTime.now(),
      unreadCount: 1,
      isOnline: true,
      flashTitleContext: updatedApt.serviceType,
      messages: [msg],
    );
    MessageThread.addThread(thread);
    BookingSyncService.syncChatThreadToCloud(
      thread,
      clientId: updatedApt.clientId,
      artistId: resolvedArtistId,
      clientName: updatedApt.clientName,
      clientAvatar: updatedApt.clientAvatar,
      artistAvatar: effectiveAvatar,
    );

    // 6. Sync to Cloud Firestore & send notification
    BookingSyncService.syncAppointmentToCloud(
      updatedApt,
      clientId: updatedApt.clientId,
      artistId: updatedApt.artistId,
      status: 'rescheduled',
    );
    BookingSyncService.sendBookingNotification(
      senderId: updatedApt.artistId ?? BookingSyncService.resolveCurrentUid(),
      recipientId: updatedApt.clientId ?? 'client_unknown',
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
    notifyPendingRequestsChanged();

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

    final resolvedArtistId = removedApt.artistId ?? BookingSyncService.resolveCurrentUid('artist_1');
    final resolvedArtistName = MockDataConfig.isEnabled
        ? 'OddMaree'
        : BookingSyncService.resolveCurrentUserDisplayNameSync('Artist');
    final effectiveAvatar = MockDataConfig.isEnabled
        ? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80'
        : BookingSyncService.resolveCurrentUserPhotoUrlSync();
    final effectiveStudio = booksSchedule.locationNote.isNotEmpty
        ? booksSchedule.locationNote
        : (MockDataConfig.isEnabled ? 'Obsidian Atelier' : 'Studio');
    final reasonNote = (reason != null && reason.trim().isNotEmpty)
        ? ' Reason: ${reason.trim()}.'
        : '';
    final msg = ChatMessage(
      id: 'msg_cancel_${DateTime.now().millisecondsSinceEpoch}',
      senderId: resolvedArtistId,
      senderName: resolvedArtistName,
      text: 'Appointment for ${removedApt.serviceType} (${removedApt.date} at ${removedApt.time}) has been cancelled.$reasonNote',
      timestamp: DateTime.now(),
      isFromArtist: true,
    );
    final thread = MessageThread(
      id: 'thread_cancel_$appointmentId',
      artistId: resolvedArtistId,
      clientId: removedApt.clientId,
      clientName: removedApt.clientName,
      clientAvatar: removedApt.clientAvatar ?? '',
      artistName: resolvedArtistName,
      artistAvatar: effectiveAvatar,
      studioName: effectiveStudio,
      lastMessage: msg.text,
      lastMessageTime: DateTime.now(),
      unreadCount: 1,
      isOnline: true,
      flashTitleContext: removedApt.serviceType,
      messages: [msg],
    );
    MessageThread.addThread(thread);
    BookingSyncService.syncChatThreadToCloud(
      thread,
      clientId: removedApt.clientId,
      artistId: resolvedArtistId,
      clientName: removedApt.clientName,
      clientAvatar: removedApt.clientAvatar,
      artistAvatar: effectiveAvatar,
    );

    BookingSyncService.syncAppointmentToCloud(
      removedApt,
      clientId: removedApt.clientId,
      artistId: removedApt.artistId,
      status: 'cancelled',
    );
    BookingSyncService.sendBookingNotification(
      senderId: removedApt.artistId ?? BookingSyncService.resolveCurrentUid(),
      recipientId: removedApt.clientId ?? 'client_unknown',
      recipientName: removedApt.clientName,
      title: 'Appointment Cancelled',
      body: 'Your ${removedApt.serviceType} session on ${removedApt.date} at ${removedApt.time} was cancelled.',
      category: 'cancelled',
      appointmentId: removedApt.id,
    );

    return true;
  }
}

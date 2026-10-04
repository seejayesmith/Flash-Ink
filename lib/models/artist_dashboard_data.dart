import 'package:flutter/material.dart';

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
  });
}

/// Top-level metrics displayed on the artist dashboard.
class ArtistDashboardStats {
  final int bookingsThisWeek;
  final int newRequests;
  final int pendingCount;

  const ArtistDashboardStats({
    this.bookingsThisWeek = 12,
    this.newRequests = 2,
    this.pendingCount = 12,
  });
}

/// Represents a past completed booking transaction for the earnings view.
class PastBookingEarningsItem {
  final String id;
  final String title;
  final String clientName;
  final String serviceType;
  final String status;
  final String dateString;
  final double amount;
  final double fee;
  final String paymentMethod;
  final String receiptId;

  const PastBookingEarningsItem({
    required this.id,
    required this.title,
    required this.clientName,
    required this.serviceType,
    this.status = 'Completed',
    required this.dateString,
    required this.amount,
    this.fee = 0.0,
    this.paymentMethod = 'Apple Pay',
    this.receiptId = 'REC-2023-8912',
  });

  double get netAmount => amount - fee;
}

/// Earnings metrics and payout information for the artist.
class ArtistEarningsData {
  final double nextPayoutAmount;
  double get availableFundsAmount => nextPayoutAmount;
  final String payoutDepositDate;
  final int mtdAmount;
  final String mtdMonth;
  final int ytdAmount;
  final String ytdYear;
  final List<PastBookingEarningsItem> pastBookings;
  final List<PastBookingEarningsItem> allPastBookings;

  const ArtistEarningsData({
    this.nextPayoutAmount = 1256.09,
    this.payoutDepositDate = 'Friday August 14th',
    this.mtdAmount = 3467,
    this.mtdMonth = 'AUGUST',
    this.ytdAmount = 16987,
    this.ytdYear = '2026',
    this.pastBookings = const [
      PastBookingEarningsItem(
        id: 'pb_alex_m',
        title: 'Full Sleeve Session - Alex M.',
        clientName: 'Alex M.',
        serviceType: 'Full Sleeve Session',
        status: 'Completed',
        dateString: 'Oct 24, 2023',
        amount: 800.00,
        fee: 40.00,
        paymentMethod: 'Direct Deposit / Card',
        receiptId: 'REC-2023-9041',
      ),
      PastBookingEarningsItem(
        id: 'pb_sarah_t',
        title: 'Custom Flash - Sarah T.',
        clientName: 'Sarah T.',
        serviceType: 'Custom Flash',
        status: 'Completed',
        dateString: 'Oct 22, 2023',
        amount: 250.00,
        fee: 12.50,
        paymentMethod: 'Apple Pay',
        receiptId: 'REC-2023-8974',
      ),
    ],
    this.allPastBookings = const [
      PastBookingEarningsItem(
        id: 'pb_alex_m',
        title: 'Full Sleeve Session - Alex M.',
        clientName: 'Alex M.',
        serviceType: 'Full Sleeve Session',
        status: 'Completed',
        dateString: 'Oct 24, 2023',
        amount: 800.00,
        fee: 40.00,
        paymentMethod: 'Direct Deposit / Card',
        receiptId: 'REC-2023-9041',
      ),
      PastBookingEarningsItem(
        id: 'pb_sarah_t',
        title: 'Custom Flash - Sarah T.',
        clientName: 'Sarah T.',
        serviceType: 'Custom Flash',
        status: 'Completed',
        dateString: 'Oct 22, 2023',
        amount: 250.00,
        fee: 12.50,
        paymentMethod: 'Apple Pay',
        receiptId: 'REC-2023-8974',
      ),
      PastBookingEarningsItem(
        id: 'pb_marcus_k',
        title: 'Fine Line Floral - Marcus K.',
        clientName: 'Marcus K.',
        serviceType: 'Fine Line Floral',
        status: 'Completed',
        dateString: 'Oct 15, 2023',
        amount: 320.00,
        fee: 16.00,
        paymentMethod: 'Credit Card',
        receiptId: 'REC-2023-8820',
      ),
      PastBookingEarningsItem(
        id: 'pb_elena_r',
        title: 'Micro Realism Eye - Elena R.',
        clientName: 'Elena R.',
        serviceType: 'Micro Realism Eye',
        status: 'Completed',
        dateString: 'Oct 10, 2023',
        amount: 450.00,
        fee: 22.50,
        paymentMethod: 'Apple Pay',
        receiptId: 'REC-2023-8742',
      ),
      PastBookingEarningsItem(
        id: 'pb_dave_l',
        title: 'Traditional Dagger - Dave L.',
        clientName: 'Dave L.',
        serviceType: 'Traditional Dagger',
        status: 'Completed',
        dateString: 'Sep 29, 2023',
        amount: 300.00,
        fee: 15.00,
        paymentMethod: 'Debit Card',
        receiptId: 'REC-2023-8510',
      ),
    ],
  });
}

/// Represents the configuration for an artist's booking schedule ("Books").
class ArtistBooksSchedule {
  final bool isBooksOpen;
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

  ArtistBooksSchedule copyWith({
    bool? isBooksOpen,
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

  static const List<DashboardAppointment> todaySchedule = [
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

  static const List<BookingRequest> pendingRequests = [
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

  static const ArtistDashboardStats stats = ArtistDashboardStats(
    bookingsThisWeek: 12,
    newRequests: 2,
    pendingCount: 12,
  );

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
      scheduledDate: DateTime(2026, 9, 9),
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
}

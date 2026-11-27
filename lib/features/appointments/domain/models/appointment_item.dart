import 'package:flutter/foundation.dart';
import '../../../../core/mock/mock_data_config.dart';
import '../../../../core/mock/mock_fixtures.dart';

enum AppointmentStatus {
  confirmed('Confirmed'),
  pending('Deposit Pending'),
  completed('Completed'),
  cancelled('Cancelled');

  final String label;
  const AppointmentStatus(this.label);
}

/// Strongly typed client appointment data model.
class ClientAppointment {
  final String id;
  final String? artistId;
  final String artistName;
  final String artistAvatar;
  final String studioName;
  final String studioAddress;
  final String flashTitle;
  final String flashImageUrl;
  final DateTime dateTime;
  final String timeSlot;
  final String placement;
  final int depositAmount;
  final int totalPrice;
  final AppointmentStatus status;
  final bool isSilentAppointment;
  final String? notes;
  final bool isTouchUp;
  final String? parentAppointmentId;
  final String? healedPhotoUrl;

  int get balanceDue => totalPrice - depositAmount;

  /// Staged Location Disclosure Guard:
  /// Exact private studio street address and suite details are only unlocked when
  /// the booking deposit is confirmed AND the session is within 24 hours (up to 12h after start).
  bool isExactLocationUnlocked({DateTime? now}) {
    if (status == AppointmentStatus.completed) {
      return true;
    }
    if (status != AppointmentStatus.confirmed) {
      return false;
    }
    final currentTime = now ?? DateTime.now();
    final unlockTime = dateTime.subtract(const Duration(hours: 24));
    final expireTime = dateTime.add(const Duration(hours: 12));
    return !currentTime.isBefore(unlockTime) && !currentTime.isAfter(expireTime);
  }

  /// Returns the exact studio address if within the 24-hour confirmed window,
  /// or a privacy-safe redacted notice otherwise.
  String effectiveStudioAddress({DateTime? now}) {
    if (isExactLocationUnlocked(now: now)) {
      return studioAddress;
    }
    return 'Private Studio • Exact address unlocks 24h before session';
  }

  const ClientAppointment({
    required this.id,
    this.artistId,
    required this.artistName,
    required this.artistAvatar,
    required this.studioName,
    required this.studioAddress,
    required this.flashTitle,
    required this.flashImageUrl,
    required this.dateTime,
    required this.timeSlot,
    required this.placement,
    required this.depositAmount,
    required this.totalPrice,
    required this.status,
    this.isSilentAppointment = false,
    this.notes,
    this.isTouchUp = false,
    this.parentAppointmentId,
    this.healedPhotoUrl,
  });

  ClientAppointment copyWith({
    String? id,
    String? artistId,
    String? artistName,
    String? artistAvatar,
    String? studioName,
    String? studioAddress,
    String? flashTitle,
    String? flashImageUrl,
    DateTime? dateTime,
    String? timeSlot,
    String? placement,
    int? depositAmount,
    int? totalPrice,
    AppointmentStatus? status,
    bool? isSilentAppointment,
    String? notes,
    bool? isTouchUp,
    String? parentAppointmentId,
    String? healedPhotoUrl,
  }) {
    return ClientAppointment(
      id: id ?? this.id,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      artistAvatar: artistAvatar ?? this.artistAvatar,
      studioName: studioName ?? this.studioName,
      studioAddress: studioAddress ?? this.studioAddress,
      flashTitle: flashTitle ?? this.flashTitle,
      flashImageUrl: flashImageUrl ?? this.flashImageUrl,
      dateTime: dateTime ?? this.dateTime,
      timeSlot: timeSlot ?? this.timeSlot,
      placement: placement ?? this.placement,
      depositAmount: depositAmount ?? this.depositAmount,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      isSilentAppointment: isSilentAppointment ?? this.isSilentAppointment,
      notes: notes ?? this.notes,
      isTouchUp: isTouchUp ?? this.isTouchUp,
      parentAppointmentId: parentAppointmentId ?? this.parentAppointmentId,
      healedPhotoUrl: healedPhotoUrl ?? this.healedPhotoUrl,
    );
  }

  factory ClientAppointment.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawStatus = (map['status'] ?? 'confirmed').toString().toLowerCase();
    final parsedDate = map['scheduledDate'] is String
        ? DateTime.tryParse(map['scheduledDate'] as String)
        : (map['selectedDate'] is String
            ? DateTime.tryParse(map['selectedDate'] as String)
            : null);
    final effectiveDate = parsedDate ?? DateTime.now();

    AppointmentStatus status;
    if (rawStatus == 'completed') {
      status = AppointmentStatus.completed;
    } else if (rawStatus == 'cancelled' || rawStatus == 'canceled') {
      status = AppointmentStatus.cancelled;
    } else if (rawStatus == 'pending' || rawStatus == 'pending_payment') {
      status = AppointmentStatus.pending;
    } else {
      status = AppointmentStatus.confirmed;
    }

    final visitType = (map['visitType'] ?? '').toString().toLowerCase();
    final serviceType = (map['serviceType'] ?? '').toString();
    final isTouchUp = map['isTouchUp'] == true ||
        visitType.contains('touch') ||
        serviceType.toLowerCase().contains('touch-up') ||
        serviceType.toLowerCase().contains('touch up');

    final rawTitle = (map['flashTitle'] ?? map['serviceType'] ?? 'Tattoo Session')
        .toString()
        .trim();
    final rawTime = (map['time'] ?? map['selectedTimeSlot'] ?? '1:00 PM')
        .toString()
        .trim();
    final rawDuration = (map['duration'] ?? map['estimatedTime'] ?? '').toString().trim();
    final formattedSlot = rawTime.contains('(') || rawDuration.isEmpty
        ? rawTime
        : '$rawTime ($rawDuration)';

    return ClientAppointment(
      id: (docId != null && docId.isNotEmpty)
          ? docId
          : (map['id']?.toString() ?? 'APT-${DateTime.now().millisecondsSinceEpoch}'),
      artistId: map['artistId']?.toString(),
      artistName: (map['artistName'] ?? 'Artist').toString(),
      artistAvatar: (map['artistAvatar'] ?? '').toString(),
      studioName: (map['studioName'] ?? 'Studio').toString(),
      studioAddress: (map['studioAddress'] ?? map['studioLocation'] ?? '').toString(),
      flashTitle: rawTitle.isNotEmpty ? rawTitle : 'Tattoo Session',
      flashImageUrl: (map['artworkImageUrl'] ?? map['flashImageUrl'] ?? '').toString(),
      dateTime: effectiveDate,
      timeSlot: formattedSlot,
      placement: (map['placement'] ?? 'Forearm').toString(),
      depositAmount: (map['depositPaid'] as num?)?.toInt() ??
          (map['depositAmount'] as num?)?.toInt() ??
          0,
      totalPrice: (map['fullPrice'] as num?)?.toInt() ??
          (map['totalAmount'] as num?)?.toInt() ??
          0,
      status: status,
      isSilentAppointment: map['isSilentAppointment'] == true,
      notes: map['notes']?.toString() ?? map['clientNotes']?.toString(),
      isTouchUp: isTouchUp,
      parentAppointmentId: map['parentAppointmentId']?.toString(),
      healedPhotoUrl: map['healedPhotoUrl']?.toString(),
    );
  }

  /// Notifier incremented whenever appointments are added or hydrated so UI rebuilds.
  static final ValueNotifier<int> appointmentsUpdateNotifier = ValueNotifier<int>(0);

  /// Quarantined mock upcoming appointments preserved in [MockFixtures].
  static List<ClientAppointment> mockUpcoming =
      MockFixtures.createUpcomingAppointments();

  /// Quarantined mock past appointments preserved in [MockFixtures].
  static List<ClientAppointment> mockPast =
      MockFixtures.createPastAppointments();

  /// Live session appointments created during the active authenticated session.
  static final List<ClientAppointment> liveUpcoming = [];
  static final List<ClientAppointment> livePast = [];

  /// Active upcoming appointments for the current runtime mode.
  static List<ClientAppointment> get activeUpcoming =>
      MockDataConfig.isEnabled ? mockUpcoming : liveUpcoming;

  /// Active past appointments for the current runtime mode.
  static List<ClientAppointment> get activePast =>
      MockDataConfig.isEnabled ? mockPast : livePast;

  /// All active appointments (upcoming + past) for the current runtime mode.
  static List<ClientAppointment> get allActive => [
        ...activeUpcoming,
        ...activePast,
      ];

  /// Adds a new booked appointment to the active session list (and mock list when sandboxed).
  static void addUpcomingAppointment(ClientAppointment appointment) {
    final target = MockDataConfig.isEnabled ? mockUpcoming : liveUpcoming;
    target.removeWhere((a) => a.id == appointment.id);
    target.insert(0, appointment);
    appointmentsUpdateNotifier.value++;
  }

  /// Clears session-scoped appointments upon sign-out.
  static void clearSessionAppointments() {
    liveUpcoming.clear();
    livePast.clear();
    appointmentsUpdateNotifier.value++;
  }
}

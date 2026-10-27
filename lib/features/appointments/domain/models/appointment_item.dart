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
  });

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

  /// Adds a new booked appointment to the active session list (and mock list when sandboxed).
  static void addUpcomingAppointment(ClientAppointment appointment) {
    if (MockDataConfig.isEnabled) {
      mockUpcoming.insert(0, appointment);
    } else {
      liveUpcoming.insert(0, appointment);
    }
  }

  /// Clears session-scoped appointments upon sign-out.
  static void clearSessionAppointments() {
    liveUpcoming.clear();
    livePast.clear();
  }
}

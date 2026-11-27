import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/mock/artist_dashboard_fixtures.dart';
import '../core/mock/mock_data_config.dart';
import '../features/appointments/domain/models/appointment_item.dart';
import '../features/messages/domain/models/message_thread.dart';
import '../models/artist_dashboard/artist_books_schedule.dart';
import '../models/artist_dashboard/artist_dashboard_stats.dart';
import '../models/artist_dashboard/book_drop.dart';
import '../models/artist_dashboard/booking_request.dart';
import '../models/artist_dashboard/dashboard_appointment.dart';
import '../models/booking.dart';
import '../models/waitlist_entry.dart';
import '../services/booking_sync_service.dart';
import '../services/scheduling/booking_slot_profile.dart';
import 'artist_availability_calculator.dart';

/// Repository for the artist dashboard, calendar, books, waitlist, and earnings.
///
/// Quarantines all Figma/demo mock datasets strictly behind [MockDataConfig.isEnabled].
/// In live runtime mode (`MockDataConfig.isEnabled == false`), exposes live Firestore-synced
/// and session-scoped collections (defaulting to empty lists and zeroed metrics).
class ArtistDashboardRepository {
  static ArtistBooksSchedule _mockBooksSchedule =
      ArtistDashboardFixtures.createMockBooksSchedule();
  static ArtistBooksSchedule _liveBooksSchedule =
      ArtistDashboardFixtures.createDefaultLiveBooksSchedule();

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

  static bool _mockStripePayoutsReady = true;
  static bool _liveStripePayoutsReady = false;

  /// Whether the artist's Stripe Connect Express account has completed KYC
  /// and has both charges and payouts enabled. Required before opening books.
  static bool get stripePayoutsReady => MockDataConfig.isEnabled
      ? _mockStripePayoutsReady
      : _liveStripePayoutsReady;

  static set stripePayoutsReady(bool ready) {
    if (MockDataConfig.isEnabled) {
      _mockStripePayoutsReady = ready;
    } else {
      _liveStripePayoutsReady = ready;
    }
    notifyPendingRequestsChanged();
  }

  static void pauseInquiries() => isPaused = true;
  static void resumeInquiries() => isPaused = false;

  static BookDrop? _mockBookDrop = ArtistDashboardFixtures.createMockBookDrop();
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

  static List<CustomHold> _mockCustomHolds =
      ArtistDashboardFixtures.createMockCustomHolds();
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
    final bufferMins = booksSchedule.bufferDurationMinutes;
    final activeEntries = customHolds
        .where((h) => !now.isAfter(h.expiresAt))
        .map(
          (h) => ScheduleSlotEntry(
            dateKey: ArtistBooksSchedule.dateKey(h.date),
            timeSlot: h.timeSlot,
            durationMinutes: h.durationMinutes,
            bufferMinutes: bufferMins,
            holdId: h.id,
            expiresAt: h.expiresAt,
          ),
        )
        .toList();
    booksSchedule = booksSchedule.copyWith(heldSlots: activeEntries);
    final resolvedId =
        (artistId ?? BookingSyncService.resolveCurrentUid('')).trim();
    if (resolvedId.isNotEmpty) {
      BookingSyncService.syncHeldSlotsToCloud(
        activeEntries,
        artistId: resolvedId,
      );
    }
  }

  static bool isDateBlocked(DateTime date, {ArtistBooksSchedule? schedule}) =>
      (schedule ?? booksSchedule).isDateBlocked(date);

  static bool isDateForceOpened(
    DateTime date, {
    ArtistBooksSchedule? schedule,
  }) =>
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
    final resolvedId =
        (artistId ?? BookingSyncService.resolveCurrentUid('')).trim();
    if (resolvedId.isNotEmpty) {
      BookingSyncService.syncBooksScheduleToCloud(
        updated,
        artistId: resolvedId,
      );
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
    final nextOpen = Set<String>.from(booksSchedule.openOverrideDates)
      ..remove(key);
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

  static int parseDurationMinutes(String duration) =>
      ArtistAvailabilityCalculator.parseDurationMinutes(
        duration,
        fallbackSlotDurationMinutes: booksSchedule.slotDurationMinutes,
      );

  static Set<String> getOccupiedDateKeys({
    ArtistBooksSchedule? schedule,
    String? artistId,
    DateTime? now,
  }) =>
      ArtistAvailabilityCalculator.getOccupiedDateKeys(
        schedule: schedule ?? booksSchedule,
        repoSchedule: booksSchedule,
        calendarAppointments: calendarAppointments,
        customHolds: customHolds,
        artistId: artistId,
        now: now,
      );

  static bool isDateOccupied(
    DateTime date, {
    ArtistBooksSchedule? schedule,
    String? artistId,
    DateTime? now,
  }) =>
      ArtistAvailabilityCalculator.isDateOccupied(
        date: date,
        schedule: schedule ?? booksSchedule,
        repoSchedule: booksSchedule,
        calendarAppointments: calendarAppointments,
        customHolds: customHolds,
        artistId: artistId,
        now: now,
      );

  static int countBookedDaysInWeek(
    DateTime date, {
    ArtistBooksSchedule? schedule,
    String? artistId,
    DateTime? now,
  }) =>
      ArtistAvailabilityCalculator.countBookedDaysInWeek(
        date: date,
        schedule: schedule ?? booksSchedule,
        repoSchedule: booksSchedule,
        calendarAppointments: calendarAppointments,
        customHolds: customHolds,
        artistId: artistId,
        now: now,
      );

  static bool isClosedByWeeklyCap(
    DateTime date, {
    ArtistBooksSchedule? schedule,
    String? artistId,
    BookingMode? mode,
    DateTime? now,
  }) =>
      ArtistAvailabilityCalculator.isClosedByWeeklyCap(
        date: date,
        schedule: schedule ?? booksSchedule,
        repoSchedule: booksSchedule,
        calendarAppointments: calendarAppointments,
        customHolds: customHolds,
        mode: mode ?? bookingMode,
        isPaused: isPaused,
        artistId: artistId,
        now: now,
      );

  static bool hasActiveHoldForSlot({
    required DateTime date,
    required String timeSlot,
    ArtistBooksSchedule? schedule,
    DateTime? now,
    int? startMinutes,
    int? durationMinutes,
    int? bufferMinutes,
    String? ignoreHoldId,
  }) =>
      ArtistAvailabilityCalculator.hasActiveHoldForSlot(
        date: date,
        timeSlot: timeSlot,
        schedule: schedule ?? booksSchedule,
        repoSchedule: booksSchedule,
        customHolds: customHolds,
        now: now,
        startMinutes: startMinutes,
        durationMinutes: durationMinutes,
        bufferMinutes: bufferMinutes,
        ignoreHoldId: ignoreHoldId,
      );

  static bool isSlotBookable({
    required DateTime date,
    required String timeSlot,
    ArtistBooksSchedule? schedule,
    String? artistId,
    BookingMode? mode,
    DateTime? now,
    int? startMinutes,
    int? durationMinutes,
    int? bufferMinutes,
    String? ignoreHoldId,
    BookingSlotType slotType = BookingSlotType.flash,
  }) =>
      ArtistAvailabilityCalculator.isSlotBookable(
        date: date,
        timeSlot: timeSlot,
        schedule: schedule ?? booksSchedule,
        repoSchedule: booksSchedule,
        calendarAppointments: calendarAppointments,
        customHolds: customHolds,
        mode: mode ?? bookingMode,
        isPaused: isPaused,
        artistId: artistId,
        now: now,
        startMinutes: startMinutes,
        durationMinutes: durationMinutes,
        bufferMinutes: bufferMinutes,
        ignoreHoldId: ignoreHoldId,
        slotType: slotType,
      );

  static bool isDateBookable({
    required DateTime date,
    ArtistBooksSchedule? schedule,
    String? artistId,
    BookingMode? mode,
    DateTime? now,
    int? durationMinutes,
    BookingSlotType slotType = BookingSlotType.flash,
  }) =>
      ArtistAvailabilityCalculator.isDateBookable(
        date: date,
        schedule: schedule ?? booksSchedule,
        repoSchedule: booksSchedule,
        calendarAppointments: calendarAppointments,
        customHolds: customHolds,
        mode: mode ?? bookingMode,
        isPaused: isPaused,
        artistId: artistId,
        now: now,
        durationMinutes: durationMinutes,
        slotType: slotType,
      );

  static int getRemainingOpenMinutes(DateTime date) =>
      ArtistAvailabilityCalculator.getRemainingOpenMinutes(
        date: date,
        schedule: booksSchedule,
        calendarAppointments: calendarAppointments,
        appointmentsForDate: getAppointmentsForDate(date),
        customHolds: customHolds,
        bookingMode: bookingMode,
        currentBookDrop: currentBookDrop,
        isPaused: isPaused,
      );

  static DayCapacityStatus getDayCapacityStatus(DateTime date) =>
      ArtistAvailabilityCalculator.getDayCapacityStatus(
        date: date,
        schedule: booksSchedule,
        calendarAppointments: calendarAppointments,
        appointmentsForDate: getAppointmentsForDate(date),
        customHolds: customHolds,
        bookingMode: bookingMode,
        currentBookDrop: currentBookDrop,
        isPaused: isPaused,
      );

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
    final resolvedArtistId =
        entry.artistId.isNotEmpty && entry.artistId != 'artist_odd_maree'
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
      final resolvedArtistId =
          entry.artistId.isNotEmpty && entry.artistId != 'artist_odd_maree'
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
    final resolvedArtistId =
        BookingSyncService.resolveCurrentUid('artist_unknown');
    BookingSyncService.syncWaitlistToCloud(
      waitlistEntries,
      artistId: resolvedArtistId,
    );
  }

  /// Triggers exclusive early access to all waiting contacts on the waitlist.
  static void sendEarlyAccessToWaitlist({int hours = 24}) {
    final endsAt = DateTime.now().add(Duration(hours: hours));
    booksSchedule = booksSchedule.copyWith(
      isBooksOpen: true,
      isEarlyAccessOnly: true,
      earlyAccessEndsAt: endsAt,
      earlyAccessHours: hours,
    );

    waitlistEntries = waitlistEntries.map((e) {
      if (e.status == WaitlistStatus.waiting) {
        return e.copyWith(
          status: WaitlistStatus.earlyAccessSent,
          invitedAt: DateTime.now(),
        );
      }
      return e;
    }).toList();

    final resolvedArtistId =
        BookingSyncService.resolveCurrentUid('artist_unknown');
    BookingSyncService.syncBooksScheduleToCloud(
      booksSchedule,
      artistId: resolvedArtistId,
    );
    BookingSyncService.syncWaitlistToCloud(
      waitlistEntries,
      artistId: resolvedArtistId,
    );
  }

  /// Transitions books to completely open to the general public.
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

  /// Closes books.
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

  /// Computes live earnings from confirmed/completed appointments when running in live mode,
  /// or returns the quarantined mock earnings when [MockDataConfig.isEnabled] is true.
  static ArtistEarningsData get earningsData {
    if (MockDataConfig.isEnabled) {
      return ArtistDashboardFixtures.mockEarningsData;
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

  /// Active next appointment for the current runtime mode (`null` when live and no appointments exist).
  static DashboardAppointment? get activeNextAppointment {
    if (MockDataConfig.isEnabled) {
      return ArtistDashboardFixtures.mockNextAppointment;
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
      activeNextAppointment ?? ArtistDashboardFixtures.mockNextAppointment;

  static List<DashboardAppointment> _mockTodaySchedule =
      List.from(ArtistDashboardFixtures.defaultTodaySchedule);
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

  static List<BookingRequest> _mockPendingRequests =
      List.from(ArtistDashboardFixtures.defaultPendingRequests);
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
    newRequests: ArtistDashboardFixtures.defaultPendingRequests.length,
    pendingCount: ArtistDashboardFixtures.defaultPendingRequests.length,
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
    _mockPendingRequests =
        List.from(ArtistDashboardFixtures.defaultPendingRequests);
    _mockTodaySchedule = List.from(ArtistDashboardFixtures.defaultTodaySchedule);
    _mockWaitlistEntries = List.from(WaitlistEntry.mockWaitlistEntries);
    _mockCalendarAppointments =
        List.from(ArtistDashboardFixtures.defaultCalendarAppointments);
    _mockStats = ArtistDashboardStats(
      bookingsThisWeek: 12,
      newRequests: _mockPendingRequests.length,
      pendingCount: _mockPendingRequests.length,
    );
    _mockBooksSchedule = ArtistDashboardFixtures.createMockBooksSchedule();
    _mockStripePayoutsReady = true;
    _liveStripePayoutsReady = false;
    livePendingRequests = [];
    liveTodaySchedule = [];
    liveWaitlistEntries = [];
    liveCalendarAppointments = [];
    _liveStatsOverride = null;
    _liveBooksSchedule = ArtistDashboardFixtures.createDefaultLiveBooksSchedule();
    _mockBookingMode = BookingMode.alwaysOpen;
    _liveBookingMode = BookingMode.alwaysOpen;
    _mockIsPaused = false;
    _liveIsPaused = false;
    _mockBookDrop = ArtistDashboardFixtures.createMockBookDrop();
    _liveBookDrop = null;
    _mockCustomHolds = ArtistDashboardFixtures.createMockCustomHolds();
    _liveCustomHolds = [];
    BookingSyncService.resetSyncState();
    notifyPendingRequestsChanged();
  }

  /// Adds a newly submitted custom tattoo brief to the artist's pending requests queue.
  static void addPendingRequest(BookingRequest request) {
    final resolvedClientId =
        request.clientId ?? BookingSyncService.resolveCurrentUid();
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
      body:
          '${enrichedRequest.category} (${enrichedRequest.placement}) • Est. \$${enrichedRequest.estimatedPrice}',
      category: 'custom_request',
      appointmentId: enrichedRequest.id,
    );
  }

  static String _formatDisplayDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static ({String artistName, String artistAvatar, String studioName})
      _resolveArtistMessagingProfile({String? fallbackArtistName}) {
    final artistName = fallbackArtistName ??
        (MockDataConfig.isEnabled
            ? 'OddMaree'
            : BookingSyncService.resolveCurrentUserDisplayNameSync('Artist'));
    final artistAvatar = MockDataConfig.isEnabled
        ? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80'
        : BookingSyncService.resolveCurrentUserPhotoUrlSync();
    final studioName = booksSchedule.locationNote.isNotEmpty
        ? booksSchedule.locationNote
        : (MockDataConfig.isEnabled
            ? 'Obsidian Atelier'
            : (fallbackArtistName ?? 'Studio'));
    return (
      artistName: artistName,
      artistAvatar: artistAvatar,
      studioName: studioName,
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
    effectiveDate =
        DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day);

    // 2. Determine available time slot on that date
    String effectiveTimeSlot = timeSlot ?? request.preferredTimeSlot ?? '';
    final candidateSlots = booksSchedule.generateTimeSlots();
    if (effectiveTimeSlot.isEmpty) {
      final available = candidateSlots.firstWhere(
        (s) => !isTimeSlotBooked(date: effectiveDate, timeSlot: s.time),
        orElse: () =>
            const BookingTimeSlot(time: '1:00 PM', period: 'Afternoon'),
      );
      effectiveTimeSlot = available.time;
    }

    final effectivePrice = customPrice ?? request.estimatedPrice;
    final effectiveDeposit = customDeposit ?? request.deposit;
    final durationHrs = (booksSchedule.slotDurationMinutes / 60.0);
    final durationLabel = durationHrs == durationHrs.roundToDouble()
        ? '${durationHrs.toInt()} hrs'
        : '${durationHrs.toStringAsFixed(1)} hrs';
    final formattedDate = _formatDisplayDate(effectiveDate);

    // 3. Remove from pending requests and update stats
    final currentStats = stats;
    pendingRequests = pendingRequests.where((r) => r.id != request.id).toList();
    stats = ArtistDashboardStats(
      bookingsThisWeek: currentStats.bookingsThisWeek + 1,
      newRequests:
          currentStats.newRequests > 0 ? currentStats.newRequests - 1 : 0,
      pendingCount: pendingRequests.length,
    );
    notifyPendingRequestsChanged();

    // 4. Create & register Artist Calendar appointment
    final resolvedArtistId =
        request.artistId ?? BookingSyncService.resolveCurrentUid('artist_1');
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
      body:
          '${request.artistName} scheduled your ${request.category} session on $formattedDate at $effectiveTimeSlot.',
      category: 'booking_confirmed',
      appointmentId: calendarApt.id,
    );

    // 5. Create & register Client Upcoming appointment
    final profile =
        _resolveArtistMessagingProfile(fallbackArtistName: request.artistName);
    final clientApt = ClientAppointment(
      id: 'CUST-${request.id.hashCode.abs() % 90000 + 10000}',
      artistId: request.artistId,
      artistName: request.artistName,
      artistAvatar: profile.artistAvatar,
      studioName: profile.studioName,
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
      studioLocation: profile.studioName,
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
      text:
          'I accepted your custom tattoo brief for $formattedDate at $effectiveTimeSlot! Estimated total: \$$effectivePrice (\$$effectiveDeposit deposit).',
      timestamp: DateTime.now(),
      isFromArtist: true,
    );

    BookingSyncService.postToCanonicalThread(
      artistId: resolvedArtistId,
      clientId: resolvedClientId,
      clientName: request.clientName,
      clientAvatar: request.clientAvatar ?? '',
      artistName: request.artistName,
      artistAvatar: profile.artistAvatar,
      studioName: profile.studioName,
      flashTitleContext: 'Custom: ${request.category}',
      messages: [receiptMessage, followUpMessage],
      initiatedByArtist: true,
      fallbackThreadId: 'thread_custom_${request.id}',
    );

    return calendarApt;
  }

  /// Sends up to 3 proposed date/time options and a quote to the client's chat
  /// thread without locking all options off the artist's public calendar.
  ///
  /// Availability is re-verified live when the client selects one of the options
  /// via [confirmProposedTimeSlot].
  static MessageThread sendCustomTimeProposal(
    BookingRequest request, {
    required List<ProposedTimeOption> proposedSlots,
    int? durationMinutes,
    int? estimatedPrice,
    int? deposit,
  }) {
    final cappedSlots = proposedSlots.take(3).toList();
    final effectivePrice = estimatedPrice ?? request.estimatedPrice;
    final effectiveDeposit = deposit ?? request.deposit;
    final effectiveDuration =
        durationMinutes ?? booksSchedule.slotDurationMinutes;
    final resolvedArtistId =
        request.artistId ?? BookingSyncService.resolveCurrentUid('artist_1');
    final resolvedClientId = request.clientId ?? 'client_unknown';
    final profile =
        _resolveArtistMessagingProfile(fallbackArtistName: request.artistName);
    final now = DateTime.now();

    final summaryText = cappedSlots.length == 1
        ? '${request.artistName} proposed a session time for your ${request.category} request.'
        : '${request.artistName} proposed ${cappedSlots.length} session times for your ${request.category} request. Select one to confirm.';

    final proposalMessage = ChatMessage(
      id: 'proposal_${request.id}_${now.millisecondsSinceEpoch}',
      senderId: resolvedArtistId,
      senderName: request.artistName,
      text: summaryText,
      timestamp: now,
      isFromArtist: true,
      type: ChatMessageType.proposal,
      receiptAmount: effectiveDeposit.toDouble(),
      estimatedTotalPrice: effectivePrice,
      appointmentDurationMinutes: effectiveDuration,
      artistName: request.artistName,
      studioLocation: booksSchedule.locationNote.isNotEmpty
          ? booksSchedule.locationNote
          : profile.studioName,
      flashTitle: 'Custom: ${request.category}',
      placement: request.placement,
      flashImageUrl: request.sketchImageUrl.isNotEmpty
          ? request.sketchImageUrl
          : 'assets/images/flash_traditional_panther.jpg',
      requestId: request.id,
      proposedSlots: cappedSlots,
    );

    final thread = BookingSyncService.postToCanonicalThread(
      artistId: resolvedArtistId,
      clientId: resolvedClientId,
      clientName: request.clientName,
      clientAvatar: request.clientAvatar ?? '',
      artistName: request.artistName,
      artistAvatar: profile.artistAvatar,
      studioName: profile.studioName,
      flashTitleContext: 'Custom: ${request.category}',
      messages: [proposalMessage],
      initiatedByArtist: true,
      fallbackThreadId: 'thread_custom_${request.id}',
    );
    BookingSyncService.syncCustomRequestToCloud(
      request,
      clientId: resolvedClientId,
      artistId: resolvedArtistId,
      status: 'proposal_sent',
    );
    BookingSyncService.sendBookingNotification(
      senderId: resolvedArtistId,
      recipientId: resolvedClientId,
      recipientName: request.clientName,
      title: 'Session Times Proposed',
      body: summaryText,
      category: 'custom_request',
      appointmentId: request.id,
    );

    return thread;
  }

  /// Live-checks the artist's latest schedule when a client selects one of the
  /// artist's proposed times. Blocks double-booking if the slot was taken in the
  /// meantime; otherwise confirms the booking, updates the calendar, and posts
  /// a confirmation receipt message.
  static Future<
      ({
        bool confirmed,
        String? errorMessage,
        ArtistBooksSchedule? schedule,
        ChatMessage? updatedProposal,
        ChatMessage? receiptMessage,
      })> confirmProposedTimeSlot({
    required ChatMessage proposalMessage,
    required int optionIndex,
    MessageThread? thread,
    String? artistId,
    FirebaseFirestore? firestore,
  }) async {
    if (optionIndex < 0 || optionIndex >= proposalMessage.proposedSlots.length) {
      return (
        confirmed: false,
        errorMessage: 'Please select a valid proposed time.',
        schedule: null,
        updatedProposal: null,
        receiptMessage: null,
      );
    }

    final option = proposalMessage.proposedSlots[optionIndex];
    final effectiveArtistId = (artistId != null && artistId.trim().isNotEmpty)
        ? artistId.trim()
        : (thread != null && thread.artistId.trim().isNotEmpty
            ? thread.artistId.trim()
            : proposalMessage.senderId.trim());
    final durationMins = option.durationMinutes > 0
        ? option.durationMinutes
        : (proposalMessage.appointmentDurationMinutes ??
            booksSchedule.slotDurationMinutes);

    ArtistBooksSchedule? resolvedSchedule;
    if (firestore != null || !MockDataConfig.isEnabled) {
      final check = await BookingSyncService.verifySlotAvailableInCloud(
        artistId: effectiveArtistId,
        date: option.date,
        timeSlot: option.timeSlot,
        startMinutes: option.startMinutes,
        durationMinutes: durationMins,
        firestore: firestore,
      );
      resolvedSchedule = check.schedule;
      if (!check.available) {
        return (
          confirmed: false,
          errorMessage:
              'That time slot is no longer available — another client booked it. Please choose another proposed time or message the artist for new options.',
          schedule: resolvedSchedule,
          updatedProposal: null,
          receiptMessage: null,
        );
      }
    } else {
      final isOpen = isSlotBookable(
        date: option.date,
        timeSlot: option.timeSlot,
        startMinutes: option.startMinutes,
        durationMinutes: durationMins,
        bufferMinutes: booksSchedule.bufferDurationMinutes,
        artistId: effectiveArtistId.isNotEmpty ? effectiveArtistId : null,
      );
      if (!isOpen) {
        return (
          confirmed: false,
          errorMessage:
              'That time slot is no longer available — another client booked it. Please choose another proposed time or message the artist for new options.',
          schedule: booksSchedule,
          updatedProposal: null,
          receiptMessage: null,
        );
      }
    }

    final normalizedDate =
        DateTime(option.date.year, option.date.month, option.date.day);
    final formattedDate = _formatDisplayDate(normalizedDate);
    final durationHrs = durationMins / 60.0;
    final durationLabel = durationHrs == durationHrs.roundToDouble()
        ? '${durationHrs.toInt()} hrs'
        : '${durationHrs.toStringAsFixed(1)} hrs';
    final effectiveDeposit = (proposalMessage.receiptAmount ?? 80).round();
    final effectivePrice =
        proposalMessage.estimatedTotalPrice ?? (effectiveDeposit * 3);
    final effectiveArtistName =
        proposalMessage.artistName ?? thread?.artistName ?? 'Artist';
    final effectiveClientName = thread?.clientName ?? 'Client';
    final effectiveClientId =
        thread?.clientId ?? BookingSyncService.resolveCurrentUid();
    final effectiveStudio = proposalMessage.studioLocation?.isNotEmpty == true
        ? proposalMessage.studioLocation!
        : (thread?.studioName.isNotEmpty == true
            ? thread!.studioName
            : 'Studio');
    final serviceTitle = proposalMessage.flashTitle ??
        thread?.flashTitleContext ??
        'Custom Tattoo';
    final placement = proposalMessage.placement ?? 'Custom Placement';
    final now = DateTime.now();

    final aptId =
        'cal_proposal_${proposalMessage.requestId ?? proposalMessage.id}';
    final calendarApt = DashboardAppointment(
      id: aptId,
      clientId: effectiveClientId,
      artistId: effectiveArtistId.isNotEmpty ? effectiveArtistId : 'artist_1',
      clientName: effectiveClientName,
      clientAvatar: thread?.clientAvatar,
      serviceType: serviceTitle,
      duration: durationLabel,
      time: option.timeSlot,
      scheduledDate: normalizedDate,
      date: formattedDate,
      placement: placement,
      notes: 'Confirmed from artist proposed times.',
      depositPaid: effectiveDeposit,
      fullPrice: effectivePrice,
      artworkImageUrl: proposalMessage.flashImageUrl ?? '',
      visitType: 'Custom Tattoo',
      dotColor: const Color(0xFF22C55E),
    );
    addCalendarAppointment(calendarApt);
    if (firestore != null) {
      await BookingSyncService.syncAppointmentToCloud(
        calendarApt,
        clientId: effectiveClientId,
        artistId: effectiveArtistId,
        status: 'confirmed',
        firestore: firestore,
      );
    }

    if (proposalMessage.requestId != null &&
        proposalMessage.requestId!.isNotEmpty) {
      pendingRequests = pendingRequests
          .where((r) => r.id != proposalMessage.requestId)
          .toList();
    }

    final clientApt = ClientAppointment(
      id: 'PROP-${aptId.hashCode.abs() % 90000 + 10000}',
      artistId: effectiveArtistId,
      artistName: effectiveArtistName,
      artistAvatar: thread?.artistAvatar ?? '',
      studioName: thread?.studioName.isNotEmpty == true
          ? thread!.studioName
          : effectiveStudio,
      studioAddress: effectiveStudio,
      flashTitle: serviceTitle,
      flashImageUrl: proposalMessage.flashImageUrl ??
          'assets/images/flash_traditional_panther.jpg',
      dateTime: normalizedDate,
      timeSlot: '${option.timeSlot} ($durationLabel)',
      placement: placement,
      depositAmount: effectiveDeposit,
      totalPrice: effectivePrice,
      status: AppointmentStatus.confirmed,
    );
    ClientAppointment.addUpcomingAppointment(clientApt);

    final updatedProposal = proposalMessage.copyWith(
      selectedProposalIndex: optionIndex,
    );
    final receiptStart =
        ArtistBooksSchedule.parseSlotDateTime(normalizedDate, option.timeSlot) ??
            normalizedDate;
    final receiptMessage = ChatMessage(
      id: 'receipt_${proposalMessage.id}',
      senderId: effectiveClientId,
      senderName: effectiveClientName,
      text:
          'Session confirmed for $formattedDate at ${option.timeSlot}. Deposit: \$$effectiveDeposit.',
      timestamp: now,
      isFromArtist: false,
      type: ChatMessageType.receipt,
      receiptAmount: effectiveDeposit.toDouble(),
      appointmentDate: receiptStart,
      appointmentTimeSlot: option.timeSlot,
      appointmentDurationMinutes: durationMins,
      artistName: effectiveArtistName,
      studioLocation: effectiveStudio,
      flashTitle: serviceTitle,
      placement: placement,
      flashImageUrl: proposalMessage.flashImageUrl,
    );

    if (thread != null) {
      final idx = MessageThread.activeThreads.indexWhere(
        (t) => t.id == thread.id || t.mergedLegacyIds.contains(thread.id),
      );
      if (idx != -1) {
        final existing = MessageThread.activeThreads[idx];
        final updatedMessages = existing.messages
            .map((m) => m.id == proposalMessage.id ? updatedProposal : m)
            .toList()
          ..add(receiptMessage);
        final updatedThread = existing.copyWith(
          lastMessage: receiptMessage.text,
          lastMessageTime: now,
          clientUnreadCount: 0,
          artistUnreadCount: existing.artistUnreadCount + 1,
          clientLastReadAt: now,
          messages: updatedMessages,
        );
        MessageThread.activeThreads[idx] = updatedThread;
        MessageThread.unreadUpdateNotifier.value++;
        BookingSyncService.syncChatThreadToCloud(
          updatedThread,
          clientId: updatedThread.clientId,
          artistId: updatedThread.artistId,
          clientName: updatedThread.clientName,
          clientAvatar: updatedThread.clientAvatar,
          artistAvatar: updatedThread.artistAvatar,
          newMessagesForSubcollection: [receiptMessage],
          incrementRecipientFromArtist: false,
        );
      }
    }

    final effectiveBuffer =
        (resolvedSchedule ?? booksSchedule).bufferDurationMinutes;
    final updatedSchedule = resolvedSchedule?.copyWith(
      bookedSlots: [
        ...resolvedSchedule.bookedSlots,
        ScheduleSlotEntry(
          dateKey: ArtistBooksSchedule.dateKey(normalizedDate),
          timeSlot: option.timeSlot,
          startMinutes: option.startMinutes,
          durationMinutes: durationMins,
          bufferMinutes: effectiveBuffer,
        ),
      ],
    );

    return (
      confirmed: true,
      errorMessage: null,
      schedule: updatedSchedule,
      updatedProposal: updatedProposal,
      receiptMessage: receiptMessage,
    );
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
        newRequests:
            currentStats.newRequests > 0 ? currentStats.newRequests - 1 : 0,
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

  static List<DashboardAppointment> _mockCalendarAppointments =
      List.from(ArtistDashboardFixtures.defaultCalendarAppointments);
  static List<DashboardAppointment> liveCalendarAppointments = [];

  static List<DashboardAppointment> get calendarAppointments =>
      MockDataConfig.isEnabled
          ? _mockCalendarAppointments
          : liveCalendarAppointments;

  /// Active transaction history appointments for the Earnings screen.
  static List<DashboardAppointment> get historyAppointments {
    if (MockDataConfig.isEnabled) {
      return [
        ..._mockCalendarAppointments,
        ...ArtistDashboardFixtures.mockHistoryAppointments,
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

  /// Returns searchable Flash clients for the waitlist sheet.
  /// In live mode, derives known clients from the artist's real appointments and custom requests.
  static List<Map<String, String>> get searchableFlashClients {
    if (MockDataConfig.isEnabled) {
      return ArtistDashboardFixtures.mockFlashUsers;
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
        'handle':
            '@${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
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
      byKey.putIfAbsent(
        id,
        () => {
          'id': id,
          'name': name,
          'handle':
              '@${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          'avatar': '',
          'email': '',
          'phone': '',
        },
      );
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

  /// Checks if a time slot interval overlaps an existing booking for an artist on a given date.
  static bool isTimeSlotBooked({
    required DateTime date,
    required String timeSlot,
    ArtistBooksSchedule? schedule,
    String? artistId,
    int? startMinutes,
    int? durationMinutes,
    int? bufferMinutes,
  }) =>
      ArtistAvailabilityCalculator.isTimeSlotBooked(
        date: date,
        timeSlot: timeSlot,
        schedule: schedule ?? booksSchedule,
        repoSchedule: booksSchedule,
        calendarAppointments: calendarAppointments,
        artistId: artistId,
        startMinutes: startMinutes,
        durationMinutes: durationMinutes,
        bufferMinutes: bufferMinutes,
      );

  /// Adds a confirmed booking appointment to the artist's calendar schedule.
  static void addCalendarAppointment(DashboardAppointment appointment) {
    final resolvedClientId =
        appointment.clientId ?? BookingSyncService.resolveCurrentUid();
    final resolvedArtistId = appointment.artistId ??
        BookingSyncService.resolveCurrentUid('artist_unknown');
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
      (n) =>
          n.appointmentId == enrichedApt.id && n.category == 'booking_confirmed',
    );
    if (!alreadyNotified) {
      BookingSyncService.sendBookingNotification(
        senderId: resolvedClientId,
        recipientId: resolvedArtistId,
        recipientName: enrichedApt.clientName,
        title: 'Booking Confirmed!',
        body:
            '${enrichedApt.serviceType} scheduled for ${enrichedApt.date} at ${enrichedApt.time}.',
        category: 'booking_confirmed',
        appointmentId: enrichedApt.id,
      );
    }
  }

  static void _updateMatchingClientAppointment(
    DashboardAppointment appointment,
    ClientAppointment Function(ClientAppointment existing) transform,
  ) {
    final activeClientApts = ClientAppointment.activeUpcoming;
    for (int i = 0; i < activeClientApts.length; i++) {
      final clientApt = activeClientApts[i];
      if (clientApt.placement == appointment.placement ||
          clientApt.flashTitle.contains(appointment.serviceType)) {
        activeClientApts[i] = transform(clientApt);
        break;
      }
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
    final normalizedDate = DateTime(newDate.year, newDate.month, newDate.day);
    final formattedDate = _formatDisplayDate(normalizedDate);

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
      if (calIdx == -1) {
        calendarAppointments.add(updatedApt);
      }
    }

    // 3. Fallback if appointment was passed directly
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
    final resolvedUpdatedApt = updatedApt;
    _updateMatchingClientAppointment(
      resolvedUpdatedApt,
      (clientApt) => ClientAppointment(
        id: clientApt.id,
        artistName: clientApt.artistName,
        artistAvatar: clientApt.artistAvatar,
        studioName: clientApt.studioName,
        studioAddress: clientApt.studioAddress,
        flashTitle: clientApt.flashTitle,
        flashImageUrl: clientApt.flashImageUrl,
        dateTime: normalizedDate,
        timeSlot: '$newTimeSlot (${resolvedUpdatedApt.duration})',
        placement: clientApt.placement,
        depositAmount: clientApt.depositAmount,
        totalPrice: clientApt.totalPrice,
        status: AppointmentStatus.confirmed,
        isSilentAppointment: clientApt.isSilentAppointment,
        notes: clientApt.notes,
      ),
    );

    // 5. Post reschedule notice to active message threads
    final resolvedArtistId =
        updatedApt.artistId ?? BookingSyncService.resolveCurrentUid('artist_1');
    final profile = _resolveArtistMessagingProfile();
    final msg = ChatMessage(
      id: 'msg_resched_${DateTime.now().millisecondsSinceEpoch}',
      senderId: resolvedArtistId,
      senderName: profile.artistName,
      text:
          'Your appointment for ${updatedApt.serviceType} has been rescheduled to $formattedDate at $newTimeSlot. Your \$${updatedApt.depositPaid} deposit automatically transfers to the new slot.',
      timestamp: DateTime.now(),
      isFromArtist: true,
    );
    BookingSyncService.postToCanonicalThread(
      artistId: resolvedArtistId,
      clientId: updatedApt.clientId,
      clientName: updatedApt.clientName,
      clientAvatar: updatedApt.clientAvatar ?? '',
      artistName: profile.artistName,
      artistAvatar: profile.artistAvatar,
      studioName: profile.studioName,
      flashTitleContext: updatedApt.serviceType,
      messages: [msg],
      initiatedByArtist: true,
      fallbackThreadId: 'thread_resched_$appointmentId',
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

    _updateMatchingClientAppointment(
      removedApt,
      (clientApt) => ClientAppointment(
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
      ),
    );

    final resolvedArtistId =
        removedApt.artistId ?? BookingSyncService.resolveCurrentUid('artist_1');
    final profile = _resolveArtistMessagingProfile();
    final reasonNote = (reason != null && reason.trim().isNotEmpty)
        ? ' Reason: ${reason.trim()}.'
        : '';
    final msg = ChatMessage(
      id: 'msg_cancel_${DateTime.now().millisecondsSinceEpoch}',
      senderId: resolvedArtistId,
      senderName: profile.artistName,
      text:
          'Appointment for ${removedApt.serviceType} (${removedApt.date} at ${removedApt.time}) has been cancelled.$reasonNote',
      timestamp: DateTime.now(),
      isFromArtist: true,
    );
    BookingSyncService.postToCanonicalThread(
      artistId: resolvedArtistId,
      clientId: removedApt.clientId,
      clientName: removedApt.clientName,
      clientAvatar: removedApt.clientAvatar ?? '',
      artistName: profile.artistName,
      artistAvatar: profile.artistAvatar,
      studioName: profile.studioName,
      flashTitleContext: removedApt.serviceType,
      messages: [msg],
      initiatedByArtist: true,
      fallbackThreadId: 'thread_cancel_$appointmentId',
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
      body:
          'Your ${removedApt.serviceType} session on ${removedApt.date} at ${removedApt.time} was cancelled.',
      category: 'cancelled',
      appointmentId: removedApt.id,
    );

    return true;
  }
}

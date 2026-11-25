import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/models/artist_dashboard/artist_books_schedule.dart';
import 'package:flash_ink/models/artist_dashboard/book_drop.dart';
import 'package:flash_ink/models/artist_dashboard/dashboard_appointment.dart';
import 'package:flash_ink/repositories/artist_dashboard_repository.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_books_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_calendar_screen.dart';
import 'package:flash_ink/screens/booking/flash_booking_screen.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/services/booking_sync_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  });

  setUp(() {
    MockDataConfig.debugOverride = true;
    ArtistDashboardRepository.resetMockData();
  });

  tearDown(() {
    MockDataConfig.resetDebugOverride();
    AuthService.devMockUser = null;
  });

  Artist buildTestArtist({String id = 'artist_avail_1'}) {
    return Artist.fromMap({
      'id': id,
      'name': 'Ari Ink',
      'isBooksOpen': true,
      'location': 'Portland, OR',
      'minDeposit': 80,
    });
  }

  FlashArtwork buildTestFlash({String artistId = 'artist_avail_1'}) {
    return FlashArtwork(
      id: 'flash_avail_1',
      artistId: artistId,
      artistName: 'Ari Ink',
      title: 'Dagger Study',
      imageUrl: 'assets/images/flash_traditional_dagger.jpg',
      estimatedTime: '2.0 hrs',
      price: 250,
      deposit: 80,
    );
  }

  group('ArtistBooksSchedule & Repository Availability Rules', () {
    test('two-way overrides (blockedDates & openOverrideDates) control isWorkingDay', () {
      // Dec 1, 2026 is Tuesday (working); Dec 6, 2026 is Sunday (weekly off)
      final tue = DateTime(2026, 12, 1);
      final sun = DateTime(2026, 12, 6);

      final schedule = ArtistBooksSchedule(
        bookingWindowStart: DateTime(2026, 11, 1),
        bookingWindowEnd: DateTime(2027, 2, 1),
        workingDays: const {2, 3, 4, 5, 6},
        blockedDates: {'2026-12-01'},
        openOverrideDates: {'2026-12-06'},
      );

      expect(schedule.isWorkingDay(tue), isFalse);
      expect(schedule.isDateBlocked(tue), isTrue);
      expect(schedule.isWorkingDay(sun), isTrue);
      expect(schedule.isDateForceOpened(sun), isTrue);
    });

    test('toMap / fromMap round-trips rules and omits server-maintained bookedSlots', () {
      final original = ArtistBooksSchedule(
        bookingWindowStart: DateTime(2026, 11, 1),
        bookingWindowEnd: DateTime(2027, 2, 1),
        workingDays: const {1, 2, 3, 4, 5, 6, 7},
        blockedDates: const {'2026-12-24', '2026-12-25'},
        openOverrideDates: const {'2026-12-20'},
        minLeadTimeHours: 48,
        maxWorkingDaysPerWeek: 3,
        bookedSlots: [
          ScheduleSlotEntry(dateKey: '2026-12-10', timeSlot: '1:30 PM'),
        ],
        heldSlots: [
          ScheduleSlotEntry(
            dateKey: '2026-12-11',
            timeSlot: '3:00 PM',
            expiresAt: DateTime(2026, 12, 10, 12, 0),
          ),
        ],
      );

      final map = original.toMap();
      expect(map.containsKey('bookedSlots'), isFalse);
      expect(map['blockedDates'], ['2026-12-24', '2026-12-25']);
      expect(map['openOverrideDates'], ['2026-12-20']);
      expect(map['minLeadTimeHours'], 48);
      expect(map['maxWorkingDaysPerWeek'], 3);
      expect((map['heldSlots'] as List).length, 1);

      final restored = ArtistBooksSchedule.fromMap({
        ...map,
        'bookedSlots': [
          {'date': '2026-12-10', 'time': '1:30 PM'},
        ],
      });
      expect(restored.workingDays, {1, 2, 3, 4, 5, 6, 7});
      expect(restored.blockedDates, {'2026-12-24', '2026-12-25'});
      expect(restored.openOverrideDates, {'2026-12-20'});
      expect(restored.minLeadTimeHours, 48);
      expect(restored.maxWorkingDaysPerWeek, 3);
      expect(restored.bookedSlots.single.dateKey, '2026-12-10');
      expect(restored.heldSlots.single.timeSlot, '3:00 PM');

      final clearedCap = restored.copyWith(clearMaxWorkingDaysPerWeek: true);
      expect(clearedCap.maxWorkingDaysPerWeek, isNull);
    });

    test('bookingWindowStart and bookingWindowEnd restrict bookable dates unless force-opened', () {
      final fixedNow = DateTime(2026, 12, 1, 9, 0);
      ArtistDashboardRepository.calendarAppointments.clear();
      ArtistDashboardRepository.customHolds = [];
      ArtistDashboardRepository.booksSchedule = ArtistBooksSchedule(
        bookingWindowStart: DateTime(2026, 12, 5),
        bookingWindowEnd: DateTime(2026, 12, 12),
        workingDays: const {1, 2, 3, 4, 5, 6, 7},
        openOverrideDates: const {'2026-12-15'},
      );

      expect(
        ArtistDashboardRepository.isDateBookable(
          date: DateTime(2026, 12, 4),
          now: fixedNow,
        ),
        isFalse,
      );
      expect(
        ArtistDashboardRepository.isSlotBookable(
          date: DateTime(2026, 12, 4),
          timeSlot: '1:30 PM',
          now: fixedNow,
        ),
        isFalse,
      );
      expect(
        ArtistDashboardRepository.isDateBookable(
          date: DateTime(2026, 12, 5),
          now: fixedNow,
        ),
        isTrue,
      );
      expect(
        ArtistDashboardRepository.isDateBookable(
          date: DateTime(2026, 12, 12),
          now: fixedNow,
        ),
        isTrue,
      );
      expect(
        ArtistDashboardRepository.isDateBookable(
          date: DateTime(2026, 12, 13),
          now: fixedNow,
        ),
        isFalse,
      );
      expect(
        ArtistDashboardRepository.isDateBookable(
          date: DateTime(2026, 12, 15),
          now: fixedNow,
        ),
        isTrue,
      );

      // When hasBookingWindow is false (Always Open default), any future working day is bookable
      ArtistDashboardRepository.booksSchedule =
          ArtistDashboardRepository.booksSchedule.copyWith(
        hasBookingWindow: false,
      );
      expect(
        ArtistDashboardRepository.isDateBookable(
          date: DateTime(2026, 12, 4),
          now: fixedNow,
        ),
        isTrue,
      );
      expect(
        ArtistDashboardRepository.isDateBookable(
          date: DateTime(2027, 6, 15),
          now: fixedNow,
        ),
        isTrue,
      );
    });

    test('empty-day minimum lead time blocks empty early days but keeps already-booked days open', () {
      // Fixed clock: Tue Dec 1, 2026 at 2:00 PM; 24h cutoff = Wed Dec 2, 2026 2:00 PM
      final fixedNow = DateTime(2026, 12, 1, 14, 0);
      final tueDec1 = DateTime(2026, 12, 1);
      final wedDec2 = DateTime(2026, 12, 2);

      ArtistDashboardRepository.calendarAppointments.clear();
      ArtistDashboardRepository.customHolds = [];
      ArtistDashboardRepository.booksSchedule = ArtistBooksSchedule(
        bookingWindowStart: DateTime(2026, 11, 1),
        bookingWindowEnd: DateTime(2027, 2, 1),
        workingDays: const {1, 2, 3, 4, 5, 6, 7},
        minLeadTimeHours: 24,
      );

      // Empty today: all slots before cutoff -> unbookable
      expect(
        ArtistDashboardRepository.isDateBookable(date: tueDec1, now: fixedNow),
        isFalse,
      );

      // Empty tomorrow (Dec 2): 11:00 AM is < 2:00 PM cutoff, 3:00 PM >= cutoff
      expect(
        ArtistDashboardRepository.isDateBookable(date: wedDec2, now: fixedNow),
        isTrue,
      );
      expect(
        ArtistDashboardRepository.isSlotBookable(
          date: wedDec2,
          timeSlot: '11:00 AM',
          now: fixedNow,
        ),
        isFalse,
      );
      expect(
        ArtistDashboardRepository.isSlotBookable(
          date: wedDec2,
          timeSlot: '3:00 PM',
          now: fixedNow,
        ),
        isTrue,
      );

      // Add a confirmed appointment on Wed Dec 2 at 5:00 PM -> day is no longer empty,
      // so remaining future morning slot 11:00 AM unlocks for client booking!
      ArtistDashboardRepository.calendarAppointments
        ..clear()
        ..add(
          DashboardAppointment.fromMap({
            'clientName': 'Existing Client',
            'serviceType': 'Flash Session',
            'duration': '2 hrs',
            'time': '5:00 PM',
            'scheduledDate': DateTime(2026, 12, 2).toIso8601String(),
          }, 'apt_dec2'),
        );
      expect(
        ArtistDashboardRepository.isSlotBookable(
          date: wedDec2,
          timeSlot: '11:00 AM',
          now: fixedNow,
        ),
        isTrue,
      );
    });

    test('Sun-Sat weekly cap closes unbooked days once reached while keeping booked/held days open', () {
      // Sun Dec 6 – Sat Dec 12, 2026; Sun Dec 13 is next week
      final fixedNow = DateTime(2026, 12, 1, 9, 0);
      final tueDec8 = DateTime(2026, 12, 8);
      final thuDec10 = DateTime(2026, 12, 10);
      final friDec11 = DateTime(2026, 12, 11);
      final sunDec13 = DateTime(2026, 12, 13);

      ArtistDashboardRepository.calendarAppointments
        ..clear()
        ..add(
          DashboardAppointment.fromMap({
            'clientName': 'Booker One',
            'serviceType': 'Custom Tattoo',
            'duration': '2 hrs',
            'time': '2:00 PM',
            'scheduledDate': tueDec8.toIso8601String(),
          }, 'apt_cap_1'),
        );
      ArtistDashboardRepository.customHolds = [
        CustomHold(
          id: 'hold_cap_1',
          requestId: 'req_cap_1',
          clientName: 'Hold Client',
          date: thuDec10,
          timeSlot: '3:00 PM',
          estimatedPrice: 300,
          deposit: 80,
          createdAt: fixedNow,
          expiresAt: fixedNow.add(const Duration(hours: 24)),
        ),
      ];
      ArtistDashboardRepository.booksSchedule = ArtistBooksSchedule(
        bookingWindowStart: DateTime(2026, 11, 1),
        bookingWindowEnd: DateTime(2027, 2, 1),
        workingDays: const {1, 2, 3, 4, 5, 6, 7},
        maxWorkingDaysPerWeek: 2,
      );

      expect(
        ArtistDashboardRepository.countBookedDaysInWeek(tueDec8, now: fixedNow),
        2,
      );
      // Unbooked Fri Dec 11 in same Sun-Sat week auto-closes
      expect(
        ArtistDashboardRepository.isClosedByWeeklyCap(friDec11, now: fixedNow),
        isTrue,
      );
      expect(
        ArtistDashboardRepository.isDateBookable(date: friDec11, now: fixedNow),
        isFalse,
      );
      expect(
        ArtistDashboardRepository.getDayCapacityStatus(friDec11),
        DayCapacityStatus.closed,
      );

      // Remaining open slots on booked Tue Dec 8 & held Thu Dec 10 stay open
      expect(
        ArtistDashboardRepository.isClosedByWeeklyCap(tueDec8, now: fixedNow),
        isFalse,
      );
      expect(
        ArtistDashboardRepository.isSlotBookable(
          date: tueDec8,
          timeSlot: '11:00 AM',
          now: fixedNow,
        ),
        isTrue,
      );
      expect(
        ArtistDashboardRepository.isSlotBookable(
          date: thuDec10,
          timeSlot: '11:00 AM',
          now: fixedNow,
        ),
        isTrue,
      );

      // Next Sun-Sat week (Sun Dec 13) starts fresh with 0 booked days
      expect(
        ArtistDashboardRepository.countBookedDaysInWeek(sunDec13, now: fixedNow),
        0,
      );
      expect(
        ArtistDashboardRepository.isDateBookable(date: sunDec13, now: fixedNow),
        isTrue,
      );

      // Releasing the hold re-opens Fri Dec 11 immediately
      ArtistDashboardRepository.releaseCustomHold('hold_cap_1');
      expect(
        ArtistDashboardRepository.isDateBookable(date: friDec11, now: fixedNow),
        isTrue,
      );

      // In Book Drops mode, weekly cap stays independent and does not block days
      ArtistDashboardRepository.addCustomHold(
        CustomHold(
          id: 'hold_cap_2',
          requestId: 'req_cap_2',
          clientName: 'Hold Client',
          date: thuDec10,
          timeSlot: '3:00 PM',
          estimatedPrice: 300,
          deposit: 80,
          createdAt: fixedNow,
          expiresAt: fixedNow.add(const Duration(hours: 24)),
        ),
      );
      ArtistDashboardRepository.bookingMode = BookingMode.drops;
      expect(
        ArtistDashboardRepository.isClosedByWeeklyCap(friDec11, now: fixedNow),
        isFalse,
      );
    });

    test('FakeFirebaseFirestore sync & live FlashBookingScreen enforcement isolate remote schedule', () async {
      MockDataConfig.debugOverride = false;
      final fakeDb = FakeFirebaseFirestore();
      final artist = buildTestArtist(id: 'artist_remote_1');

      // Target a clear future Sun-Sat week starting next Sunday + 14 days
      final now = DateTime.now();
      final currentSun = ArtistBooksSchedule.weekStartSunday(now);
      final targetTue = DateTime(currentSun.year, currentSun.month, currentSun.day + 16);
      final targetWed = DateTime(currentSun.year, currentSun.month, currentSun.day + 17);
      final targetThu = DateTime(currentSun.year, currentSun.month, currentSun.day + 18);

      final remoteSchedule = ArtistBooksSchedule(
        bookingWindowStart: DateTime(now.year, now.month, 1),
        bookingWindowEnd: DateTime(now.year, now.month + 3, 1),
        workingDays: const {2, 3, 4, 5, 6},
        blockedDates: {ArtistBooksSchedule.dateKey(targetWed)},
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 19, minute: 0),
        minLeadTimeHours: 0,
        maxWorkingDaysPerWeek: 1,
        heldSlots: const [],
      );
      await BookingSyncService.syncBooksScheduleToCloud(
        remoteSchedule,
        artistId: artist.id,
        firestore: fakeDb,
      );
      await BookingSyncService.syncHeldSlotsToCloud(
        [
          ScheduleSlotEntry(
            dateKey: ArtistBooksSchedule.dateKey(targetTue),
            timeSlot: '5:00 PM',
            expiresAt: now.add(const Duration(hours: 24)),
          ),
        ],
        artistId: artist.id,
        firestore: fakeDb,
      );
      // Simulate server Cloud Function writing anonymized bookedSlots (legacy {date, time} format)
      await fakeDb.collection('artist_schedules').doc(artist.id).set({
        'bookedSlots': [
          {'date': ArtistBooksSchedule.dateKey(targetTue), 'time': '1:00 PM'},
        ],
      }, SetOptions(merge: true));

      final fetched = await BookingSyncService.fetchArtistScheduleFromCloud(
        artist.id,
        firestore: fakeDb,
      );
      expect(fetched, isNotNull);
      expect(fetched!.blockedDates, {ArtistBooksSchedule.dateKey(targetWed)});
      expect(fetched.bookedSlots.single.timeSlot, '1:00 PM');
      expect(fetched.heldSlots.single.timeSlot, '5:00 PM');

      // Remote schedule has targetTue booked/held and cap=1, so targetThu (same week) is cap-closed
      expect(
        ArtistDashboardRepository.isDateBookable(
          date: targetTue,
          schedule: fetched,
          artistId: artist.id,
          now: now,
        ),
        isTrue,
      );
      expect(
        ArtistDashboardRepository.isDateBookable(
          date: targetWed,
          schedule: fetched,
          artistId: artist.id,
          now: now,
        ),
        isFalse,
      );
      expect(
        ArtistDashboardRepository.isDateBookable(
          date: targetThu,
          schedule: fetched,
          artistId: artist.id,
          now: now,
        ),
        isFalse,
      );
      expect(
        ArtistDashboardRepository.isSlotBookable(
          date: targetTue,
          timeSlot: '1:00 PM',
          schedule: fetched,
          artistId: artist.id,
          now: now,
        ),
        isFalse,
      );
      expect(
        ArtistDashboardRepository.isSlotBookable(
          date: targetTue,
          timeSlot: '5:00 PM',
          schedule: fetched,
          artistId: artist.id,
          now: now,
        ),
        isFalse,
      );
      expect(
        ArtistDashboardRepository.isSlotBookable(
          date: targetTue,
          timeSlot: '10:00 AM',
          schedule: fetched,
          artistId: artist.id,
          now: now,
        ),
        isTrue,
      );

      // Verify isolated schedule can differ from local repository schedule without clobbering it
      ArtistDashboardRepository.booksSchedule = ArtistBooksSchedule(
        bookingWindowStart: DateTime(2026, 11, 1),
        bookingWindowEnd: DateTime(2027, 2, 1),
        workingDays: const {1, 2, 3, 4, 5, 6, 7},
      );
      expect(ArtistDashboardRepository.booksSchedule.maxWorkingDaysPerWeek, isNull);
    });
  });

  group('FlashBookingScreen Live Schedule Hydration Widget Test', () {
    testWidgets('loads remote artist schedule from Firestore and shows Booked / Held slots', (tester) async {
      MockDataConfig.debugOverride = false;
      final fakeDb = FakeFirebaseFirestore();
      final artist = buildTestArtist(id: 'artist_remote_ui');
      final flash = buildTestFlash(artistId: artist.id);

      final now = DateTime.now();
      final targetDate = DateTime(now.year, now.month, now.day + 3);
      final targetKey = ArtistBooksSchedule.dateKey(targetDate);

      await fakeDb.collection('artist_schedules').doc(artist.id).set({
        'isBooksOpen': true,
        'bookingWindowStart': DateTime(now.year, now.month, 1).toIso8601String(),
        'bookingWindowEnd': DateTime(now.year, now.month + 3, 1).toIso8601String(),
        'workingDays': [targetDate.weekday],
        'startHour': 10,
        'endHour': 19,
        'bookedSlots': [
          {'date': targetKey, 'time': '1:00 PM'},
        ],
        'heldSlots': [
          {
            'date': targetKey,
            'time': '5:00 PM',
            'expiresAt': now.add(const Duration(hours: 20)).toIso8601String(),
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: FlashBookingScreen(
            flash: flash,
            artist: artist,
            firestore: fakeDb,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1:00 PM (Booked)'), findsOneWidget);
      expect(find.text('4:00 PM (Held)'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
    });

    testWidgets('hydrates remote artist schedule using flash.artistId when widget.artist is null', (tester) async {
      MockDataConfig.debugOverride = false;
      final fakeDb = FakeFirebaseFirestore();
      const artistId = 'artist_flash_only_1';
      final flash = buildTestFlash(artistId: artistId);

      final now = DateTime.now();
      final targetDate = DateTime(now.year, now.month, now.day + 2);
      final targetKey = ArtistBooksSchedule.dateKey(targetDate);

      await fakeDb.collection('artist_schedules').doc(artistId).set({
        'isBooksOpen': true,
        'bookingWindowStart': DateTime(now.year, now.month, 1).toIso8601String(),
        'bookingWindowEnd': DateTime(now.year, now.month + 3, 1).toIso8601String(),
        'workingDays': [targetDate.weekday],
        'startHour': 10,
        'endHour': 19,
        'bookedSlots': [
          {'date': targetKey, 'time': '2:00 PM'},
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: FlashBookingScreen(
            flash: flash,
            artist: null,
            firestore: fakeDb,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2:00 PM (Booked)'), findsOneWidget);
    });

    testWidgets('pre-payment double-booking check rejects slot booked concurrently in Firestore', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      MockDataConfig.debugOverride = true;
      final fakeDb = FakeFirebaseFirestore();
      final artist = buildTestArtist(id: 'artist_race_1');
      final flash = buildTestFlash(artistId: artist.id);

      final now = DateTime.now();
      final targetDate = DateTime(now.year, now.month, now.day + 2);
      final targetKey = ArtistBooksSchedule.dateKey(targetDate);

      await fakeDb.collection('artist_schedules').doc(artist.id).set({
        'isBooksOpen': true,
        'bookingWindowStart': DateTime(now.year, now.month, 1).toIso8601String(),
        'bookingWindowEnd': DateTime(now.year, now.month + 3, 1).toIso8601String(),
        'workingDays': [targetDate.weekday],
        'startHour': 10,
        'endHour': 19,
        'bookedSlots': [],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: FlashBookingScreen(
            flash: flash,
            artist: artist,
            firestore: fakeDb,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Explicitly select 10:00 AM, then advance Step 1 -> Step 2 -> Step 3
      await tester.tap(find.text('10:00 AM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to Payment'));
      await tester.pumpAndSettle();

      // Simulate another collector claiming 10:00 AM before this checkout completes
      await fakeDb.collection('bookings').doc('concurrent_booking_1').set({
        'artistId': artist.id,
        'clientId': 'other_client',
        'selectedDate': targetDate.toIso8601String(),
        'selectedTimeSlot': '10:00 AM',
        'status': 'pending',
      });
      await fakeDb.collection('artist_schedules').doc(artist.id).set({
        'bookedSlots': [
          {'date': targetKey, 'time': '10:00 AM'},
        ],
      }, SetOptions(merge: true));

      await tester.tap(find.text('Pay \$80 Deposit & Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Flash Claimed & Booked!'), findsNothing);
      expect(find.text('SELECT DATE'), findsOneWidget);
      expect(find.text('10:00 AM (Booked)'), findsOneWidget);
      expect(
        find.text('That time slot was just booked. Please select another available time.'),
        findsOneWidget,
      );
    });
  });

  group('ArtistBooksScreen Open All Days, Shortcut & Availability Rules UI', () {
    testWidgets('Open All Days toggle selects all 7 days, restores prior selection, and auto-syncs on manual tap', (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Start with Mon & Wed only ({1, 3})
      ArtistDashboardRepository.booksSchedule = ArtistBooksSchedule(
        bookingWindowStart: DateTime(2026, 11, 1),
        bookingWindowEnd: DateTime(2027, 2, 1),
        workingDays: const {1, 3},
        blockedDates: const {'2026-12-25'},
        isEarlyAccessOnly: true,
        earlyAccessHours: 48,
      );

      bool calendarNavigated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ArtistBooksScreen(
            artist: buildTestArtist(),
            onNavigateToCalendar: () => calendarNavigated = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle Open All Days ON -> all 7 days open
      await tester.ensureVisible(find.byKey(const Key('open_all_days_switch')));
      await tester.tap(find.byKey(const Key('open_all_days_switch')));
      await tester.pumpAndSettle();
      expect(find.text('All 7 days open — block specific dates in Calendar'), findsOneWidget);

      // Toggle Open All Days OFF -> restores prior {1, 3}
      await tester.tap(find.byKey(const Key('open_all_days_switch')));
      await tester.pumpAndSettle();
      expect(find.text('Set recurring weekdays for client bookings'), findsOneWidget);

      // Toggle ON again, then tap Sun (day 7) off -> switch flips back OFF
      await tester.tap(find.byKey(const Key('open_all_days_switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('working_day_7')));
      await tester.pumpAndSettle();
      expect(find.text('Set recurring weekdays for client bookings'), findsOneWidget);

      // Tap Sun (day 7) back on -> switch flips back ON ({1..7})
      await tester.tap(find.byKey(const Key('working_day_7')));
      await tester.pumpAndSettle();
      expect(find.text('All 7 days open — block specific dates in Calendar'), findsOneWidget);

      // Tap Calendar shortcut
      await tester.ensureVisible(find.byKey(const Key('books_manage_days_off_link')));
      await tester.tap(find.byKey(const Key('books_manage_days_off_link')));
      await tester.pumpAndSettle();
      expect(calendarNavigated, isTrue);

      // Configure 48h lead time and 3d weekly cap, then save
      await tester.ensureVisible(find.byKey(const Key('lead_time_chip_48')));
      await tester.tap(find.byKey(const Key('lead_time_chip_48')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('weekly_cap_chip_3')));
      await tester.tap(find.byKey(const Key('weekly_cap_chip_3')));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('save_books_schedule_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save_books_schedule_button')));
      await tester.pumpAndSettle();

      final saved = ArtistDashboardRepository.booksSchedule;
      expect(saved.workingDays, {1, 2, 3, 4, 5, 6, 7});
      expect(saved.minLeadTimeHours, 48);
      expect(saved.maxWorkingDaysPerWeek, 3);
      // Preserves overrides and early-access flags instead of clobbering
      expect(saved.blockedDates, {'2026-12-25'});
      expect(saved.isEarlyAccessOnly, isTrue);
      expect(saved.earlyAccessHours, 48);

      // Switch back to No Limit and None, save again
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 300));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('lead_time_chip_0')));
      await tester.tap(find.byKey(const Key('lead_time_chip_0')));
      await tester.ensureVisible(find.byKey(const Key('weekly_cap_chip_none')));
      await tester.tap(find.byKey(const Key('weekly_cap_chip_none')));
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('save_books_schedule_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save_books_schedule_button')));
      await tester.pumpAndSettle();

      expect(ArtistDashboardRepository.booksSchedule.minLeadTimeHours, 0);
      expect(ArtistDashboardRepository.booksSchedule.maxWorkingDaysPerWeek, isNull);
    });
  });

  group('ArtistCalendarScreen Two-Way Overrides & Multi-Date Time Off Sheet', () {
    testWidgets('Date Range block, Tap Dates force-open on off-weekday, Clear All Blocked, and hold conflict warning', (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ArtistDashboardRepository.calendarAppointments.clear();
      ArtistDashboardRepository.customHolds = [
        CustomHold(
          id: 'hold_conflict_1',
          requestId: 'req_conflict_1',
          clientName: 'Maya',
          date: DateTime(2026, 12, 16),
          timeSlot: '2:00 PM',
          estimatedPrice: 280,
          deposit: 80,
          createdAt: DateTime(2026, 12, 10, 10, 0),
          expiresAt: DateTime.now().add(const Duration(hours: 20)),
        ),
      ];
      ArtistDashboardRepository.booksSchedule = ArtistBooksSchedule(
        bookingWindowStart: DateTime(2026, 11, 1),
        bookingWindowEnd: DateTime(2027, 2, 1),
        workingDays: const {2, 3, 4, 5, 6}, // Sun (7) & Mon (1) off
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ArtistCalendarScreen(
            artist: buildTestArtist(),
            initialDate: DateTime(2026, 12, 13), // Sunday (weekly off)
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Single-day view of Sunday Dec 13 shows Weekly Off Day + Open This Date CTA
      expect(find.text('Weekly Off Day'), findsOneWidget);

      // Open Manage Time Off sheet
      await tester.tap(find.byKey(const Key('calendar_manage_time_off_button')));
      await tester.pumpAndSettle();

      // Switch to Date Range mode and block Dec 22..Dec 24
      await tester.tap(find.byKey(const Key('time_off_mode_range')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('time_off_picker_day_22')));
      await tester.tap(find.byKey(const Key('time_off_picker_day_24')));
      await tester.pumpAndSettle();
      expect(find.text('3 dates selected'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('time_off_block_selected_button')));
      await tester.tap(find.byKey(const Key('time_off_block_selected_button')));
      await tester.pumpAndSettle();

      expect(
        ArtistDashboardRepository.booksSchedule.blockedDates,
        {'2026-12-22', '2026-12-23', '2026-12-24'},
      );

      // Re-open sheet, tap Sun Dec 13 in Tap Dates mode, and force-open it
      await tester.tap(find.byKey(const Key('calendar_manage_time_off_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('time_off_picker_day_13')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('time_off_open_selected_button')));
      await tester.tap(find.byKey(const Key('time_off_open_selected_button')));
      await tester.pumpAndSettle();

      expect(
        ArtistDashboardRepository.booksSchedule.isWorkingDay(DateTime(2026, 12, 13)),
        isTrue,
      );
      expect(find.text('Opened for Bookings (Override)'), findsOneWidget);

      // Re-open sheet and Clear All Blocked -> clears blockedDates while keeping openOverrideDates
      await tester.tap(find.byKey(const Key('calendar_manage_time_off_button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('time_off_clear_all_blocked_button')));
      await tester.tap(find.byKey(const Key('time_off_clear_all_blocked_button')));
      await tester.pumpAndSettle();

      expect(ArtistDashboardRepository.booksSchedule.blockedDates, isEmpty);
      expect(
        ArtistDashboardRepository.booksSchedule.openOverrideDates,
        {'2026-12-13'},
      );

      // Dismiss sheet, select Dec 16 (has active 24h CustomHold) & tap block -> warns about hold
      await tester.tap(find.byKey(const Key('time_off_close_button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('calendar_day_16')));
      await tester.tap(find.byKey(const Key('calendar_day_16')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('calendar_toggle_time_off_button')));
      await tester.tap(find.byKey(const Key('calendar_toggle_time_off_button')));
      await tester.pumpAndSettle();
      expect(find.text('Existing Bookings on Date'), findsOneWidget);
      expect(find.textContaining('1 active 24h hold'), findsOneWidget);

      await tester.tap(find.text('Block Anyway'));
      await tester.pumpAndSettle();

      expect(
        ArtistDashboardRepository.isDateBlocked(DateTime(2026, 12, 16)),
        isTrue,
      );
      // Hold itself stays intact
      expect(ArtistDashboardRepository.customHolds.length, 1);
    });
  });
}

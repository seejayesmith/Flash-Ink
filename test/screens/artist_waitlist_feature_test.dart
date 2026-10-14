import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';
import 'package:flash_ink/models/waitlist_entry.dart';
import 'package:flash_ink/screens/artist_dashboard/artist_waitlist_screen.dart';
import 'package:flash_ink/screens/artist_dashboard/books_open_options_modal.dart';
import 'package:flash_ink/screens/artist_dashboard/early_access_outreach_sheet.dart';
import 'package:flash_ink/features/messages/presentation/widgets/vip_waitlist_invitation_card.dart';

void main() {
  group('WaitlistEntry Domain Model Tests', () {
    test('Correctly serializes to and from Map', () {
      final now = DateTime(2026, 10, 6, 12, 0);
      final entry = WaitlistEntry(
        id: 'test_wl_1',
        clientName: 'Sarah Connors',
        clientPhone: '(555) 999-0000',
        clientEmail: 'sarah@example.com',
        flashUserId: 'user_sarah_1',
        relationshipTag: 'Friends & Family',
        designType: 'Custom',
        conceptDescription: 'Cyberpunk mechanical floral sleeve piece',
        placement: 'Forearm',
        budget: 450,
        availabilityPreference: 'Weekends',
        status: WaitlistStatus.waiting,
        createdAt: now,
      );

      final map = entry.toMap();
      expect(map['id'], 'test_wl_1');
      expect(map['clientName'], 'Sarah Connors');
      expect(map['budget'], 450);
      expect(map['status'], 'waiting');

      final reconstructed = WaitlistEntry.fromMap(map);
      expect(reconstructed.id, entry.id);
      expect(reconstructed.clientName, entry.clientName);
      expect(reconstructed.clientPhone, entry.clientPhone);
      expect(reconstructed.budget, 450);
      expect(reconstructed.isRegisteredFlashUser, isTrue);
      expect(reconstructed.status, WaitlistStatus.waiting);
    });

    test('copyWith updates specified fields only', () {
      final entry = WaitlistEntry(
        id: 'test_wl_2',
        clientName: 'Uncle Bob',
        conceptDescription: 'Classic sailor tattoo',
        createdAt: DateTime.now(),
      );

      final updated = entry.copyWith(
        status: WaitlistStatus.booked,
        budget: 300,
      );

      expect(updated.id, 'test_wl_2');
      expect(updated.clientName, 'Uncle Bob');
      expect(updated.status, WaitlistStatus.booked);
      expect(updated.budget, 300);
      expect(updated.isBooked, isTrue);
    });
  });

  group('ArtistDashboardRepository Waitlist Management', () {
    setUp(() {
      ArtistDashboardRepository.waitlistEntries = List.from(WaitlistEntry.mockWaitlistEntries);
      ArtistDashboardRepository.closeBooks();
    });

    test('addWaitlistEntry prepends entry to repository list', () {
      final initialCount = ArtistDashboardRepository.waitlistEntries.length;
      final newEntry = WaitlistEntry(
        id: 'new_entry_99',
        clientName: 'New Client',
        conceptDescription: 'Small star on wrist',
        createdAt: DateTime.now(),
      );

      ArtistDashboardRepository.addWaitlistEntry(newEntry);
      expect(ArtistDashboardRepository.waitlistEntries.length, initialCount + 1);
      expect(ArtistDashboardRepository.waitlistEntries.first.id, 'new_entry_99');
    });

    test('updateWaitlistEntry modifies existing entry', () {
      final existingId = ArtistDashboardRepository.waitlistEntries.first.id;
      final modified = ArtistDashboardRepository.waitlistEntries.first.copyWith(
        conceptDescription: 'Updated concept text',
        status: WaitlistStatus.booked,
      );

      ArtistDashboardRepository.updateWaitlistEntry(modified);
      final found = ArtistDashboardRepository.waitlistEntries.firstWhere((e) => e.id == existingId);
      expect(found.conceptDescription, 'Updated concept text');
      expect(found.status, WaitlistStatus.booked);
    });

    test('removeWaitlistEntry removes entry by ID', () {
      final existingId = ArtistDashboardRepository.waitlistEntries.first.id;
      ArtistDashboardRepository.removeWaitlistEntry(existingId);
      expect(ArtistDashboardRepository.waitlistEntries.any((e) => e.id == existingId), isFalse);
    });

    test('sendEarlyAccessToWaitlist transitions waiting contacts to invited', () {
      ArtistDashboardRepository.sendEarlyAccessToWaitlist(hours: 48);

      final schedule = ArtistDashboardRepository.booksSchedule;
      expect(schedule.isBooksOpen, isTrue);
      expect(schedule.isEarlyAccessOnly, isTrue);
      expect(schedule.isEarlyAccessActive, isTrue);
      expect(schedule.earlyAccessHours, 48);

      // Verify that all previously waiting entries are now earlyAccessSent
      for (final entry in ArtistDashboardRepository.waitlistEntries) {
        if (entry.status != WaitlistStatus.booked && entry.status != WaitlistStatus.archived) {
          expect(entry.status, WaitlistStatus.earlyAccessSent);
          expect(entry.invitedAt, isNotNull);
        }
      }
    });

    test('openBooksPublicly sets isEarlyAccessOnly to false', () {
      ArtistDashboardRepository.sendEarlyAccessToWaitlist(hours: 24);
      expect(ArtistDashboardRepository.booksSchedule.isEarlyAccessActive, isTrue);

      ArtistDashboardRepository.openBooksPublicly();
      expect(ArtistDashboardRepository.booksSchedule.isBooksOpen, isTrue);
      expect(ArtistDashboardRepository.booksSchedule.isEarlyAccessOnly, isFalse);
      expect(ArtistDashboardRepository.booksSchedule.isEarlyAccessActive, isFalse);
    });
  });

  group('ArtistWaitlistScreen Widget Tests', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    Widget buildTestScreen() {
      return const MaterialApp(
        home: Scaffold(
          body: ArtistWaitlistScreen(),
        ),
      );
    }

    testWidgets('Renders header, stats row, search bar, and contact cards', (tester) async {
      ArtistDashboardRepository.waitlistEntries = List.from(WaitlistEntry.mockWaitlistEntries);
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('VIP Waitlist'), findsOneWidget);
      expect(find.text('WAITLIST'), findsOneWidget);
      expect(find.text('WAITING'), findsOneWidget);
      expect(find.text('INVITED'), findsOneWidget);
      expect(find.text('BOOKED'), findsOneWidget);
      expect(find.text('Add Friend'), findsOneWidget);
      expect(find.text('Chloe Bennett'), findsOneWidget);
      expect(find.text('Aunt Michelle'), findsOneWidget);
    });

    testWidgets('Filter chip filters waitlist contacts by status', (tester) async {
      ArtistDashboardRepository.waitlistEntries = List.from(WaitlistEntry.mockWaitlistEntries);
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Tap 'Early Access Sent' filter
      final invitedChip = find.textContaining('Early Access Sent (');
      expect(invitedChip, findsOneWidget);
      await tester.tap(invitedChip);
      await tester.pumpAndSettle();

      // Marcus Cole has early access sent in mock data
      expect(find.text('Marcus Cole'), findsOneWidget);
      // Chloe Bennett is waiting, so should be filtered out
      expect(find.text('Chloe Bennett'), findsNothing);
    });

    testWidgets('Search query filters contacts in real-time', (tester) async {
      ArtistDashboardRepository.waitlistEntries = List.from(WaitlistEntry.mockWaitlistEntries);
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Michelle');
      await tester.pumpAndSettle();

      expect(find.text('Aunt Michelle'), findsOneWidget);
      expect(find.text('Chloe Bennett'), findsNothing);
    });
  });

  group('BooksOpenOptionsModal & Outreach Sheet Tests', () {
    testWidgets('BooksOpenOptionsModal fires onEarlyAccessSelected callback', (tester) async {
      bool earlyAccessFired = false;
      bool publicFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    BooksOpenOptionsModal.show(
                      context: context,
                      onEarlyAccessSelected: () => earlyAccessFired = true,
                      onPublicOpenSelected: () => publicFired = true,
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Ready to Open Books?'), findsOneWidget);
      expect(find.text('Send Early Access to Waitlist'), findsOneWidget);
      expect(find.text('Launch Early Access Window'), findsOneWidget);

      await tester.tap(find.text('Launch Early Access Window'));
      await tester.pumpAndSettle();

      expect(earlyAccessFired, isTrue);
      expect(publicFired, isFalse);
    });

    testWidgets('EarlyAccessOutreachSheet displays outreach checklist for non-app friends', (tester) async {
      ArtistDashboardRepository.waitlistEntries = List.from(WaitlistEntry.mockWaitlistEntries);
      ArtistDashboardRepository.sendEarlyAccessToWaitlist(hours: 24);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => EarlyAccessOutreachSheet.show(context: context),
                  child: const Text('Open Outreach'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Outreach'));
      await tester.pumpAndSettle();

      expect(find.text('VIP Early Access Active'), findsOneWidget);
      expect(find.textContaining('FRIENDS & FAMILY OUTREACH'), findsOneWidget);
      expect(find.text('Aunt Michelle'), findsOneWidget);
      expect(find.text('Share Text Invite'), findsWidgets);
    });
  });

  group('VipWaitlistInvitationCard Widget Tests', () {
    testWidgets('Renders VIP invitation card and actions', (tester) async {
      final entry = WaitlistEntry(
        id: 'wl_test',
        clientName: 'Alex Mercer',
        conceptDescription: 'Fine line dragon and lotus flower',
        placement: 'Forearm',
        budget: 350,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VipWaitlistInvitationCard(entry: entry),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('EXCLUSIVE VIP EARLY ACCESS'), findsOneWidget);
      expect(find.text('OddMaree opened books for you!'), findsOneWidget);
      expect(find.text('Fine line dragon and lotus flower'), findsOneWidget);
      expect(find.text('Book My Request'), findsOneWidget);
      expect(find.text('Browse Flash Pieces'), findsOneWidget);
    });
  });
}

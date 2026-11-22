import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/models/artist_dashboard/book_drop.dart';
import 'package:flash_ink/repositories/artist_dashboard_repository.dart';
import 'package:flash_ink/screens/artist_dashboard/books_status_card.dart';

void main() {
  group('BooksStatusCard Widget Tests', () {
    setUp(() {
      MockDataConfig.debugOverride = true;
      ArtistDashboardRepository.resetMockData();
    });

    tearDown(() {
      MockDataConfig.resetDebugOverride();
    });

    Widget buildCard({
      VoidCallback? onOpenSettings,
      VoidCallback? onReviewRequests,
      VoidCallback? onPlanDrop,
      VoidCallback? onStatusChanged,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: BooksStatusCard(
              onOpenSettings: onOpenSettings,
              onReviewRequests: onReviewRequests,
              onPlanDrop: onPlanDrop,
              onStatusChanged: onStatusChanged,
            ),
          ),
        ),
      );
    }

    testWidgets('Normal BOOKS OPEN state hides headline, subtext, and settings icon while keeping indicator, switch, chevron, and CTAs', (tester) async {
      bool openedBooks = false;
      await tester.pumpWidget(buildCard(onOpenSettings: () => openedBooks = true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('books_status_card')), findsOneWidget);
      expect(find.text('BOOKS OPEN'), findsOneWidget);
      expect(find.byKey(const Key('books_status_chevron')), findsOneWidget);
      expect(find.byKey(const Key('books_status_switch')), findsOneWidget);
      expect(find.byKey(const Key('books_status_primary_cta')), findsOneWidget);
      expect(find.byKey(const Key('books_status_secondary_cta')), findsOneWidget);

      expect(find.text('Accepting New Appointments'), findsNothing);
      expect(find.textContaining('Clients can view available calendar dates'), findsNothing);
      expect(find.byIcon(Icons.settings_outlined), findsNothing);

      // Tapping the card indicator/chevron opens Books
      await tester.tap(find.byKey(const Key('books_status_chevron')));
      await tester.pumpAndSettle();
      expect(openedBooks, isTrue);
    });

    testWidgets('Normal INQUIRIES PAUSED and BOOKS CLOSED states hide headline and subtext', (tester) async {
      ArtistDashboardRepository.pauseInquiries();
      await tester.pumpWidget(buildCard(onOpenSettings: () {}));
      await tester.pumpAndSettle();

      expect(find.text('INQUIRIES PAUSED'), findsOneWidget);
      expect(find.text('Inquiries Currently Paused'), findsNothing);
      expect(find.text('Resume Books'), findsOneWidget);

      ArtistDashboardRepository.closeBooks();
      await tester.pumpWidget(buildCard(onOpenSettings: () {}));
      await tester.pumpAndSettle();

      expect(find.text('BOOKS CLOSED'), findsOneWidget);
      expect(find.text('Currently Closed to Inquiries'), findsNothing);
      expect(find.text('Plan a Book Drop'), findsOneWidget);
    });

    testWidgets('Booking Drop state retains dynamic drop title and description', (tester) async {
      ArtistDashboardRepository.bookingMode = BookingMode.drops;
      ArtistDashboardRepository.currentBookDrop = BookDrop(
        id: 'drop_1',
        title: 'Winter Flash Drop',
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2026, 12, 5),
        opensAt: DateTime(2026, 12, 1, 12, 0),
        status: BookDropStatus.scheduled,
      );
      await tester.pumpWidget(buildCard(onOpenSettings: () {}));
      await tester.pumpAndSettle();

      expect(find.text('DROP SCHEDULED'), findsOneWidget);
      expect(find.text('Winter Flash Drop'), findsOneWidget);
      expect(find.textContaining('Waitlist members get exclusive VIP access first.'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/models/artist.dart';
import 'package:flash_ink/screens/booking/flash_booking_screen.dart';
import 'package:flash_ink/screens/flash_details_screen.dart';

void main() {
  group('Flash Booking Flow Tests', () {
    const testFlash = FlashArtwork(
      id: 'flash_test_101',
      artistId: 'artist_1',
      artistName: 'Maree Raven',
      title: 'Obsidian Serpent & Peony',
      imageUrl: 'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28',
      price: 250,
      deposit: 75,
      dimensions: '6" x 9"',
      estimatedTime: '3.0 hrs',
      location: 'Forearm / Calf',
      status: FlashStatus.available,
    );

    const testArtist = Artist(
      id: 'artist_1',
      name: 'Maree Raven',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      location: 'Downtown Arts District, LA',
      studioType: 'Private Studio',
      rating: 4.9,
      minDeposit: 75,
      availablePieces: 8,
      images: [],
    );

    testWidgets('Renders FlashBookingScreen Step 1 (Schedule) with calendar, time slots, and artwork recap',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top Header & Stepper
      expect(find.text('Claim & Book Flash'), findsOneWidget);
      expect(find.text('Date & Time'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);

      // Artwork recap
      expect(find.text('Obsidian Serpent & Peony'), findsOneWidget);
      expect(find.text('by Maree Raven'), findsOneWidget);
      expect(find.text('Deposit: \$75 • Full: \$250'), findsOneWidget);

      // Calendar & Time slots
      expect(find.text('SELECT DATE'), findsOneWidget);
      expect(find.text('SELECT TIME SLOT'), findsOneWidget);
      expect(find.text('Session Est. 3.0 hrs'), findsOneWidget);
      expect(find.text('1:30 PM'), findsOneWidget);
      expect(find.text('3:00 PM'), findsOneWidget);

      // Placement & Silent appointment toggle
      expect(find.text('BODY PLACEMENT'), findsOneWidget);
      expect(find.text('Silent Appointment'), findsOneWidget);
      expect(find.text('CONTINUE TO DETAILS'), findsOneWidget);
    });

    testWidgets('Selecting time slot, toggling silent appointment, and proceeding to Step 2 (Details)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap different time slot
      await tester.tap(find.text('3:00 PM'));
      await tester.pumpAndSettle();

      // Toggle silent appointment switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Tap CONTINUE TO DETAILS
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();

      // Verify Step 2 rendered
      expect(find.text('CLIENT INFORMATION'), findsOneWidget);
      expect(find.text('STUDIO POLICIES & TERMS'), findsOneWidget);
      expect(find.text('CONTINUE TO PAYMENT'), findsOneWidget);
      expect(find.text('Alex Rivers'), findsOneWidget);
    });

    testWidgets('Step 2: Policy checkbox controls proceed button to Step 3 (Payment)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Step 2
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();

      // Uncheck policies
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Attempt tapping Continue To Payment when disabled
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();

      // Still on step 2
      expect(find.text('CLIENT INFORMATION'), findsOneWidget);

      // Check policies back on
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Tap Continue to payment
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();

      // Verify Step 3 Payment Breakdown
      expect(find.text('PAYMENT BREAKDOWN'), findsOneWidget);
      expect(find.text('Total Flash Price'), findsOneWidget);
      expect(find.text('\$250'), findsOneWidget);
      expect(find.text('Deposit Due Today'), findsOneWidget);
      expect(find.text('\$75'), findsOneWidget);
      expect(find.text('Balance Due at Studio'), findsOneWidget);
      expect(find.text('\$175'), findsOneWidget);
      expect(find.text('PAY \$75 DEPOSIT & CONFIRM'), findsOneWidget);
    });

    testWidgets('Step 3: Processing payment transitions to Step 4 (Confirmation screen)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashBookingScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();

      // Select Credit Card
      await tester.tap(find.text('Credit Card (•••• 4242)'));
      await tester.pumpAndSettle();

      // Tap PAY DEPOSIT & CONFIRM
      await tester.tap(find.text('PAY \$75 DEPOSIT & CONFIRM'));
      await tester.pump(); // Starts loading

      // Wait for simulated payment processing
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Verify Step 4 Confirmation
      expect(find.text('Flash Claimed & Booked!'), findsOneWidget);
      expect(find.textContaining('Ref: INK-'), findsOneWidget);
      expect(find.text('ADD TO CALENDAR'), findsOneWidget);
      expect(find.text('SESSION PREPARATION TIPS'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
    });

    testWidgets('End-to-End: Tapping CLAIM & BOOK FLASH in FlashDetailsScreen opens booking flow and marks artwork as claimed',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: FlashDetailsScreen(
            flash: testFlash,
            artist: testArtist,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.text('CLAIM & BOOK FLASH'), findsOneWidget);
      expect(find.text('AVAILABLE (1-OF-1)'), findsOneWidget);

      // Tap CLAIM & BOOK FLASH to launch flow
      await tester.tap(find.text('CLAIM & BOOK FLASH'));
      await tester.pumpAndSettle();

      // We are in FlashBookingScreen Step 1
      expect(find.text('SELECT DATE'), findsOneWidget);

      // Progress through flow: Step 1 -> Step 2
      await tester.tap(find.text('CONTINUE TO DETAILS'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3
      await tester.tap(find.text('CONTINUE TO PAYMENT'));
      await tester.pumpAndSettle();

      // Step 3 -> Pay
      await tester.tap(find.text('PAY \$75 DEPOSIT & CONFIRM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // We are on Confirmation screen
      expect(find.text('Flash Claimed & Booked!'), findsOneWidget);

      // Tap DONE to return
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();

      // Back on FlashDetailsScreen: verify artwork is now claimed!
      expect(find.text('PIECE ALREADY CLAIMED'), findsOneWidget);
      expect(find.text('CLAIMED'), findsOneWidget);
      expect(find.textContaining('Deposit \$75 confirmed'), findsOneWidget);
    });
  });
}

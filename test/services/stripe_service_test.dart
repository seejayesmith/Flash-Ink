import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/features/appointments/domain/models/appointment_item.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';
import 'package:flash_ink/services/stripe_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StripeService', () {
    late StripeService service;

    setUp(() {
      MockDataConfig.debugOverride = true;
      service = StripeService();
    });

    tearDown(() {
      MockDataConfig.resetDebugOverride();
    });

    test('fetches available funds without error', () async {
      final funds = await service.fetchAvailableFunds();
      expect(funds, isA<double>());
    });

    test('fetches YTD and MTD earnings without error', () async {
      final ytd = await service.fetchYtdEarnings();
      final mtd = await service.fetchMtdEarnings();
      expect(ytd, isA<int>());
      expect(mtd, isA<int>());
    });

    test('initiates instant transfer with success', () async {
      final success = await service.initiateInstantTransfer(
        amount: 250.0,
        bankAccountMask: '•••• 1234',
      );
      expect(success, isTrue);
    });

    test('presentDepositPaymentSheet falls back gracefully in unconfigured test environment', () async {
      final response = await service.presentDepositPaymentSheet(
        amountInDollars: 50.0,
        flashTitle: 'Dragon Flash',
        customerEmail: 'alex@example.com',
        bookingId: 'INK-99881',
        selectedDate: '2026-10-20',
        selectedTimeSlot: '1:30 PM',
        placement: 'Forearm',
      );

      expect(response.isSuccess, isTrue);
      expect(response.isSimulated, isTrue);
      expect(response.status, StripePaymentStatus.success);
    });

    test('verifyBookingPaymentStatus returns confirmed status', () async {
      final verification = await service.verifyBookingPaymentStatus('pi_test_12345');
      expect(verification['paymentIntentId'], 'pi_test_12345');
      expect(verification['status'], 'confirmed');
    });

    test('handleWebhookEvent synchronizes payment_intent.succeeded and cleans up on payment_intent.payment_failed', () {
      final succeededPayload = {
        'type': 'payment_intent.succeeded',
        'data': {
          'object': {
            'id': 'pi_webhook_9001',
            'amount': 8000,
            'metadata': {
              'booking_id': 'INK-WEBHOOK-9001',
              'flash_title': 'Cybernetic Kitsune',
              'customer_name': 'Taylor Vance',
              'selected_date': '2026-11-10',
              'selected_time_slot': '3:00 PM',
              'placement': 'Upper Arm',
              'total_price': '320',
            },
          },
        },
      };

      final handled = StripeService.handleWebhookEvent(succeededPayload);
      expect(handled, isTrue);

      final calApt = ArtistDashboardRepository.calendarAppointments.firstWhere(
        (a) => a.id == 'cal_INK-WEBHOOK-9001',
      );
      expect(calApt.clientName, 'Taylor Vance');
      expect(calApt.depositPaid, 80);
      expect(calApt.fullPrice, 320);
      expect(calApt.time, '3:00 PM');

      final clientApt = ClientAppointment.mockUpcoming.firstWhere(
        (a) => a.id == 'INK-WEBHOOK-9001',
      );
      expect(clientApt.status, AppointmentStatus.confirmed);
      expect(clientApt.depositAmount, 80);

      // Now simulate an asynchronous payment failure webhook for the same booking
      final failedPayload = {
        'type': 'payment_intent.payment_failed',
        'data': {
          'object': {
            'id': 'pi_webhook_9001',
            'metadata': {
              'booking_id': 'INK-WEBHOOK-9001',
            },
          },
        },
      };

      final failedHandled = StripeService.handleWebhookEvent(failedPayload);
      expect(failedHandled, isFalse);
      expect(
        ArtistDashboardRepository.calendarAppointments.any((a) => a.id == 'cal_INK-WEBHOOK-9001'),
        isFalse,
      );
      expect(
        ClientAppointment.mockUpcoming.any((a) => a.id == 'INK-WEBHOOK-9001'),
        isFalse,
      );
    });
  });
}

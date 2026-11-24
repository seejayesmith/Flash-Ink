import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/mock/mock_data_config.dart';
import 'package:flash_ink/features/appointments/domain/models/appointment_item.dart';
import 'package:flash_ink/repositories/artist_dashboard_repository.dart';
import 'package:flash_ink/services/stripe_service.dart';
import '../helpers/fake_recovery_functions.dart';

class _FakePaymentFunctions extends Fake implements FirebaseFunctions {
  final List<RecordedCallableInvocation> invocations = [];
  Map<String, dynamic> Function(String name, Map<String, dynamic> data)?
      handler;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    return _FakePaymentCallable(name, this);
  }

  Map<String, dynamic> _dispatch(String name, Map<String, dynamic> data) {
    invocations.add(RecordedCallableInvocation(name, data));
    if (handler != null) {
      return handler!(name, data);
    }
    return const {};
  }
}

class _FakePaymentCallable extends Fake implements HttpsCallable {
  final String name;
  final _FakePaymentFunctions backend;

  _FakePaymentCallable(this.name, this.backend);

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final data = <String, dynamic>{
      if (parameters is Map)
        for (final entry in parameters.entries)
          entry.key.toString(): entry.value,
    };
    final result = backend._dispatch(name, data);
    return _FakePaymentCallableResult<T>(result as T);
  }
}

class _FakePaymentCallableResult<T> extends Fake
    implements HttpsCallableResult<T> {
  @override
  final T data;

  _FakePaymentCallableResult(this.data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StripeService (Mock Sandbox Mode)', () {
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

    test(
        'presentDepositPaymentSheet simulates payment only in explicit non-production mock mode',
        () async {
      final response = await service.presentDepositPaymentSheet(
        amountInDollars: 50.0,
        flashTitle: 'Dragon Flash',
        flashId: 'flash_dragon_1',
        artistId: 'artist_1',
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

    test('verifyBookingPaymentStatus returns confirmed status in mock mode',
        () async {
      final verification =
          await service.verifyBookingPaymentStatus('pi_test_12345');
      expect(verification['paymentIntentId'], 'pi_test_12345');
      expect(verification['status'], 'confirmed');
    });

    test(
        'handleWebhookEvent synchronizes payment_intent.succeeded and cleans up on payment_intent.payment_failed',
        () {
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
        ArtistDashboardRepository.calendarAppointments
            .any((a) => a.id == 'cal_INK-WEBHOOK-9001'),
        isFalse,
      );
      expect(
        ClientAppointment.mockUpcoming
            .any((a) => a.id == 'INK-WEBHOOK-9001'),
        isFalse,
      );
    });
  });

  group('StripeService (Live / Production Fail-Closed Safety)', () {
    tearDown(() {
      MockDataConfig.resetDebugOverride();
    });

    test(
        'NEVER simulates payment in live mode when Stripe keys are unconfigured',
        () async {
      MockDataConfig.debugOverride = false;
      final service = StripeService(
        isStripeConfiguredOverride: false,
      );

      final response = await service.presentDepositPaymentSheet(
        amountInDollars: 75.0,
        flashTitle: 'Serpent Flash',
        flashId: 'flash_1',
        artistId: 'artist_1',
        bookingId: 'INK-LIVE-001',
        selectedDate: '2026-12-01',
        selectedTimeSlot: '1:30 PM',
      );

      expect(response.isSuccess, isFalse);
      expect(response.isSimulated, isFalse);
      expect(response.status, StripePaymentStatus.failed);
      expect(response.errorMessage, isNotEmpty);
    });

    test(
        'NEVER simulates payment when IS_PRODUCTION is true even if mock mode is forced',
        () async {
      MockDataConfig.debugOverride = true;
      final service = StripeService(
        isProductionOverride: true,
        isStripeConfiguredOverride: false,
      );

      final response = await service.presentDepositPaymentSheet(
        amountInDollars: 75.0,
        flashTitle: 'Serpent Flash',
        flashId: 'flash_1',
        artistId: 'artist_1',
        bookingId: 'INK-PROD-001',
      );

      expect(response.isSuccess, isFalse);
      expect(response.isSimulated, isFalse);
      expect(response.status, StripePaymentStatus.failed);
    });

    test(
        'fails closed on server network error instead of granting a free booking',
        () async {
      MockDataConfig.debugOverride = false;
      final fakeFunctions = _FakePaymentFunctions()
        ..handler = (name, data) {
          throw Exception('Network unreachable');
        };
      final service = StripeService(
        functions: fakeFunctions,
        isStripeConfiguredOverride: true,
      );

      final response = await service.presentDepositPaymentSheet(
        amountInDollars: 100.0,
        flashTitle: 'Dagger Flash',
        flashId: 'flash_dagger',
        artistId: 'artist_1',
        bookingId: 'INK-NET-ERR',
        selectedDate: '2026-12-05',
        selectedTimeSlot: '3:00 PM',
      );

      expect(response.isSuccess, isFalse);
      expect(response.isSimulated, isFalse);
      expect(response.status, StripePaymentStatus.failed);
      expect(response.errorMessage, contains('Could not reach'));
    });

    test('surfaces slot lock conflicts with isSlotConflict=true', () async {
      MockDataConfig.debugOverride = false;
      final fakeFunctions = _FakePaymentFunctions()
        ..handler = (name, data) {
          throw TestFunctionsException(
            code: 'already-exists',
            message:
                'Another collector is currently checking out this time slot.',
          );
        };
      final service = StripeService(
        functions: fakeFunctions,
        isStripeConfiguredOverride: true,
      );

      final response = await service.presentDepositPaymentSheet(
        amountInDollars: 75.0,
        flashTitle: 'Moth Flash',
        flashId: 'flash_moth',
        artistId: 'artist_1',
        bookingId: 'INK-LOCKED',
        selectedDate: '2026-12-05',
        selectedTimeSlot: '3:00 PM',
      );

      expect(response.isFailed, isTrue);
      expect(response.isSlotConflict, isTrue);
      expect(response.errorMessage, contains('checking out'));
    });

    test(
        'sends flashId & artistId (never client price or Stripe acct_ ID) and parses server lock/promo fields',
        () async {
      MockDataConfig.debugOverride = false;
      final fakeFunctions = _FakePaymentFunctions()
        ..handler = (name, data) {
          if (name == 'createPaymentIntent') {
            return {
              'clientSecret': 'pi_live_123_secret_abc',
              'id': 'pi_live_123',
              'lockExpiresAt': '2026-12-05T18:10:00.000Z',
              'depositCents': 7500,
              'platformFeeCents': 0,
              'totalChargeCents': 7500,
              'promoFeeWaived': true,
              'freeBookingsRemaining': 2,
            };
          }
          return const {};
        };

      String? presentedSecret;
      final service = StripeService(
        functions: fakeFunctions,
        isStripeConfiguredOverride: true,
        paymentSheetPresenter: ({
          required String clientSecret,
          String? customerEmail,
          String? customerName,
        }) async {
          presentedSecret = clientSecret;
        },
      );

      final response = await service.presentDepositPaymentSheet(
        amountInDollars: 75.0,
        flashTitle: 'Peony Flash',
        flashId: 'flash_peony',
        artistId: 'artist_42',
        customerEmail: 'collector@example.com',
        customerName: 'Alex Collector',
        bookingId: 'INK-LIVE-OK',
        selectedDate: '2026-12-05',
        selectedTimeSlot: '3:00 PM',
        placement: 'Forearm',
      );

      expect(response.isSuccess, isTrue);
      expect(response.isSimulated, isFalse);
      expect(response.paymentIntentId, 'pi_live_123');
      expect(response.depositCents, 7500);
      expect(response.platformFeeCents, 0);
      expect(response.promoFeeWaived, isTrue);
      expect(response.freeBookingsRemaining, 2);
      expect(response.lockExpiresAt, isNotNull);
      expect(presentedSecret, 'pi_live_123_secret_abc');

      expect(fakeFunctions.invocations, hasLength(1));
      final sent = fakeFunctions.invocations.first.data;
      expect(sent['flashId'], 'flash_peony');
      expect(sent['artistId'], 'artist_42');
      expect(sent.containsKey('amount'), isFalse);
      expect(sent.containsKey('accountId'), isFalse);
    });

    test('releases 10-minute checkout lock when user cancels PaymentSheet',
        () async {
      MockDataConfig.debugOverride = false;
      final fakeFunctions = _FakePaymentFunctions()
        ..handler = (name, data) {
          if (name == 'createPaymentIntent') {
            return {
              'clientSecret': 'pi_cancel_secret',
              'id': 'pi_cancel_1',
            };
          }
          if (name == 'releaseCheckoutLock') {
            return {'released': true, 'bookingId': data['bookingId']};
          }
          return const {};
        };

      final service = StripeService(
        functions: fakeFunctions,
        isStripeConfiguredOverride: true,
        paymentSheetPresenter: ({
          required String clientSecret,
          String? customerEmail,
          String? customerName,
        }) async {
          throw const StripeException(
            error: LocalizedErrorMessage(
              code: FailureCode.Canceled,
              message: 'User canceled payment sheet',
            ),
          );
        },
      );

      final response = await service.presentDepositPaymentSheet(
        amountInDollars: 75.0,
        flashTitle: 'Peony Flash',
        flashId: 'flash_peony',
        artistId: 'artist_42',
        bookingId: 'INK-CANCEL-1',
        selectedDate: '2026-12-05',
        selectedTimeSlot: '3:00 PM',
      );

      expect(response.isCanceled, isTrue);
      expect(
        fakeFunctions.invocations.map((i) => i.name).toList(),
        ['createPaymentIntent', 'releaseCheckoutLock'],
      );
      expect(fakeFunctions.invocations.last.data['bookingId'], 'INK-CANCEL-1');
    });
  });
}

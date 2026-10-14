import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/services/stripe_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StripeService', () {
    late StripeService service;

    setUp(() {
      service = StripeService();
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
      );

      expect(response.isSuccess, isTrue);
      expect(response.isSimulated, isTrue);
      expect(response.status, StripePaymentStatus.success);
    });
  });
}

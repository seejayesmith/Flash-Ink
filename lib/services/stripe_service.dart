import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../config/dev_config.dart';
import '../core/mock/mock_data_config.dart';
import '../features/appointments/domain/models/appointment_item.dart';
import '../models/artist_dashboard/artist_dashboard_stats.dart';
import '../models/artist_dashboard/dashboard_appointment.dart';
import '../repositories/artist_dashboard_repository.dart';

/// Status of a Stripe payment attempt.
enum StripePaymentStatus {
  success,
  canceled,
  failed,
}

/// Detailed result of a Stripe PaymentSheet presentation.
class StripePaymentResponse {
  final StripePaymentStatus status;
  final String? paymentIntentId;
  final String? errorMessage;
  final bool isSimulated;
  final bool isSlotConflict;
  final DateTime? lockExpiresAt;
  final int? depositCents;
  final int? platformFeeCents;
  final int? totalChargeCents;
  final bool promoFeeWaived;
  final int? freeBookingsRemaining;

  const StripePaymentResponse({
    required this.status,
    this.paymentIntentId,
    this.errorMessage,
    this.isSimulated = false,
    this.isSlotConflict = false,
    this.lockExpiresAt,
    this.depositCents,
    this.platformFeeCents,
    this.totalChargeCents,
    this.promoFeeWaived = false,
    this.freeBookingsRemaining,
  });

  bool get isSuccess => status == StripePaymentStatus.success;
  bool get isCanceled => status == StripePaymentStatus.canceled;
  bool get isFailed => status == StripePaymentStatus.failed;
}

/// Optional payment sheet presenter override for unit/widget testing.
typedef PaymentSheetPresenter = Future<void> Function({
  required String clientSecret,
  String? customerEmail,
  String? customerName,
});

/// Service for managing Stripe payments, Stripe Connect API integration,
/// available balance, and artist earnings.
class StripeService {
  final ArtistEarningsData _earningsData;
  final FirebaseFunctions? _injectedFunctions;
  final bool? isProductionOverride;
  final bool? isStripeConfiguredOverride;
  final PaymentSheetPresenter? paymentSheetPresenter;

  StripeService({
    ArtistEarningsData? initialData,
    FirebaseFunctions? functions,
    this.isProductionOverride,
    this.isStripeConfiguredOverride,
    this.paymentSheetPresenter,
  })  : _earningsData = initialData ?? ArtistDashboardRepository.earningsData,
        _injectedFunctions = functions;

  bool get _effectiveIsProduction => isProductionOverride ?? kIsProduction;

  bool get _effectiveIsStripeConfigured =>
      isStripeConfiguredOverride ?? isStripeConfigured;

  /// Simulated checkout is strictly restricted to explicit mock sandbox mode
  /// (`MockDataConfig.isEnabled == true`) and is ALWAYS disabled in production.
  bool get _allowSimulatedPayments =>
      MockDataConfig.isEnabled && !_effectiveIsProduction;

  FirebaseFunctions _resolveFunctions() =>
      _injectedFunctions ?? FirebaseFunctions.instance;

  /// Fetches the current available balance for the connected Stripe account.
  Future<double> fetchAvailableFunds() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _earningsData.nextPayoutAmount;
  }

  /// Fetches Year-To-Date (YTD) total earnings from Stripe API.
  Future<int> fetchYtdEarnings() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _earningsData.ytdAmount;
  }

  /// Fetches Month-To-Date (MTD) total earnings from Stripe API.
  Future<int> fetchMtdEarnings() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _earningsData.mtdAmount;
  }

  /// Initiates an instant transfer of available funds to the artist's bank account.
  Future<bool> initiateInstantTransfer({
    required double amount,
    required String bankAccountMask,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }

  /// Checks if Stripe is configured with a valid publishable key.
  static bool get isStripeConfigured {
    if (!dotenv.isInitialized) return false;
    final key = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
    return key != null && key.isNotEmpty && !key.contains('YOUR_STRIPE');
  }

  /// Releases an active 10-minute checkout lock when a collector cancels
  /// or abandons the Stripe PaymentSheet.
  Future<void> releaseCheckoutLock({required String bookingId}) async {
    final cleanBookingId = bookingId.trim();
    if (cleanBookingId.isEmpty || _allowSimulatedPayments) return;
    try {
      final callable =
          _resolveFunctions().httpsCallable('releaseCheckoutLock');
      await callable.call<dynamic>({'bookingId': cleanBookingId});
    } catch (_) {
      // Lock also auto-expires on the server after 10 minutes.
    }
  }

  /// Presents the native Stripe PaymentSheet for deposit payment.
  ///
  /// Live/production builds ALWAYS verify pricing, artist Stripe Connect readiness,
  /// promotional fee allowances, and an atomic 10-minute checkout lock on the server
  /// via the `createPaymentIntent` Cloud Function — never falling back to simulated
  /// success if the server call or Stripe SDK fails.
  ///
  /// Simulated payment completion is only permitted when [MockDataConfig.isEnabled]
  /// is explicitly turned on in non-production sandbox/widget-test runs.
  Future<StripePaymentResponse> presentDepositPaymentSheet({
    required double amountInDollars,
    required String flashTitle,
    String? flashId,
    String? customRequestId,
    String? clientSecret,
    String? customerEmail,
    String? customerName,
    String? customerPhone,
    String? artistId,
    @Deprecated('Pass artistId instead; server resolves private Stripe account securely.')
    String? artistStripeAccountId,
    String? bookingId,
    String? selectedDate,
    String? selectedTimeSlot,
    String? placement,
    String? clientNotes,
    bool isSilentAppointment = false,
  }) async {
    // 1. Explicit mock/sandbox shortcut (strictly non-production tests/demos only).
    if (_allowSimulatedPayments && clientSecret == null) {
      await Future.delayed(const Duration(milliseconds: 600));
      final depositCents = (amountInDollars * 100).round();
      return StripePaymentResponse(
        status: StripePaymentStatus.success,
        paymentIntentId: 'pi_simulated_deposit_test',
        isSimulated: true,
        lockExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
        depositCents: depositCents,
        platformFeeCents: 0,
        totalChargeCents: depositCents,
        promoFeeWaived: true,
      );
    }

    // 2. Live / production fail-closed configuration check.
    if (!_effectiveIsStripeConfigured && clientSecret == null) {
      return const StripePaymentResponse(
        status: StripePaymentStatus.failed,
        errorMessage:
            'Payments are temporarily unavailable. Please try again shortly.',
      );
    }

    final resolvedArtistId = (artistId?.trim().isNotEmpty == true)
        ? artistId!.trim()
        : (artistStripeAccountId != null &&
                !artistStripeAccountId.startsWith('acct_')
            ? artistStripeAccountId.trim()
            : '');

    String? effectiveClientSecret = clientSecret;
    String? intentId;
    DateTime? lockExpiresAt;
    int? depositCents;
    int? platformFeeCents;
    int? totalChargeCents;
    bool promoFeeWaived = false;
    int? freeBookingsRemaining;

    // 3. Create server-authoritative PaymentIntent & acquire 10-min checkout lock.
    if (effectiveClientSecret == null) {
      final payload = <String, dynamic>{
        'currency': 'usd',
        'artistId': resolvedArtistId,
        if (flashId != null && flashId.trim().isNotEmpty)
          'flashId': flashId.trim(),
        if (customRequestId != null && customRequestId.trim().isNotEmpty)
          'customRequestId': customRequestId.trim(),
        'flashTitle': flashTitle,
        'customerEmail': customerEmail,
        'customerName': customerName,
        if (customerPhone != null && customerPhone.trim().isNotEmpty)
          'customerPhone': customerPhone.trim(),
        'bookingId': bookingId,
        'selectedDate': selectedDate,
        'selectedTimeSlot': selectedTimeSlot,
        'placement': placement,
        if (clientNotes != null && clientNotes.trim().isNotEmpty)
          'clientNotes': clientNotes.trim(),
        'isSilentAppointment': isSilentAppointment,
      };

      try {
        final callable =
            _resolveFunctions().httpsCallable('createPaymentIntent');
        final result = await callable.call<dynamic>(payload);
        final rawData = result.data;
        if (rawData is! Map) {
          return const StripePaymentResponse(
            status: StripePaymentStatus.failed,
            errorMessage:
                'Unexpected response from the payment server. Please try again.',
          );
        }

        final data = Map<String, dynamic>.from(rawData);
        effectiveClientSecret = data['clientSecret']?.toString();
        intentId = data['id']?.toString();
        if (data['lockExpiresAt'] is String) {
          lockExpiresAt = DateTime.tryParse(data['lockExpiresAt'] as String);
        }
        if (data['depositCents'] is num) {
          depositCents = (data['depositCents'] as num).toInt();
        }
        if (data['platformFeeCents'] is num) {
          platformFeeCents = (data['platformFeeCents'] as num).toInt();
        }
        if (data['totalChargeCents'] is num) {
          totalChargeCents = (data['totalChargeCents'] as num).toInt();
        }
        promoFeeWaived = data['promoFeeWaived'] == true;
        if (data['freeBookingsRemaining'] is num) {
          freeBookingsRemaining =
              (data['freeBookingsRemaining'] as num).toInt();
        }
      } on FirebaseFunctionsException catch (e) {
        return StripePaymentResponse(
          status: StripePaymentStatus.failed,
          isSlotConflict: e.code == 'already-exists',
          errorMessage: _mapFunctionsPaymentError(e),
        );
      } catch (_) {
        return const StripePaymentResponse(
          status: StripePaymentStatus.failed,
          errorMessage:
              'Could not reach the payment server. Please check your connection and try again.',
        );
      }
    }

    if (effectiveClientSecret == null || effectiveClientSecret.isEmpty) {
      return const StripePaymentResponse(
        status: StripePaymentStatus.failed,
        errorMessage:
            'Unable to initialize secure checkout. Please try again.',
      );
    }

    // 4. Present the native Stripe PaymentSheet (Apple Pay, Google Pay, Card).
    try {
      if (paymentSheetPresenter != null) {
        await paymentSheetPresenter!(
          clientSecret: effectiveClientSecret,
          customerEmail: customerEmail,
          customerName: customerName,
        );
      } else {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: effectiveClientSecret,
            merchantDisplayName: 'Flash.Ink',
            style: ThemeMode.dark,
            applePay: const PaymentSheetApplePay(
              merchantCountryCode: 'US',
            ),
            appearance: const PaymentSheetAppearance(
              colors: PaymentSheetAppearanceColors(
                primary: Color(0xFFEEC200),
                background: Color(0xFF171A1A),
                componentBackground: Color(0xFF1E2020),
                componentText: Color(0xFFF9FAFA),
                primaryText: Color(0xFFF9FAFA),
                secondaryText: Color(0xFF919696),
              ),
            ),
            billingDetails: BillingDetails(
              email: customerEmail,
              name: customerName,
            ),
          ),
        );

        await Stripe.instance.presentPaymentSheet();
      }

      return StripePaymentResponse(
        status: StripePaymentStatus.success,
        paymentIntentId: intentId,
        lockExpiresAt: lockExpiresAt,
        depositCents: depositCents,
        platformFeeCents: platformFeeCents,
        totalChargeCents: totalChargeCents,
        promoFeeWaived: promoFeeWaived,
        freeBookingsRemaining: freeBookingsRemaining,
      );
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        if (bookingId != null && bookingId.trim().isNotEmpty) {
          await releaseCheckoutLock(bookingId: bookingId);
        }
        return const StripePaymentResponse(
          status: StripePaymentStatus.canceled,
          errorMessage: 'Payment canceled.',
        );
      }
      return StripePaymentResponse(
        status: StripePaymentStatus.failed,
        errorMessage:
            e.error.localizedMessage ?? e.error.message ?? 'Payment failed.',
      );
    } catch (e) {
      if (bookingId != null && bookingId.trim().isNotEmpty) {
        await releaseCheckoutLock(bookingId: bookingId);
      }
      return const StripePaymentResponse(
        status: StripePaymentStatus.failed,
        errorMessage:
            'Secure checkout could not be opened on this device. Please try again.',
      );
    }
  }

  String _mapFunctionsPaymentError(FirebaseFunctionsException e) {
    final rawMessage = e.message?.trim();
    if (rawMessage != null && rawMessage.isNotEmpty) {
      return rawMessage;
    }
    switch (e.code) {
      case 'unauthenticated':
        return 'Please sign in to pay your deposit and confirm your booking.';
      case 'already-exists':
        return 'This flash piece or time slot was just reserved. Please pick another option.';
      case 'failed-precondition':
        return 'This booking cannot be processed right now. Please try another date or artist.';
      case 'not-found':
        return 'This flash piece or artist is no longer available.';
      case 'permission-denied':
        return 'You do not have permission to complete this booking.';
      default:
        return 'Payment could not be started. Please try again.';
    }
  }

  /// Verifies server-side payment and booking confirmation status for a PaymentIntent ID.
  Future<Map<String, dynamic>> verifyBookingPaymentStatus(
    String paymentIntentId,
  ) async {
    if (_allowSimulatedPayments) {
      return {
        'paymentIntentId': paymentIntentId,
        'status': 'confirmed',
        'verifiedLocally': true,
      };
    }
    return {
      'paymentIntentId': paymentIntentId,
      'status': 'pending_webhook',
      'verifiedLocally': false,
    };
  }

  /// Processes a Stripe webhook event payload (`payment_intent.succeeded` or `payment_intent.payment_failed`)
  /// and synchronizes confirmed booking appointments into the artist and client repositories if not already recorded.
  static bool handleWebhookEvent(Map<String, dynamic> eventPayload) {
    final type = eventPayload['type'] as String?;
    final data = eventPayload['data'] as Map<String, dynamic>?;
    final object = data?['object'] as Map<String, dynamic>?;
    if (type == null || object == null) return false;

    final metadata = (object['metadata'] as Map<String, dynamic>?) ?? const {};
    final bookingId = (metadata['booking_id'] ?? object['id'] ?? '').toString();

    if (type == 'payment_intent.succeeded') {
      if (bookingId.isEmpty) return true;
      final calId = 'cal_$bookingId';
      final alreadyInCalendar = ArtistDashboardRepository.calendarAppointments
          .any((apt) => apt.id == calId || apt.id == bookingId);

      if (!alreadyInCalendar) {
        final flashTitle =
            (metadata['flash_title'] ?? 'Flash Artwork').toString();
        final customerName = (metadata['customer_name'] ?? 'Client').toString();
        final timeSlot =
            (metadata['selected_time_slot'] ?? '1:30 PM').toString();
        final placement = (metadata['placement'] ?? 'Forearm').toString();
        final dateStr = (metadata['selected_date'] ?? '').toString();
        final parsedDate = DateTime.tryParse(dateStr) ??
            DateTime.now().add(const Duration(days: 2));
        final amountCents = (object['amount'] as num?)?.toInt() ?? 5000;
        final depositDollars = (amountCents / 100).round();
        final totalDollars = (metadata['total_price'] != null)
            ? int.tryParse(metadata['total_price'].toString()) ??
                (depositDollars * 3)
            : (depositDollars * 3);

        final clientId =
            (metadata['client_id'] ?? 'client_unknown').toString();
        final artistId =
            (metadata['artist_id'] ?? 'artist_unknown').toString();
        final flashImageUrl =
            (metadata['flash_image_url'] ?? metadata['artwork_image_url'] ?? '')
                .toString();

        ArtistDashboardRepository.addCalendarAppointment(
          DashboardAppointment(
            id: calId,
            clientId: clientId,
            artistId: artistId,
            clientName: customerName,
            serviceType: 'Flash: $flashTitle',
            duration: '2.0 hrs',
            time: timeSlot,
            scheduledDate:
                DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
            date: dateStr.isNotEmpty ? dateStr : 'Upcoming',
            placement: placement,
            notes: 'Verified via Stripe Webhook (${object['id']})',
            depositPaid: depositDollars,
            fullPrice: totalDollars,
            artworkImageUrl: flashImageUrl,
            visitType: 'Flash Tattoo',
            dotColor: const Color(0xFF22C55E),
          ),
        );

        ClientAppointment.addUpcomingAppointment(
          ClientAppointment(
            id: bookingId,
            artistName: (metadata['artist_name'] ?? 'OddMaree').toString(),
            artistAvatar: '',
            studioName: 'Obsidian Atelier',
            studioAddress:
                ArtistDashboardRepository.booksSchedule.locationNote,
            flashTitle: flashTitle,
            flashImageUrl: flashImageUrl,
            dateTime:
                DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
            timeSlot: '$timeSlot (2.0 hrs)',
            placement: placement,
            depositAmount: depositDollars,
            totalPrice: totalDollars,
            status: AppointmentStatus.confirmed,
          ),
        );
      }
      return true;
    } else if (type == 'payment_intent.payment_failed') {
      if (bookingId.isNotEmpty) {
        ArtistDashboardRepository.calendarAppointments.removeWhere(
            (apt) => apt.id == 'cal_$bookingId' || apt.id == bookingId);
        ClientAppointment.liveUpcoming
            .removeWhere((apt) => apt.id == bookingId);
        ClientAppointment.mockUpcoming
            .removeWhere((apt) => apt.id == bookingId);
      }
      return false;
    }
    return false;
  }
}

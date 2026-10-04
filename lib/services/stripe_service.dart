import 'dart:async';
import '../models/artist_dashboard_data.dart';

/// Service for managing Stripe Connect API integration, available balance, and YTD earnings.
class StripeService {
  final ArtistEarningsData _earningsData;

  StripeService({ArtistEarningsData? initialData})
      : _earningsData = initialData ?? ArtistDashboardRepository.earningsData;

  /// Fetches the current available balance for the connected Stripe account.
  Future<double> fetchAvailableFunds() async {
    // Simulate lightweight API network latency
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
    // Successful transfer initiation
    return true;
  }
}

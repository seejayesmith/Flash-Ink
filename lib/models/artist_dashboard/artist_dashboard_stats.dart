/// Top-level metrics displayed on the artist dashboard.
class ArtistDashboardStats {
  final int bookingsThisWeek;
  final int newRequests;
  final int pendingCount;

  const ArtistDashboardStats({
    this.bookingsThisWeek = 12,
    this.newRequests = 2,
    this.pendingCount = 4,
  });
}

/// Earnings metrics and payout information for the artist.
class ArtistEarningsData {
  final double nextPayoutAmount;
  double get availableFundsAmount => nextPayoutAmount;
  final int mtdAmount;
  final int ytdAmount;
  final String ytdYear;

  const ArtistEarningsData({
    this.nextPayoutAmount = 1256.09,
    this.mtdAmount = 3467,
    this.ytdAmount = 16987,
    this.ytdYear = '2026',
  });
}

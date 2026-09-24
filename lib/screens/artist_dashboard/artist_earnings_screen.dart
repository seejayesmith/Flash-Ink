import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/flash_bottom_nav_bar.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard_data.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/tattoo_machine_icon.dart';
import '../artist_profile_screen.dart';
import '../splash_screen.dart';

/// The interactive Artist Earnings & Payouts screen matching the Flash.Ink design.
///
/// Can be presented as an independent full-screen route or embedded into
/// Tab 3 of the [ArtistDashboardScreen].
class ArtistEarningsScreen extends StatefulWidget {
  final Artist? artist;
  final AuthService? authService;
  final bool isEmbeddedInTab;
  final VoidCallback? onBack;
  final ArtistEarningsData? earningsData;

  const ArtistEarningsScreen({
    super.key,
    this.artist,
    this.authService,
    this.isEmbeddedInTab = false,
    this.onBack,
    this.earningsData,
  });

  @override
  State<ArtistEarningsScreen> createState() => _ArtistEarningsScreenState();
}

class _ArtistEarningsScreenState extends State<ArtistEarningsScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late final ArtistEarningsData _earningsData =
      widget.earningsData ?? ArtistDashboardRepository.earningsData;

  String get _artistDisplayName {
    if (widget.artist != null && widget.artist!.name.isNotEmpty) {
      return widget.artist!.name;
    }
    final user = _authService.currentUser;
    if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    return 'OddMaree';
  }

  String get _avatarUrl {
    if (widget.artist != null && widget.artist!.avatarUrl.isNotEmpty) {
      return widget.artist!.avatarUrl;
    }
    return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';
  }

  Widget _buildAvatarWidget({double radius = 18}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF262929),
      child: ClipOval(
        child: FlashImage(
          urlOrPath: _avatarUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorWidget: Container(
            color: const Color(0xFF262929),
            alignment: Alignment.center,
            child: Text(
              _artistDisplayName.isNotEmpty ? _artistDisplayName[0] : 'O',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEEC200),
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.9,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2121),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF383C3C),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildAvatarWidget(radius: 26),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _artistDisplayName,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Resident Artist • Flash.Ink',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8C9191),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Color(0xFF2C2F30), height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.white),
                  title: Text(
                    'View Public Profile',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF8C9191)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final effectiveArtist = widget.artist ??
                        Artist.mockArtists.firstWhere(
                          (a) => a.name.toLowerCase() == 'oddmaree',
                          orElse: () => Artist.mockArtists.first,
                        );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArtistProfileScreen(artist: effectiveArtist),
                      ),
                    );
                  },
                ),
                const Divider(color: Color(0xFF2C2F30), height: 1),
                ListTile(
                  key: const Key('modal_sign_out'),
                  leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                  title: Text(
                    'Sign Out',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _authService.signOut();
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const SplashScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBookingReceiptModal(BuildContext context, PastBookingEarningsItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF383C3C),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Booking Receipt',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.status.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF22C55E),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: ${item.dateString} • Payment: ${item.paymentMethod}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121414),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF262929)),
                  ),
                  child: Column(
                    children: [
                      _buildReceiptRow('Session Subtotal', '\$${item.amount.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      _buildReceiptRow(
                        'Platform Fee (5%)',
                        item.fee > 0 ? '-\$${item.fee.toStringAsFixed(2)}' : '\$0.00',
                        textColor: const Color(0xFF8C9191),
                      ),
                      const Divider(color: Color(0xFF282C2C), height: 20),
                      _buildReceiptRow(
                        'Net Deposit',
                        '\$${item.netAmount.toStringAsFixed(2)}',
                        isBold: true,
                        textColor: const Color(0xFF00E676),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Receipt Reference: ${item.receiptId}',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 12,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Receipt #${item.receiptId} downloaded.'),
                            backgroundColor: const Color(0xFF1E2121),
                          ),
                        );
                      },
                      child: Text(
                        'Download PDF',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEEC200),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    Color textColor = Colors.white,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isBold ? Colors.white : const Color(0xFF8C9191),
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: textColor,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showAllPastBookingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1D1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF383C3C),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Past Bookings & Payouts',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF8C9191)),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF282C2C), height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount: _earningsData.allPastBookings.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final item = _earningsData.allPastBookings[index];
                      return _buildPastBookingCard(item, onTap: () {
                        Navigator.pop(sheetContext);
                        _showBookingReceiptModal(context, item);
                      });
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTaxDocsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF383C3C),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.description_outlined, color: Color(0xFFEEC200), size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Tax Documents',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Access official IRS Form 1099-K statements and annual summaries.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTaxItem(
                  title: '2025 Form 1099-K',
                  subtitle: 'Gross volume \$16,987 • Ready to download',
                  status: 'Available',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Downloading 2025 Form 1099-K PDF...'),
                        backgroundColor: Color(0xFF1E2121),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildTaxItem(
                  title: '2025 Annual Earnings Statement',
                  subtitle: 'Complete itemized tax breakdown',
                  status: 'Available',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Downloading 2025 Annual Statement...'),
                        backgroundColor: Color(0xFF1E2121),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildTaxItem(
                  title: 'W-9 Form & Tax ID',
                  subtitle: 'SSN/EIN Verified with IRS',
                  status: 'Verified',
                  statusColor: const Color(0xFF22C55E),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('W-9 is in good standing.'),
                        backgroundColor: Color(0xFF1E2121),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaxItem({
    required String title,
    required String subtitle,
    required String status,
    Color statusColor = const Color(0xFFEEC200),
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF282C2C)),
      ),
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8C9191),
            fontSize: 12,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(35),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: GoogleFonts.plusJakartaSans(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showBankInfoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF383C3C),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.account_balance_outlined, color: Color(0xFFEEC200), size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Bank & Payout Info',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your direct deposit bank account and payout schedule.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121414),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF282C2C)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2121),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chase Bank •••• 4821',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Primary Checking • Direct Deposit Active',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF22C55E),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121414),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF282C2C)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flash_on, color: Color(0xFFEEC200), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Instant Payouts enabled to debit card.',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bank verification & routing tools are active.'),
                          backgroundColor: Color(0xFF1E2121),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEC200),
                      foregroundColor: const Color(0xFF121414),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Update Payout Method',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 12, 20, widget.isEmbeddedInTab ? 100 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopActionBar(),
            const SizedBox(height: 20),
            _buildHeroNextPayoutCard(),
            const SizedBox(height: 28),
            _buildEarningsTitle(),
            const SizedBox(height: 16),
            _buildMetricsRow(),
            const SizedBox(height: 28),
            _buildPastBookingsSection(),
            const SizedBox(height: 24),
            _buildUtilityActionsRow(),
          ],
        ),
      ),
    );

    if (widget.isEmbeddedInTab) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: Stack(
        children: [
          content,
          Positioned(
            left: AppTheme.navBarHorizontalMargin,
            right: AppTheme.navBarHorizontalMargin,
            bottom: MediaQuery.paddingOf(context).bottom + AppTheme.navBarBottomMargin,
            child: FlashBottomNavBar(
              currentIndex: 3,
              onTap: (index) {
                if (widget.onBack != null && index != 3) {
                  widget.onBack!();
                }
              },
              role: 'artist',
            ),
          ),
        ],
      ),
    );
  }

  /// Top action bar with tattoo machine logo on the left and artist avatar on the right
  Widget _buildTopActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!widget.isEmbeddedInTab && Navigator.canPop(context))
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.pop(context);
              }
            },
          )
        else
          const TattooMachineIcon(
            key: Key('earnings_tattoo_logo'),
            size: 28,
            color: Color(0xFFEEC200),
          ),
        GestureDetector(
          key: const Key('earnings_avatar_button'),
          onTap: _showProfileSettingsModal,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFEEC200).withAlpha(120),
                width: 1.5,
              ),
            ),
            child: _buildAvatarWidget(radius: 18),
          ),
        ),
      ],
    );
  }

  /// Hero Next Payout Card with bold amount and deposit schedule
  Widget _buildHeroNextPayoutCard() {
    final nextPayout = _earningsData.nextPayoutAmount;
    final wholePart = nextPayout.truncate();
    final centsPart = ((nextPayout - wholePart) * 100).round().toString().padLeft(2, '0');

    // Format thousands with commas
    final formattedWhole = _formatWithCommas(wholePart);

    return Container(
      key: const Key('next_payout_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF282C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Next Payout',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const _BanknoteIconWidget(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$$formattedWhole',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '.$centsPart',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF8C9191),
              ),
              children: [
                const TextSpan(text: 'to be deposited '),
                TextSpan(
                  text: _earningsData.payoutDepositDate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section heading: "Earnings"
  Widget _buildEarningsTitle() {
    return Text(
      'Earnings',
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  /// 2-Column Metrics Cards: MTD and YTD
  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            key: const Key('metric_card_mtd'),
            tag: 'MTD',
            timeframe: _earningsData.mtdMonth,
            amount: '\$${_formatWithCommas(_earningsData.mtdAmount)}',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricCard(
            key: const Key('metric_card_ytd'),
            tag: 'YTD',
            timeframe: _earningsData.ytdYear,
            amount: '\$${_formatWithCommas(_earningsData.ytdAmount)}',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required Key key,
    required String tag,
    required String timeframe,
    required String amount,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tag,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C9191),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                timeframe,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C9191),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// Past Bookings section with items and "View All" link
  Widget _buildPastBookingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Past Bookings',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              key: const Key('past_bookings_view_all_button'),
              onTap: () => _showAllPastBookingsModal(context),
              child: Text(
                'View All',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEEC200),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._earningsData.pastBookings.map((booking) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildPastBookingCard(booking, onTap: () {
              _showBookingReceiptModal(context, booking);
            }),
          );
        }),
      ],
    );
  }

  Widget _buildPastBookingCard(
    PastBookingEarningsItem booking, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2121),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF282C2C)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${booking.status} • ${booking.dateString}',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C9191),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${booking.amount.toStringAsFixed(2)}',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Action utility cards: Tax Docs and Bank Info
  Widget _buildUtilityActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildOutlinedActionButton(
            key: const Key('action_tax_docs'),
            icon: Icons.description_outlined,
            label: 'Tax Docs',
            onTap: () => _showTaxDocsModal(context),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildOutlinedActionButton(
            key: const Key('action_bank_info'),
            icon: Icons.account_balance_outlined,
            label: 'Bank Info',
            onTap: () => _showBankInfoModal(context),
          ),
        ),
      ],
    );
  }

  Widget _buildOutlinedActionButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFFEEC200).withAlpha(20),
        highlightColor: const Color(0xFFEEC200).withAlpha(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2121),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF383C3C),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: const Color(0xFFC5CECE),
                size: 26,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFD4D8D8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatWithCommas(num number) {
    final parts = number.toString().split('.');
    final integerPart = parts[0];
    final regExp = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = integerPart.replaceAllMapped(regExp, (match) => '${match[1]},');
    if (parts.length > 1) {
      return '$formatted.${parts[1]}';
    }
    return formatted;
  }
}

/// Custom emerald green banknote icon faithfully matching the design mockup.
class _BanknoteIconWidget extends StatelessWidget {
  const _BanknoteIconWidget();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Payout icon',
      child: SizedBox(
        width: 32,
        height: 22,
        child: CustomPaint(
          painter: _BanknotePainter(
            color: const Color(0xFF00E676),
          ),
        ),
      ),
    );
  }
}

class _BanknotePainter extends CustomPainter {
  final Color color;

  _BanknotePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Outer rounded bill border
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(4.5),
    );
    canvas.drawRRect(outerRect, strokePaint);

    // Center circular seal
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 3.8, fillPaint);

    // Subtle edge decorative lines (notches on sides)
    final sidePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(5, size.height * 0.32),
      Offset(5, size.height * 0.68),
      sidePaint,
    );

    canvas.drawLine(
      Offset(size.width - 5, size.height * 0.32),
      Offset(size.width - 5, size.height * 0.68),
      sidePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BanknotePainter oldDelegate) =>
      oldDelegate.color != color;
}

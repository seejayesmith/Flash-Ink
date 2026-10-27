import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/flash_bottom_nav_bar.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard_data.dart';
import '../../services/auth_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/tattoo_machine_icon.dart';
import 'appointment_detail_screen.dart';
import 'artist_account_screen.dart';

/// Enum representing the active view within the Artist Earnings screen.
enum ArtistEarningsTab {
  overview,
  history,
}

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

  ArtistEarningsTab _selectedTab = ArtistEarningsTab.overview;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  void _navigateToAccountScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistAccountScreen(
          artist: widget.artist,
          authService: _authService,
        ),
      ),
    );
  }

  void _showTaxDocsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AdaptiveGlassContainer.bottomSheet(
          glassEnabled: false,
          androidSurfaceColor: const Color(0xFF1A1D1D),
          topRadius: AppRadius.radiusSheet,
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
                      borderRadius: BorderRadius.circular(AppRadius.dragHandle),
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
                    FlashSnackBar.showInfo(
                      context,
                      'Downloading 2025 Form 1099-K PDF...',
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
                    FlashSnackBar.showInfo(
                      context,
                      'Downloading 2025 Annual Statement...',
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
                    FlashSnackBar.showSuccess(
                      context,
                      'W-9 is in good standing.',
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF121414),
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          border: Border.all(color: const Color(0xFF282C2C)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C9191),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(35),
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
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
          ],
        ),
      ),
    );
  }

  void _showBankInfoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AdaptiveGlassContainer.bottomSheet(
          glassEnabled: false,
          androidSurfaceColor: const Color(0xFF1A1D1D),
          topRadius: AppRadius.radiusSheet,
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
                      borderRadius: BorderRadius.circular(AppRadius.dragHandle),
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
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                    border: Border.all(color: const Color(0xFF282C2C)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2121),
                          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
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
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
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
                      FlashSnackBar.showInfo(
                        context,
                        'Bank verification & routing tools are active.',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEC200),
                      foregroundColor: const Color(0xFF121414),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
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
          );
        },
      );
  }

  void _showInstantTransferModal(BuildContext context) {
    final nextPayout = _earningsData.nextPayoutAmount;
    final wholePart = nextPayout.truncate();
    final centsPart =
        ((nextPayout - wholePart) * 100).round().toString().padLeft(2, '0');
    final formattedWhole = _formatWithCommas(wholePart);
    final fee = nextPayout * 0.015;
    final netAmount = nextPayout - fee;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AdaptiveGlassContainer.bottomSheet(
          glassEnabled: false,
          androidSurfaceColor: const Color(0xFF1A1D1D),
          topRadius: AppRadius.radiusSheet,
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
                      borderRadius: BorderRadius.circular(AppRadius.dragHandle),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.goldContainer,
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                        border: Border.all(color: AppTheme.goldBorder, width: 1),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: AppTheme.gold,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Instant Stripe Transfer',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Direct deposit via Stripe Connect',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8C9191),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121414),
                    borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                    border: Border.all(color: const Color(0xFF282C2C)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Available Balance',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8C9191),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '\$$formattedWhole.$centsPart',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transfer Fee (1.5%)',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8C9191),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '-\$${fee.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8C9191),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: Color(0xFF282C2C), height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'You Receive',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '\$${netAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121414),
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                    border: Border.all(color: const Color(0xFF282C2C)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance, color: Color(0xFF8C9191), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Destination: Chase Bank •••• 4821',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withAlpha(35),
                          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                        ),
                        child: Text(
                          'INSTANT',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF22C55E),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
                    key: const Key('confirm_instant_transfer_button'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      FlashSnackBar.showSuccess(
                        context,
                        'Transfer of \$${netAmount.toStringAsFixed(2)} initiated via Stripe Direct Deposit.',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: const Color(0xFF121414),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      ),
                    ),
                    child: Text(
                      'Transfer \$${netAmount.toStringAsFixed(2)} Now via Stripe',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      FlashSnackBar.showInfo(
                        context,
                        'Redirecting to Stripe Express Dashboard...',
                      );
                    },
                    icon: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF8C9191)),
                    label: Text(
                      'Manage in Stripe Express',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
  }

  List<DashboardAppointment> get _allHistoryAppointments {
    return [
      ...ArtistDashboardRepository.calendarAppointments,
      const DashboardAppointment(
        id: 'hist_alex_m',
        clientName: 'Alex M.',
        serviceType: 'Full Sleeve Session',
        duration: '4 hrs',
        time: '1:00 PM',
        date: 'Oct 24, 2023',
        placement: 'Full Right Arm',
        notes: 'Japanese dragon sleeve completion session. Shading and background waves finalized.',
        depositPaid: 150,
        fullPrice: 800,
        artworkImageUrl: 'https://images.unsplash.com/photo-1598371839696-5c5bb00bdc28?auto=format&fit=crop&w=400&q=80',
        visitType: 'Session Inking',
      ),
      const DashboardAppointment(
        id: 'hist_sarah_t',
        clientName: 'Sarah T.',
        serviceType: 'Custom Flash',
        duration: '1.5 hrs',
        time: '3:30 PM',
        date: 'Oct 22, 2023',
        placement: 'Forearm',
        notes: 'Floral flash with fine line botanicals.',
        depositPaid: 50,
        fullPrice: 250,
        artworkImageUrl: 'https://images.unsplash.com/photo-1562962230-16e4623d36e6?auto=format&fit=crop&w=400&q=80',
        visitType: 'Flash Tattoo',
      ),
      const DashboardAppointment(
        id: 'hist_marcus_k',
        clientName: 'Marcus K.',
        serviceType: 'Fine Line Floral',
        duration: '2 hrs',
        time: '11:00 AM',
        date: 'Oct 15, 2023',
        placement: 'Ribs',
        notes: 'Delicate fine line peony.',
        depositPaid: 60,
        fullPrice: 320,
        artworkImageUrl: 'https://images.unsplash.com/photo-1543852786-1cf6624b9987?auto=format&fit=crop&w=400&q=80',
        visitType: 'Fine Line',
      ),
      const DashboardAppointment(
        id: 'hist_elena_r',
        clientName: 'Elena R.',
        serviceType: 'Micro Realism Eye',
        duration: '2.5 hrs',
        time: '4:00 PM',
        date: 'Oct 10, 2023',
        placement: 'Bicep',
        notes: 'Realistic eye portrait with geometric framing.',
        depositPaid: 90,
        fullPrice: 450,
        artworkImageUrl: 'https://images.unsplash.com/photo-1568515045052-f9a854d70bfd?auto=format&fit=crop&w=400&q=80',
        visitType: 'Custom Tattoo',
      ),
      const DashboardAppointment(
        id: 'hist_dave_l',
        clientName: 'Dave L.',
        serviceType: 'Traditional Dagger',
        duration: '2 hrs',
        time: '2:30 PM',
        date: 'Sep 29, 2023',
        placement: 'Calf',
        notes: 'Classic bold line dagger piercing a black rose.',
        depositPaid: 60,
        fullPrice: 300,
        artworkImageUrl: 'https://images.unsplash.com/photo-1611501275019-9b5cda994e8d?auto=format&fit=crop&w=400&q=80',
        visitType: 'Traditional',
      ),
    ];
  }

  List<DashboardAppointment> get _filteredHistoryAppointments {
    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) {
      return _allHistoryAppointments;
    }
    return _allHistoryAppointments.where((apt) {
      final matchesClient = apt.clientName.toLowerCase().contains(query);
      final matchesService = apt.serviceType.toLowerCase().contains(query);
      final matchesVisitType = apt.effectiveVisitType.toLowerCase().contains(query);
      final matchesDate = apt.date.toLowerCase().contains(query);
      final matchesNotes = apt.notes.toLowerCase().contains(query);
      final matchesId = apt.id.toLowerCase().contains(query);
      return matchesClient ||
          matchesService ||
          matchesVisitType ||
          matchesDate ||
          matchesNotes ||
          matchesId;
    }).toList();
  }

  Map<String, List<DashboardAppointment>> _groupAppointmentsByDay(
    List<DashboardAppointment> appointments,
  ) {
    final groups = <String, List<DashboardAppointment>>{};
    for (final apt in appointments) {
      final key = apt.date;
      groups.putIfAbsent(key, () => []).add(apt);
    }
    return groups;
  }

  Widget _buildEarningsTabBar() {
    return Container(
      key: const Key('earnings_segmented_tab_bar'),
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.all(AppSpacing.spaceXxs),
      decoration: BoxDecoration(
        color: const Color(0xFF191B1B),
        borderRadius: BorderRadius.circular(AppRadius.radiusFull),
        border: Border.all(color: const Color(0xFF262929)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              tab: ArtistEarningsTab.overview,
              label: 'Overview',
              key: const Key('earnings_tab_overview'),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              tab: ArtistEarningsTab.history,
              label: 'History',
              key: const Key('earnings_tab_history'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required ArtistEarningsTab tab,
    required String label,
    required Key key,
  }) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      key: key,
      onTap: () {
        setState(() {
          _selectedTab = tab;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF252828) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
          border: isSelected
              ? Border.all(color: const Color(0xFFEEC200).withAlpha(160), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF8C9191),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    final filtered = _filteredHistoryAppointments;
    final groups = _groupAppointmentsByDay(filtered);

    return Column(
      key: const Key('earnings_history_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHistorySearchBar(),
        const SizedBox(height: 18),
        if (filtered.isEmpty)
          _buildEmptyHistoryState()
        else
          ...groups.entries.map((entry) {
            final dateLabel = entry.key;
            final items = entry.value;
            final dailyTotal = items.fold<int>(0, (sum, i) => sum + i.fullPrice);

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateLabel,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2121),
                            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                            border: Border.all(color: const Color(0xFF282C2C)),
                          ),
                          child: Text(
                            '\$${_formatWithCommas(dailyTotal)}',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFEEC200),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...items.map((apt) => _buildHistoryAppointmentCard(apt)),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildHistorySearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(AppRadius.radiusFull),
        border: Border.all(color: const Color(0xFF282C2C)),
      ),
      child: TextField(
        key: const Key('history_search_field'),
        controller: _searchController,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search client, service, or date...',
          hintStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8C9191),
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF8C9191), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  key: const Key('history_search_clear_button'),
                  icon: const Icon(Icons.clear, color: Color(0xFF8C9191), size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
          });
        },
      ),
    );
  }

  Widget _buildEmptyHistoryState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF191B1B),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: const Color(0xFF262929)),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 40, color: Color(0xFF8C9191)),
          const SizedBox(height: 12),
          Text(
            'No sessions found',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matches for "$_searchQuery". Try a different search.'
                : 'No session history found.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryAppointmentCard(DashboardAppointment item) {
    return Container(
      key: Key('history_appointment_item_${item.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(
          color: const Color(0xFF282C2C),
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AppointmentDetailScreen(appointment: item),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: item.artworkImageUrl.isNotEmpty
                      ? FlashImage(
                          urlOrPath: item.artworkImageUrl,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: const Color(0xFF252828),
                            child: const Icon(Icons.brush, color: Color(0xFF8C9191), size: 22),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF252828),
                          child: const Icon(Icons.brush, color: Color(0xFF8C9191), size: 22),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.clientName,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF262929),
                            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                          ),
                          child: Text(
                            item.effectiveVisitType.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8C9191),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${item.date} • ${item.time} • ${item.duration}',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${item.fullPrice}',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEEC200),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF8C9191),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          12,
          AppSpacing.screenGutter,
          MediaQuery.paddingOf(context).bottom + (widget.isEmbeddedInTab ? 80 : 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopActionBar(),
            const SizedBox(height: 12),
            _buildEarningsTabBar(),
            if (_selectedTab == ArtistEarningsTab.overview) ...[
              _buildHeroAvailableFundsCard(),
              const SizedBox(height: 24),
              _buildUtilityActionsRow(),
            ] else ...[
              _buildHistoryView(),
            ],
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
            left: AppSpacing.screenGutter,
            right: AppSpacing.screenGutter,
            bottom: MediaQuery.paddingOf(context).bottom + AppTheme.navBarBottomMargin,
            child: FlashBottomNavBar(
              currentIndex: 4,
              onTap: (index) {
                if (widget.onBack != null && index != 4) {
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
            size: 43,
            color: Color(0xFFEEC200),
          ),
        GestureDetector(
          key: const Key('earnings_avatar_button'),
          onTap: _navigateToAccountScreen,
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

  /// Hero Available Funds Card reflecting Stripe API balance with embedded YTD Earnings
  Widget _buildHeroAvailableFundsCard() {
    final availableFunds = _earningsData.availableFundsAmount;
    final wholePart = availableFunds.truncate();
    final centsPart =
        ((availableFunds - wholePart) * 100).round().toString().padLeft(2, '0');
    final formattedWhole = _formatWithCommas(wholePart);

    return Container(
      key: const Key('available_funds_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF232727),
            Color(0xFF1B1E1E),
            Color(0xFF161818),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.radiusXl),
        border: Border.all(
          color: AppTheme.goldBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withAlpha(20),
            blurRadius: 28,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        key: const Key('next_payout_card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Available Funds Header & Stripe Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF22C55E),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x6622C55E),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Available Funds',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF15221B),
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withAlpha(80),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    const _BanknoteIconWidget(),
                    const SizedBox(width: 6),
                    Text(
                      'Stripe Active',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF22C55E),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Large Available Balance Display
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '\$',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.gold,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: formattedWhole,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '.$centsPart',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFC5C8C8),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bank destination subtext pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF121414).withAlpha(180),
              borderRadius: BorderRadius.circular(AppRadius.radiusFull),
              border: Border.all(color: const Color(0xFF2A2E2E)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_rounded,
                  color: AppTheme.gold,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ready to transfer to Chase Bank •••• 4821',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFFC5C8C8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Primary Transfer to Bank CTA
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              key: const Key('instant_transfer_button'),
              onPressed: () => _showInstantTransferModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: const Color(0xFF121414),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFF121414)),
                  const SizedBox(width: 6),
                  Text(
                    'Transfer to Bank',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(color: Color(0xFF2E3232), height: 1),
          ),
          // Integrated YTD Earnings Container inside Hero Card
          Container(
            key: const Key('hero_ytd_earnings'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141717),
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              border: Border.all(color: const Color(0xFF282C2C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_earningsData.ytdYear} YTD EARNINGS',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Container(
                      key: const Key('metric_card_ytd'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2121),
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                      ),
                      child: Text(
                        'YTD ${_earningsData.ytdYear}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C9191),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_formatWithCommas(_earningsData.ytdAmount)}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total volume earned this year',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'MTD: \$${_formatWithCommas(_earningsData.mtdAmount)}',
                      key: const Key('metric_card_mtd'),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF22C55E),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2121),
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
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

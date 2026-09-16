import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/flash_bottom_nav_bar.dart';
import '../../theme/app_theme.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard_data.dart';
import '../../services/auth_service.dart';
import '../../widgets/tattoo_machine_icon.dart';
import '../../widgets/flash_image.dart';
import '../artist_profile_screen.dart';
import '../splash_screen.dart';
import 'appointment_detail_screen.dart';
import 'artist_calendar_screen.dart';
import 'booking_request_detail_screen.dart';

/// The central Artist Dashboard screen shown after completing account onboarding
/// or when returning to the app as an authenticated artist.
class ArtistDashboardScreen extends StatefulWidget {
  final Artist? artist;
  final AuthService? authService;

  const ArtistDashboardScreen({
    super.key,
    this.artist,
    this.authService,
  });

  @override
  State<ArtistDashboardScreen> createState() => _ArtistDashboardScreenState();
}

class _ArtistDashboardScreenState extends State<ArtistDashboardScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  int _selectedTabIndex = 0;

  late DashboardAppointment _nextAppointment;
  late List<DashboardAppointment> _todaySchedule;
  late List<BookingRequest> _pendingRequests;
  late ArtistDashboardStats _stats;
  final Set<String> _expandedAppointmentIds = {};

  void _toggleAppointmentExpanded(String id) {
    setState(() {
      if (_expandedAppointmentIds.contains(id)) {
        _expandedAppointmentIds.remove(id);
      } else {
        _expandedAppointmentIds.add(id);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _nextAppointment = ArtistDashboardRepository.nextAppointment;
    _todaySchedule = List.from(ArtistDashboardRepository.todaySchedule);
    _pendingRequests = List.from(ArtistDashboardRepository.pendingRequests);
    _stats = ArtistDashboardRepository.stats;
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

  String _formatCurrentDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final month = months[now.month - 1];
    final day = now.day;
    final suffix = _getDaySuffix(day);
    return '$month $day$suffix';
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
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
                _buildAvatarWidget(radius: 36),
                const SizedBox(height: 12),
                Text(
                  _artistDisplayName,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Portland, OR • Flash & Custom',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  key: const Key('modal_view_public_profile'),
                  leading: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFFEEC200)),
                  title: Text(
                    'View Public Profile',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Preview how clients see your portfolio & flash',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C9191),
                      fontSize: 12,
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
                  leading: const Icon(Icons.tune_outlined, color: Colors.white),
                  title: Text(
                    'Edit Pricing & Policies',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF8C9191)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pricing & Policies settings coming soon.'),
                        backgroundColor: Color(0xFF262929),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedTabIndex,
            children: [
              _buildDashboardContent(),
              _buildCalendarTab(),
              _buildMessagesPlaceholder(),
              _buildEarningsPlaceholder(),
            ],
          ),
          Positioned(
            left: AppTheme.navBarHorizontalMargin,
            right: AppTheme.navBarHorizontalMargin,
            bottom: MediaQuery.paddingOf(context).bottom + AppTheme.navBarBottomMargin,
            child: FlashBottomNavBar(
              currentIndex: _selectedTabIndex,
              onTap: (index) => setState(() => _selectedTabIndex = index),
              role: 'artist',
            ),
          ),
        ],
      ),
    );
  }

  /// Primary Artist Dashboard Content (Tab 0: Bookings)
  Widget _buildDashboardContent() {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopActionBar(),
            const SizedBox(height: 20),
            _buildHeaderTitleRow(),
            const SizedBox(height: 20),
            _buildMetricsRow(),
            const SizedBox(height: 20),
            _buildHeroNextAppointmentCard(),
            const SizedBox(height: 28),
            _buildTodayScheduleSection(),
            const SizedBox(height: 28),
            _buildPendingRequestsSection(),
          ],
        ),
      ),
    );
  }

  /// Top action bar with tattoo machine icon on the left and artist avatar on the right
  Widget _buildTopActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const TattooMachineIcon(
          key: Key('tattoo_machine_logo'),
          size: 28,
          color: Color(0xFFEEC200),
        ),
        GestureDetector(
          key: const Key('artist_avatar_button'),
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

  /// Header row with artist name on left and date on right
  Widget _buildHeaderTitleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            _artistDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _formatCurrentDate(),
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFEEC200),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// Two side-by-side metric cards: Bookings this week and New requests
  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            key: const Key('metric_bookings_this_week'),
            count: '${_stats.bookingsThisWeek}',
            label: 'BOOKINGS THIS WEEK',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            key: const Key('metric_new_requests'),
            count: '${_stats.newRequests}',
            label: 'NEW REQUESTS',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required Key key,
    required String count,
    required String label,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2E3232),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF919696),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  /// Large hero Next Appointment card with tattoo artwork background
  Widget _buildHeroNextAppointmentCard() {
    return Container(
      key: const Key('hero_next_appointment_card'),
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: _nextAppointment.artworkImageUrl.isNotEmpty &&
                  _nextAppointment.artworkImageUrl.startsWith('assets/')
              ? AssetImage(_nextAppointment.artworkImageUrl) as ImageProvider
              : const AssetImage('assets/images/flash_tiger_tattoo.jpg'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: Stack(
        children: [
          // Gradient scrim overlay for contrast & readability
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  Color(0xF0121414),
                  Color(0xB3121414),
                  Color(0x33121414),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Next Appointment',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEEC200),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _nextAppointment.time,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _nextAppointment.clientName,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_nextAppointment.serviceType} • ${_nextAppointment.duration}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFD4D8D8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    key: const Key('hero_view_details_button'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppointmentDetailScreen(
                            appointment: _nextAppointment,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEC200),
                      foregroundColor: const Color(0xFF121414),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      'View Details',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Today's Schedule section with "VIEW ALL" header and itemized schedule list
  Widget _buildTodayScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's Schedule",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              key: const Key('schedule_view_all_button'),
              onTap: () {
                setState(() => _selectedTabIndex = 1);
              },
              child: Text(
                'VIEW ALL',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEEC200),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF191C1C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF262929),
              width: 1.0,
            ),
          ),
          child: Column(
            children: List.generate(_todaySchedule.length, (index) {
              final item = _todaySchedule[index];
              final isLast = index == _todaySchedule.length - 1;
              final isExpanded = _expandedAppointmentIds.contains(item.id);
              return Column(
                children: [
                  _buildScheduleRow(item, isExpanded),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: isExpanded
                        ? _buildExpandedAppointmentDetails(item)
                        : const SizedBox.shrink(),
                  ),
                  if (!isLast)
                    const Divider(
                      color: Color(0xFF242727),
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleRow(DashboardAppointment item, bool isExpanded) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: Key('schedule_row_content_${item.id}'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AppointmentDetailScreen(appointment: item),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    // Status dot
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.dotColor,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Time
                    Text(
                      item.time,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Client Name & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.clientName,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.serviceType} • ${item.duration}',
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
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Unfold/swap vertical arrows button
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('schedule_arrow_${item.id}'),
              onTap: () => _toggleAppointmentExpanded(item.id),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isExpanded
                      ? const Color(0xFF2D3030)
                      : const Color(0xFF242727),
                  border: Border.all(
                    color: isExpanded
                        ? const Color(0xFFEEC200).withAlpha(140)
                        : const Color(0xFF333737),
                    width: 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isExpanded ? Icons.unfold_less : Icons.unfold_more,
                  color: isExpanded
                      ? const Color(0xFFEEC200)
                      : const Color(0xFF8C9191),
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Expanded view showing details of an appointment within the container
  Widget _buildExpandedAppointmentDetails(DashboardAppointment item) {
    return Container(
      key: Key('expanded_schedule_panel_${item.id}'),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141616),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF262929),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork & Primary Meta Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.artworkImageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 58,
                      height: 58,
                      color: const Color(0xFF222525),
                      child: FlashImage(
                        urlOrPath: item.artworkImageUrl,
                        fit: BoxFit.cover,
                        errorWidget: const Icon(
                          Icons.brush,
                          color: Color(0xFF8C9191),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: item.dotColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.dotColor.withAlpha(100),
                              ),
                            ),
                            child: Text(
                              item.isConsultation ? 'Consultation' : 'Confirmed',
                              style: GoogleFonts.plusJakartaSans(
                                color: item.dotColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 13,
                                  color: Color(0xFFEEC200),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.placement,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFFD4D8D8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Estimate: ',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8C9191),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '\$${item.fullPrice}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Due: ',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8C9191),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '\$${item.balanceDue}',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFEEC200),
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

            // Notes Bubble
            if (item.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF282C2C),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.notes_rounded,
                        size: 13,
                        color: Color(0xFF8C9191),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.notes,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFB0B5B5),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons Row
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      key: Key('expanded_view_details_${item.id}'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AppointmentDetailScreen(appointment: item),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEEC200),
                        foregroundColor: const Color(0xFF121414),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'View Details',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 34,
                  child: OutlinedButton.icon(
                    key: Key('expanded_message_${item.id}'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Opening chat with ${item.clientName}...'),
                          backgroundColor: const Color(0xFF1E2020),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF333737)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      size: 13,
                      color: Color(0xFFEEC200),
                    ),
                    label: Text(
                      'Message',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Pending Requests section with red counter badge and request cards
  Widget _buildPendingRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEF4444),
              ),
              alignment: Alignment.center,
              child: Text(
                '${_stats.pendingCount}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Pending Requests',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._pendingRequests.map((req) => _buildPendingRequestCard(req)),
      ],
    );
  }

  Widget _buildPendingRequestCard(BookingRequest request) {
    return Container(
      key: Key('pending_card_${request.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF282C2C),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.clientName,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        request.conceptDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFB0B5B5),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      request.timeAgo,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 54,
                        height: 54,
                        color: const Color(0xFF2A2E2E),
                        child: FlashImage(
                          urlOrPath: request.sketchImageUrl,
                          fit: BoxFit.cover,
                          errorWidget: const Icon(
                            Icons.brush,
                            color: Color(0xFF8C9191),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(
            color: Color(0xFF282C2C),
            height: 1,
          ),
          InkWell(
            key: Key('view_details_link_${request.id}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingRequestDetailScreen(request: request),
                ),
              );
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Text(
                'View details',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEEC200),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Companion Calendar Tab (Tab 1)
  Widget _buildCalendarTab() {
    return ArtistCalendarScreen(
      artist: widget.artist,
      authService: _authService,
      isEmbeddedInTab: true,
    );
  }

  Widget _buildMessagesPlaceholder() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client Messages',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time consultations and booking inquiries.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C9191),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _buildMessageItem(
              name: 'Sarah Jenkins',
              preview: 'Super excited for the tiger session today!',
              time: '9:15 AM',
              unread: true,
            ),
            _buildMessageItem(
              name: 'Sally McField',
              preview: 'Will bring the reference sketches at 12:30.',
              time: 'Yesterday',
              unread: false,
            ),
            _buildMessageItem(
              name: 'Jennie Banks',
              preview: 'Sent the deposit confirmation, see you at 6:30!',
              time: '2d ago',
              unread: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem({
    required String name,
    required String preview,
    required String time,
    required bool unread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unread ? const Color(0xFFEEC200).withAlpha(100) : const Color(0xFF282C2C),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF262929),
            child: Text(
              name[0],
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEEC200),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  style: GoogleFonts.plusJakartaSans(
                    color: unread ? Colors.white : const Color(0xFF8C9191),
                    fontSize: 13,
                    fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsPlaceholder() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Earnings & Payouts',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track completed tattoos, deposits, and payouts.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C9191),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2121),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF282C2C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIS WEEK',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF8C9191),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$2,450.00',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+18% from last week • Next payout Wednesday',
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
    );
  }
}

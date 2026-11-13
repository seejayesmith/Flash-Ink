import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/mock/mock_data_config.dart';
import '../../core/widgets/flash_bottom_nav_bar.dart';
import '../../features/messages/domain/models/message_thread.dart';
import '../../features/messages/presentation/screens/chat_conversation_screen.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard_data.dart';
import '../../repositories/artist_repository.dart';
import '../../services/auth_service.dart';
import '../../services/booking_sync_service.dart';
import '../../widgets/artist_top_bar.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import 'appointment_detail_screen.dart';
import 'artist_account_screen.dart';
import 'artist_books_screen.dart';
import 'artist_calendar_screen.dart';
import 'artist_collections_screen.dart';
import 'artist_earnings_screen.dart';
import 'booking_request_detail_screen.dart';
import 'books_status_card.dart';
import 'create_book_drop_screen.dart';

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
  Artist? _liveArtist;

  DashboardAppointment? get _activeNextAppointment => ArtistDashboardRepository.activeNextAppointment;
  List<DashboardAppointment> get _todaySchedule => ArtistDashboardRepository.todaySchedule;
  List<BookingRequest> get _pendingRequests => ArtistDashboardRepository.pendingRequests;
  ArtistDashboardStats get _stats => ArtistDashboardRepository.stats;
  final Set<String> _expandedAppointmentIds = {};

  @override
  void initState() {
    super.initState();
    ArtistDashboardRepository.pendingRequestsNotifier.addListener(_onRepositoryUpdated);
    _loadLiveArtistProfile();
  }

  Future<void> _loadLiveArtistProfile() async {
    try {
      String? authUid;
      String? authPhotoUrl;
      try {
        final user = _authService.currentUser;
        authUid = user?.uid;
        authPhotoUrl = user?.photoURL;
      } catch (_) {}

      final uid = widget.artist?.id ?? authUid;
      if (uid != null && uid.isNotEmpty) {
        BookingSyncService.hydrateArtistDataFromCloud(uid);
      }

      if (authUid == null || authUid.isEmpty) return;
      final db = FirebaseFirestore.instance;
      final doc = await db
          .collection('artists')
          .doc(authUid)
          .get();
      if (doc.exists && doc.data() != null && mounted) {
        var loaded = Artist.fromMap(doc.data()!, doc.id);
        if (loaded.avatarUrl.trim().isEmpty) {
          String? fallbackPhoto = authPhotoUrl?.trim();
          if (fallbackPhoto == null || fallbackPhoto.isEmpty) {
            final userDoc = await db.collection('users').doc(authUid).get();
            final uData = userDoc.data();
            final rawUserPhoto = uData?['photoUrl'] ??
                uData?['photoURL'] ??
                uData?['avatarUrl'];
            if (rawUserPhoto is String && rawUserPhoto.trim().isNotEmpty) {
              fallbackPhoto = rawUserPhoto.trim();
            }
          }
          if (fallbackPhoto != null &&
              fallbackPhoto.isNotEmpty &&
              !fallbackPhoto.startsWith('local://')) {
            loaded = loaded.copyWith(avatarUrl: fallbackPhoto);
            await ArtistRepository.syncUnifiedProfilePhoto(
              uid: authUid,
              photoUrl: fallbackPhoto,
              firestore: db,
              createArtistIfMissing: true,
            );
          }
        }
        if (mounted) {
          setState(() {
            _liveArtist = loaded;
          });
        }
        if (!MockDataConfig.isEnabled &&
            ArtistDashboardRepository.booksSchedule.locationNote.isEmpty) {
          final studioPart = loaded.studioName.isNotEmpty
              ? loaded.studioName
              : loaded.studioType;
          final locNote = [
            if (studioPart.isNotEmpty) studioPart,
            if (loaded.location.isNotEmpty) loaded.location,
          ].join(' • ');
          if (locNote.isNotEmpty) {
            ArtistDashboardRepository.booksSchedule =
                ArtistDashboardRepository.booksSchedule.copyWith(
              locationNote: locNote,
            );
          }
        }
      }
    } catch (_) {
      // Safe fallback in offline or widget test environments
    }
  }

  @override
  void dispose() {
    ArtistDashboardRepository.pendingRequestsNotifier.removeListener(_onRepositoryUpdated);
    super.dispose();
  }

  void _onRepositoryUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleAppointmentExpanded(String id) {
    setState(() {
      if (_expandedAppointmentIds.contains(id)) {
        _expandedAppointmentIds.remove(id);
      } else {
        _expandedAppointmentIds.add(id);
      }
    });
  }

  Artist? get _resolvedArtist => _liveArtist ?? widget.artist;

  String get _artistDisplayName {
    final resolved = _resolvedArtist;
    if (resolved != null && resolved.name.isNotEmpty) {
      return resolved.name;
    }
    try {
      final user = _authService.currentUser;
      if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!;
      }
    } catch (_) {}
    return MockDataConfig.isEnabled ? 'OddMaree' : 'Artist';
  }

  String get _avatarUrl {
    final resolved = _resolvedArtist;
    if (resolved != null && resolved.avatarUrl.isNotEmpty) {
      return resolved.avatarUrl;
    }
    try {
      final user = _authService.currentUser;
      if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
        return user.photoURL!;
      }
    } catch (_) {}
    return MockDataConfig.isEnabled
        ? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80'
        : '';
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

  Future<void> _navigateToAccountScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistAccountScreen(
          artist: _resolvedArtist,
          authService: _authService,
        ),
      ),
    );
    if (mounted) {
      await _loadLiveArtistProfile();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _navigateToMessagesScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF121414),
          body: _buildMessagesPlaceholder(showTopBar: true),
        ),
      ),
    );
  }

  Widget _buildCollectionsTab() {
    return ArtistCollectionsScreen(
      artist: _resolvedArtist,
      authService: _authService,
      onNavigateToAccount: _navigateToAccountScreen,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: FlashNavBarScope(
        child: Stack(
          children: [
            IndexedStack(
              index: _selectedTabIndex,
              children: [
                _buildDashboardContent(),
                _buildCalendarTab(),
                _buildCollectionsTab(),
                _buildBooksTab(),
                _buildEarningsTab(),
              ],
            ),
            Positioned(
              left: AppSpacing.screenGutter,
              right: AppSpacing.screenGutter,
              bottom: MediaQuery.paddingOf(context).bottom + AppTheme.navBarBottomMargin,
              child: FlashBottomNavBar(
                currentIndex: _selectedTabIndex,
                onTap: (index) => setState(() => _selectedTabIndex = index),
                role: 'artist',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Primary Artist Dashboard Content (Tab 0: Bookings)
  Widget _buildDashboardContent() {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          12,
          AppSpacing.screenGutter,
          MediaQuery.paddingOf(context).bottom + 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopActionBar(),
            const SizedBox(height: 20),
            _buildHeaderTitleRow(),
            const SizedBox(height: 20),
            _buildMetricsRow(),
            const SizedBox(height: 20),
            BooksStatusCard(
              onPlanDrop: () async {
                final result = await CreateBookDropScreen.show(context, artist: _resolvedArtist);
                if (result == true) {
                  setState(() {});
                }
              },
              onReviewRequests: () {
                final requests = ArtistDashboardRepository.pendingRequests;
                if (requests.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingRequestDetailScreen(request: requests.first),
                    ),
                  ).then((_) => setState(() {}));
                } else {
                  setState(() => _selectedTabIndex = 1); // Switch to Calendar / Schedule tab
                }
              },
              onAddDays: () async {
                final result = await CreateBookDropScreen.show(context, artist: _resolvedArtist);
                if (result == true) {
                  setState(() {});
                }
              },
              onOpenSettings: () {
                setState(() => _selectedTabIndex = 3); // Switch to Books & Schedule Tab
              },
              onStatusChanged: () => setState(() {}),
            ),
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

  /// Top action bar with tattoo machine icon on the left, Messages icon button,
  /// and artist avatar on the right.
  Widget _buildTopActionBar({
    Key logoKey = const Key('tattoo_machine_logo'),
    Key avatarKey = const Key('artist_avatar_button'),
    Key messagesKey = const Key('top_action_messages_button'),
  }) {
    return ArtistTopBar(
      logoKey: logoKey,
      avatarKey: avatarKey,
      messagesKey: messagesKey,
      onMessagesTap: _navigateToMessagesScreen,
      onAvatarTap: _navigateToAccountScreen,
      avatarChild: _buildAvatarWidget(radius: 18),
      artistId: _resolvedArtist?.id ?? _authService.currentUser?.uid,
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


  /// Large hero Next Appointment card with tattoo artwork background (or styled empty state in live mode)
  Widget _buildHeroNextAppointmentCard() {
    final nextApt = _activeNextAppointment;
    if (nextApt == null) {
      return Container(
        key: const Key('hero_next_appointment_card'),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF191C1C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF282C2C),
            width: 1.0,
          ),
        ),
        child: Column(
          key: const Key('hero_next_appointment_empty_state'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEC200).withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: Color(0xFFEEC200),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Next Appointment',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEEC200),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'No Upcoming Appointments',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Open your books or share your profile link with clients to start scheduling tattoo sessions.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C9191),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  key: const Key('hero_empty_manage_books_button'),
                  onPressed: () {
                    setState(() => _selectedTabIndex = 3);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEC200),
                    foregroundColor: const Color(0xFF121414),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_rounded, size: 15),
                  label: Text(
                    'Manage Books',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  key: const Key('hero_empty_view_calendar_button'),
                  onPressed: () {
                    setState(() => _selectedTabIndex = 1);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF333737)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'View Calendar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      key: const Key('hero_next_appointment_card'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentDetailScreen(
              appointment: nextApt,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: nextApt.artworkImageUrl.isNotEmpty &&
                    nextApt.artworkImageUrl.startsWith('assets/')
                ? AssetImage(nextApt.artworkImageUrl) as ImageProvider
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
                        nextApt.time,
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
                    nextApt.clientName,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${nextApt.serviceType} • ${nextApt.duration}',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFD4D8D8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
          child: _todaySchedule.isEmpty
              ? Padding(
                  key: const Key('no_today_schedule_empty_state'),
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Center(
                    child: Text(
                      'No sessions scheduled for today.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : Column(
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
                      FlashSnackBar.showInfo(
                        context,
                        'Opening chat with ${item.clientName}...',
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

  Future<void> _openBookingRequestDetail(BookingRequest request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingRequestDetailScreen(request: request),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  /// Pending Requests section with right-aligned request counter and cards
  Widget _buildPendingRequestsSection() {
    final count = _pendingRequests.length;
    final countText = count == 1 ? '1 request' : '$count requests';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Pending Requests',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              countText,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.navInactiveAlt,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_pendingRequests.isEmpty)
          Container(
            key: const Key('no_pending_requests_empty_state'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2121),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF282C2C),
                width: 1.0,
              ),
            ),
            child: Text(
              'No pending requests',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.navInactiveAlt,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
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
          InkWell(
            onTap: () => _openBookingRequestDetail(request),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
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
          ),
          const Divider(
            color: Color(0xFF282C2C),
            height: 1,
          ),
          InkWell(
            key: Key('view_details_link_${request.id}'),
            onTap: () => _openBookingRequestDetail(request),
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
      artist: _resolvedArtist,
      authService: _authService,
      isEmbeddedInTab: true,
    );
  }

  String _formatRelativeThreadTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  Widget _buildMessagesPlaceholder({bool showTopBar = true}) {
    final liveThreads = MessageThread.liveThreads;
    final useMock = MockDataConfig.isEnabled;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.paddingOf(context).bottom + 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTopBar) ...[
              _buildTopActionBar(
                logoKey: const Key('messages_tattoo_machine_logo'),
                avatarKey: const Key('messages_artist_avatar_button'),
              ),
              const SizedBox(height: 20),
            ],
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
            if (useMock) ...[
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
            ] else if (liveThreads.isEmpty) ...[
              Container(
                key: const Key('no_client_messages_empty_state'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF191C1C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF282C2C),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF8C9191),
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No client conversations yet',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Confirmed bookings and approved custom requests will open direct message threads here.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              for (final thread in liveThreads)
                GestureDetector(
                  key: Key('artist_message_thread_${thread.id}'),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatConversationScreen(
                          thread: thread,
                          isArtistView: true,
                        ),
                      ),
                    );
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  child: _buildMessageItem(
                    name: (thread.clientName != null && thread.clientName!.isNotEmpty)
                        ? thread.clientName!
                        : (thread.flashTitleContext ?? 'Client Inquiry'),
                    preview: thread.lastMessage,
                    time: _formatRelativeThreadTime(thread.lastMessageTime),
                    unread: thread.unreadCount > 0,
                  ),
                ),
            ],
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
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0] : '',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEEC200),
                  fontWeight: FontWeight.bold,
                ),
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

  /// Companion Books Tab (Tab 3)
  Widget _buildBooksTab() {
    return ArtistBooksScreen(
      artist: _resolvedArtist,
      authService: _authService,
      isEmbeddedInTab: true,
    );
  }

  /// Companion Earnings Tab (Tab 4)
  Widget _buildEarningsTab() {
    return ArtistEarningsScreen(
      artist: _resolvedArtist,
      authService: _authService,
      isEmbeddedInTab: true,
    );
  }
}

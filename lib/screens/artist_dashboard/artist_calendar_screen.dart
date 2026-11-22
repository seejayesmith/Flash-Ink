import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/mock/mock_data_config.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard/artist_books_schedule.dart';
import '../../models/artist_dashboard/book_drop.dart';
import '../../models/artist_dashboard/dashboard_appointment.dart';
import '../../repositories/artist_dashboard_repository.dart';
import '../../services/auth_service.dart';
import '../../services/booking_sync_service.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/artist_top_bar.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/user_avatar.dart';
import 'artist_account_screen.dart';
import 'calendar/artist_calendar_card.dart';
import 'calendar/calendar_schedule_section.dart';
import 'calendar/manage_time_off_sheet.dart';

/// Interactive artist calendar screen matching the Flash.Ink dark aesthetic.
///
/// Can be presented as an independent full-screen route or embedded seamlessly
/// into Tab 1 of the [ArtistDashboardScreen].
class ArtistCalendarScreen extends StatefulWidget {
  final Artist? artist;
  final AuthService? authService;
  final bool isEmbeddedInTab;
  final VoidCallback? onBack;
  final DateTime? initialDate;
  final VoidCallback? onNavigateToDashboard;

  const ArtistCalendarScreen({
    super.key,
    this.artist,
    this.authService,
    this.isEmbeddedInTab = false,
    this.onBack,
    this.initialDate,
    this.onNavigateToDashboard,
  });

  @override
  State<ArtistCalendarScreen> createState() => _ArtistCalendarScreenState();
}

class _ArtistCalendarScreenState extends State<ArtistCalendarScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  late DateTime _activeMonth;
  late DateTime _selectedDate;
  bool _isPickingMonth = false;

  static const List<String> _monthShortNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    final baseDate = widget.initialDate ?? DateTime.now();
    _activeMonth = DateTime(baseDate.year, baseDate.month, 1);
    _selectedDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    ArtistDashboardRepository.pendingRequestsNotifier
        .addListener(_onRepositoryChanged);
    final uid = widget.artist?.id ?? _authService.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      BookingSyncService.hydrateArtistDataFromCloud(uid);
    }
  }

  @override
  void dispose() {
    ArtistDashboardRepository.pendingRequestsNotifier
        .removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String get _artistDisplayName {
    if (widget.artist != null && widget.artist!.name.isNotEmpty) {
      return widget.artist!.name;
    }
    try {
      final user = _authService.currentUser;
      if (user != null &&
          user.displayName != null &&
          user.displayName!.isNotEmpty) {
        return user.displayName!;
      }
    } catch (_) {}
    return MockDataConfig.isEnabled ? 'OddMaree' : 'Artist';
  }

  String get _avatarUrl {
    if (widget.artist != null && widget.artist!.avatarUrl.isNotEmpty) {
      return widget.artist!.avatarUrl;
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

  String? get _resolvedArtistId {
    final widgetId = widget.artist?.id;
    if (widgetId != null && widgetId.isNotEmpty) return widgetId;
    try {
      final authId = _authService.currentUser?.uid;
      if (authId != null && authId.isNotEmpty) return authId;
    } catch (_) {}
    final syncedId = BookingSyncService.resolveCurrentUid('');
    return syncedId.isNotEmpty ? syncedId : null;
  }

  void _selectMonth(int month) {
    setState(() {
      _activeMonth = DateTime(_activeMonth.year, month, 1);
      final daysInMonth = DateTime(_activeMonth.year, month + 1, 0).day;
      final newDay = _selectedDate.day.clamp(1, daysInMonth);
      _selectedDate = DateTime(_activeMonth.year, month, newDay);
      _isPickingMonth = false;
    });
  }

  void _selectYear(int year) {
    setState(() {
      _activeMonth = DateTime(year, _activeMonth.month, 1);
      final daysInMonth = DateTime(year, _activeMonth.month + 1, 0).day;
      final newDay = _selectedDate.day.clamp(1, daysInMonth);
      _selectedDate = DateTime(year, _activeMonth.month, newDay);
    });
  }

  void _prevMonth() {
    setState(() {
      final prevMonth = _activeMonth.month == 1 ? 12 : _activeMonth.month - 1;
      final prevYear =
          _activeMonth.month == 1 ? _activeMonth.year - 1 : _activeMonth.year;
      _activeMonth = DateTime(prevYear, prevMonth, 1);
      final daysInMonth = DateTime(prevYear, prevMonth + 1, 0).day;
      final newDay = _selectedDate.day.clamp(1, daysInMonth);
      _selectedDate = DateTime(prevYear, prevMonth, newDay);
      _isPickingMonth = false;
    });
  }

  void _nextMonth() {
    setState(() {
      final nextMonth = _activeMonth.month == 12 ? 1 : _activeMonth.month + 1;
      final nextYear =
          _activeMonth.month == 12 ? _activeMonth.year + 1 : _activeMonth.year;
      _activeMonth = DateTime(nextYear, nextMonth, 1);
      final daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
      final newDay = _selectedDate.day.clamp(1, daysInMonth);
      _selectedDate = DateTime(nextYear, nextMonth, newDay);
      _isPickingMonth = false;
    });
  }

  List<DashboardAppointment> get _currentAppointments =>
      ArtistDashboardRepository.getAppointmentsForDate(_selectedDate);

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String get _scheduleSectionTitle {
    final isExplicitInitial = widget.initialDate != null &&
        _selectedDate.year == widget.initialDate!.year &&
        _selectedDate.month == widget.initialDate!.month &&
        _selectedDate.day == widget.initialDate!.day;
    if (_isToday(_selectedDate) || isExplicitInitial) {
      return "Today's Schedule";
    }
    final month = _monthShortNames[_selectedDate.month - 1];
    return '$month ${_selectedDate.day} Schedule';
  }

  List<CustomHold> _holdsForDate(DateTime date) {
    final key = ArtistBooksSchedule.dateKey(date);
    return ArtistDashboardRepository.customHolds
        .where((h) => !h.isExpired && ArtistBooksSchedule.dateKey(h.date) == key)
        .toList();
  }

  ({int appointments, int holds}) _countConflicts(Iterable<DateTime> dates) {
    int aptCount = 0;
    int holdCount = 0;
    for (final d in dates) {
      aptCount += ArtistDashboardRepository.getAppointmentsForDate(d).length;
      holdCount += _holdsForDate(d).length;
    }
    return (appointments: aptCount, holds: holdCount);
  }

  Future<void> _confirmAndBlockDates(
    List<DateTime> dates, {
    VoidCallback? onApplied,
  }) async {
    if (dates.isEmpty) return;
    final conflicts = _countConflicts(dates);
    if (conflicts.appointments == 0 && conflicts.holds == 0) {
      ArtistDashboardRepository.blockDates(dates, artistId: _resolvedArtistId);
      setState(() {});
      FlashSnackBar.showInfo(
        context,
        dates.length == 1
            ? 'Date marked as time off.'
            : '${dates.length} dates blocked off.',
      );
      onApplied?.call();
      return;
    }

    final nounParts = <String>[
      if (conflicts.appointments > 0)
        '${conflicts.appointments} confirmed ${conflicts.appointments == 1 ? 'appointment' : 'appointments'}',
      if (conflicts.holds > 0)
        '${conflicts.holds} active 24h ${conflicts.holds == 1 ? 'hold' : 'holds'}',
    ];
    final targetLabel =
        dates.length == 1 ? 'this date' : 'these ${dates.length} dates';

    final confirmed = await showBlockDatesConflictDialog(
      context: context,
      title: 'Existing Bookings on Date',
      content:
          'You have ${nounParts.join(' and ')} on $targetLabel. Existing bookings and holds stay intact while remaining open slots will be blocked.',
    );
    if (confirmed != true || !mounted) return;

    ArtistDashboardRepository.blockDates(dates, artistId: _resolvedArtistId);
    setState(() {});
    FlashSnackBar.showInfo(
      context,
      dates.length == 1
          ? 'Date blocked out.'
          : '${dates.length} dates blocked out.',
    );
    onApplied?.call();
  }

  void _openManageTimeOffSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManageTimeOffSheet(
        initialMonth: _activeMonth,
        artistId: _resolvedArtistId,
        countConflicts: _countConflicts,
        onDatesChanged: () {
          if (mounted) setState(() {});
        },
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom +
        (widget.isEmbeddedInTab ? 80.0 : 16.0);
    final appointments = _currentAppointments;

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            12,
            AppSpacing.screenGutter,
            bottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopActionBar(),
              const SizedBox(height: 20),
              _buildTitleRow(),
              const SizedBox(height: 18),
              ArtistCalendarCard(
                activeMonth: _activeMonth,
                selectedDate: _selectedDate,
                isPickingMonth: _isPickingMonth,
                holdsForDate: _holdsForDate,
                onPrevMonth: _prevMonth,
                onNextMonth: _nextMonth,
                onToggleMonthPicker: () =>
                    setState(() => _isPickingMonth = !_isPickingMonth),
                onSelectMonth: _selectMonth,
                onSelectYear: _selectYear,
                onSelectDate: (date) => setState(() => _selectedDate = date),
              ),
              const SizedBox(height: 26),
              CalendarScheduleHeader(
                sectionTitle: _scheduleSectionTitle,
                selectedDate: _selectedDate,
                sessionCount: appointments.length,
                artistId: _resolvedArtistId,
                onBlockSelectedDate: () =>
                    _confirmAndBlockDates([_selectedDate]),
                onScheduleMutated: () => setState(() {}),
              ),
              const SizedBox(height: 14),
              CalendarScheduleList(
                selectedDate: _selectedDate,
                appointments: appointments,
                holds: _holdsForDate(_selectedDate),
                artistId: _resolvedArtistId,
                onBlockSelectedDate: () =>
                    _confirmAndBlockDates([_selectedDate]),
                onScheduleMutated: () => setState(() {}),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopActionBar() {
    final canGoBack = !widget.isEmbeddedInTab && Navigator.canPop(context);

    return ArtistTopBar(
      leadingWidget: canGoBack
          ? IconButton(
              key: const Key('calendar_back_button'),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 22,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
            )
          : null,
      logoKey: const Key('calendar_tattoo_machine_logo'),
      onLogoTap: widget.onNavigateToDashboard ??
          (canGoBack ? () => Navigator.pop(context) : null),
      messagesKey: const Key('calendar_messages_button'),
      avatarKey: const Key('calendar_artist_avatar_button'),
      onMessagesTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MessagesScreen()),
        );
      },
      onAvatarTap: _navigateToAccountScreen,
      avatarChild: UserAvatar(
        imageUrl: _avatarUrl,
        displayName: _artistDisplayName,
        radius: 18,
        fallbackInitial: 'O',
        initialFontSize: 18 * 0.9,
      ),
      artistId: widget.artist?.id ?? _authService.currentUser?.uid,
    );
  }

  Widget _buildTitleRow() {
    final schedule = ArtistDashboardRepository.booksSchedule;
    final overrideCount =
        schedule.blockedDates.length + schedule.openOverrideDates.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Calendar',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          key: const Key('calendar_manage_time_off_button'),
          onTap: _openManageTimeOffSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2121),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: overrideCount > 0
                    ? AppTheme.gold.withAlpha(110)
                    : const Color(0xFF2C2F30),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.date_range_rounded,
                  size: 14,
                  color: AppTheme.gold,
                ),
                const SizedBox(width: 5),
                Text(
                  overrideCount > 0
                      ? 'Time Off ($overrideCount)'
                      : 'Manage Time Off',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

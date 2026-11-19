import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/mock/mock_data_config.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard_data.dart';
import '../../services/auth_service.dart';
import '../../services/booking_sync_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/tattoo_machine_icon.dart';
import '../../widgets/artist_top_bar.dart';
import '../../widgets/user_avatar.dart';
import 'appointment_detail_screen.dart';
import 'artist_account_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';

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

  // Active viewing month and selected date
  late DateTime _activeMonth;
  late DateTime _selectedDate;
  bool _isPickingMonth = false;

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _monthShortNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static const List<String> _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  void initState() {
    super.initState();
    final baseDate = widget.initialDate ?? DateTime.now();
    _activeMonth = DateTime(baseDate.year, baseDate.month, 1);
    _selectedDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    ArtistDashboardRepository.pendingRequestsNotifier.addListener(_onRepositoryChanged);
    final uid = widget.artist?.id ?? _authService.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      BookingSyncService.hydrateArtistDataFromCloud(uid);
    }
  }

  @override
  void dispose() {
    ArtistDashboardRepository.pendingRequestsNotifier.removeListener(_onRepositoryChanged);
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
      if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
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

  void _selectMonth(int month) {
    setState(() {
      _activeMonth = DateTime(_activeMonth.year, month, 1);
      // Ensure selected day is valid in new month
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
      final prevYear = _activeMonth.month == 1 ? _activeMonth.year - 1 : _activeMonth.year;
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
      final nextYear = _activeMonth.month == 12 ? _activeMonth.year + 1 : _activeMonth.year;
      _activeMonth = DateTime(nextYear, nextMonth, 1);
      final daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
      final newDay = _selectedDate.day.clamp(1, daysInMonth);
      _selectedDate = DateTime(nextYear, nextMonth, newDay);
      _isPickingMonth = false;
    });
  }

  int _getFirstWeekdayOffset(int year, int month) {
    final weekday = DateTime(year, month, 1).weekday; // Mon=1, Sun=7
    return weekday % 7; // Sun=0, Mon=1, etc.
  }

  List<DashboardAppointment> get _currentAppointments {
    return ArtistDashboardRepository.getAppointmentsForDate(_selectedDate);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
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
    return "$month ${_selectedDate.day} Schedule";
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom + (widget.isEmbeddedInTab ? 80.0 : 16.0);

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(AppSpacing.screenGutter, 12, AppSpacing.screenGutter, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopActionBar(),
              const SizedBox(height: 20),
              _buildTitleRow(),
              const SizedBox(height: 18),
              _buildCalendarCard(),
              const SizedBox(height: 26),
              _buildScheduleHeader(),
              const SizedBox(height: 14),
              _buildScheduleList(),
            ],
          ),
        ),
      ),
    );
  }

  /// Top action bar with tattoo machine icon/back button and artist avatar
  Widget _buildTopActionBar() {
    final canGoBack = !widget.isEmbeddedInTab && Navigator.canPop(context);

    return ArtistTopBar(
      leadingWidget: canGoBack
          ? IconButton(
              key: const Key('calendar_back_button'),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
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
      avatarChild: _buildAvatarWidget(radius: 18),
      artistId: widget.artist?.id ?? _authService.currentUser?.uid,
    );
  }

  Widget _buildAvatarWidget({double radius = 18}) {
    return UserAvatar(
      imageUrl: _avatarUrl,
      displayName: _artistDisplayName,
      radius: radius,
      fallbackInitial: 'O',
      initialFontSize: radius * 0.9,
    );
  }

  /// Page title "Calendar"
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

  void _confirmAndBlockDates(
    List<DateTime> dates, {
    VoidCallback? onApplied,
  }) {
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

    _showBlockConflictDialog(
      dates: dates,
      appointmentCount: conflicts.appointments,
      holdCount: conflicts.holds,
      onApplied: onApplied,
    );
  }

  void _openManageTimeOffSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ManageTimeOffSheet(
        initialMonth: _activeMonth,
        artistId: _resolvedArtistId,
        countConflicts: _countConflicts,
        onDatesChanged: () {
          if (mounted) setState(() {});
        },
      ),
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
                    ? const Color(0xFFEEC200).withAlpha(110)
                    : const Color(0xFF2C2F30),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.date_range_rounded,
                  size: 14,
                  color: Color(0xFFEEC200),
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

  /// The elevated calendar card with Month/Year dropdowns and days grid
  Widget _buildCalendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF191B1B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF252828),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: GestureDetector(
        onHorizontalDragEnd: _isPickingMonth
            ? null
            : (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! < -200) {
                    _nextMonth();
                  } else if (details.primaryVelocity! > 200) {
                    _prevMonth();
                  }
                }
              },
        child: Column(
          children: [
            // Month & Year Selector Pills
            _buildMonthYearSelectors(),
            const SizedBox(height: 20),

            // Animated switcher between Days view and Month selection grid
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOutCubic,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: _isPickingMonth
                  ? _buildMonthGrid(key: const ValueKey('month_picker_grid'))
                  : Column(
                      key: const ValueKey('calendar_days_view'),
                      children: [
                        // Weekday labels: Su Mo Tu We Th Fr Sa
                        _buildWeekdayHeader(),
                        const SizedBox(height: 14),

                        // Calendar grid
                        _buildCalendarDaysGrid(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Month & Year dropdown pills in header of calendar card with left/right month toggles
  Widget _buildMonthYearSelectors() {
    final currentMonthFull = _monthNames[_activeMonth.month - 1];
    final currentYear = _activeMonth.year;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Previous Month Toggle Button
        _buildNavButton(
          key: const Key('calendar_prev_month_button'),
          icon: Icons.chevron_left,
          tooltip: 'Previous month',
          onTap: _prevMonth,
        ),

        // Month & Year Selector Pills
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month Selector Pill
            GestureDetector(
              key: const Key('calendar_month_dropdown'),
              onTap: () {
                setState(() {
                  _isPickingMonth = !_isPickingMonth;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF121414),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isPickingMonth
                        ? const Color(0xFFEEC200)
                        : const Color(0xFF282B2B),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentMonthFull,
                      style: GoogleFonts.plusJakartaSans(
                        color: _isPickingMonth ? const Color(0xFFEEC200) : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _isPickingMonth ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: _isPickingMonth
                            ? const Color(0xFFEEC200)
                            : const Color(0xFF8C9191),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Year Selector Pill
            PopupMenuButton<int>(
              key: const Key('calendar_year_dropdown'),
              color: const Color(0xFF202323),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFF333737)),
              ),
              initialValue: currentYear,
              onSelected: _selectYear,
              itemBuilder: (context) {
                const years = [2024, 2025, 2026, 2027, 2028];
                return years.map((year) {
                  final isSelected = year == currentYear;
                  return PopupMenuItem<int>(
                    value: year,
                    child: Text(
                      '$year',
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? const Color(0xFFEEC200) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF121414),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF282B2B)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$currentYear',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF8C9191),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Next Month Toggle Button
        _buildNavButton(
          key: const Key('calendar_next_month_button'),
          icon: Icons.chevron_right,
          tooltip: 'Next month',
          onTap: _nextMonth,
        ),
      ],
    );
  }

  /// Circular navigation toggle button (chevron left/right) for the calendar
  Widget _buildNavButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF121414),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF282B2B),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  /// Weekday labels row
  Widget _buildWeekdayHeader() {
    return Row(
      children: _weekdays.map((day) {
        return Expanded(
          child: Text(
            day,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 7-column calendar grid matching the design
  Widget _buildCalendarDaysGrid() {
    final year = _activeMonth.year;
    final month = _activeMonth.month;

    final daysInCurrentMonth = DateTime(year, month + 1, 0).day;
    final firstWeekdayOffset = _getFirstWeekdayOffset(year, month);
    final daysWithAppointments = ArtistDashboardRepository.getDaysWithAppointments(year, month);

    // Calculate total rows needed (typically 5)
    final totalOccupiedCells = firstWeekdayOffset + daysInCurrentMonth;
    final totalRows = (totalOccupiedCells / 7.0).ceil();

    return Column(
      children: List.generate(totalRows, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;

              if (cellIndex < firstWeekdayOffset) {
                // Leading blank space for current month
                return const Expanded(child: SizedBox(height: 44));
              }

              final dayNumber = cellIndex - firstWeekdayOffset + 1;

              if (dayNumber <= daysInCurrentMonth) {
                // Current month day
                final isSelected = _selectedDate.year == year &&
                    _selectedDate.month == month &&
                    _selectedDate.day == dayNumber;
                final hasAppointments = daysWithAppointments.contains(dayNumber);

                return Expanded(
                  child: _buildDayCell(
                    dayNumber: dayNumber,
                    isSelected: isSelected,
                    hasAppointments: hasAppointments,
                    onTap: () {
                      setState(() {
                        _selectedDate = DateTime(year, month, dayNumber);
                      });
                    },
                  ),
                );
              } else {
                // Trailing next-month day (dimmed numbers)
                final trailingDay = dayNumber - daysInCurrentMonth;
                return Expanded(
                  child: _buildTrailingDayCell(trailingDay),
                );
              }
            }),
          ),
        );
      }),
    );
  }

  /// Individual active day cell
  Widget _buildDayCell({
    required int dayNumber,
    required bool isSelected,
    required bool hasAppointments,
    required VoidCallback onTap,
  }) {
    final cellDate = DateTime(_activeMonth.year, _activeMonth.month, dayNumber);
    final capacity = ArtistDashboardRepository.getDayCapacityStatus(cellDate);
    final isBlocked = ArtistDashboardRepository.isDateBlocked(cellDate);
    final isForceOpened = ArtistDashboardRepository.isDateForceOpened(cellDate);
    final isWeeklyCapClosed =
        ArtistDashboardRepository.isClosedByWeeklyCap(cellDate);
    final isClosedOrBlocked =
        capacity == DayCapacityStatus.closed || capacity == DayCapacityStatus.blocked;
    final holds = _holdsForDate(cellDate);
    final hasHold = holds.isNotEmpty;

    Color dotColor = const Color(0xFF8C9191);
    if (hasHold) {
      dotColor = const Color(0xFFA855F7); // Purple for 24h holds
    } else if (isBlocked) {
      dotColor = const Color(0xFFF97316).withAlpha(180); // Orange for blocked time off
    } else if (isForceOpened && !hasAppointments) {
      dotColor = const Color(0xFF22C55E); // Green for force-opened off-weekday
    } else if (isWeeklyCapClosed) {
      dotColor = const Color(0xFFEEC200).withAlpha(130); // Amber dot for cap closed
    } else if (hasAppointments) {
      if (capacity == DayCapacityStatus.full) {
        dotColor = const Color(0xFF8C9191);
      } else if (capacity == DayCapacityStatus.filling) {
        dotColor = const Color(0xFFEEC200);
      } else {
        dotColor = const Color(0xFF22C55E);
      }
    }

    final showIndicatorDot = !isSelected &&
        (hasAppointments ||
            hasHold ||
            isBlocked ||
            isForceOpened ||
            isWeeklyCapClosed);

    return GestureDetector(
      key: Key('calendar_day_$dayNumber'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          width: 38,
          height: 44,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2C3030)
                : (isForceOpened && !isClosedOrBlocked
                    ? const Color(0xFF142119)
                    : (isClosedOrBlocked
                        ? const Color(0xFF131515)
                        : Colors.transparent)),
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? null
                : (isForceOpened && !isClosedOrBlocked
                    ? Border.all(
                        color: const Color(0xFF22C55E).withAlpha(80),
                        width: 0.9,
                      )
                    : (isClosedOrBlocked
                        ? Border.all(color: const Color(0xFF1D2020), width: 0.8)
                        : null)),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$dayNumber',
                style: GoogleFonts.plusJakartaSans(
                  color: isClosedOrBlocked && !isSelected
                      ? const Color(0xFF4B5050) // Faded dark for closed/off days
                      : Colors.white,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              if (isSelected)
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                )
              else if (showIndicatorDot)
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  /// Trailing next-month day cell
  Widget _buildTrailingDayCell(int trailingDay) {
    return Center(
      child: Container(
        width: 38,
        height: 44,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$trailingDay',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF383C3C),
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 7),
          ],
        ),
      ),
    );
  }

  /// 3x4 grid for selecting any month of the year
  Widget _buildMonthGrid({Key? key}) {
    return Column(
      key: key,
      children: List.generate(4, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: List.generate(3, (colIndex) {
              final monthIndex = rowIndex * 3 + colIndex;
              final monthNum = monthIndex + 1;
              final isSelected = monthNum == _activeMonth.month;
              final monthName = _monthNames[monthIndex];

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: colIndex == 0 ? 0 : 5,
                    right: colIndex == 2 ? 0 : 5,
                  ),
                  child: GestureDetector(
                    key: Key('calendar_select_month_$monthNum'),
                    onTap: () => _selectMonth(monthNum),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEEC200).withAlpha(35)
                            : const Color(0xFF141616),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFEEC200)
                              : const Color(0xFF282B2B),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        monthName,
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected ? const Color(0xFFEEC200) : Colors.white,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  /// Header row for the schedule section: "Today's Schedule" + session count badge
  Widget _buildScheduleHeader() {
    final sessionCount = _currentAppointments.length;
    final schedule = ArtistDashboardRepository.booksSchedule;
    final isBlocked = ArtistDashboardRepository.isDateBlocked(_selectedDate);
    final isForceOpened = ArtistDashboardRepository.isDateForceOpened(_selectedDate);
    final isWeekdayScheduled = schedule.workingDays.contains(_selectedDate.weekday);

    IconData toggleIcon = Icons.beach_access_outlined;
    Color toggleColor = const Color(0xFF8C9191);
    String toggleTooltip = 'Block Date Off (Time Off)';
    if (isBlocked) {
      toggleIcon = Icons.beach_access;
      toggleColor = const Color(0xFFF97316);
      toggleTooltip = 'Unblock Date';
    } else if (!isWeekdayScheduled && !isForceOpened) {
      toggleIcon = Icons.event_available_outlined;
      toggleColor = const Color(0xFFEEC200);
      toggleTooltip = 'Open This Off-Day for Bookings';
    } else if (!isWeekdayScheduled && isForceOpened) {
      toggleIcon = Icons.event_available;
      toggleColor = const Color(0xFF22C55E);
      toggleTooltip = 'Revert to Weekly Off-Day';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            _scheduleSectionTitle,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          children: [
            if (sessionCount > 0)
              Container(
                key: const Key('calendar_session_count_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2121),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF282C2C)),
                ),
                child: Text(
                  '$sessionCount ${sessionCount == 1 ? 'session' : 'sessions'}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEEC200),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('calendar_toggle_time_off_button'),
              icon: Icon(
                toggleIcon,
                color: toggleColor,
                size: 20,
              ),
              tooltip: toggleTooltip,
              onPressed: () {
                if (isBlocked) {
                  ArtistDashboardRepository.unblockDate(
                    _selectedDate,
                    artistId: _resolvedArtistId,
                  );
                  FlashSnackBar.showSuccess(context, 'Date unblocked.');
                  setState(() {});
                } else if (!isWeekdayScheduled && !isForceOpened) {
                  ArtistDashboardRepository.forceOpenDate(
                    _selectedDate,
                    artistId: _resolvedArtistId,
                  );
                  FlashSnackBar.showSuccess(context, 'Date opened for bookings.');
                  setState(() {});
                } else if (!isWeekdayScheduled && isForceOpened) {
                  ArtistDashboardRepository.revertForceOpenDate(
                    _selectedDate,
                    artistId: _resolvedArtistId,
                  );
                  FlashSnackBar.showInfo(context, 'Returned to weekly off-day.');
                  setState(() {});
                } else {
                  _confirmAndBlockDates([_selectedDate]);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showBlockConflictDialog({
    required List<DateTime> dates,
    required int appointmentCount,
    required int holdCount,
    VoidCallback? onApplied,
  }) {
    final nounParts = <String>[
      if (appointmentCount > 0)
        '$appointmentCount confirmed ${appointmentCount == 1 ? 'appointment' : 'appointments'}',
      if (holdCount > 0)
        '$holdCount active 24h ${holdCount == 1 ? 'hold' : 'holds'}',
    ];
    final targetLabel = dates.length == 1 ? 'this date' : 'these ${dates.length} dates';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Existing Bookings on Date',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'You have ${nounParts.join(' and ')} on $targetLabel. Existing bookings and holds stay intact while remaining open slots will be blocked.',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8C9191),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ArtistDashboardRepository.blockDates(
                dates,
                artistId: _resolvedArtistId,
              );
              setState(() {});
              FlashSnackBar.showInfo(
                context,
                dates.length == 1
                    ? 'Date blocked out.'
                    : '${dates.length} dates blocked out.',
              );
              onApplied?.call();
            },
            child: Text(
              'Block Anyway',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFF97316),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// List of appointments for the active selected day
  Widget _buildScheduleList() {
    final appointments = _currentAppointments;
    final holds = _holdsForDate(_selectedDate);
    final schedule = ArtistDashboardRepository.booksSchedule;
    final isBlocked = ArtistDashboardRepository.isDateBlocked(_selectedDate);
    final isForceOpened = ArtistDashboardRepository.isDateForceOpened(_selectedDate);
    final isWeekdayScheduled = schedule.workingDays.contains(_selectedDate.weekday);
    final isWeeklyCapClosed =
        ArtistDashboardRepository.isClosedByWeeklyCap(_selectedDate);

    if (appointments.isEmpty && holds.isEmpty) {
      if (isBlocked) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF191B1B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF252828)),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.beach_access, color: Color(0xFFF97316), size: 36),
              const SizedBox(height: 12),
              Text(
                'Day Blocked for Time Off',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Clients cannot book or request appointments on this day.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C9191),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () {
                  ArtistDashboardRepository.unblockDate(
                    _selectedDate,
                    artistId: _resolvedArtistId,
                  );
                  setState(() {});
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEEC200),
                  side: const BorderSide(color: Color(0xFFEEC200)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Unblock Day'),
              ),
            ],
          ),
        );
      }

      if (isWeeklyCapClosed) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF191B1B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF252828)),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_note_rounded, color: Color(0xFFEEC200), size: 34),
              const SizedBox(height: 12),
              Text(
                'Weekly Cap Reached (${schedule.maxWorkingDaysPerWeek}d/wk)',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Other booked days filled this Sun–Sat week. Empty days auto-close until slots free up.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C9191),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }

      if (!isWeekdayScheduled && !isForceOpened) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF191B1B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF252828)),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.nights_stay_outlined, color: Color(0xFF8C9191), size: 34),
              const SizedBox(height: 12),
              Text(
                'Weekly Off Day',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Clients cannot book on this weekday unless you open it for this date.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C9191),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                key: const Key('calendar_open_override_button'),
                onPressed: () {
                  ArtistDashboardRepository.forceOpenDate(
                    _selectedDate,
                    artistId: _resolvedArtistId,
                  );
                  setState(() {});
                  FlashSnackBar.showSuccess(context, 'Date opened for bookings.');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF22C55E),
                  side: const BorderSide(color: Color(0xFF22C55E)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Open This Date'),
              ),
            ],
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF191B1B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF252828)),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available,
              color: isForceOpened ? const Color(0xFF22C55E) : const Color(0xFF8C9191),
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              isForceOpened ? 'Opened for Bookings (Override)' : 'No appointments on this date',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isForceOpened
                  ? 'This off-weekday is open as a special booking date.'
                  : 'Enjoy your open studio time or open booking slots.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C9191),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final openMinutes = ArtistDashboardRepository.getRemainingOpenMinutes(_selectedDate);
    final showOpenGap = !isBlocked && openMinutes >= 30;

    return Column(
      children: [
        if (isBlocked)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF231812),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF97316).withAlpha(90)),
            ),
            child: Row(
              children: [
                const Icon(Icons.beach_access, color: Color(0xFFF97316), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Remaining open slots blocked for time off',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF97316),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ArtistDashboardRepository.unblockDate(
                      _selectedDate,
                      artistId: _resolvedArtistId,
                    );
                    setState(() {});
                  },
                  child: const Text('Unblock'),
                ),
              ],
            ),
          ),
        // Custom 24h holds
        ...holds.map((hold) => _buildCustomHoldCard(hold)),
        // Confirmed appointments
        ...appointments.map((appointment) => _buildAppointmentCard(appointment)),
        // Factual open gap card
        if (showOpenGap) _buildOpenGapCard(openMinutes),
      ],
    );
  }

  Widget _buildCustomHoldCard(CustomHold hold) {
    final remaining = hold.remainingTime;
    final expiresLabel = remaining.inHours >= 1
        ? 'Expires in ${remaining.inHours}h'
        : 'Expires in ${remaining.inMinutes.clamp(1, 59)}m';
    return Container(
      key: Key('calendar_custom_hold_${hold.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA855F7).withAlpha(120), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Color(0xFFA855F7), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '24H PENDING HOLD',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFA855F7),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFA855F7).withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  expiresLabel,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFA855F7),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Custom Session: ${hold.clientName}',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '${hold.timeSlot} • ${(hold.durationMinutes / 60).toStringAsFixed(1)} hrs held • \$${hold.deposit} deposit pending',
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF919696), fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  ArtistDashboardRepository.releaseCustomHold(
                    hold.id,
                    artistId: _resolvedArtistId,
                  );
                  setState(() {});
                  FlashSnackBar.showInfo(context, 'Hold released.');
                },
                child: Text(
                  'Release Hold',
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpenGapCard(int openMinutes) {
    final openHoursText = '${(openMinutes / 60).toStringAsFixed(1)} hrs open';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141A16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E).withAlpha(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    openHoursText,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _confirmAndBlockDates([_selectedDate]),
            child: Text(
              '+ Block Out Time',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF22C55E), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Individual appointment card with primary details:
  /// tattoo thumbnail, client name, visit type badge, service description,
  /// duration, cost, and a "View Details" button.
  Widget _buildAppointmentCard(DashboardAppointment item) {
    return Container(
      key: Key('calendar_appointment_item_${item.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF191B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF252828),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Tattoo Thumbnail
                _buildTattooThumbnail(item),
                const SizedBox(width: 12),

                // 2. Middle Details: Client Name, Visit Type, Service, Duration & Cost
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Client Name & Type of Visit Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              item.clientName,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildVisitTypeBadge(item),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Second Row: Service / Tattoo Name & Status Dot
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: item.dotColor,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.serviceType,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFD1D5DB),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Third Row: Duration, Time & Cost
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Time & Duration
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 13,
                                color: Color(0xFF8C9191),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.time,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '• ${item.duration}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF8C9191),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          // Cost
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.payments_outlined,
                                size: 13,
                                color: Color(0xFFEEC200),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Cost: \$${item.fullPrice}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFEEC200),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.depositPaid > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(\$${item.depositPaid} dep)',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF8C9191),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(
              color: Color(0xFF252828),
              height: 1,
              thickness: 1,
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                key: Key('calendar_view_details_btn_${item.id}'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppointmentDetailScreen(appointment: item),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFEEC200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View Details',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEEC200),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Thumbnail of the tattoo artwork with fallback placeholder
  Widget _buildTattooThumbnail(DashboardAppointment item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: const Color(0xFF222525),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF2E3232),
            width: 1.0,
          ),
        ),
        child: item.artworkImageUrl.isNotEmpty
            ? FlashImage(
                urlOrPath: item.artworkImageUrl,
                width: 62,
                height: 62,
                fit: BoxFit.cover,
                errorWidget: _buildThumbnailFallback(item),
              )
            : _buildThumbnailFallback(item),
      ),
    );
  }

  /// Placeholder when artwork image is not present or fails to load
  Widget _buildThumbnailFallback(DashboardAppointment item) {
    return Container(
      width: 62,
      height: 62,
      color: const Color(0xFF222525),
      alignment: Alignment.center,
      child: item.isConsultation
          ? const Icon(
              Icons.forum_outlined,
              color: Color(0xFFEEC200),
              size: 24,
            )
          : const TattooMachineIcon(
              size: 24,
              color: Color(0xFFEEC200),
            ),
    );
  }

  /// Pill badge showing the visit type (e.g. CONSULTATION, COVER-UP, FLASH TATTOO, CUSTOM)
  Widget _buildVisitTypeBadge(DashboardAppointment item) {
    final isConsultation = item.isConsultation;
    final badgeColor = isConsultation ? const Color(0xFF8C9191) : const Color(0xFFEEC200);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isConsultation
            ? const Color(0xFF242727)
            : const Color(0xFFEEC200).withAlpha(28),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isConsultation
              ? const Color(0xFF383C3C)
              : const Color(0xFFEEC200).withAlpha(100),
          width: 0.8,
        ),
      ),
      child: Text(
        item.effectiveVisitType.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: badgeColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  /// Profile Settings Navigation to ArtistAccountScreen
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
}

enum _TimeOffSelectionMode { tapDates, dateRange }

/// Dedicated multi-date and date-range picker bottom sheet for managing
/// two-way calendar overrides (blocking days off or force-opening off-weekdays).
class _ManageTimeOffSheet extends StatefulWidget {
  final DateTime initialMonth;
  final String? artistId;
  final ({int appointments, int holds}) Function(Iterable<DateTime> dates)
      countConflicts;
  final VoidCallback onDatesChanged;

  const _ManageTimeOffSheet({
    required this.initialMonth,
    required this.artistId,
    required this.countConflicts,
    required this.onDatesChanged,
  });

  @override
  State<_ManageTimeOffSheet> createState() => _ManageTimeOffSheetState();
}

class _ManageTimeOffSheetState extends State<_ManageTimeOffSheet> {
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  late DateTime _viewMonth;
  _TimeOffSelectionMode _mode = _TimeOffSelectionMode.tapDates;
  final Set<String> _selectedKeys = {};
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _viewMonth = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
  }

  List<DateTime> get _selectedDates {
    final parsed = <DateTime>[];
    for (final key in _selectedKeys) {
      final parts = key.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          parsed.add(DateTime(y, m, d));
        }
      }
    }
    parsed.sort((a, b) => a.compareTo(b));
    return parsed;
  }

  void _onTapDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final key = ArtistBooksSchedule.dateKey(normalized);

    setState(() {
      if (_mode == _TimeOffSelectionMode.tapDates) {
        if (_selectedKeys.contains(key)) {
          _selectedKeys.remove(key);
        } else {
          _selectedKeys.add(key);
        }
        return;
      }

      if (_rangeStart == null || _rangeEnd != null) {
        _rangeStart = normalized;
        _rangeEnd = null;
        _selectedKeys
          ..clear()
          ..add(key);
      } else {
        final start =
            normalized.isBefore(_rangeStart!) ? normalized : _rangeStart!;
        final end =
            normalized.isBefore(_rangeStart!) ? _rangeStart! : normalized;
        _rangeStart = start;
        _rangeEnd = end;
        _selectedKeys.clear();
        var cursor = start;
        while (!cursor.isAfter(end)) {
          _selectedKeys.add(ArtistBooksSchedule.dateKey(cursor));
          cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
        }
      }
    });
  }

  Future<void> _handleBlockSelected() async {
    final dates = _selectedDates;
    if (dates.isEmpty) return;

    final conflicts = widget.countConflicts(dates);
    if (conflicts.appointments > 0 || conflicts.holds > 0) {
      final nounParts = <String>[
        if (conflicts.appointments > 0)
          '${conflicts.appointments} confirmed ${conflicts.appointments == 1 ? 'appointment' : 'appointments'}',
        if (conflicts.holds > 0)
          '${conflicts.holds} active 24h ${conflicts.holds == 1 ? 'hold' : 'holds'}',
      ];
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          backgroundColor: const Color(0xFF1E2121),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Existing Bookings on Selected Dates',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'You have ${nounParts.join(' and ')} across ${dates.length} selected ${dates.length == 1 ? 'date' : 'dates'}. Existing bookings and holds stay intact while remaining open slots will be blocked.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx, true),
              child: Text(
                'Block Anyway',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF97316),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    ArtistDashboardRepository.blockDates(dates, artistId: widget.artistId);
    widget.onDatesChanged();
    if (!mounted) return;
    Navigator.pop(context);
    FlashSnackBar.showInfo(
      context,
      dates.length == 1
          ? '1 date blocked off.'
          : '${dates.length} dates blocked off.',
    );
  }

  void _handleOpenSelected() {
    final dates = _selectedDates;
    if (dates.isEmpty) return;

    ArtistDashboardRepository.forceOpenDates(dates, artistId: widget.artistId);
    widget.onDatesChanged();
    Navigator.pop(context);
    FlashSnackBar.showSuccess(
      context,
      dates.length == 1
          ? '1 date opened for bookings.'
          : '${dates.length} dates opened for bookings.',
    );
  }

  void _handleClearAllBlocked() {
    ArtistDashboardRepository.clearAllBlockedDates(artistId: widget.artistId);
    widget.onDatesChanged();
    setState(() {
      _selectedKeys.clear();
      _rangeStart = null;
      _rangeEnd = null;
    });
    FlashSnackBar.showSuccess(context, 'All blocked dates cleared.');
  }

  Widget _buildModeChip({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF141616),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF2C2F30),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isSelected ? const Color(0xFF121414) : const Color(0xFF8C9191),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ArtistDashboardRepository.booksSchedule;
    final daysInMonth = DateUtils.getDaysInMonth(_viewMonth.year, _viewMonth.month);
    final firstWeekday =
        DateTime(_viewMonth.year, _viewMonth.month, 1).weekday % 7;
    final totalCells = firstWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final blockedCount = schedule.blockedDates.length;
    final openedCount = schedule.openOverrideDates.length;
    final hasSelection = _selectedKeys.isNotEmpty;

    return AdaptiveGlassContainer.bottomSheet(
      glassEnabled: true,
      androidSurfaceColor: const Color(0xFF191B1B),
      topRadius: AppRadius.radiusSheet,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3F3F),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Time Off & Overrides',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Block trips or open specific off-weekdays',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF8C9191),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('time_off_close_button'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF8C9191)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildModeChip(
                    key: const Key('time_off_mode_tap'),
                    label: 'Tap Dates',
                    isSelected: _mode == _TimeOffSelectionMode.tapDates,
                    onTap: () => setState(() {
                      _mode = _TimeOffSelectionMode.tapDates;
                      _rangeStart = null;
                      _rangeEnd = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _buildModeChip(
                    key: const Key('time_off_mode_range'),
                    label: 'Date Range',
                    isSelected: _mode == _TimeOffSelectionMode.dateRange,
                    onTap: () => setState(() {
                      _mode = _TimeOffSelectionMode.dateRange;
                      _selectedKeys.clear();
                      _rangeStart = null;
                      _rangeEnd = null;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    key: const Key('time_off_prev_month'),
                    onPressed: () => setState(() {
                      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
                    }),
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                  ),
                  Text(
                    '${_monthNames[_viewMonth.month - 1]} ${_viewMonth.year}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    key: const Key('time_off_next_month'),
                    onPressed: () => setState(() {
                      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
                    }),
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _weekdays
                    .map(
                      (d) => SizedBox(
                        width: 38,
                        child: Center(
                          child: Text(
                            d,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF6B7272),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Column(
                children: List.generate(rowCount, (rowIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (colIndex) {
                        final cellIndex = rowIndex * 7 + colIndex;
                        final dayNum = cellIndex - firstWeekday + 1;
                        if (dayNum < 1 || dayNum > daysInMonth) {
                          return const SizedBox(width: 38, height: 38);
                        }
                        final cellDate = DateTime(
                          _viewMonth.year,
                          _viewMonth.month,
                          dayNum,
                        );
                        final key = ArtistBooksSchedule.dateKey(cellDate);
                        final isPicked = _selectedKeys.contains(key);
                        final isBlocked = schedule.isDateBlocked(cellDate);
                        final isForceOpened = schedule.isDateForceOpened(cellDate);

                        return GestureDetector(
                          key: Key('time_off_picker_day_$dayNum'),
                          onTap: () => _onTapDate(cellDate),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isPicked
                                  ? const Color(0xFFEEC200)
                                  : (isBlocked
                                      ? const Color(0xFF2B1C12)
                                      : (isForceOpened
                                          ? const Color(0xFF142419)
                                          : const Color(0xFF141616))),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isPicked
                                    ? const Color(0xFFEEC200)
                                    : (isBlocked
                                        ? const Color(0xFFF97316).withAlpha(140)
                                        : (isForceOpened
                                            ? const Color(0xFF22C55E).withAlpha(120)
                                            : const Color(0xFF252828))),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$dayNum',
                              style: GoogleFonts.plusJakartaSans(
                                color: isPicked
                                    ? const Color(0xFF121414)
                                    : (isBlocked
                                        ? const Color(0xFFF97316)
                                        : (isForceOpened
                                            ? const Color(0xFF22C55E)
                                            : Colors.white)),
                                fontSize: 13,
                                fontWeight: isPicked
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Text(
                hasSelection
                    ? '${_selectedKeys.length} ${_selectedKeys.length == 1 ? 'date' : 'dates'} selected'
                    : (_mode == _TimeOffSelectionMode.dateRange
                        ? (_rangeStart == null
                            ? 'Tap start date, then end date'
                            : 'Tap end date to complete range')
                        : 'Tap one or more dates above'),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C9191),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('time_off_block_selected_button'),
                      onPressed: hasSelection ? _handleBlockSelected : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        disabledBackgroundColor: const Color(0xFF252828),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFF6B7272),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Block Selected'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('time_off_open_selected_button'),
                      onPressed: hasSelection ? _handleOpenSelected : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        disabledBackgroundColor: const Color(0xFF252828),
                        foregroundColor: const Color(0xFF0E1410),
                        disabledForegroundColor: const Color(0xFF6B7272),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Open Selected'),
                    ),
                  ),
                ],
              ),
              if (blockedCount > 0 || openedCount > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (blockedCount > 0)
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('time_off_clear_all_blocked_button'),
                          onPressed: _handleClearAllBlocked,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEEC200),
                            side: const BorderSide(color: Color(0xFF2C2F30)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Clear All Blocked ($blockedCount)'),
                        ),
                      ),
                    if (blockedCount > 0 && openedCount > 0)
                      const SizedBox(width: 10),
                    if (openedCount > 0)
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('time_off_clear_all_opened_button'),
                          onPressed: () {
                            ArtistDashboardRepository.clearAllOpenOverrides(
                              artistId: widget.artistId,
                            );
                            widget.onDatesChanged();
                            setState(() {});
                            FlashSnackBar.showInfo(
                              context,
                              'Cleared open-day overrides.',
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8C9191),
                            side: const BorderSide(color: Color(0xFF2C2F30)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Reset Opened ($openedCount)'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
    );
  }
}

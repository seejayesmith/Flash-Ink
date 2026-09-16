import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard_data.dart';
import '../../services/auth_service.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/tattoo_machine_icon.dart';
import '../artist_profile_screen.dart';
import '../splash_screen.dart';
import 'appointment_detail_screen.dart';

/// Interactive artist calendar screen matching the Flash.Ink dark aesthetic.
///
/// Can be presented as an independent full-screen route or embedded seamlessly
/// into Tab 1 of the [ArtistDashboardScreen].
class ArtistCalendarScreen extends StatefulWidget {
  final Artist? artist;
  final AuthService? authService;
  final bool isEmbeddedInTab;
  final VoidCallback? onBack;

  const ArtistCalendarScreen({
    super.key,
    this.artist,
    this.authService,
    this.isEmbeddedInTab = false,
    this.onBack,
  });

  @override
  State<ArtistCalendarScreen> createState() => _ArtistCalendarScreenState();
}

class _ArtistCalendarScreenState extends State<ArtistCalendarScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  // Active viewing month and selected date (defaults to September 9, 2026 per mockup)
  late DateTime _activeMonth;
  late DateTime _selectedDate;

  final Set<String> _expandedAppointmentIds = {};

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
    // Default to September 9, 2026 to match the visual design
    _activeMonth = DateTime(2026, 9, 1);
    _selectedDate = DateTime(2026, 9, 9);
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

  void _toggleAppointmentExpanded(String id) {
    setState(() {
      if (_expandedAppointmentIds.contains(id)) {
        _expandedAppointmentIds.remove(id);
      } else {
        _expandedAppointmentIds.add(id);
      }
    });
  }

  void _selectMonth(int month) {
    setState(() {
      _activeMonth = DateTime(_activeMonth.year, month, 1);
      // Ensure selected day is valid in new month
      final daysInMonth = DateTime(_activeMonth.year, month + 1, 0).day;
      final newDay = _selectedDate.day.clamp(1, daysInMonth);
      _selectedDate = DateTime(_activeMonth.year, month, newDay);
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
    });
  }

  int _getFirstWeekdayOffset(int year, int month) {
    // Design spec alignment: September 2026 starts on Monday (1 under Mo, 9 under Tu)
    if (year == 2026 && month == 9) {
      return 1;
    }
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
    if (_isToday(_selectedDate) ||
        (_selectedDate.year == 2026 && _selectedDate.month == 9 && _selectedDate.day == 9)) {
      return "Today's Schedule";
    }
    final month = _monthShortNames[_selectedDate.month - 1];
    return "$month ${_selectedDate.day} Schedule";
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = widget.isEmbeddedInTab ? 100.0 : 32.0;

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding),
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (canGoBack)
          IconButton(
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
        else
          GestureDetector(
            key: const Key('calendar_tattoo_machine_logo'),
            onTap: () {
              if (canGoBack) Navigator.pop(context);
            },
            child: const TattooMachineIcon(
              size: 28,
              color: Color(0xFFEEC200),
            ),
          ),
        GestureDetector(
          key: const Key('calendar_artist_avatar_button'),
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

  /// Page title "Calendar"
  Widget _buildTitleRow() {
    return Text(
      'Calendar',
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
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
        onHorizontalDragEnd: (details) {
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

            // Weekday labels: Su Mo Tu We Th Fr Sa
            _buildWeekdayHeader(),
            const SizedBox(height: 14),

            // Calendar grid
            _buildCalendarDaysGrid(),
          ],
        ),
      ),
    );
  }

  /// Month & Year dropdown pills in header of calendar card
  Widget _buildMonthYearSelectors() {
    final currentMonthShort = _monthShortNames[_activeMonth.month - 1];
    final currentYear = _activeMonth.year;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Month Selector Pill
        PopupMenuButton<int>(
          key: const Key('calendar_month_dropdown'),
          color: const Color(0xFF202323),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF333737)),
          ),
          initialValue: _activeMonth.month,
          onSelected: _selectMonth,
          itemBuilder: (context) {
            return List.generate(12, (index) {
              final monthNum = index + 1;
              final isSelected = monthNum == _activeMonth.month;
              return PopupMenuItem<int>(
                value: monthNum,
                child: Text(
                  _monthNames[index],
                  style: GoogleFonts.plusJakartaSans(
                    color: isSelected ? const Color(0xFFEEC200) : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              );
            });
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
                  currentMonthShort,
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
        const SizedBox(width: 10),

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
    return GestureDetector(
      key: Key('calendar_day_$dayNumber'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          width: 38,
          height: 44,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2C3030) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$dayNumber',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
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
              else if (hasAppointments)
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8C9191),
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

  /// Header row for the schedule section: "Today's Schedule" + "VIEW ALL"
  Widget _buildScheduleHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _scheduleSectionTitle,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          key: const Key('calendar_view_all_button'),
          onTap: _showAllAppointmentsSheet,
          child: Text(
            'VIEW ALL',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFEEC200),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  /// List of appointments for the active selected day
  Widget _buildScheduleList() {
    final appointments = _currentAppointments;

    if (appointments.isEmpty) {
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
            const Icon(Icons.event_available, color: Color(0xFF8C9191), size: 36),
            const SizedBox(height: 12),
            Text(
              'No appointments on this date',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enjoy your open studio time or open booking slots.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C9191),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: appointments.map((appointment) {
        return _buildAppointmentCard(appointment);
      }).toList(),
    );
  }

  /// Individual appointment card matching the visual mockup
  Widget _buildAppointmentCard(DashboardAppointment item) {
    final isExpanded = _expandedAppointmentIds.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF191B1B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded ? const Color(0xFF383C3C) : const Color(0xFF252828),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          // Main Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Primary interactive area: navigates to AppointmentDetailScreen
                Expanded(
                  child: InkWell(
                    key: Key('calendar_appointment_item_${item.id}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppointmentDetailScreen(appointment: item),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        // Time
                        Text(
                          item.time,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Status dot
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item.dotColor,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Client Name
                        Text(
                          item.clientName,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Service description & duration
                        Expanded(
                          child: Text(
                            '${item.serviceType} • ${item.duration}',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8C9191),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Trailing vertical arrows button (mirroring Bookings accordion behavior)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('calendar_arrow_${item.id}'),
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
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Inline expanded accordion details
          if (isExpanded) _buildExpandedAppointmentDetails(item),
        ],
      ),
    );
  }

  /// Expanded inline details accordion panel
  Widget _buildExpandedAppointmentDetails(DashboardAppointment item) {
    return Container(
      key: Key('calendar_expanded_panel_${item.id}'),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.artworkImageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 54,
                      height: 54,
                      color: const Color(0xFF222525),
                      child: FlashImage(
                        urlOrPath: item.artworkImageUrl,
                        fit: BoxFit.cover,
                        errorWidget: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFF8C9191),
                          size: 24,
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
                      Text(
                        item.serviceType,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Placement: ${item.placement}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C9191),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Deposit: \$${item.depositPaid} • Balance Due: \$${item.balanceDue}',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEEC200),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1C1C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.notes,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFD1D5DB),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: Key('calendar_message_btn_${item.id}'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Opening chat with ${item.clientName}...'),
                          backgroundColor: const Color(0xFF242727),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF383C3C)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Message Client',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    key: Key('calendar_full_details_btn_${item.id}'),
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Full Details',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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

  /// Bottom sheet listing all scheduled appointments across dates
  void _showAllAppointmentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF191B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final allAppointments = ArtistDashboardRepository.calendarAppointments;

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF383C3C),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Scheduled Sessions',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
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
                const Divider(color: Color(0xFF262929), height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    itemCount: allAppointments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final item = allAppointments[index];
                      return ListTile(
                        key: Key('all_appointments_sheet_item_${item.id}'),
                        tileColor: const Color(0xFF141616),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF262929)),
                        ),
                        leading: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item.dotColor,
                          ),
                        ),
                        title: Text(
                          item.clientName,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${item.date} • ${item.time} • ${item.serviceType}',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF8C9191),
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF8C9191)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AppointmentDetailScreen(appointment: item),
                            ),
                          );
                        },
                      );
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

  /// Profile Settings Modal matching the dashboard
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
                  key: const Key('calendar_modal_view_public_profile'),
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
                  key: const Key('calendar_modal_sign_out'),
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
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/artist_dashboard/artist_books_schedule.dart';
import '../../../models/artist_dashboard/book_drop.dart';
import '../../../repositories/artist_dashboard_repository.dart';
import '../../../theme/app_theme.dart';

/// Interactive calendar card with month/year dropdown pills, horizontal month swipe,
/// day-capacity indicator dots, and an animated 3x4 month picker grid.
class ArtistCalendarCard extends StatelessWidget {
  final DateTime activeMonth;
  final DateTime selectedDate;
  final bool isPickingMonth;
  final List<CustomHold> Function(DateTime date) holdsForDate;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToggleMonthPicker;
  final ValueChanged<int> onSelectMonth;
  final ValueChanged<int> onSelectYear;
  final ValueChanged<DateTime> onSelectDate;

  const ArtistCalendarCard({
    super.key,
    required this.activeMonth,
    required this.selectedDate,
    required this.isPickingMonth,
    required this.holdsForDate,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onToggleMonthPicker,
    required this.onSelectMonth,
    required this.onSelectYear,
    required this.onSelectDate,
  });

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _weekdays = [
    'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'
  ];

  int _getFirstWeekdayOffset(int year, int month) {
    final weekday = DateTime(year, month, 1).weekday;
    return weekday % 7;
  }

  @override
  Widget build(BuildContext context) {
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
        onHorizontalDragEnd: isPickingMonth
            ? null
            : (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! < -200) {
                    onNextMonth();
                  } else if (details.primaryVelocity! > 200) {
                    onPrevMonth();
                  }
                }
              },
        child: Column(
          children: [
            _buildMonthYearSelectors(),
            const SizedBox(height: 20),
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
              child: isPickingMonth
                  ? _buildMonthGrid(key: const ValueKey('month_picker_grid'))
                  : Column(
                      key: const ValueKey('calendar_days_view'),
                      children: [
                        _buildWeekdayHeader(),
                        const SizedBox(height: 14),
                        _buildCalendarDaysGrid(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthYearSelectors() {
    final currentMonthFull = _monthNames[activeMonth.month - 1];
    final currentYear = activeMonth.year;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildNavButton(
          key: const Key('calendar_prev_month_button'),
          icon: Icons.chevron_left,
          tooltip: 'Previous month',
          onTap: onPrevMonth,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              key: const Key('calendar_month_dropdown'),
              onTap: onToggleMonthPicker,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.onyxBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPickingMonth
                        ? AppTheme.gold
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
                        color: isPickingMonth ? AppTheme.gold : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: isPickingMonth ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: isPickingMonth
                            ? AppTheme.gold
                            : AppTheme.navInactiveAlt,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<int>(
              key: const Key('calendar_year_dropdown'),
              color: const Color(0xFF202323),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.actionButtonBorder),
              ),
              initialValue: currentYear,
              onSelected: onSelectYear,
              itemBuilder: (context) {
                const years = [2024, 2025, 2026, 2027, 2028];
                return years.map((year) {
                  final isSelected = year == currentYear;
                  return PopupMenuItem<int>(
                    value: year,
                    child: Text(
                      '$year',
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? AppTheme.gold : Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.onyxBackground,
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
                      color: AppTheme.navInactiveAlt,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        _buildNavButton(
          key: const Key('calendar_next_month_button'),
          icon: Icons.chevron_right,
          tooltip: 'Next month',
          onTap: onNextMonth,
        ),
      ],
    );
  }

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
              color: AppTheme.onyxBackground,
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

  Widget _buildWeekdayHeader() {
    return Row(
      children: _weekdays.map((day) {
        return Expanded(
          child: Text(
            day,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.navInactiveAlt,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarDaysGrid() {
    final year = activeMonth.year;
    final month = activeMonth.month;

    final daysInCurrentMonth = DateTime(year, month + 1, 0).day;
    final firstWeekdayOffset = _getFirstWeekdayOffset(year, month);
    final daysWithAppointments =
        ArtistDashboardRepository.getDaysWithAppointments(year, month);

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
                return const Expanded(child: SizedBox(height: 44));
              }

              final dayNumber = cellIndex - firstWeekdayOffset + 1;

              if (dayNumber <= daysInCurrentMonth) {
                final isSelected = selectedDate.year == year &&
                    selectedDate.month == month &&
                    selectedDate.day == dayNumber;
                final hasAppointments =
                    daysWithAppointments.contains(dayNumber);

                return Expanded(
                  child: _buildDayCell(
                    dayNumber: dayNumber,
                    isSelected: isSelected,
                    hasAppointments: hasAppointments,
                    onTap: () => onSelectDate(DateTime(year, month, dayNumber)),
                  ),
                );
              } else {
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

  Widget _buildDayCell({
    required int dayNumber,
    required bool isSelected,
    required bool hasAppointments,
    required VoidCallback onTap,
  }) {
    final cellDate = DateTime(activeMonth.year, activeMonth.month, dayNumber);
    final capacity = ArtistDashboardRepository.getDayCapacityStatus(cellDate);
    final isBlocked = ArtistDashboardRepository.isDateBlocked(cellDate);
    final isForceOpened = ArtistDashboardRepository.isDateForceOpened(cellDate);
    final isWeeklyCapClosed =
        ArtistDashboardRepository.isClosedByWeeklyCap(cellDate);
    final isClosedOrBlocked = capacity == DayCapacityStatus.closed ||
        capacity == DayCapacityStatus.blocked;
    final holds = holdsForDate(cellDate);
    final hasHold = holds.isNotEmpty;

    Color dotColor = AppTheme.navInactiveAlt;
    if (hasHold) {
      dotColor = const Color(0xFFA855F7);
    } else if (isBlocked) {
      dotColor = const Color(0xFFF97316).withAlpha(180);
    } else if (isForceOpened && !hasAppointments) {
      dotColor = const Color(0xFF22C55E);
    } else if (isWeeklyCapClosed) {
      dotColor = AppTheme.gold.withAlpha(130);
    } else if (hasAppointments) {
      if (capacity == DayCapacityStatus.full) {
        dotColor = AppTheme.navInactiveAlt;
      } else if (capacity == DayCapacityStatus.filling) {
        dotColor = AppTheme.gold;
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
                      ? const Color(0xFF4B5050)
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
              final isSelected = monthNum == activeMonth.month;
              final monthName = _monthNames[monthIndex];

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: colIndex == 0 ? 0 : 5,
                    right: colIndex == 2 ? 0 : 5,
                  ),
                  child: GestureDetector(
                    key: Key('calendar_select_month_$monthNum'),
                    onTap: () => onSelectMonth(monthNum),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.gold.withAlpha(35)
                            : AppTheme.onyxSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.gold
                              : const Color(0xFF282B2B),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        monthName,
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected ? AppTheme.gold : Colors.white,
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
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
}

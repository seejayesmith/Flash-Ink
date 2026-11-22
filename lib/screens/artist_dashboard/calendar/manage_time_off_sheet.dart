import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/artist_dashboard/artist_books_schedule.dart';
import '../../../repositories/artist_dashboard_repository.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/adaptive_glass_container.dart';
import '../../../widgets/flash_snack_bar.dart';

/// Shows a shared confirmation dialog when blocking date(s) that already have
/// confirmed appointments or active 24h custom holds.
Future<bool?> showBlockDatesConflictDialog({
  required BuildContext context,
  required String title,
  required String content,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      backgroundColor: const Color(0xFF1E2121),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        content,
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.navInactiveAlt,
          fontSize: 13,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dlgCtx, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.plusJakartaSans(color: AppTheme.navInactiveAlt),
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
}

enum _TimeOffSelectionMode { tapDates, dateRange }

/// Dedicated multi-date and date-range picker bottom sheet for managing
/// two-way calendar overrides (blocking days off or force-opening off-weekdays).
class ManageTimeOffSheet extends StatefulWidget {
  final DateTime initialMonth;
  final String? artistId;
  final ({int appointments, int holds}) Function(Iterable<DateTime> dates)
      countConflicts;
  final VoidCallback onDatesChanged;

  const ManageTimeOffSheet({
    super.key,
    required this.initialMonth,
    required this.artistId,
    required this.countConflicts,
    required this.onDatesChanged,
  });

  @override
  State<ManageTimeOffSheet> createState() => _ManageTimeOffSheetState();
}

class _ManageTimeOffSheetState extends State<ManageTimeOffSheet> {
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _weekdays = [
    'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'
  ];

  late DateTime _viewMonth;
  _TimeOffSelectionMode _mode = _TimeOffSelectionMode.tapDates;
  final Set<String> _selectedKeys = {};
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _viewMonth =
        DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
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
      final confirmed = await showBlockDatesConflictDialog(
        context: context,
        title: 'Existing Bookings on Selected Dates',
        content:
            'You have ${nounParts.join(' and ')} across ${dates.length} selected ${dates.length == 1 ? 'date' : 'dates'}. Existing bookings and holds stay intact while remaining open slots will be blocked.',
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
            color: isSelected ? AppTheme.gold : AppTheme.onyxSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.gold : const Color(0xFF2C2F30),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isSelected
                  ? AppTheme.onyxBackground
                  : AppTheme.navInactiveAlt,
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
    final daysInMonth =
        DateUtils.getDaysInMonth(_viewMonth.year, _viewMonth.month);
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
                          color: AppTheme.navInactiveAlt,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('time_off_close_button'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.navInactiveAlt),
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
                    _viewMonth =
                        DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
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
                    _viewMonth =
                        DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
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
                      final isForceOpened =
                          schedule.isDateForceOpened(cellDate);

                      return GestureDetector(
                        key: Key('time_off_picker_day_$dayNum'),
                        onTap: () => _onTapDate(cellDate),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isPicked
                                ? AppTheme.gold
                                : (isBlocked
                                    ? const Color(0xFF2B1C12)
                                    : (isForceOpened
                                        ? const Color(0xFF142419)
                                        : AppTheme.onyxSurface)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isPicked
                                  ? AppTheme.gold
                                  : (isBlocked
                                      ? const Color(0xFFF97316).withAlpha(140)
                                      : (isForceOpened
                                          ? const Color(0xFF22C55E)
                                              .withAlpha(120)
                                          : const Color(0xFF252828))),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$dayNum',
                            style: GoogleFonts.plusJakartaSans(
                              color: isPicked
                                  ? AppTheme.onyxBackground
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
                color: AppTheme.navInactiveAlt,
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
                          foregroundColor: AppTheme.gold,
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
                          foregroundColor: AppTheme.navInactiveAlt,
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

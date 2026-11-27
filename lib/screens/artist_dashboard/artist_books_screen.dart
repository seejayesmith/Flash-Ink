import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/mock/mock_data_config.dart';
import '../../core/widgets/flash_bottom_nav_bar.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard/book_drop.dart';
import '../../repositories/artist_dashboard_repository.dart';
import '../../models/waitlist_entry.dart';
import '../../services/auth_service.dart';
import '../../services/booking_sync_service.dart';
import '../../services/stripe_service.dart';
import 'stripe_payout_gate_sheet.dart';
import '../../theme/app_buttons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/adaptive_glass_container.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/flash_switch.dart';
import '../../widgets/artist_top_bar.dart';
import '../../widgets/user_avatar.dart';
import 'add_waitlist_entry_sheet.dart';
import 'artist_account_screen.dart';
import 'artist_calendar_screen.dart';
import 'artist_waitlist_screen.dart';
import 'books_open_options_modal.dart';
import 'create_book_drop_screen.dart';
import 'early_access_outreach_sheet.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';

/// Screen allowing tattoo artists to manage and create their "Books" schedule.
///
/// Houses controls for Books Open/Closed status, booking window ranges,
/// recurring working days/hours, slot duration/buffers, and accepted session types.
class ArtistBooksScreen extends StatefulWidget {
  final Artist? artist;
  final AuthService? authService;
  final StripeService? stripeService;
  final bool isEmbeddedInTab;
  final VoidCallback? onBack;
  final VoidCallback? onNavigateToCalendar;
  final VoidCallback? onNavigateToDashboard;

  const ArtistBooksScreen({
    super.key,
    this.artist,
    this.authService,
    this.stripeService,
    this.isEmbeddedInTab = false,
    this.onBack,
    this.onNavigateToCalendar,
    this.onNavigateToDashboard,
  });

  @override
  State<ArtistBooksScreen> createState() => _ArtistBooksScreenState();
}

class _ArtistBooksScreenState extends State<ArtistBooksScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  late bool _isBooksOpen;
  late DateTime _windowStart;
  late DateTime _windowEnd;
  late bool _hasBookingWindow;
  late Set<int> _workingDays;
  Set<int>? _previousWorkingDays;
  late int _minLeadTimeHours;
  int? _maxWorkingDaysPerWeek;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _slotDurationMinutes;
  late int _bufferMinutes;
  late bool _preventDeadGaps;
  late int _minBookableSessionMinutes;
  late int _defaultDeposit;
  late bool _acceptFlash;
  late bool _acceptCustom;
  late bool _acceptTouchUps;
  late int _touchUpDurationMinutes;
  late int _touchUpBufferMinutes;
  late int _touchUpWindowMonths;
  late int _touchUpFeeDollars;
  late final TextEditingController _locationController;

  bool _isSaving = false;

  bool get _isAllDaysOpen => _workingDays.length == 7;

  @override
  void initState() {
    super.initState();
    _syncFieldsFromRepository(isInitial: true);
    ArtistDashboardRepository.pendingRequestsNotifier.addListener(_onRepositoryChanged);
    final uid = widget.artist?.id ?? _authService.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      BookingSyncService.hydrateArtistDataFromCloud(uid);
    }
  }

  void _syncFieldsFromRepository({bool isInitial = false}) {
    final schedule = ArtistDashboardRepository.booksSchedule;
    _isBooksOpen = schedule.isBooksOpen;
    _windowStart = schedule.bookingWindowStart;
    _windowEnd = schedule.bookingWindowEnd;
    _hasBookingWindow = schedule.hasBookingWindow;
    _workingDays = Set<int>.from(schedule.workingDays);
    if (schedule.workingDays.length < 7) {
      _previousWorkingDays = Set<int>.from(schedule.workingDays);
    }
    _minLeadTimeHours = schedule.minLeadTimeHours;
    _maxWorkingDaysPerWeek = schedule.maxWorkingDaysPerWeek;
    _startTime = schedule.startTime;
    _endTime = schedule.endTime;
    _slotDurationMinutes = schedule.slotDurationMinutes;
    _bufferMinutes = schedule.bufferDurationMinutes;
    _preventDeadGaps = schedule.preventDeadGaps;
    _minBookableSessionMinutes =
        const [60, 90, 120].contains(schedule.minBookableSessionMinutes)
            ? schedule.minBookableSessionMinutes
            : 60;
    _defaultDeposit = schedule.defaultDepositAmount;
    _acceptFlash = schedule.acceptFlash;
    _acceptCustom = schedule.acceptCustom;
    _acceptTouchUps = schedule.acceptTouchUps;
    _touchUpDurationMinutes = const [15, 30, 45, 60, 90, 120]
            .contains(schedule.touchUpDurationMinutes)
        ? schedule.touchUpDurationMinutes
        : 30;
    _touchUpBufferMinutes =
        const [0, 15, 30, 45, 60].contains(schedule.touchUpBufferMinutes)
            ? schedule.touchUpBufferMinutes
            : 30;
    _touchUpWindowMonths =
        const [3, 6, 12].contains(schedule.touchUpWindowMonths)
            ? schedule.touchUpWindowMonths
            : 6;
    _touchUpFeeDollars = schedule.touchUpFeeDollars.clamp(0, 10000);
    final defaultLoc = schedule.locationNote.isNotEmpty
        ? schedule.locationNote
        : (widget.artist != null
            ? [
                if (widget.artist!.studioName.isNotEmpty)
                  widget.artist!.studioName
                else if (widget.artist!.studioType.isNotEmpty)
                  widget.artist!.studioType,
                if (widget.artist!.location.isNotEmpty) widget.artist!.location,
              ].join(' • ')
            : '');
    if (isInitial) {
      _locationController = TextEditingController(text: defaultLoc);
    } else if (_locationController.text.isEmpty && defaultLoc.isNotEmpty) {
      _locationController.text = defaultLoc;
    }
  }

  void _onRepositoryChanged() {
    if (mounted) {
      setState(() {
        _syncFieldsFromRepository();
      });
    }
  }

  @override
  void dispose() {
    ArtistDashboardRepository.pendingRequestsNotifier.removeListener(_onRepositoryChanged);
    _locationController.dispose();
    super.dispose();
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

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickDateRange() async {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minAllowedDate = today.subtract(const Duration(days: 30));
    final maxAllowedDate = today.add(const Duration(days: 365));

    DateTime rangeStart =
        DateTime(_windowStart.year, _windowStart.month, _windowStart.day);
    DateTime? rangeEnd =
        DateTime(_windowEnd.year, _windowEnd.month, _windowEnd.day);
    if (rangeEnd.isBefore(rangeStart)) {
      rangeEnd = rangeStart;
    }
    DateTime displayMonth = DateTime(rangeStart.year, rangeStart.month, 1);

    final picked = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final daysInMonth =
                DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
            final firstWeekday =
                DateTime(displayMonth.year, displayMonth.month, 1).weekday % 7;
            final rowCount = ((firstWeekday + daysInMonth) / 7).ceil();

            final canGoPrevMonth = displayMonth.isAfter(
              DateTime(minAllowedDate.year, minAllowedDate.month, 1),
            );
            final canGoNextMonth = displayMonth.isBefore(
              DateTime(maxAllowedDate.year, maxAllowedDate.month, 1),
            );

            void handleDayTap(DateTime tapped) {
              setModalState(() {
                if (rangeEnd != null) {
                  rangeStart = tapped;
                  rangeEnd = null;
                } else if (tapped.isBefore(rangeStart)) {
                  rangeEnd = rangeStart;
                  rangeStart = tapped;
                } else {
                  rangeEnd = tapped;
                }
              });
            }

            final canApply = rangeEnd != null;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
              ),
              child: AdaptiveGlassContainer.bottomSheet(
                glassEnabled: true,
                androidSurfaceColor: const Color(0xFF171A1A),
                topRadius: AppRadius.radiusSheet,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.viewInsetsOf(ctx).bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF333838),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select Booking Window',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rangeEnd == null
                            ? 'Now tap a closing date for your booking window.'
                            : 'Tap a start date, then an end date.',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C9191),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161818),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: rangeEnd == null
                                      ? AppTheme.gold
                                      : const Color(0xFF2C2F30),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'OPEN DATE',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF8C9191),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(rangeStart),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.arrow_forward,
                              color: AppTheme.gold,
                              size: 16,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161818),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: rangeEnd == null
                                      ? AppTheme.gold.withValues(alpha: 0.5)
                                      : const Color(0xFF2C2F30),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CLOSE DATE',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF8C9191),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    rangeEnd != null
                                        ? _formatDate(rangeEnd!)
                                        : 'Select end date',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: rangeEnd != null
                                          ? Colors.white
                                          : AppTheme.gold,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141616),
                          borderRadius:
                              BorderRadius.circular(AppRadius.radiusLg),
                          border: Border.all(
                            color: const Color(0xFF38352A),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  key: const Key('range_calendar_prev_month'),
                                  icon: Icon(
                                    Icons.chevron_left,
                                    color: canGoPrevMonth
                                        ? Colors.white
                                        : const Color(0xFF424747),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: canGoPrevMonth
                                      ? () => setModalState(() {
                                            displayMonth = DateTime(
                                              displayMonth.year,
                                              displayMonth.month - 1,
                                              1,
                                            );
                                          })
                                      : null,
                                ),
                                Text(
                                  '${monthNames[displayMonth.month - 1]} ${displayMonth.year}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  key: const Key('range_calendar_next_month'),
                                  icon: Icon(
                                    Icons.chevron_right,
                                    color: canGoNextMonth
                                        ? Colors.white
                                        : const Color(0xFF424747),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: canGoNextMonth
                                      ? () => setModalState(() {
                                            displayMonth = DateTime(
                                              displayMonth.year,
                                              displayMonth.month + 1,
                                              1,
                                            );
                                          })
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: weekdays
                                  .map(
                                    (d) => SizedBox(
                                      width: 34,
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: List.generate(7, (colIndex) {
                                      final dayNum = rowIndex * 7 +
                                          colIndex -
                                          firstWeekday +
                                          1;
                                      if (dayNum < 1 || dayNum > daysInMonth) {
                                        return const SizedBox(
                                          width: 36,
                                          height: 36,
                                        );
                                      }
                                      final cellDate = DateTime(
                                        displayMonth.year,
                                        displayMonth.month,
                                        dayNum,
                                      );
                                      final isDisabled =
                                          cellDate.isBefore(minAllowedDate) ||
                                              cellDate.isAfter(maxAllowedDate);
                                      final isStart = cellDate == rangeStart;
                                      final isEnd = rangeEnd != null &&
                                          cellDate == rangeEnd;
                                      final isEndpoint = isStart || isEnd;
                                      final isInRange = rangeEnd != null &&
                                          cellDate.isAfter(rangeStart) &&
                                          cellDate.isBefore(rangeEnd!);
                                      final isToday = cellDate == today;

                                      return GestureDetector(
                                        key: Key('range_calendar_day_$dayNum'),
                                        onTap: isDisabled
                                            ? null
                                            : () => handleDayTap(cellDate),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isEndpoint
                                                ? AppTheme.gold
                                                : (isInRange
                                                    ? AppTheme.gold
                                                        .withValues(alpha: 0.18)
                                                    : Colors.transparent),
                                            border: isEndpoint
                                                ? Border.all(
                                                    color: AppTheme.gold,
                                                    width: 1.5,
                                                  )
                                                : (isToday
                                                    ? Border.all(
                                                        color: const Color(
                                                          0xFF4D5252,
                                                        ),
                                                        width: 1,
                                                      )
                                                    : null),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$dayNum',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                color: isEndpoint
                                                    ? AppTheme.onyxBackground
                                                    : (isDisabled
                                                        ? const Color(
                                                            0xFF424747,
                                                          )
                                                        : (isInRange
                                                            ? AppTheme.gold
                                                            : Colors.white)),
                                                fontSize: 13,
                                                fontWeight: isEndpoint
                                                    ? FontWeight.bold
                                                    : (isInRange
                                                        ? FontWeight.w600
                                                        : FontWeight.w500),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppButtons.primaryCTA(
                        key: const Key('apply_date_range_button'),
                        onPressed: canApply
                            ? () => Navigator.pop(
                                  modalContext,
                                  DateTimeRange(
                                    start: rangeStart,
                                    end: rangeEnd!,
                                  ),
                                )
                            : null,
                        text: canApply
                            ? 'Apply Booking Window'
                            : 'Select Closing Date',
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.onyxBackground,
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(modalContext),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.navInactive,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _windowStart = picked.start;
        _windowEnd = picked.end;
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFEEC200),
              onPrimary: Color(0xFF121414),
              surface: Color(0xFF1E2121),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if (_isBooksOpen && !ArtistDashboardRepository.stripePayoutsReady) {
      setState(() => _isBooksOpen = false);
      StripePayoutGateSheet.show(
        context,
        stripeService: widget.stripeService,
        artistName: _artistDisplayName,
        onVerified: () {
          if (!mounted) return;
          setState(() => _isBooksOpen = true);
          _handleSave();
        },
      );
      return;
    }

    setState(() => _isSaving = true);

    final updated = ArtistDashboardRepository.booksSchedule.copyWith(
      isBooksOpen: _isBooksOpen,
      bookingWindowStart: _windowStart,
      bookingWindowEnd: _windowEnd,
      hasBookingWindow: _hasBookingWindow,
      workingDays: Set<int>.from(_workingDays),
      minLeadTimeHours: _minLeadTimeHours,
      maxWorkingDaysPerWeek: _maxWorkingDaysPerWeek,
      clearMaxWorkingDaysPerWeek: _maxWorkingDaysPerWeek == null,
      startTime: _startTime,
      endTime: _endTime,
      slotDurationMinutes: _slotDurationMinutes,
      bufferDurationMinutes: _bufferMinutes,
      preventDeadGaps: _preventDeadGaps,
      minBookableSessionMinutes: _minBookableSessionMinutes,
      defaultDepositAmount: _defaultDeposit,
      acceptFlash: _acceptFlash,
      acceptCustom: _acceptCustom,
      acceptTouchUps: _acceptTouchUps,
      touchUpDurationMinutes: _touchUpDurationMinutes,
      touchUpBufferMinutes: _touchUpBufferMinutes,
      touchUpWindowMonths: _touchUpWindowMonths,
      touchUpFeeDollars: _touchUpFeeDollars,
      locationNote: _locationController.text.trim().isEmpty
          ? 'OddMaree Studio • Portland, OR'
          : _locationController.text.trim(),
    );

    String artistUid;
    try {
      final injectedUser = _authService.currentUser;
      artistUid = (injectedUser != null && injectedUser.uid.isNotEmpty)
          ? injectedUser.uid
          : FirebaseAuth.instance.currentUser!.uid;
    } catch (_) {
      artistUid = widget.artist?.id ?? '';
    }

    // 1. Update in-memory repository and sync to /artist_schedules/{uid}
    ArtistDashboardRepository.updateBooksSchedule(
      updated,
      artistId: artistUid,
    );

    // 2. Sync isBooksOpen and booksSchedule to public /artists/{uid} document
    try {
      if (artistUid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('artists')
            .doc(artistUid)
            .set({
          'isBooksOpen': _isBooksOpen,
          'booksSchedule': updated.toMap(),
        }, SetOptions(merge: true)).timeout(const Duration(milliseconds: 600));
      }
    } catch (_) {
      // Offline / mock fallback without breaking UI flow
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    FlashSnackBar.showSuccess(
      context,
      'Books schedule saved successfully!',
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          12,
          AppSpacing.screenGutter,
          MediaQuery.paddingOf(context).bottom + 100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopActionBar(),
            const SizedBox(height: 20),
            _buildHeaderTitleRow(),
            const SizedBox(height: 20),
            _buildStatusHeroCard(),
            const SizedBox(height: 18),
            Builder(
              builder: (context) {
                final mode = ArtistDashboardRepository.bookingMode;
                final drop = ArtistDashboardRepository.currentBookDrop;
                final isDropActive = mode == BookingMode.drops &&
                    drop != null &&
                    drop.status != BookDropStatus.closed;
                final headerSubtitle = isDropActive
                    ? 'Book Drop active (${drop.title}) — defaults resume when the drop ends'
                    : (_hasBookingWindow
                        ? 'Bookings limited to your selected date range & working days'
                        : 'Always open — accepts bookings on any future working day');
                return _buildSectionGroupHeader(
                  key: const Key('always_open_defaults_header'),
                  title: 'ALWAYS OPEN DEFAULTS',
                  subtitle: headerSubtitle,
                );
              },
            ),
            const SizedBox(height: 8),
            _buildBookingWindowCard(),
            const SizedBox(height: 14),
            _buildWorkingDaysCard(),
            const SizedBox(height: 14),
            _buildAvailabilityRulesCard(),
            const SizedBox(height: 18),
            _buildSectionGroupHeader(
              key: const Key('global_studio_rules_header'),
              title: 'GLOBAL STUDIO RULES',
              subtitle:
                  'Applies across both Always Open and Book Drops',
            ),
            const SizedBox(height: 8),
            _buildWorkingHoursAndBufferCard(),
            const SizedBox(height: 12),
            _buildBookingTypesCard(),
            const SizedBox(height: 12),
            _buildLocationCard(),
            const SizedBox(height: 12),
            _buildWaitlistSectionCard(),
            const SizedBox(height: 14),
            _buildSaveButton(),
          ],
        ),
      ),
    );

    if (widget.isEmbeddedInTab) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: FlashNavBarScope(
        child: Stack(
          children: [
            content,
            Positioned(
              left: AppSpacing.screenGutter,
              right: AppSpacing.screenGutter,
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
      ),
    );
  }

  /// Top action bar with tattoo machine logo on left and avatar on right
  Widget _buildTopActionBar() {
    final canGoBack = !widget.isEmbeddedInTab && Navigator.canPop(context);

    final avatarChild = UserAvatar(
      imageUrl: _avatarUrl,
      displayName: _artistDisplayName,
      radius: 18,
      fallbackInitial: 'O',
      initialFontSize: 16,
    );

    return ArtistTopBar(
      leadingWidget: canGoBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
            )
          : null,
      logoKey: const Key('tattoo_machine_logo'),
      onLogoTap: widget.onNavigateToDashboard,
      messagesKey: const Key('books_messages_button'),
      avatarKey: const Key('books_artist_avatar_button'),
      onMessagesTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MessagesScreen()),
        );
      },
      onAvatarTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistAccountScreen(
              artist: widget.artist,
              authService: widget.authService,
            ),
          ),
        );
      },
      avatarChild: avatarChild,
      artistId: widget.artist?.id ?? widget.authService?.currentUser?.uid,
    );
  }

  /// Header row with title and status description
  Widget _buildHeaderTitleRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Books & Schedule',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage your client booking windows, working days, and session rules.',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8C9191),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppButtons.primaryCTA(
                key: const Key('plan_book_drop_button'),
                onPressed: () async {
                  final res = await CreateBookDropScreen.show(context, artist: widget.artist);
                  if (res == true && mounted) {
                    setState(() {
                      _syncFieldsFromRepository();
                    });
                  }
                },
                text: 'Plan a Book Drop',
                backgroundColor: const Color(0xFFEEC200),
                foregroundColor: const Color(0xFF121414),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Hero card displaying current Books Open / Closed status with live toggle
  Widget _buildStatusHeroCard() {
    final schedule = ArtistDashboardRepository.booksSchedule;
    final mode = ArtistDashboardRepository.bookingMode;
    final drop = ArtistDashboardRepository.currentBookDrop;
    final isPaused = ArtistDashboardRepository.isPaused;
    final isEarlyAccess = schedule.isEarlyAccessActive;
    final isDropScheduled = mode == BookingMode.drops && drop?.status == BookDropStatus.scheduled;
    final isDropActive = mode == BookingMode.drops && _isBooksOpen && drop != null && drop.status != BookDropStatus.closed;

    final Color activeColor = isPaused
        ? const Color(0xFFF97316)
        : (isDropScheduled
            ? const Color(0xFFA855F7)
            : (isEarlyAccess
                ? const Color(0xFFEEC200)
                : (_isBooksOpen ? const Color(0xFF22C55E) : const Color(0xFF919696))));
    final Color borderColor = isPaused
        ? const Color(0xFFF97316)
        : (isDropScheduled
            ? const Color(0xFFA855F7)
            : (isEarlyAccess
                ? const Color(0xFFEEC200)
                : (_isBooksOpen ? const Color(0xFF22C55E) : const Color(0xFF282C2C))));

    final String statusLabel = isPaused
        ? 'INQUIRIES PAUSED'
        : (isDropScheduled
            ? 'DROP SCHEDULED'
            : (isEarlyAccess
                ? 'VIP EARLY ACCESS ACTIVE'
                : (isDropActive
                    ? 'BOOKS OPEN (DROP)'
                    : (_isBooksOpen ? 'BOOKS OPEN' : 'BOOKS CLOSED'))));

    final String titleText = isPaused
        ? 'Inquiries Currently Paused'
        : (isDropScheduled
            ? (drop?.title ?? 'Upcoming Booking Drop')
            : (isEarlyAccess
                ? 'VIP Waitlist Early Access Live'
                : (isDropActive
                    ? drop.title
                    : (_isBooksOpen ? 'Accepting New Appointments' : 'Currently Closed to Inquiries'))));

    final String subtitleText = isPaused
        ? 'Clients can view your portfolio, but cannot submit new requests.'
        : (isDropScheduled
            ? 'Your next drop is scheduled and waiting to go live.'
            : (isEarlyAccess
                ? 'Your private waitlist members have exclusive access before public release.'
                : (_isBooksOpen
                    ? 'Clients can view your available calendar slots and request bookings directly.'
                    : 'Clients can browse your portfolio, but general booking submissions are paused.')));

    return Container(
      key: const Key('books_status_card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: (_isBooksOpen || isEarlyAccess || isPaused || isDropScheduled) ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (_isBooksOpen || isEarlyAccess || isPaused || isDropScheduled)
            BoxShadow(
              color: activeColor.withAlpha(20),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withAlpha(160),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        statusLabel,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: activeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              FlashSwitch(
                key: const Key('books_status_switch'),
                value: ArtistDashboardRepository.stripePayoutsReady &&
                    _isBooksOpen &&
                    !isPaused,
                onChanged: (val) {
                  if (!val) {
                    setState(() => _isBooksOpen = false);
                    ArtistDashboardRepository.closeBooks();
                    return;
                  }
                  if (!ArtistDashboardRepository.stripePayoutsReady) {
                    StripePayoutGateSheet.show(
                      context,
                      stripeService: widget.stripeService,
                      artistName: _artistDisplayName,
                      onVerified: () {
                        if (!mounted) return;
                        setState(() => _isBooksOpen = true);
                        ArtistDashboardRepository.openBooksPublicly();
                      },
                    );
                    return;
                  }
                  setState(() => _isBooksOpen = true);
                  ArtistDashboardRepository.openBooksPublicly();
                  final waitingCount = ArtistDashboardRepository.waitlistEntries
                      .where((e) => e.status.name == 'waiting')
                      .length;
                  if (waitingCount > 0) {
                    BooksOpenOptionsModal.show(
                      context: context,
                      onEarlyAccessSelected: () {
                        setState(() {
                          _isBooksOpen = true;
                        });
                        EarlyAccessOutreachSheet.show(
                          context: context,
                          onBooksUpdated: () => setState(() {}),
                        );
                      },
                      onPublicOpenSelected: () {
                        setState(() {
                          _isBooksOpen = true;
                        });
                      },
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            titleText,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitleText,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFB0B6B6),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          if (isEarlyAccess) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      EarlyAccessOutreachSheet.show(
                        context: context,
                        onBooksUpdated: () => setState(() {}),
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: const Text('Outreach Checklist'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEEC200),
                      side: const BorderSide(color: Color(0xFFEEC200)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ArtistDashboardRepository.openBooksPublicly();
                      setState(() {});
                      FlashSnackBar.showSuccess(
                        context,
                        'Books opened to public!',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF262A2A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Open Public Now'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Dedicated section card for the artist's VIP Waitlist
  Widget _buildWaitlistSectionCard() {
    final waitlist = ArtistDashboardRepository.waitlistEntries;
    final waitingCount = waitlist.where((e) => e.status == WaitlistStatus.waiting).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2E2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEC200).withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.people_alt_rounded, color: Color(0xFFEEC200), size: 15),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'VIP WAITLIST & EARLY ACCESS',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8C9191),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEC200).withAlpha(24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  waitingCount > 0 ? '$waitingCount Waiting' : '${waitlist.length} Contacts',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEEC200),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Keep track of friends, family, and direct inquiries so you can grant them early booking access before releasing public books.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFB0B6B6),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

          // Top contacts preview row
          if (waitlist.isNotEmpty)
            Column(
              children: waitlist.take(3).map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161818),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF242828)),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(
                        imageUrl: entry.avatarUrl,
                        displayName: entry.clientName,
                        radius: 14,
                        backgroundColor: const Color(0xFF2A2E2E),
                        fallbackInitial: '?',
                        initialFontSize: 12,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.clientName,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${entry.relationshipTag} • ${entry.conceptDescription}',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF8C9191),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: entry.status.badgeColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.status.label,
                          style: GoogleFonts.plusJakartaSans(
                            color: entry.status.badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 8),

          // Actions Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArtistWaitlistScreen(
                            artist: widget.artist,
                          ),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    icon: const Icon(Icons.people_outline_rounded, size: 16),
                    label: const Text('Manage Waitlist'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEC200),
                      foregroundColor: const Color(0xFF121414),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                width: 38,
                child: IconButton(
                  onPressed: () {
                    AddWaitlistEntrySheet.show(
                      context: context,
                      onSaved: () => setState(() {}),
                    );
                  },
                  tooltip: 'Add Contact',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFEEC200), size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF262A2A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildSectionGroupHeader({
    required Key key,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFEEC200),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Booking window date range card (dynamic: Always Open vs. custom date range / Book Drop)
  Widget _buildBookingWindowCard() {
    final mode = ArtistDashboardRepository.bookingMode;
    final drop = ArtistDashboardRepository.currentBookDrop;
    final isDropActive = mode == BookingMode.drops &&
        drop != null &&
        drop.status != BookDropStatus.closed;

    return Container(
      padding: const EdgeInsets.all(18),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'BOOKING WINDOW',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF8C9191),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (isDropActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA855F7)
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFA855F7)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              'Drop Active',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFFD8B4FE),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hasBookingWindow
                          ? 'Only dates inside this window are open for booking'
                          : 'No date limit — clients can book any future working day',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF6B7272),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FlashSwitch(
                key: const Key('booking_window_toggle'),
                value: _hasBookingWindow,
                onChanged: (val) {
                  setState(() => _hasBookingWindow = val);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!_hasBookingWindow)
            GestureDetector(
              key: const Key('booking_window_unlimited_banner'),
              onTap: () {
                setState(() => _hasBookingWindow = true);
                _pickDateRange();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161818),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2C2F30)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.all_inclusive_rounded,
                      color: AppTheme.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isDropActive
                            ? 'Book Drop dates active • Always open resumes after drop'
                            : 'Always open unless blocked in Calendar',
                        style: AppTypography.bodySmallBold.copyWith(
                          color: AppTheme.textPrimary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Set Dates',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161818),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2C2F30)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OPEN DATE',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8C9191),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(_windowStart),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Color(0xFF8C9191),
                    size: 16,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161818),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2C2F30)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CLOSE DATE',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8C9191),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(_windowEnd),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                key: const Key('booking_window_picker_button'),
                onTap: _pickDateRange,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.edit_calendar_outlined,
                      color: AppTheme.gold,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Edit Range',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleOpenAllDaysToggle(bool enabled) {
    setState(() {
      if (enabled) {
        if (_workingDays.length < 7) {
          _previousWorkingDays = Set<int>.from(_workingDays);
        }
        _workingDays = {1, 2, 3, 4, 5, 6, 7};
      } else {
        final fallback = (_previousWorkingDays != null &&
                _previousWorkingDays!.isNotEmpty &&
                _previousWorkingDays!.length < 7)
            ? _previousWorkingDays!
            : const {2, 3, 4, 5, 6};
        _workingDays = Set<int>.from(fallback);
      }
    });
  }

  void _navigateToCalendar() {
    if (widget.onNavigateToCalendar != null) {
      widget.onNavigateToCalendar!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtistCalendarScreen(
          artist: widget.artist,
          authService: _authService,
        ),
      ),
    );
  }

  /// Recurring weekly working days selector
  Widget _buildWorkingDaysCard() {
    const days = [
      {'val': 1, 'label': 'Mon'},
      {'val': 2, 'label': 'Tue'},
      {'val': 3, 'label': 'Wed'},
      {'val': 4, 'label': 'Thu'},
      {'val': 5, 'label': 'Fri'},
      {'val': 6, 'label': 'Sat'},
      {'val': 7, 'label': 'Sun'},
    ];

    final schedule = ArtistDashboardRepository.booksSchedule;
    final blockedCount = schedule.blockedDates.length;
    final openedCount = schedule.openOverrideDates.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEKLY WORKING DAYS',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isAllDaysOpen
                          ? 'All 7 days open — block specific dates in Calendar'
                          : 'Set recurring weekdays for client bookings',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF6B7272),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Open All Days',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFCCCCCC),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              FlashSwitch(
                key: const Key('open_all_days_switch'),
                value: _isAllDaysOpen,
                onChanged: _handleOpenAllDaysToggle,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: days.map((d) {
              final dayVal = d['val'] as int;
              final dayLabel = d['label'] as String;
              final isSelected = _workingDays.contains(dayVal);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: GestureDetector(
                    key: Key('working_day_$dayVal'),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          if (_workingDays.length > 1) {
                            _workingDays.remove(dayVal);
                          }
                        } else {
                          _workingDays.add(dayVal);
                        }
                      });
                    },
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF161818),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF2C2F30),
                        ),
                      ),
                      child: Text(
                        dayLabel,
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected ? const Color(0xFF121414) : const Color(0xFF8C9191),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            key: const Key('books_manage_days_off_link'),
            onTap: _navigateToCalendar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161818),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2C2F30)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_busy_outlined,
                    size: 16,
                    color: Color(0xFFEEC200),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Block specific dates in Calendar',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFCCCCCC),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (blockedCount > 0 || openedCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEC200).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        [
                          if (blockedCount > 0) '$blockedCount off',
                          if (openedCount > 0) '$openedCount open',
                        ].join(' · '),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEEC200),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: Color(0xFFEEC200),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleChip({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF161818),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF2C2F30),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? const Color(0xFF121414) : const Color(0xFF8C9191),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// Dynamic availability rules: minimum empty-day booking notice & Sun–Sat weekly cap
  Widget _buildAvailabilityRulesCard() {
    const leadTimeOptions = <({int hours, String label})>[
      (hours: 0, label: 'None'),
      (hours: 24, label: '24h'),
      (hours: 48, label: '48h'),
      (hours: 72, label: '72h'),
      (hours: 168, label: '7d'),
    ];
    const weeklyCapOptions = <({int? days, String label})>[
      (days: null, label: 'No Limit'),
      (days: 2, label: '2d'),
      (days: 3, label: '3d'),
      (days: 4, label: '4d'),
      (days: 5, label: '5d'),
      (days: 6, label: '6d'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'AVAILABILITY RULES',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C9191),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF161818),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2C2F30)),
                ),
                child: Text(
                  'Always Open',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'MINIMUM BOOKING NOTICE',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFCCCCCC),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lead time required before an empty day can be booked. Already-booked days keep open slots.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF6B7272),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: leadTimeOptions
                .map(
                  (opt) => _buildRuleChip(
                    key: Key('lead_time_chip_${opt.hours}'),
                    label: opt.label,
                    isSelected: _minLeadTimeHours == opt.hours,
                    onTap: () => setState(() => _minLeadTimeHours = opt.hours),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF282C2C), height: 1),
          const SizedBox(height: 16),
          Text(
            'MAX BOOKED DAYS / WEEK',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFCCCCCC),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sunday–Saturday cap. Once reached, remaining empty days auto-close while booked days stay open.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF6B7272),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: weeklyCapOptions
                .map(
                  (opt) => _buildRuleChip(
                    key: Key('weekly_cap_chip_${opt.days ?? 'none'}'),
                    label: opt.label,
                    isSelected: _maxWorkingDaysPerWeek == opt.days,
                    onTap: () =>
                        setState(() => _maxWorkingDaysPerWeek = opt.days),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  /// Working hours, session slot duration, and appointment buffer
  Widget _buildWorkingHoursAndBufferCard() {
    const slotDurations = [60, 120, 180, 240];
    const bufferDurations = [15, 30, 45, 60];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOURS & SLOT SIZING',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Powers time slots, 24h holds, and daily open hours',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF6B7272),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const Key('hours_all_modes_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEC200).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFEEC200).withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'All Modes',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEEC200),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  key: const Key('books_start_time_button'),
                  onTap: () => _pickTime(isStart: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161818),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2C2F30)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'START TIME',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF8C9191),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(_startTime),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  key: const Key('books_end_time_button'),
                  onTap: () => _pickTime(isStart: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161818),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2C2F30)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'END TIME',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF8C9191),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(_endTime),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'DEFAULT SLOT DURATION',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: slotDurations.map((mins) {
              final isSel = _slotDurationMinutes == mins;
              final label = mins >= 60 ? '${mins ~/ 60}h' : '${mins}m';
              return ChoiceChip(
                label: Text(label),
                selected: isSel,
                onSelected: (selected) {
                  if (selected) setState(() => _slotDurationMinutes = mins);
                },
                selectedColor: const Color(0xFFEEC200),
                backgroundColor: const Color(0xFF161818),
                labelStyle: GoogleFonts.plusJakartaSans(
                  color: isSel ? const Color(0xFF121414) : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSel ? const Color(0xFFEEC200) : const Color(0xFF2C2F30),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text(
            'BUFFER BETWEEN SESSIONS',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: bufferDurations.map((mins) {
              final isSel = _bufferMinutes == mins;
              return ChoiceChip(
                label: Text('${mins}m'),
                selected: isSel,
                onSelected: (selected) {
                  if (selected) setState(() => _bufferMinutes = mins);
                },
                selectedColor: const Color(0xFFEEC200),
                backgroundColor: const Color(0xFF161818),
                labelStyle: GoogleFonts.plusJakartaSans(
                  color: isSel ? const Color(0xFF121414) : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSel ? const Color(0xFFEEC200) : const Color(0xFF2C2F30),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.darkBorder, height: 1),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prevent awkward schedule gaps',
                      style: AppTypography.bodySmallBold.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hides flash start times that strand unusable holes between sessions',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppTheme.navInactive,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FlashSwitch(
                key: const Key('prevent_dead_gaps_switch'),
                value: _preventDeadGaps,
                onChanged: (val) => setState(() => _preventDeadGaps = val),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Minimum bookable session',
                      style: AppTypography.bodySmallBold.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Smallest tattoo session used to judge usable gaps',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppTheme.navInactive,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.onyxSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: const Key('min_bookable_session_dropdown'),
                    value: _minBookableSessionMinutes,
                    isDense: true,
                    dropdownColor: AppTheme.onyxContainer,
                    iconEnabledColor: AppTheme.gold,
                    style: AppTypography.bodySmallBold.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                    items: const [60, 90, 120]
                        .map(
                          (mins) => DropdownMenuItem<int>(
                            value: mins,
                            child: Text('$mins min'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _minBookableSessionMinutes = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Booking types accepted during this books window
  Widget _buildBookingTypesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACCEPTED SESSION TYPES',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          _buildToggleRow(
            title: 'Flash Tattoos',
            subtitle: 'Pre-drawn pieces from your portfolio',
            value: _acceptFlash,
            onChanged: (val) => setState(() => _acceptFlash = val),
          ),
          const Divider(color: Color(0xFF282C2C), height: 1),
          _buildToggleRow(
            title: 'Custom Concepts',
            subtitle: 'Client idea requests & design consultations',
            value: _acceptCustom,
            onChanged: (val) => setState(() => _acceptCustom = val),
          ),
          const Divider(color: Color(0xFF282C2C), height: 1),
          _buildToggleRow(
            title: 'Touch-ups',
            subtitle: 'Past clients can self-book even while public books are closed',
            value: _acceptTouchUps,
            switchKey: const Key('accept_touch_ups_switch'),
            onChanged: (val) => setState(() => _acceptTouchUps = val),
          ),
          if (_acceptTouchUps) _buildTouchUpSettingsPanel(),
        ],
      ),
    );
  }

  Widget _buildTouchUpSettingsPanel() {
    final isPaidTouchUp = _touchUpFeeDollars > 0;
    const feePresets = [20, 30, 40, 50, 75];

    return Container(
      key: const Key('touch_up_settings_panel'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2F30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOUCH-UP SESSION RULES',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFEEC200),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          // Duration & Buffer side-by-side
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Duration',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.onyxContainer,
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                        border: Border.all(color: const Color(0xFF2C2F30)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          key: const Key('touch_up_duration_dropdown'),
                          isExpanded: true,
                          isDense: true,
                          value: _touchUpDurationMinutes,
                          dropdownColor: AppTheme.onyxContainer,
                          iconEnabledColor: AppTheme.gold,
                          style: AppTypography.bodySmallBold.copyWith(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                          items: const [15, 30, 45, 60, 90, 120]
                              .map(
                                (mins) => DropdownMenuItem<int>(
                                  value: mins,
                                  child: Text('$mins min'),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _touchUpDurationMinutes = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cleanup Buffer',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.onyxContainer,
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                        border: Border.all(color: const Color(0xFF2C2F30)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          key: const Key('touch_up_buffer_dropdown'),
                          isExpanded: true,
                          isDense: true,
                          value: _touchUpBufferMinutes,
                          dropdownColor: AppTheme.onyxContainer,
                          iconEnabledColor: AppTheme.gold,
                          style: AppTypography.bodySmallBold.copyWith(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                          items: const [0, 15, 30, 45, 60]
                              .map(
                                (mins) => DropdownMenuItem<int>(
                                  value: mins,
                                  child: Text(mins == 0 ? 'None' : '$mins min'),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _touchUpBufferMinutes = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Eligibility window
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Self-Booking Window',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Opens 7 days after session; 1 per tattoo',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF8C9191),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.onyxContainer,
                  borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                  border: Border.all(color: const Color(0xFF2C2F30)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: const Key('touch_up_window_dropdown'),
                    isDense: true,
                    value: _touchUpWindowMonths,
                    dropdownColor: AppTheme.onyxContainer,
                    iconEnabledColor: AppTheme.gold,
                    style: AppTypography.bodySmallBold.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                    items: const [3, 6, 12]
                        .map(
                          (months) => DropdownMenuItem<int>(
                            value: months,
                            child: Text('$months months'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _touchUpWindowMonths = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Pricing Rule (Free vs Flat Fee / Deposit)
          Text(
            'TOUCH-UP PRICING',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  key: const Key('touch_up_pricing_free'),
                  onTap: () => setState(() => _touchUpFeeDollars = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !isPaidTouchUp
                          ? const Color(0xFFEEC200)
                          : AppTheme.onyxContainer,
                      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                      border: Border.all(
                        color: !isPaidTouchUp
                            ? const Color(0xFFEEC200)
                            : const Color(0xFF2C2F30),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Free (\$0)',
                        style: GoogleFonts.plusJakartaSans(
                          color: !isPaidTouchUp
                              ? const Color(0xFF121414)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  key: const Key('touch_up_pricing_paid'),
                  onTap: () => setState(() {
                    if (_touchUpFeeDollars <= 0) {
                      _touchUpFeeDollars = 30;
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isPaidTouchUp
                          ? const Color(0xFFEEC200)
                          : AppTheme.onyxContainer,
                      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                      border: Border.all(
                        color: isPaidTouchUp
                            ? const Color(0xFFEEC200)
                            : const Color(0xFF2C2F30),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Flat Fee / Deposit',
                        style: GoogleFonts.plusJakartaSans(
                          color: isPaidTouchUp
                              ? const Color(0xFF121414)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isPaidTouchUp) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: feePresets.map((amount) {
                final isSelected = _touchUpFeeDollars == amount;
                return GestureDetector(
                  key: Key('touch_up_fee_$amount'),
                  onTap: () => setState(() => _touchUpFeeDollars = amount),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEEC200).withValues(alpha: 0.18)
                          : AppTheme.onyxContainer,
                      borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFEEC200)
                            : const Color(0xFF2C2F30),
                      ),
                    ),
                    child: Text(
                      '\$$amount',
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected
                            ? const Color(0xFFEEC200)
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Touch-ups can fill shorter gaps between larger tattoos (dead-gap protection is skipped). Past the window or after 1 touch-up, clients are directed to message you.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Key? switchKey,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          FlashSwitch(
            key: switchKey,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// Location / Guest spot note
  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STUDIO OR GUEST SPOT LOCATION',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('books_location_field'),
            controller: _locationController,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF161818),
              hintText: 'e.g. OddMaree Studio • Portland, OR',
              hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6B7272), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2C2F30)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFEEC200)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Prominent save CTA button
  Widget _buildSaveButton() {
    return AppButtons.primaryCTA(
      key: const Key('save_books_schedule_button'),
      onPressed: _isSaving ? null : _handleSave,
      text: 'Save Books Schedule',
      isLoading: _isSaving,
      backgroundColor: const Color(0xFFEEC200),
      foregroundColor: const Color(0xFF121414),
    );
  }
}

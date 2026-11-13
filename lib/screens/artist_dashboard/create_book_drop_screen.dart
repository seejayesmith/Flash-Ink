import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard_data.dart';
import '../../models/waitlist_entry.dart';
import '../../theme/app_buttons.dart';
import '../../theme/app_radius.dart';
import '../../widgets/flash_snack_bar.dart';
import '../../widgets/flash_switch.dart';

/// Dedicated full-screen wizard for creating, configuring, and scheduling a Book Drop.
class CreateBookDropScreen extends StatefulWidget {
  final Artist? artist;

  const CreateBookDropScreen({
    super.key,
    this.artist,
  });

  static Future<bool?> show(BuildContext context, {Artist? artist}) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateBookDropScreen(artist: artist),
      ),
    );
  }

  @override
  State<CreateBookDropScreen> createState() => _CreateBookDropScreenState();
}

class _CreateBookDropScreenState extends State<CreateBookDropScreen> {
  int _currentStep = 0; // 0: Dates, 1: Scope, 2: Launch & VIP, 3: Review, 4: Celebration

  // Step 1: Dates & Working Windows
  late DateTime _displayedMonth;
  final Set<int> _selectedDays = {};
  TimeOfDay _startTime = const TimeOfDay(hour: 11, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 0);

  // Step 2: Scope & Intake
  bool _acceptFlash = true;
  bool _acceptCustom = true;
  bool _acceptTouchUps = false;
  bool _useRequestCap = false;
  int _requestCap = 25;

  // Step 3: Launch Strategy & VIP
  bool _launchImmediately = true;
  DateTime _scheduledLaunchDate = DateTime.now().add(const Duration(days: 2));
  TimeOfDay _scheduledLaunchTime = const TimeOfDay(hour: 10, minute: 0);
  bool _enableEarlyAccess = true;
  int _earlyAccessHours = 24;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);

    final schedule = ArtistDashboardRepository.booksSchedule;
    _startTime = schedule.startTime;
    _endTime = schedule.endTime;

    _preselectWorkingDaysForDisplayedMonth();
    // If no future working days remain in current month (e.g. end of month), default to next month
    if (_selectedDays.isEmpty) {
      _displayedMonth = DateTime(now.year, now.month + 1, 1);
      _preselectWorkingDaysForDisplayedMonth();
    }
  }

  void _preselectWorkingDaysForDisplayedMonth() {
    _selectedDays.clear();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final schedule = ArtistDashboardRepository.booksSchedule;
    final daysInMonth = DateUtils.getDaysInMonth(_displayedMonth.year, _displayedMonth.month);
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
      if (!date.isBefore(todayStart) && schedule.workingDays.contains(date.weekday)) {
        _selectedDays.add(day);
      }
    }
  }

  int get _waitingCount {
    return ArtistDashboardRepository.waitlistEntries
        .where((e) => e.status == WaitlistStatus.waiting)
        .length;
  }

  int get _bookableHoursPerDay {
    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;
    return ((endMin - startMin) / 60).round().clamp(1, 24);
  }

  int get _totalBookableHours {
    return _selectedDays.length * _bookableHoursPerDay;
  }

  void _onExitPressed() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.radiusLg)),
        title: Text(
          'Exit Drop Builder?',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Your selected dates and intake preferences will be discarded.',
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF919696), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Editing', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEEC200))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              Navigator.pop(context, false);
            },
            child: Text('Discard Draft', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  void _commitDrop() {
    final start = DateTime(_displayedMonth.year, _displayedMonth.month, _selectedDays.isEmpty ? 1 : _selectedDays.reduce((a, b) => a < b ? a : b));
    final end = DateTime(_displayedMonth.year, _displayedMonth.month, _selectedDays.isEmpty ? 28 : _selectedDays.reduce((a, b) => a > b ? a : b));
    final opensAt = _launchImmediately
        ? DateTime.now()
        : DateTime(
            _scheduledLaunchDate.year,
            _scheduledLaunchDate.month,
            _scheduledLaunchDate.day,
            _scheduledLaunchTime.hour,
            _scheduledLaunchTime.minute,
          );

    final newDrop = BookDrop(
      id: 'drop_${DateTime.now().millisecondsSinceEpoch}',
      title: '${_monthName(_displayedMonth.month)} Booking Drop',
      startDate: start,
      endDate: end,
      status: _launchImmediately
          ? (_enableEarlyAccess ? BookDropStatus.earlyAccess : BookDropStatus.open)
          : BookDropStatus.scheduled,
      selectedDays: Set.from(_selectedDays),
      acceptFlash: _acceptFlash,
      acceptCustom: _acceptCustom,
      acceptTouchUps: _acceptTouchUps,
      requestCap: _useRequestCap ? _requestCap : null,
      requestCount: 0,
      opensAt: opensAt,
      earlyAccessHours: _earlyAccessHours,
      earlyAccessEndsAt: _enableEarlyAccess
          ? opensAt.add(Duration(hours: _earlyAccessHours))
          : null,
    );

    ArtistDashboardRepository.isPaused = false;
    ArtistDashboardRepository.bookingMode = BookingMode.drops;
    ArtistDashboardRepository.currentBookDrop = newDrop;
    ArtistDashboardRepository.booksSchedule = ArtistDashboardRepository.booksSchedule.copyWith(
      isBooksOpen: _launchImmediately,
      isEarlyAccessOnly: _enableEarlyAccess && _launchImmediately,
      earlyAccessEndsAt: newDrop.earlyAccessEndsAt,
      earlyAccessHours: _earlyAccessHours,
      startTime: _startTime,
      endTime: _endTime,
      bookingWindowStart: start,
      bookingWindowEnd: end,
      acceptFlash: _acceptFlash,
      acceptCustom: _acceptCustom,
      acceptTouchUps: _acceptTouchUps,
    );

    if (_enableEarlyAccess && _launchImmediately) {
      ArtistDashboardRepository.sendEarlyAccessToWaitlist(hours: _earlyAccessHours);
    }

    setState(() {
      _currentStep = 4; // Celebration step
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 4) {
      return _buildCelebrationScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121414),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: 'Exit Draft',
          onPressed: _onExitPressed,
        ),
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2121),
            borderRadius: BorderRadius.circular(AppRadius.radiusFull),
            border: Border.all(color: const Color(0xFF2C2F30)),
          ),
          child: Text(
            'STEP ${_currentStep + 1} OF 4',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFEEC200),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FlashSnackBar.showInfo(context, 'Drop draft saved.');
              Navigator.pop(context, true);
            },
            child: Text(
              'Save Draft',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF8C9191),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
              backgroundColor: const Color(0xFF1E2121),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEEC200)),
              minHeight: 2,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: _buildCurrentStepContent(),
              ),
            ),
            _buildBottomNavControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Dates();
      case 1:
        return _buildStep2Scope();
      case 2:
        return _buildStep3Launch();
      case 3:
        return _buildStep4Review();
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _pickWorkingHour({required bool isStart}) async {
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
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickScheduledLaunchDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledLaunchDate.isBefore(now) ? now : _scheduledLaunchDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
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
      setState(() => _scheduledLaunchDate = picked);
    }
  }

  Future<void> _pickScheduledLaunchTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledLaunchTime,
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
      setState(() => _scheduledLaunchTime = picked);
    }
  }

  // -------------------------------------------------------------
  // Step 1: Dates & Working Windows
  // -------------------------------------------------------------
  Widget _buildStep1Dates() {
    final daysInMonth = DateUtils.getDaysInMonth(_displayedMonth.year, _displayedMonth.month);
    final firstDayWeekday = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday; // 1=Mon, 7=Sun
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Open Booking Days',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap days to include or exclude from this drop.',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8C9191),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),

        // Month Selector Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1C1C),
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(color: const Color(0xFF282C2C)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
                    _preselectWorkingDaysForDisplayedMonth();
                  });
                },
              ),
              Text(
                '${_monthName(_displayedMonth.month)} ${_displayedMonth.year}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
                    _preselectWorkingDaysForDisplayedMonth();
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Weekday Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'].map((d) {
            return SizedBox(
              width: 38,
              child: Center(
                child: Text(
                  d,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8C9191),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Month Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: (firstDayWeekday - 1) + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstDayWeekday - 1) {
              return const SizedBox.shrink();
            }
            final day = index - (firstDayWeekday - 1) + 1;
            final cellDate = DateTime(_displayedMonth.year, _displayedMonth.month, day);
            final isPast = cellDate.isBefore(todayStart);
            final isSelected = !isPast && _selectedDays.contains(day);

            return InkWell(
              onTap: isPast
                  ? null
                  : () {
                      setState(() {
                        if (isSelected) {
                          _selectedDays.remove(day);
                        } else {
                          _selectedDays.add(day);
                        }
                      });
                    },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isPast
                      ? const Color(0xFF131515)
                      : (isSelected ? const Color(0xFFEEC200) : const Color(0xFF1E2121)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPast
                        ? const Color(0xFF1C1E1E)
                        : (isSelected ? const Color(0xFFEEC200) : const Color(0xFF2C2F30)),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: GoogleFonts.plusJakartaSans(
                      color: isPast
                          ? const Color(0xFF4B5050)
                          : (isSelected ? const Color(0xFF121414) : Colors.white),
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Drop Snapshot Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2121),
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(color: const Color(0xFF2C2F30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DROP SNAPSHOT',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFEEC200),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '${_selectedDays.length} Working Days',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Bookable Hours',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191), fontSize: 13),
                    ),
                  ),
                  Text(
                    '~$_totalBookableHours hrs total',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Daily Hours',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191), fontSize: 13),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _pickWorkingHour(isStart: true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141616),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2C2F30)),
                          ),
                          child: Text(
                            _formatTime(_startTime),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF38BDF8),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '–',
                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191)),
                        ),
                      ),
                      InkWell(
                        onTap: () => _pickWorkingHour(isStart: false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141616),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2C2F30)),
                          ),
                          child: Text(
                            _formatTime(_endTime),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF38BDF8),
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
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Step 2: Scope & Intake Rules
  // -------------------------------------------------------------
  Widget _buildStep2Scope() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Intake Scope & Limits',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose what appointments you are accepting for this drop.',
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191), fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Session Types
        _buildCheckboxTile(
          title: 'Flash Tattoos',
          subtitle: 'Instant client booking from your flash portfolio.',
          value: _acceptFlash,
          onChanged: (val) => setState(() => _acceptFlash = val ?? true),
        ),
        const SizedBox(height: 10),
        _buildCheckboxTile(
          title: 'Custom Concepts',
          subtitle: 'Clients submit ideas for your approval before booking.',
          value: _acceptCustom,
          onChanged: (val) => setState(() => _acceptCustom = val ?? true),
        ),
        const SizedBox(height: 10),
        _buildCheckboxTile(
          title: 'Touch-ups & Consultations',
          subtitle: 'Short follow-up sessions for previous clients.',
          value: _acceptTouchUps,
          onChanged: (val) => setState(() => _acceptTouchUps = val ?? false),
        ),
        const SizedBox(height: 24),

        // Auto-close Cap
        Text(
          'AUTOMATIC CLOSE CAPACITY',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8C9191),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: const Color(0xFF1E2121),
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              border: Border.all(color: const Color(0xFF2C2F30)),
            ),
            child: RadioGroup<bool>(
              groupValue: _useRequestCap,
              onChanged: (val) => setState(() => _useRequestCap = val ?? false),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: false,
                    activeColor: const Color(0xFFEEC200),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Close when all working hours fill up (Default)',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Continuous bookings until zero time remains on selected days.',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191), fontSize: 11.5),
                    ),
                  ),
                  const Divider(color: Color(0xFF2C2F30), height: 16),
                  RadioListTile<bool>(
                    value: true,
                    activeColor: const Color(0xFFEEC200),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Cap total requests / bookings',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Auto-closes books once a target number of requests is reached.',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191), fontSize: 11.5),
                    ),
                  ),
                  if (_useRequestCap) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Max Requests Cap:',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEEC200)),
                              onPressed: () {
                                if (_requestCap > 5) setState(() => _requestCap -= 5);
                              },
                            ),
                            Text(
                              '$_requestCap',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFFEEC200)),
                              onPressed: () {
                                if (_requestCap < 100) setState(() => _requestCap += 5);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Step 3: Launch Strategy & VIP
  // -------------------------------------------------------------
  Widget _buildStep3Launch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Release Strategy & VIP',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Decide when books release and who gets priority access.',
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191), fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Release Timing
        Text(
          'LAUNCH TIMING',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF8C9191),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: const Color(0xFF1E2121),
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              border: Border.all(color: const Color(0xFF2C2F30)),
            ),
            child: RadioGroup<bool>(
              groupValue: _launchImmediately,
              onChanged: (val) => setState(() => _launchImmediately = val ?? true),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: true,
                    activeColor: const Color(0xFFEEC200),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Launch Drop Immediately',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Books open right away as soon as you tap Commit.',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191), fontSize: 11.5),
                    ),
                  ),
                  const Divider(color: Color(0xFF2C2F30), height: 16),
                  RadioListTile<bool>(
                    value: false,
                    activeColor: const Color(0xFFEEC200),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Schedule Future Launch Date & Time',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Creates a countdown badge on your profile to build hype.',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191), fontSize: 11.5),
                    ),
                  ),
                  if (!_launchImmediately) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            key: const Key('scheduled_launch_date_picker'),
                            onTap: _pickScheduledLaunchDate,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141616),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF2C2F30)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LAUNCH DATE',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF8C9191),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatShortDate(_scheduledLaunchDate),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFFEEC200),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            key: const Key('scheduled_launch_time_picker'),
                            onTap: _pickScheduledLaunchTime,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141616),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF2C2F30)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LAUNCH TIME',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF8C9191),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatTime(_scheduledLaunchTime),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFFEEC200),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // VIP Waitlist Early Access
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D1D),
            borderRadius: BorderRadius.circular(AppRadius.radiusLg),
            border: Border.all(
              color: const Color(0xFFEEC200).withAlpha(100),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFEEC200), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'VIP Waitlist First Dibs',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FlashSwitch(
                    value: _enableEarlyAccess,
                    onChanged: (val) => setState(() => _enableEarlyAccess = val),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Give your $_waitingCount waitlist contacts priority access before general public release.',
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191), fontSize: 12),
              ),
              if (_enableEarlyAccess) ...[
                const SizedBox(height: 14),
                Text(
                  'Exclusive VIP Window Duration:',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [24, 48, 72].map((hours) {
                    final isSel = _earlyAccessHours == hours;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$hours Hours'),
                        selected: isSel,
                        selectedColor: const Color(0xFFEEC200),
                        backgroundColor: const Color(0xFF1E2121),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: isSel ? const Color(0xFF121414) : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _earlyAccessHours = hours);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Step 4: Summary & Commit
  // -------------------------------------------------------------
  Widget _buildStep4Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review & Commit Drop',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Please verify the details below before committing your schedule.',
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191), fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Master Summary Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1C1C),
            borderRadius: BorderRadius.circular(AppRadius.radiusLg),
            border: Border.all(color: const Color(0xFFEEC200), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEEC200).withAlpha(20),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_stories_rounded, color: Color(0xFFEEC200), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '${_monthName(_displayedMonth.month)} Booking Drop',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: Color(0xFF2C2F30), height: 1),
              ),
              _buildReviewRow('Open Days', '${_selectedDays.length} working days selected'),
              _buildReviewRow('Daily Hours', '${_formatTime(_startTime)} – ${_formatTime(_endTime)}'),
              _buildReviewRow('Estimated Capacity', '~$_totalBookableHours bookable hours'),
              _buildReviewRow(
                'Accepting',
                [
                  if (_acceptFlash) 'Flash',
                  if (_acceptCustom) 'Customs',
                  if (_acceptTouchUps) 'Touch-ups',
                ].join(' • '),
              ),
              _buildReviewRow(
                'Intake Limit',
                _useRequestCap ? 'Cap at $_requestCap requests' : 'Full working hours capacity',
              ),
              _buildReviewRow(
                'Launch Strategy',
                _launchImmediately
                    ? 'Immediate Launch'
                    : 'Scheduled: ${_formatShortDate(_scheduledLaunchDate)} at ${_formatTime(_scheduledLaunchTime)}',
              ),
              if (_enableEarlyAccess)
                _buildReviewRow(
                  'VIP Early Access',
                  '$_earlyAccessHours hrs exclusive for $_waitingCount waitlist contacts',
                  valueColor: const Color(0xFFEEC200),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Celebration Screen
  // -------------------------------------------------------------
  Widget _buildCelebrationScreen() {
    final cleanHandle = widget.artist != null && widget.artist!.name.trim().isNotEmpty
        ? widget.artist!.name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')
        : 'artist';
    final shareLink = 'flash.ink/@${cleanHandle.isEmpty ? 'artist' : cleanHandle}/books';

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEC200).withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEEC200), width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFFEEC200),
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _launchImmediately
                    ? 'Your Booking Drop is Live!'
                    : 'Your Booking Drop is Scheduled!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                !_launchImmediately
                    ? 'Launches on ${_formatShortDate(_scheduledLaunchDate)} at ${_formatTime(_scheduledLaunchTime)}. Waitlist VIPs will get early access.'
                    : (_enableEarlyAccess
                        ? 'Exclusive VIP early access has been sent to your $_waitingCount waitlist members.'
                        : 'Your books are now open for clients on Flash.Ink.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C9191),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Share Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2121),
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  border: Border.all(color: const Color(0xFF2C2F30)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        shareLink,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: 'https://$shareLink'));
                        FlashSnackBar.showSuccess(context, 'Booking link copied to clipboard!');
                      },
                      child: Text(
                        'Copy Link',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEEC200),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AppButtons.primaryCTA(
                onPressed: () => Navigator.pop(context, true),
                text: 'Done & Return to Dashboard',
                backgroundColor: const Color(0xFF262A2A),
                foregroundColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------
  Widget _buildBottomNavControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161818),
        border: Border(top: BorderSide(color: Color(0xFF282C2C))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: AppButtons.secondaryCTA(
                onPressed: () => setState(() => _currentStep--),
                text: 'Back',
                borderColor: const Color(0xFF383C3C),
                foregroundColor: Colors.white,
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: AppButtons.primaryCTA(
              key: _currentStep == 3 ? const Key('commit_book_drop_button') : null,
              onPressed: () {
                if (_currentStep == 0 && _selectedDays.isEmpty) {
                  FlashSnackBar.showError(context, 'Please select at least 1 working day.');
                  return;
                }
                if (_currentStep == 1 && !_acceptFlash && !_acceptCustom && !_acceptTouchUps) {
                  FlashSnackBar.showError(context, 'Select at least one session type to accept.');
                  return;
                }
                if (_currentStep < 3) {
                  setState(() => _currentStep++);
                } else {
                  _commitDrop();
                }
              },
              text: _currentStep == 3
                  ? (_launchImmediately ? 'Commit & Launch Drop' : 'Commit & Schedule Drop')
                  : 'Continue ➔',
              backgroundColor: const Color(0xFFEEC200),
              foregroundColor: const Color(0xFF121414),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Material(
      color: const Color(0xFF1E2121),
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          border: Border.all(color: value ? const Color(0xFFEEC200).withAlpha(120) : const Color(0xFF2C2F30)),
        ),
        child: CheckboxListTile(
          value: value,
          activeColor: const Color(0xFFEEC200),
          checkColor: const Color(0xFF121414),
          title: Text(
            title,
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191), fontSize: 12),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8C9191), fontSize: 13),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                color: valueColor ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(DateTime dt) {
    return '${_monthName(dt.month).substring(0, 3)} ${dt.day}, ${dt.year}';
  }

  String _formatTime(TimeOfDay tod) {
    final h = tod.hour == 0 ? 12 : (tod.hour > 12 ? tod.hour - 12 : tod.hour);
    final m = tod.minute.toString().padLeft(2, '0');
    final p = tod.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[(month - 1).clamp(0, 11)];
  }
}

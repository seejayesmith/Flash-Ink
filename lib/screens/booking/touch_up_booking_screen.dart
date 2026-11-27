import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/calendar_event_launcher.dart';
import '../../features/appointments/domain/models/appointment_item.dart';
import '../../models/artist_dashboard/artist_books_schedule.dart';
import '../../models/artist_dashboard/book_drop.dart';
import '../../repositories/artist_availability_calculator.dart';
import '../../repositories/artist_dashboard_repository.dart';
import '../../services/booking_sync_service.dart';
import '../../services/scheduling/booking_slot_profile.dart';
import '../../services/scheduling/slot_availability_engine.dart';
import '../../services/scheduling/touch_up_eligibility.dart';
import '../../services/touch_up_service.dart';
import '../../theme/app_buttons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_snack_bar.dart';

/// Client self-booking screen for scheduling a touch-up linked to a completed tattoo.
///
/// Uses `BookingSlotType.touchUp` (gating on `acceptTouchUps`, skipping dead-gap
/// protection, and respecting the artist's configured duration, buffer, and fee).
class TouchUpBookingScreen extends StatefulWidget {
  final ClientAppointment originalAppointment;
  final ArtistBooksSchedule? initialSchedule;
  final String? threadId;
  final TouchUpService? touchUpService;

  const TouchUpBookingScreen({
    super.key,
    required this.originalAppointment,
    this.initialSchedule,
    this.threadId,
    this.touchUpService,
  });

  @override
  State<TouchUpBookingScreen> createState() => _TouchUpBookingScreenState();
}

class _TouchUpBookingScreenState extends State<TouchUpBookingScreen> {
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _weekdays = [
    'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa',
  ];

  late final TouchUpService _touchUpService =
      widget.touchUpService ?? TouchUpService();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();

  late ArtistBooksSchedule _schedule;
  bool _isLoadingSchedule = false;
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  String _selectedTimeSlot = '';
  Uint8List? _healedPhotoBytes;
  String? _healedPhotoName;
  bool _isSubmitting = false;
  TouchUpBookingResult? _confirmedResult;

  String? get _artistId => widget.originalAppointment.artistId;

  @override
  void initState() {
    super.initState();
    _schedule = widget.initialSchedule ?? ArtistDashboardRepository.booksSchedule;
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectFirstAvailableDate();
    if (widget.initialSchedule == null) {
      _refreshArtistSchedule();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _refreshArtistSchedule() async {
    final artistId = _artistId?.trim() ?? '';
    if (artistId.isEmpty) return;
    setState(() => _isLoadingSchedule = true);
    try {
      final fetched =
          await BookingSyncService.fetchArtistScheduleFromCloud(artistId);
      if (fetched != null && mounted) {
        setState(() {
          _schedule = fetched;
          _selectFirstAvailableDate();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingSchedule = false);
    }
  }

  void _selectFirstAvailableDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eligibility = TouchUpEligibilityService.evaluate(
      originalAppointment: widget.originalAppointment,
      schedule: _schedule,
      now: now,
    );
    final maxDate = eligibility.windowEndsAt ?? today.add(const Duration(days: 90));

    DateTime? picked;
    for (int i = 0; i < 60; i++) {
      final candidate = today.add(Duration(days: i));
      if (candidate.isAfter(maxDate)) break;
      if (_isDateBookable(candidate)) {
        picked = candidate;
        break;
      }
    }

    _selectedDate = picked;
    if (picked != null) {
      _currentMonth = DateTime(picked.year, picked.month, 1);
      final slots = _availableSlotsForDate(picked);
      _selectedTimeSlot = slots.isNotEmpty ? slots.first.time : '';
    } else {
      _selectedTimeSlot = '';
    }
  }

  bool _isDateBookable(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date.isBefore(today)) return false;
    final eligibility = TouchUpEligibilityService.evaluate(
      originalAppointment: widget.originalAppointment,
      schedule: _schedule,
      now: now,
    );
    if (eligibility.windowEndsAt != null &&
        date.isAfter(eligibility.windowEndsAt!)) {
      return false;
    }
    return ArtistDashboardRepository.isDateBookable(
      date: date,
      schedule: _schedule,
      artistId: _artistId,
      slotType: BookingSlotType.touchUp,
      now: now,
    );
  }

  List<AvailableSlot> _availableSlotsForDate(DateTime date) {
    final now = DateTime.now();
    final repoSchedule = ArtistDashboardRepository.booksSchedule;
    return SlotAvailabilityEngine.generateAvailableSlots(
      date: date,
      schedule: _schedule,
      slotType: BookingSlotType.touchUp,
      localAppointments: ArtistAvailabilityCalculator.matchingAppointments(
        schedule: _schedule,
        repoSchedule: repoSchedule,
        calendarAppointments: ArtistDashboardRepository.calendarAppointments,
        artistId: _artistId,
      ),
      localHolds: ArtistAvailabilityCalculator.activeLocalHolds(
        schedule: _schedule,
        repoSchedule: repoSchedule,
        customHolds: ArtistDashboardRepository.customHolds,
        now: now,
      ),
      now: now,
      enforceLeadTime:
          ArtistDashboardRepository.bookingMode == BookingMode.alwaysOpen,
      hasBookingOrHoldOnDay: ArtistDashboardRepository.isDateOccupied(
        date,
        schedule: _schedule,
        artistId: _artistId,
        now: now,
      ),
    );
  }

  Future<void> _pickHealedPhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _healedPhotoBytes = bytes;
        _healedPhotoName = picked.name;
      });
    } catch (_) {
      if (!mounted) return;
      FlashSnackBar.showError(
        context,
        'Could not load photo. You can still book without attaching a photo.',
      );
    }
  }

  Future<void> _handleConfirmBooking() async {
    if (_selectedDate == null || _selectedTimeSlot.isEmpty) {
      FlashSnackBar.showError(
        context,
        'Please select a date and time slot for your touch-up.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await _touchUpService.bookTouchUp(
      originalAppointment: widget.originalAppointment,
      schedule: _schedule,
      selectedDate: _selectedDate!,
      selectedTimeSlot: _selectedTimeSlot,
      clientNotes: _notesController.text,
      healedPhotoBytes: _healedPhotoBytes,
      healedPhotoFileName: _healedPhotoName,
      threadId: widget.threadId,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.canceled) {
      FlashSnackBar.showInfo(context, 'Checkout canceled.');
      return;
    }

    if (!result.success) {
      FlashSnackBar.showError(
        context,
        result.errorMessage ?? 'Unable to book touch-up right now.',
      );
      if (result.isSlotConflict) {
        _refreshArtistSchedule();
      }
      return;
    }

    setState(() => _confirmedResult = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmedResult != null) {
      return _buildConfirmationView(_confirmedResult!);
    }

    final feeDollars = _schedule.touchUpFeeDollars;
    final durationLabel = TouchUpEligibilityService.formatDurationLabel(
      _schedule.touchUpDurationMinutes,
    );
    final slots = _selectedDate != null
        ? _availableSlotsForDate(_selectedDate!)
        : const <AvailableSlot>[];

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.onyxSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Book Touch-up',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenGutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOriginalTattooRecap(
                      feeDollars: feeDollars,
                      durationLabel: durationLabel,
                    ),
                    const SizedBox(height: 20),
                    if (_isLoadingSchedule)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(
                          color: AppTheme.gold,
                          backgroundColor: AppTheme.cardBackground,
                        ),
                      ),
                    _buildSectionLabel('SELECT DATE'),
                    const SizedBox(height: 10),
                    _buildCalendarCard(),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionLabel('SELECT TIME SLOT'),
                        Text(
                          'Est. $durationLabel',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTimeSlotsGrid(slots),
                    const SizedBox(height: 22),
                    _buildSectionLabel('HEALED TATTOO PHOTO (OPTIONAL)'),
                    const SizedBox(height: 8),
                    _buildOptionalPhotoSection(),
                    const SizedBox(height: 22),
                    _buildSectionLabel('NOTES FOR ARTIST (OPTIONAL)'),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('touch_up_notes_field'),
                      controller: _notesController,
                      maxLines: 3,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 13.5,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.cardBackground,
                        hintText:
                            'e.g. Slight fading along the upper linework...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: AppTheme.navInactive,
                          fontSize: 13,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.radiusMd),
                          borderSide: const BorderSide(color: AppTheme.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.radiusMd),
                          borderSide: const BorderSide(color: AppTheme.gold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                12,
                AppSpacing.screenGutter,
                16,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.onyxSurface,
                border: Border(top: BorderSide(color: AppTheme.darkBorder)),
              ),
              child: AppButtons.primaryCTA(
                key: const Key('confirm_touch_up_booking_button'),
                onPressed: (_isSubmitting ||
                        _selectedDate == null ||
                        _selectedTimeSlot.isEmpty)
                    ? null
                    : _handleConfirmBooking,
                isLoading: _isSubmitting,
                text: feeDollars <= 0
                    ? 'Confirm Free Touch-up'
                    : 'Pay \$$feeDollars & Book Touch-up',
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.onyxBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: AppTheme.navInactive,
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildOriginalTattooRecap({
    required int feeDollars,
    required String durationLabel,
  }) {
    final orig = widget.originalAppointment;
    return Container(
      key: const Key('touch_up_original_recap'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppTheme.goldBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            child: SizedBox(
              width: 58,
              height: 58,
              child: FlashImage(
                urlOrPath: orig.flashImageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orig.flashTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'with ${orig.artistName} • ${orig.placement}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: feeDollars <= 0
                            ? const Color(0xFF1E2E20)
                            : const Color(0xFF332B14),
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                        border: Border.all(
                          color: feeDollars <= 0
                              ? const Color(0xFF4ADE80)
                              : AppTheme.gold,
                        ),
                      ),
                      child: Text(
                        feeDollars <= 0
                            ? 'FREE TOUCH-UP'
                            : 'FEE: \$$feeDollars',
                        style: GoogleFonts.plusJakartaSans(
                          color: feeDollars <= 0
                              ? const Color(0xFF4ADE80)
                              : AppTheme.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.onyxContainer,
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Text(
                        durationLabel,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildCalendarCard() {
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    final totalCells = firstWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: const Color(0xFF38352A), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                key: const Key('touch_up_prev_month'),
                icon:
                    const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month - 1,
                      1,
                    );
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                key: const Key('touch_up_next_month'),
                icon: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textPrimary,
                ),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month + 1,
                      1,
                    );
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekdays.map((day) {
              return SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    day,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF6B7272),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Column(
            children: List.generate(rowCount, (rowIndex) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (colIndex) {
                    final dayNum = rowIndex * 7 + colIndex - firstWeekday + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const SizedBox(width: 34, height: 34);
                    }
                    final cellDate = DateTime(
                      _currentMonth.year,
                      _currentMonth.month,
                      dayNum,
                    );
                    final isBookable = _isDateBookable(cellDate);
                    final isSelected = _selectedDate != null &&
                        cellDate.year == _selectedDate!.year &&
                        cellDate.month == _selectedDate!.month &&
                        cellDate.day == _selectedDate!.day;

                    return GestureDetector(
                      key: Key('touch_up_day_$dayNum'),
                      onTap: !isBookable
                          ? null
                          : () {
                              final nextSlots =
                                  _availableSlotsForDate(cellDate);
                              setState(() {
                                _selectedDate = cellDate;
                                _selectedTimeSlot = nextSlots.isNotEmpty
                                    ? nextSlots.first.time
                                    : '';
                              });
                            },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isSelected ? AppTheme.gold : Colors.transparent,
                          border: isSelected
                              ? Border.all(color: AppTheme.gold, width: 1.5)
                              : (cellDate.year == today.year &&
                                      cellDate.month == today.month &&
                                      cellDate.day == today.day
                                  ? Border.all(
                                      color: const Color(0xFF4D5252),
                                      width: 1,
                                    )
                                  : null),
                        ),
                        child: Center(
                          child: Text(
                            '$dayNum',
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? AppTheme.onyxBackground
                                  : (isBookable
                                      ? AppTheme.textPrimary
                                      : const Color(0xFF424747)),
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
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
    );
  }

  Widget _buildTimeSlotsGrid(List<AvailableSlot> slots) {
    if (slots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Text(
          'No open touch-up slots on this date. Try selecting another working day.',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.navInactive,
            fontSize: 12.5,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isSelected = _selectedTimeSlot == slot.time;
        return GestureDetector(
          key: Key('touch_up_slot_${slot.time}'),
          onTap: () => setState(() => _selectedTimeSlot = slot.time),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.gold : AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              border: Border.all(
                color: isSelected ? AppTheme.gold : AppTheme.cardBorder,
              ),
            ),
            child: Text(
              slot.time,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected
                    ? AppTheme.onyxBackground
                    : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOptionalPhotoSection() {
    if (_healedPhotoBytes != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          border: Border.all(color: AppTheme.goldBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              child: Image.memory(
                _healedPhotoBytes!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Healed photo attached',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _healedPhotoName ?? 'healed_tattoo.jpg',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.navInactive,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('remove_healed_photo_button'),
              icon: const Icon(Icons.close, color: AppTheme.navInactive),
              onPressed: () => setState(() {
                _healedPhotoBytes = null;
                _healedPhotoName = null;
              }),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adding a quick photo of your healed tattoo helps your artist prepare needles & ink, though it is completely optional.',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.navInactive,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('touch_up_pick_gallery_button'),
                  onPressed: () => _pickHealedPhoto(ImageSource.gallery),
                  icon: const Icon(
                    Icons.photo_library_outlined,
                    size: 16,
                    color: AppTheme.gold,
                  ),
                  label: Text(
                    'Photo Library',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.darkBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('touch_up_pick_camera_button'),
                  onPressed: () => _pickHealedPhoto(ImageSource.camera),
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    size: 16,
                    color: AppTheme.gold,
                  ),
                  label: Text(
                    'Camera',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.darkBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
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

  Widget _buildConfirmationView(TouchUpBookingResult result) {
    final apt = result.appointment!;
    final isFree = apt.totalPrice <= 0;

    return Scaffold(
      backgroundColor: AppTheme.onyxBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spaceLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2E20),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF4ADE80), width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF4ADE80),
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Touch-up Confirmed!',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isFree
                    ? 'Your complimentary touch-up with ${apt.artistName} is locked in.'
                    : 'Your \$${apt.totalPrice} touch-up with ${apt.artistName} is confirmed.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.navInactive,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  border: Border.all(color: AppTheme.goldBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apt.flashTitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${TouchUpEligibilityService.formatShortDate(apt.dateTime)} at ${apt.timeSlot}',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Placement: ${apt.placement} • Ref: ${apt.id}',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.navInactive,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppButtons.secondaryCTA(
                onPressed: () {
                  final event = CalendarEventLauncher.buildTattooAppointmentEvent(
                    date: apt.dateTime,
                    timeSlot: _selectedTimeSlot,
                    durationMinutes: _schedule.touchUpDurationMinutes,
                    flashTitle: apt.flashTitle,
                    artistName: apt.artistName,
                    studioName: apt.studioName,
                    studioAddress: apt.studioAddress,
                    placement: apt.placement,
                    depositAmount: apt.depositAmount,
                    totalPrice: apt.totalPrice,
                    notes: apt.notes,
                  );
                  CalendarEventLauncher.addEventToCalendar(
                    context,
                    event,
                    confirmationMessage:
                        'Touch-up session saved to your device calendar!',
                  );
                },
                icon: Icons.calendar_month_outlined,
                text: 'Add to Calendar',
                borderColor: AppTheme.goldBorder,
                foregroundColor: AppTheme.gold,
              ),
              const SizedBox(height: 12),
              AppButtons.primaryCTA(
                key: const Key('touch_up_done_button'),
                onPressed: () => Navigator.pop(context, result),
                text: 'Done',
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.onyxBackground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

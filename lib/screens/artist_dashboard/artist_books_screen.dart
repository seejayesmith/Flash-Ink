import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/flash_bottom_nav_bar.dart';
import '../../models/artist.dart';
import '../../models/artist_dashboard_data.dart';
import '../../models/waitlist_entry.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/flash_switch.dart';
import '../../widgets/tattoo_machine_icon.dart';
import 'add_waitlist_entry_sheet.dart';
import 'artist_account_screen.dart';
import 'artist_waitlist_screen.dart';
import 'books_open_options_modal.dart';
import 'early_access_outreach_sheet.dart';

/// Screen allowing tattoo artists to manage and create their "Books" schedule.
///
/// Houses controls for Books Open/Closed status, booking window ranges,
/// recurring working days/hours, slot duration/buffers, and accepted session types.
class ArtistBooksScreen extends StatefulWidget {
  final Artist? artist;
  final AuthService? authService;
  final bool isEmbeddedInTab;
  final VoidCallback? onBack;

  const ArtistBooksScreen({
    super.key,
    this.artist,
    this.authService,
    this.isEmbeddedInTab = false,
    this.onBack,
  });

  @override
  State<ArtistBooksScreen> createState() => _ArtistBooksScreenState();
}

class _ArtistBooksScreenState extends State<ArtistBooksScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();

  late bool _isBooksOpen;
  late DateTime _windowStart;
  late DateTime _windowEnd;
  late Set<int> _workingDays;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _slotDurationMinutes;
  late int _bufferMinutes;
  late int _defaultDeposit;
  late bool _acceptFlash;
  late bool _acceptCustom;
  late bool _acceptTouchUps;
  late final TextEditingController _locationController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final schedule = ArtistDashboardRepository.booksSchedule;
    _isBooksOpen = schedule.isBooksOpen;
    _windowStart = schedule.bookingWindowStart;
    _windowEnd = schedule.bookingWindowEnd;
    _workingDays = Set<int>.from(schedule.workingDays);
    _startTime = schedule.startTime;
    _endTime = schedule.endTime;
    _slotDurationMinutes = schedule.slotDurationMinutes;
    _bufferMinutes = schedule.bufferDurationMinutes;
    _defaultDeposit = schedule.defaultDepositAmount;
    _acceptFlash = schedule.acceptFlash;
    _acceptCustom = schedule.acceptCustom;
    _acceptTouchUps = schedule.acceptTouchUps;
    _locationController = TextEditingController(text: schedule.locationNote);
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _windowStart, end: _windowEnd),
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
    setState(() => _isSaving = true);

    final updated = ArtistBooksSchedule(
      isBooksOpen: _isBooksOpen,
      bookingWindowStart: _windowStart,
      bookingWindowEnd: _windowEnd,
      workingDays: _workingDays,
      startTime: _startTime,
      endTime: _endTime,
      slotDurationMinutes: _slotDurationMinutes,
      bufferDurationMinutes: _bufferMinutes,
      defaultDepositAmount: _defaultDeposit,
      acceptFlash: _acceptFlash,
      acceptCustom: _acceptCustom,
      acceptTouchUps: _acceptTouchUps,
      locationNote: _locationController.text.trim().isEmpty
          ? 'OddMaree Studio • Portland, OR'
          : _locationController.text.trim(),
    );

    // 1. Update in-memory repository
    ArtistDashboardRepository.updateBooksSchedule(updated);

    // 2. Hybrid sync with Firestore if authenticated
    try {
      final user = _authService.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFFEEC200), size: 18),
            const SizedBox(width: 8),
            Text(
              'Books schedule saved successfully!',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E2121),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEEC200), width: 1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopActionBar(),
            const SizedBox(height: 20),
            _buildHeaderTitleRow(),
            const SizedBox(height: 20),
            _buildStatusHeroCard(),
            const SizedBox(height: 24),
            _buildBookingWindowCard(),
            const SizedBox(height: 24),
            _buildWorkingDaysCard(),
            const SizedBox(height: 24),
            _buildWorkingHoursAndBufferCard(),
            const SizedBox(height: 24),
            _buildBookingTypesCard(),
            const SizedBox(height: 24),
            _buildLocationCard(),
            const SizedBox(height: 24),
            _buildWaitlistSectionCard(),
            const SizedBox(height: 32),
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
      body: Stack(
        children: [
          content,
          Positioned(
            left: AppTheme.navBarHorizontalMargin,
            right: AppTheme.navBarHorizontalMargin,
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
    );
  }

  /// Top action bar with tattoo machine logo on left and avatar on right
  Widget _buildTopActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!widget.isEmbeddedInTab && Navigator.canPop(context))
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.pop(context);
              }
            },
          )
        else
          const TattooMachineIcon(
            key: Key('tattoo_machine_logo'),
            size: 43,
            color: Color(0xFFEEC200),
          ),
        GestureDetector(
          key: const Key('books_artist_avatar_button'),
          onTap: () {
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
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFEEC200).withAlpha(120),
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF262929),
              child: ClipOval(
                child: FlashImage(
                  urlOrPath: _avatarUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorWidget: Center(
                    child: Text(
                      _artistDisplayName.isNotEmpty ? _artistDisplayName[0] : 'O',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEEC200),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
      ],
    );
  }

  /// Hero card displaying current Books Open / Closed status with live toggle
  Widget _buildStatusHeroCard() {
    final schedule = ArtistDashboardRepository.booksSchedule;
    final isEarlyAccess = schedule.isEarlyAccessActive;

    final activeColor = isEarlyAccess
        ? const Color(0xFFEEC200)
        : (_isBooksOpen ? const Color(0xFF22C55E) : const Color(0xFF919696));
    final borderColor = isEarlyAccess
        ? const Color(0xFFEEC200)
        : (_isBooksOpen ? const Color(0xFF22C55E) : const Color(0xFF282C2C));

    return Container(
      key: const Key('books_status_card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: (_isBooksOpen || isEarlyAccess) ? 1.5 : 1.0),
        boxShadow: [
          if (_isBooksOpen || isEarlyAccess)
            BoxShadow(
              color: (isEarlyAccess ? const Color(0xFFEEC200) : const Color(0xFF22C55E)).withAlpha(20),
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
              Row(
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
                  Text(
                    isEarlyAccess
                        ? 'VIP EARLY ACCESS ACTIVE'
                        : (_isBooksOpen ? 'BOOKS OPEN' : 'BOOKS CLOSED'),
                    style: GoogleFonts.plusJakartaSans(
                      color: activeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              FlashSwitch(
                key: const Key('books_status_switch'),
                value: _isBooksOpen,
                onChanged: (val) {
                  setState(() => _isBooksOpen = val);
                  if (!val) {
                    ArtistDashboardRepository.closeBooks();
                  } else {
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
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isEarlyAccess
                ? 'VIP Waitlist Early Access Live'
                : (_isBooksOpen ? 'Accepting New Appointments' : 'Currently Closed to Inquiries'),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEarlyAccess
                ? 'Your private waitlist members have exclusive access before public release.'
                : (_isBooksOpen
                    ? 'Clients can view your available calendar slots and request bookings directly.'
                    : 'Clients can browse your portfolio, but general booking submissions are paused.'),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Books opened to public!'),
                          backgroundColor: Color(0xFF22C55E),
                        ),
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
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF2A2E2E),
                        child: ClipOval(
                          child: entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                              ? FlashImage(
                                  urlOrPath: entry.avatarUrl!,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.cover,
                                  errorWidget: Center(
                                    child: Text(
                                      entry.clientName.isNotEmpty ? entry.clientName[0] : '?',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFEEC200),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  entry.clientName.isNotEmpty ? entry.clientName[0] : '?',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFEEC200),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
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


  /// Booking window date range card
  Widget _buildBookingWindowCard() {
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
              Text(
                'BOOKING WINDOW',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C9191),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              GestureDetector(
                key: const Key('booking_window_picker_button'),
                onTap: _pickDateRange,
                child: Row(
                  children: [
                    const Icon(Icons.edit_calendar_outlined, color: Color(0xFFEEC200), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'EDIT RANGE',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEEC200),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: Color(0xFF8C9191), size: 16),
              ),
              Expanded(
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
            ],
          ),
        ],
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
            'WEEKLY WORKING DAYS',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((d) {
              final dayVal = d['val'] as int;
              final dayLabel = d['label'] as String;
              final isSelected = _workingDays.contains(dayVal);

              return GestureDetector(
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
                  width: 40,
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
              );
            }).toList(),
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
          Text(
            'HOURS & SLOT SIZING',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF8C9191),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
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
            title: 'Touch-ups & Consultations',
            subtitle: 'Follow-ups and sizing discussions',
            value: _acceptTouchUps,
            onChanged: (val) => setState(() => _acceptTouchUps = val),
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
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        key: const Key('save_books_schedule_button'),
        onPressed: _isSaving ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEEC200),
          foregroundColor: const Color(0xFF121414),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF121414)),
                ),
              )
            : Text(
                'Save Books Schedule',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}

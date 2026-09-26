import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist.dart';
import '../../models/booking.dart';
import '../../theme/app_buttons.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/flash_image.dart';
import '../../features/messages/domain/models/message_thread.dart';
import '../../features/messages/presentation/screens/chat_conversation_screen.dart';


/// Full-flow booking screen for claiming a flash artwork piece.
///
/// Features 4 sequential steps:
/// 1. Schedule (Interactive Calendar & Time Slot Picker + Preferences)
/// 2. Client Details & Studio Policy Agreement
/// 3. Order Breakdown & Deposit Payment
/// 4. Celebratory Booking Confirmation & Session Preparation
class FlashBookingScreen extends StatefulWidget {
  final FlashArtwork flash;
  final Artist? artist;

  const FlashBookingScreen({
    super.key,
    required this.flash,
    this.artist,
  });

  @override
  State<FlashBookingScreen> createState() => _FlashBookingScreenState();
}

class _FlashBookingScreenState extends State<FlashBookingScreen> {
  int _currentStep = 0; // 0: Schedule, 1: Details, 2: Payment, 3: Confirmed

  // Step 1 State: Date & Time
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  String _selectedTimeSlot = '1:30 PM';
  late String _selectedPlacement;
  bool _isSilentSession = false;

  // Step 2 State: Details & Policies
  final _nameController = TextEditingController(text: 'Alex Rivers');
  final _phoneController = TextEditingController(text: '(555) 234-5678');
  final _emailController = TextEditingController(text: 'alex.rivers@example.com');
  final _notesController = TextEditingController();
  bool _agreedToPolicies = true;

  // Step 3 State: Payment
  String _selectedPaymentMethod = 'Apple Pay';
  bool _isProcessingPayment = false;

  // Step 4 State: Confirmation
  late final String _confirmationCode;

  final List<String> _placementOptions = [
    'Forearm',
    'Upper Arm',
    'Thigh',
    'Calf',
    'Shoulder / Back',
    'Ribs',
    'Other',
  ];

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  void initState() {
    super.initState();
    // Default to tomorrow or next valid upcoming date in current/next month
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = now.add(const Duration(days: 2));
    if (_selectedDate.month != _currentMonth.month) {
      _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    }

    _selectedPlacement = widget.flash.location.split('/').first.trim();
    if (!_placementOptions.contains(_selectedPlacement)) {
      _selectedPlacement = _placementOptions.first;
    }

    final codeNum = (10000 + (_selectedDate.millisecondsSinceEpoch % 89999)).toString();
    _confirmationCode = 'INK-$codeNum';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _artistName =>
      widget.artist?.name ?? widget.flash.artistName ?? 'Featured Artist';

  String get _artistLocation =>
      widget.artist?.location ?? widget.flash.location;

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final weekday = days[date.weekday % 7];
    return '$weekday, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _prevMonth() {
    final now = DateTime.now();
    final firstOfCurrent = DateTime(now.year, now.month, 1);
    final prev = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    if (prev.isBefore(firstOfCurrent)) return;
    setState(() {
      _currentMonth = prev;
    });
  }

  void _processPaymentAndConfirm() async {
    setState(() {
      _isProcessingPayment = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    setState(() {
      _isProcessingPayment = false;
    });

    final bookingThread = MessageThread.mockThreads.firstWhere(
      (t) => t.id == 'thread_new_booking',
      orElse: () => MessageThread.mockThreads.first,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatConversationScreen(thread: bookingThread),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep < 3,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep == 3) {
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121414),
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              // Top Progress Indicator
              _buildProgressStepper(),

              // Step Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.spaceLg,
                    vertical: AppSpacing.spaceMd,
                  ),
                  child: _buildCurrentStepContent(),
                ),
              ),

              // Bottom Action Bar
              if (_currentStep < 3) _buildBottomActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF121414),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          _currentStep == 3 ? Icons.close : Icons.arrow_back,
          color: const Color(0xFFF9FAFA),
        ),
        onPressed: () {
          if (_currentStep == 3) {
            Navigator.of(context).pop(true);
          } else if (_currentStep > 0) {
            setState(() {
              _currentStep--;
            });
          } else {
            Navigator.of(context).pop(false);
          }
        },
      ),
      title: Text(
        _currentStep == 3 ? 'Booking Confirmed' : 'Claim & Book Flash',
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFFF9FAFA),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProgressStepper() {
    final steps = ['Date & Time', 'Details', 'Payment', 'Confirmed'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF171A1A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF262929), width: 1),
        ),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isPast = index < _currentStep;
          final isCurrent = index == _currentStep;
          final isLast = index == steps.length - 1;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: isPast || isCurrent
                              ? const Color(0xFFEEC200)
                              : const Color(0xFF2E3333),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: isCurrent
                              ? const Color(0xFFEEC200)
                              : (isPast ? const Color(0xFFF9FAFA) : const Color(0xFF6B7272)),
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepSchedule();
      case 1:
        return _buildStepDetails();
      case 2:
        return _buildStepPayment();
      case 3:
        return _buildStepConfirmation();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 1: SCHEDULE (Date, Time, Placement, Silent Toggle)
  // ---------------------------------------------------------------------------
  Widget _buildStepSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Artwork Recap Header
        _buildArtworkSummaryBanner(),
        const SizedBox(height: 20),

        // Section Title: Select Date
        Text(
          'SELECT DATE',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        // Calendar Card
        _buildCalendarCard(),
        const SizedBox(height: 24),

        // Section Title: Select Time Slot
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SELECT TIME SLOT',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF919696),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'Session Est. ${widget.flash.estimatedTime}',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEEC200),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Time Slot Chips
        _buildTimeSlotsGrid(),
        const SizedBox(height: 24),

        // Placement Selection
        Text(
          'BODY PLACEMENT',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        _buildPlacementDropdown(),
        const SizedBox(height: 20),

        // Silent Session Preference Switch
        _buildSilentSessionTile(),
      ],
    );
  }

  Widget _buildArtworkSummaryBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262929)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 58,
              height: 58,
              child: FlashImage(
                urlOrPath: widget.flash.imageUrl,
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
                  widget.flash.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'by $_artistName',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFEEC200),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Deposit: \$${widget.flash.deposit} • Full: \$${widget.flash.price}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    final totalCells = firstWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38352A), width: 1.2),
      ),
      child: Column(
        children: [
          // Month Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Color(0xFFF9FAFA)),
                onPressed: _prevMonth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF9FAFA),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Color(0xFFF9FAFA)),
                onPressed: _nextMonth,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Day of week headers
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
          const SizedBox(height: 10),

          // Calendar Grid
          Column(
            children: List.generate(rowCount, (rowIndex) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (colIndex) {
                    final cellIndex = rowIndex * 7 + colIndex;
                    final dayNum = cellIndex - firstWeekday + 1;

                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const SizedBox(width: 34, height: 34);
                    }

                    final cellDate = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
                    final isPast = cellDate.isBefore(today);
                    final isSelected = cellDate.year == _selectedDate.year &&
                        cellDate.month == _selectedDate.month &&
                        cellDate.day == _selectedDate.day;

                    return GestureDetector(
                      onTap: isPast
                          ? null
                          : () {
                              setState(() {
                                _selectedDate = cellDate;
                              });
                            },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFFEEC200)
                              : Colors.transparent,
                          border: isSelected
                              ? Border.all(color: const Color(0xFFEEC200), width: 1.5)
                              : (cellDate.day == today.day && cellDate.month == today.month
                                  ? Border.all(color: const Color(0xFF4D5252), width: 1)
                                  : null),
                        ),
                        child: Center(
                          child: Text(
                            '$dayNum',
                            style: GoogleFonts.plusJakartaSans(
                              color: isSelected
                                  ? const Color(0xFF121414)
                                  : (isPast
                                      ? const Color(0xFF424747)
                                      : const Color(0xFFF9FAFA)),
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

  Widget _buildTimeSlotsGrid() {
    final slots = BookingTimeSlot.defaultSlots;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isSelected = _selectedTimeSlot == slot.time;

        return ChoiceChip(
          label: Text(slot.time),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedTimeSlot = slot.time;
              });
            }
          },
          selectedColor: const Color(0xFFEEC200),
          backgroundColor: const Color(0xFF1E2020),
          labelStyle: GoogleFonts.plusJakartaSans(
            color: isSelected ? const Color(0xFF121414) : const Color(0xFFF9FAFA),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
          side: BorderSide(
            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF333737),
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlacementDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262929)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _placementOptions.contains(_selectedPlacement)
              ? _selectedPlacement
              : _placementOptions.first,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E2020),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFEEC200)),
          items: _placementOptions.map((placement) {
            return DropdownMenuItem<String>(
              value: placement,
              child: Text(
                placement,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF9FAFA),
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedPlacement = val;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildSilentSessionTile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF262929)),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_off_outlined, color: Color(0xFFEEC200), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Silent Appointment',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Minimal chatter during session. Perfect for resting or reading.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF919696),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isSilentSession,
            onChanged: (val) {
              setState(() {
                _isSilentSession = val;
              });
            },
            activeThumbColor: const Color(0xFFEEC200),
            activeTrackColor: const Color(0xFF4D4530),
            inactiveThumbColor: const Color(0xFF6B7272),
            inactiveTrackColor: const Color(0xFF202323),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: DETAILS & STUDIO POLICIES
  // ---------------------------------------------------------------------------
  Widget _buildStepDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLIENT INFORMATION',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),

        _buildInputField(
          controller: _nameController,
          label: 'Full Legal Name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),

        _buildInputField(
          controller: _phoneController,
          label: 'Phone Number (for SMS reminders)',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),

        _buildInputField(
          controller: _emailController,
          label: 'Email Address (for receipt & prep guide)',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),

        _buildInputField(
          controller: _notesController,
          label: 'Special Notes or Allergies (optional)',
          icon: Icons.note_outlined,
          maxLines: 2,
        ),
        const SizedBox(height: 24),

        Text(
          'STUDIO POLICIES & TERMS',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        _buildPoliciesCard(),
        const SizedBox(height: 16),

        // Policy Agreement Checkbox
        GestureDetector(
          onTap: () {
            setState(() {
              _agreedToPolicies = !_agreedToPolicies;
            });
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreedToPolicies,
                onChanged: (val) {
                  setState(() {
                    _agreedToPolicies = val ?? false;
                  });
                },
                activeColor: const Color(0xFFEEC200),
                checkColor: const Color(0xFF121414),
                side: const BorderSide(color: Color(0xFF4D5252), width: 1.5),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'I confirm I am 18+ years old and agree to the studio deposit and cancellation policies.',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF9FAFA),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(
        color: const Color(0xFFF9FAFA),
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF919696),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFEEC200), size: 20),
        filled: true,
        fillColor: const Color(0xFF171A1A),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF262929)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEC200), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildPoliciesCard() {
    final policies = [
      'Deposits are non-refundable and credited toward your session balance.',
      '48-hour advance notice is required to reschedule your appointment.',
      'A valid government-issued photo ID (18+) is required at the studio.',
      'Please arrive well-rested, hydrated, and within 10 minutes of start time.',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2B2F2F)),
      ),
      child: Column(
        children: policies.map((policy) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF4ADE80), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    policy,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFC0C5C5),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: REVIEW & PAYMENT
  // ---------------------------------------------------------------------------
  Widget _buildStepPayment() {
    final deposit = widget.flash.deposit;
    final total = widget.flash.price;
    final balance = total - deposit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Appointment Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF171A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38352A), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: FlashImage(
                        urlOrPath: widget.flash.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.flash.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFF9FAFA),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'by $_artistName',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEEC200),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF262929), height: 24),

              _buildSummaryRow('Date', _formatDate(_selectedDate)),
              const SizedBox(height: 6),
              _buildSummaryRow('Time', '$_selectedTimeSlot (${widget.flash.estimatedTime})'),
              const SizedBox(height: 6),
              _buildSummaryRow('Placement', _selectedPlacement),
              if (_isSilentSession) ...[
                const SizedBox(height: 6),
                _buildSummaryRow('Atmosphere', 'Silent Appointment requested'),
              ],
              const SizedBox(height: 6),
              _buildSummaryRow('Studio', _artistLocation),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Cost Breakdown Card
        Text(
          'PAYMENT BREAKDOWN',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2020),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2B2F2F)),
          ),
          child: Column(
            children: [
              _buildPriceLine('Total Flash Price', '\$$total', isBold: false),
              const SizedBox(height: 8),
              _buildPriceLine(
                'Deposit Due Today',
                '\$$deposit',
                isBold: true,
                color: const Color(0xFFEEC200),
              ),
              const Divider(color: Color(0xFF333737), height: 20),
              _buildPriceLine('Balance Due at Studio', '\$$balance', isBold: false),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Payment Method Selector
        Text(
          'SELECT PAYMENT METHOD',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        _buildPaymentMethodTile('Apple Pay', Icons.phone_iphone),
        const SizedBox(height: 8),
        _buildPaymentMethodTile('Credit Card (•••• 4242)', Icons.credit_card),
        const SizedBox(height: 8),
        _buildPaymentMethodTile('Cash App Pay', Icons.attach_money),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF9FAFA),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceLine(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: color ?? const Color(0xFFC0C5C5),
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: color ?? const Color(0xFFF9FAFA),
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(String method, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF171A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF262929),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF919696),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                method,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF9FAFA),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFEEC200), size: 18),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 4: CONFIRMATION & PREP GUIDE
  // ---------------------------------------------------------------------------
  Widget _buildStepConfirmation() {
    return Column(
      children: [
        const SizedBox(height: 10),
        // Golden Badge
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF38351F),
            border: Border.all(color: const Color(0xFFEEC200), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEEC200).withAlpha(40),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.check, color: Color(0xFFEEC200), size: 44),
          ),
        ),
        const SizedBox(height: 18),

        Text(
          'Flash Claimed & Booked!',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF9FAFA),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ref: $_confirmationCode',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFEEC200),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'A confirmation email and SMS receipt have been sent.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),

        // Appointment Recap Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF171A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262929)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: FlashImage(
                        urlOrPath: widget.flash.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.flash.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFF9FAFA),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Artist: $_artistName',
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
              const Divider(color: Color(0xFF262929), height: 20),
              _buildSummaryRow('Date', _formatDate(_selectedDate)),
              const SizedBox(height: 6),
              _buildSummaryRow('Time Slot', _selectedTimeSlot),
              const SizedBox(height: 6),
              _buildSummaryRow('Placement', _selectedPlacement),
              const SizedBox(height: 6),
              _buildSummaryRow('Studio Location', _artistLocation),
              const SizedBox(height: 6),
              _buildSummaryRow('Deposit Paid', '\$${widget.flash.deposit} ($_selectedPaymentMethod)'),
              const SizedBox(height: 6),
              _buildSummaryRow(
                'Balance at Appointment',
                '\$${widget.flash.price - widget.flash.deposit}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Add to calendar action button
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Appointment saved to your device calendar!'),
                backgroundColor: Color(0xFF262929),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.calendar_month, color: Color(0xFFEEC200), size: 18),
          label: Text(
            'ADD TO CALENDAR',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFEEC200),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFEEC200)),
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),

        // Session Preparation Guidelines
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D1D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2E2E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SESSION PREPARATION TIPS',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEEC200),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              _buildPrepItem('Hydrate thoroughly & eat a solid meal 1-2 hours before.'),
              _buildPrepItem('Bring valid 18+ government photo ID to the studio.'),
              _buildPrepItem('Avoid alcohol or blood thinners for 24 hours prior.'),
              _buildPrepItem('Wear loose, comfortable clothes for easy placement access.'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Done button
        AppButtons.primaryCTA(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          text: 'DONE',
          backgroundColor: const Color(0xFFEEC200),
          foregroundColor: const Color(0xFF121414),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPrepItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, color: Color(0xFFEEC200), size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFC0C5C5),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM ACTION BAR
  // ---------------------------------------------------------------------------
  Widget _buildBottomActionBar() {
    String buttonText;
    VoidCallback? onPressed;

    if (_currentStep == 0) {
      buttonText = 'CONTINUE TO DETAILS';
      onPressed = () {
        setState(() {
          _currentStep = 1;
        });
      };
    } else if (_currentStep == 1) {
      buttonText = 'CONTINUE TO PAYMENT';
      final isFormValid = _nameController.text.trim().isNotEmpty &&
          _phoneController.text.trim().isNotEmpty &&
          _emailController.text.trim().isNotEmpty &&
          _agreedToPolicies;

      onPressed = isFormValid
          ? () {
              setState(() {
                _currentStep = 2;
              });
            }
          : null;
    } else {
      buttonText = 'PAY \$${widget.flash.deposit} DEPOSIT & CONFIRM';
      onPressed = _isProcessingPayment ? null : _processPaymentAndConfirm;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spaceLg),
      decoration: const BoxDecoration(
        color: Color(0xFF171A1A),
        border: Border(
          top: BorderSide(color: Color(0xFF262929), width: 1),
        ),
      ),
      child: AppButtons.primaryCTA(
        onPressed: onPressed,
        text: buttonText,
        isLoading: _isProcessingPayment,
        backgroundColor: const Color(0xFFEEC200),
        foregroundColor: const Color(0xFF121414),
      ),
    );
  }
}

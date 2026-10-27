import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/artist.dart';
import '../models/artist_dashboard_data.dart';
import '../theme/app_spacing.dart';
import '../widgets/flash_snack_bar.dart';
import '../widgets/flash_switch.dart';
import '../widgets/guest_auth_prompt_bottom_sheet.dart';

class CustomRequestScreen extends StatefulWidget {
  final Artist artist;
  final String? initialDescription;
  final String? initialPlacement;

  const CustomRequestScreen({
    super.key,
    required this.artist,
    this.initialDescription,
    this.initialPlacement,
  });

  @override
  State<CustomRequestScreen> createState() => _CustomRequestScreenState();
}

class _CustomRequestScreenState extends State<CustomRequestScreen> {
  late final TextEditingController _conceptController;
  final _budgetController = TextEditingController();

  final List<String> _placementOptions = [
    'Forearm',
    'Upper Arm',
    'Thigh',
    'Calf',
    'Back',
    'Chest',
    'Ribs',
    'Other',
  ];
  late String _selectedPlacement;

  final List<String> _sizeOptions = [
    'Small (2"-4")',
    'Medium (4"-7")',
    'Large (8"-12")',
    'Sleeve / Backpiece',
  ];
  String _selectedSize = 'Medium (4"-7")';

  bool _requestSilentAppointment = false;
  int _referencePhotoCount = 1;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _conceptController = TextEditingController(text: widget.initialDescription ?? '');
    _selectedPlacement = (widget.initialPlacement != null && _placementOptions.contains(widget.initialPlacement))
        ? widget.initialPlacement!
        : 'Forearm';
  }

  @override
  void dispose() {
    _conceptController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _submitBrief() async {
    final authenticated = await GuestAuthPromptBottomSheet.ensureAuthenticated(
      context,
      actionType: AuthActionPromptType.customRequest,
    );
    if (!authenticated || !mounted) return;

    if (_conceptController.text.trim().isEmpty) {
      FlashSnackBar.showError(
        context,
        'Please describe your tattoo concept or idea.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Simulate brief submission
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final int estimatedPrice;
    final int requiredDeposit;
    switch (_selectedSize) {
      case 'Small (2"-4")':
        estimatedPrice = 220;
        requiredDeposit = 60;
        break;
      case 'Large (8"-12")':
        estimatedPrice = 550;
        requiredDeposit = 120;
        break;
      case 'Sleeve / Backpiece':
        estimatedPrice = 850;
        requiredDeposit = 200;
        break;
      default:
        estimatedPrice = 350;
        requiredDeposit = widget.artist.minDeposit > 0 ? widget.artist.minDeposit : 80;
    }

    final reqId = 'req_custom_${DateTime.now().millisecondsSinceEpoch}';
    final category = widget.artist.tags.isNotEmpty
        ? widget.artist.tags.first
        : 'Custom Design';
    final sketchImg = widget.artist.flashArtworks.isNotEmpty
        ? widget.artist.flashArtworks.first.imageUrl
        : 'assets/images/flash_traditional_panther.jpg';

    final newRequest = BookingRequest(
      id: reqId,
      clientName: 'Alex Rivers',
      timeAgo: 'Just now',
      conceptDescription: _conceptController.text.trim(),
      placement: _selectedPlacement,
      category: category,
      sketchImageUrl: sketchImg,
      estimatedPrice: estimatedPrice,
      deposit: requiredDeposit,
      size: _selectedSize,
      isSilentAppointment: _requestSilentAppointment,
      artistName: widget.artist.name,
    );
    ArtistDashboardRepository.addPendingRequest(newRequest);

    // Anti-Spam Deposit Gate:
    // Direct messaging threads are NOT created on initial custom request submission.
    // A chat thread is provisioned only after the artist approves the brief and the
    // booking deposit is confirmed (`deposit_confirmed`).

    Navigator.pop(context, newRequest);
    FlashSnackBar.showSuccess(
      context,
      'Custom brief sent to ${widget.artist.name}! You will receive a response within 48 hours.',
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121414),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Custom Tattoo Brief',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF9FAFA),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                    // Artist Context Header
                    _buildArtistHeader(),
                    const SizedBox(height: 24),

                    // Section: Concept
                    _buildSectionTitle('1. YOUR TATTOO CONCEPT', 'Describe what you want tattooed, elements, mood, or story'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _conceptController,
                      maxLines: 4,
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF9FAFA), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g., A serpent coiled around Japanese peonies with geometric line accents...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6B7272), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF1B1E1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2E3333)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2E3333)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEEC200), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section: Placement
                    _buildSectionTitle('2. PLACEMENT & LOCATION', 'Where on your body would you like this piece?'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _placementOptions.map((placement) {
                        final isSelected = _selectedPlacement == placement;
                        return ChoiceChip(
                          label: Text(placement),
                          selected: isSelected,
                          selectedColor: const Color(0xFF4D4530),
                          backgroundColor: const Color(0xFF1B1E1E),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF919696),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF2E3333),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedPlacement = placement;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Section: Size
                    _buildSectionTitle('3. ESTIMATED SIZE', 'Approximate size dimensions for pricing and timing'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sizeOptions.map((size) {
                        final isSelected = _selectedSize == size;
                        return ChoiceChip(
                          label: Text(size),
                          selected: isSelected,
                          selectedColor: const Color(0xFF4D4530),
                          backgroundColor: const Color(0xFF1B1E1E),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF919696),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF2E3333),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedSize = size;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Section: Reference Images
                    _buildSectionTitle('4. REFERENCE IMAGES', 'Upload inspiration or placement photos (up to 3)'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (int i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (i < _referencePhotoCount) {
                                    if (_referencePhotoCount > 1) {
                                      _referencePhotoCount--;
                                    }
                                  } else {
                                    _referencePhotoCount = i + 1;
                                  }
                                });
                              },
                              child: Container(
                                height: 90,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B1E1E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: i < _referencePhotoCount
                                        ? const Color(0xFFEEC200).withAlpha(160)
                                        : const Color(0xFF2E3333),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: i < _referencePhotoCount
                                    ? Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.image_outlined,
                                            color: const Color(0xFFEEC200).withAlpha(180),
                                            size: 32,
                                          ),
                                          Positioned(
                                            bottom: 6,
                                            child: Text(
                                              'Photo ${i + 1}',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: const Color(0xFFEEC200),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.add_photo_alternate_outlined,
                                              color: Color(0xFF6B7272),
                                              size: 24,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Add Image',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: const Color(0xFF6B7272),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section: Silent Appointment Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2E3333)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_off_outlined, color: Color(0xFFEEC200), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Silent Appointment',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFF9FAFA),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Minimal chatting, relaxed quiet session',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF919696),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FlashSwitch(
                            value: _requestSilentAppointment,
                            onChanged: (val) {
                              setState(() {
                                _requestSilentAppointment = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Submit Button (Inline, no gray bar)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitBrief,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEC200),
                          foregroundColor: const Color(0xFF121414),
                          disabledBackgroundColor: const Color(0xFF4D4530),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF121414),
                                ),
                              )
                            : Text(
                                'SUBMIT CUSTOM BRIEF',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildArtistHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E3333)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 44,
              height: 44,
              child: widget.artist.avatarUrl.startsWith('http')
                  ? Image.network(
                      widget.artist.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFF262929),
                        child: const Icon(Icons.person, color: Color(0xFFEEC200), size: 22),
                      ),
                    )
                  : Image.asset(
                      widget.artist.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFF262929),
                        child: const Icon(Icons.person, color: Color(0xFFEEC200), size: 22),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Requesting from ${widget.artist.name}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFF9FAFA),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.artist.location} • Min deposit \$${widget.artist.minDeposit}',
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

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFEEC200),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF919696),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

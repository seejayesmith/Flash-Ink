import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/artist.dart';
import '../theme/app_spacing.dart';

class CustomRequestScreen extends StatefulWidget {
  final Artist artist;

  const CustomRequestScreen({super.key, required this.artist});

  @override
  State<CustomRequestScreen> createState() => _CustomRequestScreenState();
}

class _CustomRequestScreenState extends State<CustomRequestScreen> {
  final _conceptController = TextEditingController();
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
  String _selectedPlacement = 'Forearm';

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
  void dispose() {
    _conceptController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _submitBrief() async {
    if (_conceptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your tattoo concept or idea.'),
          backgroundColor: Color(0xFF7A3535),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Simulate brief submission
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E2020),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFEEC200), width: 1),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFFEEC200), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Custom brief sent to ${widget.artist.name}! You will receive a response within 48 hours.',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF9FAFA),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
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
        child: Column(
          children: [
            Expanded(
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
                          Switch(
                            value: _requestSilentAppointment,
                            activeColor: const Color(0xFFEEC200),
                            activeTrackColor: const Color(0xFF4D4530),
                            inactiveThumbColor: const Color(0xFF919696),
                            inactiveTrackColor: const Color(0xFF2E3333),
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
                  ],
                ),
              ),
            ),

            // Submit Button
            Container(
              padding: const EdgeInsets.all(AppSpacing.spaceLg),
              decoration: const BoxDecoration(
                color: Color(0xFF151717),
                border: Border(
                  top: BorderSide(color: Color(0xFF262929), width: 1),
                ),
              ),
              child: SizedBox(
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
            ),
          ],
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
          CircleAvatar(
            radius: 22,
            backgroundImage: NetworkImage(widget.artist.avatarUrl),
            backgroundColor: const Color(0xFF262929),
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

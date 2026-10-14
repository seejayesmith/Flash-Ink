import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist_dashboard_data.dart';
import '../../models/waitlist_entry.dart';
import '../../widgets/flash_image.dart';

/// Bottom sheet dialog for artists to add friends, family, or VIP clients to their waitlist.
/// Supports both searching registered Flash users and manual entry for friends not yet on Flash.
class AddWaitlistEntrySheet extends StatefulWidget {
  final WaitlistEntry? initialEntry; // If editing an existing entry
  final VoidCallback? onSaved;

  const AddWaitlistEntrySheet({
    super.key,
    this.initialEntry,
    this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    WaitlistEntry? initialEntry,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddWaitlistEntrySheet(
        initialEntry: initialEntry,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AddWaitlistEntrySheet> createState() => _AddWaitlistEntrySheetState();
}

class _AddWaitlistEntrySheetState extends State<AddWaitlistEntrySheet> {
  int _activeTabIndex = 0; // 0: Search Flash Users, 1: Manual Contact

  // Form Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _conceptController;
  late final TextEditingController _placementController;
  late final TextEditingController _budgetController;
  late final TextEditingController _notesController;
  late final TextEditingController _searchController;

  String? _selectedFlashUserId;
  String? _selectedAvatarUrl;
  String _relationshipTag = 'Friends & Family';
  String _designType = 'Custom';
  String _availability = 'Flexible';
  String? _referenceImageUrl;

  // Mock Flash users for quick search
  static const List<Map<String, String>> _mockFlashUsers = [
    {
      'id': 'user_chloe_b',
      'name': 'Chloe Bennett',
      'handle': '@chloeb_ink',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
      'email': 'chloe.bennett@example.com',
      'phone': '(503) 555-0192',
    },
    {
      'id': 'user_julian_a',
      'name': 'Julian Alvarez',
      'handle': '@julian_arts',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
      'email': 'julian.ink@example.com',
      'phone': '(503) 555-0841',
    },
    {
      'id': 'user_marcus_c',
      'name': 'Marcus Cole',
      'handle': '@marcus_tats',
      'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
      'email': 'marcus.cole@example.com',
      'phone': '(503) 555-9923',
    },
    {
      'id': 'user_elena_r',
      'name': 'Elena Rostova',
      'handle': '@elena_pnw',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      'email': 'elena.rostova@example.com',
      'phone': '(503) 555-4412',
    },
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.initialEntry;
    _nameController = TextEditingController(text: e?.clientName ?? '');
    _emailController = TextEditingController(text: e?.clientEmail ?? '');
    _phoneController = TextEditingController(text: e?.clientPhone ?? '');
    _conceptController = TextEditingController(text: e?.conceptDescription ?? '');
    _placementController = TextEditingController(text: e?.placement ?? 'Forearm');
    _budgetController = TextEditingController(text: e?.budget?.toString() ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _searchController = TextEditingController();

    if (e != null) {
      _selectedFlashUserId = e.flashUserId;
      _selectedAvatarUrl = e.avatarUrl;
      _relationshipTag = e.relationshipTag;
      _designType = e.designType;
      _availability = e.availabilityPreference;
      _referenceImageUrl = e.referenceImageUrl;
      _activeTabIndex = e.isRegisteredFlashUser ? 0 : 1;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _conceptController.dispose();
    _placementController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectFlashUser(Map<String, String> user) {
    setState(() {
      _selectedFlashUserId = user['id'];
      _selectedAvatarUrl = user['avatar'];
      _nameController.text = user['name'] ?? '';
      _emailController.text = user['email'] ?? '';
      _phoneController.text = user['phone'] ?? '';
    });
  }

  void _handleSubmit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name or select a Flash user.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final budget = int.tryParse(_budgetController.text.trim());
    final isEditing = widget.initialEntry != null;

    final entry = WaitlistEntry(
      id: widget.initialEntry?.id ?? 'wl_${DateTime.now().millisecondsSinceEpoch}',
      artistId: 'artist_odd_maree',
      clientName: name,
      clientEmail: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      clientPhone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      flashUserId: _selectedFlashUserId,
      avatarUrl: _selectedAvatarUrl,
      relationshipTag: _relationshipTag,
      designType: _designType,
      conceptDescription: _conceptController.text.trim().isEmpty
          ? 'Tattoo appointment inquiry'
          : _conceptController.text.trim(),
      placement: _placementController.text.trim().isEmpty ? 'Forearm' : _placementController.text.trim(),
      budget: budget,
      availabilityPreference: _availability,
      referenceImageUrl: _referenceImageUrl,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      status: widget.initialEntry?.status ?? WaitlistStatus.waiting,
      createdAt: widget.initialEntry?.createdAt ?? DateTime.now(),
      vipAccessCode: widget.initialEntry?.vipAccessCode ?? 'VIP-${name.toUpperCase().replaceAll(' ', '')}-99',
      vipBookingLink: widget.initialEntry?.vipBookingLink ??
          'https://flashink.app/vip/oddmaree?pass=VIP-${name.toUpperCase().replaceAll(' ', '')}-99',
    );

    if (isEditing) {
      ArtistDashboardRepository.updateWaitlistEntry(entry);
    } else {
      ArtistDashboardRepository.addWaitlistEntry(entry);
    }

    widget.onSaved?.call();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing ? 'Waitlist entry updated!' : '$name added to your VIP waitlist!',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF141616),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFFEEC200), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333838),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialEntry != null ? 'Edit Waitlist Entry' : 'Add to VIP Waitlist',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF8C9191)),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF222626), height: 1),

          // Body Form Scrollable
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(22, 16, 22, bottomInset + 30),
              physics: const BouncingScrollPhysics(),
              children: [
                // Mode Selector Tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2E3333)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildModeTab(
                          index: 0,
                          icon: Icons.search_rounded,
                          label: 'Flash Profiles',
                        ),
                      ),
                      Expanded(
                        child: _buildModeTab(
                          index: 1,
                          icon: Icons.person_add_alt_1_rounded,
                          label: 'Manual Contact',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Tab 0: Flash Profiles Search
                if (_activeTabIndex == 0) ...[
                  _buildFlashUserSearchSection(),
                  const SizedBox(height: 18),
                ] else ...[
                  // Tab 1: Manual Contact Input Fields
                  _buildManualContactFields(),
                  const SizedBox(height: 18),
                ],

                // Relationship Tag Row
                _buildSectionLabel('RELATIONSHIP & PRIORITY TAG'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTagChip('Friends & Family'),
                    _buildTagChip('VIP Regular'),
                    _buildTagChip('Direct Inquiry'),
                    _buildTagChip('Referral'),
                  ],
                ),

                const SizedBox(height: 20),

                // Design Type (Flash vs Custom)
                _buildSectionLabel('DESIGN TYPE'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildTypePill('Custom', Icons.brush_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTypePill('Flash', Icons.flash_on_rounded)),
                  ],
                ),

                const SizedBox(height: 20),

                // Concept & Placement
                _buildSectionLabel('TATTOO CONCEPT / IDEA'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _conceptController,
                  hint: 'e.g. Micro realism lavender sprig & moon with sister',
                  maxLines: 3,
                ),

                const SizedBox(height: 16),

                // Placement & Budget Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('PLACEMENT'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _placementController,
                            hint: 'e.g. Forearm, Ankle',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('ESTIMATED BUDGET (\$)'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _budgetController,
                            hint: 'e.g. 300',
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Availability Preference
                _buildSectionLabel('AVAILABILITY PREFERENCE'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildAvailabilityChip('Flexible'),
                    _buildAvailabilityChip('Weekends Only'),
                    _buildAvailabilityChip('Weekday Evenings'),
                    _buildAvailabilityChip('Next Month'),
                  ],
                ),

                const SizedBox(height: 20),

                // Reference Image Selection
                _buildSectionLabel('REFERENCE IMAGE (OPTIONAL)'),
                const SizedBox(height: 8),
                _buildReferenceImageRow(),

                const SizedBox(height: 20),

                // Artist Private Notes
                _buildSectionLabel('PRIVATE NOTES (FOR ARTIST ONLY)'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _notesController,
                  hint: 'e.g. Mentioned wanting to book in November for birthday.',
                  maxLines: 2,
                ),

                const SizedBox(height: 28),

                // Save Action Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEC200),
                      foregroundColor: const Color(0xFF121414),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.initialEntry != null ? 'Save Changes' : 'Add to VIP Waitlist',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({required int index, required IconData icon, required String label}) {
    final isSelected = _activeTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeTabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEC200) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF121414) : const Color(0xFF8C9191),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? const Color(0xFF121414) : const Color(0xFF8C9191),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashUserSearchSection() {
    final query = _searchController.text.toLowerCase().trim();
    final filtered = _mockFlashUsers.where((u) {
      if (query.isEmpty) return true;
      return u['name']!.toLowerCase().contains(query) ||
          u['handle']!.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('SEARCH FLASH PROFILES'),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() {}),
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search by client name or @handle...',
            hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6B7272), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFEEC200), size: 20),
            filled: true,
            fillColor: const Color(0xFF1B1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2C3232)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEEC200), width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final user = filtered[i];
              final isSelected = _selectedFlashUserId == user['id'];
              return InkWell(
                onTap: () => _selectFlashUser(user),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEEC200).withAlpha(30) : const Color(0xFF1B1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF282D2D),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF282D2D),
                        child: ClipOval(
                          child: FlashImage(
                            urlOrPath: user['avatar']!,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name']!,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              user['handle']!,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF8C9191),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFFEEC200), size: 18),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildManualContactFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('FRIEND / CONTACT NAME *'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _nameController,
          hint: 'e.g. Aunt Michelle, Sarah Jenkins',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('PHONE NUMBER'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _phoneController,
                    hint: '(555) 000-0000',
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('EMAIL (OPTIONAL)'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _emailController,
                    hint: 'friend@email.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF8C9191),
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF6B7272), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1B1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C3232)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C3232)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEC200), width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildTagChip(String label) {
    final isSelected = _relationshipTag == label;
    return InkWell(
      onTap: () => setState(() => _relationshipTag = label),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEC200).withAlpha(40) : const Color(0xFF1B1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF2E3333),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFFC7CDCD),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityChip(String label) {
    final isSelected = _availability == label;
    return InkWell(
      onTap: () => setState(() => _availability = label),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8).withAlpha(35) : const Color(0xFF1B1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF2E3333),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFC7CDCD),
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTypePill(String type, IconData icon) {
    final isSelected = _designType == type;
    return InkWell(
      onTap: () => setState(() => _designType = type),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF1B1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF2E3333),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? const Color(0xFF121414) : const Color(0xFF8C9191),
            ),
            const SizedBox(width: 8),
            Text(
              type,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? const Color(0xFF121414) : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceImageRow() {
    const sampleImages = [
      'assets/images/flash_fineline_flora.jpg',
      'assets/images/flash_traditional_dagger.jpg',
      'assets/images/flash_japanese_koi.jpg',
      'assets/images/flash_tiger_tattoo.jpg',
    ];

    return Row(
      children: [
        ...sampleImages.map((img) {
          final isSelected = _referenceImageUrl == img;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () {
                setState(() {
                  _referenceImageUrl = isSelected ? null : img;
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFEEC200) : const Color(0xFF2E3333),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FlashImage(urlOrPath: img, fit: BoxFit.cover),
                      if (isSelected)
                        Container(
                          color: const Color(0xFFEEC200).withAlpha(80),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

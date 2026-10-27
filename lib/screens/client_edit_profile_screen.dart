import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_glass_container.dart';
import '../widgets/flash_glass_app_bar.dart';
import '../widgets/pinned_bottom_action_scaffold.dart';
import '../widgets/username_input_formatter.dart';

class ClientEditProfileScreen extends StatefulWidget {
  final String? initialDisplayName;
  final String initialUsername;
  final Future<void> Function(String username)? onSave;

  const ClientEditProfileScreen({
    super.key,
    this.initialDisplayName,
    required this.initialUsername,
    this.onSave,
  });

  @override
  State<ClientEditProfileScreen> createState() => _ClientEditProfileScreenState();
}

class _ClientEditProfileScreenState extends State<ClientEditProfileScreen> {
  late final TextEditingController _usernameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.initialUsername.replaceFirst(RegExp(r'^@'), ''),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newUsername = _usernameController.text.trim().replaceAll('@', '');

    if (newUsername.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      if (widget.onSave != null) {
        await widget.onSave!(newUsername);
      }
      if (mounted) {
        Navigator.pop(context, {
          'username': newUsername,
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PinnedBottomActionScaffold(
      backgroundColor: const Color(0xFF121414),
      extendBodyBehindAppBar: true,
      inlineCTA: true,
      appBar: FlashGlassAppBar(
        title: Text(
          'Edit Profile',
          key: const Key('edit_profile_sheet_title'),
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      ctaKey: const Key('account_save_profile_button'),
      ctaText: 'Save Changes',
      onCtaPressed: _handleSave,
      isCtaLoading: _isSaving,
      child: AdaptiveGlassContainer(
        useGradient: false,
        borderRadius: 20.0,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Username (@handle)',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF919696),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('account_edit_username_input'),
              controller: _usernameController,
              inputFormatters: const [StripLeadingAtFormatter()],
              style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                prefixText: '@',
                prefixStyle: GoogleFonts.plusJakartaSans(color: AppTheme.gold),
                filled: true,
                fillColor: const Color(0xFF141616),
                hintText: 'yourhandle',
                hintStyle: const TextStyle(color: Color(0xFF4D5252)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.gold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

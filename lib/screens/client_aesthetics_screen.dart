import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/app_spacing.dart';
import '../widgets/adaptive_glass_container.dart';

class ClientAestheticsScreen extends StatefulWidget {
  final List<String> initialAesthetics;
  final Future<void> Function(List<String> aesthetics)? onSave;

  const ClientAestheticsScreen({
    super.key,
    required this.initialAesthetics,
    this.onSave,
  });

  @override
  State<ClientAestheticsScreen> createState() => _ClientAestheticsScreenState();
}

class _ClientAestheticsScreenState extends State<ClientAestheticsScreen> {
  late final List<String> _selectedAesthetics;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _availableStyles = const [
    {'id': 'traditional', 'label': 'Traditional', 'icon': Icons.anchor},
    {'id': 'fineline', 'label': 'Fine Line', 'icon': Icons.gesture},
    {'id': 'japanese', 'label': 'Japanese', 'icon': Icons.water},
    {'id': 'blackwork', 'label': 'Blackwork', 'icon': Icons.contrast},
    {'id': 'watercolor', 'label': 'Watercolor', 'icon': Icons.palette_outlined},
    {'id': 'realism', 'label': 'Realism', 'icon': Icons.visibility_outlined},
    {'id': 'neotraditional', 'label': 'Neo-Traditional', 'icon': Icons.auto_awesome_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _selectedAesthetics = List<String>.from(widget.initialAesthetics);
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      if (widget.onSave != null) {
        await widget.onSave!(_selectedAesthetics);
      }
      if (mounted) {
        Navigator.pop(context, _selectedAesthetics);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Aesthetic Preferences',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdaptiveGlassContainer(
                useGradient: false,
                borderRadius: 20.0,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Your Aesthetics',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tailors your flash recommendations and artist matching.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF919696),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _availableStyles.map((style) {
                        final id = style['id'] as String;
                        final isSelected = _selectedAesthetics.contains(id);
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                style['icon'] as IconData,
                                size: 16,
                                color: isSelected ? AppTheme.onyxBackground : AppTheme.gold,
                              ),
                              const SizedBox(width: 8),
                              Text(style['label'] as String),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.gold,
                          backgroundColor: const Color(0xFF141616),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            color: isSelected ? AppTheme.onyxBackground : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          side: BorderSide(
                            color: isSelected ? AppTheme.gold : AppTheme.darkBorder,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAesthetics.add(id);
                              } else {
                                if (_selectedAesthetics.length > 1) {
                                  _selectedAesthetics.remove(id);
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('account_save_aesthetics_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.onyxBackground,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : Text(
                          'Save Aesthetics',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/adaptive_glass_container.dart';

/// Bottom sheet allowing clients to pick a preset body placement or type a custom one.
class PlacementSelectionBottomSheet extends StatefulWidget {
  final String initialPlacement;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const PlacementSelectionBottomSheet({
    super.key,
    required this.initialPlacement,
    required this.options,
    required this.onSelected,
  });

  @override
  State<PlacementSelectionBottomSheet> createState() =>
      _PlacementSelectionBottomSheetState();
}

class _PlacementSelectionBottomSheetState
    extends State<PlacementSelectionBottomSheet> {
  late String _currentSelection;
  late final TextEditingController _customController;
  bool _isCustomActive = false;

  @override
  void initState() {
    super.initState();
    _currentSelection = widget.initialPlacement;
    final isPreset = widget.options
        .where((opt) => opt != 'Other')
        .contains(widget.initialPlacement);

    if (!isPreset && widget.initialPlacement.isNotEmpty) {
      _isCustomActive = true;
      _customController = TextEditingController(
        text: widget.initialPlacement == 'Other' ? '' : widget.initialPlacement,
      );
    } else {
      _customController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _selectPreset(String option) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentSelection = option;
      _isCustomActive = false;
    });
    widget.onSelected(option);
    Navigator.of(context).pop();
  }

  void _activateCustom() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentSelection = 'Other';
      _isCustomActive = true;
    });
  }

  void _submitCustom() {
    final text = _customController.text.trim();
    final chosen = text.isNotEmpty ? text : 'Other';
    HapticFeedback.selectionClick();
    widget.onSelected(chosen);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveGlassContainer.bottomSheet(
      glassEnabled: true,
      androidSurfaceColor: AppTheme.cardBackground,
      topRadius: AppRadius.radiusSheet,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF4D5252),
                  borderRadius: BorderRadius.circular(AppRadius.dragHandle),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Body Placement',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  key: const Key('close_placement_sheet'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.navInactive,
                    size: 22,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose where you want this flash piece tattooed',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.navInactive,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.cardBorder, height: 1),
            ...widget.options.map((option) {
              final isOther = option == 'Other';
              final isSelected = isOther
                  ? (_isCustomActive ||
                      !widget.options
                          .where((o) => o != 'Other')
                          .contains(_currentSelection))
                  : (_currentSelection == option && !_isCustomActive);

              return Column(
                children: [
                  InkWell(
                    key: Key('placement_option_$option'),
                    onTap: () {
                      if (isOther) {
                        _activateCustom();
                      } else {
                        _selectPreset(option);
                      }
                    },
                    splashColor: AppTheme.gold.withAlpha(20),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: GoogleFonts.plusJakartaSans(
                                color: isSelected
                                    ? AppTheme.gold
                                    : AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_rounded,
                              color: AppTheme.gold,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (isOther && _isCustomActive) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('custom_placement_field'),
                              controller: _customController,
                              autofocus: true,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submitCustom(),
                              decoration: InputDecoration(
                                hintText: 'e.g. Behind ear, Ankle, Ribs',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF6B7280),
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: AppTheme.onyxBackground,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.radiusSm),
                                  borderSide: const BorderSide(
                                    color: AppTheme.cardBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.radiusSm),
                                  borderSide: const BorderSide(
                                    color: AppTheme.gold,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              key: const Key('confirm_custom_placement_btn'),
                              onPressed: _submitCustom,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.gold,
                                foregroundColor: AppTheme.onyxBackground,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.radiusSm),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              child: Text(
                                'Set',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(color: AppTheme.cardBorder, height: 1),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

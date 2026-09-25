import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';

/// Search input bar with horizontal scrolling filter chips for the Explore interface.
class ExploreSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;
  final List<String> filters;

  const ExploreSearchBar({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    required this.selectedFilter,
    required this.onFilterSelected,
    this.filters = const [
      'All',
      'Traditional',
      'Fine Line',
      'Blackwork',
      'Japanese',
      'Books Open',
      'Nearby',
    ],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: AppTheme.cardBorder, width: 1.2),
            ),
            child: TextField(
              controller: controller,
              onChanged: onQueryChanged,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search artists, studios, styles...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: AppTheme.navInactive,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(Icons.search, color: AppTheme.gold, size: 20),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.navInactive, size: 18),
                        onPressed: () {
                          controller.clear();
                          onQueryChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal scrolling filter chips
        SizedBox(
          height: 34,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = filters[index];
              final isSelected = filter == selectedFilter;

              return GestureDetector(
                onTap: () => onFilterSelected(filter),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.gold : AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: isSelected ? AppTheme.gold : AppTheme.cardBorder,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      filter,
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? AppTheme.onyxBackground : AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

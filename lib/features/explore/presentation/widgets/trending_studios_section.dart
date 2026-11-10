import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_spacing.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/models/explore_studio.dart';
import 'studio_card.dart';

/// Row 3+: Studios section displaying nearest tattoo shops or trending collectives.
class TrendingStudiosSection extends StatelessWidget {
  final String title;
  final List<ExploreStudio> studios;
  final ValueChanged<ExploreStudio>? onStudioTap;

  const TrendingStudiosSection({
    super.key,
    this.title = 'TRENDING SHOPS & STUDIOS',
    required this.studios,
    this.onStudioTap,
  });

  @override
  Widget build(BuildContext context) {
    if (studios.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.navInactive,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.9,
                ),
              ),
              Text(
                '${studios.length} Studios',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: studios.length,
            itemBuilder: (context, index) {
              final studio = studios[index];
              return StudioCard(
                studio: studio,
                onTap: onStudioTap != null ? () => onStudioTap!(studio) : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

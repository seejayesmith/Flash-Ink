import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/artist_dashboard/book_drop.dart';
import '../../models/artist_dashboard/booking_request.dart';
import '../../repositories/artist_dashboard_repository.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/flash_image.dart';
import '../../widgets/user_avatar.dart';
import 'booking_request_detail_screen.dart';

/// Dedicated screen displaying all pending custom tattoo piece requests awaiting
/// artist review, slot proposals, or approval.
class PendingCustomRequestsScreen extends StatefulWidget {
  const PendingCustomRequestsScreen({super.key});

  @override
  State<PendingCustomRequestsScreen> createState() =>
      _PendingCustomRequestsScreenState();
}

class _PendingCustomRequestsScreenState
    extends State<PendingCustomRequestsScreen> {
  @override
  void initState() {
    super.initState();
    ArtistDashboardRepository.pendingRequestsNotifier
        .addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    ArtistDashboardRepository.pendingRequestsNotifier
        .removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  CustomHold? _activeHoldForRequest(String requestId) {
    final now = DateTime.now();
    for (final hold in ArtistDashboardRepository.customHolds) {
      if (hold.requestId == requestId && !now.isAfter(hold.expiresAt)) {
        return hold;
      }
    }
    return null;
  }

  String _resolvePreviewImage(BookingRequest request) {
    if (request.sketchImageUrl.trim().isNotEmpty) {
      return request.sketchImageUrl.trim();
    }
    if (request.referenceImageUrls.isNotEmpty) {
      return request.referenceImageUrls.first.trim();
    }
    return '';
  }

  Future<void> _openRequestDetail(BookingRequest request) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingRequestDetailScreen(request: request),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = ArtistDashboardRepository.pendingRequests;

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
          key: const Key('pending_custom_requests_back_button'),
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF9FAFA)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pending Custom Requests',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFF9FAFA),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.screenGutter),
            child: Center(
              child: Container(
                key: const Key('pending_custom_requests_count_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2121),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2E3232)),
                ),
                child: Text(
                  '${requests.length}',
                  style: GoogleFonts.plusJakartaSans(
                    color: requests.isNotEmpty
                        ? const Color(0xFFEEC200)
                        : const Color(0xFF919696),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: requests.isEmpty
            ? _buildEmptyState()
            : ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  12,
                  AppSpacing.screenGutter,
                  28,
                ),
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) =>
                    _buildRequestCard(requests[index]),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const Key('pending_custom_requests_empty_state'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2121),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2E3232)),
              ),
              child: const Icon(
                Icons.brush_outlined,
                color: Color(0xFF919696),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No pending custom requests',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New custom piece briefs submitted by clients will appear here for your review.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.navInactiveAlt,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(BookingRequest request) {
    final activeHold = _activeHoldForRequest(request.id);
    final previewImage = _resolvePreviewImage(request);

    return Container(
      key: Key('pending_custom_request_card_${request.id}'),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2121),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF282C2C), width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('open_custom_request_${request.id}'),
          onTap: () => _openRequestDetail(request),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCardHeader(request, activeHold),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.conceptDescription.isNotEmpty
                                    ? request.conceptDescription
                                    : 'Custom tattoo brief',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFD5D9D9),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildMetaChip(request.placement),
                                  _buildMetaChip(request.size),
                                  _buildMetaChip(request.category),
                                  if (request.isSilentAppointment)
                                    _buildMetaChip(
                                      'Silent Session',
                                      accent: const Color(0xFF38BDF8),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 68,
                            height: 68,
                            color: const Color(0xFF2A2E2E),
                            child: FlashImage(
                              urlOrPath: previewImage,
                              fit: BoxFit.cover,
                              errorWidget: const Icon(
                                Icons.brush,
                                color: Color(0xFF8C9191),
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF282C2C), height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Est. \$${request.estimatedPrice}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '  •  \$${request.deposit} deposit',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF919696),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View details',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFEEC200),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Color(0xFFEEC200),
                          size: 12,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(BookingRequest request, CustomHold? activeHold) {
    return Row(
      children: [
        UserAvatar(
          imageUrl: request.clientAvatar,
          displayName: request.clientName,
          radius: 18,
          fallbackInitial: 'C',
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.clientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                request.timeAgo,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8C9191),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (activeHold != null) ...[
          const SizedBox(width: 8),
          Container(
            key: Key('pending_custom_request_hold_badge_${request.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEC200).withAlpha(24),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFEEC200).withAlpha(110),
              ),
            ),
            child: Text(
              '24h Hold • ${activeHold.timeSlot}',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEEC200),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaChip(String label, {Color? accent}) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    final textColor = accent ?? const Color(0xFFB0B5B5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141616),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent != null ? accent.withAlpha(90) : const Color(0xFF282C2C),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

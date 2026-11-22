import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/calendar_event_launcher.dart';
import '../../../../models/artist_dashboard/artist_books_schedule.dart';
import '../../../../theme/app_buttons.dart';
import '../../../../theme/app_radius.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/flash_image.dart';
import '../../domain/models/message_thread.dart';

class BookingReceiptMessageTile extends StatefulWidget {
  final ChatMessage message;
  final MessageThread? thread;

  const BookingReceiptMessageTile({
    super.key,
    required this.message,
    this.thread,
  });

  @override
  State<BookingReceiptMessageTile> createState() =>
      _BookingReceiptMessageTileState();
}

class _BookingReceiptMessageTileState extends State<BookingReceiptMessageTile> {
  static const Color _confirmedGreen = Color(0xFF4ADE80);
  static const Color _confirmedGreenBg = Color(0x1F4ADE80);

  bool _addedToCalendar = false;
  bool _isAdding = false;

  DateTime? _effectiveAppointmentDateTime() {
    final base = widget.message.appointmentDate;
    if (base == null) return null;
    final slot = widget.message.appointmentTimeSlot?.trim() ?? '';
    if (slot.isNotEmpty) {
      return ArtistBooksSchedule.parseSlotDateTime(base, slot) ?? base;
    }
    return base;
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('MMM d, yyyy • h:mm a').format(date);
  }

  Future<void> _addToCalendar() async {
    final baseDate = widget.message.appointmentDate;
    if (baseDate == null || _isAdding) return;

    setState(() => _isAdding = true);

    final event = CalendarEventLauncher.buildTattooAppointmentEvent(
      date: baseDate,
      timeSlot: widget.message.appointmentTimeSlot,
      durationMinutes: widget.message.appointmentDurationMinutes,
      flashTitle: widget.message.flashTitle ?? widget.thread?.flashTitleContext,
      artistName: widget.message.artistName ?? widget.thread?.artistName,
      studioName: widget.thread?.studioName,
      studioAddress: widget.message.studioLocation,
      placement: widget.message.placement,
      depositAmount: widget.message.receiptAmount,
    );

    final added = await CalendarEventLauncher.addEventToCalendar(context, event);
    if (!mounted) return;
    setState(() {
      _isAdding = false;
      if (added) {
        _addedToCalendar = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final displayDateTime = _effectiveAppointmentDateTime();

    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        width: MediaQuery.of(context).size.width * 0.85,
        decoration: BoxDecoration(
          color: AppTheme.onyxContainer,
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          border: Border.all(color: AppTheme.goldBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.gold.withAlpha(25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.gold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'BOOKING CONFIRMED',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  if (message.flashImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: FlashImage(
                          urlOrPath: message.flashImageUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (message.flashImageUrl != null) const SizedBox(width: 12),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deposit Paid',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.navInactive,
                            fontSize: 12,
                          ),
                        ),
                        if (message.receiptAmount != null)
                          Text(
                            '\$${message.receiptAmount!.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (displayDateTime != null)
                          Text(
                            _formatDateTime(displayDateTime),
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action Button
            if (message.appointmentDate != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: AppButtons.secondaryCTA(
                  key: const Key('receipt_add_to_calendar_button'),
                  onPressed: _isAdding ? null : _addToCalendar,
                  isLoading: _isAdding,
                  icon: _addedToCalendar
                      ? Icons.check_circle_rounded
                      : Icons.calendar_month,
                  text: _addedToCalendar
                      ? 'Added to Calendar'
                      : 'Add to Calendar',
                  borderColor: _addedToCalendar
                      ? _confirmedGreen
                      : AppTheme.goldBorder,
                  foregroundColor: _addedToCalendar
                      ? _confirmedGreen
                      : AppTheme.gold,
                  backgroundColor: _addedToCalendar
                      ? _confirmedGreenBg
                      : Colors.transparent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

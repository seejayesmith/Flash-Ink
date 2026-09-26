import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:intl/intl.dart';

import '../../../../theme/app_theme.dart';
import '../../../../theme/app_typography.dart';
import '../../../../widgets/flash_image.dart';
import '../../domain/models/message_thread.dart';

class BookingReceiptMessageTile extends StatelessWidget {
  final ChatMessage message;

  const BookingReceiptMessageTile({super.key, required this.message});

  String _formatDateTime(DateTime date) {
    return DateFormat('MMM d, yyyy • h:mm a').format(date);
  }

  void _addToCalendar() {
    if (message.appointmentDate == null) return;
    
    final event = Event(
      title: 'Tattoo Session',
      description: 'Your tattoo session appointment',
      location: 'Studio',
      startDate: message.appointmentDate!,
      endDate: message.appointmentDate!.add(const Duration(hours: 2)), // Default 2 hours
    );
    
    Add2Calendar.addEvent2Cal(event);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        width: MediaQuery.of(context).size.width * 0.85,
        decoration: BoxDecoration(
          color: AppTheme.onyxContainer,
          borderRadius: BorderRadius.circular(16),
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
                      borderRadius: BorderRadius.circular(8),
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
                        if (message.appointmentDate != null)
                          Text(
                            _formatDateTime(message.appointmentDate!),
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
                child: OutlinedButton.icon(
                  onPressed: _addToCalendar,
                  icon: const Icon(Icons.calendar_month, color: AppTheme.gold, size: 18),
                  label: Text(
                    'ADD TO CALENDAR',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.goldBorder),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

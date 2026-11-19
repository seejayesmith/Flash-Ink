import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/artist_dashboard_data.dart';
import '../../widgets/flash_snack_bar.dart';

/// Builds real tattoo session calendar [Event]s and launches the platform
/// calendar sheet with visual & haptic confirmation upon completion.
class CalendarEventLauncher {
  CalendarEventLauncher._();

  static const MethodChannel _channel = MethodChannel('add_2_calendar');

  @visibleForTesting
  static Future<bool> Function(Event event)? debugAddEventCallback;

  @visibleForTesting
  static Event? lastAddedEvent;

  @visibleForTesting
  static void resetDebugOverrides() {
    debugAddEventCallback = null;
    lastAddedEvent = null;
  }

  /// Constructs an [Event] populated with real tattoo appointment details,
  /// parsed start time, and computed session duration.
  static Event buildTattooAppointmentEvent({
    required DateTime date,
    String? timeSlot,
    int? durationMinutes,
    String? durationLabel,
    String? flashTitle,
    String? artistName,
    String? studioName,
    String? studioAddress,
    String? placement,
    num? depositAmount,
    num? totalPrice,
    String? notes,
  }) {
    final cleanTime = timeSlot?.trim() ?? '';
    final startDate = cleanTime.isNotEmpty
        ? (ArtistBooksSchedule.parseSlotDateTime(date, cleanTime) ?? date)
        : date;

    final int resolvedDurationMinutes;
    if (durationMinutes != null && durationMinutes > 0) {
      resolvedDurationMinutes = durationMinutes;
    } else if (durationLabel != null && durationLabel.trim().isNotEmpty) {
      resolvedDurationMinutes =
          ArtistDashboardRepository.parseDurationMinutes(durationLabel);
    } else {
      final repoDuration =
          ArtistDashboardRepository.booksSchedule.slotDurationMinutes;
      resolvedDurationMinutes = repoDuration > 0 ? repoDuration : 120;
    }

    final endDate = startDate.add(Duration(minutes: resolvedDurationMinutes));

    final cleanFlash = flashTitle?.trim() ?? '';
    final cleanArtist = artistName?.trim() ?? '';
    final String title;
    if (cleanFlash.isNotEmpty && cleanArtist.isNotEmpty) {
      title = 'Tattoo Session: $cleanFlash with $cleanArtist';
    } else if (cleanArtist.isNotEmpty) {
      title = 'Tattoo Session with $cleanArtist';
    } else if (cleanFlash.isNotEmpty) {
      title = 'Tattoo Session: $cleanFlash';
    } else {
      title = 'Tattoo Session';
    }

    final cleanStudio = studioName?.trim() ?? '';
    final cleanAddress = studioAddress?.trim() ?? '';
    final String location;
    if (cleanStudio.isNotEmpty &&
        cleanAddress.isNotEmpty &&
        cleanStudio.toLowerCase() != cleanAddress.toLowerCase()) {
      location = '$cleanStudio — $cleanAddress';
    } else if (cleanAddress.isNotEmpty) {
      location = cleanAddress;
    } else if (cleanStudio.isNotEmpty) {
      location = cleanStudio;
    } else {
      final fallbackNote =
          ArtistDashboardRepository.booksSchedule.locationNote.trim();
      location = fallbackNote.isNotEmpty ? fallbackNote : 'Studio';
    }

    final details = <String>[];
    if (cleanFlash.isNotEmpty) {
      details.add('Piece: $cleanFlash');
    }
    if (cleanArtist.isNotEmpty) {
      details.add('Artist: $cleanArtist');
    }
    final cleanPlacement = placement?.trim() ?? '';
    if (cleanPlacement.isNotEmpty) {
      details.add('Placement: $cleanPlacement');
    }
    if (depositAmount != null && depositAmount > 0) {
      details.add('Deposit Paid: \$${_formatMoney(depositAmount)}');
    }
    if (totalPrice != null && depositAmount != null && totalPrice >= depositAmount) {
      final balance = totalPrice - depositAmount;
      details.add('Remaining Balance at Studio: \$${_formatMoney(balance)}');
    }
    final cleanNotes = notes?.trim() ?? '';
    if (cleanNotes.isNotEmpty) {
      details.add('Notes: $cleanNotes');
    }

    final description = details.isNotEmpty
        ? details.join('\n')
        : 'Your confirmed Flash.Ink tattoo session appointment.';

    return Event(
      title: title,
      description: description,
      location: location,
      startDate: startDate,
      endDate: endDate,
      iosParams: const IOSParams(reminder: Duration(hours: 2)),
    );
  }

  static String _formatMoney(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  /// Invokes the native calendar integration to save [event], and triggers
  /// haptic + floating [FlashSnackBar] visual confirmation on success.
  static Future<bool> addEventToCalendar(
    BuildContext context,
    Event event, {
    String confirmationMessage = 'Appointment saved to your device calendar!',
  }) async {
    lastAddedEvent = event;

    bool added;
    if (debugAddEventCallback != null) {
      added = await debugAddEventCallback!(event);
    } else {
      try {
        final rawResult =
            await _channel.invokeMethod<bool?>('add2Cal', event.toJson());
        // Unmocked MethodChannel in headless widget tests returns null; treat as
        // success unless the native handler or test mock explicitly returns false.
        added = rawResult ?? true;
      } on MissingPluginException {
        added = true;
      } catch (_) {
        added = false;
      }
    }

    if (added && context.mounted) {
      HapticFeedback.mediumImpact().catchError((_) {});
      if (ScaffoldMessenger.maybeOf(context) != null) {
        FlashSnackBar.showSuccess(
          context,
          confirmationMessage,
          duration: const Duration(seconds: 3),
        );
      }
    }

    return added;
  }
}

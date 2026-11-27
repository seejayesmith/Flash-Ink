import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../config/dev_config.dart';
import '../core/mock/mock_data_config.dart';
import '../features/appointments/domain/models/appointment_item.dart';
import '../features/messages/domain/models/message_thread.dart';
import '../models/artist_dashboard/artist_books_schedule.dart';
import '../models/artist_dashboard/dashboard_appointment.dart';
import '../repositories/artist_dashboard_repository.dart';
import 'booking_sync_service.dart';
import 'chat_service.dart';
import 'scheduling/touch_up_eligibility.dart';
import 'stripe_service.dart';

/// Outcome of booking a self-scheduled touch-up (either free $0 or paid via Stripe).
class TouchUpBookingResult {
  final bool success;
  final bool canceled;
  final bool isSlotConflict;
  final String? bookingId;
  final String? threadId;
  final ClientAppointment? appointment;
  final String? errorMessage;

  const TouchUpBookingResult({
    required this.success,
    this.canceled = false,
    this.isSlotConflict = false,
    this.bookingId,
    this.threadId,
    this.appointment,
    this.errorMessage,
  });
}

/// Service orchestrating client self-booked touch-ups:
/// - Free ($0) touch-ups confirm instantly via `bookFreeTouchUp` Cloud Function.
/// - Paid touch-ups run through `StripeService.presentDepositPaymentSheet` with
///   `parentAppointmentId` so the server validates eligibility & flat fee pricing.
/// - Optional healed-tattoo photo uploads go to `custom_requests/{uid}/...`
///   which is permitted by `storage.rules` for authenticated owners.
class TouchUpService {
  final FirebaseFunctions? _injectedFunctions;
  final StripeService? _injectedStripeService;
  final bool? isProductionOverride;

  TouchUpService({
    FirebaseFunctions? functions,
    StripeService? stripeService,
    this.isProductionOverride,
  })  : _injectedFunctions = functions,
        _injectedStripeService = stripeService;

  bool get _effectiveIsProduction => isProductionOverride ?? kIsProduction;

  bool get _allowSimulatedBooking =>
      MockDataConfig.isEnabled && !_effectiveIsProduction;

  FirebaseFunctions _resolveFunctions() =>
      _injectedFunctions ?? FirebaseFunctions.instance;

  StripeService _resolveStripeService() =>
      _injectedStripeService ?? StripeService();

  /// Uploads an optional healed tattoo photo for [clientUid], returning its URL
  /// (or empty string in sandbox/offline mode if upload is skipped).
  Future<String> uploadOptionalHealedPhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (_allowSimulatedBooking) {
      return '';
    }
    final uid = BookingSyncService.resolveCurrentUid('');
    if (uid.isEmpty) return '';
    return ChatService.uploadCustomRequestImage(
      userId: uid,
      bytes: bytes,
      fileName: 'touchup_$fileName',
    );
  }

  /// Books a touch-up slot for [originalAppointment].
  Future<TouchUpBookingResult> bookTouchUp({
    required ClientAppointment originalAppointment,
    required ArtistBooksSchedule schedule,
    required DateTime selectedDate,
    required String selectedTimeSlot,
    String? clientNotes,
    Uint8List? healedPhotoBytes,
    String? healedPhotoFileName,
    String? threadId,
    String? customerEmail,
    String? customerName,
  }) async {
    final artistId = (originalAppointment.artistId ?? '').trim();
    final bookingId = 'TU-${DateTime.now().millisecondsSinceEpoch}';
    final dateKey = ArtistBooksSchedule.dateKey(selectedDate);
    final startMinutes =
        ScheduleSlotEntry.parseTimeLabelToMinutes(selectedTimeSlot);
    final durationMinutes = schedule.touchUpDurationMinutes.clamp(15, 720);
    final bufferMinutes = schedule.touchUpBufferMinutes.clamp(0, 240);
    final durationLabel =
        TouchUpEligibilityService.formatDurationLabel(durationMinutes);
    final feeDollars = schedule.touchUpFeeDollars.clamp(0, 10000);
    final trimmedNotes = clientNotes?.trim() ?? '';

    String healedPhotoUrl = '';
    if (healedPhotoBytes != null && healedPhotoBytes.isNotEmpty) {
      try {
        healedPhotoUrl = await uploadOptionalHealedPhoto(
          bytes: healedPhotoBytes,
          fileName: healedPhotoFileName ?? 'healed_tattoo.jpg',
        );
      } catch (_) {
        // Healed photo is strictly optional; continue booking even if upload fails.
      }
    }

    final clientUidForThread = BookingSyncService.resolveCurrentUid('');
    // Resolve canonical dm_<clientId>_<artistId> thread (or an existing thread with this artist).
    final resolvedThreadId = _resolveExistingThreadId(
      explicitThreadId: threadId,
      clientId: clientUidForThread,
      artistId: artistId,
      artistName: originalAppointment.artistName,
    );

    String confirmedBookingId = bookingId;
    String confirmedThreadId = resolvedThreadId ??
        MessageThread.resolveCanonicalThreadId(
          clientId: clientUidForThread,
          artistId: artistId,
          fallbackId: 'thread_booking_$bookingId',
        );

    if (feeDollars <= 0) {
      // FREE ($0) TOUCH-UP PATH — instant confirmation without Stripe.
      if (!_allowSimulatedBooking) {
        try {
          final callable = _resolveFunctions().httpsCallable('bookFreeTouchUp');
          final result = await callable.call<dynamic>({
            'artistId': artistId,
            'parentAppointmentId': originalAppointment.id,
            'selectedDate': dateKey,
            'selectedTimeSlot': selectedTimeSlot,
            'startMinutes': ?startMinutes,
            if (trimmedNotes.isNotEmpty) 'clientNotes': trimmedNotes,
            if (healedPhotoUrl.isNotEmpty) 'healedPhotoUrl': healedPhotoUrl,
            'threadId': ?resolvedThreadId,
            'bookingId': bookingId,
          });
          if (result.data is Map) {
            final map = Map<String, dynamic>.from(result.data as Map);
            confirmedBookingId =
                map['bookingId']?.toString() ?? confirmedBookingId;
            confirmedThreadId =
                map['threadId']?.toString() ?? confirmedThreadId;
          }
        } on FirebaseFunctionsException catch (e) {
          final detailsCode =
              e.details is Map ? (e.details as Map)['code']?.toString() : null;
          final isConflict = e.code == 'already-exists' &&
                  (detailsCode == 'TIME_SLOT_CONFLICT' ||
                      (e.message?.contains('TIME_SLOT_CONFLICT') ?? false)) ||
              detailsCode == 'TIME_SLOT_CONFLICT';
          return TouchUpBookingResult(
            success: false,
            isSlotConflict: isConflict,
            errorMessage: e.message?.trim().isNotEmpty == true
                ? e.message!.trim()
                : 'Unable to confirm touch-up. Please try again.',
          );
        } catch (_) {
          return const TouchUpBookingResult(
            success: false,
            errorMessage:
                'Could not reach the server to confirm your touch-up. Please check your connection.',
          );
        }
      }
    } else {
      // PAID TOUCH-UP PATH — Stripe PaymentSheet with server-verified flat fee.
      final paymentResult =
          await _resolveStripeService().presentDepositPaymentSheet(
        amountInDollars: feeDollars.toDouble(),
        flashTitle: 'Touch-up: ${originalAppointment.flashTitle}',
        parentAppointmentId: originalAppointment.id,
        healedPhotoUrl: healedPhotoUrl.isNotEmpty ? healedPhotoUrl : null,
        threadId: resolvedThreadId,
        customerEmail: customerEmail,
        customerName: customerName,
        artistId: artistId,
        bookingId: bookingId,
        selectedDate: dateKey,
        selectedTimeSlot: selectedTimeSlot,
        startMinutes: startMinutes,
        durationMinutes: durationMinutes,
        bufferMinutes: bufferMinutes,
        placement: originalAppointment.placement,
        clientNotes: trimmedNotes.isNotEmpty ? trimmedNotes : null,
      );

      if (paymentResult.isCanceled) {
        return const TouchUpBookingResult(
          success: false,
          canceled: true,
          errorMessage: 'Touch-up checkout canceled.',
        );
      }
      if (!paymentResult.isSuccess) {
        return TouchUpBookingResult(
          success: false,
          isSlotConflict: paymentResult.isSlotConflict,
          errorMessage: paymentResult.errorMessage ??
              'Unable to complete touch-up payment.',
        );
      }
    }

    // Update local repositories so Appointments, Artist Calendar, and Messages reflect immediately.
    final normalizedDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final touchUpTitle = 'Touch-up: ${originalAppointment.flashTitle}';

    final newClientAppointment = ClientAppointment(
      id: confirmedBookingId,
      artistId: artistId.isNotEmpty ? artistId : null,
      artistName: originalAppointment.artistName,
      artistAvatar: originalAppointment.artistAvatar,
      studioName: originalAppointment.studioName,
      studioAddress: schedule.locationNote.isNotEmpty
          ? schedule.locationNote
          : originalAppointment.studioAddress,
      flashTitle: touchUpTitle,
      flashImageUrl: healedPhotoUrl.isNotEmpty
          ? healedPhotoUrl
          : originalAppointment.flashImageUrl,
      dateTime: normalizedDate,
      timeSlot: '$selectedTimeSlot ($durationLabel)',
      placement: originalAppointment.placement,
      depositAmount: feeDollars,
      totalPrice: feeDollars,
      status: AppointmentStatus.confirmed,
      notes: trimmedNotes.isNotEmpty ? trimmedNotes : null,
      isTouchUp: true,
      parentAppointmentId: originalAppointment.id,
      healedPhotoUrl: healedPhotoUrl.isNotEmpty ? healedPhotoUrl : null,
    );
    ClientAppointment.addUpcomingAppointment(newClientAppointment);

    final clientUid = BookingSyncService.resolveCurrentUid('client_user');
    final clientDisplayName =
        (customerName != null && customerName.trim().isNotEmpty)
            ? customerName.trim()
            : BookingSyncService.resolveCurrentUserDisplayNameSync('Client');

    final dashboardApt = DashboardAppointment(
      id: 'cal_$confirmedBookingId',
      clientId: clientUid,
      artistId: artistId.isNotEmpty ? artistId : null,
      clientName: clientDisplayName,
      serviceType: touchUpTitle,
      duration: durationLabel,
      time: selectedTimeSlot,
      date: dateKey,
      scheduledDate: normalizedDate,
      placement: originalAppointment.placement,
      notes: trimmedNotes,
      depositPaid: feeDollars,
      fullPrice: feeDollars,
      artworkImageUrl: originalAppointment.flashImageUrl,
      visitType: 'Touch-up',
      isTouchUp: true,
      parentAppointmentId: originalAppointment.id,
      parentTattooTitle: originalAppointment.flashTitle,
      healedPhotoUrl: healedPhotoUrl.isNotEmpty ? healedPhotoUrl : null,
      dotColor: const Color(0xFFEEC200),
    );
    ArtistDashboardRepository.addCalendarAppointment(dashboardApt);

    // Also append a receipt message into the active chat thread in local state.
    final appointmentStart = ArtistBooksSchedule.parseSlotDateTime(
          normalizedDate,
          selectedTimeSlot,
        ) ??
        normalizedDate;
    final receiptText = feeDollars <= 0
        ? 'Complimentary touch-up booked for "${originalAppointment.flashTitle}" on ${TouchUpEligibilityService.formatShortDate(normalizedDate)} at $selectedTimeSlot ($durationLabel).${trimmedNotes.isNotEmpty ? ' Note: $trimmedNotes' : ''}'
        : 'Touch-up booked for "${originalAppointment.flashTitle}" on ${TouchUpEligibilityService.formatShortDate(normalizedDate)} at $selectedTimeSlot ($durationLabel). \$$feeDollars fee paid.${trimmedNotes.isNotEmpty ? ' Note: $trimmedNotes' : ''}';

    final receiptMessage = ChatMessage(
      id: 'msg_touchup_$confirmedBookingId',
      senderId: clientUid,
      senderName: clientDisplayName,
      text: receiptText,
      timestamp: DateTime.now(),
      isFromArtist: false,
      type: ChatMessageType.receipt,
      receiptAmount: feeDollars.toDouble(),
      appointmentDate: appointmentStart,
      flashImageUrl: healedPhotoUrl.isNotEmpty
          ? healedPhotoUrl
          : originalAppointment.flashImageUrl,
    );

    final threads = MessageThread.activeThreads;
    final threadIdx = threads.indexWhere(
      (t) => t.id == confirmedThreadId || t.mergedLegacyIds.contains(confirmedThreadId),
    );
    if (threadIdx != -1) {
      final existing = threads[threadIdx];
      final alreadyHasMsg =
          existing.messages.any((m) => m.id == receiptMessage.id);
      if (!alreadyHasMsg) {
        threads[threadIdx] = existing.copyWith(
          lastMessage: receiptText,
          lastMessageTime: receiptMessage.timestamp,
          clientUnreadCount: 0,
          artistUnreadCount: existing.artistUnreadCount + 1,
          clientLastReadAt: DateTime.now(),
          messages: [...existing.messages, receiptMessage],
        );
        MessageThread.unreadUpdateNotifier.value++;
      }
    } else if (artistId.isNotEmpty) {
      BookingSyncService.postToCanonicalThread(
        artistId: artistId,
        clientId: clientUid,
        clientName: clientDisplayName,
        artistName: originalAppointment.artistName,
        artistAvatar: originalAppointment.artistAvatar,
        studioName: originalAppointment.studioName,
        flashTitleContext: originalAppointment.flashTitle,
        messages: [receiptMessage],
        initiatedByArtist: false,
        syncToCloud: false,
        fallbackThreadId: confirmedThreadId,
      );
    }

    return TouchUpBookingResult(
      success: true,
      bookingId: confirmedBookingId,
      threadId: confirmedThreadId,
      appointment: newClientAppointment,
    );
  }

  String? _resolveExistingThreadId({
    String? explicitThreadId,
    required String clientId,
    required String artistId,
    required String artistName,
  }) {
    if (MessageThread.hasCanonicalParticipants(
      clientId: clientId,
      artistId: artistId,
    )) {
      return MessageThread.canonicalThreadId(
        clientId: clientId,
        artistId: artistId,
      );
    }
    if (explicitThreadId != null && explicitThreadId.trim().isNotEmpty) {
      return explicitThreadId.trim();
    }
    final threads = MessageThread.activeThreads;
    for (final t in threads) {
      if (artistId.isNotEmpty && t.artistId.trim() == artistId) {
        return t.id;
      }
    }
    final lowerName = artistName.trim().toLowerCase();
    for (final t in threads) {
      if (lowerName.isNotEmpty &&
          t.artistName.trim().toLowerCase() == lowerName) {
        return t.id;
      }
    }
    return null;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/artist_dashboard/artist_books_schedule.dart';
import '../../models/waitlist_entry.dart';
import '../../repositories/artist_dashboard_repository.dart';

/// Handles Firestore synchronization and availability verification for artist
/// booking schedules, 24h held slots, and VIP waitlist entries.
class ScheduleCloudSync {
  const ScheduleCloudSync._();

  static Future<void> syncBooksScheduleToCloud(
    ArtistBooksSchedule schedule, {
    required String artistId,
    required List<Map<String, dynamic>> syncedPayloads,
    required bool enableCloudWrites,
    FirebaseFirestore? firestore,
  }) async {
    final cleanArtistId = artistId.trim();
    if (cleanArtistId.isEmpty) return;

    final scheduleMap = schedule.toMap();
    final payload = {
      ...scheduleMap,
      'artistId': cleanArtistId,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    syncedPayloads.add({'collection': 'artist_schedules', 'data': payload});

    if (!enableCloudWrites && firestore == null) return;
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      await db
          .collection('artist_schedules')
          .doc(cleanArtistId)
          .set(payload, SetOptions(merge: true));
      await db.collection('artists').doc(cleanArtistId).set({
        'isBooksOpen': schedule.isBooksOpen,
        'booksSchedule': scheduleMap,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
        '[BookingSyncService] Offline/local fallback for schedule $cleanArtistId: $e',
      );
    }
  }

  static Future<void> syncHeldSlotsToCloud(
    List<ScheduleSlotEntry> heldSlots, {
    required String artistId,
    required List<Map<String, dynamic>> syncedPayloads,
    required bool enableCloudWrites,
    FirebaseFirestore? firestore,
  }) async {
    final cleanArtistId = artistId.trim();
    if (cleanArtistId.isEmpty) return;

    final serialized = heldSlots.map((e) => e.toMap()).toList();
    final nowIso = DateTime.now().toIso8601String();
    final payload = {
      'artistId': cleanArtistId,
      'heldSlots': serialized,
      'updatedAt': nowIso,
    };

    syncedPayloads.add({'collection': 'artist_schedules', 'data': payload});

    if (!enableCloudWrites && firestore == null) return;
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      await db
          .collection('artist_schedules')
          .doc(cleanArtistId)
          .set(payload, SetOptions(merge: true));
      await db.collection('artists').doc(cleanArtistId).set({
        'booksSchedule': {'heldSlots': serialized},
        'updatedAt': nowIso,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
        '[BookingSyncService] Offline/local fallback for heldSlots $cleanArtistId: $e',
      );
    }
  }

  static Future<ArtistBooksSchedule?> fetchArtistScheduleFromCloud(
    String artistId, {
    FirebaseFirestore? firestore,
  }) async {
    final cleanArtistId = artistId.trim();
    if (cleanArtistId.isEmpty) return null;

    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return null;
      }
    }

    try {
      final schedDoc =
          await db.collection('artist_schedules').doc(cleanArtistId).get();
      if (schedDoc.exists && schedDoc.data() != null) {
        return ArtistBooksSchedule.fromMap(schedDoc.data()!);
      }
      final artistDoc = await db.collection('artists').doc(cleanArtistId).get();
      final artistData = artistDoc.data();
      if (artistData != null && artistData['booksSchedule'] is Map) {
        return ArtistBooksSchedule.fromMap(
          Map<String, dynamic>.from(artistData['booksSchedule'] as Map),
        );
      }
    } catch (e) {
      debugPrint(
        '[BookingSyncService] Failed to fetch artist schedule $cleanArtistId: $e',
      );
    }
    return null;
  }

  static Future<({bool available, ArtistBooksSchedule? schedule})>
      verifySlotAvailableInCloud({
    required String artistId,
    required DateTime date,
    required String timeSlot,
    FirebaseFirestore? firestore,
  }) async {
    final cleanArtistId = artistId.trim();
    if (cleanArtistId.isEmpty) {
      return (available: true, schedule: null);
    }

    FirebaseFirestore? db = firestore;
    if (db == null) {
      try {
        db = FirebaseFirestore.instance;
      } catch (_) {
        return (available: true, schedule: null);
      }
    }

    final fetched = await fetchArtistScheduleFromCloud(
      cleanArtistId,
      firestore: db,
    );

    final extraBooked = <ScheduleSlotEntry>[];
    const excludedStatuses = {
      'cancelled',
      'canceled',
      'declined',
      'passed',
    };

    void collectSlot(dynamic rawDate, dynamic rawTime, dynamic rawStatus) {
      final status = (rawStatus ?? 'confirmed').toString().trim().toLowerCase();
      if (excludedStatuses.contains(status)) return;
      DateTime? parsedDate;
      if (rawDate is Timestamp) {
        parsedDate = rawDate.toDate();
      } else if (rawDate is String) {
        parsedDate = DateTime.tryParse(rawDate);
      }
      if (parsedDate == null) return;
      final rawTimeStr = (rawTime ?? '').toString().split('(').first.trim();
      if (rawTimeStr.isEmpty) return;
      extraBooked.add(
        ScheduleSlotEntry(
          dateKey: ArtistBooksSchedule.dateKey(parsedDate),
          timeSlot: rawTimeStr,
        ),
      );
    }

    try {
      final aptSnap = await db
          .collection('appointments')
          .where('artistId', isEqualTo: cleanArtistId)
          .get();
      for (final doc in aptSnap.docs) {
        final data = doc.data();
        collectSlot(data['scheduledDate'], data['time'], data['status']);
      }
    } catch (_) {}

    try {
      final bookingSnap = await db
          .collection('bookings')
          .where('artistId', isEqualTo: cleanArtistId)
          .get();
      for (final doc in bookingSnap.docs) {
        final data = doc.data();
        collectSlot(
          data['selectedDate'],
          data['selectedTimeSlot'],
          data['status'],
        );
      }
    } catch (_) {}

    ArtistBooksSchedule effectiveSchedule =
        fetched ?? ArtistDashboardRepository.booksSchedule;
    if (extraBooked.isNotEmpty) {
      final merged = <String, ScheduleSlotEntry>{
        for (final e in effectiveSchedule.bookedSlots)
          '${e.dateKey}__${ArtistBooksSchedule.normalizeTimeLabel(e.timeSlot)}':
              e,
        for (final e in extraBooked)
          '${e.dateKey}__${ArtistBooksSchedule.normalizeTimeLabel(e.timeSlot)}':
              e,
      };
      effectiveSchedule = effectiveSchedule.copyWith(
        bookedSlots: merged.values.toList(),
      );
    }

    final isAvailable = ArtistDashboardRepository.isSlotBookable(
      date: date,
      timeSlot: timeSlot,
      schedule: effectiveSchedule,
      artistId: cleanArtistId,
    );
    return (
      available: isAvailable,
      schedule: fetched != null || extraBooked.isNotEmpty
          ? effectiveSchedule
          : null,
    );
  }

  static Future<void> syncWaitlistToCloud(
    List<WaitlistEntry> entries, {
    required String artistId,
    required List<Map<String, dynamic>> syncedPayloads,
    required bool enableCloudWrites,
  }) async {
    final cleanArtistId = artistId.trim();
    if (cleanArtistId.isEmpty) return;

    final serialized = entries.map((e) => e.toMap()).toList();
    final payload = {
      'artistId': cleanArtistId,
      'waitlistEntries': serialized,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    syncedPayloads.add({'collection': 'artist_schedules', 'data': payload});

    if (!enableCloudWrites) return;
    try {
      await FirebaseFirestore.instance
          .collection('artist_schedules')
          .doc(cleanArtistId)
          .set(payload, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('artists')
          .doc(cleanArtistId)
          .set({
        'waitlistEntries': serialized,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
        '[BookingSyncService] Offline/local fallback for waitlist $cleanArtistId: $e',
      );
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flash_ink/features/appointments/domain/models/appointment_item.dart';
import 'package:flash_ink/models/artist_dashboard_data.dart';
import 'package:flash_ink/services/auth_service.dart';
import 'package:flash_ink/services/booking_sync_service.dart';

class _UnverifiedFakeUser extends Fake implements User {
  @override
  String get uid => 'client_uid_001';
  @override
  bool get isAnonymous => false;
}

void main() {
  group('Zero-Trust RBAC & Privacy Guards', () {
    test('getVerifiedRole defaults to client when JWT custom claims lack artist role', () async {
      final fakeUser = _UnverifiedFakeUser();
      final authService = AuthService(auth: null, firestore: null);

      final role = await authService.getVerifiedRole(user: fakeUser, forceRefresh: true);
      expect(role, equals('client'));
    });

    test('Staged Location Disclosure locks exact studio address until 24h before confirmed appointment', () {
      final sessionTime = DateTime(2026, 10, 25, 14, 0);
      final confirmedApt = ClientAppointment(
        id: 'APT-SEC-1',
        artistName: 'OddMaree',
        artistAvatar: '',
        studioName: 'Obsidian Atelier',
        studioAddress: '742 S Santa Fe Ave, Suite 4B, Los Angeles, CA',
        flashTitle: 'Sacred Serpent',
        flashImageUrl: '',
        dateTime: sessionTime,
        timeSlot: '2:00 PM',
        placement: 'Forearm',
        depositAmount: 75,
        totalPrice: 280,
        status: AppointmentStatus.confirmed,
      );

      // 48 hours before appointment -> LOCKED
      final twoDaysBefore = sessionTime.subtract(const Duration(hours: 48));
      expect(confirmedApt.isExactLocationUnlocked(now: twoDaysBefore), isFalse);
      expect(
        confirmedApt.effectiveStudioAddress(now: twoDaysBefore),
        contains('Private Studio • Exact address unlocks 24h before session'),
      );

      // 12 hours before appointment -> UNLOCKED
      final twelveHoursBefore = sessionTime.subtract(const Duration(hours: 12));
      expect(confirmedApt.isExactLocationUnlocked(now: twelveHoursBefore), isTrue);
      expect(
        confirmedApt.effectiveStudioAddress(now: twelveHoursBefore),
        equals('742 S Santa Fe Ave, Suite 4B, Los Angeles, CA'),
      );

      // Pending deposit even 2 hours before appointment -> LOCKED
      final pendingApt = ClientAppointment(
        id: 'APT-SEC-2',
        artistName: 'OddMaree',
        artistAvatar: '',
        studioName: 'Obsidian Atelier',
        studioAddress: '742 S Santa Fe Ave, Suite 4B, Los Angeles, CA',
        flashTitle: 'Sacred Serpent',
        flashImageUrl: '',
        dateTime: sessionTime,
        timeSlot: '2:00 PM',
        placement: 'Forearm',
        depositAmount: 0,
        totalPrice: 280,
        status: AppointmentStatus.pending,
      );
      final twoHoursBefore = sessionTime.subtract(const Duration(hours: 2));
      expect(pendingApt.isExactLocationUnlocked(now: twoHoursBefore), isFalse);
    });

    test('invalidateSessionState clears DevMockUser and in-memory repositories on sign-out', () {
      AuthService.devMockUser = DevMockUser(uid: 'temp_artist', role: 'artist');
      BookingSyncService.claimedFlashPieceIds.add('flash_999');

      AuthService.invalidateSessionState();

      expect(AuthService.devMockUser, isNull);
      expect(BookingSyncService.claimedFlashPieceIds, isEmpty);
      expect(ArtistDashboardRepository.pendingRequests, isNotEmpty);
    });
  });
}

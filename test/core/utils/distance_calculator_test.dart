import 'package:flutter_test/flutter_test.dart';
import 'package:flash_ink/core/utils/distance_calculator.dart';
import 'package:flash_ink/models/artist.dart';

void main() {
  group('DistanceCalculator.stripAwaySuffix', () {
    test('strips trailing "away" from miles strings', () {
      expect(DistanceCalculator.stripAwaySuffix('1.4 mi away'), '1.4 mi');
      expect(DistanceCalculator.stripAwaySuffix('20.6 mi away'), '20.6 mi');
      expect(DistanceCalculator.stripAwaySuffix('< 0.1 mi away'), '< 0.1 mi');
    });

    test('strips trailing "away" from kilometers strings', () {
      expect(DistanceCalculator.stripAwaySuffix('2.5 km away'), '2.5 km');
      expect(DistanceCalculator.stripAwaySuffix('< 0.1 km away'), '< 0.1 km');
    });

    test('case-insensitively handles trailing "away"', () {
      expect(DistanceCalculator.stripAwaySuffix('1.4 mi AWAY'), '1.4 mi');
      expect(DistanceCalculator.stripAwaySuffix('1.4 mi Away'), '1.4 mi');
    });

    test('leaves strings without trailing "away" untouched', () {
      expect(DistanceCalculator.stripAwaySuffix('1.4 mi'), '1.4 mi');
      expect(DistanceCalculator.stripAwaySuffix('Location set'), 'Location set');
      expect(DistanceCalculator.stripAwaySuffix('Portland, OR'), 'Portland, OR');
      expect(DistanceCalculator.stripAwaySuffix(''), '');
      expect(DistanceCalculator.stripAwaySuffix('   '), '   ');
    });
  });

  Artist createTestArtist({
    String distance = '',
    String location = 'Portland, OR',
  }) {
    return Artist(
      id: 'test_artist',
      name: 'CJ Smith',
      avatarUrl: 'https://example.com/avatar.jpg',
      location: location,
      studioType: 'Street Shop',
      rating: 5.0,
      availablePieces: 4,
      minDeposit: 50,
      distance: distance,
    );
  }

  group('Artist.statsDistanceLabel', () {
    test('removes "away" when artist has a distance string with "away"', () {
      final artist = createTestArtist(distance: '1.4 mi away');
      expect(artist.statsDistanceLabel, '1.4 mi');
    });

    test('preserves distance string when it does not end with "away"', () {
      final artist = createTestArtist(distance: '1.4 mi');
      expect(artist.statsDistanceLabel, '1.4 mi');
    });

    test('falls back to location when distance is empty', () {
      final artist = createTestArtist(
        distance: '',
        location: 'Portland, OR',
      );
      expect(artist.statsDistanceLabel, 'Portland, OR');
    });

    test('falls back to "Location set" when distance and location are empty', () {
      final artist = createTestArtist(
        distance: '',
        location: '',
      );
      expect(artist.statsDistanceLabel, 'Location set');
    });
  });
}

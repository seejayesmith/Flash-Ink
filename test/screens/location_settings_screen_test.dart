import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flash_ink/core/utils/distance_calculator.dart';
import 'package:flash_ink/providers/app_providers.dart';
import 'package:flash_ink/screens/location_settings_screen.dart';
import 'package:flash_ink/services/location_service.dart';

class FakeLocationPlatformDelegate implements LocationPlatformDelegate {
  bool serviceEnabled;
  LocationPermission permission;
  int requestPermissionCount = 0;
  int openAppSettingsCount = 0;
  int openLocationSettingsCount = 0;
  int getCurrentLocationCount = 0;
  UserLocationResult? mockLocationResult;
  GeoPointCoords? mockPermittedCoordinates;

  FakeLocationPlatformDelegate({
    this.serviceEnabled = true,
    this.permission = LocationPermission.denied,
    this.mockLocationResult,
    this.mockPermittedCoordinates,
  });

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCount++;
    return permission;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCount++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCount++;
    return true;
  }

  @override
  Future<UserLocationResult?> getCurrentLocation() async {
    getCurrentLocationCount++;
    return mockLocationResult;
  }

  @override
  Future<GeoPointCoords?> tryGetPermittedCoordinates() async => mockPermittedCoordinates;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    LocationService.delegate = null;
  });

  Widget buildTestWidget({
    required FakeLocationPlatformDelegate delegate,
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        home: LocationSettingsScreen(
          locationDelegate: delegate,
        ),
      ),
    );
  }

  group('LocationSettingsScreen Tests', () {
    testWidgets('Renders app bar, title, back button, and privacy points', (tester) async {
      final fake = FakeLocationPlatformDelegate(
        permission: LocationPermission.whileInUse,
      );

      await tester.pumpWidget(buildTestWidget(delegate: fake));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('location_settings_title')), findsOneWidget);
      expect(find.text('Location Permissions'), findsOneWidget);
      expect(find.byKey(const Key('location_settings_back_button')), findsOneWidget);

      // Verify privacy sections
      expect(find.text('HOW WE PROTECT YOUR PRIVACY'), findsOneWidget);
      expect(find.text('On-Demand Access Only'), findsOneWidget);
      expect(find.text('Zero Background Tracking'), findsOneWidget);
      expect(find.text('Strict Privacy'), findsOneWidget);
    });

    testWidgets('Displays PERMISSION DENIED badge and request button when denied', (tester) async {
      final fake = FakeLocationPlatformDelegate(
        permission: LocationPermission.denied,
      );

      await tester.pumpWidget(buildTestWidget(delegate: fake));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('location_permission_badge')), findsOneWidget);
      expect(find.text('PERMISSION DENIED'), findsOneWidget);
      expect(find.byKey(const Key('request_location_permission_button')), findsOneWidget);
      expect(find.text('Allow Location Access'), findsOneWidget);

      // Tapping request permission button calls delegate
      fake.permission = LocationPermission.whileInUse;
      fake.mockLocationResult = const UserLocationResult(
        latitude: 45.5152,
        longitude: -122.6784,
        city: 'Portland',
        state: 'OR',
      );

      await tester.tap(find.byKey(const Key('request_location_permission_button')));
      await tester.pumpAndSettle();

      expect(fake.requestPermissionCount, 1);
      expect(find.text('ALLOWED WHILE IN USE'), findsOneWidget);
      expect(find.text('Portland, OR'), findsWidgets);
    });

    testWidgets('Displays PERMANENTLY DENIED badge and Open Device Settings button when deniedForever', (tester) async {
      final fake = FakeLocationPlatformDelegate(
        permission: LocationPermission.deniedForever,
      );

      await tester.pumpWidget(buildTestWidget(delegate: fake));
      await tester.pumpAndSettle();

      expect(find.text('PERMANENTLY DENIED'), findsOneWidget);
      expect(find.byKey(const Key('open_device_settings_button')), findsOneWidget);
      expect(find.text('Open Device Settings'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open_device_settings_button')));
      await tester.pumpAndSettle();

      expect(fake.openAppSettingsCount, 1);
    });

    testWidgets('Displays SERVICES DISABLED badge and Open Location Settings button when service is disabled', (tester) async {
      final fake = FakeLocationPlatformDelegate(
        serviceEnabled: false,
        permission: LocationPermission.whileInUse,
      );

      await tester.pumpWidget(buildTestWidget(delegate: fake));
      await tester.pumpAndSettle();

      expect(find.text('SERVICES DISABLED'), findsOneWidget);
      expect(find.byKey(const Key('open_location_settings_button')), findsOneWidget);
      expect(find.text('Open Location Settings'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open_location_settings_button')));
      await tester.pumpAndSettle();

      expect(fake.openLocationSettingsCount, 1);
    });

    testWidgets('Displays ALLOWED WHILE IN USE when permission granted and opens device settings from header button', (tester) async {
      final fake = FakeLocationPlatformDelegate(
        permission: LocationPermission.whileInUse,
      );

      await tester.pumpWidget(buildTestWidget(delegate: fake));
      await tester.pumpAndSettle();

      expect(find.text('ALLOWED WHILE IN USE'), findsOneWidget);
      expect(find.text('Granted: While using the app'), findsOneWidget);
      expect(find.byKey(const Key('open_device_settings_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('open_device_settings_button')));
      await tester.pumpAndSettle();

      expect(fake.openAppSettingsCount, 1);
    });

    testWidgets('Toggling use live GPS preference switch updates Riverpod state', (tester) async {
      final fake = FakeLocationPlatformDelegate(
        permission: LocationPermission.whileInUse,
      );

      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return LocationSettingsScreen(locationDelegate: fake);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedRef.read(useLiveLocationPreferenceProvider), isTrue);

      // Toggle switch off
      await tester.tap(find.byKey(const Key('use_precise_location_switch')));
      await tester.pumpAndSettle();

      expect(capturedRef.read(useLiveLocationPreferenceProvider), isFalse);

      // Toggle switch back on
      await tester.tap(find.byKey(const Key('use_precise_location_switch')));
      await tester.pumpAndSettle();

      expect(capturedRef.read(useLiveLocationPreferenceProvider), isTrue);
    });

    testWidgets('Tapping refresh location button fetches current location and displays result', (tester) async {
      final fake = FakeLocationPlatformDelegate(
        permission: LocationPermission.whileInUse,
        mockLocationResult: const UserLocationResult(
          latitude: 37.7749,
          longitude: -122.4194,
          city: 'San Francisco',
          state: 'CA',
        ),
      );

      await tester.pumpWidget(buildTestWidget(delegate: fake));
      await tester.pumpAndSettle();

      final refreshBtn = find.byKey(const Key('refresh_location_button'));
      expect(refreshBtn, findsOneWidget);

      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      expect(fake.getCurrentLocationCount, 1);
      expect(find.text('San Francisco, CA'), findsWidgets);
    });

    testWidgets('Back button pops the LocationSettingsScreen', (tester) async {
      final fake = FakeLocationPlatformDelegate(
        permission: LocationPermission.whileInUse,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  key: const Key('open_screen_btn'),
                  onPressed: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => LocationSettingsScreen(locationDelegate: fake),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_screen_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(LocationSettingsScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('location_settings_back_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LocationSettingsScreen), findsNothing);
    });
  });
}

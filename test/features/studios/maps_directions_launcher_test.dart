import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:flash_ink/core/utils/maps_directions_launcher.dart';
import 'package:flash_ink/features/appointments/domain/models/appointment_item.dart';
import 'package:flash_ink/features/appointments/presentation/widgets/appointment_detail_modal.dart';
import 'package:flash_ink/features/studios/studio_profile_screen.dart';
import 'package:flash_ink/providers/app_providers.dart';
import 'package:flash_ink/services/studio_map_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const reverieStudio = StudioMapMarkerData(
    id: 'studio_reverie',
    name: 'Reverie',
    address: '608 E 1st St, Newberg, OR 97132',
    cityState: 'Newberg, OR',
    position: LatLng(45.3001, -122.9731),
    isPrivateStudio: false,
  );

  const privateStudio = StudioMapMarkerData(
    id: 'studio_private',
    name: 'Hidden Sanctuary',
    address: '742 Evergreen Ter, Portland, OR 97205',
    cityState: 'Portland, OR',
    position: LatLng(45.5152, -122.6784),
    isPrivateStudio: true,
  );

  String? clipboardText;

  void setupMockClipboard() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        clipboardText = args?['text']?.toString();
      }
      return null;
    });
  }

  setUp(() {
    MapsDirectionsLauncher.resetDebugOverrides();
    setupMockClipboard();
  });

  tearDown(() {
    MapsDirectionsLauncher.resetDebugOverrides();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget buildStudioProfileTestApp({
    required StudioMapMarkerData studio,
    bool openedFromMap = false,
  }) {
    return ProviderScope(
      overrides: [
        artistsWithDistanceProvider.overrideWithValue(
          const AsyncValue.data([]),
        ),
      ],
      child: MaterialApp(
        home: StudioProfileScreen(
          studio: studio,
          openedFromMap: openedFromMap,
        ),
      ),
    );
  }

  group('MapsDirectionsLauncher & Directions Entry Points', () {
    testWidgets(
      '1 installed app: skips picker sheet and opens directions directly',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final launchedUris = <Uri>[];
        MapsDirectionsLauncher.debugPlatformOverride = TargetPlatform.iOS;
        MapsDirectionsLauncher.debugCanLaunchUrl = (uri) async {
          return uri.scheme == 'maps';
        };
        MapsDirectionsLauncher.debugLaunchUrl = (uri) async {
          launchedUris.add(uri);
          return true;
        };

        await tester.pumpWidget(
          buildStudioProfileTestApp(studio: reverieStudio, openedFromMap: true),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('studio_directions_button')));
        await tester.pumpAndSettle();

        expect(find.text('Open Directions'), findsNothing);
        expect(launchedUris, hasLength(1));
        expect(launchedUris.single.scheme, equals('maps'));
        expect(
          launchedUris.single.queryParameters['daddr'],
          equals('45.3001,-122.9731'),
        );
        expect(launchedUris.single.queryParameters['dirflg'], equals('d'));
      },
    );

    testWidgets(
      '1 installed app from Explore (openedFromMap: false): also opens external maps',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final launchedUris = <Uri>[];
        MapsDirectionsLauncher.debugPlatformOverride = TargetPlatform.android;
        MapsDirectionsLauncher.debugCanLaunchUrl = (uri) async {
          return uri.scheme == 'google.navigation';
        };
        MapsDirectionsLauncher.debugLaunchUrl = (uri) async {
          launchedUris.add(uri);
          return true;
        };

        await tester.pumpWidget(
          buildStudioProfileTestApp(
            studio: reverieStudio,
            openedFromMap: false,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('studio_directions_button')));
        await tester.pumpAndSettle();

        expect(launchedUris, hasLength(1));
        expect(launchedUris.single.scheme, equals('google.navigation'));
        expect(
          launchedUris.single.toString(),
          contains('45.3001%2C-122.9731'),
        );
      },
    );

    testWidgets(
      '2+ installed apps: shows picker sheet with installed apps and launches selected app',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final launchedUris = <Uri>[];
        MapsDirectionsLauncher.debugPlatformOverride = TargetPlatform.iOS;
        MapsDirectionsLauncher.debugCanLaunchUrl = (uri) async {
          return uri.scheme == 'maps' ||
              uri.scheme == 'comgooglemaps' ||
              uri.scheme == 'waze';
        };
        MapsDirectionsLauncher.debugLaunchUrl = (uri) async {
          launchedUris.add(uri);
          return true;
        };

        await tester.pumpWidget(
          buildStudioProfileTestApp(studio: reverieStudio),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('studio_directions_button')));
        await tester.pumpAndSettle();

        expect(find.text('Open Directions'), findsOneWidget);
        expect(find.byKey(const Key('maps_option_appleMaps')), findsOneWidget);
        expect(
          find.byKey(const Key('maps_option_googleMaps')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('maps_option_waze')), findsOneWidget);
        expect(
          find.byKey(const Key('maps_option_copy_address')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('maps_option_waze')));
        await tester.pumpAndSettle();

        expect(find.text('Open Directions'), findsNothing);
        expect(launchedUris, hasLength(1));
        expect(launchedUris.single.scheme, equals('waze'));
        expect(
          launchedUris.single.queryParameters['ll'],
          equals('45.3001,-122.9731'),
        );
        expect(
          launchedUris.single.queryParameters['navigate'],
          equals('yes'),
        );
      },
    );

    testWidgets(
      '2+ installed apps: tapping Copy Address copies destination and shows snackbar',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        MapsDirectionsLauncher.debugPlatformOverride = TargetPlatform.iOS;
        MapsDirectionsLauncher.debugCanLaunchUrl = (uri) async {
          return uri.scheme == 'maps' || uri.scheme == 'comgooglemaps';
        };
        MapsDirectionsLauncher.debugLaunchUrl = (_) async => true;

        await tester.pumpWidget(
          buildStudioProfileTestApp(studio: reverieStudio),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('studio_directions_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('maps_option_copy_address')));
        await tester.pumpAndSettle();

        expect(clipboardText, equals('608 E 1st St, Newberg, OR 97132'));
        expect(
          find.text('Studio address copied for directions!'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '0 installed apps: falls back to web Google Maps directions URL',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final launchedUris = <Uri>[];
        MapsDirectionsLauncher.debugPlatformOverride = TargetPlatform.iOS;
        MapsDirectionsLauncher.debugCanLaunchUrl = (_) async => false;
        MapsDirectionsLauncher.debugLaunchUrl = (uri) async {
          launchedUris.add(uri);
          return true;
        };

        await tester.pumpWidget(
          buildStudioProfileTestApp(studio: reverieStudio),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('studio_directions_button')));
        await tester.pumpAndSettle();

        expect(launchedUris, hasLength(1));
        expect(launchedUris.single.scheme, equals('https'));
        expect(launchedUris.single.host, equals('www.google.com'));
        expect(launchedUris.single.path, equals('/maps/dir/'));
        expect(
          launchedUris.single.queryParameters['destination'],
          equals('45.3001,-122.9731'),
        );
      },
    );

    testWidgets(
      'Private studio keeps privacy guard and does not launch maps',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final launchedUris = <Uri>[];
        MapsDirectionsLauncher.debugPlatformOverride = TargetPlatform.iOS;
        MapsDirectionsLauncher.debugCanLaunchUrl = (_) async => true;
        MapsDirectionsLauncher.debugLaunchUrl = (uri) async {
          launchedUris.add(uri);
          return true;
        };

        await tester.pumpWidget(
          buildStudioProfileTestApp(studio: privateStudio),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('studio_directions_button')));
        await tester.pumpAndSettle();

        expect(launchedUris, isEmpty);
        expect(
          find.text(
            'Exact private studio address is shared after booking confirmation.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AppointmentDetailModal opens directions when exact location is unlocked',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final launchedUris = <Uri>[];
        MapsDirectionsLauncher.debugPlatformOverride = TargetPlatform.iOS;
        MapsDirectionsLauncher.debugCanLaunchUrl = (uri) async {
          return uri.scheme == 'maps' || uri.scheme == 'comgooglemaps';
        };
        MapsDirectionsLauncher.debugLaunchUrl = (uri) async {
          launchedUris.add(uri);
          return true;
        };

        final unlockedAppointment = ClientAppointment(
          id: 'APT-1001',
          artistName: 'Oddmaree',
          artistAvatar: '',
          studioName: 'Reverie',
          studioAddress: '608 E 1st St, Newberg, OR 97132',
          flashTitle: 'Botanical Dagger',
          flashImageUrl: '',
          dateTime: DateTime.now().add(const Duration(hours: 4)),
          timeSlot: '2:00 PM',
          placement: 'Forearm',
          depositAmount: 50,
          totalPrice: 250,
          status: AppointmentStatus.confirmed,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      AppointmentDetailModal.show(context, unlockedAppointment),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Directions'));
        await tester.pumpAndSettle();

        expect(find.text('Open Directions'), findsOneWidget);
        await tester.tap(find.byKey(const Key('maps_option_googleMaps')));
        await tester.pumpAndSettle();

        expect(launchedUris, hasLength(1));
        expect(launchedUris.single.scheme, equals('comgooglemaps'));
        expect(
          launchedUris.single.queryParameters['daddr'],
          equals('608 E 1st St, Newberg, OR 97132'),
        );
      },
    );

    testWidgets(
      'AppointmentDetailModal shows 24h lock notice when location is locked',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final launchedUris = <Uri>[];
        MapsDirectionsLauncher.debugPlatformOverride = TargetPlatform.iOS;
        MapsDirectionsLauncher.debugCanLaunchUrl = (_) async => true;
        MapsDirectionsLauncher.debugLaunchUrl = (uri) async {
          launchedUris.add(uri);
          return true;
        };

        final lockedAppointment = ClientAppointment(
          id: 'APT-1002',
          artistName: 'Sora Vale',
          artistAvatar: '',
          studioName: 'Hidden Sanctuary',
          studioAddress: '742 Evergreen Ter, Portland, OR 97205',
          flashTitle: 'Serpent Study',
          flashImageUrl: '',
          dateTime: DateTime.now().add(const Duration(days: 5)),
          timeSlot: '3:00 PM',
          placement: 'Shoulder',
          depositAmount: 100,
          totalPrice: 400,
          status: AppointmentStatus.confirmed,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      AppointmentDetailModal.show(context, lockedAppointment),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Directions'));
        await tester.pumpAndSettle();

        expect(launchedUris, isEmpty);
        expect(
          find.text(
            'Exact studio address unlocks 24 hours before your confirmed session.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}

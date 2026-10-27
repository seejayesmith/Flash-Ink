import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'theme/app_theme.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment secrets
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // If .env is missing in certain environments, continue gracefully
  }

  // Initialize Stripe SDK if configured
  final stripePublishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
  if (stripePublishableKey != null && stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = stripePublishableKey;
    Stripe.merchantIdentifier = dotenv.env['STRIPE_MERCHANT_IDENTIFIER'] ?? 'merchant.com.seejaye.flash_ink';
    try {
      await Stripe.instance.applySettings();
    } catch (_) {
      // In tests or unsupported environments, continue gracefully
    }
  }
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Cap image cache to prevent Jetsam memory terminations on iOS devices
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20; // 80 MB limit
  PaintingBinding.instance.imageCache.maximumSize = 60; // 60 image limit

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  final Duration splashDelay;

  const MyApp({
    super.key,
    this.splashDelay = const Duration(seconds: 2),
  });

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Flash Ink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: SplashScreen(delay: splashDelay),
    );
    final hasScope = context.findAncestorWidgetOfExactType<ProviderScope>() !=
            null ||
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
            null;
    return hasScope ? app : ProviderScope(child: app);
  }
}

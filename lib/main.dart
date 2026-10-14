import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'theme/app_typography.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final Duration splashDelay;

  const MyApp({
    super.key,
    this.splashDelay = const Duration(seconds: 2),
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flash Ink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: AppTypography.textTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEEC200),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121414),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: SplashScreen(delay: splashDelay),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  const MyApp({super.key});

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
      home: const SplashScreen(),
    );
  }
}

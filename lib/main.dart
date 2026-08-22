import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

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
        textTheme: GoogleFonts.epilogueTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEEC200),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121414),
      ),
      home: const SplashScreen(),
    );
  }
}

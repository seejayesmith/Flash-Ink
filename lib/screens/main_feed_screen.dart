import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'browse_artists_screen.dart';

/// Main client feed screen hosting the Browse Artists experience.
class MainFeedScreen extends StatelessWidget {
  final AuthService? authService;

  const MainFeedScreen({
    super.key,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return BrowseArtistsScreen(authService: authService);
  }
}

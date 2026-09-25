import 'package:flutter/material.dart';
import '../features/appointments/presentation/screens/appointments_screen.dart';
import '../features/discover/presentation/screens/discover_screen.dart';
import '../features/explore/presentation/screens/explore_screen.dart';
import '../features/messages/presentation/screens/messages_screen.dart';
import '../models/nav_destination_item.dart';
import '../services/auth_service.dart';
import '../widgets/scaffold_with_nav_bar.dart';
import 'browse_artists_screen.dart';

/// Main client feed & navigation shell hosting the 5 primary root screens:
/// 1. Feed (Browse Artists)
/// 2. Discover (Curated Drops & Spotlight)
/// 3. Explore (Artists & Studios Directory)
/// 4. Appointments (Bookings Management)
/// 5. Messages (Direct Messaging Inbox)
class MainFeedScreen extends StatefulWidget {
  final AuthService? authService;
  final int initialIndex;

  const MainFeedScreen({
    super.key,
    this.authService,
    this.initialIndex = 0,
  });

  @override
  State<MainFeedScreen> createState() => _MainFeedScreenState();
}

class _MainFeedScreenState extends State<MainFeedScreen> {
  late int _activeTabIndex;

  @override
  void initState() {
    super.initState();
    _activeTabIndex = widget.initialIndex;
  }

  void _navigateToTab(int index) {
    setState(() {
      _activeTabIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BrowseArtistsScreen(
        authService: widget.authService,
        showBottomNav: false,
      ),
      DiscoverScreen(authService: widget.authService),
      const ExploreScreen(),
      AppointmentsScreen(
        onExploreTap: () => _navigateToTab(2), // Switch to Explore tab
      ),
      const MessagesScreen(),
    ];

    return ScaffoldWithNavBar(
      pages: pages,
      items: NavDestinationItem.clientDestinations,
      currentIndex: _activeTabIndex,
      onDestinationSelected: (index) {
        setState(() {
          _activeTabIndex = index;
        });
      },
    );
  }
}

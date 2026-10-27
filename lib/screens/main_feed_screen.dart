import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/appointments/presentation/screens/appointments_screen.dart';
import '../features/explore/presentation/screens/explore_screen.dart';
import '../features/messages/domain/models/message_thread.dart';
import '../features/messages/presentation/screens/messages_screen.dart';
import '../models/nav_destination_item.dart';
import '../providers/app_providers.dart';
import '../services/auth_service.dart';
import '../widgets/scaffold_with_nav_bar.dart';
import 'browse_artists_screen.dart';

/// Main client feed & navigation shell hosting the 4 primary root screens:
/// 1. Feed (Browse Artists)
/// 2. Explore (Curated Drops & Spotlight)
/// 3. Appointments (Bookings Management)
/// 4. Messages (Direct Messaging Inbox)
class MainFeedScreen extends StatelessWidget {
  final AuthService? authService;
  final int initialIndex;

  const MainFeedScreen({
    super.key,
    this.authService,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final content = _MainFeedContent(
      authService: authService,
      initialIndex: initialIndex,
    );
    final hasScope = context.findAncestorWidgetOfExactType<ProviderScope>() !=
            null ||
        context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() !=
            null;
    return hasScope ? content : ProviderScope(child: content);
  }
}

class _MainFeedContent extends ConsumerStatefulWidget {
  final AuthService? authService;
  final int initialIndex;

  const _MainFeedContent({
    required this.authService,
    required this.initialIndex,
  });

  @override
  ConsumerState<_MainFeedContent> createState() => _MainFeedContentState();
}

class _MainFeedContentState extends ConsumerState<_MainFeedContent> {
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
    final useMock = ref.watch(mockModeProvider);
    ref.watch(activeUidProvider);

    final activeThreads = useMock
        ? MessageThread.mockThreads
        : MessageThread.liveThreads;
    final unreadCount =
        activeThreads.fold<int>(0, (sum, t) => sum + t.unreadCount);

    final navItems = NavDestinationItem.clientDestinations.map((item) {
      if (item.route == '/client/messages') {
        return NavDestinationItem(
          icon: item.icon,
          activeIcon: item.activeIcon,
          label: item.label,
          route: item.route,
          key: item.key,
          hasNotificationBadge: unreadCount > 0,
          badgeCount: unreadCount > 0 ? unreadCount : null,
        );
      }
      return item;
    }).toList(growable: false);

    final pages = [
      BrowseArtistsScreen(
        authService: widget.authService,
        showBottomNav: false,
      ),
      ExploreScreen(authService: widget.authService),
      AppointmentsScreen(
        onExploreTap: () => _navigateToTab(1), // Switch to Explore tab
      ),
      const MessagesScreen(),
    ];

    return ScaffoldWithNavBar(
      pages: pages,
      items: navItems,
      currentIndex: _activeTabIndex,
      onDestinationSelected: (index) {
        setState(() {
          _activeTabIndex = index;
        });
      },
    );
  }
}

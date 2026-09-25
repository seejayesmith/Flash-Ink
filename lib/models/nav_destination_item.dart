import 'package:flutter/material.dart';

/// Strongly typed data model representing a navigation destination item.
///
/// Configures destination icons, active icons, localized/standard labels,
/// navigation routes, test keys, and optional notification badges.
class NavDestinationItem {
  /// The default icon rendered in inactive state.
  final IconData icon;

  /// The icon rendered when this destination is active. Defaults to [icon].
  final IconData? activeIcon;

  /// Display text label for this destination.
  final String label;

  /// Optional route path identifier (e.g., '/client/home' or '/artist/bookings').
  final String? route;

  /// Optional widget key for target-specific testing and identification.
  final Key? key;

  /// Whether to display a notification indicator badge on the destination.
  final bool hasNotificationBadge;

  /// Optional badge count displayed inside the badge indicator.
  final int? badgeCount;

  const NavDestinationItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.route,
    this.key,
    this.hasNotificationBadge = false,
    this.badgeCount,
  });

  /// The active icon to render, falling back to [icon] if not provided.
  IconData get effectiveActiveIcon => activeIcon ?? icon;

  /// Standard destinations for the Client interface (Feed, Discover, Explore, Appointments, Messages).
  static const List<NavDestinationItem> clientDestinations = [
    NavDestinationItem(
      icon: Icons.view_stream_outlined,
      activeIcon: Icons.view_stream_rounded,
      label: 'Feed',
      route: '/client/feed',
      key: Key('nav_item_0'),
    ),
    NavDestinationItem(
      icon: Icons.auto_awesome_mosaic_outlined,
      activeIcon: Icons.auto_awesome_mosaic,
      label: 'Discover',
      route: '/client/discover',
      key: Key('nav_item_1'),
    ),
    NavDestinationItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Explore',
      route: '/client/explore',
      key: Key('nav_item_2'),
    ),
    NavDestinationItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      label: 'Appointments',
      route: '/client/appointments',
      key: Key('nav_item_3'),
    ),
    NavDestinationItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Messages',
      route: '/client/messages',
      key: Key('nav_item_4'),
      hasNotificationBadge: true,
      badgeCount: 2,
    ),
  ];

  /// Standard destinations for the Artist interface (Schedule, Requests, Messages, Profile).
  static const List<NavDestinationItem> artistDestinations = [
    NavDestinationItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      label: 'Schedule',
      route: '/artist/schedule',
      key: Key('nav_item_0'),
    ),
    NavDestinationItem(
      icon: Icons.inbox_outlined,
      activeIcon: Icons.inbox_rounded,
      label: 'Requests',
      route: '/artist/requests',
      key: Key('nav_item_1'),
    ),
    NavDestinationItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Messages',
      route: '/artist/messages',
      key: Key('nav_item_2'),
      hasNotificationBadge: true,
    ),
    NavDestinationItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
      route: '/artist/profile',
      key: Key('nav_item_3'),
    ),
  ];

  /// Legacy uppercase destinations for backward compatibility.
  static const List<NavDestinationItem> legacyClientDestinations = [
    NavDestinationItem(
      icon: Icons.home_filled,
      activeIcon: Icons.home,
      label: 'HOME',
      route: '/client/home',
      key: Key('nav_item_0'),
    ),
    NavDestinationItem(
      icon: Icons.search,
      activeIcon: Icons.search,
      label: 'EXPLORE',
      route: '/client/explore',
      key: Key('nav_item_1'),
    ),
    NavDestinationItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      label: 'APPOINTMENTS',
      route: '/client/appointments',
      key: Key('nav_item_2'),
    ),
    NavDestinationItem(
      icon: Icons.notifications_none_outlined,
      activeIcon: Icons.notifications,
      label: 'ALERTS',
      route: '/client/alerts',
      key: Key('nav_item_3'),
    ),
  ];

  /// Legacy artist destinations for backward compatibility.
  static const List<NavDestinationItem> legacyArtistDestinations = [
    NavDestinationItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'DASHBOARD',
      route: '/artist/dashboard',
      key: Key('nav_item_0'),
    ),
    NavDestinationItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      label: 'CALENDAR',
      route: '/artist/calendar',
      key: Key('nav_item_1'),
    ),
    NavDestinationItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'MESSAGES',
      route: '/artist/messages',
      key: Key('nav_item_2'),
      hasNotificationBadge: true,
    ),
    NavDestinationItem(
      icon: Icons.attach_money,
      activeIcon: Icons.attach_money,
      label: 'EARNINGS',
      route: '/artist/earnings',
      key: Key('nav_item_3'),
    ),
  ];

  /// Dynamically resolves standardized destination items based on the active role.
  static List<NavDestinationItem> forRole(String role) {
    switch (role.toLowerCase().trim()) {
      case 'artist':
        return artistDestinations;
      case 'legacy_artist':
        return legacyArtistDestinations;
      case 'legacy_client':
        return legacyClientDestinations;
      case 'client':
      default:
        return clientDestinations;
    }
  }

  NavDestinationItem copyWith({
    IconData? icon,
    IconData? activeIcon,
    String? label,
    String? route,
    Key? key,
    bool? hasNotificationBadge,
    int? badgeCount,
  }) {
    return NavDestinationItem(
      icon: icon ?? this.icon,
      activeIcon: activeIcon ?? this.activeIcon,
      label: label ?? this.label,
      route: route ?? this.route,
      key: key ?? this.key,
      hasNotificationBadge: hasNotificationBadge ?? this.hasNotificationBadge,
      badgeCount: badgeCount ?? this.badgeCount,
    );
  }
}

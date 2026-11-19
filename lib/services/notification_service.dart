import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level handler invoked when an FCM message arrives while the app is
/// in the background or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Strongly typed per-user notification preference flags stored under
/// `users/{uid}.notificationPreferences`.
class NotificationPreferences {
  final bool flashDropAlerts;
  final bool bookingReminders;
  final bool artistMessages;
  final bool bookingAlerts;
  final bool reminderAlerts;
  final bool clientMessages;

  const NotificationPreferences({
    this.flashDropAlerts = true,
    this.bookingReminders = true,
    this.artistMessages = true,
    this.bookingAlerts = true,
    this.reminderAlerts = true,
    this.clientMessages = true,
  });

  factory NotificationPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NotificationPreferences();
    return NotificationPreferences(
      flashDropAlerts: map['flashDropAlerts'] is bool
          ? map['flashDropAlerts'] as bool
          : true,
      bookingReminders: map['bookingReminders'] is bool
          ? map['bookingReminders'] as bool
          : true,
      artistMessages: map['artistMessages'] is bool
          ? map['artistMessages'] as bool
          : true,
      bookingAlerts: map['bookingAlerts'] is bool
          ? map['bookingAlerts'] as bool
          : true,
      reminderAlerts: map['reminderAlerts'] is bool
          ? map['reminderAlerts'] as bool
          : true,
      clientMessages: map['clientMessages'] is bool
          ? map['clientMessages'] as bool
          : true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'flashDropAlerts': flashDropAlerts,
      'bookingReminders': bookingReminders,
      'artistMessages': artistMessages,
      'bookingAlerts': bookingAlerts,
      'reminderAlerts': reminderAlerts,
      'clientMessages': clientMessages,
    };
  }

  NotificationPreferences copyWith({
    bool? flashDropAlerts,
    bool? bookingReminders,
    bool? artistMessages,
    bool? bookingAlerts,
    bool? reminderAlerts,
    bool? clientMessages,
  }) {
    return NotificationPreferences(
      flashDropAlerts: flashDropAlerts ?? this.flashDropAlerts,
      bookingReminders: bookingReminders ?? this.bookingReminders,
      artistMessages: artistMessages ?? this.artistMessages,
      bookingAlerts: bookingAlerts ?? this.bookingAlerts,
      reminderAlerts: reminderAlerts ?? this.reminderAlerts,
      clientMessages: clientMessages ?? this.clientMessages,
    );
  }
}

/// Manages push (FCM) and local notification setup, token lifecycle,
/// foreground/tap handling, and Firestore preference synchronization.
class NotificationService {
  static const String highImportanceChannelId =
      'flash_ink_high_importance_channel';
  static const String highImportanceChannelName = 'Flash.Ink Alerts';

  /// Observable payload updated whenever the user taps a local or remote notification.
  static final ValueNotifier<Map<String, dynamic>?> lastTappedPayload =
      ValueNotifier<Map<String, dynamic>?>(null);

  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  static StreamSubscription<String>? _onTokenRefreshSub;

  static bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  /// Initializes FCM background handling, local notifications, permission prompts,
  /// foreground presentation, tap payloads, and token refresh listeners.
  static Future<void> initialize({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    FirebaseFirestore? firestore,
  }) async {
    if (_isWidgetTest && messaging == null && localNotifications == null) {
      return;
    }

    final fcm = messaging ?? FirebaseMessaging.instance;
    final plugin = localNotifications ?? FlutterLocalNotificationsPlugin();

    if (messaging == null) {
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (_) {}
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    try {
      await plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final rawPayload = response.payload;
          if (rawPayload != null && rawPayload.isNotEmpty) {
            try {
              final decoded = jsonDecode(rawPayload);
              if (decoded is Map) {
                lastTappedPayload.value = Map<String, dynamic>.from(decoded);
                return;
              }
            } catch (_) {}
            lastTappedPayload.value = {'raw': rawPayload};
          }
        },
      );
    } catch (e) {
      debugPrint('[NotificationService] Local notification init failed: $e');
    }

    try {
      final androidPlugin = plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const channel = AndroidNotificationChannel(
          highImportanceChannelId,
          highImportanceChannelName,
          description:
              'Immediate alerts for flash drops, bookings, reminders, and messages.',
          importance: Importance.max,
        );
        await androidPlugin.createNotificationChannel(channel);
      }
    } catch (_) {}

    try {
      await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('[NotificationService] Permission setup failed: $e');
    }

    await _onMessageSub?.cancel();
    _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message, plugin);
    });

    await _onMessageOpenedSub?.cancel();
    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.isNotEmpty) {
        lastTappedPayload.value = Map<String, dynamic>.from(message.data);
      }
    });

    try {
      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null && initialMessage.data.isNotEmpty) {
        lastTappedPayload.value = Map<String, dynamic>.from(
          initialMessage.data,
        );
      }
    } catch (_) {}

    await _onTokenRefreshSub?.cancel();
    _onTokenRefreshSub = fcm.onTokenRefresh.listen((String newToken) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.uid.isNotEmpty) {
          await syncFcmTokenForUser(
            user.uid,
            firestore: firestore,
            messaging: fcm,
            tokenOverride: newToken,
          );
        }
      } catch (_) {}
    });

    try {
      await syncFcmTokenForCurrentUser(
        firestore: firestore,
        messaging: fcm,
      );
    } catch (_) {}
  }

  static Future<void> _handleForegroundMessage(
    RemoteMessage message,
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title']?.toString();
    final body =
        notification?.body ?? message.data['body']?.toString();

    if (title == null && body == null) return;

    // On Apple platforms, setForegroundNotificationPresentationOptions already
    // presents notifications that include an APNs `notification` block.
    final isAppleWithSystemBanner = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS) &&
        notification != null;
    if (isAppleWithSystemBanner) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      highImportanceChannelId,
      highImportanceChannelName,
      channelDescription:
          'Immediate alerts for flash drops, bookings, reminders, and messages.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      final id = message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
      await plugin.show(
        id,
        title,
        body,
        details,
        payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
      );
    } catch (e) {
      debugPrint('[NotificationService] Foreground local display failed: $e');
    }
  }

  /// Syncs the device FCM token for [user] (or `FirebaseAuth.instance.currentUser`)
  /// when signed into a non-anonymous account.
  static Future<String?> syncFcmTokenForCurrentUser({
    User? user,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    String? tokenOverride,
  }) async {
    User? targetUser = user;
    if (targetUser == null) {
      try {
        targetUser = FirebaseAuth.instance.currentUser;
      } catch (_) {
        return null;
      }
    }
    if (targetUser == null ||
        targetUser.isAnonymous ||
        targetUser.uid.trim().isEmpty) {
      return null;
    }

    return syncFcmTokenForUser(
      targetUser.uid,
      firestore: firestore,
      messaging: messaging,
      tokenOverride: tokenOverride,
    );
  }

  /// Fetches the current device FCM token (or uses [tokenOverride]) and stores it
  /// in `users/{uid}.fcmTokens`.
  static Future<String?> syncFcmTokenForUser(
    String uid, {
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    String? tokenOverride,
  }) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return null;
    if (_isWidgetTest && messaging == null && tokenOverride == null) {
      return null;
    }

    try {
      final token = tokenOverride ??
          await (messaging ?? FirebaseMessaging.instance).getToken();
      if (token == null || token.trim().isEmpty) return null;

      final cleanToken = token.trim();
      final db = firestore ?? FirebaseFirestore.instance;
      await db.collection('users').doc(cleanUid).set({
        'fcmTokens': FieldValue.arrayUnion([cleanToken]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return cleanToken;
    } catch (e) {
      debugPrint('[NotificationService] Failed to sync FCM token: $e');
      return null;
    }
  }

  /// Removes the current device FCM token (or [tokenOverride]) from `users/{uid}.fcmTokens`.
  static Future<void> removeFcmTokenForUser(
    String uid, {
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    String? tokenOverride,
  }) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return;
    if (_isWidgetTest && messaging == null && tokenOverride == null) {
      return;
    }

    try {
      final token = tokenOverride ??
          await (messaging ?? FirebaseMessaging.instance).getToken();
      if (token == null || token.trim().isEmpty) return;

      final cleanToken = token.trim();
      final db = firestore ?? FirebaseFirestore.instance;
      await db.collection('users').doc(cleanUid).update({
        'fcmTokens': FieldValue.arrayRemove([cleanToken]),
      });
    } catch (e) {
      debugPrint('[NotificationService] Failed to remove FCM token: $e');
    }
  }

  /// Loads `notificationPreferences` for [uid] from Firestore, returning defaults
  /// when unavailable.
  static Future<NotificationPreferences> loadPreferences(
    String uid, {
    FirebaseFirestore? firestore,
  }) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return const NotificationPreferences();
    if (_isWidgetTest && firestore == null) {
      return const NotificationPreferences();
    }

    try {
      final db = firestore ?? FirebaseFirestore.instance;
      final snap = await db.collection('users').doc(cleanUid).get();
      final data = snap.data();
      if (data == null || data['notificationPreferences'] is! Map) {
        return const NotificationPreferences();
      }
      return NotificationPreferences.fromMap(
        Map<String, dynamic>.from(data['notificationPreferences'] as Map),
      );
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  /// Persists a single notification preference toggle under
  /// `users/{uid}.notificationPreferences`.
  static Future<void> updatePreference(
    String uid, {
    required String key,
    required bool value,
    FirebaseFirestore? firestore,
  }) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return;
    if (_isWidgetTest && firestore == null) {
      return;
    }

    try {
      final db = firestore ?? FirebaseFirestore.instance;
      await db.collection('users').doc(cleanUid).set({
        'notificationPreferences': {key: value},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[NotificationService] Failed to update preference $key: $e');
    }
  }

  /// Persists whether [uid] is following [artistId] under
  /// `users/{uid}.followedArtistIds` for Flash Drop push alerts.
  static Future<void> syncFollowedArtist(
    String uid, {
    required String artistId,
    required bool isFollowed,
    FirebaseFirestore? firestore,
  }) async {
    final cleanUid = uid.trim();
    final cleanArtistId = artistId.trim();
    if (cleanUid.isEmpty || cleanArtistId.isEmpty) return;
    if (_isWidgetTest && firestore == null) {
      return;
    }

    try {
      final db = firestore ?? FirebaseFirestore.instance;
      await db.collection('users').doc(cleanUid).set({
        'followedArtistIds': isFollowed
            ? FieldValue.arrayUnion([cleanArtistId])
            : FieldValue.arrayRemove([cleanArtistId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
        '[NotificationService] Failed to sync followed artist $cleanArtistId: $e',
      );
    }
  }
}

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Resolves the device's physical display bottom corner radii in logical pixels.
///
/// Resolution order:
/// 1. [MediaQuery.maybeDisplayCornerRadiiOf] (populated natively on Android API 31+).
/// 2. Cached iOS native measurement via [MethodChannel] (`flash_ink/device_corner_radius`),
///    using UIKit's `containerConcentric` `effectiveRadius` on iOS 26+ and an
///    App-Store-safe hardware identifier / screen-size table on iOS 15–25.
/// 3. Orientation-independent Dart geometry fallback when the native channel
///    is unavailable (e.g., first frame or headless widget tests).
class DeviceCornerRadius {
  DeviceCornerRadius._();

  static const MethodChannel _channel = MethodChannel('flash_ink/device_corner_radius');

  /// Notifies listeners (such as [AdaptiveGlassContainer.bottomSheet]) when
  /// the asynchronous iOS native corner radius measurement completes.
  static final ValueNotifier<({double bottomLeft, double bottomRight})?> iosRadiiNotifier =
      ValueNotifier<({double bottomLeft, double bottomRight})?>(null);

  static Future<void>? _inFlightWarmUp;
  static bool _didWarmUp = false;

  /// Pre-fetches the native iOS display corner radii so the value is available
  /// synchronously before any bottom sheet opens.
  static Future<void> warmUp() async {
    if (_didWarmUp) return;
    if (_inFlightWarmUp != null) return _inFlightWarmUp;

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      _didWarmUp = true;
      return;
    }

    _inFlightWarmUp = _fetchNativeIosRadii().whenComplete(() {
      _inFlightWarmUp = null;
      _didWarmUp = true;
    });
    return _inFlightWarmUp;
  }

  /// Triggers a one-time lazy fetch when running on iOS if [warmUp] hasn't run yet.
  static void ensureInitialized(TargetPlatform platform) {
    if (_didWarmUp || _inFlightWarmUp != null) return;
    if (kIsWeb || platform != TargetPlatform.iOS) return;
    warmUp();
  }

  static Future<void> _fetchNativeIosRadii() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getBottomCornerRadii');
      if (result == null) return;
      final left = (result['bottomLeft'] as num?)?.toDouble();
      final right = (result['bottomRight'] as num?)?.toDouble();
      if (left != null && right != null && left >= 0 && right >= 0) {
        iosRadiiNotifier.value = (bottomLeft: left, bottomRight: right);
      }
    } on MissingPluginException {
      // Expected in headless widget tests without a platform runner.
    } catch (_) {
      // Fall back gracefully to the Dart geometry heuristic.
    }
  }

  /// Overrides or clears the cached iOS corner radii for deterministic widget tests.
  @visibleForTesting
  static void setTestingIosRadii(({double bottomLeft, double bottomRight})? radii) {
    _didWarmUp = radii != null;
    _inFlightWarmUp = null;
    iosRadiiNotifier.value = radii;
  }

  /// Resets cached initialization state for tests.
  @visibleForTesting
  static void resetForTesting() {
    _didWarmUp = false;
    _inFlightWarmUp = null;
    iosRadiiNotifier.value = null;
  }

  /// Resolves the raw hardware bottom-left and bottom-right corner radii (in
  /// logical pixels) before applying any sheet edge inset.
  ///
  /// Returns `(bottomLeft: 0.0, bottomRight: 0.0)` when the device has no
  /// bottom hardware bezel curve (e.g. square screens or home-button devices).
  static ({double bottomLeft, double bottomRight}) resolveBottomRadii(BuildContext context) {
    // 1. Native Android API 31+ (or any platform populating displayCornerRadii)
    final displayRadii = MediaQuery.maybeDisplayCornerRadiiOf(context);
    if (displayRadii != null &&
        (displayRadii.bottomLeft.x > 0 || displayRadii.bottomRight.x > 0)) {
      return (
        bottomLeft: displayRadii.bottomLeft.x,
        bottomRight: displayRadii.bottomRight.x,
      );
    }

    final viewPadding = MediaQuery.viewPaddingOf(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    final bottomSafe = viewPadding.bottom > 0 ? viewPadding.bottom : mediaPadding.bottom;

    if (bottomSafe <= 0) {
      return (bottomLeft: 0.0, bottomRight: 0.0);
    }

    // 2. Native iOS measurement (cached from MethodChannel)
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      final cached = iosRadiiNotifier.value;
      if (cached != null) {
        return cached;
      }
    }

    // 3. Accurate orientation-independent screen-dimension fallback
    final size = MediaQuery.sizeOf(context);
    final fallback = fallbackRadiusForScreenSize(size);
    return (bottomLeft: fallback, bottomRight: fallback);
  }

  /// Maps logical screen dimensions to known hardware display corner radii for
  /// edge-to-edge devices with a bottom home indicator.
  static double fallbackRadiusForScreenSize(Size size) {
    final minSide = math.min(size.width, size.height);
    final maxSide = math.max(size.width, size.height);

    // Modern bezel-less iPads (11", 13", mini with home indicator)
    if (minSide >= 600) {
      return 18.0;
    }

    // Exact logical point dimensions for modern iPhone generations:
    // - iPhone 16 Pro (402x874), 16 Pro Max (440x956), 17 / 17 Pro / 17 Pro Max, Air (420x912)
    if (_matches(minSide, maxSide, 402, 874) ||
        _matches(minSide, maxSide, 440, 956) ||
        _matches(minSide, maxSide, 420, 912)) {
      return 62.0;
    }

    // - iPhone 14 Pro / 15 / 15 Pro / 16 (393x852),
    //   14 Pro Max / 15 Plus / 15 Pro Max / 16 Plus (430x932)
    if (_matches(minSide, maxSide, 393, 852) ||
        _matches(minSide, maxSide, 430, 932)) {
      return 55.0;
    }

    // - iPhone 12 / 12 Pro / 13 / 13 Pro / 14 / 16e (390x844),
    //   12 Pro Max / 13 Pro Max / 14 Plus (428x926)
    if (_matches(minSide, maxSide, 390, 844) ||
        _matches(minSide, maxSide, 428, 926)) {
      return 47.33;
    }

    // - iPhone X / XS / 11 Pro / 12 mini / 13 mini (375x812)
    if (_matches(minSide, maxSide, 375, 812)) {
      return 44.0;
    }

    // - iPhone XR / 11 / XS Max / 11 Pro Max (414x896)
    if (_matches(minSide, maxSide, 414, 896)) {
      return 41.5;
    }

    // Generic phone fallback for future/Android devices without displayCornerRadii
    if (maxSide >= 940) return 62.0;
    if (maxSide >= 850) return 55.0;
    return 47.33;
  }

  static bool _matches(double minSide, double maxSide, double targetW, double targetH) {
    return (minSide - targetW).abs() <= 1.5 && (maxSide - targetH).abs() <= 1.5;
  }
}

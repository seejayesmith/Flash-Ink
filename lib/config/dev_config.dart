import 'package:flutter/foundation.dart';

/// Flag controlling whether developer bypass shortcuts (such as Skip buttons)
/// are rendered during development, QA, and local testing builds.
///
/// In local testing (including Debug, Profile, and Release schemes run from Xcode),
/// this evaluates to `true`.
/// It is only disabled in production App Store releases built with:
/// `--dart-define=IS_PRODUCTION=true`.
const bool kIsProduction = bool.fromEnvironment('IS_PRODUCTION', defaultValue: false);
const bool kEnableDevBypass = !kIsProduction || !kReleaseMode;

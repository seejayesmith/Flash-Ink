/// Centralized gate controlling whether quarantined mock/fixture datasets are
/// exposed to active application runtime surfaces.
///
/// Disabled (`false`) by default in all dev and production builds.
/// Pass `--dart-define=USE_MOCK_DATA=true` or use Riverpod `ProviderScope`
/// overrides (`mockModeProvider`) in isolated UI sandboxes / widget tests.
const bool kEnableMockData = bool.fromEnvironment(
  'USE_MOCK_DATA',
  defaultValue: false,
);

/// Runtime configuration helper for mock data quarantine.
class MockDataConfig {
  MockDataConfig._();

  /// Optional test-only override. Leave `null` in all production/dev runtime paths.
  static bool? debugOverride;

  /// Whether quarantined mock data is enabled in the current process.
  static bool get isEnabled => debugOverride ?? kEnableMockData;

  /// Resets [debugOverride] back to `null` (default live runtime mode).
  static void resetDebugOverride() {
    debugOverride = null;
  }
}

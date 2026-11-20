/// Legacy display switch for fixture-only previews and compatibility tests.
/// Live request routing is based on the exact packaged account/token allowlist,
/// never this build flag: real accounts always use the configured backend.
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);

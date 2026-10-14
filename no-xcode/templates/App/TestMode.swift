import Foundation

/// Test/demo mode for driving the app autonomously on the simulator.
///
/// Activated by launching with `APP_TEST_MODE=1` in the environment: set by XCUITest via
/// `app.launchEnvironment`, or by `simctl launch` via `SIMCTL_CHILD_APP_TEST_MODE=1`
/// (`make run` does this). In test mode the app should:
///   - start from deterministic seeded data (in-memory, never the user's real store),
///   - skip auth gates, onboarding and permission prompts that block automation,
///   - route network/hardware services to local stubs behind small protocols.
///
/// Everything is `#if DEBUG`, so Release builds can never enter test mode.
enum TestMode {
    #if DEBUG
    static let isActive = ProcessInfo.processInfo.environment["APP_TEST_MODE"] == "1"
    #else
    static let isActive = false
    #endif
}

#if DEBUG
extension CounterModel {
    /// Deterministic starting state for screenshots and UI tests.
    static func seeded() -> CounterModel { CounterModel(count: 3) }
}
#else
extension CounterModel {
    static func seeded() -> CounterModel { CounterModel() }
}
#endif

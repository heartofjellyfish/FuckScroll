import AppIntents

struct BeginScrollSession: AppIntent {
    static var title: LocalizedStringResource = "App opened — start session"
    static var description = IntentDescription("Use in a Run Immediately automation when your selected scroll app is opened. Runs without opening Scroll Stopper.")
    static var isDiscoverable: Bool { false }
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    func perform() async throws -> some IntentResult {
        try Monitoring.appOpened()
        return .result()
    }
}

struct EndScrollSession: AppIntent {
    static var title: LocalizedStringResource = "App closed — end session"
    static var description = IntentDescription("Use in a Run Immediately automation when your selected scroll app is closed. A minute away resets the next session.")
    static var isDiscoverable: Bool { false }
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    func perform() async throws -> some IntentResult {
        Monitoring.appClosed()
        return .result()
    }
}

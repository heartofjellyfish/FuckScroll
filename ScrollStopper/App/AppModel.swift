import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

struct InterruptionMode: Identifiable {
    let id = UUID()
    var preview: Bool
    var mood: Int
}

enum DutyStatus { case noRules, off, on, check, starting }

@MainActor
final class AppModel: ObservableObject {
    @Published var language = SharedStore.language { didSet { SharedStore.language = language } }
    @Published var onboarded = UserDefaults.standard.bool(forKey: "onboarded")
    @Published var firstDutyThisVisit = false
    @Published var selection = FamilyActivitySelection()
    @Published var limits: [ApplicationToken: Int] = [:]
    @Published var focusedToken: ApplicationToken?
    @Published var saving = false
    @Published var states = UsageSessions()
    @Published var limit = 20
    @Published var breaks: [ApplicationToken: Int] = [:]
    @Published var showSetup = false
    @Published var showSettings = false
    @Published var interruption: InterruptionMode?
    @Published var error: String?
    @Published var selectionIssue: AppSelectionIssue?
    @Published var authorizing = false
    @Published var authorized = false
    @Published var enabled = SharedStore.enabled
    @Published var session = SharedStore.session
    @Published var rules = SharedStore.rules
    @Published private var stateUnavailable = false
    @Published private var enablingDuty = false
    var dutyStatus: DutyStatus {
        if enablingDuty { return .starting }
        if stateUnavailable { return .check }
        if isRehearsal { return enabled ? .on : .off }
        guard !rules.isEmpty else { return .noRules }
        guard authorized else { return .check }
        guard enabled else { return .off }
        let now = Date()
        let ready = rules.allSatisfy { rule in
            guard let state = states.values[rule.id], state.monitoringError == nil else { return false }
            return state.activeMonitor != nil || state.isResting(at: now)
        }
        return ready ? .on : .check
    }
    var dutyLabel: String {
        switch dutyStatus {
        case .starting: return voice("Starting…", "启动中…")
        case .check: return voice("CHECK DUTY", "查看状态")
        case .on: return voice("ON DUTY", "在岗")
        case .off, .noRules: return voice("OFF DUTY", "已下班")
        }
    }
    var voice: Voice { Voice(language: language) }
    var resting: Bool { session.isResting(at: Date()) }
    // Opt-in, in-memory fixtures for UI tests; never grant permission or touch
    // the real monitoring state. Release builds cannot enter this mode.
    var isRehearsal: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--rehearsal-rest") || args.contains("--rehearsal-paused")
        #else
        return false
        #endif
    }
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    init() {
        if let rule = rules.first {
            selection.applicationTokens = Set(rules.map(\.token))
            limits = Dictionary(uniqueKeysWithValues: rules.map { ($0.token, $0.limit) })
            limit = rule.limit
            breaks = Dictionary(uniqueKeysWithValues: rules.map { ($0.token, $0.restMinutes) })
        }
        if !isRehearsal && !isSimulator { Monitoring.migrateIfNeeded() }
        refresh()
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--welcome") { onboarded = false }
        if args.contains("--home") { onboarded = true }
        if args.contains("--settings") { showSettings = true }
        if args.contains("--qa-limits") { enabled = true; onboarded = !args.contains("--qa-first-selection"); showSetup = true }
        if args.contains("--setup") { showSetup = true }
        if args.contains("--zh") { language = .chinese }
        if args.contains("--en") { language = .english }
        if let qa = AppLanguage.allCases.first(where: { args.contains("--locale-" + $0.code) }) { language = qa }
        if args.contains("--preview") { interruption = .init(preview: true, mood: args.contains("--rage") ? 2 : 0) }
        if isRehearsal {
            session = SessionState()
            if args.contains("--rehearsal-rest") { session.beginRest(at: Date(), minutes: 15) }
            if args.contains("--short-rest") { session.cooldownUntil = Date().addingTimeInterval(8) }
            onboarded = true
            authorized = true
            stateUnavailable = args.contains("--qa-unreadable")
            enabled = !args.contains("--rehearsal-paused")
            firstDutyThisVisit = args.contains("--qa-first-duty")
        }
        if args.contains("--quick-test") { limit = 2; for rule in rules { limits[rule.token] = 2 }; showSetup = true }
        #endif
    }
    func refresh() {
        if isRehearsal { session.finishRest(at: Date()); return }
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        if #available(iOS 26.4, *), AuthorizationCenter.shared.authorizationStatus == .approvedWithDataAccess { authorized = true }
        Monitoring.finishRest()
        guard let value = try? SharedStore.loadProtection() else {
            stateUnavailable = true
            return
        }
        stateUnavailable = false
        rules = value.rules
        states = value.sessions
        enabled = value.enabled
        if let id = states.restingIDs(at: Date()).first { session = states.values[id] ?? SessionState() }
        else { session = states.values.values.first(where: { $0.monitoringError != nil }) ?? SessionState() }
    }
    func requestAccess() async {
        guard !authorizing else { return }
        if isSimulator {
            error = voice("Screen Time needs a real iPhone. You can explore the interruption here, but this simulator cannot protect other apps.", "屏幕使用时间需要真机。这里可以预览界面，但模拟器无法拦截其他 App。")
            return
        }
        authorizing = true
        defer { authorizing = false }
        do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual); refresh() }
        catch { self.error = voice("Screen Time access wasn’t granted. You can try again whenever you’re ready.", "没有获得屏幕使用时间权限。准备好以后可以再试。") }
    }
    func edit(_ rule: AppRule? = nil) {
        breaks = Dictionary(uniqueKeysWithValues: rules.map { ($0.token, $0.restMinutes) })
        selection = FamilyActivitySelection()
        selectionIssue = nil
        selection.applicationTokens = Set(rules.map(\.token))
        limits = Dictionary(uniqueKeysWithValues: rules.map { ($0.token, $0.limit) })
        focusedToken = rule?.token
        showSetup = true
    }
    func state(for token: ApplicationToken) -> SessionState {
        guard let id = rules.first(where: { $0.token == token })?.id else { return SessionState() }
        return states.values[id] ?? SessionState()
    }
    func saveEmptySelectionIfNeeded() {
        guard !rules.isEmpty, selection.applicationTokens.isEmpty,
              selection.categoryTokens.isEmpty, selection.webDomainTokens.isEmpty else { return }
        save(dismissAfterSaving: false)
    }
    func checkSelection() -> Bool {
        selectionIssue = AppSelectionIssue(
            appCount: selection.applicationTokens.count,
            maximumApps: Monitoring.maximumApps,
            hasUnsupportedItems: !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty
        )
        return selectionIssue == nil
    }
    func keepSelectedApps() {
        let apps = selection.applicationTokens
        guard !apps.isEmpty, apps.count <= Monitoring.maximumApps else { return }
        var appsOnly = FamilyActivitySelection()
        appsOnly.applicationTokens = apps
        selection = appsOnly
        selectionIssue = nil
    }
    func save(dismissAfterSaving: Bool = true) {
        guard !isRehearsal, !saving else { return }
        guard checkSelection() else { return }
        refresh()
        guard authorized || selection.applicationTokens.isEmpty else { error = voice("Allow Screen Time access first.", "请先允许屏幕使用时间权限。"); return }
        let retained = rules.filter { selection.applicationTokens.contains($0.token) }
        let newTokens = selection.applicationTokens.subtracting(Set(rules.map(\.token)))
        let chosen = retained.map { old in
            AppRule(id: old.id, token: old.token, limit: ScrollPolicy.validLimit(limits[old.token] ?? old.limit), restMinutes: breaks[old.token] ?? old.restMinutes)
        } + newTokens.map { AppRule(id: UUID().uuidString, token: $0, limit: ScrollPolicy.validLimit(limits[$0] ?? 20), restMinutes: breaks[$0] ?? 15) }
        saving = true
        Task {
            let issue = await Task.detached { () -> String? in
                do { try Monitoring.configure(chosen); return nil }
                catch { return error.localizedDescription }
            }.value
            saving = false
            refresh()
            if let issue {
                // A rejected clear must not leave the editor pretending the saved list is empty.
                if chosen.isEmpty { selection.applicationTokens = Set(rules.map(\.token)) }
                error = issue
                return
            }
            firstDutyThisVisit = !onboarded
            UserDefaults.standard.set(true, forKey: "onboarded")
            onboarded = true
            if dismissAfterSaving { showSetup = false }
        }
    }
    func retryDuty() {
        if isRehearsal { stateUnavailable = false }
        refresh()
        guard !stateUnavailable else { error = Monitoring.ConfigurationError.storage.localizedDescription; return }
        // Re-reading a paused snapshot must never implicitly resume it.
        if dutyStatus == .check && enabled && authorized { setDuty(true) }
    }
    func setDuty(_ turnOn: Bool) {
        guard !saving else { return }
        if isRehearsal { enabled = turnOn; return }
        refresh()
        guard !stateUnavailable else { error = Monitoring.ConfigurationError.storage.localizedDescription; return }
        guard turnOn != enabled || (turnOn && dutyStatus == .check) else { return }
        let currentRules = rules
        guard !turnOn || (authorized && !currentRules.isEmpty) else { edit(); return }
        saving = true
        enablingDuty = turnOn
        Task {
            let issue = await Task.detached { () -> String? in
                do {
                    if turnOn { try Monitoring.configure(currentRules) }
                    else { try Monitoring.pauseNewMonitoring() }
                    return nil
                } catch { return error.localizedDescription }
            }.value
            refresh()
            enablingDuty = false
            saving = false
            error = issue
        }
    }
}

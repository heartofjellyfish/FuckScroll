import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Darwin
import OSLog

struct AppRule: Codable, Identifiable {
    let id: String
    let token: ApplicationToken
    var limit: Int
    var restMinutes: Int = ScrollPolicy.defaultBreak
    var store: ManagedSettingsStore { SharedStore.shieldStore }
}

extension AppRule {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        token = try values.decode(ApplicationToken.self, forKey: .token)
        limit = try values.decode(Int.self, forKey: .limit)
        restMinutes = try values.decodeIfPresent(Int.self, forKey: .restMinutes) ?? 15
    }
}

struct ProtectionState: Codable {
    var lastEmphaticBreak: Date?
    // Resolve the expression once, while committing a new break under the shared lock.
    mutating func edition(for id: String, at now: Date) -> Int {
        let recentOthers = rules.filter { rule in
            guard rule.id != id, let last = sessions.values[rule.id]?.lastInterruptionAt else { return false }
            return (0..<1800).contains(now.timeIntervalSince(last))
        }.count
        if recentOthers >= 2 && (lastEmphaticBreak.map { now.timeIntervalSince($0) >= 14400 } ?? true) {
            lastEmphaticBreak = now
            return 0
        }
        return recentOthers == 0 ? 2 : 1
    }
    var rules: [AppRule] = []
    var sessions = UsageSessions()
    var enabled = false
}

enum SharedStore {
    static let group = "group.com.heartofjellyfish.scrollstopper"
    static var defaults: UserDefaults { UserDefaults(suiteName: group)! }
    static let reminderKey = "customReminder"
    static let reminderLimit = 40

    static let actionKey = "customReminderAction"
    static let actionLimit = 16
    static func actionTitle(_ voice: Voice) -> String {
        reminderLine(defaults.string(forKey: actionKey) ?? "", action: true, voice: voice)
    }
    static func reminderLine(_ raw: String, action: Bool, voice: Voice) -> String {
        let saved = limitedReminder(raw, limit: action ? actionLimit : reminderLimit)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !saved.isEmpty { return saved }
        return action ? voice("Step away", "先放下") : voice("One more?", "再刷一条？")
    }
    static func limitedReminder(_ text: String, limit: Int = reminderLimit) -> String {
        String(text.components(separatedBy: .newlines).joined(separator: " ").prefix(limit))
    }

    static func reminderTitle(_ voice: Voice) -> String {
        reminderLine(defaults.string(forKey: reminderKey) ?? "", action: false, voice: voice)
    }
    static var shieldStore: ManagedSettingsStore { ManagedSettingsStore(named: .init("scrollstopper.selected")) }
    static var language: AppLanguage {
        get { AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .preferred() }
        set { defaults.set(newValue.rawValue, forKey: "language") }
    }
    private static func url(_ name: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent(name)
    }
    // Rules, monitor ownership and cooldowns commit together across all processes.
    #if MONITOR_TESTS
    static var testState = ProtectionState()
    #endif
    // Only a genuinely absent file should import the pre-v3 defaults.
    static func readProtection(at file: URL, legacy: () throws -> ProtectionState) throws -> ProtectionState {
        do {
            return try JSONDecoder().decode(ProtectionState.self, from: Data(contentsOf: file))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return try legacy()
        }
    }
    static func loadProtection() throws -> ProtectionState {
        #if MONITOR_TESTS
        return testState
        #else
        guard let file = url("protection-v3.json") else { throw Monitoring.ConfigurationError.storage }
        return try readProtection(at: file) {
            var legacy = ProtectionState()
            if let data = defaults.data(forKey: "rules") {
                legacy.rules = try JSONDecoder().decode([AppRule].self, from: data)
            }
            legacy.enabled = defaults.bool(forKey: "enabled")
            if let id = legacy.rules.first?.id, let file = url("session.json"), let data = try? Data(contentsOf: file) {
                legacy.sessions.values[id] = try JSONDecoder().decode(SessionState.self, from: data)
            }
            return legacy
        }
        #endif
    }
    static var protection: ProtectionState { (try? loadProtection()) ?? ProtectionState() }
    @discardableResult static func persist(_ value: ProtectionState) -> Bool {
        #if MONITOR_TESTS
        testState = value
        return true
        #else
        guard let file = url("protection-v3.json"), let data = try? JSONEncoder().encode(value) else { return false }
        do { try data.write(to: file, options: .atomic); return true } catch { return false }
        #endif
    }
    static var rules: [AppRule] { protection.rules }
    static var enabled: Bool { protection.enabled }
    static var session: SessionState {
        let value = protection
        if let id = value.sessions.restingIDs(at: Date()).first { return value.sessions.values[id] ?? SessionState() }
        return value.rules.first.flatMap { value.sessions.values[$0.id] } ?? SessionState()
    }
    static func locked<T>(_ body: () throws -> T) rethrows -> T {
        let fd = url("session.lock").map { Darwin.open($0.path, O_CREAT | O_RDWR, 0o600) } ?? -1
        if fd >= 0 { flock(fd, LOCK_EX) }
        defer { if fd >= 0 { flock(fd, LOCK_UN); Darwin.close(fd) } }
        return try body()
    }
    static func updateShield(_ value: ProtectionState) {
        let tokens = Set(value.rules.filter { value.sessions.values[$0.id]?.isResting(at: Date()) == true }.map(\.token))
        shieldStore.shield.applications = tokens.isEmpty ? nil : tokens
    }
}

enum Monitoring {
    static let threshold = DeviceActivityEvent.Name("enough")
    static let prefix = "usage."
    private static let freshPrefix = "usage.run."
    static func marks(for limit: Int) -> [Int] {
        // Minute precision for short limits. Bound the number of events on longer rules.
        let step = max(1, (limit + 11) / 12)
        return Array(Set([1, limit] + Array(stride(from: step, through: limit, by: step)))).sorted()
    }
    static func eventName(minute: Int, limit: Int) -> DeviceActivityEvent.Name {
        minute == limit ? threshold : .init("minute." + String(minute))
    }
    // Each rule needs a usage monitor and a release monitor. Reserve two slots.
    static let maximumApps = 9
    private static let log = Logger(subsystem: "com.heartofjellyfish.scrollstopper", category: "Monitoring")
    static func window(start: Date, minutes: Int) -> DeviceActivitySchedule {
        let components: Set<Calendar.Component> = [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second]
        return DeviceActivitySchedule(intervalStart: Calendar.current.dateComponents(components, from: start), intervalEnd: Calendar.current.dateComponents(components, from: start.addingTimeInterval(TimeInterval(minutes * 60))), repeats: false)
    }
    static func appOpened() throws {}
    static func appClosed() {}

    private static func save(_ value: ProtectionState) throws {
        guard SharedStore.persist(value) else { throw ConfigurationError.storage }
    }
    private static func arm(_ rule: AppRule, value: inout ProtectionState) throws {
        let name = freshPrefix + UUID().uuidString
        var state = value.sessions.values[rule.id] ?? SessionState()
        state.usageRun?.lastMark = 0
        state.activeMonitor = name
        state.monitoringError = nil
        value.sessions.values[rule.id] = state
        try save(value)
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0), intervalEnd: DateComponents(hour: 23, minute: 59, second: 59), repeats: true)
        let events = Dictionary(uniqueKeysWithValues: marks(for: rule.limit).map { minute in
            (eventName(minute: minute, limit: rule.limit), DeviceActivityEvent(applications: [rule.token], threshold: DateComponents(minute: minute), includesPastActivity: false))
        })
        do {
            try DeviceActivityCenter().startMonitoring(.init(name), during: schedule, events: events)
        } catch {
            state.activeMonitor = nil
            state.monitoringError = error.localizedDescription
            value.sessions.values[rule.id] = state
            try save(value)
            throw error
        }
    }
    static func reachedThreshold(event: DeviceActivityEvent.Name, activity: DeviceActivityName, at began: Date = Date()) {
        guard activity.rawValue.hasPrefix(prefix),
              SharedStore.protection.sessions.usageOwner(activity.rawValue, at: Date()) != nil else { return }
        SharedStore.locked {
            guard var value = try? SharedStore.loadProtection() else { return }
            guard value.enabled, let id = value.sessions.usageOwner(activity.rawValue, at: Date()),
                  let rule = value.rules.first(where: { $0.id == id }) else { return }
            var state = value.sessions.values[id] ?? SessionState()
            let release = "rest." + UUID().uuidString
            do {
                let lastMilestone = event == threshold
                let minute = lastMilestone ? rule.limit : Int(event.rawValue.dropFirst("minute.".count))
                guard let minute, marks(for: rule.limit).contains(minute),
                      event == eventName(minute: minute, limit: rule.limit) else { return }
                if !activity.rawValue.hasPrefix(freshPrefix) {
                    // A pre-update monitor has no history to establish freshness.
                    state.retiredUsageMonitor = activity.rawValue
                    state.usageRun = nil
                    value.sessions.values[id] = state
                    try arm(rule, value: &value)
                    return
                }
                var run = state.usageRun ?? UsageRun()
                guard run.record(mark: minute, at: began, breakMinutes: rule.restMinutes) else { return }
                state.usageRun = run
                if let old = state.retiredUsageMonitor {
                    DeviceActivityCenter().stopMonitoring([.init(old)])
                    state.retiredUsageMonitor = nil
                }
                if let old = state.retiredRestMonitor {
                    DeviceActivityCenter().stopMonitoring([.init(old)])
                    state.retiredRestMonitor = nil
                }
                if run.minutes < rule.limit {
                    if lastMilestone {
                        // iOS only sends each milestone once per interval. Roll to a
                        // fresh counter while retaining this return's confirmed use.
                        state.retiredUsageMonitor = activity.rawValue
                        value.sessions.values[id] = state
                        try arm(rule, value: &value)
                    } else {
                        value.sessions.values[id] = state
                        try save(value)
                    }
                    return
                }
                state.usageRun = nil
                let start = Date(timeIntervalSince1970: ceil(began.timeIntervalSince1970))
                // For short rests, register an already-open 15-minute interval whose end
                // is the requested release time. Shielding starts only after registration.
                let windowMinutes = max(15, rule.restMinutes)
                let windowStart = start.addingTimeInterval(-TimeInterval((windowMinutes - rule.restMinutes) * 60))
                try DeviceActivityCenter().startMonitoring(.init(release), during: window(start: windowStart, minutes: windowMinutes))
                state.beginRest(at: start, minutes: rule.restMinutes)
                state.shieldEdition = value.edition(for: id, at: start)
                state.cooldownMonitor = release
                state.retiredUsageMonitor = activity.rawValue
                state.monitoringError = nil
                value.sessions.values[id] = state
                try save(value)
                SharedStore.updateShield(value)
                log.notice("shield applied after \(Date().timeIntervalSince(began), privacy: .public)s")
            } catch {
                // No new shield if release registration or persistence failed.
                guard var failed = try? SharedStore.loadProtection() else { return }
                failed.sessions.values[id]?.monitoringError = error.localizedDescription
                _ = SharedStore.persist(failed)
                log.error("break failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    static func finishRest(activity: DeviceActivityName? = nil) {
        let snapshot = SharedStore.protection
        guard !snapshot.sessions.expiredIDs(at: Date(), activity: activity?.rawValue).isEmpty else { return }
        SharedStore.locked {
            guard var value = try? SharedStore.loadProtection() else { return }
            for id in value.sessions.expiredIDs(at: Date(), activity: activity?.rawValue) {
                guard let rule = value.rules.first(where: { $0.id == id }),
                      var state = value.sessions.values[id] else { continue }
                let retired = state.retiredUsageMonitor
                let release = state.cooldownMonitor
                state.finishRest(at: Date())
                state.retiredUsageMonitor = nil
                state.retiredRestMonitor = release
                value.sessions.values[id] = state
                // Recompute the union: another app's active break stays shielded.
                SharedStore.updateShield(value)
                guard SharedStore.persist(value) else { return }
                if let retired { DeviceActivityCenter().stopMonitoring([.init(retired)]) }
                if value.enabled {
                    do { try arm(rule, value: &value) }
                    catch { log.error("rearm failed: \(error.localizedDescription, privacy: .public)") }
                }
            }
        }
    }
    static func sessionIntervalEnded(activity: DeviceActivityName) {}
    enum ConfigurationError: LocalizedError {
        case resting, storage, selection
        var errorDescription: String? {
            switch self {
            case .resting: return Voice(language: SharedStore.language)("An app on a break can’t be removed yet.", "休息中的 App 暂时不能移除。")
            case .storage: return Voice(language: SharedStore.language)("Couldn’t save the timer. Please try again.", "计时保存失败，请再试一次。")
            case .selection: return Voice(language: SharedStore.language)("Choose 1–9 individual apps, not categories or websites.", "请选择 1 到 9 个 App，不选分类或网站。")
            }
        }
    }
    static func configure(_ rule: AppRule) throws { try configure([rule]) }
    static func configure(_ rules: [AppRule]) throws {
        guard rules.count <= maximumApps,
              Set(rules.map(\.id)).count == rules.count,
              Set(rules.map(\.token)).count == rules.count else { throw ConfigurationError.selection }
        if rules.isEmpty {
            let stopped = try SharedStore.locked { () throws -> [DeviceActivityName] in
                var value = try SharedStore.loadProtection()
                guard value.sessions.restingIDs(at: Date()).isEmpty else { throw ConfigurationError.resting }
                let owned = DeviceActivityCenter().activities.filter {
                    $0.rawValue.hasPrefix(prefix) || $0.rawValue.hasPrefix("rest.")
                }
                value.rules = []
                value.sessions = UsageSessions()
                value.enabled = false
                try save(value)
                SharedStore.updateShield(value)
                return owned
            }
            // Cancellation can wake the extension. It must see the empty saved
            // ownership without waiting on our lock, including for retired monitors.
            if !stopped.isEmpty { DeviceActivityCenter().stopMonitoring(stopped) }
            return
        }
        try SharedStore.locked {
            var value = try SharedStore.loadProtection()
            let restingIDs = Set(value.sessions.restingIDs(at: Date()))
            for old in value.rules where restingIDs.contains(old.id) {
                guard let replacement = rules.first(where: { $0.id == old.id }), replacement.token == old.token else { throw ConfigurationError.resting }
            }
            let oldRules = value.rules
            let wasEnabled = value.enabled
            let changed = oldRules.filter { old in
                guard let new = rules.first(where: { $0.id == old.id }) else { return true }
                // The active break owns its original deadline. finishRest arms the saved rule.
                return new.token != old.token || (new.limit != old.limit && !restingIDs.contains(old.id))
            }
            let stopped = changed.flatMap { old -> [DeviceActivityName] in
                let state = value.sessions.values.removeValue(forKey: old.id)
                return [state?.activeMonitor, state?.retiredUsageMonitor, state?.cooldownMonitor, state?.retiredRestMonitor].compactMap { $0.map { DeviceActivityName($0) } }
            }
            value.rules = rules
            value.enabled = true
            try save(value)
            // Ownership was removed before cancellation, so stale callbacks return without locking.
            if !stopped.isEmpty { DeviceActivityCenter().stopMonitoring(stopped) }
            SharedStore.updateShield(value)
            var firstError: Error?
            for rule in rules {
                let state = value.sessions.values[rule.id] ?? SessionState()
                guard !restingIDs.contains(rule.id) else { continue }
                if wasEnabled && state.activeMonitor?.hasPrefix(freshPrefix) == true && state.monitoringError == nil { continue }
                if let stale = state.activeMonitor {
                    value.sessions.values[rule.id]?.activeMonitor = nil
                    try save(value)
                    DeviceActivityCenter().stopMonitoring([.init(stale)])
                }
                do { try arm(rule, value: &value) }
                catch { if firstError == nil { firstError = error } }
            }
            if let firstError { throw firstError }
        }
    }
    static func migrateIfNeeded() {
        SharedStore.locked {
            guard var value = try? SharedStore.loadProtection() else { return }
            _ = SharedStore.persist(value)
            guard value.enabled else { return }
            for rule in value.rules {
                guard var state = value.sessions.values[rule.id], let old = state.activeMonitor,
                      !old.hasPrefix(freshPrefix), !state.isResting(at: Date()) else { continue }
                state.usageRun = nil
                state.retiredUsageMonitor = old
                value.sessions.values[rule.id] = state
                do { try arm(rule, value: &value) }
                catch { log.error("usage migration failed: \(error.localizedDescription, privacy: .public)") }
            }
        }
    }
    static func pauseNewMonitoring() throws {
        try SharedStore.locked {
            var value = try SharedStore.loadProtection()
            var stopped: [DeviceActivityName] = []
            for id in Array(value.sessions.values.keys) {
                guard let state = value.sessions.values[id], state.cooldownUntil == nil else { continue }
                stopped += [state.activeMonitor, state.retiredRestMonitor].compactMap { $0.map { DeviceActivityName($0) } }
                value.sessions.values.removeValue(forKey: id)
            }
            value.enabled = false
            try save(value)
            if !stopped.isEmpty { DeviceActivityCenter().stopMonitoring(stopped) }
        }
    }
    static func disable() {
        SharedStore.locked {
            guard var value = try? SharedStore.loadProtection() else { return }
            guard value.sessions.restingIDs(at: Date()).isEmpty else { return }
            value.enabled = false
            value.sessions = UsageSessions()
            guard SharedStore.persist(value) else { return }
            DeviceActivityCenter().stopMonitoring()
            SharedStore.updateShield(value)
        }
    }
}

// A one-shot handoff from the shield button to either a cold or warm launch.
struct DuckRevealRequest: Codable {
    let edition: Int
    let created: Date
    private static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedStore.group)?
            .appendingPathComponent("duck-reveal.json")
    }
    func enqueue() throws {
        guard let url = Self.url else { throw CocoaError(.fileNoSuchFile) }
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
    static func consume() -> Self? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        try? FileManager.default.removeItem(at: url)
        guard let request = try? JSONDecoder().decode(Self.self, from: data),
              abs(request.created.timeIntervalSinceNow) < 60 else { return nil }
        return request
    }
}

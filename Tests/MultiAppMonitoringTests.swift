import Foundation
import ManagedSettings
import DeviceActivity

@main struct MultiAppMonitoringTests {
    static var checks = 0
    static func expect(_ value: @autoclosure () -> Bool, _ why: String) {
        checks += 1
        if !value() { fatalError("FAIL: " + why) }
    }
    static func current(_ id: String) -> SessionState { SharedStore.protection.sessions.values[id]! }
    static func fire(_ id: String) {
        let name = DeviceActivityName(current(id).activeMonitor!)
        DeviceActivityCenter.delivering = name
        let limit = SharedStore.rules.first { $0.id == id }!.limit
        let now = Date()
        for minute in Monitoring.marks(for: limit) {
            Monitoring.reachedThreshold(event: Monitoring.eventName(minute: minute, limit: limit), activity: name,
                                        at: now.addingTimeInterval(Double(minute - limit) * 60))
        }
        DeviceActivityCenter.delivering = nil
    }
    static func expire(_ id: String) {
        var value = SharedStore.protection
        value.sessions.values[id]?.cooldownUntil = Date().addingTimeInterval(-1)
        SharedStore.persist(value)
        let name = DeviceActivityName(current(id).cooldownMonitor!)
        DeviceActivityCenter.delivering = name
        Monitoring.finishRest(activity: name)
        DeviceActivityCenter.delivering = nil
    }
    static func main() throws {
        let lateStart = Date(timeIntervalSince1970: 1794614340)
        let fullDay = Monitoring.window(start: lateStart, minutes: 1440)
        expect(Calendar.current.date(from: fullDay.start) == lateStart, "release schedule retains absolute start date")
        expect(Calendar.current.date(from: fullDay.end) == lateStart.addingTimeInterval(86400), "24-hour release schedule retains next-day date")
        expect(!fullDay.repeats, "long rest release is one-shot")
        expect(Monitoring.marks(for: 1440).last == 1440, "full-day usage threshold is retained")

        let a = AppRule(id: "A", token: ApplicationToken("rednote"), limit: 2, restMinutes: 5)
        let b = AppRule(id: "B", token: ApplicationToken("instagram"), limit: 5)
        try Monitoring.configure([a, b])
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let migrated = try SharedStore.readProtection(at: file) { SharedStore.protection }
        expect(migrated.enabled && migrated.rules.count == 2, "absent v3 file may migrate legacy data")
        var oldJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(migrated)) as! [String: Any]
        var oldRules = oldJSON["rules"] as! [[String: Any]]
        oldRules[0].removeValue(forKey: "restMinutes")
        oldJSON["rules"] = oldRules
        try JSONSerialization.data(withJSONObject: oldJSON).write(to: file)
        let oldRulesRead = try SharedStore.readProtection(at: file) { fatalError("discarded current file") }
        expect(oldRulesRead.enabled && oldRulesRead.rules[0].restMinutes == 15, "older rule without per-app break retains duty")
        try Data("{".utf8).write(to: file)
        do {
            _ = try SharedStore.readProtection(at: file) { fatalError("invented OFF DUTY during a read failure") }
            fatalError("accepted unreadable state")
        } catch is DecodingError { expect(true, "unreadable current state stays unknown") }
        let originalA = current("A").activeMonitor!
        let originalB = current("B").activeMonitor!
        expect(originalA != originalB, "each app owns a separate monitor")
        let events = DeviceActivityCenter.registrations.values.flatMap { $0.events.values }
        expect(events.count == 7 && events.allSatisfy { $0.applications.count == 1 && !$0.includesPastActivity }, "no pooled token budgets or past-usage leakage")
        expect(Set(events.compactMap { $0.threshold.minute }) == [1, 2, 3, 4, 5], "fresh per-app milestones passed to system")
        let c = AppRule(id: "C", token: ApplicationToken("youtube"), limit: 10)
        try Monitoring.configure([a, b, c])
        expect(current("A").activeMonitor == originalA && current("B").activeMonitor == originalB, "adding app preserves existing counters")
        fire("A")
        expect(SharedStore.shieldStore.shield.applications == [a.token], "A threshold only blocks A")
        expect(current("B").activeMonitor == originalB && !current("B").isResting(at: Date()), "A threshold does not touch B")
        let schedule = DeviceActivityCenter.registrations[DeviceActivityName(current("A").cooldownMonitor!)]!.schedule
        let end = schedule.end.date!
        expect(end.timeIntervalSince(schedule.start.date!) == 900, "five-minute break registers a full fifteen-minute monitoring interval")
        expect(end == current("A").cooldownUntil && (298...302).contains(end.timeIntervalSinceNow), "release deadline is five minutes away")
        let deadlineA = current("A").cooldownUntil
        Monitoring.reachedThreshold(event: Monitoring.threshold, activity: .init(originalA))
        expect(current("A").cooldownUntil == deadlineA, "duplicate threshold cannot extend rest")
        do { try Monitoring.configure([b, c]); fatalError("removed resting A") } catch Monitoring.ConfigurationError.resting {}
        expect(SharedStore.rules.count == 3, "removing resting app is rejected before mutation")
        var editedB = b; editedB.limit = 20
        try Monitoring.configure([a, editedB, c])
        expect(current("A").cooldownUntil == deadlineA, "editing B preserves A rest")
        expect(current("B").activeMonitor != originalB, "only edited B receives new budget")
        Monitoring.reachedThreshold(event: Monitoring.threshold, activity: .init(originalB))
        expect(!current("B").isResting(at: Date()), "stale B callback ignored")
        fire("B")
        expect(SharedStore.shieldStore.shield.applications == [a.token, b.token], "simultaneous rests shield both apps")
        let priorA = current("A")
        let baselineRules = SharedStore.protection
        let originalMonitors = Set(DeviceActivityCenter.registrations.keys)
        let previewNow = Date()
        let expires = try ReminderTrial.start(c, now: previewNow)
        let firstTrial = Set(DeviceActivityCenter.registrations.keys).subtracting(originalMonitors).first!
        expect((60...61).contains(expires.timeIntervalSince(previewNow)), "preview expires after one minute")
        expect(ReminderTrial.store.shield.applications == [c.token] && SharedStore.shieldStore.shield.applications == [a.token,b.token], "preview overlays one app independently")
        _ = try ReminderTrial.start(a)
        let replacementTrial = Set(DeviceActivityCenter.registrations.keys).subtracting(originalMonitors).first!
        expect(ReminderTrial.intervalEnded(firstTrial) && ReminderTrial.store.shield.applications == [a.token], "retired preview callback cannot end a newer preview")
        DeviceActivityCenter.delivering = replacementTrial
        expect(ReminderTrial.intervalEnded(replacementTrial) && ReminderTrial.store.shield.applications == nil, "extension releases the trial without foregrounding")
        DeviceActivityCenter.delivering = nil
        ReminderTrial.cancel()
        expect(Set(DeviceActivityCenter.registrations.keys) == originalMonitors, "preview monitor is cleaned up")
        expect(current("A") == priorA && SharedStore.protection.sessions == baselineRules.sessions && SharedStore.shieldStore.shield.applications == [a.token,b.token], "preview preserves real shields and rule progress")
        DeviceActivityCenter.failNext = true
        do { _ = try ReminderTrial.start(c); fatalError("expected failed trial registration") }
        catch { expect(ReminderTrial.store.shield.applications == nil, "failed preview never shields an app") }
        let beforeEdit = current("A")
        let existingMonitors = Set(DeviceActivityCenter.registrations.keys)
        var nextA = a
        nextA.limit = 10
        try Monitoring.configure([nextA, editedB, c])
        nextA.limit = 5
        try Monitoring.configure([nextA, editedB, c])
        expect(current("A") == beforeEdit && Set(DeviceActivityCenter.registrations.keys) == existingMonitors,
               "edits during a break preserve the deadline and release monitor")
        expect(SharedStore.shieldStore.shield.applications == [a.token, b.token], "editing a future limit leaves both breaks enforced")
        let deadlineB = current("B").cooldownUntil
        expire("A")
        expect(SharedStore.shieldStore.shield.applications == [b.token], "A release cannot release B")
        expect(current("B").cooldownUntil == deadlineB, "A release cannot shorten B timer")
        expect(current("A").activeMonitor != nil, "A rearmed independently")
        let nextEvents = DeviceActivityCenter.registrations[.init(current("A").activeMonitor!)]?.events
        expect(nextEvents?[Monitoring.threshold]?.threshold.minute == 5, "release uses the last saved limit")
        try Monitoring.configure([a, editedB, c])
        Monitoring.disable()
        expect(SharedStore.enabled, "global pause cannot skip B break")
        DeviceActivityCenter.failNext = true
        expire("B")
        expect(SharedStore.shieldStore.shield.applications == nil, "rearm error cannot trap user behind shield")
        expect(current("B").monitoringError != nil, "rearm failure is visible")
        let activeA = current("A").activeMonitor
        try Monitoring.configure([a, editedB, c])
        expect(current("B").monitoringError == nil && current("A").activeMonitor == activeA, "retry failed B without resetting A")
        var editions: [Int] = []
        for _ in 0..<24 {
            fire("A")
            editions.append(current("A").shieldEdition ?? -1)
            expire("A")
        }
        expect(!editions.contains(0), "repeats from the same two apps never trigger the loud duck")
        var moods = ProtectionState()
        moods.rules = [a,b,c]
        let now = Date()
        expect(moods.edition(for: a.id, at: now) == 2, "gentle first break")
        moods.sessions.values[a.id] = SessionState()
        moods.sessions.values[a.id]?.lastInterruptionAt = now
        expect(moods.edition(for: b.id, at: now) == 1, "second distinct app is a raised eyebrow")
        moods.sessions.values[b.id] = SessionState()
        moods.sessions.values[b.id]?.lastInterruptionAt = now.addingTimeInterval(-1800)
        expect(moods.edition(for: c.id, at: now) == 1, "stale app is outside rolling window")
        moods.sessions.values[b.id]?.lastInterruptionAt = now
        expect(moods.edition(for: c.id, at: now) == 0, "third distinct app unlocks the theatrical pose")
        expect(moods.edition(for: c.id, at: now) == 1, "the loud pose rests for four hours")
        expect(moods.edition(for: c.id, at: now.addingTimeInterval(14400)) == 2, "a quiet period restores the relaxed duck")
        expect(DeviceActivityCenter.registrations.count <= 6, "repeated cycles clean old monitors")
        expect(!DeviceActivityCenter.cancelledOwnCallback, "never cancels the monitor delivering a callback")
        let encoded = try JSONEncoder().encode(SharedStore.protection)
        let restored = try JSONDecoder().decode(ProtectionState.self, from: encoded)
        expect(restored.sessions == SharedStore.protection.sessions && restored.rules.count == 3, "per-app ownership survives restart")
        let oldC = current("C").activeMonitor!
        try Monitoring.configure([a, editedB])
        expect(SharedStore.protection.sessions.values["C"] == nil, "removing C deletes only C state")
        Monitoring.reachedThreshold(event: Monitoring.threshold, activity: .init(oldC))
        expect(SharedStore.shieldStore.shield.applications == nil, "removed-app callback cannot block anything")
        DeviceActivityCenter.failNext = true
        fire("A")
        expect(SharedStore.shieldStore.shield.applications == nil, "failed release registration never applies shield")
        Monitoring.disable()
        expect(!SharedStore.enabled && DeviceActivityCenter.registrations.isEmpty, "pause cleans inactive protection")
        let nine = (0..<9).map { AppRule(id: "rule-\($0)", token: ApplicationToken("app-\($0)"), limit: 2 + $0) }
        try Monitoring.configure(nine)
        for rule in nine { fire(rule.id) }
        expect(SharedStore.shieldStore.shield.applications?.count == 9, "nine simultaneous breaks fit system monitor budget")
        for rule in nine { expire(rule.id) }
        for rule in nine { fire(rule.id); expire(rule.id) }
        expect(DeviceActivityCenter.registrations.count <= 18, "nine rules continue across repeated cycles without monitor leakage")
        expect(!DeviceActivityCenter.cancelledOwnCallback, "capacity cleanup never cancels own callback")
        Monitoring.disable()
        try Monitoring.configure([a, b])
        fire("A")
        let originalDeadline = current("A").cooldownUntil
        var longer = a
        longer.restMinutes = 30
        try Monitoring.configure([longer, b])
        expect(current("A").cooldownUntil == originalDeadline, "changing next break preserves current deadline")
        try Monitoring.pauseNewMonitoring()
        expect(!SharedStore.enabled && SharedStore.shieldStore.shield.applications == [a.token], "off duty preserves active shield")
        expire("A")
        expect(current("A").activeMonitor == nil && SharedStore.shieldStore.shield.applications == nil, "paused break releases without rearming")
        try Monitoring.configure([a,b])
        let five = current("B").activeMonitor!
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(6 * 3600)
        func report(_ name: String, _ minute: Int, _ time: TimeInterval) {
            DeviceActivityCenter.delivering = .init(name)
            Monitoring.reachedThreshold(event: Monitoring.eventName(minute: minute, limit: 5), activity: .init(name),
                                        at: start.addingTimeInterval(time))
            DeviceActivityCenter.delivering = nil
        }
        for m in 1...4 { report(five, m, Double(m * 60)) }
        let other = current("A").activeMonitor
        report(five, 5, 4 * 60 + 6 * 3600 + 60)
        expect(current("B").cooldownUntil == nil && current("B").usageRun?.minutes == 1, "four minutes then six hours away then one minute: one fresh minute, no break")
        expect(current("A").activeMonitor == other && current("A").usageRun == nil, "a voluntary break only resets its own app")
        let renewed = current("B").activeMonitor!
        expect(renewed != five, "an exhausted system counter rolls to a fresh generation")
        report(five, 5, 22000)
        expect(current("B").usageRun?.minutes == 1, "late old-generation callbacks ignored")
        for m in 1...4 { report(renewed, m, 4 * 60 + 6 * 3600 + 60 + Double(m * 60)) }
        expect(current("B").cooldownUntil != nil, "four more minutes after returning complete a fresh five")
        expect(!DeviceActivityCenter.cancelledOwnCallback, "rollover never cancels its own callback")
        var run = UsageRun()
        for m in 1...4 { _ = run.record(mark: m, at: start.addingTimeInterval(Double(m * 60)), breakMinutes: 15) }
        _ = run.record(mark: 5, at: start.addingTimeInterval(5 * 60 + 60), breakMinutes: 15)
        expect(run.minutes == 5, "a one-minute interruption still accumulates")
        var edge = UsageRun()
        _ = edge.record(mark: 1, at: start, breakMinutes: 15)
        _ = edge.record(mark: 2, at: start.addingTimeInterval(16 * 60), breakMinutes: 15)
        expect(edge.minutes == 1, "a complete voluntary 15-minute rest clears the previous use")
        for m in 3...5 { _ = edge.record(mark: m, at: start.addingTimeInterval(16 * 60), breakMinutes: 15) }
        expect(edge.minutes == 1, "batch delivery cannot instantly charge several minutes")
        _ = edge.record(mark: 2, at: start.addingTimeInterval(18 * 60), breakMinutes: 15)
        expect(edge.lastMark == 5, "out-of-order markers cannot rewind evidence")
        _ = edge.record(mark: 1, at: start.addingTimeInterval(86400), breakMinutes: 15)
        expect(edge.lastMark == 1 && edge.minutes == 1, "new daily interval resets the local counter")
        var old = SharedStore.protection
        old.sessions.values["A"]?.activeMonitor = "usage.legacy"
        SharedStore.persist(old)
        let existingEnd = current("B").cooldownUntil
        Monitoring.migrateIfNeeded()
        expect(current("A").activeMonitor != "usage.legacy" && current("B").cooldownUntil == existingEnd,
               "upgrade starts fresh for legacy use while preserving an enforced break")
        fire("A")
        let enforcedEnd = current("A").cooldownUntil
        let beforeClear = SharedStore.protection
        let beforeClearMonitors = Set(DeviceActivityCenter.registrations.keys)
        do { try Monitoring.configure([]); fatalError("cleared an enforced break") }
        catch Monitoring.ConfigurationError.resting {}
        expect(current("A").cooldownUntil == enforcedEnd && current("A").isResting(at: Date()) && SharedStore.rules.count == 2 &&
               Set(DeviceActivityCenter.registrations.keys) == beforeClearMonitors,
               "clear-all during a mandatory break is rejected without changing rules or release")
        expire("A")
        Monitoring.finishRest()
        let discardedMonitors = Set(DeviceActivityCenter.registrations.keys)
        try Monitoring.configure([])
        expect(SharedStore.rules.isEmpty && !SharedStore.enabled && SharedStore.protection.sessions.values.isEmpty,
               "clearing the final apps persists an empty disabled configuration")
        expect(DeviceActivityCenter.registrations.isEmpty && SharedStore.shieldStore.shield.applications == nil,
               "clear-all cancels old monitors and clears stale shielding")
        try JSONEncoder().encode(SharedStore.protection).write(to: file)
        let emptyOnRestart = try SharedStore.readProtection(at: file) { beforeClear }
        expect(emptyOnRestart.rules.isEmpty && !emptyOnRestart.enabled,
               "an intentionally empty saved list survives restart without reviving legacy apps")
        for monitor in discardedMonitors {
            Monitoring.reachedThreshold(event: Monitoring.threshold, activity: monitor)
            Monitoring.finishRest(activity: monitor)
        }
        expect(SharedStore.rules.isEmpty && SharedStore.shieldStore.shield.applications == nil && DeviceActivityCenter.registrations.isEmpty,
               "late callbacks from cleared apps cannot restore a rule or a shield")
        try Monitoring.configure([a])
        expect(SharedStore.enabled && SharedStore.rules.count == 1 && current("A").activeMonitor != nil,
               "apps can be selected and monitored again after clearing everything")
        Monitoring.disable()
        print("PASS: \(checks) multi-app checks against production Monitoring with fake system delivery")
    }
}

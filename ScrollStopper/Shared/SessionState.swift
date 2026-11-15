import Foundation

/// Automations define session boundaries; Screen Time confirms usage checkpoints.
struct SessionState: Codable, Equatable {
    var openedAt: Date?
    var closedAt: Date?
    var usedSeconds: TimeInterval = 0
    var confirmedSeconds: TimeInterval = 0
    var monitorBaselineSeconds: TimeInterval?
    var cooldownUntil: Date?
    var activeMonitor: String?
    var cooldownMonitor: String?
    var retiredUsageMonitor: String?
    var retiredRestMonitor: String?
    var usageRun: UsageRun?
    var shieldEdition: Int?
    var dailyBreakDates: [Date]?
    var interruptions = 0
    var lastInterruptionAt: Date?
    var lastOpenedSignal: Date?
    var lastClosedSignal: Date?
    var monitoringError: String?
    var targetIsOpen = false

    static let resetGap: TimeInterval = 60
    func isResting(at now: Date) -> Bool { cooldownUntil.map { $0 > now } ?? false }
    func remaining(limit: Int) -> TimeInterval {
        max(0, TimeInterval(limit * 60) - usedSeconds - confirmedSeconds)
    }
    mutating func open(at now: Date) {
        lastOpenedSignal = now
        targetIsOpen = true
        guard !isResting(at: now), openedAt == nil else { return }
        if let closedAt, now.timeIntervalSince(closedAt) >= Self.resetGap {
            usedSeconds = 0
            activeMonitor = nil
            monitorBaselineSeconds = nil
        }
        if cooldownUntil != nil { usedSeconds = 0; cooldownUntil = nil }
        openedAt = now
        confirmedSeconds = 0
        closedAt = nil
    }
    mutating func confirmUsage(_ seconds: TimeInterval) {
        guard openedAt != nil || activeMonitor != nil else { return }
        let total = (monitorBaselineSeconds ?? 0) + max(0, seconds)
        if openedAt != nil {
            confirmedSeconds = max(confirmedSeconds, max(0, total - usedSeconds))
        } else {
            usedSeconds = max(usedSeconds, total)
        }
    }
    func acceptsUsageEvent(from monitor: String, at now: Date) -> Bool {
        guard activeMonitor == monitor, !isResting(at: now) else { return false }
        if openedAt != nil { return true }
        return closedAt.map { now.timeIntervalSince($0) < Self.resetGap } ?? false
    }
    mutating func close(at now: Date) {
        lastClosedSignal = now
        let wasOpen = targetIsOpen || openedAt != nil
        targetIsOpen = false
        // Only carry Screen Time-confirmed usage. A lock screen or missed close
        // signal must never be charged as hours of foreground scrolling.
        if openedAt != nil { usedSeconds += confirmedSeconds }
        confirmedSeconds = 0
        openedAt = nil
        if wasOpen || closedAt == nil { closedAt = now }
        // Keep the same system event through brief switches. Stopping here
        // loses fractional usage on every visit shorter than a checkpoint.
    }
    mutating func beginRest(at now: Date, minutes: Int) {
        dailyBreakDates = (dailyBreakDates ?? []).filter { Calendar.current.isDate($0, inSameDayAs: now) } + [now]
        cooldownUntil = now.addingTimeInterval(TimeInterval(minutes * 60))
        openedAt = nil
        usedSeconds = 0
        confirmedSeconds = 0
        monitorBaselineSeconds = nil
        activeMonitor = nil
        if let lastInterruptionAt, now.timeIntervalSince(lastInterruptionAt) < 4 * 60 * 60,
           Calendar.current.isDate(lastInterruptionAt, inSameDayAs: now) {
            interruptions += 1
        } else { interruptions = 1 }
        lastInterruptionAt = now
    }
    mutating func finishRest(at now: Date) {
        guard let end = cooldownUntil, now >= end else { return }
        cooldownUntil = nil
        cooldownMonitor = nil
        usedSeconds = 0
        confirmedSeconds = 0
        monitorBaselineSeconds = nil
        openedAt = nil
        closedAt = now
    }
}

/// Rule IDs own their timers. No app may consume or release another app's budget.
struct UsageSessions: Codable, Equatable {
    var values: [String: SessionState] = [:]
    func usageOwner(_ activity: String, at now: Date) -> String? {
        values.first { $0.value.activeMonitor == activity && !$0.value.isResting(at: now) }?.key
    }
    func restingIDs(at now: Date) -> [String] {
        values.filter { $0.value.isResting(at: now) }.sorted {
            ($0.value.cooldownUntil ?? now) < ($1.value.cooldownUntil ?? now)
        }.map(\.key)
    }
    func expiredIDs(at now: Date, activity: String? = nil) -> [String] {
        values.filter { _, state in
            guard let end = state.cooldownUntil, end <= now else { return false }
            return activity == nil || state.cooldownMonitor == activity
        }.map(\.key)
    }
}


// Screen Time reports cumulative milestones, without foreground or exit timestamps.
// Count new measured minutes, forgiving an old run when the delivery gap contains
// a full rest beyond the measured use. Delayed bursts alone cannot prove a run.
struct UsageRun: Codable, Equatable {
    var lastMark = 0
    var minutes = 0
    var lastDelivery: Date?
    var earliestUse: Date?

    mutating func record(mark: Int, at now: Date, breakMinutes: Int) -> Bool {
        if let lastDelivery, !Calendar.current.isDate(now, inSameDayAs: lastDelivery) || now < lastDelivery {
            self = UsageRun()
        }
        guard mark > lastMark else { return false }
        let delta = mark - lastMark
        let elapsed = lastDelivery.map { now.timeIntervalSince($0) }
        let measured = Double(delta) * 60
        let quiet = elapsed.map { $0 - measured >= Double(breakMinutes) * 60 - 2 } ?? true
        if quiet || earliestUse == nil {
            // On return, credit at most the latest minute, even for a late batch.
            minutes = 1
            earliestUse = now.addingTimeInterval(-60)
        } else if let earliestUse {
            let plausible = Int((now.timeIntervalSince(earliestUse) + 2) / 60)
            minutes = min(minutes + delta, plausible)
        }
        lastMark = mark
        lastDelivery = now
        return true
    }
}

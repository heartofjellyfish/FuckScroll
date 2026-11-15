#if DEBUG
import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings

/// Observes system delivery timing only. Never infers that callbacks are
/// foreground-app transitions, and never applies a shield.
enum UsageProbe {
    struct Entry: Codable {
        let time: Date
        let kind: String
        let activity: String
        let usageSeconds: Int?
    }
    static let prefix = "probe.usage."
    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedStore.group)?
            .appendingPathComponent("usage-probe.json")
    }
    static var entries: [Entry] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }
    static func exportSnapshot() {
        guard let url, let data = try? Data(contentsOf: url),
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        try? data.write(to: documents.appendingPathComponent("usage-probe-export.json"), options: .atomic)
    }
    static func record(_ kind: String, activity: String = "", seconds: Int? = nil) {
        SharedStore.locked {
            guard let url else { return }
            let updated = Array((entries + [Entry(time: Date(), kind: kind, activity: activity, usageSeconds: seconds)]).suffix(500))
            if let data = try? JSONEncoder().encode(updated) { try? data.write(to: url, options: .atomic) }
        }
    }
    static func start(token: ApplicationToken) throws {
        guard !SharedStore.session.isResting(at: Date()) else { throw Monitoring.ConfigurationError.resting }
        // Disable the old intent-driven engine so a previously created test
        // automation cannot contaminate this experiment.
        Monitoring.disable()
        stop()
        if let url { try Data("[]".utf8).write(to: url, options: .atomic) }
        let name = DeviceActivityName(prefix + UUID().uuidString)
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        // First establish basic delivery with explicit minute components and
        // only two events. This experiment does not classify continuity.
        for minutes in [1, 2] {
            let seconds = minutes * 60
            events[.init("seconds.\(seconds)")] = DeviceActivityEvent(
                applications: [token], threshold: DateComponents(minute: minutes), includesPastActivity: false)
        }
        record("register", activity: name.rawValue)
        do {
            try DeviceActivityCenter().startMonitoring(name, during: Monitoring.window(start: Date(), minutes: 30), events: events)
            record("armed", activity: name.rawValue)
        } catch {
            record("registration-error: \(error.localizedDescription)", activity: name.rawValue)
            throw error
        }
    }
    static func stop() {
        let names = DeviceActivityCenter().activities.filter { $0.rawValue.hasPrefix(prefix) }
        DeviceActivityCenter().stopMonitoring(names)
        if !names.isEmpty { record("stopped") }
    }
    static func event(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) -> Bool {
        guard activity.rawValue.hasPrefix(prefix) else { return false }
        record("threshold", activity: activity.rawValue, seconds: Int(event.rawValue.replacingOccurrences(of: "seconds.", with: "")))
        return true
    }
}
#endif

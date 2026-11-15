import Foundation
import DeviceActivity
import ManagedSettings

/// Only the preview shield lives in this store. Real usage timers and breaks
/// keep their original ownership, including when both shield the same app.
enum ReminderTrial {
    private static let prefix = "reminder.preview."
    static var store: ManagedSettingsStore { ManagedSettingsStore(named: .init("scrollstopper.preview")) }
    private static var marker: URL? {
        #if MONITOR_TESTS
        return FileManager.default.temporaryDirectory.appendingPathComponent("duck-preview-test-" + String(ProcessInfo.processInfo.processIdentifier))
        #else
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedStore.group)?
            .appendingPathComponent("preview-owner")
        #endif
    }

    @discardableResult static func start(_ rule: AppRule, now: Date = Date()) throws -> Date {
        guard let marker else { throw Monitoring.ConfigurationError.storage }
        let name = prefix + UUID().uuidString
        let deadline = Date(timeIntervalSince1970: ceil(now.timeIntervalSince1970) + 60)
        let old: String? = try SharedStore.locked {
            guard try SharedStore.loadProtection().rules.contains(where: { $0.id == rule.id && $0.token == rule.token }) else {
                throw Monitoring.ConfigurationError.selection
            }
            let previous = try? String(contentsOf: marker, encoding: .utf8)
            try name.write(to: marker, atomically: true, encoding: .utf8)
            if previous != nil { store.clearAllSettings() }
            return previous
        }
        // start/stopMonitoring can synchronously wake the extension. Never
        // hold its shared lock while waiting for the Screen Time daemon.
        let center = DeviceActivityCenter()
        if let old { center.stopMonitoring([.init(old)]) }
        do {
            try center.startMonitoring(.init(name), during: Monitoring.window(start: deadline.addingTimeInterval(-900), minutes: 15))
            let armed = SharedStore.locked {
                guard (try? String(contentsOf: marker, encoding: .utf8)) == name, Date() < deadline else { return false }
                store.shield.applications = [rule.token]
                return true
            }
            if !armed {
                center.stopMonitoring([.init(name)])
                throw CocoaError(.userCancelled)
            }
            return deadline
        } catch {
            SharedStore.locked {
                if (try? String(contentsOf: marker, encoding: .utf8)) == name {
                    try? FileManager.default.removeItem(at: marker)
                }
            }
            throw error
        }
    }

    static func cancel() {
        guard let marker, FileManager.default.fileExists(atPath: marker.path) else { return }
        let owner: String? = SharedStore.locked {
            guard let name = try? String(contentsOf: marker, encoding: .utf8) else { return nil }
            store.clearAllSettings()
            try? FileManager.default.removeItem(at: marker)
            return name
        }
        guard let owner else { return }
        #if MONITOR_TESTS
        DeviceActivityCenter().stopMonitoring([.init(owner)])
        #else
        DispatchQueue.global(qos: .utility).async { DeviceActivityCenter().stopMonitoring([.init(owner)]) }
        #endif
    }

    static func intervalEnded(_ activity: DeviceActivityName) -> Bool {
        guard activity.rawValue.hasPrefix(prefix) else { return false }
        SharedStore.locked {
            guard let marker, let owner = try? String(contentsOf: marker, encoding: .utf8),
                  owner == activity.rawValue else { return }
            store.clearAllSettings()
            // Keep the ID until the next foreground cleanup. Never cancel a
            // DeviceActivity registration from inside its own callback.
        }
        return true
    }
}

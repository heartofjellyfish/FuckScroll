import Foundation
import ManagedSettings
public struct DeviceActivityName: Hashable { public let rawValue: String; public init(_ value: String) { rawValue = value } }
public struct DeviceActivitySchedule {
    public let start, end: DateComponents
    public let repeats: Bool
    public init(intervalStart: DateComponents, intervalEnd: DateComponents, repeats: Bool) { self.start = intervalStart; self.end = intervalEnd; self.repeats = repeats }
}
public struct DeviceActivityEvent {
    public struct Name: Hashable { public let rawValue: String; public init(_ value: String) { rawValue = value } }
    public let applications: Set<ApplicationToken>
    public let threshold: DateComponents
    public let includesPastActivity: Bool
    public init(applications: Set<ApplicationToken>, threshold: DateComponents, includesPastActivity: Bool) {
        self.applications = applications; self.threshold = threshold; self.includesPastActivity = includesPastActivity
    }
}
public final class DeviceActivityCenter {
    public struct Registration { public let schedule: DeviceActivitySchedule; public let events: [DeviceActivityEvent.Name: DeviceActivityEvent] }
    public static var registrations: [DeviceActivityName: Registration] = [:]
    public static var stopped: [DeviceActivityName] = []
    public static var failNext = false
    public static var delivering: DeviceActivityName?
    public static var cancelledOwnCallback = false
    public enum Failure: Error { case injected, excessive }
    public init() {}
    public var activities: [DeviceActivityName] { Array(Self.registrations.keys) }
    public func startMonitoring(_ name: DeviceActivityName, during schedule: DeviceActivitySchedule, events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]) throws {
        if Self.failNext { Self.failNext = false; throw Failure.injected }
        guard Self.registrations.count < 20 else { throw Failure.excessive }
        Self.registrations[name] = Registration(schedule: schedule, events: events)
    }
    public func stopMonitoring(_ names: [DeviceActivityName]? = nil) {
        for name in names ?? Array(Self.registrations.keys) {
            if Self.delivering == name { Self.cancelledOwnCallback = true }
            Self.registrations.removeValue(forKey: name); Self.stopped.append(name)
        }
    }
}

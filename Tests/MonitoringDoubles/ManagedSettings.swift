import Foundation
public struct ApplicationToken: Codable, Hashable { public let value: String; public init(_ value: String) { self.value = value } }
public final class ShieldSettings { public var applications: Set<ApplicationToken>? }
public final class ManagedSettingsStore {
    public struct Name: Hashable { public let value: String; public init(_ value: String) { self.value = value } }
    public static var containers: [Name: ShieldSettings] = [:]
    public let shield: ShieldSettings
    public init(named name: Name) {
        if let old = Self.containers[name] { shield = old }
        else { let new = ShieldSettings(); Self.containers[name] = new; shield = new }
    }
    public func clearAllSettings() { shield.applications = nil }
}

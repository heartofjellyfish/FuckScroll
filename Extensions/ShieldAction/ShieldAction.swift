import ManagedSettings
import Foundation

final class ShieldAction: ShieldActionDelegate {
    override func handle(action: ManagedSettings.ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        if #available(iOS 26.5, *), action == .primaryButtonPressed {
            let value = SharedStore.protection
            let session = value.rules.first { $0.token == application }.flatMap { value.sessions.values[$0.id] }
            // An old rotating edition is not evidence of a recent three-app streak.
            let raw = session?.shieldEdition ?? 2
            let edition = raw == 0 && (value.lastEmphaticBreak == nil || value.lastEmphaticBreak != session?.lastInterruptionAt) ? 2 : raw
            do {
                try DuckRevealRequest(edition: edition, created: Date()).enqueue()
                completionHandler(.openParentalControlsApp)
                return
            } catch { /* A failed handoff still lets the user leave the blocked app. */ }
        }
        completionHandler(.close)
    }
}

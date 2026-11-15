import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfiguration: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ManagedSettingsUI.ShieldConfiguration {
        let voice = Voice(language: SharedStore.language)
        return ManagedSettingsUI.ShieldConfiguration(
            backgroundBlurStyle: nil, backgroundColor: BreakScreen.background,
            icon: UIImage(named: BreakScreen.eye),
            title: .init(text: SharedStore.reminderTitle(voice), color: BreakScreen.titleInk),
            // Omitting the subtitle lets Screen Time insert its restriction message.
            subtitle: .init(text: "\u{00A0}", color: .clear),
            primaryButtonLabel: .init(text: SharedStore.actionTitle(voice), color: BreakScreen.actionInk),
            primaryButtonBackgroundColor: BreakScreen.actionBackground,
            secondaryButtonLabel: nil)
    }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ManagedSettingsUI.ShieldConfiguration {
        configuration(shielding: application)
    }
}

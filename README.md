# Scroll Stopper

A small duck. A hard stop.

Native SwiftUI iPhone app, built from Qi’s grumpy-duck reference. Warm ivory paper, dense black type, hand-drawn ink illustrations, and a small amount of yellow. English first, with an in-app Chinese language option. No account, network client, ads, analytics, streaks, or reward economy.

## What this version does

- Select **one individual app** with Apple’s privacy-preserving picker.
- Choose a session limit of 10, 15, 20, 30, 45, or 60 minutes.
- Connect **two Shortcuts personal automations** for that same app: App Opened and App Closed, both set to Run Immediately.
- Screen Time tracks actual usage during the session. Shortcuts supplies session boundaries.
- Leaving for at least one minute resets an unfinished session. Brief switches reuse the same Screen Time event so its fractional usage can accumulate across visits. Delivered checkpoints remain minute-granular, and callback latency remains OS-controlled; this behavior still needs physical-device validation.
- At the threshold, apply a system shield and start a mandatory 15-, 20-, or 30-minute break. There is **no in-app snooze or early-unlock action**.
- After the break, the system monitor releases the shield. Returning to Scroll Stopper also reconciles an expired break if iOS delayed the callback.
- The duck escalates from dry to irritated to furious on repeated interruptions, then calms down after a long absence or a new day.

This is **session-based, not a daily usage cap**. It measures app use, not actual finger-scrolling. The app cannot inspect which application the user selects in a Shortcuts automation, so the guide asks them to match both automations to the app selected in Scroll Stopper.

## Current validation status

The native app and all three Screen Time extensions compile; the app itself runs in the iPhone simulator. Native XCTest tap-through journeys run on both large and small iPhone simulators. The pure session-state tests and virtual-time user scenarios pass. Actual system shielding, automation delivery, lock/unlock behavior, and release timing still require a signed physical-device run; simulator previews are not evidence that these work end to end.

**November 4 update:** the full signed app and three extensions installed successfully on the paired iPhone 14 Pro. The app subsequently launched successfully; Screen Time setup and real intervention testing are still pending.

Historical: a signing attempt on 2026-10-16 failed with **“No Accounts”** and missing development provisioning profiles. The existing team ID from the Metronome project is configured, but Xcode needs the account signed in. No App Store or TestFlight submission has been made.

## Run in Xcode

1. Open `ScrollStopper.xcodeproj` in Xcode 26.6 or newer (the code conditionally uses an iOS 26.5 shield response).
2. Select the `ScrollStopper` scheme and an iPhone simulator. Run. Minimum deployment target is iOS 17.4.
3. On a physical device, sign in under Xcode → Settings → Accounts. Choose the developer team for all four targets and allow Xcode to manage signing.
4. Confirm Family Controls and the shared App Group are present in **all four** targets.
5. Install on the iPhone, allow Screen Time, select one app, then follow the two-automation guide.

Bundle IDs:

- `com.heartofjellyfish.scrollstopper`
- `com.heartofjellyfish.scrollstopper.monitor`
- `com.heartofjellyfish.scrollstopper.shield`
- `com.heartofjellyfish.scrollstopper.action`

App Group: `group.com.heartofjellyfish.scrollstopper`

The generated project defaults to Qi’s existing development team (`47C4WT5UPR`). Override `DEVELOPMENT_TEAM` when building with another team. Public distribution requires Apple’s Family Controls distribution entitlement approval for the app and its extensions; development signing and distribution approval are different steps.

## Reproduce the project and checks

No third-party packages are required.

```sh
python3 Scripts/generate_project.py
bash Scripts/test.sh
xcodebuild -project ScrollStopper.xcodeproj -scheme ScrollStopper \
  -configuration Debug -sdk iphonesimulator \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build
```

Debug-only launch arguments support visual QA: `--welcome`, `--home`, `--setup`, `--settings`, `--preview`, `--preview --rage`, `--preview --alternatives`, `--preview --goodbye`, and `--zh`. They do not fake Screen Time authorization or install restrictions. `--rehearsal-rest` supplies a clearly labeled, in-memory simulated break for UI tests; `--short-rest` shortens only that fixture to eight seconds. Release builds cannot enter this mode.

## Project map

- `ScrollStopper/App/`: SwiftUI screens, styling, app model, two App Intents.
- `ScrollStopper/Shared/`: session state, bilingual voice, app-group persistence, and monitor orchestration.
- `Extensions/`: Device Activity Monitor, Shield Configuration, Shield Action.
- `Tests/SessionPolicyTests.swift`: executable Foundation-only state-machine checks.
- `Tests/SessionScenarioTests.swift`: virtual-time scrolling, short switching, rest, restart and repeated-interruption scenarios.
- `Tests/UI/`: native XCTest taps and assertions, including Chinese and accessibility text. Run with the scheme’s Test action.
- `Documentation/SELF-TEST.md`: user-perspective findings, fixes, and the boundary between simulation and physical-device evidence.
- `Documentation/DEVICE-VALIDATION.md`: physical-device acceptance checklist and known limits.
- `Design/`: source icon, generation prompts, simulator screenshots, and visual review sheet.

## Platform boundaries

The full-screen illustrated interruption is an **in-app experience and labeled preview**. The actual overlay on another app uses Apple’s `ShieldConfiguration` layout, which accepts an icon, text, colors, and buttons—not arbitrary SwiftUI composition.

On iOS 26.5+, the secondary shield action requests `openParentalControlsApp`. Earlier systems show only the close action; users can open Scroll Stopper manually. This newer response also needs physical-device validation.

Individual authorization does not make this uninstall-proof: the user can revoke Screen Time permission or delete the app through iOS. No claim of tamper-proof enforcement is made.

References: [Screen Time frameworks](https://developer.apple.com/documentation/screentimeapidocumentation/), [Family Controls configuration](https://developer.apple.com/documentation/xcode/configuring-family-controls), [Shortcuts personal automation](https://support.apple.com/en-ie/guide/shortcuts/apd690170742/9.0/ios/26), [Shield configuration](https://developer.apple.com/documentation/managedsettingsui/shieldconfiguration).

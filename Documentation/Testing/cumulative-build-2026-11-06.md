# Cumulative-use test build — November 6, 2026

User explicitly authorized the simpler cumulative-use version for personal testing.

## Implemented

- One app, minute-based Screen Time usage threshold; no manual start per visit and no Shortcuts.
- Eight limits from 2 to 60 minutes; mandatory rest 15/20/30 minutes.
- Daily repeating monitoring schedule. Visits accumulate; budget resets at midnight or after a completed break.
- Fresh monitor identifier on every new cycle, with includesPastActivity false. Only the current identifier and the enough event can start a rest.
- Rest expiry is registered before shielding. Persistent deadline prevents in-app skip; expired shield clears even when next monitor registration fails. App foreground and shield actions also reconcile expired breaks.
- Legacy automation intents intentionally do nothing. Legacy guides removed from the product UI.
- Quick-test launch opens normal setup with 2 minutes selected; user saves to start enforcement.

## Validation / installation

Signed device build succeeded. Existing 30 policy checks, 10 legacy session scenarios, extension metadata/assets/privacy validation passed. The legacy session scenarios are regression checks only; they do not validate the new cumulative scheduler or real Screen Time callbacks.

Installed via CoreDevice on Qi's iPhone (com.heartofjellyfish.scrollstopper) and launched with --quick-test successfully, approximately 12:24 Pacific. Installation identifier: E0E280D5-3C74-496C-B0C4-0FC99220BCDD.

Initial simulator run was interrupted because another app's UI interfered. Re-running the three relevant UI flows on dedicated simulator CA7450D4-2E2C-4983-8049-6C3772E7E6FC; results appended below.

## User device acceptance

Save selected rednote with 2-minute usage / 15-minute rest. Use rednote on the physical screen and verify shield; verify reopening cannot skip rest; verify automatic release and a second usage cycle. Check separate short visits add up. No successful real-device enforcement is claimed until observed.

Dedicated simulator: all three selected UI tests passed (0 failures): cumulative setup with no Shortcuts, mandatory break cannot be paused/edited, and live expiry restoring editability. Completed at approximately 12:26:48 Pacific. Log: /private/tmp/scrollstopper-cumulative-isolated-tests.log. This verifies UI behavior with a simulated break, not actual system enforcement.

## First actual phone feedback and hotfix

Qi reports the shield appeared within the configured usage limit. This establishes the first observed cumulative-use intervention on the physical phone. Qi also reports approximately 30 seconds of apparent phone unresponsiveness, recovering spontaneously. Screenshots IMG_5182/5183 show dark background with near-black text and a contrasting rectangular outer background in the app switcher. No successful automatic rest expiry or second cycle has yet been reported.

Hotfix: remove synchronous cancellation of the usage monitor from its own threshold callback; retain its name and retire it at rest expiry instead. Do not stop a rest monitor from its own interval-end callback. ShieldAction now immediately calls its completion handler, without taking the shared lock or calling DeviceActivity. Unrelated interval-end callbacks and unexpired-rest reconciliation return before taking the cross-process lock. Add OSLog timings around rest registration and shield application. These address plausible blocking paths; no captured hang stack establishes causation.

Shield configuration now explicitly selects systemMaterialLight with warm paper tint, dark text, a dark primary button, and a short single-line heading. Previously blur was nil; Apple documents backgroundColor as a color for the background blur effect (https://developer.apple.com/documentation/managedsettingsui/shieldconfiguration/backgroundblurstyle). This is a proposed fix for the screenshot's mismatch; actual iOS rendering and app-switcher clipping must be checked on the phone. System-owned shield layout is not reproduced by our SwiftUI simulator screens.

Signed build and existing policy/scenario/metadata checks pass after the hotfix. Prior UI tests remain applicable to unchanged product flows; they do not establish absence of a system hang.

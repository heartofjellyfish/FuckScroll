# Build and validation status

## Update — November 4, 2026

The signing blocker below is resolved. The **full duck app** and all three extensions built with development signing and installed successfully on the paired iPhone 14 Pro. All four signed targets include Family Controls and the shared App Group. The initial launch was rejected because the iPhone was locked; a subsequent launch succeeded, confirmed by devicectl. Screen Time authorization, automation setup, and actual blocking remain unverified. Evidence: `Testing/device-installation-2026-11-04.json`. The October audit below is historical.

2026-10-16, America/Los_Angeles. Xcode 26.6 (17F113), iOS 26.5 SDK.

## Verified

- Native XCTest: 3 rounds, 30 successful executions across 11 distinct journeys (8 on iPhone 17 Pro, 11 on iPhone SE, then 11 on the final iPhone 17 Pro build). Includes English, Chinese, accessibility text, dismissal, mandatory-rest controls, and automatic expiry. See `SELF-TEST.md` and `Testing/native-ui-results.json`. These tests do not install actual system restrictions.

- Comic v2: oversized ink close-ups, expressive rage panel and exhausted exit pose are integrated into native views. Final Debug and unsigned Release builds pass. New assets and shared shield thumbnails pass resource validation. iPhone SE renders were rechecked; decorative art shrinks for accessibility text sizes. Screen Time behavior and signing status below are unchanged.

- Debug build for iOS Simulator: **BUILD SUCCEEDED** (app and all three extensions).
- Release build for generic physical iOS, `CODE_SIGNING_ALLOWED=NO`: **BUILD SUCCEEDED**. This verifies compilation, **not installation or valid device signing**.
- 30 executable Foundation session-policy checks pass: actual usage carry-over, the one-minute reset boundary, duplicate open/close signals, out-of-order progress, safe late/stale progress handling, retained counters across short switches, mandatory rest, serialization round trips, midnight, long-absence mood reset, and safe configuration defaults.
- Extension point identifiers, principal classes, shared App Group entitlements, asset references, and privacy manifest checks pass.
- Both BeginScrollSession and EndScrollSession are present in the compiled App Intents metadata.
- Native simulator renders inspected on iPhone 17 Pro / iOS 26.5 and iPhone SE 3 / iOS 18.2, including English and Chinese. Small-screen layout was adjusted to keep primary actions visible at the default text size.
- An accessibility-large text render was checked; decorative overlapping side notes are omitted at accessibility sizes. Longer content remains scrollable. VoiceOver and scrolling interaction still require hands-on verification.
- Ten virtual-time user scenarios pass, including the regression for repeated 59-second visits. These inject cumulative activity data and do not validate OS delivery.
- Review images are composed from actual simulator screenshots. No app UI was drawn into the screenshots afterward.

## Not verified / blocked

Completion audit: `COMPLETION-AUDIT.md`. A fresh signed-device attempt again failed with No Accounts and missing profiles for all four targets; concise evidence is in `Testing/device-signing-audit.log`.

- **Signed-device build:** Xcode reports “No Accounts” and missing development provisioning profiles for all four bundle IDs. Sign in to the developer account to continue.
- **End-to-end Screen Time behavior:** not verified. The paired iPhone 14 Pro requires a signed installation, owner-granted Screen Time permission, and two Shortcuts automations. See DEVICE-VALIDATION.md.
- **Manual desktop interaction and VoiceOver:** still pending; the Mac remains locked. Native simulator XCTest tap-through tests now run independently through the normal Xcode test runner. No lock bypass was attempted.
- **App Store / TestFlight:** not submitted. Family Controls distribution approval is a separate prerequisite.

## Where to look

- `Design/visual-review.png`: welcome, calm interruption preview, rage preview, goodbye.
- `Design/flow-review.png`: alternatives, permission recovery, setup, settings.
- `Design/small-screen-review.png`: iPhone SE layouts and Chinese.
- `Design/Screenshots/`: individual native captures.
- `Design/asset-prompts.json`: original built-in ImageGen provenance. `Design/comic-v2-prompts.json`: the new comic poses and exact prompts. ShieldChill and ShieldRage now use downsampled v2 close-ups to keep extension memory low.
- `Design/visual-review-v1.png`: previous restrained direction for comparison.

The full illustrated interruption is the app's own preview/companion flow. The system shield on another app uses Apple's constrained ShieldConfiguration layout and remains pending physical-device visual validation.

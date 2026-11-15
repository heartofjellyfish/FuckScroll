# Physical-device acceptance — not yet completed

The simulator demonstrates native UI and compilation, not system-level app blocking. Do not describe this build as having passed real-device intervention testing until this checklist has recorded results.

## Required setup

- Sign in to the developer account in Xcode; automatic provisioning currently fails with “No Accounts.”
- Sign all four targets with Family Controls development entitlement and the same App Group.
- Use an unlocked iPhone with Developer Mode enabled and Screen Time authorization granted by its owner.
- Pick one nonessential test app. Create two personal automations for **that same app** with **Run Immediately**:
  - Is Opened → Scroll Stopper → **App opened — start session**.
  - Is Closed → Scroll Stopper → **App closed — end session**.
- Launch the test app, leave it, return to Scroll Stopper. Both signal indicators should be received. The app can verify reception but cannot inspect which app the automation targets.

## Acceptance cases

| Case | Expected result | Result |
| --- | --- | --- |
| Stay in selected app for the configured duration | System shield appears after Screen Time threshold delivery | Pending |
| Use another unselected app | No shield on it | Pending |
| Leave selected app for 30 seconds, return | Reuse the same monitoring event; retain fractional usage and do not reset the session | Pending |
| Repeated 59-second visits with 10-second switches | The same event eventually reaches the usage limit; no per-visit truncation | Pending |
| Leave for 60+ seconds, return | Fresh allowance | Pending |
| Repeated/delayed open-close signals | No duplicate session reset or obsolete restriction | Pending |
| Force-quit Scroll Stopper while using selected app | Registered monitoring and extensions continue; verify delivery | Pending |
| Lock phone mid-session, leave locked, unlock | Record which automation signals iOS sends; locked time must not be charged; assess whether session reliably resets after a long lock | Pending |
| Calls, Control Center, Notification Center, app switcher | Record App Closed/Open triggers and whether they cause unexpected resets | Pending |
| Threshold reached, try reopening/closing repeatedly | Full mandatory break remains | Pending |
| Change limits, pause, or change selected app during break | App rejects the change | Pending |
| Leave phone alone until break ends | System releases restriction, allowing for callback latency | Pending |
| Stay on the shield until expiry | Restriction releases and a new monitoring session is armed | Pending |
| iOS delays expiry callback | Returning to Scroll Stopper or shield action reconciles expired rest | Pending |
| Cross midnight / daylight-saving transition | Active break does not vanish or extend unexpectedly | Pending |
| Reboot during break | Persistent state and system monitor reconcile correctly | Pending |
| Deny/revoke authorization | No false “protected” status; recovery path visible | Pending |
| iOS 26.5 shield secondary action | Opens containing app without clearing the active break | Pending |
| iOS 17.4–26.4 shield | Close-only primary action; no unsupported parent-app jump | Pending |

## Deliberate limits

- **One app at a time.** Entire categories and websites are rejected rather than silently ignored. This keeps the automation-to-token mapping explicit and avoids pretending to know app identities hidden by Apple.
- **Signals are essential.** Neither the app nor the extension can directly observe arbitrary foreground/background transitions. Missing App Closed signals can merge separate sessions; missing App Opened signals can prevent monitoring. Screen lock behavior is an explicit release gate.
- **The counter survives short switches.** App Closed no longer stops the DeviceActivity monitor. A return within one minute reuses it; a return after a full minute replaces it. Cumulative callbacks are reconciled without double-counting, including delayed callbacks during a short absence. Unit scenarios prove the app logic, not the system’s delivery or sub-minute accumulation. Checkpoint delivery remains minute-granular; do not market second-perfect timing.
- **The release monitor is registered before shielding.** If registration fails, no indefinite shield is applied. The error is recorded and displayed; this is a protection failure, not successful enforcement.
- **iOS owns delivery.** Thresholds and interval callbacks are not hard real-time timers. A scheduled interval can end slightly late. The stored deadline is rounded up to a whole second so it cannot be later than the configured interval end due to subsecond truncation.
- **Individual users retain system control.** Permission revocation and app deletion can bypass app-level rules. No attempt is made to defeat these controls.
- **No daily cap fallback.** If session signals do not prove reliable on the target OS, surface that failure and revise the design with Qi; do not quietly ship a cumulative daily timer.

## Before TestFlight / App Store

Obtain Family Controls **distribution** approval for the app and each Screen Time extension. Review the privacy manifest, age-rating answers (including strong language), actual shield appearance, and the complete test matrix above. This repository does not submit anything to Apple automatically.

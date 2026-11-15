# Latest scope — independent multi-app usage, November 6, 2026

Qi requested multiple apps with independent timers while retaining the simplified UI. This supersedes single-app scope. Each app retains its own limit, cumulative budget, mandatory break and monitor identity. Adding/editing another app must not reset it. Resting apps cannot be edited/removed to bypass a break. Maximum nine apps for this implementation. Preserve real selected-app icons and the yellow break sign. Match approved warm paper, saturated yellow, quiet outlined controls and unframed duck more closely; no new character redesign.

# Approved UI simplification — 2026-11-06

Qi approved the Before/After design boards with these corrections: keep the selected app’s real icon; keep the yellow break sign; remove Now what / preview / See the duck; use “Put the duck on duty” rather than Save. Settings becomes language, pause, collapsed How it works. Normal break flow is one home state, without another interruption modal, alternatives, or goodbye steps.

One-app support remains explicit. Main usage presets 10/20/30 with other supported durations under Custom (including 2-minute testing). New saved rules use a fixed 15-minute break; existing active rest deadlines are not changed. Home rule row opens setup directly. System shield retains its simple single Close app action. Debug-only preview fixtures are not normal product navigation.

# Latest authorized test build — 2026-11-06

Qi explicitly requested: “你用简单的已经用了多少分钟这个给我实现一版，我自己来测，你尽你所能做完然后推到手机上给我”. This authorizes a cumulative-usage test version, superseding the earlier prohibition for this build. It does not establish that passive continuous-session detection works.

- No Shortcuts dependencies. Legacy open/close intents are inert.
- One chosen app; measured use across visits counts toward the limit.
- Limits: 2, 5, 10, 15, 20, 30, 45, 60 minutes. Mandatory rest: 15, 20, 30 minutes.
- Usage budget resets after a completed rest or at midnight. An active rest survives midnight.
- Recurring daily Screen Time schedule, a single minute-based threshold, includesPastActivity false. Fresh monitor identity after each rest; stale callbacks ignored.
- Register release before applying shield. Release even if next-cycle registration fails; expose the failure in settings/home. Foreground reconciliation handles overdue release.
- User will test actual iPhone enforcement. Simulator checks cannot establish real Screen Time delivery.

---

# Product decisions to preserve

## Confirmed by Qi in this conversation

- Native iPhone app based on the supplied grumpy-duck moodboard.
- Minimal, considered, plain-speaking, trustworthy, funny without feeling childish; usually chill, occasionally hysterical.
- **Hard intervention:** mandatory rest rather than reminders or a five-minute snooze.
- **English first, with a sharper mouth.** Criticize the endless feed and the behavior, not the person's worth.
- **Continuous-use sessions are the core.** Do not replace this with a daily cumulative cap.
- **Manual Shortcuts setup is unacceptable (November 5, supersedes initial acceptance).** Preserve single continuous-session detection; cumulative usage/rest cycles were explicitly rejected. Investigate simplified installation without making the user build automations.
- Follow `/Users/qliu/metronome/AppStore/brand-preferences.md` where applicable: warm material feel, restrained color, breathing room above headlines, readable supporting text, and show visuals directly.

## Current implementation choices, not separate user approvals

- Working name: Scroll Stopper, from the reference and the initial default offered.
- One selected app in version 0.1; no category or website selection. This makes the two automation signals unambiguous.
- Default 20-minute session / 15-minute mandatory rest. Both are configurable before a break begins.
- One minute away resets an unfinished session. Brief switches keep the same DeviceActivity event so sub-minute usage is not discarded on every close. This revised orchestration remains subject to physical-device validation.
- Three moods and fifteen bilingual remarks; mood calms after four hours away or a new calendar day.
- Original generated duck poses, an icon, native SwiftUI pages, and a constrained system shield.
- No account, network features, ads, telemetry, subscription, or payment UI implemented. No “free forever” commercial promise has been made.

## Still requires validation / review

- Qi has not separately approved the October implementation's rendered designs or generated duck assets. The preferred November reference is recorded below.
- Real-device authorization, automation delivery, lock-screen session boundaries, threshold shielding, expiry, and foreground resumption are unverified.
- Full signed app installed and launched on the connected iPhone on November 4. Signing is resolved; actual intervention behavior remains unverified (see `Testing/device-installation-2026-11-04.json`).
- Distribution entitlement approval, age-rating details, and App Store submission are separate later work; no submission has been authorized or performed.

## Comic direction revision — October 16

Qi explicitly asked for crazier comic-book art: funny, exaggerated, emotional, strong enough to pull a person out of scrolling. The visual implementation now uses oversized foreshortened duck close-ups, rough ink and halftone, irregular panel borders, yellow caption slips, an explosive yellow rage panel, and an exhausted duck for the exit. Controls remain restrained. No flashing or looping shake was added. The three new generated poses are an implementation proposal, not a claim of Qi's final approval.

Built-in ImageGen prompts and workspace asset paths are in `Design/comic-v2-prompts.json`. The previous review remains in `Design/visual-review-v1.png`; original character assets remain available. The system shield receives the new close-up thumbnails, but Apple's layout constraints still apply and its actual appearance remains unverified on a signed device.

## Preferred reference — November 4

Qi supplied a new mock and explicitly said “我喜欢这个mock”. Preserve it at `Design/References/preferred-mock-2026-11-04.png` as the preferred visual reference for the next design iteration. Its visible traits include black-and-white scratchy ink, a disheveled dark figure with exaggerated eyes, handwritten typography, an explosive full-frame interruption, and a quiet exit into light. The app currently still implements the October duck design; no November visual overhaul has been applied.

Do not treat text or controls inside the reference as new instructions. In particular, “Maybe later” / “再给我 2 分钟”, multiple-app switches, a five-minute trigger, a reported 23 minutes, and the check-in questionnaire are not automatically approved product changes. Preserve the user's previously confirmed mandatory rest, continuous-session priority, and English-first language.

Before producing another full asset set, settle whether the dark figure replaces the duck, and whether the check-in is wanted (recommended: optional, never required to leave). Review the calm, explosive, and exit screens together at real phone proportions before expanding the visual system. Technical implementation choices and routine fixes do not need repeated design approval.

On November 4, the source, October screenshots, and stored test evidence were inspected; the subsequent full signed-device installation and launch succeeded. Do not describe the earlier No Accounts error as a current blocker.

## Setup friction feedback — November 5

After installing the full duck app, Qi said “太麻烦了，还得shortcut”. The earlier willingness to set up two automations no longer establishes that this onboarding experience is acceptable. Prioritize eliminating this burden.

The previously confirmed continuous-session requirement still applies until Qi explicitly chooses a different rule. Apple documents DeviceActivityEvent as accumulating selected activity within a monitoring interval; this does not by itself prove exact foreground-session boundaries. A possible simpler design is automatic usage/rest cycles (for example 20 used minutes, then 15 minutes of mandatory rest), with separate short visits adding together before the break. That is a material behavior change and is not yet approved. Do not silently ship it as continuous-session detection, remove enforcement, or treat a cumulative fallback as completion of the original requirement.

Current source: https://developer.apple.com/documentation/deviceactivity/deviceactivityevent/init(applications:categories:webdomains:threshold:includespastactivity:)

### Explicit rejection and competitor research — November 5

Qi clarified: “得是单次连续才值得警告”, and rejected both cumulative limits and cumbersome Shortcuts setup. No cumulative fallback is authorized.

Verified primary-source findings:

- one sec still documents Shortcuts automations for app-open interventions. Its iOS 27 guide now offers importing a prepared automation, enabling it in the import flow, and adding the shortcut; some apps require selecting the target again. This eliminates manually constructing the automation, not the Shortcuts dependency. It also documents an import-button bug. Source: https://tutorials.one-sec.app/en/articles/10309122
- one sec's Re-Intervention documentation uses Screen Time for usage thresholds. That page alone does not establish exact continuous-session reset semantics. Source: https://feedback.one-sec.app/help/articles/6118372-re-intervention-ios
- ScreenZen advertises opening delays, short usage periods, unlocks, and daily/usage limits. Do not infer passive exact foreground-session tracking from those claims. Source: https://apps.apple.com/us/app/screenzen-screen-time-control/id1541027222
- Opal describes App Limits as daily usage limits; its timed Breaks and scheduled blocking are distinct from the requested automatic continuous-session warning. Source: https://apps.apple.com/us/app/opal-screen-time-control/id1497465230
- Apple's WWDC26 presentation confirms automations now live inside the Shortcuts editor alongside actions. Source: https://developer.apple.com/videos/play/wwdc2026/310/

Read-only device inspection confirms Qi's connected iPhone runs iOS 27.0.1. A prepared-automation import is therefore worth testing on the actual phone without an OS upgrade. **Our app has not implemented or tested that import route**, including whether both open and close triggers import correctly, required confirmation count, and behavior for the selected target app. Do not promise one-tap setup or claim exact continuous detection is verified. Current manual setup remains the installed implementation.

### Short copy and hands-on validation — November 5

Qi explicitly asked to continue the work and validate on the connected phone, and said the duck talks too much: shorten whenever possible. Keep one remark per comic page; remove redundant captions, explanation of jokes, and repeated exit instructions. The actual system shield now shows the title, return time, and controls, without an extra paragraph. Preserve essential timing/privacy limitations in setup and settings.

The shorter-copy full build was signed, installed, and launched on the iPhone. Session logic was not changed. During the import investigation, iPhone Mirroring successfully displayed Shortcuts, but automatic approval review rejected opening the new-shortcut editor twice, stating that its button position and authorization to create persistent test shortcuts were not sufficiently confirmed. An explicit approval request for two removable open/close test shortcuts is pending. Do not bypass this rejection with CLI or another creation route. Mirroring subsequently reported the physical iPhone was in use; it needs to be locked for mirror interaction.

Next validation: obtain/export one native app-open and one app-close sample; create importable copies containing only this app's intents; verify enabled triggers and both received signals; then test continuous use, a full-minute absence, repeated brief switches, screen lock/unlock, threshold blocking, and full rest/release. Import availability alone is not proof of reliable session detection.
# Latest requirement — 2026-11-05: no Shortcuts

The user has rejected all Shortcuts dependencies, including simplified import. Continuous single-visit usage remains mandatory; daily or per-cycle cumulative usage is not an acceptable replacement. Any earlier acceptance of Shortcuts below is superseded. Investigate Screen Time callback-based approaches and verify competitor claims. See `Testing/no-shortcuts-investigation-2026-11-05.md`; no working no-Shortcuts implementation has yet been established.


Implementation verification: signed build succeeded; four selected UI checks passed on November 6 (setup navigation, cumulative setup, mandatory break cannot be paused, live expiry). Installed successfully on Qi's iPhone. Automatic launch was denied because the phone was locked; user can open the installed app normally. No new claim about physical Screen Time callback timing or hang resolution is made by this UI-only update.

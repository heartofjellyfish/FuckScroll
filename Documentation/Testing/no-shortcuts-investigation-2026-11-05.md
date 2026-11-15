# Continuous sessions without Shortcuts — investigation

## Acceptance criteria

No Shortcuts setup, import, or automation dependency. Only a long continuous visit should trigger a mandatory rest. Separate short visits must not accumulate toward the warning. The user has explicitly rejected changing this requirement.

## Primary-source findings

- Detox explicitly advertises consecutive usage, with reset after roughly one minute away: https://detox.so/blog/refocus-alternative and https://detox.so/blog/why-daily-screen-time-limits-dont-work . This is a vendor claim, not our observed test result.
- Its developer (then named Filos) says the implementation uses Apple's Screen Time API in an unconventional way: https://www.reddit.com/r/ProductivityApps/comments/1d1yd1q/ . The post does not disclose an algorithm. Do not infer that Detox uses our proposed algorithm.
- The associated research describes configurable continuous-use thresholds and cooldowns but does not document callback timing or an implementation: https://formative.jmir.org/2026/1/e85349 .
- Cape advertises automatic breaks after extended use, but its public description does not establish whether an intervening absence resets the counter: https://getcape.app/ and https://getcape.app/faq.html .
- Apple exposes measured-usage thresholds within monitoring intervals: https://developer.apple.com/documentation/deviceactivity/deviceactivityevent/init(applications:categories:webdomains:threshold:includespastactivity:) . Absence of a direct foreground-app callback alone does not prove that a useful continuity detector cannot be built.

## Experiment

Debug launch argument `--usage-probe` opens a dedicated instrument screen. Select exactly one test app and register 10-second usage checkpoints for 15 minutes in a 30-minute monitoring interval, with `includesPastActivity: false`. Log registration, interval boundaries, threshold values, receipt timestamps, and manual test marks into the app group's `usage-probe.json`. No app identifiers or user content are logged. No blocking occurs in this instrument.

Starting the probe disables the legacy intent-driven monitor, so existing test automations cannot create session signals in this experiment. The old import probe is no longer reachable or packaged with Shortcut resources. The ordinary product flow is not yet migrated; this is an instrument, not a completed no-Shortcuts feature.

Test continuous use, leave for over 60 seconds, then return. Repeat with short separate visits, app suspension and process termination. Check especially for historical usage leaking into a fresh monitor and batched/delayed delivery. A delivered callback is not proof of an app-open or app-close event.

## Hypotheses to falsify

1. Usage checkpoints plus elapsed time may reveal a sufficiently long absence. Callback delays can confound this; do not ship based only on ideal-clock unit tests.
2. Staggered windows whose usage fills the entire window could provide conservative continuity evidence. Minimum schedule duration, simultaneous-monitor limits, boundary delivery, and detection latency require measurement. This does not automatically solve shorter configured limits.

## Status

The signed Debug build compiles. Existing 30 policy checks and 10 modeled session scenarios pass; these test the legacy session engine and do **not** establish no-Shortcuts support. Phone experiment results are recorded separately below when observed.

- A dedicated UI test verifies that pressing Start without an app selection displays the validation message. It caught a temporary root long-press gesture swallowing taps; that gesture was removed and the test passed at 02:23:25 local time. This is only an instrument UI test.
- The device installed and opened the instrument. Mirroring repeatedly disconnected with “iPhone in Use.” No target-app selection or active recording has yet been confirmed. No real usage-callback results are claimed.
- The tool also supports a Debug-only `scrollstopper://usage-probe` URL. No hidden gesture is required. The normal app remains available when launched without the probe argument.
- `Scripts/analyze_usage_probe.py` summarizes recorded callback times, flags batches/out-of-order thresholds and usage greater than elapsed time since registration. It explicitly avoids labeling callback receipt timestamps as app-open/close events.

## Device run, 2026-11-05 morning (America/Los_Angeles)

The user provided an uninterrupted locked-phone window, then connected USB. Screen Time authorization was confirmed in the instrument. Exactly one application, rednote, was selected. The probe ran without Shortcuts and disabled the legacy engine.

Observed log before shutdown:

- 09:27:49.654 register; 09:27:49.832 interval-start; 09:27:49.838 armed.
- 09:27:50.201 operator mark before first use; 09:28:57.602 mark after return. These marks bound navigation plus use, not exact foreground transitions.
- 09:31:47.893 operator mark before second use, following more than a minute away. Returned to the Home Screen around 09:33:30; no second return mark was recorded.
- Exported at 09:34:08: **six entries, zero usage-threshold callbacks**. Successful registration and interval-start are established; usage tracking and continuity inference are **not established**.
- All target usage was through iPhone Mirroring. This run does not establish whether mirrored usage is counted identically to physical-screen use. Callback granularity, delay, seconds-based thresholds and the measurement environment remain candidate causes. Do not claim a confirmed cause or a platform impossibility.
- Stopped the temporary monitor via the instrument; the UI explicitly showed “Stopped.” No shield was applied. The legacy monitor remains disabled by the probe.

Device-group file retrieval failed with CoreDevice's “File paths cannot contain '..'” error despite an ordinary relative source path. A local Documents export succeeded over USB. The new instrument displays individual callbacks, provides export, and registers/stops asynchronously so slow system calls do not swallow subsequent UI interactions. Its source changes compile; on-device Stop was verified. The new detailed-log UI is diagnostic only, not a shipped feature.

Raw evidence: `no-shortcuts-device-2026-11-05.json`. The required next control is reliable measured-use delivery before attempting a continuity classifier. The no-Shortcuts product requirement has not passed.

## Physical-use control prepared, 2026-11-05 afternoon

Replaced the 90 ten-second thresholds with exactly two events, using `DateComponents(minute: 1)` and `DateComponents(minute: 2)`. Both retain `includesPastActivity: false`. The diagnostic screen shows the two received checkpoints, the selected app's system-provided label, and the raw delivery log. It preselects the app already saved in the user's rule. Starting remains an explicit button action; no usage tracking or blocking is claimed before registration.

Signed device build and the diagnostic selection-validation UI test passed. Installed on the connected iPhone at approximately 14:49 local time. This installation is preparation for a physical-screen control, not proof of working continuous-session detection.

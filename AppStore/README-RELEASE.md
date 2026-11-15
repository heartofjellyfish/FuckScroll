# Stop Scrolling – Duck on Duty · 1.0 (51)

Materials are refreshed. This is NOT yet a submitted or App Store-ready binary.

## Included

- Ten localized names, subtitles, keyword fields, descriptions and promotional texts.
- Country-appropriate example apps with matched names and official App Store icons (see example-apps-by-market.json).
- Four screenshots per language, in 1290 × 2796 and 1206 × 2622: social-scrolling pain, independent app timers, companion duck, Ground rules.
- The current 1024 × 1024 opaque app icon.
- Accurate reviewer instructions for Screen Time access, short testing, custom reminders, cumulative usage and independent breaks.
- Deployable support and privacy HTML under website/scroll-stopper/.
- Validation JSON and actual release status. All app times/identities in store images are illustrative fixtures in real SwiftUI views.

## Release decisions

Name: Stop Scrolling – Duck on Duty
English subtitle: Social Media App Blocker
Price: Free (owner confirmed). No price claims on screenshots.
Primary category proposal: Productivity.
Availability intent: every eligible App Store region, subject to required regional information.
Owner authorized direct submission without another visual review on 2026-11-09. App Store Connect record 6832822647 was created and four English screenshots were uploaded. The binary has not been uploaded or submitted.

## Current submission blockers

1. App Store export fails because the main app and three extension distribution profiles do not include com.apple.developer.family-controls. After the owner restored Xcode login, No Accounts was resolved. Verify Family Controls (Distribution) approval/configuration for the team and all four bundle IDs, then regenerate the profiles/export. Do not remove this entitlement to force an upload; the main feature depends on it.
2. https://app.qi.land/scroll-stopper/ and /scroll-stopper/privacy/ both returned HTTP 404 during this run. Publish the included pages to the existing Clean app-series site before entering the URLs in App Store Connect.
3. Verify the App Store Connect app record, price, region availability, age questionnaire, privacy declaration and review contact. These remote settings have not been claimed as configured.

## Binary

Xcode archive created successfully:
AppStore/Builds/ScrollStopper-1.0-51.xcarchive
It is separate from this materials ZIP and still needs successful App Store distribution export.
Export recipe: AppStore/ExportOptions.plist. The export destination is local; it does not automatically upload or submit.

## Verification limits

72 deterministic production-monitoring checks with simulated Screen Time delivery, 30 policy checks and 10 modeled scenarios passed. Recent simulator tests cover the settings states, reminder editing, keyboard avoidance, empty home and permission entry. Build 51 is installed on the paired iPhone.
A full physical release-timing/idle-reset/reboot matrix has not been completed. The large comic is the companion app; the system shield on another app uses Apple's constrained eye/text/button layout.

## Apple references

- https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/

# Family Controls distribution request

The archive succeeds and the iPhone development build works. App Store export is currently rejected because the distribution profiles for every target omit `com.apple.developer.family-controls`.

Developer team: 47C4WT5UPR
App: Stop Scrolling – Duck on Duty
Version: 1.0 (51)

Bundle IDs that need the managed distribution capability:

- com.heartofjellyfish.scrollstopper
- com.heartofjellyfish.scrollstopper.monitor
- com.heartofjellyfish.scrollstopper.shield
- com.heartofjellyfish.scrollstopper.action

Use the Developer portal's Capability Requests / Family Controls (Distribution) flow. Check existing requests before creating duplicates. If a request is team-level, include all four identifiers in the app/extension explanation. Once Assigned for the required distribution methods, refresh automatic signing profiles and repeat App Store export. Do not remove the entitlement to bypass signing errors.

Suggested explanation, for the account holder to review:

“Stop Scrolling – Duck on Duty is an iPhone app for voluntary management of the user's own app usage. The user authorizes Family Controls with individual authorization, selects specific applications in Apple's privacy-preserving picker, and sets independent usage budgets and mandatory breaks. Device Activity delivers usage milestones, Managed Settings shields an application after its budget is reached, and an extension releases the shield after the break. Shield Configuration supplies our duck-eye illustration, short custom text and one exit action. On supported iOS versions Shield Action opens the containing app; otherwise it closes the shielded application. All selected-app tokens, settings, usage state and custom text remain local in the shared App Group. The app has no server, account, advertising SDK or analytics. It does not inspect what the user reads, types or sends.”

Apple guidance:
https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement

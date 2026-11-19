# Publication and readback

Use only when the user requests an external update/submission. Research or skill creation does not authorize publishing another app. Existing authorization for the same concrete release persists; do not add redundant approval gates.

## Before writing

- Check the actual app record, live version, active submission, binary and editable locales. Local release files can be stale; an archive is not an upload.
- Identify the approved source of truth and targets. Preserve unrelated price, privacy, contacts, screenshots and settings unless needed and authorized.
- Metadata-only edits may fit a pending version. Do not automatically rebuild or bump it. New languages may require editable status. If withdrawing/resubmitting is necessary within authorized publishing, account for queue impact and explicit instructions to preserve a submission. An assistant's old plan is not a user-imposed prohibition.
- New locales may require descriptions even when research covered three fields. Check current Apple requirements and the form. Supply concise accurate local copy within authorized scope, or report the real dependency.
- Use primary-language screenshot fallback only when supported; do not call that newly localized screenshots or additional UI languages.

## Reliable save and submission

Use supported connectors, APIs, CLIs or UI with the authorized account. Do not recover sessions through private browser internals or expose credentials. Tool-specific policies still apply.

In repetitive UI edits, wait for the selected locale's actual data to load. A dropdown label can change before its form data arrives; early filling may hit the wrong locale or be discarded. Inspect fresh visible values and save-completion signals. Disabled Save can mean unchanged, saving or a late response; check before retrying.

After failure, inspect the server error and persisted values. Fix a concrete formatting conflict or restore an authorized session. Do not blindly retry, silently choose another name, duplicate locales or submit again after an ambiguous timeout. Inspect the resulting state first.

Read every targeted name, subtitle and keyword set back from Apple. Reload/re-open where needed to distinguish persisted data from an unsaved form. Compare with the approved source using `scripts/check_metadata.py --readback`. Local JSON validity does not prove a successful Apple write.

Check new-locale requirements, server validation and submission summary. Reuse a verified binary for metadata-only edits. If a binary is replaced, verify release permissions/signing in the actual export, not just project settings.

Complete the authorized final action and verify receipt/status. Distinguish draft, saved, ready, submitted, waiting, approved and live. Report actual version/build and automatic/manual release mode; approval does not imply immediate indexing.

## Private evidence and public source

Keep actual readback, receipt and a suitable screenshot locally. Before uploading or committing, check destination visibility and authorization. Private submission links/IDs, reviewer contacts, account details and identifying screenshots are not automatically authorized for public GitHub because source pushes were authorized.

For public repositories, exclude private artifacts from staging, preserve a local audit, and publish nonsensitive copy/code/status. Add narrowly scoped ignore rules where useful. Respond to approval-review feedback with a genuinely safer payload; never disguise or reroute rejected data.

Record lifecycle state in project files without invented timestamps. Use the user's timezone and evidenced precision. Update generators so rerunning them does not falsely mark submitted fields as unsubmitted drafts.

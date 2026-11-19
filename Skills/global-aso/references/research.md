# Research method

## Evidence and market depth

Make a compact brief from shipping code, verified listing and user decisions: main job, mechanism, audience, current capabilities, exclusions, brand constraints and UI languages. For a metronome, music streaming is not a direct rival just because both rank for “music.”

Record provider, storefront, query, observation timestamp, returned positions and source location together. Keep metric timestamps separately when different. Distinguish:

| Evidence | Supports | Does not support |
|---|---|---|
| Native keyword-ranking response | Observed country/query/snapshot positions | Permanent rank, downloads, causal ASO impact |
| Public Apple search/catalog | Discovery, public wording, release facts | Verified native rank from catalog order |
| Popularity/difficulty estimate | Relative opportunity in a comparable provider/market | Exact searches/day or interchangeable tool scores |

Minimum scores may be low-information. Missing data, an untracked term, a failed request and a measured low score are different states. Out-of-chart sentinels are not literal ranks. Skipped keyword-add results may need a tracked-record lookup; skipped is not zero demand.

A tool named `get_app_keywords` may return only tracked terms. A competitor-keyword extraction tool may derive combinations from public wording. Check semantics before calling either a competitor's private keywords.

For a broad deep audit, start with a few dozen plausible local/bilingual terms and several distinct intents, then prune using evidence. These are starting points, not quotas to pad. Inspect top-five results and expand to a supported larger window when needed. Save actual counts; never fabricate missing results. A popular “app lock” query dominated by password tools may be wrong for a focus blocker.

For every requested market, mark measured, low-signal, catalog-only, unavailable or not researched. Do not substitute US scores for unsupported countries. Shared-language anchors may support cautious drafts; preserve local differences and label borrowed evidence. Coverage changes: do not hardcode a previous count of supported markets.

Use Apple's current country-to-localization mapping. One locale may serve several countries, and customers in one country can see different localized listings. Store localization does not add in-app UI translations.

## Young winners

Choose the user's period or a relevant current product cycle, often the last 12–18 months. Launch proximity helps only after relevant strong ranking is established. Verify public `releaseDate`, not `currentVersionReleaseDate`. Compare storefront facts when needed: a local launch may follow an older release elsewhere. Use the earliest verified observed public date and keep its source; it does not prove developer or brand age.

Exclude our own product from the competitor cohort; its rank is a baseline to track separately.

Check public descriptions, and classify both young apps and old comparators:

- Direct: same central job, broadly comparable mechanism.
- Related: same job, materially different mechanism; explain the difference.
- Adjacent/excluded: different intent, audience or capability.
- Unverified: not enough evidence.

A primary case is normally native top five, ideally top three, with a verified relevant older app below in the same response. Broaden dates or positions only for a stated reason. Keep low-demand wins secondary. A popularity cutoff such as 20 is a configurable analyst convention, not an Apple rule.

Prefer recurrence across related queries/markets when available, while preserving timestamps. Distinguish “currently above X” from “rose above X,” which requires history. Do not imply all incumbents were beaten if some remain higher.

## Extract useful lessons

Separate three things for each case:

1. Observed: current localized title/subtitle, release fact, function and positions.
2. Interpretation: category/problem words and product differences communicated.
3. Hypothesis: a relevant token, clearer name structure or sharper benefit to test.

Current metadata and rank do not reveal the original launch strategy or prove an ASO effect. Downloads, ads, conversion, ratings, external traffic, prior brands and editorial exposure may contribute. Actual before/after claims need history. Do not copy unsupported capabilities, medical outcomes, absolute “unbreakable” claims or competitor identity.

## Reliable collection

Discover current schemas and cache successes. For an authorized direct MCP connection, use unique JSON-RPC IDs and respect actual rate limits/retry-after hints. Do not hardcode an old localhost port or another provider's limits.

Bound retries. Repeated auth failures need a valid session or handoff; repeated rate errors need slower pacing. Preserve partial progress and label gaps. Do not flood query grids, scrape browser credentials or bypass rejected actions.

Use short paraphrases for scope review. Preserve URLs and optionally description hashes without committing full descriptions. Keep private publication/auth artifacts separate from public research.

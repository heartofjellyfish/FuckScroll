# Helper input formats

## Metadata and readback

`check_metadata.py` accepts a locale map, or a wrapper with `localizations`:

```json
{"localizations":{"en-US":{"name":"Approved Product Name","subtitle":"A concrete benefit","keywords":"relevant,search,terms"}}}
```

An optional `--readback` file accepts the same map or a list under `localizations`, with `locale`, `name`, `subtitle`, `keywords` on each row. Extra description/state fields are ignored. Use data actually read from Apple, not a copy of expectations. Keep private files local as needed.

Errors cover missing/invalid fields, limits, empty tokens and duplicate keyword tokens. Warnings flag padding, short ASCII abbreviations and obvious Latin-word repetition. Native two-character terms are valid. Internal phrase spaces are preserved; CJK is not split into individual characters. Scripts cannot prove relevance, demand, indexing, translation quality or name availability.

Default keyword limit: **conservative 100 UTF-8 bytes**. `--keyword-unit characters` deliberately changes that convention; check the target API/form's current rules. Name/subtitle code-point counts are only a local preflight; Apple validation is authoritative.

## Ranking evidence

`find_recent_winners.py` has no embedded account, app ID, localhost URL, country count or launch year. Normalize tool data to:

```json
{
  "apps": {
    "young-id": {"name":"Young Product","releaseDate":"2026-02-01T08:00:00Z","releaseSource":"https://public.example/young-fact","scope":"direct","scopeVerified":true},
    "older-id": {"name":"Older Product","releaseDate":"2022-01-01T08:00:00Z","releaseSource":"https://public.example/older-fact","scope":"direct","scopeVerified":true}
  },
  "snapshots": [{
    "id":"unique-provider-response-id","store":"us","keyword":"relevant query",
    "observedAt":"2026-11-19T08:00:00Z","source":"raw/saved-response.json",
    "evidenceType":"native-rank","popularity":35,"difficulty":25,
    "apps":[
      {"appId":"young-id","rank":2,"rankStatus":"ranked","title":"Young Product","subtitle":"Visible wording"},
      {"appId":"older-id","rank":4,"rankStatus":"ranked","title":"Older Product","subtitle":"Visible wording"}
    ]
  }]
}
```

Dates here are illustrative. Set `--released-since`, `--as-of` and `--incumbent-before` for the actual task. The latter defines how old comparators must be. ISO timestamps convert using `--timezone`; date-only facts stay date-only. Use the earliest verified observed release fact, not an update date, and preserve evidence for storefront differences.

Set optional top-level `ownAppId` to our product's ID to exclude it from the competitor analysis. Remove own-app entries during normalization if no ID is supplied.

Scopes: `direct`, `related`, `adjacent`, `excluded`, `unverified`. Verification means the public function was checked, not device-tested. Only verified direct/related products with a sourced release fact count as comparable.

Evidence types: `native-rank` or `catalog`. Catalog results never become ranking wins. Popularity may be null. `--min-popularity` defaults to 20 as a screening convention; adjust with a reason.

Each native result requires `rankStatus`: use `ranked` only for actually measured positions. Use another explicit status such as `out-of-chart` for provider sentinels; those entries are ignored. Do not turn a value such as 1000 into a real position unless that is what the provider measured.

Output separates primary cases from low-signal observations. It processes each snapshot independently, never mixing a candidate from one result with an incumbent from another. Counts describe this sample, not all markets or unqueried keywords. Recurring snapshots are not independent countries.

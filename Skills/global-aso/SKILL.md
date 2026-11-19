---
name: global-aso
description: Research App Store keywords per country, find recently launched comparable apps ranking ahead of incumbents, and produce evidence-backed localized names, subtitles, and keywords. Use for deep ASO research and cross-market optimization, including Astro MCP. Publication steps apply only when publishing is requested.
---

# Global ASO

Optimize how the actual product is found and understood in each market. Deliver a clear recommendation with traceable evidence, rather than a keyword dump or a translation of the US listing.

## Establish the product and scope

- Read project instructions, approved branding, current listing and shipping behavior. Identify the main job, real features and adjacent products. Mockups and plans are not evidence of shipped capabilities.
- For Qi's apps, read project preferences and the cross-app brand-preferences file if present. Carry over clear benefits and concise, personable copy; do not carry over another app's mascot, price promises, fixed name or visual identity.
- Start with the requested fields. A title/subtitle/keywords task does not imply new features, screenshots, UI translations, a binary or publication.
- Establish target storefronts, writable language/region localizations, existing locales, recent-launch period and release state. Infer these from connected tools and the project before asking. Respect approved names and later corrections.

## Research each market

Read [the research method](references/research.md) when collecting or interpreting data.

1. Discover available ASO tools and their current schemas. Prefer the user's Astro MCP or another connected provider. Recheck country coverage, result limits, metric definitions and rate limits. A local MCP URL is configuration, not a hardcoded dependency or authorization for other servers.
2. Build local hypotheses from category words, user problems and actual mechanisms. Include native wording, colloquial alternatives and English queries where locally relevant. Prioritize functional relevance, then demand; use lower difficulty to find an opening. If there is no clear opening, favor demand rather than an empty niche.
3. Inspect the top five relevant results for promising queries. Expand the result window to locate young challengers and older comparators. On a broad market request, cover every requested market and show missing evidence. Do not describe a seed scan as completed deep research.
4. Find recent winners: similar function, verified original release date in the chosen period, strong rank, and a relevant incumbent lower in the **same country, query and response snapshot**. Launch proximity or few reviews alone is not success. Use the helper below after normalizing data.
5. Read shortlisted products' public titles, subtitles and descriptions to verify scope. Learn which problem terms and differentiators they emphasize. Hidden keyword fields and ranking causes remain unknown unless a source actually supplies that evidence.

Choose the recent period for this task; do not perpetuate a past case study's year. A browser feed filter, parental-control tool, password lock or generic productivity app may be adjacent despite appearing in the same search.

## Make the three-field decision

- Recommend one set per writable locale. Map covered countries and shared-locale tradeoffs; countries are not independent language fields.
- A new app can lead with a category term plus a memorable brand. A recognized or explicitly approved brand may stay first. The subtitle should clarify the benefit or mechanism, not merely add a slogan.
- Localize names naturally where useful and authorized. Do not mechanically append English branding everywhere, or replace established names merely to mimic competitors.
- Cover valuable relevant queries across the name, subtitle and keyword tokens. Avoid duplicate indexed words, filler and competitor trademarks. Preserve meaningful native multi-character terms; do not apply English word-length rules to Chinese or Japanese.
- Choose remaining keywords for supported query coverage, not to fill space. Do not assume cross-locale indexing, arbitrary token combinations or unsupported product capabilities.
- Run `scripts/check_metadata.py` on the final sets. It checks structural limits and emits review warnings; it cannot establish demand or translation quality. Apple validation remains authoritative. This workflow defaults to a conservative 100 UTF-8-byte keyword budget and states that convention explicitly.

Explain what changes, what stays, why, and what could change the recommendation. A new competitor does not require replacing fields that already target the right intent. Avoid repeated renaming without new evidence.

## Deliver and measure

Give a concise decision first, with a viewable project report for depth. Include:

- Per-locale name, subtitle, keywords and validation counts; before/after when editing.
- Per-market terms, demand/difficulty estimates, relevant results, and low-signal/unsupported states.
- Young-winner comparisons naming the query, positions, older comparators, release-date sources, scope verification and response provenance.
- Country-to-locale mapping, reasons, uncertainties and current draft/submitted/live state.

Preserve compact public source facts and timestamps in the project, not full copyrighted descriptions or credentials. Keep private submission receipts, account details and identifying screenshots outside public commits.

Compare search impressions, downloads, conversion and target-query positions by market against a pre-change baseline, commonly at 7/14/28 days when traffic permits. Separate paid acquisition and major product changes. Do not invent a percentage lift without a baseline.

If publication is requested, read [publication and readback](references/publication.md). This skill grants no publishing authority. Respect existing explicit authorization without asking again.

## Helpers

Both scripts use Python's standard library. Read [input formats](references/data-formats.md) when normalizing tool output.

```bash
python3 scripts/check_metadata.py /absolute/path/metadata.json
python3 scripts/check_metadata.py /absolute/path/metadata.json --readback /absolute/path/private-readback.json
python3 scripts/find_recent_winners.py /absolute/path/evidence.json --released-since YYYY-MM-DD --as-of YYYY-MM-DD --incumbent-before YYYY-MM-DD --timezone America/Los_Angeles
```

Use the installed skill's absolute script paths. Dates are actual task inputs. The winner helper uses native ranks, separates low-signal cases and never combines snapshots.

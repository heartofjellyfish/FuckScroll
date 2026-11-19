#!/usr/bin/env python3
"""Validate ranking and date claims against saved research observations."""
import json
from pathlib import Path
from collections import defaultdict

ROOT=Path(__file__).resolve().parents[1]/'AppStore/ASO/next-release'
OUT=ROOT/'peer-cohort'
read=lambda p:json.loads(p.read_text())
result=read(OUT/'winners.json')
observations=read(OUT/'observations.json')
groups=defaultdict(list)
for row in observations:
    groups[row['store'],row['keyword'],row['source']].append(row)
assert len(result['countries'])==175
assert sum(c['astroSupported'] for c in result['countries'])==91
assert len({c['store'] for c in result['countries']})==175
assert not read(OUT/'cohort-candidates.json')['discoveryErrors']
for win in result['wins']:
    assert win['evidenceType']=='astro'
    assert win['position']<=5
    assert '2026-01-01'<=win['releaseClientDate']<=result['asOfClientDate']
    source=ROOT/win['source'];assert source.exists()
    rows=groups[win['store'],win['keyword'],win['source']]
    assert any(r['appId']==win['appId'] and r['position']==win['position'] for r in rows)
    for old in win['beaten']:
        assert old['position']>win['position']
        assert old['releaseDate'][:4]<'2025'
        assert any(r['appId']==old['appId'] and r['position']==old['position'] for r in rows)
    evidence=win['releaseDateEvidence'];path=ROOT/evidence['source'];assert path.exists()
    dated=read(path)
    records=dated.get('apps',dated.get('response',{}).get('results',[dated]))
    assert any(str(a.get('trackId'))==win['appId'] and a.get('releaseDate')==evidence['releaseDate'] for a in records)
    if win['strongSignal']:
        assert win['scope'] in ('direct','related') and win['descriptionChecked']
        assert win['popularity']>=20 and win['descriptionSHA256']
for country in result['countries']:
    if not country['astroSupported']:
        assert not country['strongWins'] and country['status']=='catalog-only-no-rank-conclusion'
assert result['coverage']['strongCountries']==sum(bool(c['strongWins']) for c in result['countries'])
assert result['coverage']['strongApps']==len({w['appId'] for w in result['wins'] if w['strongSignal']})
assert result['coverage']['strongKeywordWins']==sum(w['strongSignal'] for w in result['wins'])
print('Validated: dates, same-response competitor comparisons, 175 market statuses, and strong-evidence filters.')

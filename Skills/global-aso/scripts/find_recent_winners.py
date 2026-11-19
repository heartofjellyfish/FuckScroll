#!/usr/bin/env python3
"""Find recent comparable apps ahead of older comparators within one response."""
import argparse
from datetime import date, datetime
import json
from pathlib import Path
from zoneinfo import ZoneInfo


def day(value, zone):
    if len(value) == 10:
        return date.fromisoformat(value)
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None:
        raise ValueError('Timestamp needs an explicit timezone: ' + value)
    return parsed.astimezone(zone).date()


def analyze(document, since, as_of, incumbent_before, zone, top=5, min_popularity=20):
    if since > as_of or incumbent_before > since:
        raise ValueError('Date boundaries must satisfy incumbent-before <= released-since <= as-of.')
    apps = document['apps']
    primary, secondary, skipped = [], [], []
    snapshots_seen = set()
    dates = {}
    for appid, app in apps.items():
        if app.get('releaseDate'):
            dates[appid] = day(app['releaseDate'], zone)

    def comparable(appid):
        app = apps.get(appid, {})
        return (appid != document.get('ownAppId') and app.get('scope') in ('direct', 'related') and app.get('scopeVerified') is True
                and bool(app.get('releaseSource')) and appid in dates)

    for snapshot in document['snapshots']:
        sid = snapshot['id']
        if sid in snapshots_seen:
            raise ValueError('Duplicate snapshot ID: ' + str(sid))
        snapshots_seen.add(sid)
        for key in ('store', 'keyword', 'observedAt', 'source', 'evidenceType'):
            if not snapshot.get(key):
                raise ValueError(f'Snapshot {sid} is missing {key}.')
        if day(snapshot['observedAt'], zone) > as_of:
            raise ValueError('Snapshot is later than as-of in the selected timezone: ' + str(sid))
        if snapshot['evidenceType'] == 'catalog':
            skipped.append(dict(snapshot=sid, reason='Catalog order is not a verified native rank.'))
            continue
        if snapshot['evidenceType'] != 'native-rank':
            raise ValueError('Unknown evidence type: ' + snapshot['evidenceType'])
        ranked = []
        appids_seen, positions_seen = set(), set()
        for item in snapshot['apps']:
            if 'rankStatus' not in item:
                raise ValueError('Every result needs rankStatus; normalize out-of-chart sentinels explicitly.')
            if item['rankStatus'] != 'ranked':
                continue
            rank = item.get('rank')
            if type(rank) is not int or rank < 1:
                raise ValueError('Ranked results need positive integer positions.')
            appid = item['appId']
            if appid in appids_seen or rank in positions_seen:
                raise ValueError('Duplicate app or position within snapshot: ' + str(sid))
            appids_seen.add(appid)
            positions_seen.add(rank)
            ranked.append(item)
        for item in ranked:
            appid = item['appId']
            if item['rank'] > top or not comparable(appid) or not since <= dates[appid] <= as_of:
                continue
            beaten = [dict(appId=old['appId'], name=apps[old['appId']].get('name'),
                           rank=old['rank'], releaseDate=dates[old['appId']].isoformat())
                      for old in ranked if comparable(old['appId']) and dates[old['appId']] < incumbent_before
                      and old['rank'] > item['rank']]
            if not beaten:
                continue
            popularity = snapshot.get('popularity')
            strong = isinstance(popularity, (int, float)) and not isinstance(popularity, bool) and popularity >= min_popularity
            result = dict(appId=appid, name=apps[appid].get('name'), scope=apps[appid]['scope'],
                          releaseDate=dates[appid].isoformat(), releaseSource=apps[appid]['releaseSource'],
                          rank=item['rank'], title=item.get('title'), subtitle=item.get('subtitle'),
                          store=snapshot['store'], keyword=snapshot['keyword'], snapshot=sid,
                          observedAt=snapshot['observedAt'], source=snapshot['source'],
                          popularity=popularity, difficulty=snapshot.get('difficulty'), beaten=beaten,
                          classification='primary' if strong else 'secondary-low-or-unknown-demand')
            (primary if strong else secondary).append(result)
    return dict(cohort=dict(releasedSince=since.isoformat(), asOf=as_of.isoformat(),
                            incumbentBefore=incumbent_before.isoformat(), timezone=str(zone),
                            top=top, minPopularity=min_popularity),
                summary=dict(snapshots=len(snapshots_seen), primaryCases=len(primary),
                             primaryApps=len({r['appId'] for r in primary}),
                             primaryMarkets=len({r['store'] for r in primary}), secondaryCases=len(secondary)),
                primary=primary, secondary=secondary, skipped=skipped,
                interpretation='Sampled comparisons only. No hidden keywords, historical rise or causal ASO effect established.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    parser.add_argument('--released-since', type=date.fromisoformat, required=True)
    parser.add_argument('--as-of', type=date.fromisoformat, required=True)
    parser.add_argument('--incumbent-before', type=date.fromisoformat, required=True)
    parser.add_argument('--timezone', default='UTC')
    parser.add_argument('--top', type=int, default=5)
    parser.add_argument('--min-popularity', type=float, default=20)
    args = parser.parse_args()
    if args.top < 1 or args.min_popularity < 0:
        parser.error('Top must be positive and popularity threshold nonnegative.')
    try:
        result = analyze(json.loads(args.evidence.read_text()), args.released_since, args.as_of,
                         args.incumbent_before, ZoneInfo(args.timezone), args.top, args.min_popularity)
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.error(str(error))
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()

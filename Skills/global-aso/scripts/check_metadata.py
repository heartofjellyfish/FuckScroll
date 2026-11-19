#!/usr/bin/env python3
"""Validate locale fields and optionally compare actual store readback. No network."""
import argparse
import json
from pathlib import Path
import re
import unicodedata

FIELDS = ('name', 'subtitle', 'keywords')


def normalize(value):
    return unicodedata.normalize('NFKC', value).casefold()


def locales(document):
    rows = document.get('localizations', document)
    if isinstance(rows, list):
        if not rows:
            raise ValueError('Expected at least one localization.')
        result = {}
        for row in rows:
            if not isinstance(row, dict) or not isinstance(row.get('locale'), str):
                raise ValueError('Each localization row needs a locale string.')
            if row['locale'] in result:
                raise ValueError('Duplicate locale: ' + row['locale'])
            result[row['locale']] = row
        return result
    if not isinstance(rows, dict) or not rows:
        raise ValueError('Expected a nonempty locale map or localization rows.')
    return rows


def check(document, readback=None, keyword_budget=100, keyword_unit='bytes'):
    rows = locales(document)
    issues, counts = [], {}

    def add(level, locale, field, message):
        issues.append(dict(level=level, locale=locale, field=field, message=message))

    for locale, row in rows.items():
        if not isinstance(row, dict):
            add('error', locale, '*', 'Locale must contain a field object.')
            continue
        good = True
        for field in FIELDS:
            if not isinstance(row.get(field), str) or not row[field].strip():
                add('error', locale, field, 'Missing or empty string.')
                good = False
        if not good:
            continue
        sizes = {field: len(row[field]) for field in FIELDS}
        sizes['keywordBytes'] = len(row['keywords'].encode('utf-8'))
        counts[locale] = sizes
        for field in ('name', 'subtitle'):
            if sizes[field] > 30:
                add('error', locale, field, 'Over 30 Unicode code points; verify Apple acceptance.')
        used = sizes['keywordBytes'] if keyword_unit == 'bytes' else sizes['keywords']
        if used > keyword_budget:
            add('error', locale, 'keywords', f'Over configured {keyword_budget} {keyword_unit} budget.')
        tokens = row['keywords'].split(',')
        cleaned = [normalize(t.strip()) for t in tokens]
        if any(not token for token in cleaned):
            add('error', locale, 'keywords', 'Empty comma-separated token.')
        if len(cleaned) != len(set(cleaned)):
            add('error', locale, 'keywords', 'Duplicate normalized keyword token.')
        if any(t != t.strip() for t in tokens):
            add('warning', locale, 'keywords', 'Padding around tokens wastes space.')
        short = [t for t in tokens if t.isascii() and 0 < len(t.strip()) <= 2]
        if short:
            add('warning', locale, 'keywords', 'Review short ASCII terms for real intent: ' + ', '.join(short))
        # Whole Latin words only: do not split CJK into characters or pretend
        # that this lexical check establishes native indexing/stemming behavior.
        visible = set(re.findall(r'[^\W\d_]+', normalize(row['name'] + ' ' + row['subtitle'])))
        repeated = [t for t in cleaned if t in visible and any('LATIN' in unicodedata.name(c, '') for c in t)]
        if repeated:
            add('warning', locale, 'keywords', 'Already visible in name/subtitle: ' + ', '.join(repeated))
    if readback is not None:
        actual = locales(readback)
        for locale, row in rows.items():
            if locale not in actual:
                add('error', locale, '*', 'Locale missing from store readback.')
                continue
            for field in FIELDS:
                if not isinstance(row, dict) or actual[locale].get(field) != row.get(field):
                    add('error', locale, field, 'Store readback differs from approved source.')
        extras = sorted(set(actual) - set(rows))
        if extras:
            add('warning', '*', '*', 'Readback has additional, unchecked locales: ' + ', '.join(extras))
    return dict(valid=not any(i['level'] == 'error' for i in issues),
                localeCount=len(rows), keywordBudget=dict(value=keyword_budget, unit=keyword_unit),
                readbackCompared=readback is not None, counts=counts, issues=issues)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('metadata', type=Path)
    parser.add_argument('--readback', type=Path)
    parser.add_argument('--keyword-budget', type=int, default=100)
    parser.add_argument('--keyword-unit', choices=('bytes', 'characters'), default='bytes')
    args = parser.parse_args()
    if args.keyword_budget < 1:
        parser.error('Keyword budget must be positive.')
    try:
        document = json.loads(args.metadata.read_text())
        actual = json.loads(args.readback.read_text()) if args.readback else None
        result = check(document, actual, args.keyword_budget, args.keyword_unit)
    except (ValueError, OSError, AttributeError, TypeError) as error:
        parser.error(str(error))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['valid'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

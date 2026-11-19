#!/usr/bin/env python3
"""Validate a staged App Store localization file without changing the live listing."""
import argparse
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('listings', type=Path)
args = parser.parse_args()
listings = json.loads(args.listings.read_text())
limits = {'name': 30, 'subtitle': 30, 'keywords': 100, 'description': 4000, 'promotional_text': 170}
stopwords = {'de', 'di', 'do', 'da', 'd', 'e', 'et', 'mit', 'und', 'a', 'of', 'and', 'the', 'for', 'on'}
for locale, listing in listings.items():
    for field, limit in limits.items():
        value = listing[field]
        count = len(value.encode('utf-8')) if field == 'keywords' else len(value)
        assert value == value.strip() and 0 < count <= limit, (locale, field, count)
    tokens = listing['keywords'].split(',')
    assert all(t and t == t.strip() for t in tokens), locale
    assert len(tokens) == len(set(t.casefold() for t in tokens)), locale
    words = lambda text: set(re.findall(r'[^\W\d_]+', text.casefold()))
    indexed = words(listing['name'] + ' ' + listing['subtitle']) - stopwords
    repeated = {w for w in words(listing['keywords']) if w.isascii() and w in indexed and w not in stopwords}
    assert not repeated, (locale, sorted(repeated))
    assert len(listing['captions']) == 4 and all(listing['captions']), locale
print(f'PASS: {len(listings)} store localizations; field sizes, keywords and four captions')

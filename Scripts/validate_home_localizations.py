#!/usr/bin/env python3
"""Keep newly rotated home copy from silently falling back to English."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'ScrollStopper/App/HomeView.swift').read_text()
pattern = r'\("((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)"\)'
pairs = [[json.loads('"' + x + '"') for x in row] for row in re.findall(pattern, source)]
assert pairs, 'No home copy pairs found; update this coverage check if the format changes.'
strings = json.loads((root / 'ScrollStopper/Resources/Duck.xcstrings').read_text())['strings']
languages = ['en', 'zh-Hans', 'zh-Hant', 'es', 'fr', 'de', 'it', 'ja', 'ko', 'pt-BR']
for title, chinese_title, note, chinese_note in pairs:
    for key, chinese in [(title, chinese_title), (note, chinese_note)]:
        localized = strings[key]['localizations']
        for language in languages:
            unit = localized[language]['stringUnit']
            assert unit['value'].strip() and unit['state'] == 'translated', (key, language)
        assert localized['en']['stringUnit']['value'] == key
        assert localized['zh-Hans']['stringUnit']['value'] == chinese
print(f'PASS: {len(pairs)} home title/note pairs localized in {len(languages)} languages')

# Also cover the new picker labels and interruption actions exposed in the screenshots.
static_keys = set()
for file in (root / 'ScrollStopper').rglob('*.swift'):
    for english, _ in re.findall(r'(?:voice|v)\("((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"\)', file.read_text()):
        key = json.loads('"' + english + '"')
        static_keys.add(key)
        for language in languages:
            assert strings[key]['localizations'][language]['stringUnit']['value'].strip(), (file, key, language)
print(f'PASS: {len(static_keys)} literal voice keys have all ten translations')

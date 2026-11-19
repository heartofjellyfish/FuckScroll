#!/usr/bin/env python3
"""Check final ASO artifacts, actual coverage, and raw-source links without network calls."""
import json
from html.parser import HTMLParser
from pathlib import Path
import re
import unicodedata

ROOT=Path(__file__).resolve().parents[1]/'AppStore/ASO/next-release';OUT=ROOT/'deep-research'
load=lambda p:json.loads(p.read_text())
plan=load(OUT/'plan.json');meta=load(OUT/'metadata.json')['localizations'];summary=load(OUT/'summary.json')
assert len(plan['markets'])==175 and len({r['store'] for r in plan['markets']})==175
assert len(meta)==40


def norm(q):
    q=unicodedata.normalize('NFKC',q).replace('’',"'").replace('‘',"'").casefold()
    return re.sub(r'\s+','',q) if re.search('[가-힣]',q) else re.sub(r'\s+',' ',q).strip()


def research(row,astro):
    assert len(row['searches'])==8,row['store']
    assert len({norm(s['query']) for s in row['searches']})==8,row['store']
    assert all(not s.get('error') for s in row['searches']),row['store']
    if astro:
        assert len(row['metrics'])>=22,row['store']
        assert len({norm(k['keyword']) for k in row['metrics']})>=22,row['store']
        for metric in row['metrics']:
            assert 0<=metric['popularity']<=100 and 0<=metric['difficulty']<=100,(row['store'],metric)
    else:
        assert row['metrics']==[],row['store']
        assert row['source'].startswith('Apple'),row['store']
    for search in row['searches']:
        assert (ROOT/search['source']).exists(),search['source']
        assert len(search['apps'])<=5,(row['store'],search['query'])
        assert len({a['appStoreId'] for a in search['apps']})==len(search['apps'])
        for app in search['apps']:
            assert app['appStoreId'].isdigit() and app['name'],app
            if not astro:
                assert '/'+row['store']+'/' in app['trackViewUrl'],app
                assert 'ranking' not in app and app.get('subtitle') is None,app


for market in plan['markets']:
    row=load(OUT/'markets'/market['store']/'research.json')
    research(row,market['astroSupported'])
for study in plan['languageStudies']:
    research(load(OUT/'language-studies'/study['studyID']/'research.json'),True)
assert summary['complete'] and summary['astroDeepComplete']==91 and summary['catalogComplete']==84
assert summary['queryRecords']==1400 and summary['languageStudiesComplete']==4
existing=load(ROOT/'listings.json')
for locale,row in meta.items():
    for key in ['name','subtitle','keywords']:
        value=row[key];count=len(value.encode()) if key=='keywords' else len(value)
        assert value==value.strip() and 0<count<=(100 if key=='keywords' else 30),(locale,key,count)
        assert not any(unicodedata.category(c).startswith('C') for c in value),(locale,key,'control character')
        path=(ROOT/'metadata'/locale if locale in existing else OUT/'additional-localizations'/locale)/(key+'.txt')
        assert path.read_text().strip()==value,(locale,key,'unsynced file')
        if locale in existing:assert existing[locale][key]==value,(locale,key,'unsynced listing')
    tokens=row['keywords'].split(',')
    assert all(t and t==t.strip() for t in tokens)
    assert len(tokens)==len({t.casefold() for t in tokens})
    forbidden={'opal','screenzen','refocus','jomo','forest','brick','appblock','one sec','freedom'}
    assert not forbidden&{t.casefold() for t in tokens},locale


class Links(HTMLParser):
    def __init__(self):super().__init__();self.links=[];self.ids=[]
    def handle_starttag(self,tag,attrs):
        data=dict(attrs)
        if 'href' in data:self.links.append(data['href'])
        if 'id' in data:self.ids.append(data['id'])


pages=[ROOT/'index.html',OUT/'index.html']+list((OUT/'markets').glob('*/index.html'))+list((OUT/'language-studies').glob('*/index.html'))
for page in pages:
    parser=Links();parser.feed(page.read_text())
    for link in parser.links:
        if link.startswith(('https://','http://')):continue
        if link.startswith('#'):assert link[1:] in parser.ids,(page,link)
        else:assert (page.parent/link.split('#')[0]).exists(),(page,link)
mapping=load(OUT/'country-to-fields.json')['countries']
assert len(mapping)==175
for country in mapping:
    assert country['sharedDrafts'],country['store']
    for row in country['sharedDrafts']:
        for key in ['name','subtitle','keywords']:assert row[key]==meta[row['locale']][key]
print('PASS: 175 country records, 4 language studies, 40 field sets, 16 synchronized complete listings,',len(pages),'linked pages')

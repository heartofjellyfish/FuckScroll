#!/usr/bin/env python3
"""Find recent-launch competitors in country keyword results; keep provenance.
Astro ranks and public catalog positions are separate. No hidden keyword claims.
"""
import concurrent.futures
from datetime import datetime,date
from zoneinfo import ZoneInfo
import hashlib
import json
from pathlib import Path
import threading
import time
import urllib.parse
import urllib.request
import uuid

ROOT=Path(__file__).resolve().parents[1]/'AppStore/ASO/next-release';DEEP=ROOT/'deep-research';OUT=ROOT/'peer-cohort';OUT.mkdir(exist_ok=True)
PLAN=json.loads((DEEP/'plan.json').read_text());ASOF=date(2026,11,18);ZONE=ZoneInfo('America/Los_Angeles')
own=json.loads((OUT/'own-app-lookup.json').read_text())['response']['results'][0]
OWN_DATE=datetime.fromisoformat(own['releaseDate'].replace('Z','+00:00')).astimezone(ZONE).date()
LOCKS={'astro':threading.Lock(),'apple':threading.Lock()};LAST={'astro':0.,'apple':0.}


def pace(service):
    with LOCKS[service]:
        time.sleep(max(0,(2.5 if service=='astro' else 3.4)-(time.monotonic()-LAST[service])))
        LAST[service]=time.monotonic()


def unpack(raw):
    for block in raw.get('result',{}).get('content',[]):
        if block.get('type')=='text':
            try:return json.loads(block['text'])
            except ValueError:pass
    return {'error':str(raw.get('error','No JSON tool content'))}


def astro(args,path):
    if path.exists():
        cached=json.loads(path.read_text())
        if not unpack(cached).get('error'):return unpack(cached)
    pace('astro')
    request=urllib.request.Request('http://127.0.0.1:8089/mcp',data=json.dumps({'jsonrpc':'2.0','id':str(uuid.uuid4()),'method':'tools/call','params':{'name':'search_app_store','arguments':args}}).encode(),headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'})
    try:
        with urllib.request.urlopen(request,timeout=60) as response:raw=json.load(response)
        path.write_text(json.dumps(raw,ensure_ascii=False,indent=2)+'\n');return unpack(raw)
    except Exception as e:return {'error':str(e)}


KEEP={'trackId','trackName','trackViewUrl','artistName','artistId','bundleId','primaryGenreName','genres','releaseDate','currentVersionReleaseDate','version','averageUserRating','userRatingCount','price','currency','descriptionSHA256'}


def apple(params,path):
    if path.exists():return json.loads(path.read_text())
    pace('apple')
    url='https://itunes.apple.com/'+('lookup?' if 'id' in params else 'search?')+urllib.parse.urlencode(params)
    result={'requestURL':url}
    try:
        with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Duck-ASO-Research/1.0'}),timeout=40) as response:body=json.load(response)
        result['resultCount']=body.get('resultCount');result['apps']=[]
        for value in body.get('results',[]):
            if not value.get('trackId'):continue
            # Working excerpts for classifying product scope, never published as full descriptions.
            description=value.get('description','')
            working=Path('/tmp/duck-peer-descriptions');working.mkdir(exist_ok=True)
            (working/(str(value['trackId'])+'.txt')).write_text(description)
            fact={k:v for k,v in value.items() if k in KEEP}
            fact['descriptionSHA256']=hashlib.sha256(description.encode()).hexdigest();result['apps'].append(fact)
    except Exception as e:result['error']=str(e)
    path.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');return result


inventory={};observations=[];metadata={}


def record(app,store,query,kind,source,position):
    appid=str(app.get('appStoreId',app.get('trackId','')))
    if not appid.isdigit() or appid=='6832822647':return
    entry=inventory.setdefault(appid,{'appId':appid,'names':set(),'stores':set()})
    entry['names'].add(app.get('name',app.get('trackName','')));entry['stores'].add(store)
    observations.append({'appId':appid,'store':store,'keyword':query,'position':position,'evidenceType':kind,
                         'name':app.get('name',app.get('trackName','')),'subtitle':app.get('subtitle'),
                         'ratingCount':app.get('ratingCount',app.get('userRatingCount')),'source':source})


for path in (DEEP/'markets').glob('*/research.json'):
    row=json.loads(path.read_text())
    for search in row['searches']:
        for n,app in enumerate(search['apps'],1):record(app,row['store'],search['query'],'astro' if row['astroSupported'] else 'catalog',str(path.relative_to(ROOT)),app.get('ranking',app.get('catalogPosition',n)))
for path in (DEEP/'markets').glob('*/raw/catalog-*.json'):
    for app in json.loads(path.read_text()).get('response',{}).get('results',[]):
        if app.get('releaseDate'):metadata[str(app['trackId'])]=app


def enrich(apps):
    missing=[a for a in apps if a not in metadata];lookup=OUT/'lookups';lookup.mkdir(exist_ok=True)
    for offset in range(0,len(missing),100):
        ids=missing[offset:offset+100];key=hashlib.sha256(','.join(sorted(ids)).encode()).hexdigest()[:12]
        value=apple({'id':','.join(ids),'country':'us'},lookup/('us-'+key+'.json'))
        for app in value.get('apps',[]):metadata[str(app['trackId'])]=app
    # An app can be local-only; use a country where it was actually observed.
    groups={}
    for appid in missing:
        if appid not in metadata:
            stores=inventory[appid]['stores'];store=next((x for x in ['cn','jp','kr','ru','tw','fr','de','es','gb'] if x in stores),sorted(stores)[0])
            groups.setdefault(store,[]).append(appid)
    for store,ids in groups.items():
        for offset in range(0,len(ids),100):
            chunk=ids[offset:offset+100];key=hashlib.sha256(','.join(sorted(chunk)).encode()).hexdigest()[:12]
            value=apple({'id':','.join(chunk),'country':store},lookup/(store+'-'+key+'.json'))
            for app in value.get('apps',[]):metadata[str(app['trackId'])]=app
    print('DATES',len(apps),len(set(apps)&set(metadata)),flush=True)


def select_queries(market):
    row=json.loads((DEEP/'markets'/market['store']/'research.json').read_text())
    scores={k['keyword']:k for k in row.get('metrics',[])}
    local=PLAN['packs'][market['languages'][0]][:3]
    core=list(dict.fromkeys(local+['app blocker','screen time','screen time control','scroll blocker']))
    ranked=sorted(core,key=lambda q:(-scores.get(q,{}).get('popularity',0),scores.get(q,{}).get('difficulty',100)))
    selected=ranked[:1]
    native=next((q for q in ranked[1:] if q in local and scores.get(q,{}).get('popularity',0)>5),None)
    selected.append(native or next(q for q in ranked if q not in selected))
    # For unsupported countries, begin with a local phrase and the actual function category.
    if not market['astroSupported']:selected=list(dict.fromkeys([local[0],'app blocker','screen time']))[:2]
    return selected


def discover(market):
    store=market['store'];directory=OUT/'discovery'/store;directory.mkdir(parents=True,exist_ok=True);records=[]
    for query in select_queries(market):
        key=hashlib.sha256(query.encode()).hexdigest()[:12]
        if market['astroSupported']:
            path=directory/(key+'.json');value=astro({'keyword':query,'store':store,'platform':'iphone','limit':20,'appId':'6832822647'},path)
            apps=value.get('apps',[]);error=value.get('error');kind='astro'
        else:
            path=directory/(key+'.json');value=apple({'term':query,'country':store,'entity':'software','limit':20},path)
            apps=value.get('apps',[]);error=value.get('error');kind='catalog'
        records.append({'store':store,'keyword':query,'evidenceType':kind,'apps':apps,'error':error,'source':str(path.relative_to(ROOT))})
    (directory/'searches.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
    print(store,'DISCOVERY',[(r['keyword'],len(r['apps']),r['error']) for r in records],flush=True);return records


# Dates of already observed candidates are fetched while the broader rank window runs.
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as outer:
    early=outer.submit(enrich,list(inventory))
    def block(supported):
        markets=[m for m in PLAN['markets'] if m['astroSupported']==supported]
        priority=['us','cn','gb','ca','au','jp','kr','fr','de','es','mx','br','it','pt','nl','ru','se']
        markets.sort(key=lambda m:priority.index(m['store']) if m['store'] in priority else 1000)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:return list(executor.map(discover,markets))
    native=outer.submit(block,True);catalog=outer.submit(block,False)
    early.result();all_records=native.result()+catalog.result()
for batch in all_records:
    for row in batch:
        for n,app in enumerate(row['apps'],1):record(app,row['store'],row['keyword'],row['evidenceType'],row['source'],app.get('ranking',n))
for path in (OUT/'targeted').glob('*.json'):
    value=json.loads(path.read_text());response=unpack(value['response'])
    for n,app in enumerate(response.get('apps',[]),1):
        record(app,value['store'],value['keyword'],'astro',str(path.relative_to(ROOT)),app.get('ranking',n))
enrich(list(inventory))
# Storefront release dates can differ. Prefer the earliest PUBLICLY OBSERVED
# date across the collected facts, rather than labeling a local relaunch new.
date_sources=[];release_evidence={}
for path in (DEEP/'markets').glob('*/raw/catalog-*.json'):
    date_sources.extend((app,path) for app in json.loads(path.read_text()).get('response',{}).get('results',[]))
for path in (OUT/'lookups').glob('*.json'):
    date_sources.extend((app,path) for app in json.loads(path.read_text()).get('apps',[]))
for path in (OUT/'verified-products').glob('*.json'):
    date_sources.append((json.loads(path.read_text()),path))
for app,path in date_sources:
    appid=str(app.get('trackId',''));release=app.get('releaseDate')
    if appid in inventory and release and release<=release_evidence.get(appid,{}).get('releaseDate','9999'):
        release_evidence[appid]={'releaseDate':release,'source':str(path.relative_to(ROOT))}
    if appid in inventory and release and release<metadata.get(appid,{}).get('releaseDate','9999'):
        metadata[appid]=app
cohort=[]
for appid,entry in inventory.items():
    app=metadata.get(appid,{})
    release=app.get('releaseDate')
    if not release:continue
    try:released=datetime.fromisoformat(release.replace('Z','+00:00')).astimezone(ZONE).date()
    except ValueError:continue
    gap=(released-OWN_DATE).days
    if released<=ASOF and released.year==2026:
        cohort.append(dict(appId=appid,names=sorted(entry['names']),stores=sorted(entry['stores']),releaseDate=release,
                           releaseClientDate=str(released),daysFromOurRelease=gap,tier='within30days' if abs(gap)<=30 else ('31to90days' if abs(gap)<=90 else '2026-earlier'),
                           releaseDateEvidence=release_evidence.get(appid),
                           metadata=app,observations=[r for r in observations if r['appId']==appid],
                           featureReview='Pending product-scope review; date proximity alone does not establish comparability.'))
result={'ourApp':own,'ourFirstReleaseClientDate':str(OWN_DATE),'asOfClientDate':str(ASOF),'timezone':'America/Los_Angeles',
        'method':'User revision: 2026 original releases, comparable functionality and strong rank ahead of established apps matter more than proximity to our launch. Current observed apps -> verify releaseDate, not update date -> feature review -> same-store/query/snapshot ranking comparisons. Top20 expansion plus prior eight-query evidence. Catalog positions are not native ranks.',
        'candidateAppsObserved':len(inventory),'appsWithReleaseMetadata':len(metadata),'candidateCohort':cohort,
        'discoveryErrors':[{'store':r['store'],'keyword':r['keyword'],'error':r['error']} for batch in all_records for r in batch if r['error']],
        'limitations':['No access to competitor hidden keyword fields, downloads, acquisition spend or brand age.','Current public metadata is correlated with current positions; no proof that a title caused a rank.','No observed rank within the sampled window is not proof that the app is unindexed.']}
(OUT/'app-metadata.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
(OUT/'observations.json').write_text(json.dumps(observations,ensure_ascii=False,indent=2)+'\n')
(OUT/'cohort-candidates.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('FINISHED',len(inventory),'apps;',len(cohort),'date-matched candidates;',len(result['discoveryErrors']),'errors',flush=True)

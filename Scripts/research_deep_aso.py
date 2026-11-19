#!/usr/bin/env python3
"""Resumable country research; raw provenance preserved, Apple metadata never changed."""
import argparse
import concurrent.futures
from datetime import datetime, timezone
import hashlib
import json
import re
from pathlib import Path
import threading
import time
import urllib.parse
import urllib.request
import uuid
import unicodedata

ROOT=Path(__file__).resolve().parents[1]/'AppStore/ASO/next-release'
OUT=ROOT/'deep-research';PLAN=json.loads((OUT/'plan.json').read_text())
P=argparse.ArgumentParser(description=__doc__);P.add_argument('mode',choices=['astro','catalog','studies']);P.add_argument('--workers',type=int,default=4);A=P.parse_args()
LOCK=threading.Lock();LAST=0


def pace(seconds):
    global LAST
    with LOCK:
        time.sleep(max(0,seconds-(time.monotonic()-LAST)))
        LAST=time.monotonic()


def unpack(raw):
    for b in raw.get('result',{}).get('content',[]):
        if b.get('type')=='text':
            try:return json.loads(b['text'])
            except ValueError:
                if raw['result'].get('isError'):return {'error':b['text']}
    return {'error':str(raw.get('error','Empty tool response'))}


def rpc(name,args,path):
    for attempt in range(2):
        pace(2.5)
        request=urllib.request.Request('http://127.0.0.1:8089/mcp',data=json.dumps({
            'jsonrpc':'2.0','id':str(uuid.uuid4()),'method':'tools/call','params':{'name':name,'arguments':args}}).encode(),
            headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'})
        try:
            with urllib.request.urlopen(request,timeout=55) as response:raw=json.load(response)
            path.write_text(json.dumps(raw,ensure_ascii=False,indent=2)+'\n')
            value=unpack(raw)
            if value.get('error') and 'rate limit' in value['error'].lower() and attempt==0:
                time.sleep(35);continue
            return value
        except Exception as error:
            if attempt: return {'error':str(error)}
    return {'error':'Retries exhausted'}


def known_metrics(store):
    known={}
    sources=[ROOT/'all-storefronts'/f'{store}.json']
    for path in sources:
        if path.exists():
            d=json.loads(path.read_text());known.update({k['keyword']:k for k in d.get('keywords',[])})
    # Cached tracked responses can contain more candidates than the first audit.
    paths=list((ROOT/'all-storefronts/raw').glob(store+'-*tracked*.json'))
    if store=='cn':paths += [ROOT/'china-deep-dive/raw/tracked-keywords.json']
    for path in paths:
        d=unpack(json.loads(path.read_text()));known.update({k['keyword']:k for k in d.get('keywords',[])})
    return known


def cache_searches(store):
    found={}
    old=ROOT/'all-storefronts'/f'{store}.json'
    if old.exists():
        d=json.loads(old.read_text());q=d.get('selectedKeyword',{}).get('keyword')
        if q and len(d.get('top5',[]))>=5:found[q]={'apps':d['top5'],'source':str(old.relative_to(ROOT))}
    paths=list((ROOT/'top5').glob(store+'-*.json'))
    if store=='cn':paths+=list((ROOT/'china-deep-dive/raw').glob('*.json'))
    for path in paths:
        d=json.loads(path.read_text());q=d.get('query')
        if q:
            result=unpack(d.get('response',{}))
            if len(result.get('apps',[]))>=5:found[q]={'apps':result['apps'][:5],'source':str(path.relative_to(ROOT))}
    return found


BROAD=set('focus|stay focused|self control|screen time tracker|parental control|app lock|concentration|contrôle parental|fokus|konzentration|selbstkontrolle|kindersicherung|app sperre|handy sperren|concentración|autocontrol|control parental|concentrazione|autocontrollo|controllo parentale|foco|autocontrole|controle parental|concentração|autocontrolo|controlo parental|集中|自制心|ペアレンタルコントロール|집중|자기 통제|자녀 보호|앱 잠금|concentratie|zelfcontrole|ouderlijk toezicht|фокус|концентрация|самоконтроль|родительский контроль|koncentration|självkontroll|föräldrakontroll|تركيز|التحكم بالنفس|الرقابة الأبوية|قفل التطبيقات|odaklanma|odak|öz kontrol|ebeveyn kontrolü|uygulama kilidi|ध्यान केंद्रित|आत्म नियंत्रण|ऐप लॉक|konsentrasi|kontrol diri|kontrol orang tua|kunci aplikasi|tumpuan|kawalan diri|kawalan ibu bapa|สมาธิ|โฟกัส|ควบคุมตัวเอง|ควบคุมโดยผู้ปกครอง|ล็อกแอป|tập trung|tự kiểm soát|kiểm soát của cha mẹ|khóa ứng dụng|skupienie|koncentracja|samokontrola|kontrola rodzicielska|blokada telefonu|soustředění|koncentrace|sebekontrola|rodičovská kontrola|zámek aplikací|selvkontrol|forældrekontrol|app lås|keskittyminen|keskittymiskyky|itsehillintä|lapsilukko|sovelluslukko|konsentrasjon|selvkontroll|foreldrekontroll|applås|συγκέντρωση|εστίαση|αυτοέλεγχος|γονικός έλεγχος|κλείδωμα εφαρμογών|ריכוז|מיקוד|שליטה עצמית|בקרת הורים|נעילת אפליקציות|fókusz|koncentráció|önkontroll|szülői felügyelet|alkalmazászár|concentrare|focalizare|control parental|blocare telefon|sústredenie|koncentrácia|sebakontrola|rodičovská kontrola|zámok aplikácií|концентрація|самоконтроль|батьківський контроль|concentració|koncentracija|roditeljski nadzor|zaključavanje aplikacija|专注|自律|时间管理|锁机|專注|自律|鎖手機|時間管理'.split('|'))

BROAD.update(['starševski nadzor','zbranost','koncentracija','samokontrola','zaklepanje aplikacij'])

def queries(market,metrics):
    by={k['keyword']:k for k in metrics}
    ranked=sorted(metrics,key=lambda k:(-k.get('popularity',0),k.get('difficulty',100)))
    core=[k for k in ranked if k['keyword'] not in BROAD]
    frontier=[k for k in core if k.get('popularity',0)>5 and not any(
        o['popularity']>=k['popularity'] and o['difficulty']<=k['difficulty']
        and (o['popularity']>k['popularity'] or o['difficulty']<k['difficulty']) for o in core)]
    selected=[]
    def add(q):
        if q in by and qnorm(q) not in {qnorm(s) for s in selected}:selected.append(q)
    add(PLAN['packs'][market['languages'][0]][0])
    for k in core[:3]:add(k['keyword'])
    for k in sorted(frontier,key=lambda k:k['difficulty'])[:2]:add(k['keyword'])
    broad=[k for k in ranked if k['keyword'] in BROAD]
    if broad:add(broad[0]['keyword'])
    # At least one primary-language core query and one second-language query.
    for lang in market['languages'][1:]:add(PLAN['packs'][lang][0])
    for k in core:
        if len(selected)>=8:break
        add(k['keyword'])
    for q in market['candidates']:
        if len(selected)>=8:break
        add(q)
    return selected[:8]


def qnorm(q):
    q=unicodedata.normalize('NFKC',q).replace('’',"'").replace('‘',"'").casefold()
    return re.sub(r'\s+','',q) if re.search('[가-힣]',q) else re.sub(r'\s+',' ',q).strip()


def astro(market):
    store=market['store'];directory=OUT/('language-studies' if market.get('studyID') else 'markets')/market.get('studyID',store);(directory/'raw').mkdir(parents=True,exist_ok=True)
    dest=directory/'research.json'
    if dest.exists():
        old=json.loads(dest.read_text())
        if old.get('status')=='deep-astro-complete' and len({qnorm(s['query']) for s in old.get('searches',[])})>=8:return old
    result=dict(market,startedAt=datetime.now(timezone.utc).isoformat(),source='Astro MCP, iPhone storefront')
    known=known_metrics(store)
    checkpoint=directory/'metrics.json'
    if checkpoint.exists():known.update({k['keyword']:k for k in json.loads(checkpoint.read_text())})
    missing=[q for q in market['candidates'] if q not in known]
    if missing:
        value=rpc('add_keywords',{'appId':'6832822647','platform':'iphone','store':store,'keywords':missing},directory/'raw/add.json')
        if value.get('error'):
            result.update(status='metrics-unavailable',error=value['error']);dest.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(store,result['status'],flush=True);return result
        for k in value.get('results',[]):
            if k.get('success') and not k.get('skipped'):known[k['keyword']]=k
        if any(k.get('skipped') for k in value.get('results',[])):
            value=rpc('get_app_keywords',{'appId':'6832822647','platform':'iphone','store':store},directory/'raw/tracked.json')
            known.update({k['keyword']:k for k in value.get('keywords',[])})
    metrics=[known[q] for q in market['candidates'] if q in known]
    checkpoint.write_text(json.dumps(metrics,ensure_ascii=False,indent=2)+'\n')
    result['metrics']=metrics;result['queries']=queries(market,metrics);result['searches']=[]
    cache=cache_searches(store)
    for q in result['queries']:
        key=hashlib.sha256(q.encode()).hexdigest()[:12];raw=directory/'raw'/f'search-{key}.json'
        if raw.exists():
            value=unpack(json.loads(raw.read_text()));source=str(raw.relative_to(ROOT))
            if value.get('error'):
                value=rpc('search_app_store',{'appId':'6832822647','platform':'iphone','store':store,'keyword':q,'limit':5},raw)
        elif q in cache:value=cache[q];source=value['source']
        else:
            value=rpc('search_app_store',{'appId':'6832822647','platform':'iphone','store':store,'keyword':q,'limit':5},raw)
            source=str(raw.relative_to(ROOT))
        apps=value.get('apps',[])[:5]
        result['searches'].append(dict(query=q,apps=apps,source=source,error=value.get('error'),
                                       purpose='Intent comparator; not a claim this app provides that feature' if q in BROAD else 'Functional search hypothesis'))
        result['status']='in-progress';dest.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    full=sum(len(s['apps'])==5 for s in result['searches'])
    result.update(status='deep-astro-complete' if len(metrics)>=22 and len(result['searches'])>=8 and all(not s.get('error') for s in result['searches']) else 'deep-astro-partial',completedAt=datetime.now(timezone.utc).isoformat(),fullTop5Queries=full,
                  limitation='Popularity/difficulty are tool estimates, not search counts. Missing subtitles remain missing. Broad or password-lock/parental-control intent is compared, never copied as an unsupported feature.')
    dest.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(store,result['status'],len(metrics),'metrics',full,'top5',flush=True);return result


def catalog(market):
    store=market['store'];directory=OUT/'markets'/store;(directory/'raw').mkdir(parents=True,exist_ok=True)
    dest=directory/'research.json'
    if dest.exists():
        old=json.loads(dest.read_text())
        if old.get('status')=='catalog-only-complete' and {s['query'] for s in old.get('searches',[])}==set(market['catalogQueries']):return old
    result=dict(market,source='Apple public software catalog search; not native App Store SERP or Astro metrics',
                metrics=[],searches=[],status='in-progress')
    for q in market['catalogQueries']:
        key=hashlib.sha256(q.encode()).hexdigest()[:12];path=directory/'raw'/f'catalog-{key}.json'
        url='https://itunes.apple.com/search?'+urllib.parse.urlencode({'term':q,'country':store,'entity':'software','limit':5})
        error=None;body={}
        if path.exists():
            envelope=json.loads(path.read_text());body=envelope.get('response',{});error=envelope.get('error')
        else:
            pace(3.3)
            try:
                with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Duck-ASO-Research/1.0'}),timeout=35) as r:body=json.load(r)
            except Exception as e:error=str(e)
            if not isinstance(body.get('resultCount'),int) and not error:error='Apple catalog returned no valid resultCount'
            keep={'trackId','trackName','trackViewUrl','artistName','bundleId','primaryGenreName','genres','averageUserRating','userRatingCount','releaseDate','currentVersionReleaseDate','version','descriptionSHA256','price','currency','kind','wrapperType'}
            for app in body.get('results',[]):
                if 'description' in app:app['descriptionSHA256']=hashlib.sha256(app.pop('description').encode()).hexdigest()
                for field in list(app):
                    if field not in keep:app.pop(field)
            path.write_text(json.dumps({'requestURL':url,'response':body,'error':error,'omittedFields':['description: full marketing prose omitted; factual metadata and SHA256 retained']},ensure_ascii=False,indent=2)+'\n')
        apps=[]
        for position,a in enumerate(body.get('results',[])[:5],1):
            link=a.get('trackViewUrl','')
            if '/'+store+'/' not in link:
                error='Country mismatch in public catalog response';continue
            apps.append({'appStoreId':str(a.get('trackId')),'name':a.get('trackName'),
                         'catalogPosition':position,'subtitle':None,'averageRating':a.get('averageUserRating'),
                         'ratingCount':a.get('userRatingCount'),'trackViewUrl':link})
        result['searches'].append(dict(query=q,apps=apps,source=str(path.relative_to(ROOT)),error=error))
        dest.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    result['status']='catalog-only-complete' if len(result['searches'])>=8 and all(not s['error'] for s in result['searches']) else 'catalog-partial'
    result['completedAt']=datetime.now(timezone.utc).isoformat()
    result['limitation']='Astro rejects this storefront. No local popularity/difficulty, no native keyword ranks, and public catalog does not return subtitles. Result count may be under five. Locale decisions require explicitly labelled language-anchor evidence.'
    dest.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(store,result['status'],[(q['query'],len(q['apps'])) for q in result['searches']],flush=True);return result


markets=PLAN.get('languageStudies',[]) if A.mode=='studies' else [m for m in PLAN['markets'] if m['astroSupported']==(A.mode=='astro')]
priority=['us','gb','ca','au','cn','tw','hk','jp','kr','de','fr','es','mx','it','br','pt','nl','ru','se','sa','tr','in','id','my','th','vn','pl','cz','dk','fi','no','gr','il','hu','ro','sk','ua','hr','be','ch','sg']
markets.sort(key=lambda m:priority.index(m['store']) if m['store'] in priority else 1000)
with concurrent.futures.ThreadPoolExecutor(max_workers=A.workers) as executor:
    results=list(executor.map(catalog if A.mode=='catalog' else astro,markets))
(OUT/f'{A.mode}-summary.json').write_text(json.dumps({'mode':A.mode,'results':[{'store':r['store'],'status':r['status']} for r in results]},ensure_ascii=False,indent=2)+'\n')
print('FINISHED',A.mode,len(results),flush=True)

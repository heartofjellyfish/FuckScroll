#!/usr/bin/env python3
"""Audit three-field ASO candidates across Apple's storefront list through local Astro MCP.
Keeps cached evidence, paces requests below Astro's 30/min cap, and records failures.
Does not modify App Store Connect metadata. Adds keyword tracking in Astro.
"""
import argparse,concurrent.futures,hashlib,json,re,threading,time,urllib.request,uuid
from pathlib import Path
P=argparse.ArgumentParser(description=__doc__);P.add_argument('--endpoint',default='http://127.0.0.1:8089/mcp');P.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]/'AppStore/ASO/next-release');A=P.parse_args();OUT=A.root/'all-storefronts';(OUT/'raw').mkdir(exist_ok=True)
STORES=json.loads((OUT/'storefronts.json').read_text());METRICS=json.loads((A.root/'market-evidence.json').read_text())['metrics']
SEEDS={
'English':['app blocker','screen time','screen time control','scroll blocker','stop scrolling'],
'French':["temps d'écran",'bloqueur application','concentration','app blocker','screen time'],
'German':['app blocker','bildschirmzeit','apps sperren','digital detox'],
'Italian':['tempo di utilizzo','blocco app','blocca app','app blocker'],
'Spanish (Spain)':['bloquear aplicaciones','tiempo de pantalla','bloqueador de apps','limitar aplicaciones'],
'Spanish (Mexico)':['bloquear aplicaciones','tiempo en pantalla','tiempo de pantalla','limitar apps'],
'Portuguese (Brazil)':['tempo de tela','bloquear aplicativos','bloqueador de aplicativos','limite de uso'],
'Portuguese (Portugal)':['tempo de ecrã','screen time','app blocker','bloquear aplicações'],
'Japanese':['スマホ制限','スクリーンタイム','アプリ制限','デジタルデトックス'],
'Korean':['스크린타임','앱차단','사용시간 제한','디지털 디톡스'],
'Simplified Chinese':['屏幕使用时间','戒手机','防沉迷','少刷手机'],
'Chinese (Traditional)':['螢幕使用時間','戒手機','app blocker','screen time'],
'Dutch':['schermtijd','app blocker','apps blokkeren','schermtijd beperken','stop scrollen'],
'Russian':['экранное время','блокировка приложений','таймер приложений','цифровой детокс','app blocker'],
'Swedish':['skärmtid','app blocker','blockera appar','digital detox','sluta scrolla']}
# An explicit relevance gate precedes the popularity/difficulty comparison.
RELEVANCE={'concentration':3,'blocco app':3,'blocca app':3,'bloquear aplicaciones':4,'apps sperren':4,'блокировка приложений':3,'防沉迷':4,'scroll blocker':4}
LOCK=threading.Lock();LAST=0

def rpc(tool,args):
 global LAST
 with LOCK:
  wait=max(0,2.4-(time.monotonic()-LAST))
  if wait:time.sleep(wait)
  LAST=time.monotonic()
 req=urllib.request.Request(A.endpoint,data=json.dumps({'jsonrpc':'2.0','id':str(uuid.uuid4()),'method':'tools/call','params':{'name':tool,'arguments':args}}).encode(),headers={'Content-Type':'application/json','Accept':'application/json, text/event-stream'})
 with urllib.request.urlopen(req,timeout=70) as r:d=json.load(r)
 for b in d.get('result',{}).get('content',[]):
  if b.get('type')=='text':
   try:return json.loads(b['text']),d
   except:pass
 if d.get('result',{}).get('isError'):
  return {'error':str(d['result'].get('content',[]))},d
 return {},d

def choose(items):
 valid=[k for k in items if k.get('popularity',0)>5 and RELEVANCE.get(k['keyword'],5)>=4]
 max_pop=max((k['popularity'] for k in valid),default=0)
 sweet=[k for k in valid if k['popularity']>=max(25,0.60*max_pop) and k.get('difficulty',100)<=35]
 if sweet:return max(sweet,key=lambda k:(k['popularity'],-k.get('difficulty',100))), 'sweet-spot heuristic: popularity≥max(25,60% of local best), difficulty≤35, relevance≥4; not a conversion prediction'
 if valid:return max(valid,key=lambda k:(k['popularity'],-k.get('difficulty',100))), 'no qualifying sweet spot; popularity first, difficulty as tie-break'
 fallback=[k for k in items if RELEVANCE.get(k['keyword'],5)>=4]
 return (max(fallback,key=lambda k:(k.get('popularity',0),-k.get('difficulty',100))) if fallback else None),'low-data market; relevance-first provisional, not a proven sweet spot'

def cached_search(store,q):
 for p in (A.root/'top5').glob(store+'-*.json'):
  d=json.loads(p.read_text())
  if d.get('query')==q:
   for c in d.get('response',{}).get('result',{}).get('content',[]):
    if c.get('type')=='text':
     try:v=json.loads(c['text'])
     except:continue
     if len(v.get('apps',[]))>=5:return v
 return None

def work(country):
 store=country['store'];dest=OUT/(store+'.json')
 if dest.exists():
  d=json.loads(dest.read_text())
  if d.get('status')=='completed':return d
 seeds=SEEDS.get(country['defaultLanguage'],SEEDS['English']);known={k['keyword']:k for k in METRICS.get(store,[]) if k.get('popularity',0)>0};result=dict(country,seeds=seeds,endpoint=A.endpoint)
 try:
  missing=[q for q in seeds if q not in known]
  if missing:
   v,raw=rpc('add_keywords',{'appId':'6832822647','platform':'iphone','store':store,'keywords':missing});(OUT/'raw'/(store+'-metrics.json')).write_text(json.dumps(raw,ensure_ascii=False,indent=2))
   if v.get('error'):raise RuntimeError(v['error'])
   for k in v.get('results',[]):
    if k.get('success') and not k.get('skipped'):known[k['keyword']]=k
   # Previously tracked terms must be read, not interpreted as zero-demand results.
   if any(k.get('skipped') for k in v.get('results',[])):
    v,raw=rpc('get_app_keywords',{'appId':'6832822647','platform':'iphone','store':store});(OUT/'raw'/(store+'-tracked.json')).write_text(json.dumps(raw,ensure_ascii=False,indent=2));known.update({k['keyword']:k for k in v.get('keywords',[])})
  result['keywords']=[known[q] for q in seeds if q in known];best,rule=choose(result['keywords']);result.update(selectedKeyword=best,selectionRule=rule)
  if not best:raise RuntimeError('No measurable keyword data returned')
  v=cached_search(store,best['keyword'])
  if v is None:
   v,raw=rpc('search_app_store',{'keyword':best['keyword'],'store':store,'platform':'iphone','limit':5,'appId':'6832822647'});(OUT/'raw'/(store+'-search.json')).write_text(json.dumps(raw,ensure_ascii=False,indent=2))
  if v.get('error'):raise RuntimeError(v['error'])
  result.update(top5=v.get('apps',[])[:5],yourAppRanking=v.get('yourAppRanking'))
  if len(result['top5'])<5:result['status']='insufficient-results'
  else:result['status']='completed'
 except Exception as e:result.update(status='data-unavailable',error=str(e))
 dest.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(store,result['status'],result.get('selectedKeyword',{}),flush=True);return result

with concurrent.futures.ThreadPoolExecutor(max_workers=3) as ex:results=list(ex.map(work,STORES))
(OUT/'audit.json').write_text(json.dumps({'endpoint':A.endpoint,'scope':'All175 storefronts from Apple public localization reference; actual per-app availability must still be read from App Store Connect.','method':'heuristic thresholds, not a calibrated conversion model; hidden competitor keywords unavailable','results':results},ensure_ascii=False,indent=2)+'\n')
print('FINISHED',len(results),{s:sum(r['status']==s for r in results) for s in set(r['status'] for r in results)},flush=True)

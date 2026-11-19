#!/usr/bin/env python3
"""Render provenance-aware country research and coordinated localized metadata."""
from collections import Counter
from datetime import datetime,timezone
import html
import json
from pathlib import Path
import re
import unicodedata

ROOT=Path(__file__).resolve().parents[1]/'AppStore/ASO/next-release';OUT=ROOT/'deep-research'
PLAN=json.loads((OUT/'plan.json').read_text());META=json.loads((OUT/'metadata.json').read_text())
ESC=lambda value:html.escape(str(value))
CSS='body{max-width:1150px;margin:44px auto;padding:0 24px 48px;background:#fcf6e6;color:#191916;font:16px/1.65 -apple-system,sans-serif}h1{font-size:40px;line-height:1.15;letter-spacing:-.6px}h2{margin-top:38px}table{border-collapse:collapse;width:100%;font-size:14px}td,th{text-align:left;vertical-align:top;border-bottom:1px solid #c8bfad;padding:12px;overflow-wrap:anywhere}th{white-space:nowrap}.note{background:#fed336;padding:20px;border:2px solid;border-radius:8px}.muted,small{color:#6e6557}.tag{font-size:12px;border:1px solid;padding:3px 7px;border-radius:5px;white-space:nowrap}a{color:inherit}code{white-space:pre-wrap;overflow-wrap:anywhere}details{border-top:1px solid #c8bfad;padding:15px 0}summary{cursor:pointer;font-weight:600}nav{display:flex;flex-wrap:wrap;gap:16px;margin:22px 0}.scroll{overflow-x:auto}input{font:inherit;background:transparent;border:2px solid;border-radius:6px;padding:12px;width:min(600px,90%)}.numbers{display:flex;flex-wrap:wrap;gap:12px}.numbers p{border:1px solid;padding:14px;flex:1;min-width:180px}.numbers b{font-size:28px;display:block}'


def header(title):
    return f'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>{ESC(title)}</title><style>{CSS}</style>'


def quality(row):
    searches=row.get('searches',[]);errors=[s for s in searches if s.get('error')]
    def normalized(q):
        q=unicodedata.normalize('NFKC',q).replace('’',"'").replace('‘',"'").casefold()
        return re.sub(r'\s+','',q) if re.search('[가-힣]',q) else re.sub(r'\s+',' ',q).strip()
    distinct=len({normalized(s['query']) for s in searches})
    if row.get('source','').startswith('Apple'):
        return '目录补充完成；无热度／自然排名' if distinct>=8 and not errors else '目录补充待重试'
    return '深查完成' if len(row.get('metrics',[]))>=22 and distinct>=8 and not errors else '深查待补全'


LANG={'en':'en-GB','fr':'fr-FR','de':'de-DE','es':'es-MX','it':'it','pt-BR':'pt-BR','pt-PT':'pt-PT','ja':'ja','ko':'ko','zh-Hans':'zh-Hans','zh-Hant':'zh-Hant','nl':'nl-NL','ru':'ru','sv':'sv','ar':'ar-SA','tr':'tr','hi':'hi','id':'id','ms':'ms','th':'th','vi':'vi','pl':'pl','cs':'cs','da':'da','fi':'fi','no':'no','el':'el','he':'he','hu':'hu','ro':'ro','sk':'sk','uk':'uk','ca':'ca','hr':'hr','sl':'sl'}
DEFAULT={'English (US)':'en-US','English (U.K.)':'en-GB','English (Australia)':'en-AU','English (Canada)':'en-CA','French':'fr-FR','German':'de-DE','Italian':'it','Spanish (Spain)':'es-ES','Spanish (Mexico)':'es-MX','Portuguese (Brazil)':'pt-BR','Portuguese (Portugal)':'pt-PT','Japanese':'ja','Korean':'ko','Simplified Chinese':'zh-Hans','Chinese (Traditional)':'zh-Hant','Dutch':'nl-NL','Russian':'ru','Swedish':'sv'}


def locale_links(market,prefix=''):
    codes=[DEFAULT[market['defaultLanguage']]]+[LANG[k] for k in market['languages']]
    if market['store']=='ca':codes+=['fr-CA','en-CA']
    if market['store']=='es':codes+=['es-ES','ca']
    if market['store'] in ['au','nz']:codes+=['en-AU']
    if market['store']=='us':codes+=['en-US']
    return ', '.join(f'<a href="{prefix}#locale-{ESC(c)}">{ESC(c)}</a>' for c in dict.fromkeys(codes) if c in META['localizations'])


def country_page(row):
    store=row['store'];parts=[header(row['country']+' · ASO 深查'),f'<p><a href="../../index.html#countries">← 全球清单</a></p><h1>{ESC(row["country"])} <small>{store.upper()}</small></h1>',
        f'<p>{ESC(quality(row))} · {len(row.get("metrics",[]))} 个有指标候选 · {len(row.get("candidates",[]))} 个研究假设 · {len(row.get("searches",[]))} 组搜索</p>',
        f'<div class="note">{ESC(row.get("source",""))}<br>{ESC(row.get("limitation","进行中；以记录实际返回为准。"))}</div>',
        f'<p>研究语言：{ESC(", ".join(row["languages"]))}。可参考的本地化草稿：{locale_links(row,"../../index.html")}。这些不是每国可独立编辑的字段；展示还受 Apple 商店与设备语言规则影响。</p>']
    metrics=sorted(row.get('metrics',[]),key=lambda k:(-k.get('popularity',0),k.get('difficulty',100)))
    parts.append('<h2>候选词：热度／难度</h2>')
    if metrics:
        parts.append('<table><tr><th>词</th><th>热度 ↑</th><th>难度 ↓</th><th>信号</th></tr>')
        for k in metrics:
            parts.append(f'<tr><td>{ESC(k["keyword"])}</td><td>{k.get("popularity","—")}</td><td>{k.get("difficulty","—")}</td><td>{"低信号，不能当零需求" if k.get("popularity",0)<=5 else "工具估算，不是搜索次数"}</td></tr>')
        parts.append('</table>')
    else:
        parts.append('<p>Astro 不支持此地区，没有本地热度／难度。以下假设只用于本地目录核对，不伪造分数。定稿以可共享的语言锚点为依据，标注这个证据缺口。</p><p>'+ESC('、'.join(row['candidates']))+'</p>')
    parts.append('<h2>逐词竞品</h2><p>展示前五条实际返回；不足五条就保留真实数量。标题和副标题是公开资料，后台 keywords 无法读取。目录位序不视为 iPhone 自然搜索排名。</p>')
    for s in row.get('searches',[]):
        parts.append(f'<details><summary>{ESC(s["query"])} · {len(s.get("apps",[]))} 条结果</summary><p><small>{ESC(s.get("purpose", "公开目录词义核对"))}</small></p>')
        if s.get('error'):parts.append('<p>查询错误：'+ESC(s['error'])+'</p>')
        parts.append('<table><tr><th>位置</th><th>主标题</th><th>副标题</th><th>评分／数量</th></tr>')
        for position,a in enumerate(s.get('apps',[]),1):
            link=a.get('trackViewUrl') or f'https://apps.apple.com/{store}/app/id{a["appStoreId"]}'
            subtitle=a.get('subtitle')
            if subtitle is None:
                subtitle='目录未返回副标题。'+(' '+a.get('description','').replace('\n',' ')[:100] if a.get('description') else '')
            parts.append(f'<tr><td>{a.get("ranking",a.get("catalogPosition",position))}</td><td><a href="{ESC(link)}">{ESC(a["name"])}</a></td><td>{ESC(subtitle)}</td><td>{ESC(a.get("averageRating","—"))} / {ESC(a.get("ratingCount","—"))}</td></tr>')
        parts.append(f'</table><p><a href="../../../{ESC(s["source"])}">来源记录</a></p></details>')
    parts.append('<h2>边界</h2><p>未读取竞品后台关键词。密码锁、家长控制、网站过滤、番茄钟作为相邻搜索意图比较，不会写成我们拥有的功能。热度／难度与单次排名都不是下载量或转化保证。</p></html>')
    folder=OUT/('language-studies' if row.get('studyID') else 'markets')/row.get('studyID',store)
    (folder/'index.html').write_text(''.join(parts))


rows=[]
for market in PLAN['markets']:
    f=OUT/'markets'/market['store']/'research.json'
    if f.exists():
        try:r=json.loads(f.read_text())
        except ValueError:continue
        rows.append(r);country_page(r)
astro=[r for r in rows if r['astroSupported']];catalog=[r for r in rows if not r['astroSupported']]
done_a=[r for r in astro if quality(r)=='深查完成'];done_c=[r for r in catalog if quality(r).startswith('目录补充完成')]
studies=[]
for study in PLAN.get('languageStudies',[]):
    path=OUT/'language-studies'/study['studyID']/'research.json'
    if path.exists():
        r=json.loads(path.read_text());studies.append(r);country_page(r)
summary={'generatedAt':datetime.now(timezone.utc).isoformat(),'storefrontsPlanned':175,'storefrontRecords':len(rows),'astroDeepComplete':len(done_a),'astroDeepPlanned':91,'catalogComplete':len(done_c),'catalogPlanned':84,
         'keywordMetricRows':sum(len(r.get('metrics',[])) for r in astro),'queryRecords':sum(len(r.get('searches',[])) for r in rows),
         'astroQueries':sum(len(r.get('searches',[])) for r in astro),'catalogQueries':sum(len(r.get('searches',[])) for r in catalog),
         'actualCompetitorRows':sum(len(s.get('apps',[])) for r in rows for s in r.get('searches',[])),
         'studyKeywordMetricRows':sum(len(r.get('metrics',[])) for r in studies),
         'studyQueryRecords':sum(len(r.get('searches',[])) for r in studies),
         'studyCompetitorRows':sum(len(s.get('apps',[])) for r in studies for s in r.get('searches',[])),
         'languageStudiesComplete':sum(quality(s)=='深查完成' for s in studies),'languageStudiesPlanned':len(PLAN.get('languageStudies',[])),
         'complete':len(done_a)==91 and len(done_c)==84 and len(studies)==4 and all(quality(s)=='深查完成' for s in studies),'metadataDrafts':len(META['localizations']),
         'statusCounts':dict(Counter(quality(r) for r in rows)),
         'limitations':['84 storefronts have no Astro popularity or native keyword rank; Apple catalog is labelled separately.','Public catalog may omit subtitles or return fewer than five.','Country hypotheses are not individually writable locale fields.','New locale drafts do not add UI translations or complete store assets.','Names are draft candidates; search does not reserve names or clear trademarks.']}
(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
parts=[header('全球 ASO 深查与本地品牌'),'<h1>全球 ASO · 本地化三字段</h1>',
       '<p>本轮只处理主标题、副标题和 keywords。地域数据、相邻意图、公开竞品、本地角色名一起看。</p>',
       '<div class="note"><b>中国候选：自觉鸭：戒手机与屏幕使用时间</b><br>副标题：少刷社交媒体，应用限时，到点休息。<br>商店名称、角色与功能表达一起本地化；当前全为本地审阅草稿，未向 Apple 提交。</div>',
       f'<div class="numbers"><p><b>{len(done_a)} / 91</b>Astro 深查完成</p><p><b>{len(done_c)} / 84</b>公开目录补充完成</p><p><b>{len(META["localizations"])}</b>本地化三字段草稿</p></div>',
       '<nav><a href="../peer-cohort/index.html">2026 新产品赢过老牌</a><a href="#locales">全部名称与关键词</a><a href="#countries">175 地区</a><a href="metadata.json">三字段 JSON</a><a href="metadata.txt">全部文案纯文本</a><a href="summary.json">覆盖统计</a><a href="name-check-summary.json">公开名称检查</a><a href="../china-deep-dive/index.html">中国上一轮专项</a></nav>',
       '<h2>这次和初筛有什么不同</h2><p>每个工具支持的国家扩至至少 22 个本地／双语候选，核对八组相关搜索；某些相邻词更热，但结果偏密码锁、番茄钟或家长控制，单独记录而不照抄。加拿大法语、西班牙加泰语、印度印地语、斯洛文尼亚语另有语言专项。</p>',
       '<p>84 个不支持地区也查询八组 Apple 本地公开目录。它们的热度仍是未知，目录位序也不等于 iPhone 自然排名：不把这个缺口藏进“全球已优化”四个字。该部分采用可共享的语言锚点，并保留实际当地返回的产品差异。</p><p>已交叉核对 <a href="https://ads.apple.com/app-store/countries-and-regions">Apple Ads 官方可投地区</a>：其 91 个市场与 Astro 当前支持的国家集合一致。相同覆盖范围不等于证明 Astro 内部采用何种数据来源；它也不能让其他 84 个市场凭空出现可比的热度。<a href="apple-ads-coverage.json">名单核对记录</a></p>',
       '<p>热度低于或等于 5 按低信号处理，不等于零需求。搜索名称无返回不等于获准注册。所有额外语言目前只有三字段草稿；原有 16 份完整物料同步这三个字段，App 内语言仍为现有 10 种。</p>',
       '<p>依据：<a href="https://developer.apple.com/app-store/search/">Apple 搜索规则</a> · <a href="https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations/">本地化展示规则</a> · <a href="https://performance-partners.apple.com/search-api">Apple 公开目录接口</a></p>',
       '<h2 id="locales">本地化三字段</h2>']
for locale,m in META['localizations'].items():
    parts.append(f'<details id="locale-{ESC(locale)}"><summary>{ESC(locale)} · {ESC(m["name"])}</summary><p>{ESC(m["rationale"])}</p><p><small>{ESC(m["scope"])}。锚点：{ESC(", ".join(m["anchorStores"]))}。</small></p><table><tr><th>字段</th><th>草稿</th><th>长度</th></tr>')
    for key in ['name','subtitle','keywords']:
        count=len(m[key].encode()) if key=='keywords' else len(m[key])
        parts.append(f'<tr><th>{key}</th><td dir="auto"><code>{ESC(m[key])}</code></td><td>{count}/{100 if key=="keywords" else 30}{" bytes" if key=="keywords" else ""}</td></tr>')
    parts.append('</table><p>相关国家：'+', '.join(f'<a href="markets/{c}/index.html">{c.upper()}</a>' for c in m['anchorStores'] if (OUT/'markets'/c/'index.html').exists())+'</p>')
    if m.get('measuredEnglishAdditions'):
        parts.append('<p><small>按当地数据补入的英语组词：'+ESC('；'.join(f'{x["query"]} {x["popularity"]}/{x["difficulty"]}（{x["store"].upper()}）' for x in m['measuredEnglishAdditions']))+'。不是英语品牌后缀。</small></p>')
    parts.append('</details>')
parts.append('<h2>补充语言专项</h2><p>'+', '.join(f'<a href="language-studies/{s["studyID"]}/index.html">{ESC(s["studyID"])}：{ESC(quality(s))}</a>' for s in studies)+'</p>')
parts.append('<h2 id="countries">175 地区索引</h2><input id="filter" placeholder="搜索国家、语言或状态…"><div class="scroll"><table id="markets"><thead><tr><th>地区</th><th>研究语言</th><th>指标／查询</th><th>进度与证据</th><th>相关本地化草稿</th></tr></thead><tbody>')
by={r['store']:r for r in rows}
for market in PLAN['markets']:
    c=market['store'];row=by.get(c);state=quality(row) if row else '待查询'
    metric_count=len(row.get('metrics',[])) if row else 0;query_count=len(row.get('searches',[])) if row else 0
    link=f'<a href="markets/{c}/index.html">{ESC(state)} →</a>' if row else ESC(state)
    parts.append(f'<tr><td>{ESC(market["country"])}<br><small>{c.upper()}</small></td><td>{ESC(", ".join(market["languages"]))}</td><td>{metric_count} / {query_count}</td><td>{link}</td><td>{locale_links(market)}</td></tr>')
parts.append('</tbody></table></div><h2>发布前与发布后</h2><p>名称可用性以 App Store Connect 校验为准。发布前记录 7–14 天基线，发布后对比 7／14／28 天关键词排名、App Store Search 曝光、首次下载和转化，注明广告或其他获客变化。没有付费投放，也没有建立定时任务。</p><script>document.querySelector("#filter").addEventListener("input",e=>{let q=e.target.value.toLowerCase();document.querySelectorAll("#markets tbody tr").forEach(r=>r.hidden=!r.textContent.toLowerCase().includes(q))});if(location.hash.startsWith("#locale-")){document.querySelector(location.hash)?.setAttribute("open","")}</script></html>')
(OUT/'index.html').write_text(''.join(parts))
print(json.dumps(summary,ensure_ascii=False))

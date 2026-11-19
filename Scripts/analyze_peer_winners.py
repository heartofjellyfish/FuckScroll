#!/usr/bin/env python3
"""Compare young apps with named incumbents inside the SAME ranking response."""
import json
import html
import hashlib
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'AppStore/ASO/next-release'
OUT = ROOT / 'peer-cohort'
load = lambda p: json.loads(p.read_text())
data = load(OUT / 'cohort-candidates.json')
facts = load(OUT / 'app-metadata.json')
observations = load(OUT / 'observations.json')
plan = load(ROOT / 'deep-research/plan.json')
incumbents = {'1497465230', '1541027222', '1532875441', '1645639057',
              '1515753232', '1644737181', '1609960918', '1474967653',
              '1474340105', '6448794069', '6444819615'}
# Product-scope judgments follow a manual read of public descriptions. They are
# not device tests, nor an endorsement of competitors' scientific/absolute claims.
scopes = {
 '6822790279': ('direct', '按使用时长锁定并休息，角色会吐槽；与我们最接近。'),
 '6811619023': ('related', '整 App 拦截，但以完成习惯任务换取使用时间。'),
 '6760668517': ('direct', '整 App 严格拦截，突出不能轻易跳过；固定等待机制与我们不同。'),
 '6784308174': ('direct', '使用时长、打开次数与定时规则拦截，附带习惯和统计。'),
 '6758152591': ('direct', '选择 App、定时拦截、使用统计；广义屏幕时间管理。'),
 '6755889415': ('direct', 'App 与网站分组、专注时段、定时休息与打开前阻力。'),
 '6757622975': ('direct', '整 App 拦截、使用限额与专注时段。'),
 '6758338291': ('related', '整 App 拦截，可用运动和任务解锁；强度更复杂。'),
 '6786942350': ('direct', '角色受使用时长影响，可选 App 限额阻断；可参考温和的动物伙伴定位。'),
 '6759700381': ('related', '屏幕时间限额与隐私锁混合定位；不照搬隐私相册词。'),
 '6791383965': ('direct', '打开前提醒、等待与每日限额；与我们触发时机不同。'),
 '6755110504': ('related', 'App 拦截与完成习惯换取屏幕时间。'),
 '6784166547': ('direct', '按 App 每日限额、专注时段、打开前暂停。'),
 '6788488118': ('direct', '系统级 App 拦截、专注时段、严格模式与休息提醒。'),
 '6749869519': ('direct', '定时与即时 App 拦截、使用报告。'),
 '6787695392': ('direct', 'App 立即锁、定时锁、每日用量阈值锁。'),
 '6761280235': ('direct', 'App 拦截与专注规则；不把 detox 作为医疗功效。'),
 '6806876559': ('direct', '整 App 定时拦截，以目标和累计专注时间表达收益。'),
 '6759315272': ('related', 'App 限额加内置浏览器；其中移除 Reels 功能不属于我们。'),
 '6748807463': ('direct', '即时与定时拦截、每日共享限额、临时通行。'),
 '6834225631': ('direct', 'App 限额、拦截与专注时段；仅有公开描述，未实测。'),
 '6768861415': ('related', '整 App 拦截，以 NFC/二维码/地点主动解锁。'),
 '6818806667': ('related', '学习计时器，锁 App 作为专注机制；不是刷屏后休息。'),
 '6761388724': ('direct', '描述主张连续使用后休息；实现与连续识别能力未验证。'),
 '6819562117': ('direct', '角色监督，使用累积后警告和锁 App；动态岛与声音不是我们的能力。'),
 '6769819246': ('related', '进入 App 前展示目标提醒，不等于到点强制休息。'),
 '6792533301': ('related', '打开前提醒与文字确认；不是我们的用量到点锁。'),
 '6815957929': ('related', 'App 使用预算，运动与学习可换更多分钟。'),
 '6757661674': ('adjacent', '以浏览体验移除短视频和推荐流，不是整 App 到点拦截。'),
 '6809352229': ('adjacent', '以移除 Reels/Shorts 为主；不能承诺我们也能保留私信。'),
 '6754183872': ('adjacent', 'Safari 过滤社交网页内容，不是原生 App 使用阈值锁。'),
 '6786888937': ('exclude', '公开说明明确不拦截，只记录长期屏幕时间。'),
 '6811993215': ('exclude', '面向参加机构的学生，目标与排名；未见 App 拦截能力。'),
 '6788602363': ('exclude', '种花专注计时器，未见选定 App 阈值阻断。'),
 '6790097515': ('mixed', '隐私保护与屏幕时间混合，私密相册不是我们的搜索意图。'),
 '6777914542': ('mixed', '英文描述有专注锁，但当地副标题主打密码锁；不当同类主证据。'),
}
reviews = {}
saved_reviews=load(OUT/'product-scope-reviews.json') if (OUT/'product-scope-reviews.json').exists() else {}
for appid, (scope, note) in scopes.items():
    p = Path('/tmp/duck-peer-verified') / (appid + '.json')
    saved_product=OUT/'verified-products'/(appid+'.json')
    public = load(p) if p.exists() else (load(saved_product) if saved_product.exists() else facts.get(appid, {}))
    reviews[appid] = dict(scope=scope, note=note,
        publicURL=public.get('trackViewUrl', f'https://apps.apple.com/app/id{appid}'),
        descriptionChecked=p.exists() or saved_reviews.get(appid,{}).get('descriptionChecked',False), publicReleaseDate=public.get('releaseDate'),
        descriptionSHA256=hashlib.sha256(public['description'].encode()).hexdigest() if 'description' in public else saved_reviews.get(appid,{}).get('descriptionSHA256'),
        evidence='Public App Store description, not a device test')
    if p.exists():
        directory=OUT/'verified-products';directory.mkdir(exist_ok=True)
        keep=['trackId','trackName','trackViewUrl','artistName','releaseDate','version','currentVersionReleaseDate']
        record={key:public.get(key) for key in keep}
        record.update(lookupURL='https://itunes.apple.com/lookup?id='+appid+'&country=us',country='us')
        (directory/(appid+'.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
(OUT/'product-scope-reviews.json').write_text(json.dumps(reviews,ensure_ascii=False,indent=2)+'\n')

metrics={}
for p in (ROOT/'deep-research/markets').glob('*/research.json'):
    r=load(p)
    for m in r.get('metrics',[]):metrics[r['store'],m['keyword']]=m
cohort={a['appId']:a for a in data['candidateCohort']}
groups=defaultdict(list)
for r in observations:
    if r['evidenceType']=='astro':groups[r['store'],r['keyword'],r['source']].append(r)
# Use the newest captured response per country and query. Never splice together
# the new candidate's rank from one response and the incumbent from another.
latest={}
for (store,q,source), rows in groups.items():
    mtime=(ROOT/source).stat().st_mtime
    if (store,q) not in latest or mtime>latest[store,q][0]:latest[store,q]=(mtime,source,rows)
wins=[]
for (store,q),(mtime,source,rows) in latest.items():
    rows.sort(key=lambda r:r['position'])
    for r in rows:
        if r['appId'] not in cohort or r['position']>5:continue
        beaten=[a for a in rows if a['appId'] in incumbents and a['position']>r['position']
                and facts.get(a['appId'],{}).get('releaseDate','9999')[:4]<'2025']
        if not beaten:continue
        metric=metrics.get((store,q),{})
        win=dict(r,releaseDate=cohort[r['appId']]['releaseClientDate'],
                 popularity=metric.get('popularity'),difficulty=metric.get('difficulty'),
                 releaseDateEvidence=cohort[r['appId']].get('releaseDateEvidence'),
                 capturedFileTimeUTC=datetime.fromtimestamp(mtime,timezone.utc).isoformat(),
                 beaten=[dict(appId=a['appId'],name=a['name'],position=a['position'],
                              releaseDate=facts[a['appId']]['releaseDate']) for a in beaten],
                 **reviews.get(r['appId'],dict(scope='pending',note='功能待核实，不纳入主要结论。')))
        # reviews' source date may be country-specific; keep cohort's normalized
        # release day and the publicly checked source date as separate fields.
        win['releaseClientDate']=cohort[r['appId']]['releaseClientDate']
        win['strongSignal']=bool(win['scope'] in ('direct','related') and win.get('descriptionChecked') and (win['popularity'] or 0)>=20)
        wins.append(win)
wins.sort(key=lambda r:(not r['strongSignal'],r['store'],r['position'],r['keyword']))
countries=[]
for market in plan['markets']:
    found=[w for w in wins if w['store']==market['store']]
    strong=[w for w in found if w['strongSignal']]
    countries.append(dict(store=market['store'],astroSupported=market['astroSupported'],
        status='supported-win' if strong else ('no-verified-strong-win-in-sample' if market['astroSupported'] else 'catalog-only-no-rank-conclusion'),
        strongWins=strong,otherObservedCandidates=found))
report=dict(asOfClientDate=data['asOfClientDate'],ownRelease=data['ourFirstReleaseClientDate'],
    cohortRule='2026 original release, native Top 5, named pre-2025 comparable incumbent below in same response; main evidence additionally needs popularity >=20 and reviewed scope.',
    coverage={'countries':len(countries),'astroCountries':sum(c['astroSupported'] for c in countries),
              'publicCatalogOnly':sum(not c['astroSupported'] for c in countries),
              'all2026Candidates':len(cohort),'strongApps':len({w['appId'] for w in wins if w['strongSignal']}),
              'strongCountries':sum(c['status']=='supported-win' for c in countries),'strongKeywordWins':sum(w['strongSignal'] for w in wins)},
    productScopeReviews=reviews,countries=countries,wins=wins,
    limitation='Sampled observations, not all App Store keywords. Popularity is Astro estimate, not searches/day. Public releaseDate can differ by storefront. No access to hidden keywords or download/ad spend. Current metadata and rank cannot establish causal ASO lift.')
(OUT/'winners.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')

intro='''# 2026 新上架、却排在老牌前面的 App

本轮按 Qi 的新标准筛选：同一国家、同一关键词、同一份 Astro 返回结果中，2026 年上架、功能相近且进入前五，并排在至少一个已知老牌产品前面。优先看前三区间；主要案例另要求关键词热度估算 ≥20。这个门槛是分析筛选，不是 Apple 官方规则。

175 个国家重新扩展前 20 个结果；91 个有 Astro 排名，另 84 个只有公开目录，不能据此判断跑赢老牌。原先每国八组搜索也保留。上架年份用公开 releaseDate，不能用最近更新日期；不同商店的首次可用日期可能不同。我们公开的美区首次上架日期为 2026-11-12。

看得见的是公开名称、副标题、产品描述和当前排名。看不见的是竞品后台 keywords、下载量、投放、品牌迁移和元数据历史，所以不把“排在前面”写成“靠改名赢了”。排名是采样结果，不是永久名次，也不代表榜单位置。

## 最值得看的一组

'''
selected=[('cn','戒手机','6822790279'),('us','stop doomscrolling','6784308174'),
          ('gb','screen time','6760668517'),('nl','schermtijd','6758338291'),
          ('fr','scroll blocker','6811619023'),('ru','экранное время','6755889415'),
          ('de','bildschirmzeit','6815957929'),('tw','戒手機','6819562117')]
md=intro+'|国家 / 搜索词|2026 新产品 / 上架日|位置|同份结果中排在后面的老牌|公开副标题|\n|---|---|---|---|---|\n'
highlights=[]
for store,q,appid in selected:
    w=next((w for w in wins if w['store']==store and w['keyword']==q and w['appId']==appid),None)
    if not w:continue
    highlights.append(w)
    beaten='；'.join(a['name']+' #'+str(a['position']) for a in w['beaten'][:4])
    clean=lambda s:s.replace('|','\\|')
    url=f'https://apps.apple.com/{store}/app/id{appid}'
    md+=f"|{store.upper()} / {q}|[{clean(w['name'])}]({url}) / {w['releaseClientDate']}|#{w['position']}|{clean(beaten)}|{clean(w.get('subtitle') or '该响应未返回')}|\n"
md+='''
## 他们的公开字段怎么分工

|例子|标题承担搜索意图|副标题承担什么|我们能学什么|
|---|---|---|---|
|Derot|Stop Doomscrolling，直接写用户想停止的行为|Screen Time & App Blocker，解释工具类别|问题词和功能词分开覆盖；我们已有 stop、doomscrolling 与 App Blocker|
|67|Strict Screen Time Blocker，类别加约束|No More “Ignore Limit”，点出旧方案的漏洞|用具体差异解释为什么要换 App，不靠空泛 focus 口号|
|毒舌鹦鹉|角色名加戒手机、少玩手机、防沉迷|专注、作息等更广泛目标|角色与功能可以同时明确；不必照搬标题堆词|
|Blocus（荷兰）|Verdien schermtijd，当地词加“赚取时间”机制|Blokkeren, Focus & Limieten，补类别词|本地功能词之外，让用户看懂独特机制|
|Scrollr（法国）|Bloqueur d’apps，本地类别词|Gagne ton temps d’écran，写换取使用时间的差异|本地读起来清楚；英语搜索词未必要求英语标题|

这些是当前公开元数据的分工分析，不是已证明有效的改名前后实验；也不是对竞品隐藏 keywords 的推断。

'''
md+='''
## 对我们三个字段的影响

- **美国：保留 App Blocker – Duck on Duty / Screen Time Control & Focus 的当前草稿。** 大类词对应真实功能；Derot 的例子支持补充 stop / doomscrolling 的问题词，而这两个已在我们的关键词字段里。不能说新产品已经打穿 app blocker 前三：本轮美国 app blocker 前列仍是老牌。SocialLite 在 scroll blocker 更强，但属于短视频内容过滤，不给我们加入 Reels / Shorts 功能承诺。
- **中国：保留“自觉鸭：戒手机与屏幕使用时间”的待审方向。** 毒舌鹦鹉不仅是近日期，它在“戒手机”排第一，并明确宣传使用 X 分钟、休息 Y 分钟，功能与角色都很接近。“戒手机＋角色名”值得学习；其标题堆叠、羞辱口吻和强制功能不能直接复制。品牌“自觉鸭”仍未获最终批准。
- **英国、加拿大：功能词配具体约束比纯口号更有说服力。** 67 的副标题 No More “Ignore Limit” 让人知道差异。我们现有草稿覆盖 screen time / control / limit / break；不能写无法绕过，因为用户能关闭值班，个人授权也有平台边界。
- **荷兰、德国、俄罗斯：继续使用当地的 schermtijd / Bildschirmzeit / экранное время。** 年轻赢家也用这些词，强化了之前的本地化选择。我们不加入“运动换时间”“学习奖励”等不存在的功能词。
- **法国：保留 scroll 相关覆盖，并把本地 Bloqueur d’apps 作为后续标题测试候选。** Scrollr 的法语标题在英语查询 scroll blocker 下领先，说明英语查询也可能对应本地语言页面；不能因此认定标题只要英语或只要法语即可。现有标题先沿用热度证据，不因单个赢家强行替换。
- **台湾、韩国：角色名和口语问句可以承载个性，但要同时带戒手機 / 앱차단等功能词。** Gamijii 与 Really? 是角色/提醒型近邻，不能据此复制它们的动态岛、语音或打开前确认能力。

以上是对现有 40 份三字段草稿的证据复核。本轮未修改标题、副标题或隐藏关键词，也未向 Apple 上传。后续测试一次改变一个主要变量，按地区看搜索曝光、搜索下载、转化与目标词名次；不把付费投放混入自然增长结论。

## 排除与降级

- OpenAppLock 美区 app blocker #8：2026 年上架但不进主要前五，不凭“新、评分少”当主要成功案例。
- Aheno：日期很近，但原来靠前的多是热度估算 5 的词，证据弱；Lunisa 的公开目录位置也不算真实搜索排名。
- SocialLite / ScrollGuard / minulo：可研究反刷屏定位，内容过滤能力与我们不同，放在邻近案例。
- finit：明确不拦截；学生机构目标打卡、纯番茄钟、密码锁意图也不冒充同类拦截成功。
- “没有符合条件的例子”仅表示本次样本没找到，不代表这个市场不存在年轻赢家。

## 每个国家的结果

|国家|证据状态|经过功能核实、热度 ≥20 的获胜词组数|
|---|---|---|
'''
for c in countries:
    status={'supported-win':'找到符合条件案例','no-verified-strong-win-in-sample':'本次样本未找到强案例','catalog-only-no-rank-conclusion':'只有目录，不能判断排名'}[c['status']]
    md+=f"|{c['store'].upper()}|{status}|{len(c['strongWins'])}|\n"
md+='''
## 可复核材料

- [机器可读国家逐项与排名对照](winners.json)：包括同响应来源、具体对手和位置、热度估算、功能核实状态。
- [全部 2026 候选](cohort-candidates.json)：日期筛选名单，未必是成功案例。
- [原始排名](discovery/) / [重点查询](targeted/) / [日期查询](lookups/) / [精选产品公开事实](verified-products/)。产品功能判断只来自公开描述，未实测竞品。
- [Apple 对搜索排序的说明](https://developer.apple.com/app-store/search/)：文字相关性之外，还包括下载、评分、评价等用户行为信号。
'''
(OUT/'README.md').write_text(md)
esc=html.escape
sections=''
for w in highlights:
    old=' · '.join(a['name']+' #'+str(a['position']) for a in w['beaten'][:4])
    sections+=f'''<article><small>{esc(w['store'].upper())} · {esc(w['keyword'])} · 热度 {w['popularity']} / 难度 {w['difficulty']}</small><h2>#{w['position']} {esc(w['name'])}</h2><p>2026 上架：{esc(w['releaseClientDate'])}</p><p class="sub">{esc(w.get('subtitle') or '副标题未返回')}</p><p>排在后面：{esc(old)}</p><p>{esc(w['note'])}</p><a href="{esc(w['publicURL'])}">公开商店页 ↗</a> · <a href="../{esc(w['source'])}">本次排名来源</a></article>'''
table=''.join(f"<tr><td>{c['store'].upper()}</td><td>{'找到案例' if c['strongWins'] else ('样本未找到强案例' if c['astroSupported'] else '只有目录，无排名结论')}</td><td>{len(c['strongWins'])}</td></tr>" for c in countries)
(OUT/'index.html').write_text(f'''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>2026 新产品如何排到老牌前面</title><style>body{{background:#faf6e7;color:#191915;font:17px/1.65 -apple-system,BlinkMacSystemFont,sans-serif;max-width:1100px;margin:auto;padding:48px 24px}}h1{{font-size:44px;line-height:1.15}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px}}article{{border:2px solid;padding:24px;background:#fffbed}}small{{background:#ffda32}}h2{{font-size:24px;line-height:1.3}}.sub{{font-weight:600}}a{{color:inherit}}table{{width:100%;border-collapse:collapse}}td,th{{text-align:left;border-bottom:1px solid #ccc;padding:10px}}</style><p>ASTRO · 2026 年新产品 · 2026-11-18（洛杉矶日期）</p><h1>新上架，也能排在老牌前面。</h1><p>同一个国家、同一个搜索词、同一份返回结果：2026 年上架，前五，至少一个已知老牌在后面。主要案例另要求热度估算 ≥20 和功能核实。</p><p>{report['coverage']['strongApps']} 个已核实产品 · {report['coverage']['strongCountries']} 个国家找到强案例。91 国有 Astro 排名；84 国只有目录，不能判断排名。</p><p>公开元数据与排名只能提供线索，无法证明排名由 ASO 导致；竞品隐藏 keywords 不可见。数据是样本，不是全市场。</p><div class="grid">{sections}</div><h2>完整分析与三字段决策</h2><p><a href="README.md">阅读中文分析</a> · <a href="winners.json">全部对照与证据</a> · <a href="../deep-research/index.html">现有 40 份本地化草稿</a></p><h2>175 个国家逐项结果</h2><table><tr><th>国家</th><th>状态</th><th>强获胜词组</th></tr>{table}</table></html>''')
print(json.dumps(report['coverage'],ensure_ascii=False))

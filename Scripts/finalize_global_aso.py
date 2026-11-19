#!/usr/bin/env python3
"""Reconcile the 175-store Astro audit and render the next-version three-field report.

Local output only. --refresh-searches fetches top-five results for changed picks,
with unique RPC IDs and a conservative request pace. It never writes to Apple.
"""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import html
import json
from pathlib import Path
import time
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1] / 'AppStore/ASO/next-release'
OUT = ROOT / 'all-storefronts'
RELEVANCE = {'concentration': 3, 'blocco app': 3, 'blocca app': 3,
             'bloquear aplicaciones': 4, 'apps sperren': 4,
             'блокировка приложений': 3, '防沉迷': 4, 'scroll blocker': 4}
LOCALES = {'English (US)': 'en-US', 'English (U.K.)': 'en-GB',
           'English (Australia)': 'en-AU', 'English (Canada)': 'en-CA',
           'Simplified Chinese': 'zh-Hans', 'Chinese (Traditional)': 'zh-Hant',
           'Japanese': 'ja', 'Korean': 'ko', 'Spanish (Spain)': 'es-ES',
           'Spanish (Mexico)': 'es-MX', 'French': 'fr-FR', 'German': 'de-DE',
           'Italian': 'it', 'Portuguese (Brazil)': 'pt-BR',
           'Portuguese (Portugal)': 'pt-PT', 'Dutch': 'nl-NL',
           'Russian': 'ru', 'Swedish': 'sv'}


def unpack(envelope):
    for block in envelope.get('result', {}).get('content', []):
        if block.get('type') == 'text':
            try:
                return json.loads(block['text'])
            except ValueError:
                if envelope['result'].get('isError'):
                    return {'error': block['text']}
    return {}


def select(items):
    valid = [k for k in items if k.get('popularity', 0) > 5
             and RELEVANCE.get(k['keyword'], 5) >= 4]
    frontier = [k for k in valid if not any(
        o['popularity'] >= k['popularity'] and o['difficulty'] <= k['difficulty']
        and (o['popularity'] > k['popularity'] or o['difficulty'] < k['difficulty'])
        for o in valid)]
    maximum = max((k['popularity'] for k in valid), default=0)
    sweet = [k for k in valid if k['popularity'] >= max(25, .6 * maximum)
             and k['difficulty'] <= 35]
    pool = sweet or valid
    if pool:
        best = max(pool, key=lambda k: (k['popularity'], -k['difficulty']))
        rule = 'balanced-shortlist' if sweet else 'popularity-first'
        return best, rule, frontier
    return None, 'insufficient-demand-signal', frontier


def cached_search(store, query, previous):
    if previous.get('selectedKeyword', {}).get('keyword') == query and len(previous.get('top5', [])) >= 5:
        return {'apps': previous['top5'], 'yourAppRanking': previous.get('yourAppRanking')}
    for path in (ROOT / 'top5').glob(store + '-*.json'):
        value = json.loads(path.read_text())
        if value.get('query') == query:
            result = unpack(value.get('response', {}))
            if len(result.get('apps', [])) >= 5:
                return result
    key = hashlib.sha256(query.encode()).hexdigest()[:12]
    path = OUT / 'raw' / f'{store}-reselected-{key}.json'
    if path.exists():
        return unpack(json.loads(path.read_text()))
    return None


def reconcile(refresh):
    rows = []
    for country in json.loads((OUT / 'storefronts.json').read_text()):
        store = country['store']
        previous = json.loads((OUT / f'{store}.json').read_text())
        row = dict(previous)
        row['defaultLocalePlanningGroup'] = LOCALES[country['defaultLanguage']]
        errors = []
        for path in (OUT / 'raw').glob(store + '-*.json'):
            error = unpack(json.loads(path.read_text())).get('error')
            if error:
                errors.append(error)
        if any('Unsupported store' in e for e in errors):
            row.update(status='unsupported-by-astro', error=next(e for e in errors if 'Unsupported store' in e))
            row['evidenceScope'] = 'No local metrics or local SERP claim; use explicitly labelled language fallback.'
        elif row.get('keywords'):
            best, rule, frontier = select(row['keywords'])
            row.update(selectionRule=rule, paretoFrontier=frontier)
            if best:
                value = cached_search(store, best['keyword'], previous)
                if value is None and refresh:
                    time.sleep(2.5)
                    args = {'keyword': best['keyword'], 'store': store, 'platform': 'iphone', 'limit': 5, 'appId': '6832822647'}
                    request = urllib.request.Request('http://127.0.0.1:8089/mcp', data=json.dumps({
                        'jsonrpc': '2.0', 'id': str(uuid.uuid4()), 'method': 'tools/call',
                        'params': {'name': 'search_app_store', 'arguments': args}}).encode(),
                        headers={'Content-Type': 'application/json', 'Accept': 'application/json, text/event-stream'})
                    try:
                        with urllib.request.urlopen(request, timeout=75) as response:
                            envelope = json.load(response)
                        key = hashlib.sha256(best['keyword'].encode()).hexdigest()[:12]
                        (OUT / 'raw' / f'{store}-reselected-{key}.json').write_text(json.dumps(envelope, ensure_ascii=False, indent=2))
                        value = unpack(envelope)
                    except Exception as error:
                        value = {'error': str(error)}
                row.update(selectedKeyword=best, top5=(value or {}).get('apps', [])[:5],
                           yourAppRanking=(value or {}).get('yourAppRanking'))
                row['status'] = 'completed' if len(row['top5']) == 5 else 'search-unavailable'
                row['evidenceScope'] = 'This country: four or five seed metrics and selected-query top five. Not exhaustive keyword discovery.'
                if value and value.get('error'):
                    row['error'] = value['error']
            else:
                # Keep the original SERP as evidence, without pretending score=5 proves demand.
                row['status'] = 'low-signal'
                row['evidenceScope'] = 'Only low-signal seed metrics; original SERP retained, no proven opportunity.'
        else:
            row['status'] = 'data-unavailable'
            row['evidenceScope'] = 'No local claim; language fallback only.'
        rows.append(row)
    audit = {'generatedAt': datetime.now(timezone.utc).isoformat(), 'storefrontCount': len(rows),
             'statusCounts': dict(Counter(r['status'] for r in rows)),
             'method': {'gate': 'Actual app relevance before score comparisons; privacy/password-lock terms excluded where ambiguous.',
                        'shortlist': 'Popularity >= max(25, 60% of best relevant seed), difficulty <=35; then popularity first.',
                        'caveat': 'Human-chosen screening thresholds, not calibrated ROI, search volumes, or guaranteed rankings. The final locale title can override this shortlist.',
                        'fallback': 'Without a qualifying shortlist, prioritize popularity; score<=5 is low-signal, not proven zero demand.'},
             'sources': ['https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations/',
                         'https://developer.apple.com/app-store/search/', 'http://127.0.0.1:8089/mcp'],
             'scope': '175 official storefront reference entries checked. Per-app current availability not reverified. Metadata is language/region-localized, not separately writable in every country.',
             'results': rows}
    (OUT / 'audit-reconciled.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    return audit


def render(audit):
    esc = lambda value: html.escape(str(value))
    meta = json.loads((OUT / 'three-field-recommendations.json').read_text())
    previous = json.loads((ROOT / 'listings-before-global-three-field.json').read_text())
    css = 'body{max-width:1160px;margin:44px auto;padding:0 24px;background:#fcf6e6;color:#191916;font:16px/1.65 -apple-system,sans-serif}h1{font-size:40px;line-height:1.15}h2{margin-top:42px}table{border-collapse:collapse;width:100%;font-size:14px}td,th{padding:12px;text-align:left;vertical-align:top;border-bottom:1px solid #ccc3ad;overflow-wrap:anywhere}th{white-space:nowrap}section{border-top:2px solid;padding:20px 0}code{font-size:14px;overflow-wrap:anywhere}a{color:inherit}.note{padding:18px;background:#fed336;border:2px solid;border-radius:8px}small{color:#655f52}details{padding:12px 0}summary{cursor:pointer;font-weight:600}nav{display:flex;gap:16px;flex-wrap:wrap}input{font:inherit;padding:12px;width:min(600px,90%);border:2px solid;border-radius:6px;background:transparent}.muted{color:#777}.tag{font-size:12px;padding:2px 6px;border:1px solid;border-radius:4px}.scroll{overflow-x:auto}'
    parts = [f'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>全球关键词决策 · Duck on Duty</title><style>{css}</style>',
             '<h1>先让人搜到，再让鸭子出场。</h1>',
             f'<p>下一版三字段方案 · {esc(audit["generatedAt"])} · 175 个商店尝试查询 · {esc(audit["statusCounts"])}</p>',
             '<div class="note"><b>美区建议：App Blocker – Duck on Duty</b><br>副标题：Screen Time Control &amp; Focus<br>26 / 27 字符；关键词不重复。当前仅在项目中准备，未改线上名称，也未向 Apple 提交本轮。</div>',
             '<nav><a href="#decisions">19 份三字段方案</a><a href="#markets">175 地区证据</a><a href="#openapplock">OpenAppLock 案例</a><a href="../archive-21-storefronts.html">上一轮完整物料（历史）</a></nav>',
             '<h2>怎么选，而不是怎么凑词</h2><p>先保证意图相符，再比较热度与竞争。美区 App Blocker 是 54 / 59，Scroll Blocker 是 35 / 15；前者需求更大，后者更容易。美国最终采用用户最新提出的 App Blocker，把 scroll 留在关键词中，不把一个筛选公式当成答案。</p>',
             '<p>每国查询 4–5 个相关种子词，检查所选词的前五名；部分重点市场另有上一轮多词前五名记录。这个范围是逐国种子筛选，不是穷举该国全部热门词，也没有读取竞品后台关键词。热度和难度是 Astro 指标，不是实际搜索次数。</p>',
             '<p>初筛平衡候选：热度至少 25 且不低于当地相关词最高值的 60%，难度不高于 35。没找到就优先热度。这是人为筛选起点；最终本地化还考虑语言、意图和共用字段。数值 5 按低信号处理，不视为零需求或绝佳机会。</p>',
             '<p><b>175 个国家不能各写一个名字。</b>Apple 按本地化语言／地区保存字段，展示还取决于设备语言和已提供的本地化。下表默认语言仅用于规划；各国推荐冲突会保留，不冒充独立可发布版本。84 个不支持地区使用语言锚点方案，不伪造本地热度。</p>',
             '<p>这轮只改名称、副标题、关键词。原有 16 份完整物料同步三字段；荷兰语、俄语、瑞典语新增的是三字段草案，尚未补全这些语言的简介、截图或 App 内翻译。</p>',
             '<p>依据：<a href="https://developer.apple.com/app-store/search/">Apple 搜索说明</a> · <a href="https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations/">Apple 本地化展示规则</a></p>',
             '<h2 id="decisions">本地化三字段</h2>']
    for locale, item in meta['localizations'].items():
        parts.append(f'<section id="{esc(locale)}"><h3>{esc(locale)} <span class="tag">{esc(item["scope"])}</span></h3><p>{esc(item["rationale"])}</p><p><small>研究锚点：{esc(", ".join(item["anchorStores"]))}。{esc(item.get("conflict", ""))}</small></p><table><tr><th>字段</th><th>上一轮候选</th><th>本轮建议</th><th>长度</th></tr>')
        for field in ('name', 'subtitle', 'keywords'):
            value = item[field]
            count = len(value.encode()) if field == 'keywords' else len(value)
            parts.append(f'<tr><th>{field}</th><td>{esc(previous.get(locale, {}).get(field, "尚无"))}</td><td>{esc(value)}</td><td>{count}/{100 if field=="keywords" else 30}{" bytes" if field=="keywords" else ""}</td></tr>')
        parts.append('</table></section>')
    parts += ['<h2 id="markets">175 个地区：原始证据与限制</h2><input id="filter" placeholder="按国家、词或本地化筛选…"><div class="scroll"><table id="countries"><thead><tr><th>地区</th><th>规划语言</th><th>种子词：热度 / 难度</th><th>初筛词与前五名</th><th>状态</th></tr></thead><tbody>']
    for row in audit['results']:
        metrics = '<br>'.join(f'{esc(k["keyword"])}: {k.get("popularity", "?")} / {k.get("difficulty", "?")}' for k in row.get('keywords', [])) or '无数据；不是零需求'
        best = row.get('selectedKeyword') or {}
        apps = '<br>'.join(f'{a.get("ranking", n)}. {esc(a["name"])}<br><small>{esc(a.get("subtitle") or "副标题未返回")}</small>' for n, a in enumerate(row.get('top5', []), 1))
        evidence = f'<details><summary>{esc(best.get("keyword", "无本地候选"))}</summary>{apps}<p><small>{esc(row.get("selectionRule", ""))}</small></p></details>'
        group = row['defaultLocalePlanningGroup']
        parts.append(f'<tr><td>{esc(row["country"])}<br><small>{row["store"].upper()}</small></td><td><a href="#{group}">{group}</a><br><small>规划归组</small></td><td>{metrics}</td><td>{evidence}</td><td>{esc(row["status"])}<br><small>{esc(row.get("error", ""))}</small><br><a href="{row["store"]}.json">首次记录</a></td></tr>')
    parts += ['</tbody></table></div><h2 id="openapplock">9 条评分也能排第 8？</h2>',
              '<p>Astro 本次重查：OpenAppLock 在美国 App Blocker 查询中排第 8，9 条评分，5.0。公开副标题是 “A simple app for blocking apps”，功能和搜索意图相符；它没有把 App Blocker 完整词组直接写在标题里。</p>',
              '<p>Apple 明确同时考虑文字相关性、下载、评分和评论等。我们看不到它的下载、该查询的用户行为、隐藏关键词和足够长的排名历史，所以不能断言第 8 名由哪一项造成。评分少不等于下载少，一次前十也不保证长期稳住。</p>',
              '<p>结论：不能因为对手评分多，就直接放弃大词。也不能因为它排第 8，就保证我们改名后能复制。已加入 Astro 竞品／关键词跟踪；未创建定时任务。</p>',
              '<p><a href="https://apps.apple.com/us/app/openapplock/id6780259647">OpenAppLock 商店页</a> · <a href="openapplock-case.json">本次证据</a> · <a href="audit-reconciled.json">完整逐国数据</a> · <a href="three-field-recommendations.json">三字段 JSON</a></p>',
              '<h2>上线后怎么判断</h2><p>由 Qi／Codex 在发布前记录 7–14 天基线；上线后看 7、14、28 天的关键词排名，以及 App Store Search 来源的曝光、首次下载和转化率，区分 Apple Ads 流量并记录其他获客变化。低流量延长观察；不会把单日排名或无法归到具体词的转化数据写成因果结论。</p>',
              '<script>document.querySelector("#filter").addEventListener("input",e=>{let q=e.target.value.toLowerCase();document.querySelectorAll("#countries tbody tr").forEach(r=>r.hidden=!r.textContent.toLowerCase().includes(q))})</script></html>']
    (OUT / 'index.html').write_text(''.join(parts))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--refresh-searches', action='store_true')
    parser.add_argument('--render', action='store_true')
    args = parser.parse_args()
    audit = reconcile(args.refresh_searches)
    print(json.dumps(audit['statusCounts']))
    if args.render:
        render(audit)

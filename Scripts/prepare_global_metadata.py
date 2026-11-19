#!/usr/bin/env python3
"""Stage researched title/subtitle/keyword decisions. No App Store writes."""
import json
from pathlib import Path
import re
import unicodedata

ROOT = Path(__file__).resolve().parents[1] / 'AppStore/ASO/next-release'
OUT = ROOT / 'all-storefronts'
existing = json.loads((ROOT / 'listings.json').read_text())
decisions = {}


def add(locale, name, subtitle, keywords, anchors, why, conflict=''):
    decisions[locale] = dict(name=name, subtitle=subtitle, keywords=keywords,
                             anchorStores=anchors, rationale=why, conflict=conflict,
                             scope='同步已有完整物料' if locale in existing else '仅三字段草案；未新增 UI 语言')


english_keywords = 'scroll,social,media,limit,break,digital,detox,doomscroll,distraction,habit,timer'
add('en-US', 'App Blocker – Duck on Duty', 'Screen Time Control & Focus', english_keywords, ['us'],
    '采用 Qi 最新提出的组合：最大相关需求 App Blocker 54/59 放主名；Screen Time Control 50/65 放副标题。关键词补 scroll。',
    'Scroll Blocker 35/15 是低竞争备选，仍保留为实验；不是因为 OpenAppLock 排第八就保证能复制。')
add('en-GB', 'App Blocker – Duck on Duty', 'Screen Time Control & Focus', english_keywords, ['gb', 'ie', 'nz', 'za'],
    '英国 App Blocker 52/48，比 Scroll Blocker 26/9 需求明显更高；没有同时满足相对热度门槛的低难度词，按用户偏好优先热度。',
    '大量国家共用 en-GB。印度偏 Screen Time，其他国家偏 Control，不能按国家分别写 en-GB 名称；副标题兼顾两者。')
add('en-AU', 'App Blocker – Duck on Duty', 'Screen Time Control & Focus', english_keywords, ['au'],
    '澳洲 Screen Time 49/42 与 App Blocker 48/40 很接近；人为选择略低竞争的 App Blocker，并保持英语品牌一致，副标题覆盖前者。')
add('en-CA', 'App Blocker – Duck on Duty', 'Screen Time Control & Focus', english_keywords, ['ca'],
    '加拿大 App Blocker 49/48，高于 Screen Time 46/46；Scroll Blocker 26/11 需求落差较大，选最大相关词。')
add('zh-Hans', '屏幕使用时间 – Duck on Duty', '戒手机，少刷社交媒体，到点休息',
    'app,blocker,screen,time,防沉迷,应用限制,专注,自律,数字健康,定时', ['cn'],
    '中国专项补查 22 个候选、8 个搜索词的前五名。屏幕使用时间 42/53，App Blocker 33/11 是值得保留的低竞争方向；专注 55/74、自律 50/75 意图偏宽。',
    '最终人为选择中文主名以清楚表达功能，英文 App Blocker 放关键词承接另一组需求；不把初筛公式直接当标题。锁机容易误解成锁整台手机，不采用。')
add('zh-Hant', '螢幕使用時間 – Duck on Duty', '戒手機，少滑社群動態，到點休息',
    '專注,防沉迷,滑手機,數位健康,減少分心,自律,應用限制', ['tw', 'hk'],
    '台湾螢幕使用時間 33/19，相关且有量、难度低。',
    '香港英文 App Blocker 38/9 更强，但与台湾共享繁体字段。英文 en-GB 本地化可承接英文设备用户；不能保证所有香港用户看到英文。')
add('ja', 'スマホ制限 – Duck on Duty', 'スクリーンタイム管理、アプリごとに休憩',
    'スマホ依存,デジタルデトックス,集中,タイマー,SNS', ['jp'],
    'スマホ制限 63/60、スクリーンタイム 60/46。主名优先热度，副标题覆盖较低难度的核心词；没有假称存在低竞争甜点。')
add('ko', '스크린타임 – Duck on Duty', '앱 차단으로 줄이는 SNS 사용 시간',
    '스마트폰중독,집중,타이머,디지털디톡스,휴식', ['kr'],
    '스크린타임 57/45 高于 앱차단 31/23；后者不足最高相关热度的六成，主名选择更大需求，副标题补充应用拦截。')
add('es-ES', 'Bloquear aplicaciones – Duck', 'Límites de tiempo y descansos',
    'pantalla,concentración,temporizador,redes,sociales,hábitos,pausa', ['es'],
    '西班牙 Bloquear aplicaciones 50/19，有量且难度低；缩短品牌为 Duck 才能在 30 字内保留完整功能表达。',
    '搜索结果包含隐私锁工具；副标题明确限时与休息，不声称密码保护。')
add('es-MX', 'Tiempo en pantalla – Duck', 'Bloquear aplicaciones y pausar',
    'límites,concentración,temporizador,redes,sociales,descanso,hábitos', ['mx', 'ar', 'cl', 'co'],
    '墨西哥 Tiempo en pantalla 33/38 高于 Bloquear aplicaciones 30/38；主名与副标题合并覆盖两个功能方向。',
    '阿根廷偏 Bloquear aplicaciones 44/17，智利与哥伦比亚偏 Tiempo en pantalla；共享 es-MX，只能在一组字段里折中。')
add('fr-FR', 'Screen Time – Duck on Duty', 'Bloqueur d’apps et pauses',
    'application,limite,concentration,minuteur,réseaux,sociaux,détox,habitude', ['fr'],
    '法国实测 Screen Time 35/44 高于 bloqueur application 22/47；temps d’écran 仅得 5 的低信号，不冒充高热度。主名用实测英文词，副标题保留自然法语。',
    'concentration 44/47 意图过宽，不因热度更高就用于主名。法语其他地区共用字段，未支持商店以法国为语言锚点。')
add('fr-CA', 'App Blocker – Duck on Duty', 'Temps d’écran et pauses',
    'application,limite,concentration,minuteur,réseaux,sociaux,détox,habitude', ['ca'],
    '加拿大本地 App Blocker 49/48 最大；主名保留该词，副标题用法语明确功能与休息。',
    '补查 temps d’écran、bloqueur application、bloqueur apps 均为低信号 5；不把国家级数据等同于魁北克用户的独立搜索量。见 ca-french-tracked.json。')
add('de-DE', 'App Blocker – Duck on Duty', 'Bildschirmzeit, feste Pausen',
    'fokus,timer,scrollen,handyzeit,sperren,digital,detox,limit,gewohnheit', ['de', 'at', 'ch'],
    '德国 App Blocker 52/52 略高于 Bildschirmzeit 50/47；前者放主名，后者放副标题；两项都保留。',
    '瑞士 apps sperren 26/13 更容易，但有密码锁意图且共用德语字段，不用其取代主功能。')
add('it', 'Tempo di utilizzo – Duck', 'Limiti app, pause obbligatorie',
    'concentrazione,timer,digitale,detox,scroll,abitudini,bloccare', ['it'],
    'Tempo di utilizzo 37/21 是相关的低竞争方向。blocco app 47/23 更热但混有隐私／密码锁意图，未直接以它命名。')
add('pt-BR', 'Tempo de Tela – Duck on Duty', 'Bloqueie apps e faça pausas',
    'limite,foco,celular,redes,sociais,digital,detox,cronômetro,hábito', ['br'],
    '巴西 tempo de tela 40/45 高于 bloquear aplicativos 33/40，优先热度；副标题自然表达拦截与暂停。')
add('pt-PT', 'Screen Time – Duck on Duty', 'Limites de apps e pausas',
    'ecrã,telemóvel,foco,bloquear,redes,sociais,digital,detox,temporizador', ['pt'],
    '葡萄牙 Screen Time 29/17 与 App Blocker 28/21 都可用；前者热度略高、难度更低。原生 tempo de ecrã 得 5，只作相关词而非流量主张。')
add('nl-NL', 'Schermtijd – Duck on Duty', 'App Blocker met vaste pauzes',
    'limiet,focus,scrollen,sociale,media,digitale,detox,timer,afleiding,gebruik', ['nl'],
    '荷兰 schermtijd 44/23，较 app blocker 48/45 只少少量热度、竞争明显更低，适合功能词前置。')
add('ru', 'Экранное время – Duck', 'Лимиты приложений и перерывы',
    'фокус,пауза,таймер,блокировка', ['ru'],
    '俄罗斯 экранное время 49/17；高热度、低难度且符合限时功能。避免直接声称隐私锁。俄文关键词按 UTF-8 字节控制。')
add('sv', 'App Blocker – Duck on Duty', 'Skärmtid, gränser och pauser',
    'fokus,scrolla,sociala,medier,digital,detox,timer,vanor,begränsa', ['se'],
    '瑞典 app blocker 34/38 高于 skärmtid 21/9；后者热度较低，不把低难度直接当最优，采用大词并在副标题覆盖原生词。')


def normalize(text):
    return unicodedata.normalize('NFKC', text).casefold()


def words(text):
    return set(re.findall(r'[^\W\d_]+', normalize(text)))


stop = {'de', 'di', 'do', 'da', 'd', 'e', 'et', 'mit', 'und', 'a', 'of', 'and', 'the', 'for', 'on', 'in', 'en', 'y', 'met', 'och', 'и'}
checks = {}
for locale, item in decisions.items():
    sizes = {key: len(item[key].encode()) if key == 'keywords' else len(item[key]) for key in ('name', 'subtitle', 'keywords')}
    assert 0 < sizes['name'] <= 30 and 0 < sizes['subtitle'] <= 30 and 0 < sizes['keywords'] <= 100, (locale, sizes)
    tokens = item['keywords'].split(',')
    assert all(t and t == t.strip() for t in tokens), locale
    assert len(set(map(normalize, tokens))) == len(tokens), locale
    indexed = words(item['name'] + ' ' + item['subtitle']) - stop
    repeated = (words(item['keywords']) - stop) & indexed
    assert not repeated, (locale, repeated)
    # ASCII singular/plural duplicates are wasteful even when spelling differs.
    stems = lambda terms: {w[:-1] if w.endswith('s') else w for w in terms if w.isascii()}
    assert not (stems(words(item['keywords']) - stop) & stems(indexed)), (locale, 'plural duplication')
    checks[locale] = sizes
    if locale in existing:
        for key in ('name', 'subtitle', 'keywords'):
            existing[locale][key] = item[key]
            (ROOT / 'metadata' / locale / (key + '.txt')).write_text(item[key] + '\n')
    else:
        directory = OUT / 'additional-localizations' / locale
        directory.mkdir(parents=True, exist_ok=True)
        for key in ('name', 'subtitle', 'keywords'):
            (directory / (key + '.txt')).write_text(item[key] + '\n')

result = {'state': 'Local draft only; no App Store Connect changes or name reservation.',
          'scope': 'Only name, subtitle, keywords. Sixteen complete existing listings updated; three new locales are metadata-only candidates.',
          'keywordEvidence': 'Functional relevance plus seed demand evidence; individual keyword tokens are not all separately volume-validated. No competitor brand names, website-blocking, private-lock or continuous-session claims.',
          'localizations': decisions, 'validation': checks}
(OUT / 'three-field-recommendations.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
(ROOT / 'listings.json').write_text(json.dumps(existing, ensure_ascii=False, indent=2) + '\n')
print('PASS:', len(decisions), 'three-field drafts;', len(existing), 'complete listings updated')

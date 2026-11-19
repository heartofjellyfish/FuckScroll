#!/usr/bin/env python3
"""Curated, localized three-field drafts informed by the deeper market research.
Never publishes or claims native-speaker, legal, or name-reservation clearance.
"""
from datetime import datetime,timezone
import json
from pathlib import Path
import re
import unicodedata

ROOT=Path(__file__).resolve().parents[1]/'AppStore/ASO/next-release';OUT=ROOT/'deep-research'
ROWS={
'en-US':('App Blocker – Duck on Duty','Screen Time Control & Focus','scroll,social,media,limit,break,digital,detox,doomscrolling,distraction,habit,timer,self,reduce,stop','us'),
'en-GB':('App Blocker – Duck on Duty','Screen Time Control & Focus','scroll,social,media,limit,break,doomscrolling,distraction,habit,timer,self,reduce,stop,stay,focused','gb,ie,nz,za,in'),
'en-AU':('App Blocker – Duck on Duty','Screen Time Limits & Focus','scroll,social,media,break,digital,detox,doomscrolling,distraction,timer,self,reduce,stop,control','au,nz'),
'en-CA':('App Blocker – Duck on Duty','Screen Time Control & Focus','scroll,social,media,limit,break,doomscrolling,distraction,habit,timer,self,reduce,stop,stay,focused','ca'),
'zh-Hans':('自觉鸭：戒手机与屏幕使用时间','少刷社交媒体，应用限时，到点休息','app,blocker,screen,time,control,防沉迷,专注,自律,数字健康,定时,自控力','cn,sg,my'),
'zh-Hant':('自覺鴨：戒手機與螢幕使用時間','少滑社群動態，應用限時，到點休息','app,blocker,screen,time,control,專注,防沉迷,數位健康,自律','tw,hk,mo'),
'ja':('スマホ制限 – みてるアヒル','スクリーンタイム管理、アプリごとに休憩','スマホ依存,デジタルデトックス,集中,タイマー,SNS','jp'),
'ko':('스크린타임 – 지켜보는 오리','앱마다 사용 한도와 쉬는 시간을 따로','앱차단,스마트폰중독,집중,타이머,디지털디톡스','kr'),
'fr-FR':('Screen Time – Canard de garde','Bloqueur d’apps, vraies pauses','control,scroll,blocker,limite,concentration,minuteur,réseaux,sociaux,détox','fr,be,ch,lu,ma,dz'),
'fr-CA':('App Blocker – Canard de garde','Temps d’écran, pauses imposées','screen,time,control,scroll,limite,concentration,minuteur,réseaux,sociaux,détox','ca'),
'de-DE':('App Blocker – Ente im Dienst','Bildschirmzeit, feste Pausen','fokus,timer,scrollen,handyzeit,sperren,digital,detox,limit,gewohnheit','de,at,ch,lu'),
'es-ES':('Bloquear aplicaciones – Pato','Tiempo de pantalla y descansos','concentración,temporizador,redes,sociales,hábitos,pausa,app,blocker','es'),
'es-MX':('Tiempo en pantalla – Pato','Bloquear aplicaciones y pausar','límites,concentración,temporizador,redes,sociales,descanso,app,blocker','mx,ar,cl,co,pe'),
'it':('Tempo di utilizzo – Papero','Limiti app, pause obbligatorie','concentrazione,timer,digitale,detox,scroll,abitudini,bloccare','it,ch'),
'pt-BR':('Tempo de Tela: Pato de Plantão','Bloqueie apps e faça pausas','limite,foco,celular,redes,sociais,digital,detox,cronômetro,hábito','br'),
'pt-PT':('Screen Time – Pato de Vigia','Limites de apps e pausas','ecrã,control,blocker,telemóvel,foco,bloquear,redes,sociais,detox','pt'),
'nl-NL':('Schermtijd – Eend op wacht','App Blocker met vaste pauzes','limiet,focus,scrollen,sociale,media,digitale,detox,timer,afleiding,gebruik','nl,be'),
'ru':('Экранное время – Утка на посту','Лимиты приложений и перерывы','фокус,пауза,таймер,ограничение','ru,kz,kg,ua'),
'sv':('Screen Time – Anka på vakt','App Blocker, skärmtid & pauser','fokus,scrolla,sociala,medier,digital,detox,timer,vanor,begränsa','se'),
'ar-SA':('Screen Time – بطّة الحراسة','حظر التطبيقات واستراحات','وقت الشاشة,تركيز,حدود,مؤقت,app,blocker','sa,ae,eg,iq,jo,kw,qa,om,bh'),
'tr':('Ekran Süresi – Nöbetçi Ördek','Uygulama sınırları ve molalar','engelleme,odak,dijital,detoks,telefon,bağımlılık,app,blocker','tr,cy'),
'hi':('Screen Time – पहरेदार बत्तख','ऐप की सीमा और फोन से ब्रेक','app,blocker,focus,digital,detox,लत,स्क्रीन टाइम','in'),
'id':('Screen Time Control – Bebek','Batasi aplikasi. Istirahat.','layar,fokus,kecanduan,ponsel,sosial,media,detoks,digital','id'),
'ms':('App Blocker – Itik Bertugas','Had aplikasi dan rehat wajib','masa,skrin,fokus,sekat,telefon,ketagihan,sosial,media,detoks,digital','my'),
'th':('Screen Time – เป็ดคุมเวลา','จำกัดแอป แล้วพักมือถือ','เวลาหน้าจอ,บล็อก,ติดมือถือ,app,blocker','th'),
'vi':('Screen Time – Vịt canh giờ','Giới hạn ứng dụng, nghỉ ngơi','màn hình,thời gian,tập trung,app,blocker','vn'),
'pl':('Czas przed ekranem – Kaczka','Blokuj aplikacje, rób przerwy','limit,skupienie,telefon,detoks,cyfrowy,scroll,app,blocker','pl'),
'cs':('Screen Time – Kachna','Blokování aplikací a přestávky','čas,obrazovka,limit,soustředění,telefon,detox,digitální,app,blocker','cz'),
'da':('Skærmtid – And på vagt','Bloker apps. Hold en pause.','fokus,mobil,afhængighed,grænser,digital,detox,timer,screen,time,blocker','dk'),
'fi':('Ruutuaika – Vahtiankka','Sovellusrajat ja tauot','esto,keskittyminen,puhelin,digipaasto,ajastin,app,blocker,screen,time','fi'),
'no':('Skjermtid – And på vakt','Blokker apper. Ta en pause.','fokus,mobil,avhengighet,grenser,digital,detox,timer,screen,time,blocker','no'),
'el':('App Blocker – Πάπια','Όρια εφαρμογών και διαλείμματα','συγκέντρωση,χρόνος,οθόνης,αποκλεισμός','gr,cy'),
'he':('זמן מסך – ברווז במשמרת','הגבלת אפליקציות והפסקות','ריכוז,טלפון,חסימה,התמכרות,app,blocker','il'),
'hu':('App Blocker – Őrkacsa','Appkorlátok és szünetek','képernyőidő,fókusz,telefon,függőség,blokkoló,digitális,detox','hu'),
'ro':('Screen Time – Rața de pază','Blochează aplicații, ia pauze','ecran,blocare,concentrare,telefon,dependență,detox,digital,app,blocker','ro'),
'sk':('Screen Time – Kačka','Limity aplikácií a prestávky','čas,obrazovka,blokovanie,sústredenie,telefón,detox,digitálny,app,blocker','sk'),
'uk':('Екранний час – Качка на варті','Ліміти застосунків і перерви','фокус,таймер,блокування,телефон','ua'),
'ca':('Screen Time – Ànec','Límits d’aplicacions i pauses','temps,pantalla,bloquejar,concentració,mòbil,xarxes,socials,detox,app,blocker','es'),
'hr':('Screen Time – Patka','Limiti aplikacija i predasi','zaslon,blokiranje,fokus,mobitel,ovisnost,digitalni,detoks,app,blocker','hr'),
'sl':('Screen Time – Račka','Omejitve aplikacij in odmori','čas,zaslon,blokiranje,zbranost,telefon,odvisnost,digitalni,detoks,app,blocker','si')}

# Reasons are written independently of field generation; metrics are attached
# below from actual country files, not copied from the US to another locale.
REASONS={
'en-US':'保留用户选定的大类词 App Blocker。Focus 作为宽泛目标可在副标题出现，但不取代主要拦截功能。',
'en-GB':'英国作为英语锚点，同时保留各共用国家的差异；不能为印度、爱尔兰和南非各写一份 en-GB。',
'en-AU':'澳洲 Screen Time Limit 28/38 比 Screen Time Control 9/48 更符合需求，因此副标题改为 Limits，control 留隐藏字段。与美区分别研究。',
'en-CA':'英语、法语候选在加拿大同一 storefront 分别查；不把英语指标当成魁北克独立搜索量。',
'zh-Hans':'中文品牌改为自觉鸭，读音呼应“自觉呀”，功能词也全部用中文。英语功能词留在隐藏字段，不强塞英文品牌。名称查无返回不等于已注册或商标获准。',
'zh-Hant':'繁体品牌跟随同一只鸭子，句子采用“滑、社群”等当地表达；台湾、香港和澳门各自的数据保留，不把三地看成同一市场。',
'ja':'みてるアヒル是“看着呢”的口语角色，搭配用户熟悉的スマホ制限；不硬译 Duck on Duty。',
'ko':'지켜보는 오리是看着你的鸭子。排除密码锁／家长保护的误解，突出每个 App 各自使用与休息。',
'fr-FR':'Canard de garde 借用看门伙伴的语感。法国英语功能词与法语词实际比较；不因 concentration 更热就把番茄钟意图当本产品。',
'fr-CA':'保留加拿大高意图的 App Blocker 功能表达，角色名与副标题用自然法语。法国与加拿大分开研究。',
'de-DE':'Ente im Dienst 是德语角色名；App Blocker 在德语同类中是常见表达，和原生 Bildschirmzeit 一起覆盖。密码保护词不做功能承诺。',
'es-ES':'以西班牙实际搜索表达选择功能词；Pato 是本地鸭子名，不保留英文后缀。避免用 contraseña／隐私锁吸引错误人群。',
'es-MX':'拉美多个国家共用西语字段，显式比较 pantalla／celular 等习惯；不能按国家独立发布同一 es-MX。',
'pt-BR':'Pato de Plantão 是巴西“值班鸭”的口语角色；tela／celular 按巴西习惯写。',
'pt-PT':'葡萄牙角色用 Pato de Vigia，副标题与关键词保留 ecrã／telemóvel。原生核心词仅低信号 5，英语 Screen Time 29/17 更有依据，因此功能主词采用当地实际搜索的英语，品牌不留英文后缀。',
'nl-NL':'Schermtijd 是原生核心词，Eend op wacht 是自然的看守鸭角色；不是把美区标题逐字翻译。',
'ru':'Утка на посту 是俄语“鸭子在岗”。блокировка приложений 47/13 虽好看，前五四款偏密码锁；主名仍选 экранное время 49/17，隐藏字段也去掉含混锁词。',
'sv':'本地角色 Anka på vakt；补查 Screen Time 38/23 同时比 App Blocker 34/38 更热且更低难度，调整主标题，后者移到副标题。'}
REASONS.update({
'ar-SA':'品牌改为阿拉伯语“看守鸭”，副标题也用阿拉伯语。沙特 قفل التطبيقات 57/21 的前五全偏密码锁；功能主词选更符合用途的 Screen Time 38/21，原生 وقت الشاشة 只作补充，不伪称高热度。',
'tr':'Nöbetçi Ördek 是本地值班鸭。Ekran süresi 39/11 是明确的原生核心词；不追家长控制 52/38。',
'hi':'角色名和副标题用印地语。完整专项中原生／音译功能词低信号，印度英语 Screen Time 40/42 更有依据，放主名；不把英语分数冒充印地语热度。',
'id':'Bebek 是当地鸭子名。印尼英语 Screen Time Control 38/17 比原生候选更有依据，完整放主名；副标题用当地语言说限制 App、休息。排除更热但偏密码锁的 kunci aplikasi。',
'ms':'Itik Bertugas 为马来语角色。马来西亚 App Blocker 33/17 适合主名；Screen Time 32/23 由字段协调覆盖。原生功能词低信号，不靠翻译制造流量结论；不写家长控制。',
'th':'เป็ดคุมเวลา 是“管时间的鸭子”。当地应用锁 37/11 偏隐私，สมาธิ 32/15 偏冥想／专注；选择相关的 Screen Time 32/19，角色名、副标题及补充词用泰语。',
'vi':'Vịt canh giờ 是看时间的鸭子。当地英语 Screen Time 37/40 有信号，放主名；副标题自然表达限 App、休息，Control 22/17 由隐藏字段覆盖。原生低信号不当作量化胜出。',
'pl':'波兰 blokada aplikacji 44/13 混有密码锁与番茄钟；改用 czas przed ekranem 36/13，前五更贴合限时功能。副标题自然表达拦应用与休息；不因热度较高就追错意图。',
'cs':'Kachna 是本地鸭子。捷克原生功能词信号低，主名选本国有依据的 Screen Time 35/23；副标题及辅助词用捷克语，App Blocker 32/23 由隐藏字段覆盖。',
'da':'丹麦原生 skærmtid 39/13 与英文 App Blocker 39/19 热度相同、难度更低，适合前置；角色 And på vagt，副标题是自然短句。',
'fi':'Ruutuaika 33/19 与英文 Screen Time 37/19 都相关，原生名便于理解，英语由隐藏字段覆盖。Vahtiankka 是角色候选，不把 lapsilukko 童锁功能照搬过来。',
'no':'挪威 skjermtid 36/23 是明确核心词，角色 And på vakt；与英文 Screen Time 34/17 一起覆盖，不追 foreldrekontroll 家长控制。',
'el':'品牌用希腊语 Πάπια。原生短语信号不足，功能主词选当地 App Blocker 35/17，副标题用希腊语说限制和休息；Screen Time 27/13 由隐藏字段承接。',
'he':'品牌改为希伯来语“值班鸭”。זמן מסך 28/15 与英语 Screen Time 40/15 都记录；密码锁、家长控制更热也不照抄。',
'hu':'Őrkacsa 是匈牙利语看守鸭候选。原生 képernyőidő 信号低，功能主词选择本国 App Blocker 41/15，副标题自然本地化；Screen Time 31/17 由隐藏字段承接，不写家长监护。',
'ro':'Rața de pază 为当地看守鸭。原生词信号低，功能主词选 Screen Time 38/19，比同热度的 App Blocker 38/21 竞争稍低；副标题用罗马尼亚语，后者由隐藏字段覆盖。',
'sk':'本地角色 Kačka。斯洛伐克原生功能词信号低，选择当地 Screen Time 38/15 配本地副标题，App Blocker 35/11 由隐藏字段覆盖；不是美区分数的移植。',
'uk':'用乌克兰语与 Качка на варті 的本地角色。乌克兰语、俄语、英语在乌克兰各查，俄语也保留独立字段；不把俄语词量当成乌克兰语词量。',
'ca':'角色 Ànec、副标题与辅助词用加泰语。完整专项中原生词信号低，采用西班牙境内有数据的 Screen Time 35/23；不把西班牙语 50 的词量移植为加泰语证据。',
'hr':'Patka 是当地鸭子。原生候选信号低，选 Screen Time 34/13，较同热度 App Blocker 34/21 难度低；副标题本地化，后者由隐藏字段承接。',
'sl':'用斯洛文尼亚语 Račka，与斯洛伐克语 Kačka 分开。完整专项中原生词信号低，采用当地 Screen Time 43/13，加本地副标题；真实返回不足五条的查询照实保留。'})

existing=json.loads((ROOT/'listings.json').read_text());drafts={};errors=[]
stop=set('a an the de di do da d e et mit und of and for on in en y met och и u ve le la du des at på и на'.split())
def words(s):return set(re.findall(r'[^\W\d_]+',unicodedata.normalize('NFKC',s).casefold()))
def latin_key(word):
    if any('LATIN' in unicodedata.name(c,'') for c in word):
        word=''.join(c for c in unicodedata.normalize('NFKD',word) if not unicodedata.combining(c))
        if len(word)>3 and word.endswith('s'):word=word[:-1]
    return word
for locale,(name,subtitle,keywords,anchors) in ROWS.items():
    # Add only complete English search groups with an actual signal in this
    # locale's research anchors. English brand names are not forced on users.
    additions=[];measured={}
    for store in anchors.split(','):
        path=OUT/'markets'/store/'metrics.json'
        if path.exists():
            for metric in json.loads(path.read_text()):
                q=metric['keyword']
                if metric.get('popularity',0)>measured.get(q,{}).get('popularity',0):measured[q]=dict(metric,sourceStore=store)
    if not locale.startswith('en-'):
        core=['screen time control','app blocker','screen time','scroll blocker','digital detox','self control']
        for q in sorted(core,key=lambda q:-measured.get(q,{}).get('popularity',0)):
            evidence=measured.get(q,{})
            if evidence.get('popularity',0)<=5:continue
            canonical=lambda ws:{latin_key(w) for w in ws}
            indexed=canonical(words(name+' '+subtitle+' '+keywords))
            new=[w for w in q.split() if w not in indexed]
            candidate=keywords+(','+','.join(new) if new else '')
            if new and len(candidate.encode())<=100:
                keywords=candidate;additions.append({'query':q,'addedTokens':new,'popularity':evidence['popularity'],'difficulty':evidence['difficulty'],'store':evidence['sourceStore']})
    sizes={'name':len(name),'subtitle':len(subtitle),'keywords':len(keywords.encode())}
    if any(sizes[k]>(100 if k=='keywords' else 30) for k in sizes):errors.append((locale,sizes))
    tokens=keywords.split(',')
    if any(not t or t!=t.strip() for t in tokens) or len(tokens)!=len(set(t.casefold() for t in tokens)):errors.append((locale,'bad tokens'))
    repeated=(words(name+' '+subtitle)&words(keywords))-stop
    # Python \w incorrectly splits Indic combining marks and Thai syllables.
    # Those two drafts receive whole-token comparisons rather than fake words.
    if locale in ['hi','th']:
        repeated={t for t in tokens if t.casefold() in (name+' '+subtitle).casefold()}
    if repeated:errors.append((locale,'duplicates',sorted(repeated)))
    canonical_tokens=[latin_key(t.casefold()) for t in tokens]
    if len(canonical_tokens)!=len(set(canonical_tokens)):errors.append((locale,'accent/plural keyword duplication'))
    if any(t.isascii() and len(t)<=2 for t in tokens):errors.append((locale,'too-short ASCII keyword'))
    evidence=[]
    for store in anchors.split(','):
        path=OUT/'markets'/store/'research.json'
        if path.exists():
            r=json.loads(path.read_text())
            evidence.append({'store':store,'status':r['status'],'metrics':len(r.get('metrics',[])),
                             'queries':len(r.get('searches',[])),'source':str(path.relative_to(ROOT))})
    study={'fr-CA':'ca-fr','hi':'in-hi','ca':'es-ca','sl':'si-sl'}.get(locale)
    if study:
        path=OUT/'language-studies'/study/'research.json'
        if path.exists():
            r=json.loads(path.read_text());evidence.append({'store':r['store'],'study':study,'status':r['status'],'metrics':len(r.get('metrics',[])),'queries':len(r.get('searches',[])),'source':str(path.relative_to(ROOT))})
    drafts[locale]={'name':name,'subtitle':subtitle,'keywords':keywords,'anchorStores':anchors.split(','),
                    'rationale':REASONS.get(locale,'本地功能表达与英语候选在该国比较后再确定；角色名也本地化。不是美区字段的直接翻译。'),
                    'evidence':evidence,'measuredEnglishAdditions':additions,'counts':sizes,'scope':'同步已有完整物料' if locale in existing else '三字段扩展草案；没有新增 App 内语言或完整商店资产',
                    'reviewState':'Prepared draft; language and brand review required before publishing. No registration/trademark clearance.'}
if errors:
    print(json.dumps(errors,ensure_ascii=False,indent=2));raise SystemExit(1)
result={'generatedAt':datetime.now(timezone.utc).isoformat(),'state':'Draft only; no Apple writes or name reservation.',
        'scope':'Existing 16 complete listings receive only name/subtitle/keyword edits. Additional locales are three-field drafts, not claims of translated UI or complete store assets.',
        'localizations':drafts}
(OUT/'metadata.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
for locale,row in drafts.items():
    folder=(ROOT/'metadata'/locale) if locale in existing else (OUT/'additional-localizations'/locale)
    folder.mkdir(parents=True,exist_ok=True)
    for key in ['name','subtitle','keywords']:
        (folder/(key+'.txt')).write_text(row[key]+'\n')
        if locale in existing:existing[locale][key]=row[key]
(ROOT/'listings.json').write_text(json.dumps(existing,ensure_ascii=False,indent=2)+'\n')
print('PASS',len(drafts),'localized drafts;',len(existing),'existing listings synchronized')

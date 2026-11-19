#!/usr/bin/env python3
"""Human-authored local search hypotheses, not translated US metadata or demand claims."""
import json
import re
import unicodedata
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/'AppStore/ASO/next-release'
OUT=ROOT/'deep-research'
OUT.mkdir(exist_ok=True)
TEXT={
'en':'app blocker|screen time|screen time control|scroll blocker|stop scrolling|social media blocker|block apps|app limits|screen time limit|reduce screen time|digital detox|stop doomscrolling|doomscroll|app timer|phone addiction|stay focused|focus|self control|distraction blocker|phone detox|screen time tracker|social media addiction|app lock|parental control',
'zh-Hans':'屏幕使用时间|戒手机|防沉迷|少刷手机|屏幕时间|屏幕时间管理|手机使用时间|控制手机时间|手机自律|自律|专注|锁机|应用限时|应用限制|戒网瘾|不玩手机|手机防沉迷|短视频防沉迷|少玩手机|时间管理|app blocker|screen time|自控力|放下手机',
'zh-Hant':'螢幕使用時間|戒手機|手機成癮|少滑手機|螢幕時間|螢幕時間管理|手機使用時間|限制手機時間|手機自律|自律|專注|鎖手機|應用程式限制|App限時|數位排毒|不玩手機|防沉迷|短影音成癮|減少滑手機|時間管理|app blocker|screen time|自制力|放下手機',
'fr':'temps d’écran|temps d\'écran|bloqueur d’apps|bloqueur d\'apps|bloqueur d’applications|bloquer des applications|contrôle du temps d’écran|limite temps écran|réduire temps écran|arrêter de scroller|addiction téléphone|détox digitale|detox digital|temps écran|blocage applications|limiter applications|limite applications|moins de téléphone|application anti addiction|concentration|app blocker|screen time|réseaux sociaux|contrôle parental',
'de':'bildschirmzeit|app blocker|apps sperren|app sperre|handy sucht|handysucht|handy weniger nutzen|handyzeit begrenzen|bildschirmzeit reduzieren|digital detox|apps blockieren|app limits|app zeitlimit|weniger scrollen|social media blocker|fokus|konzentration|selbstkontrolle|handy pause|zeit am handy|handynutzung kontrollieren|screen time|kindersicherung|handy sperren',
'es':'bloquear aplicaciones|tiempo de pantalla|tiempo en pantalla|bloqueador de apps|bloqueador de aplicaciones|limitar apps|limitar aplicaciones|control del tiempo de pantalla|adicción al móvil|adicción al celular|dejar de usar el móvil|dejar de usar el celular|dejar de hacer scroll|menos redes sociales|bloquear redes sociales|desintoxicación digital|concentración|autocontrol|límite de uso|temporizador de apps|app blocker|screen time|control parental|bloqueo de apps',
'it':'tempo di utilizzo|tempo sullo schermo|blocco app|blocca app|bloccare applicazioni|limiti app|limite tempo app|dipendenza telefono|dipendenza smartphone|usare meno il telefono|ridurre tempo schermo|smettere di scrollare|bloccare social|disintossicazione digitale|digital detox|concentrazione|autocontrollo|pausa telefono|timer app|app blocker|screen time|controllo parentale|limitare app|meno social',
'pt-BR':'tempo de tela|bloquear aplicativos|bloqueador de aplicativos|limite de uso|controle de tempo de tela|limitar aplicativos|bloquear apps|vício em celular|usar menos o celular|diminuir tempo de tela|parar de rolar|bloquear redes sociais|menos redes sociais|desintoxicação digital|detox digital|foco|autocontrole|pausa no celular|temporizador de aplicativos|app blocker|screen time|controle parental|tempo no celular|limite de apps',
'pt-PT':'tempo de ecrã|bloquear aplicações|bloqueador de aplicações|limite de utilização|controlo do tempo de ecrã|limitar aplicações|bloquear apps|dependência do telemóvel|usar menos o telemóvel|reduzir tempo de ecrã|parar de fazer scroll|bloquear redes sociais|menos redes sociais|desintoxicação digital|detox digital|concentração|autocontrolo|pausa no telemóvel|temporizador de aplicações|app blocker|screen time|controlo parental|tempo no telemóvel|limite de apps',
'ja':'スマホ制限|スクリーンタイム|アプリ制限|デジタルデトックス|スマホ依存|スマホ依存対策|スマホをやめる|スマホ時間|スマホ時間制限|使いすぎ防止|アプリブロック|アプリ使用制限|SNS制限|SNS依存|スマホ断ち|スクロール防止|集中|自制心|スマホ休憩|アプリタイマー|app blocker|screen time|ペアレンタルコントロール|スマホ管理',
'ko':'스크린타임|앱차단|앱 차단|사용시간 제한|디지털 디톡스|스마트폰 중독|스마트폰 사용 제한|핸드폰 중독|핸드폰 사용시간|앱 사용시간 제한|SNS 중독|SNS 차단|스마트폰 줄이기|휴대폰 사용시간|휴대폰 중독 방지|집중|자기 통제|스마트폰 휴식|앱 타이머|app blocker|screen time|자녀 보호|스크롤 중독|앱 잠금',
'nl':'schermtijd|app blocker|apps blokkeren|schermtijd beperken|stop scrollen|telefoonverslaving|minder op telefoon|schermtijd verminderen|apps vergrendelen|app limiet|social media blokkeren|minder sociale media|digitale detox|digital detox|focus|concentratie|zelfcontrole|telefoon pauze|app timer|screen time|schermtijd app|telefoongebruik|ouderlijk toezicht|tijdslimiet apps',
'ru':'экранное время|блокировка приложений|таймер приложений|цифровой детокс|лимит приложений|ограничение приложений|ограничение времени|зависимость от телефона|меньше телефона|время в телефоне|блокировщик приложений|блокировка соцсетей|меньше соцсетей|перестать листать|фокус|концентрация|самоконтроль|перерыв от телефона|контроль времени|app blocker|screen time|родительский контроль|лимит экранного времени|использование телефона',
'sv':'skärmtid|app blocker|blockera appar|digital detox|sluta scrolla|mobilberoende|mindre skärmtid|begränsa skärmtid|appgräns|tidsgräns appar|blockera sociala medier|mindre sociala medier|digital avgiftning|fokus|koncentration|självkontroll|mobilpaus|apptimer|screen time|skärmtidskontroll|mobilanvändning|föräldrakontroll|använda mobilen mindre|låsa appar',
'ar':'وقت الشاشة|مدة استخدام الجهاز|حظر التطبيقات|قفل التطبيقات|تقليل وقت الشاشة|تحديد وقت التطبيقات|حدود التطبيقات|إدمان الهاتف|إدمان الجوال|تقليل استخدام الهاتف|تقليل استخدام الجوال|حظر وسائل التواصل|إدمان السوشيال ميديا|التخلص من إدمان الهاتف|ديتوكس رقمي|تركيز|التحكم بالنفس|استراحة من الهاتف|مؤقت التطبيقات|app blocker|screen time|الرقابة الأبوية|إيقاف التمرير|تنظيم وقت الجوال',
'tr':'ekran süresi|uygulama engelleyici|uygulama engelleme|uygulama kilidi|telefon bağımlılığı|ekran süresi sınırı|telefonu az kullan|telefon kullanım süresi|sosyal medya engelleme|sosyal medya bağımlılığı|dijital detoks|odaklanma|odak|öz kontrol|telefon molası|uygulama zamanlayıcı|app blocker|screen time|ebeveyn kontrolü|ekran süresini azalt|uygulama sınırı|kaydırmayı bırak|telefon detoksu|kullanım sınırı',
'hi':'स्क्रीन टाइम|ऐप ब्लॉकर|ऐप लॉक|फोन की लत|मोबाइल की लत|फोन कम चलाएं|स्क्रीन टाइम लिमिट|ऐप टाइमर|सोशल मीडिया की लत|सोशल मीडिया ब्लॉकर|डिजिटल डिटॉक्स|ध्यान केंद्रित|आत्म नियंत्रण|फोन से ब्रेक|मोबाइल उपयोग समय|app blocker|screen time|digital detox|stop scrolling|social media blocker|phone addiction|parental control|ऐप की समय सीमा|मोबाइल कम इस्तेमाल',
'id':'waktu layar|pemblokir aplikasi|blokir aplikasi|kunci aplikasi|batas waktu aplikasi|batas penggunaan aplikasi|kecanduan hp|kecanduan ponsel|kurangi main hp|kurangi waktu layar|blokir media sosial|kecanduan media sosial|detoks digital|fokus|konsentrasi|kontrol diri|istirahat dari hp|timer aplikasi|app blocker|screen time|kontrol orang tua|berhenti scroll|waktu penggunaan hp|batasi aplikasi',
'ms':'masa skrin|penyekat aplikasi|sekat aplikasi|kunci aplikasi|had masa aplikasi|had penggunaan aplikasi|ketagihan telefon|kurangkan masa skrin|kurangkan guna telefon|sekat media sosial|ketagihan media sosial|detoks digital|fokus|tumpuan|kawalan diri|rehat telefon|pemasa aplikasi|app blocker|screen time|parental control|berhenti scroll|masa penggunaan telefon|kawalan ibu bapa|had aplikasi',
'th':'เวลาหน้าจอ|บล็อกแอป|ล็อกแอป|จำกัดเวลาแอป|จำกัดการใช้แอป|ติดมือถือ|ลดเวลาเล่นมือถือ|ลดเวลาหน้าจอ|บล็อกโซเชียล|ติดโซเชียล|เลิกไถหน้าจอ|เลิกเล่นมือถือ|ดีท็อกซ์ดิจิทัล|สมาธิ|โฟกัส|ควบคุมตัวเอง|พักจากมือถือ|จับเวลาแอป|app blocker|screen time|ควบคุมโดยผู้ปกครอง|เวลาใช้โทรศัพท์|จำกัดหน้าจอ|พักสายตา',
'vi':'thời gian sử dụng|thời gian màn hình|chặn ứng dụng|khóa ứng dụng|giới hạn ứng dụng|giới hạn thời gian|nghiện điện thoại|giảm dùng điện thoại|giảm thời gian màn hình|chặn mạng xã hội|nghiện mạng xã hội|cai nghiện điện thoại|cai điện thoại|thải độc số|tập trung|tự kiểm soát|nghỉ dùng điện thoại|hẹn giờ ứng dụng|app blocker|screen time|kiểm soát của cha mẹ|ngừng lướt|sử dụng điện thoại|giới hạn màn hình',
'pl':'czas przed ekranem|blokada aplikacji|blokowanie aplikacji|limit aplikacji|limit czasu aplikacji|uzależnienie od telefonu|mniej telefonu|ograniczenie czasu ekranu|kontrola czasu ekranu|blokada social mediów|mniej social mediów|cyfrowy detoks|digital detox|skupienie|koncentracja|samokontrola|przerwa od telefonu|timer aplikacji|app blocker|screen time|kontrola rodzicielska|przestań scrollować|czas na telefonie|blokada telefonu',
'cs':'čas u obrazovky|blokování aplikací|blokátor aplikací|zámek aplikací|limit aplikací|časový limit aplikací|závislost na telefonu|méně telefonu|omezit čas na telefonu|blokování sociálních sítí|méně sociálních sítí|digitální detox|digital detox|soustředění|koncentrace|sebekontrola|pauza od telefonu|časovač aplikací|app blocker|screen time|rodičovská kontrola|přestat scrollovat|používání telefonu|omezení aplikací',
'da':'skærmtid|app blokering|bloker apps|app lås|tidsgrænse apps|begræns skærmtid|mobilafhængighed|mindre mobil|reducer skærmtid|bloker sociale medier|mindre sociale medier|digital detox|fokus|koncentration|selvkontrol|mobilpause|app timer|app blocker|screen time|forældrekontrol|stop scrolling|telefonforbrug|skærmtidskontrol|app grænser',
'fi':'ruutuaika|sovellusten esto|sovellusesto|sovelluslukko|sovellusten aikaraja|ruutuajan rajoitus|puhelinriippuvuus|vähemmän puhelinta|vähennä ruutuaikaa|sosiaalisen median esto|vähemmän somea|digipaasto|digital detox|keskittyminen|keskittymiskyky|itsehillintä|puhelintauko|sovellusajastin|app blocker|screen time|lapsilukko|lopeta selaaminen|puhelimen käyttö|ruutuaikasovellus',
'no':'skjermtid|app blokkering|blokker apper|applås|tidsgrense apper|begrens skjermtid|mobilavhengighet|mindre mobil|reduser skjermtid|blokker sosiale medier|mindre sosiale medier|digital detox|fokus|konsentrasjon|selvkontroll|mobilpause|app timer|app blocker|screen time|foreldrekontroll|slutt å scrolle|mobilbruk|skjermtidskontroll|appgrenser',
'el':'χρόνος οθόνης|αποκλεισμός εφαρμογών|κλείδωμα εφαρμογών|όριο εφαρμογών|χρονικό όριο εφαρμογών|εθισμός στο κινητό|λιγότερο κινητό|μείωση χρόνου οθόνης|αποκλεισμός social media|εθισμός στα social media|ψηφιακή αποτοξίνωση|digital detox|συγκέντρωση|εστίαση|αυτοέλεγχος|διάλειμμα από το κινητό|χρονόμετρο εφαρμογών|app blocker|screen time|γονικός έλεγχος|σταμάτα το σκρολάρισμα|χρήση κινητού|όρια οθόνης|περιορισμός εφαρμογών',
'he':'זמן מסך|חסימת אפליקציות|נעילת אפליקציות|הגבלת אפליקציות|הגבלת זמן מסך|התמכרות לטלפון|פחות בטלפון|צמצום זמן מסך|חסימת רשתות חברתיות|התמכרות לרשתות חברתיות|גמילה דיגיטלית|digital detox|ריכוז|מיקוד|שליטה עצמית|הפסקה מהטלפון|טיימר אפליקציות|app blocker|screen time|בקרת הורים|להפסיק לגלול|שימוש בטלפון|מגבלת זמן|שימוש באפליקציות',
'hu':'képernyőidő|alkalmazásblokkoló|alkalmazások blokkolása|alkalmazászár|alkalmazás időkorlát|képernyőidő korlátozás|telefonfüggőség|kevesebb telefon|képernyőidő csökkentése|közösségi média blokkolás|közösségi média függőség|digitális detox|digital detox|fókusz|koncentráció|önkontroll|telefonszünet|alkalmazás időzítő|app blocker|screen time|szülői felügyelet|görgetés leállítása|telefonhasználat|alkalmazáskorlát',
'ro':'timp de ecran|blocare aplicații|blocator aplicații|blocare telefon|limită aplicații|limită de timp aplicații|dependență de telefon|mai puțin telefon|reducere timp de ecran|blocare rețele sociale|dependență de social media|detox digital|digital detox|concentrare|focalizare|autocontrol|pauză de telefon|temporizator aplicații|app blocker|screen time|control parental|oprește derularea|utilizare telefon|limite de ecran',
'sk':'čas pred obrazovkou|blokovanie aplikácií|blokovač aplikácií|zámok aplikácií|limit aplikácií|časový limit aplikácií|závislosť od telefónu|menej telefónu|obmedziť čas na mobile|blokovanie sociálnych sietí|menej sociálnych sietí|digitálny detox|digital detox|sústredenie|koncentrácia|sebakontrola|prestávka od telefónu|časovač aplikácií|app blocker|screen time|rodičovská kontrola|prestať scrollovať|používanie telefónu|obmedzenie aplikácií',
'uk':'екранний час|блокування застосунків|блокування додатків|ліміт застосунків|обмеження часу|залежність від телефону|менше телефону|час у телефоні|блокувальник застосунків|блокування соцмереж|менше соцмереж|цифровий детокс|digital detox|фокус|концентрація|самоконтроль|перерва від телефону|таймер застосунків|контроль часу|app blocker|screen time|батьківський контроль|припинити гортати|використання телефону',
'ca':'temps de pantalla|bloquejar aplicacions|bloquejador d’aplicacions|límit d’aplicacions|límit de temps|addicció al mòbil|menys mòbil|reduir temps de pantalla|bloquejar xarxes socials|menys xarxes socials|desintoxicació digital|digital detox|concentració|autocontrol|pausa del mòbil|temporitzador d’aplicacions|app blocker|screen time|control parental|deixar de fer scroll|temps d’ús|ús del mòbil|limitar aplicacions|bloqueig d’aplicacions',
'hr':'vrijeme uporabe zaslona|vrijeme na zaslonu|blokiranje aplikacija|blokator aplikacija|zaključavanje aplikacija|ograničenje aplikacija|vremensko ograničenje|ovisnost o mobitelu|manje mobitela|smanji vrijeme na mobitelu|blokiranje društvenih mreža|manje društvenih mreža|digitalni detoks|digital detox|fokus|koncentracija|samokontrola|pauza od mobitela|timer aplikacija|app blocker|screen time|roditeljski nadzor|prestani skrolati|uporaba mobitela'}
TEXT['sl']='čas pred zaslonom|čas zaslona|blokiranje aplikacij|blokator aplikacij|zaklepanje aplikacij|omejitev aplikacij|časovna omejitev|zasvojenost s telefonom|manj telefona|zmanjšaj čas pred zaslonom|blokiranje družbenih omrežij|manj družbenih omrežij|digitalni detoks|digital detox|zbranost|koncentracija|samokontrola|odmor od telefona|časovnik aplikacij|app blocker|screen time|starševski nadzor|prenehaj drseti|uporaba telefona'
PACKS={k:list(dict.fromkeys(v.split('|'))) for k,v in TEXT.items()}
for k,v in PACKS.items():assert len(v)>=22,(k,len(v))
# Country-specific language mixes. These are research hypotheses, not a claim
# that every resident uses a particular language or that each country has its own fields.
OVERRIDES={
'al':['en'],'dz':['ar','fr'],'am':['ru','en'],'az':['en','ru'],'bh':['ar','en'],'be':['nl','fr','de'],'bg':['en'],'kh':['en'],
'ca':['en','fr'],'hr':['hr','en'],'cy':['el','en'],'cz':['cs','en'],'dk':['da','en'],'eg':['ar','en'],'ee':['en'],'fi':['fi','en'],
'gr':['el','en'],'hk':['zh-Hant','en'],'hu':['hu','en'],'is':['en'],'in':['en','hi'],'id':['id','en'],'iq':['ar','en'],
'il':['he','ar','en'],'jo':['ar','en'],'kz':['ru','en'],'kw':['ar','en'],'kg':['ru','en'],'lv':['en'],'lb':['ar','fr','en'],
'lu':['fr','de','en'],'mo':['zh-Hant','en'],'my':['ms','en','zh-Hans'],'mn':['en'],'ma':['ar','fr'],'np':['en'],
'no':['no','en'],'om':['ar','en'],'pk':['en'],'ph':['en'],'pl':['pl','en'],'qa':['ar','en'],'ro':['ro','en'],
'sa':['ar','en'],'sg':['en','zh-Hans','ms'],'sk':['sk','en'],'si':['en'],'lk':['en'],'ch':['de','fr','it'],
'es':['es','ca'],'th':['th','en'],'tr':['tr','en'],'ua':['uk','ru','en'],'ae':['ar','en'],'uz':['en','ru'],'vn':['vi','en'],
'ao':['pt-PT'],'bj':['fr'],'bf':['fr'],'cm':['fr','en'],'cv':['pt-PT'],'td':['fr','ar'],'cd':['fr'],'cg':['fr'],'ci':['fr'],
'gw':['pt-PT'],'ly':['ar'],'mg':['fr'],'ml':['fr'],'mr':['ar','fr'],'mu':['en','fr'],'mz':['pt-PT'],'ne':['fr'],'st':['pt-PT'],
'sn':['fr'],'sc':['en','fr'],'tn':['ar','fr'],'ye':['ar'],'mt':['en'],'md':['ro','ru'],'lt':['en'],'me':['en'],
'rs':['en'],'ba':['hr','en'],'xk':['en'],'ge':['en'],'by':['ru'],'ve':['es'],'uy':['es'],'ni':['es']}
DEFAULT={'Simplified Chinese':'zh-Hans','Chinese (Traditional)':'zh-Hant','French':'fr','German':'de','Italian':'it',
         'Spanish (Spain)':'es','Spanish (Mexico)':'es','Portuguese (Brazil)':'pt-BR','Portuguese (Portugal)':'pt-PT',
         'Japanese':'ja','Korean':'ko','Dutch':'nl','Russian':'ru','Swedish':'sv'}
audit=json.loads((ROOT/'all-storefronts/audit-reconciled.json').read_text())['results']
records=[]
def unique_queries(values):
    seen=set();result=[]
    for value in values:
        key=unicodedata.normalize('NFKC',value).replace('’',"'").replace('‘',"'").casefold()
        key=re.sub(r'\s+','',key) if re.search('[가-힣]',key) else re.sub(r'\s+',' ',key).strip()
        if key not in seen:seen.add(key);result.append(value)
    return result
for old in audit:
    store=old['store'];langs=OVERRIDES.get(store,[DEFAULT.get(old['defaultLanguage'],'en')])
    primary=PACKS[langs[0]]
    # Twenty-two primary hypotheses plus meaningful secondary-language terms.
    # Explicitly research bilingual markets, rather than inferring their demand.
    candidates=list(primary)
    for lang in langs[1:]:candidates+=PACKS[lang][:8]
    if 'en' not in langs:candidates+=PACKS['en'][:4]
    candidates=list(dict.fromkeys(candidates))
    records.append({k:old[k] for k in ['store','country','defaultLanguage','additionalLanguages']}|
                   {'languages':langs,'candidates':candidates,'astroSupported':old['status']!='unsupported-by-astro',
                    'catalogQueries':unique_queries(unique_queries(primary)[:6]+PACKS['en'][:2]+primary[6:])[:8]})
assert all(len(m['catalogQueries'])==8 and len(m['candidates'])>=22 for m in records)
studies=[]
for store,lang in [('ca','fr'),('es','ca'),('in','hi'),('si','sl')]:
    country=next(r for r in records if r['store']==store)
    studies.append(dict(country,studyID=store+'-'+lang,languages=[lang,'en'],candidates=list(dict.fromkeys(PACKS[lang]+PACKS['en'][:8]))))
(OUT/'plan.json').write_text(json.dumps({'scope':'175 storefronts; local and multilingual search hypotheses; ≥22 candidates and eight searches per supported storefront, eight public-catalog queries as fallback where Astro is unsupported. No paid actions.','countryLanguageCaveat':'Research languages are hypotheses. Device language and available App Store localizations determine the displayed fields. Some local languages have no Apple metadata localization; no fake per-country fields.','packs':PACKS,'markets':records,'languageStudies':studies},ensure_ascii=False,indent=2)+'\n')
print('Plan:',len(records),'markets;',len(PACKS),'language packs;',sum(len(r['candidates']) for r in records),'country/keyword hypotheses')

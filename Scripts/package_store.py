"""Assemble the reviewed store copy, artwork and submission notes into one offline kit."""
import json
import struct
import subprocess
import tempfile
from html import escape
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
store = root / 'AppStore'
listings = json.loads((store / 'listings.json').read_text())
release = json.loads((store / 'release.json').read_text())
kit = f"Scroll-Stopper-{release['version']}-App-Store"
icon = root / 'ScrollStopper/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
field_limits = {'name': 30, 'subtitle': 30, 'keywords': 100, 'description': 4000, 'promotional_text': 170}
screens = ['01-break.png', '02-limits.png', '03-walk.png', '04-rules.png']
destination = store / f'{kit}.zip'
store_title = escape(listings[release['primaryLocale']]['name'])

def check_png(path, size):
    header = path.read_bytes()[:33]
    if header[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>IIBB', header[16:26]) != (*size, 8, 2):
        raise ValueError(f'Expected opaque RGB PNG, {size}: {path}')

with tempfile.TemporaryDirectory(dir=store) as temp:
    archive = Path(temp) / destination.name
    with ZipFile(archive, 'w', ZIP_DEFLATED, compresslevel=3) as z:
        def put(name, contents):
            z.writestr(f'{kit}/{name}', contents)
        def copy(name, src):
            z.write(src, f'{kit}/{name}')
        check_png(icon, (1024, 1024))
        copy('icon.png', icon)
        for name in ('review-notes.txt','release.json','verification.json','listings.json'):
            copy(name, store / name)
        for src in sorted((store / 'website').rglob('*.html')):
            copy(src.relative_to(store), src)
        for name in ('README-RELEASE.md', 'metadata-validation.json', 'Family-Controls-Request.md'):
            if (store/name).exists(): copy(name, store/name)
        copy('example-apps-by-market.json', store/'ExampleApps/markets.json')
        copy('example-app-sources.json', store/'ExampleApps/sources.json')
        sections = []
        for lang, listing in listings.items():
            for field, limit in field_limits.items():
                value = listing[field].strip()
                length = len(value.encode()) if field == 'keywords' else len(value)
                if not 0 < length <= limit:
                    raise ValueError(f'{lang}: {field} exceeds field limits or is empty')
                put(f'metadata/{lang}/{field}.txt', value + '\n')
            thumbs = []
            for name in screens:
                src = store / 'Screenshots' / lang / name
                check_png(src, (1290, 2796))
                original = f'screenshots/{lang}/1290x2796/{name}'
                copy(original, src)
                medium = Path(temp) / 'medium.png'
                subprocess.run(['magick',str(src),'-resize','1206x2622^','-gravity','center','-extent','1206x2622','-strip','PNG24:'+str(medium)],check=True)
                check_png(medium, (1206, 2622))
                copy(f'screenshots/{lang}/1206x2622/{name}', medium)
                alt = listing['captions'][len(thumbs)].replace('\n', ' ')
                if not thumbs:
                    alt += ' ' + listing['firstScreenshotDetail']
                thumbs.append(f'<a href="{original}"><img src="{original}" loading="lazy" width="230" alt="{escape(alt)}"></a>')
            sections.append(f'<section id="{lang}" lang="{lang}"><h2>{lang} · {escape(listing["subtitle"])}</h2><div>{"".join(thumbs)}</div><p>{escape(listing["promotional_text"])}</p><p>{escape(listing["description"]).replace(chr(10),"<br>")}</p></section>')
        nav = ' · '.join(f'<a href="#{lang}">{lang}</a>' for lang in listings)
        put('index.html','<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>'+store_title+' · Store review</title><style>body{max-width:52rem;margin:3rem auto;padding:0 1rem;background:#fdf6e6;color:#1d1c18;font:1rem/1.5 system-ui}a{color:inherit}section{padding:1rem 0;border-top:2px solid}section div{display:flex;gap:1%}section div a{width:24%}img{width:100%;height:auto}nav{margin:1.2rem 0}</style><h1>'+store_title+'</h1><p><strong>Build '+escape(release['build'])+' · Materials refreshed · Submission blocked</strong></p><p>Family Controls is missing from distribution profiles. Support and privacy pages need deployment. Nothing has been uploaded or submitted. See README-RELEASE.md.</p><nav>'+nav+'</nav>'+''.join(sections)+'</html>')
    with ZipFile(archive) as verified:
        assert verified.testzip() is None
        assert sum('/screenshots/' in n for n in verified.namelist()) == len(listings)*len(screens)*2
        assert sum('/metadata/' in n for n in verified.namelist()) == len(listings)*len(field_limits)
    archive.replace(destination)
print(f'{destination} ({destination.stat().st_size/1_000_000:.1f} MB)')

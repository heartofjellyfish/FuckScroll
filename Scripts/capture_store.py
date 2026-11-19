"""Capture shipping SwiftUI layouts with explicitly selected market-example fixtures."""
from pathlib import Path
import subprocess,sys,time,shutil,os,json
root=Path(__file__).resolve().parents[1]
device,icon_source=sys.argv[1:3]
langs=os.environ.get('DUCK_CAPTURE_LANGS','en,zh-Hans,zh-Hant,ja,ko,es,de,fr,it,pt-BR').split(',')
bundle='com.heartofjellyfish.scrollstopper'
def sim(*args,check=True):
 return subprocess.run(['xcrun','simctl',*args],check=check,capture_output=True,text=True)
sim('install',device,os.environ.get('DUCK_CAPTURE_APP_PATH',str(root/'.build/Build/Products/Debug-iphonesimulator/ScrollStopper.app')))
capture_root=Path(os.environ.get('DUCK_CAPTURE_OUT',str(root/'AppStore'/'Captures')))
def docs(dev):return Path(sim('get_app_container',dev,bundle,'data').stdout.strip())/'Documents'
folder,source=docs(device),docs(icon_source)
if folder!=source:
 for icon in source.glob('qa-icon-*.png'):shutil.copyfile(icon,folder/icon.name)
assert (folder/'qa-icon-8.png').exists()
original={f.name:f.read_bytes() for f in folder.glob('qa-icon-*.png')}
namefile=folder/'qa-app-names.json';original_names=namefile.read_bytes() if namefile.exists() else None
sim('status_bar',device,'override','--time','6:27','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--cellularMode','active','--cellularBars','4','--batteryState','discharging','--batteryLevel','100')
market_examples=json.loads((root/'AppStore/ExampleApps/markets.json').read_text())
default_names=['rednote','Instagram','Discord','Drums','Photos','Maps','Notes','Reminders','Calendar']
try:
 for lang in langs:
  examples=market_examples[lang];count=len(examples['apps'])
  assert count==len(examples['names']) and 1<=count<=9
  namefile.write_text(json.dumps(examples['names']+default_names[count:],ensure_ascii=False))
  for index,key in enumerate(examples['apps']):
   shutil.copyfile(root/'AppStore/ExampleApps/icons'/(key+'.png'),folder/f'qa-icon-{index}.png')
  scenes=[('01-break',['--rehearsal-rest','-rehearsalCount',str(count)]),('02-limits',['--rehearsal-rest','--qa-limits']),('03-walk',['--qa-edition-2']),('04-rules',['--rehearsal-paused','--settings'])]
  if lang=='en':scenes += [('review-eyebrow',['--qa-edition-1']),('review-intermission',['--qa-edition-0']),('review-nine',['--rehearsal-rest','-rehearsalCount','9'])]
  for name,args in scenes:
   if sys.argv[3:] and name not in sys.argv[3:]:continue
   target=capture_root/lang/(name+'.png');target.parent.mkdir(parents=True,exist_ok=True)
   sim('terminate',device,bundle,check=False)
   sim('launch',device,bundle,'--qa-store-market','-qaStoreExampleCount',str(count),'--locale-'+lang,*args)
   time.sleep(4 if lang==langs[0] and name=='01-break' else 2.3)
   for attempt in range(3):
    shot=sim('io',device,'screenshot',str(target),check=False)
    if shot.returncode==0:break
    print(shot.stderr,flush=True);time.sleep(1.5)
   if shot.returncode:raise RuntimeError('Screenshot failed: '+str(target))
   print(lang,name,examples['names'],flush=True)
finally:
 for name,data in original.items():(folder/name).write_bytes(data)
 if original_names is None:namefile.unlink(missing_ok=True)
 else:namefile.write_bytes(original_names)

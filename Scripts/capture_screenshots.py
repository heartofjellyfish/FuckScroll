#!/usr/bin/env python3
"""Capture real simulator renders via Xcode's simctl; no permission simulation."""
import subprocess, sys, time
from pathlib import Path
root = Path(__file__).resolve().parents[1]
device = sys.argv[1] if len(sys.argv) > 1 else '9AAA8A10-232C-4798-B514-9F0E2B6D2392'
prefix = sys.argv[2] if len(sys.argv) > 2 else ''
bundle = 'com.heartofjellyfish.scrollstopper'
out = root/'Design/Screenshots'
out.mkdir(parents=True,exist_ok=True)
def sim(*args, check=True):
    return subprocess.run(['xcrun','simctl',*args], check=check, capture_output=True, text=True)
sim('install',device,str(root/'.build/Build/Products/Debug-iphonesimulator/ScrollStopper.app'))
sim('status_bar',device,'override','--time','6:27','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--cellularMode','active','--cellularBars','4','--batteryState','discharging','--batteryLevel','100')
for name,args in [
    ('welcome',['--welcome']),
    ('interruption',['--preview']),
    ('rage',['--preview','--rage']),
    ('alternatives',['--preview','--alternatives']),
    ('goodbye',['--preview','--goodbye']),
    ('setup',['--setup']),
    ('settings',['--settings']),
    ('home',['--home']),
]:
    sim('terminate',device,bundle,check=False)
    sim('launch',device,bundle,'--en',*args)
    time.sleep(1.5)
    sim('io',device,'screenshot',str(out/(prefix+name+'.png')))
    print(name, flush=True)

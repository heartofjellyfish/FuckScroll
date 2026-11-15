#!/usr/bin/env python3
"""Lay out actual simulator screenshots for review; no UI is redrawn."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
root = Path(__file__).resolve().parents[1]
shots = root/'Design/Screenshots'
font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', 19)
def sheet(names, filename, width=350):
    first = Image.open(shots/(names[0][0]+'.png'))
    height = round(first.height * width / first.width)
    gap, margin = 24, 28
    out = Image.new('RGB', (margin*2 + width*len(names) + gap*(len(names)-1), height+100), '#e6e4de')
    draw = ImageDraw.Draw(out)
    for i, (name,label) in enumerate(names):
        shot = Image.open(shots/(name+'.png')).convert('RGB').resize((width,height),Image.Resampling.LANCZOS)
        mask = Image.new('L',(width,height),0)
        ImageDraw.Draw(mask).rounded_rectangle((0,0,width-1,height-1),radius=27,fill=255)
        x=margin+i*(width+gap)
        draw.text((x,21),label,font=font,fill='#22221e')
        out.paste(shot,(x,58),mask)
    out.save(root/'Design'/filename)
sheet([('welcome','01  /  First hello'),('interruption','02  /  Still scrolling?'),('rage','03  /  The last nerve'),('goodbye','04  /  Back to life')], 'visual-review.png')
sheet([('alternatives','What else to do'),('home','Waiting for setup'),('setup','Set the rules'),('settings','The honest details')], 'flow-review.png')
if (shots/'se-welcome.png').exists():
    sheet([('se-welcome','SE / First hello'),('se-alternatives','SE / Alternatives'),('se-goodbye','SE / Goodbye'),('se-chinese','SE / Chinese')], 'small-screen-review.png')

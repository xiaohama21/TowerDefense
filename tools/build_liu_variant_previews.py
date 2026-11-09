"""A/B review sheets and synchronized GIF from exact native Spine frames."""
from pathlib import Path
import argparse,json,math
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--frames',type=Path,default=ROOT/'build/liu_variants_0.9.8.1')
p.add_argument('--output',type=Path,default=ROOT/'build/liu_variants_review_0.9.8.1')
p.add_argument('--font',default='C:/Windows/Fonts/msyh.ttc');args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
FONT=lambda size:ImageFont.truetype(args.font,size)
BG='#182b27';PANEL='#233a32';TEXT='#f1ead7';GOLD='#d9bd7d';MUTED='#b0c1ae'
ids=['a_158','b_original'];names=['A · 158 底模改造','B · 原创分层重画']
rows=json.loads((args.frames/'frames.json').read_text(encoding='utf-8'))

def load(id,pose='Idle',index=0):return Image.open(args.frames/f'{id}_right_{pose}_{index:02d}.png').convert('RGBA')
def tight(img):return img.crop(img.getchannel('A').getbbox())
def base(size,title,subtitle):
    img=Image.new('RGBA',size,BG);d=ImageDraw.Draw(img)
    d.text((28,19),title,font=FONT(28),fill=TEXT);d.text((29,60),subtitle,font=FONT(16),fill=MUTED)
    return img,d

img,d=base((1180,770),'刘备 · 两版模型对照','同等游戏比例放大 4 倍 / 同一朝向 / 实际 Spine 渲染')
for i,id in enumerate(ids):
    x=24+i*590;d.rounded_rectangle((x,100,x+542,633),radius=14,fill=PANEL)
    d.text((x+23,119),names[i],font=FONT(23),fill=GOLD)
    caption='158 原骨架与网格 · 黑发束冠 · 双剑高低护势' if i==0 else '原创图层与骨架 · 大头比例 · 发束与甲袍分层'
    d.text((x+23,156),caption,font=FONT(16),fill=MUTED)
    art=tight(load(id));img.alpha_composite(art,(x+271-art.width//2,611-art.height))
    native=art.resize((round(art.width/4),round(art.height/4)),Image.Resampling.LANCZOS)
    img.alpha_composite(native,(x+271-native.width//2,745-native.height))
    d.text((x+18,739),'缩至游戏尺寸',font=FONT(14),fill=MUTED)
img.convert('RGB').save(args.output/'comparison.png')

poses=[('Attack_A','普攻',.33),('Critical','暴击',.44),('Active_A','光环',.4),('XX','大招',.55)]
selected=[r for r in rows if r['facing']==1 and r['pose'] in ['Idle']+[v[0] for v in poses]]
crop=(min(r['bbox'][0] for r in selected)-8,min(r['bbox'][1] for r in selected)-8,
      max(r['bbox'][0]+r['bbox'][2] for r in selected)+8,max(r['bbox'][1]+r['bbox'][3] for r in selected)+8)
scale=min(440/(crop[2]-crop[0]),390/(crop[3]-crop[1]));size=(round((crop[2]-crop[0])*scale),round((crop[3]-crop[1])*scale))
cache={}
for id in ids:
    for pose in ['Idle']+[v[0] for v in poses]:
        for index in range(16):cache[id,pose,index]=load(id,pose,index).crop(crop).resize(size,Image.Resampling.LANCZOS)
frames=[]
for pose,label,duration in poses:
    for tick in range(36):
        img,d=base((1000,610),'刘备 · '+label+'动作对照','0.5 倍慢放 / 两版同一时刻 / 暴击从实际命中帧接续')
        t=max(0,tick*.02-.08)
        for i,id in enumerate(ids):
            x=18+i*500;d.rounded_rectangle((x,101,x+464,584),radius=12,fill=PANEL)
            d.text((x+20,116),names[i],font=FONT(20),fill=GOLD)
            shown=pose;index=min(15,round(t/duration*15))
            if pose=='Critical' and t<.11:shown='Attack_A';index=round(t/.33*15)
            if t>duration:shown='Idle';index=0
            img.alpha_composite(cache[id,shown,index],(x+232-size[0]//2,169+(390-size[1])//2))
        frames.append(img.convert('RGB'))
frames[0].save(args.output/'actions.gif',save_all=True,append_images=frames[1:],duration=40,loop=0,disposal=2)

img,d=base((1180,1080),'刘备 · 关键动作帧','每行左右为 A / B；上起：普攻命中、暴击、光环、大招中段')
for row,(pose,label,duration) in enumerate(poses):
    at=.11 if pose in ['Attack_A','Critical'] else .12 if pose=='Active_A' else .22
    index=round(at/duration*15)
    for i,id in enumerate(ids):
        x=20+i*590;y=105+row*235
        d.rounded_rectangle((x,y,x+550,y+220),radius=10,fill=PANEL)
        d.text((x+12,y+10),('A' if i==0 else 'B')+' · '+label,font=FONT(17),fill=GOLD)
        art=load(id,pose,index).crop(crop)
        ratio=min(500/art.width,183/art.height);art=art.resize((round(art.width*ratio),round(art.height*ratio)),Image.Resampling.LANCZOS)
        img.alpha_composite(art,(x+275-art.width//2,y+34))
img.convert('RGB').save(args.output/'keyframes.png')
(args.output/'preview.json').write_text(json.dumps({'source':'native Spine captures','program':'0.9.8.1','variants':ids,'slow_motion':.5,'capture_frames':len(rows),'crop':crop},indent=2),encoding='utf-8')
print('LIU_AB_PREVIEWS: comparison.png, actions.gif, keyframes.png')

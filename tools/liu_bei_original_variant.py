"""Original candidate B: chibi proportions and layered hair, without D69 parts."""
from pathlib import Path
import json,sys,math
from PIL import Image
import liu_bei_art as art

ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/battle_visuals/liu_bei/variants/b_original'

def parts():
    p=art.parts();draw=art.path
    locks=draw('M-13 -31 Q-31 -27 -30 -6 L-35 14 L-28 9 L-31 29 L-20 22 L-21 38 L-9 25 L-5 -18 Z','#253b33')
    locks+=draw('M-21 -23 L-24 -7 L-29 9 L-23 5 L-26 21 L-19 16 L-17 26 L-13 9 L-14 -24 Z','#455b48','none',0)
    locks+=draw('M-24 -14 L-27 0 M-21 3 L-22 12','none','#6e8060',1)
    fringe=draw('M-18 -25 Q-7 -34 8 -27 L18 -16 L21 -3 L12 -8 L8 -5 L-6 -18 L-10 -11 L-10 -22 L-19 -15 Z','#2c4035')
    fringe+=draw('M-14 -24 L-5 -27 L7 -25 L13 -17 L7 -18 L12 -10 L-1 -20 L-5 -16 L-7 -23 Z','#50624b','none',0)
    fringe+=draw('M-9 -25 L2 -25 L7 -22','none','#7b8564',1)
    p['hair_locks']=art.defs()+locks;p['forelock']=art.defs()+fringe
    return p

def rig():
    d=art.rig();bones={b['name']:b for b in d['bones']}
    bones['torso'].update(y=69,rotation=-8)
    bones['head'].update(y=64,x=2,rotation=8,scaleX=1.28,scaleY=1.16)
    bones['upper_r']['rotation']=40;bones['fore_r']['rotation']=30
    bones['upper_l']['rotation']=-20;bones['fore_l']['rotation']=-25
    bones['boot_l'].update(x=-18,y=17,rotation=0)
    bones['boot_r'].update(x=17,y=14,rotation=-6)
    d['bones'] += [{'name':'hair_locks','parent':'head'},{'name':'forelock','parent':'head'}]
    slots=d['slots'];head_index=next(i for i,s in enumerate(slots) if s['name']=='head')
    slots.insert(head_index,{'name':'hair_locks','bone':'hair_locks','attachment':'hair_locks'})
    slots.insert(head_index+2,{'name':'forelock','bone':'forelock','attachment':'forelock'})
    skin=d['skins'][0]['attachments']
    for name in ['hair_locks','forelock']:skin[name]={name:{'path':name,'width':128,'height':128}}
    skin['shoulder_r']['shoulder'].update(width=99,height=108)
    d['animations']['Idle']['bones']['hair_locks']=art.rotations([(0,-2),(.65,3),(1.3,-2)])
    d['animations']['Idle']['bones']['forelock']=art.rotations([(0,0),(.65,1.2),(1.3,0)])
    for name,end in [('Attack_A',.33),('Critical',.44),('XX',.55)]:
        d['animations'][name]['bones']['hair_locks']=art.rotations([(0,0),(.11,-8),(end,0)])
    return d

def generate():
    source=DEST/'source';source.mkdir(parents=True,exist_ok=True);entries=[]
    for name,body in parts().items():
        w,h=art.dimensions(name)
        svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{-w//2} {-h//2} {w} {h}">{body}</svg>'
        (source/f'{name}.svg').write_text(svg,encoding='utf-8',newline='\n')
        relative=source.relative_to(ROOT/'assets/battle_visuals').as_posix()
        entries.append({'svg':f'{relative}/{name}.svg','png':f'{relative}/{name}.png','pixels':128,'width':w*2,'height':h*2})
    (DEST/'render_manifest.json').write_text(json.dumps({'entries':entries},indent=2),encoding='utf-8',newline='\n')
    (DEST/'liu_bei_original.spine-json').write_text(json.dumps(rig(),separators=(',',':')),encoding='utf-8')
    relative=DEST.relative_to(ROOT).as_posix()
    (DEST/'liu_bei_original-data.tres').write_text(f'[gd_resource type="SpineSkeletonDataResource" load_steps=3 format=3]\n[ext_resource type="SpineAtlasResource" path="res://{relative}/liu_bei_original.atlas" id="1"]\n[ext_resource type="SpineSkeletonFileResource" path="res://{relative}/liu_bei_original.spine-json" id="2"]\n[resource]\natlas_res=ExtResource("1")\nskeleton_file_res=ExtResource("2")\ndefault_mix=0.08\n',encoding='utf-8',newline='\n')
    print('LIU_ORIGINAL_VARIANT sources ready')

def pack():
    regions=[];x=y=row=0
    for name in parts():
        img=Image.open(DEST/'source'/f'{name}.png').convert('RGBA')
        if x+img.width>1024:x=0;y+=row;row=0
        regions.append((name,img,x,y));x+=img.width;row=max(row,img.height)
    height=2**math.ceil(math.log2(y+row));atlas=Image.new('RGBA',(1024,height))
    lines=f'liu_bei_original.png\nsize: 1024,{height}\nformat: RGBA8888\nfilter: Linear,Linear\nrepeat: none\n'
    for name,img,x,y in regions:
        atlas.alpha_composite(img,(x,y));lines+=f'{name}\n  rotate: false\n  xy: {x}, {y}\n  size: {img.width}, {img.height}\n  orig: {img.width}, {img.height}\n  offset: 0, 0\n  index: -1\n'
    atlas.save(DEST/'liu_bei_original.png');(DEST/'liu_bei_original.atlas').write_text(lines,encoding='utf-8')
    (DEST/'README.md').write_text('# 刘备 B：原创分层试作\n\n原创SVG零件与Spine骨架；参考用户指定158的Q版头身、侧向重心和分层发束/衣摆，不包含158图集或骨架。\n\n生成：python tools/liu_bei_original_variant.py；Godot tools/render_battle_visuals.gd带--manifest=res://assets/battle_visuals/liu_bei/variants/b_original/render_manifest.json；python tools/liu_bei_original_variant.py --pack。\n',encoding='utf-8',newline='\n')
    print('LIU_ORIGINAL_VARIANT packed')

if __name__=='__main__':pack() if '--pack' in sys.argv else generate()

"""Original battle SVG parts and Spine 4.3 rigs. Rasterize with Godot, then --pack.

Enemy/map art stays editable; Liu Bei imports the archived, user-selected original #158.
"""
from pathlib import Path
import json, sys, hashlib
import liu_bei_art
import import_liu_bei_158
import import_d69_heroes

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/battle_visuals'
INK = '#302b28'
ACTORS = {
    'liu_bei': dict(scale=.53, foot=8, native_facing=-1, hit=.11, attack_source_hit=.5333, attack_duration=.8667*.11/.5333, ult_hit=0, ult_duration=.55, ultimate='Appear', critical='Critical', role='hero', source='D69 #158 / Hero_LiBai_A'),
    'yellow_turban_soldier': dict(scale=.28, foot=16, top=131, width=95, coat='#a5966b', trim='#dbb450', skin='#daba8e', role='soldier'),
    'yellow_turban_cavalry': dict(scale=.30, foot=20, top=167, width=160, coat='#8b7858', trim='#ddbb53', skin='#daba8e', role='cavalry'),
    'yellow_turban_sergeant': dict(scale=.33, foot=18, top=134, width=126, coat='#5b6265', trim='#dbc259', skin='#daba8e', role='sergeant'),
    'yellow_turban_general': dict(scale=.43, foot=24, top=137, width=144, coat='#68594c', trim='#dab44c', skin='#cead85', role='boss'),
}
ACTORS.update(import_d69_heroes.actor_specs())

def path(d, fill, stroke=INK, width=3):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'

def ellipse(x,y,rx,ry,fill,stroke=INK,width=3):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'

def svg(body, part=True, dimensions=(128,128)):
    w,h=dimensions if part else (80,80)
    box=f'{-w//2} {-h//2} {w} {h}' if part else '0 0 80 80'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{box}">{body}</svg>'

def parts(spec):
    if spec['role']=='hero': return liu_bei_art.parts()
    role=spec['role']; coat=spec['coat']; trim=spec['trim']; skin=spec['skin']
    head=ellipse(0,0,23,25,skin)
    head+=path('M-23 -4 Q-25 -26 -8 -29 Q14 -31 24 -16 L23 1 Q15 -9 12 -15 Q-9 -13 -23 -4', '#393331')
    head+=path('M-20 11 Q-18 23 0 26 Q17 24 22 10 Q12 25 -2 22 Q-13 20 -20 11', '#bb9675','none',0)
    head+=ellipse(-8,0,2.8,3.8,'#302b28','none',0)+ellipse(8,1,2.3,3.1,'#302b28','none',0)
    head+=path('M-13 -7 L-5 -8 M5 -7 L12 -5 M-16 7 Q-12 10 -8 7','none',INK,2)
    head+=path('M-6 15 Q1 18 8 14','none',INK,1.6)
    if role=='hero':
        head+=path('M-11 -24 L-10 -37 Q0 -43 10 -36 L12 -24 Z','#3c5547')
        head+=path('M-7 -26 L-6 -35 L7 -35 L8 -26',trim,INK,2)
        head+=path('M-13 17 Q-4 30 4 28 L9 16 Q-2 22 -13 17','#463931',INK,1.7)
    else:
        head+=path('M-24 -13 Q0 -19 24 -9 L23 -3 Q1 -12 -22 -5 Z',trim,INK,2)
        head+=path('M18 -8 Q34 -11 37 -1 L24 3 L30 11 L20 5',trim,INK,2)
        if role in ['sergeant','boss']:
            head+=path('M-24 -15 Q-21 -34 0 -36 Q24 -33 26 -13 L19 -12 Q1 -22 -24 -15',coat)
            head+=path('M-3 -35 L4 -35 L7 -18 L-2 -18 Z',trim,INK,2)
            head+=path('M-23 -9 L-27 10 L-21 19 L-14 11 L-15 -7',coat)
            head+=path('M19 -7 L25 11 L18 20 L11 11 L12 -9',coat)
        if role=='boss':
            head+=path('M-16 14 Q0 24 18 13 L13 34 L2 39 L-11 32 Z','#4c3b2b')
            head+=path('M-7 23 L-6 30 M4 24 L4 33','none','#7b6045',1.5)
    body=path('M-16 -27 Q0 -36 17 -24 L23 17 L13 30 L-14 28 L-24 16 Z',coat)
    body+=path('M-12 -24 L0 -6 L13 -25 L8 -8 L0 0 L-16 -16', '#ced1b1' if role=='hero' else '#bbb197',INK,2)
    body+=path('M-20 7 L21 7 L21 14 L-21 14 Z','#5b4130',INK,2)
    body+=path('M-5 7 L6 7 L6 14 L-5 14 Z',trim,INK,1.5)
    body+=path('M-9 15 L-11 25 M5 16 L7 26','none','#d9ceac',1.5)
    if role in ['sergeant','boss']:
        body+=path('M-19 -23 L-3 -20 L-3 4 L-21 3 Z M3 -20 L20 -22 L21 3 L3 4 Z','#767a74')
        body+=path('M-19 -12 L-5 -10 M5 -10 L19 -12 M-20 -2 L-5 -1 M5 -1 L20 -3','none',trim,1.4)
    cape=path('M-14 -30 Q-35 -19 -32 8 L-27 33 L-13 26 L-3 34 L13 24 L24 31 Q31 0 14 -28 Z', '#316347' if role=='hero' else '#8b683d')
    cape+=path('M-24 -9 Q-19 13 -22 27 M15 -11 Q19 8 14 22','none','#629474' if role=='hero' else '#ac8450',2)
    boot=path('M-6 -11 L6 -11 L7 4 L12 10 Q4 15 -10 10 L-10 2 Z','#514132')
    boot+=path('M-7 -1 L6 -1','none','#bea075',2)
    arm=path('M-5 -4 Q-13 0 -12 13 L-7 22 L5 19 L8 9 L5 -3 Z',coat)
    arm+=ellipse(-1,21,7,6,skin,INK,2)
    blade=path('M-4 7 L-7 -35 L0 -49 L7 -35 L4 7 Z','#ccd2c9')
    blade+=path('M0 -43 L0 6','none','#f4f1d9',1.4)
    blade+=path('M-9 8 L9 8 L9 12 L-9 12 Z M-3 13 L3 13 L3 26 L-3 26 Z',trim,INK,2)
    blade+=ellipse(0,27,4,3,trim,INK,1.5)
    shield=path('M-22 -12 L0 -21 L22 -12 L19 17 L0 30 L-20 17 Z','#7a6242')
    shield+=path('M-18 -9 L0 -16 L17 -9 L14 14 L0 24 L-15 14 Z','#b19968',INK,2)
    shield+=path('M-2 -15 L3 -15 L3 24 L-2 24 Z',coat,INK,1.2)
    shield+=ellipse(0,4,5,5,trim,INK,2)
    hammer=path('M-3 13 L3 13 L3 -29 L-3 -29 Z','#74543a')
    hammer+=path('M-24 -39 L24 -39 L27 -20 L-26 -20 Z','#737772')
    hammer+=path('M-23 -39 L24 -39 L21 -33 L-20 -33 Z','#a1a69b',INK,2)
    hammer+=path('M-19 -36 L-18 -23 M18 -36 L18 -22','none',trim,2.5)
    spear=path('M-2 31 L3 31 L3 -41 L-2 -41 Z','#8d6945',INK,2)
    spear+=path('M-6 -39 L0 -60 L7 -40 L1 -31 Z','#cbd1c5',INK,2)
    spear+=path('M2 -34 L14 -25 L5 -17 Z',trim,INK,1.5)
    horse=path('M-49 -11 Q-52 -26 -26 -29 L17 -28 L28 -40 L37 -43 L48 -32 L46 -16 L39 -6 L29 -6 L26 20 Q-3 30 -32 14 L-44 14 Z','#795940')
    horse+=path('M-43 -8 Q-26 -22 1 -18 L26 -8 L25 9 Q-1 20 -36 7 Z','#a5825b',INK,2)
    horse+=path('M-9 -24 L13 -24 L17 10 L-12 10 Z','#977444')
    horse+=path('M32 -42 L29 -30 L37 -17 L32 -4','none','#42332a',4)
    horse+=ellipse(40,-28,2.5,2.5,'#211f20','none',0)
    horse+=path('M-49 -14 Q-58 -1 -55 12 L-49 4','none','#42332a',5)
    return dict(cape=cape, body=body, head=head, boot=boot, arm=arm,
        weapon=hammer if role=='boss' else spear if role=='cavalry' else blade,
        offhand=shield if role=='sergeant' else blade if role=='hero' else arm,
        horse=horse)

def animation_cycle(a,b,duration,field='value'):
    return [{'time':0,field:a},{'time':duration/2,field:b},{'time':duration,field:a}]

def rig(spec):
    if spec['role']=='hero': return liu_bei_art.rig()
    mounted=spec['role']=='cavalry'; lift=34 if mounted else 0
    bones=[dict(name='root'),dict(name='torso',parent='root',y=54+lift),dict(name='cape',parent='torso'),
        dict(name='boot_l',parent='root',x=-10,y=15),dict(name='boot_r',parent='root',x=10,y=15),
        dict(name='arm_l',parent='torso',x=-21,y=13),dict(name='arm_r',parent='torso',x=20,y=12),
        dict(name='weapon',parent='arm_l',x=-2,y=-17,rotation=27),dict(name='offhand',parent='arm_r',x=1,y=-19,rotation=-18),
        dict(name='head',parent='torso',x=0,y=45),dict(name='horse',parent='root',x=0,y=37,scaleX=1.55)]
    if mounted:
        bones += [dict(name=name,parent='root',x=x,y=15) for name,x in [('hoof_bl',-42),('hoof_br',-32),('hoof_fl',31),('hoof_fr',41)]]
        for bone in bones:
            if bone['name'] in ['boot_l','boot_r']: bone['y']=55
    if spec['role']=='boss':
        bones[1]['scaleX']=1.25
        for bone in bones:
            if bone['name']=='offhand': bone.update(x=-5,y=-14,rotation=35)
    ordered=(['hoof_bl','hoof_fl','horse','hoof_br','hoof_fr'] if mounted else [])+['cape','boot_l','boot_r','body','arm_r','arm_l','head','offhand','weapon']
    slots=[]; attachments={}
    for part in ordered:
        art='boot' if part.startswith(('boot','hoof')) else 'arm' if part.startswith('arm') else part
        bone='torso' if part=='body' else part
        slots.append(dict(name=part,bone=bone,attachment=art))
        attachments[part]={art:dict(path=art,width=128,height=128)}
    idle={'bones':{'torso':{'translate':animation_cycle(0,2,1.2,'y')},'head':{'rotate':animation_cycle(-1,1,1.2)},'cape':{'rotate':animation_cycle(0,3,1.2)}}}
    move={'bones':{'torso':{'translate':animation_cycle(0,2.5,.5,'y')},'boot_l':{'rotate':animation_cycle(-18,18,.5)},'boot_r':{'rotate':animation_cycle(18,-18,.5)},'head':{'rotate':animation_cycle(-1.5,1.5,.5)}}}
    if mounted:
        for i,name in enumerate(['hoof_bl','hoof_br','hoof_fl','hoof_fr']):
            move['bones'][name]={'rotate':animation_cycle(-24 if i%2 else 24,24 if i%2 else -24,.5)}
    attack={'bones':{'arm_l':{'rotate':[{'time':0,'value':0},{'time':.055,'value':-65},{'time':.11,'value':55},{'time':.33,'value':0}]},'arm_r':{'rotate':animation_cycle(0,-25,.33)},'torso':{'rotate':animation_cycle(0,-7,.33)}},'events':[{'time':.11,'name':'Effect'}]}
    ultimate={'bones':{'arm_l':{'rotate':animation_cycle(0,65,.55)},'arm_r':{'rotate':animation_cycle(0,-65,.55)},'head':{'rotate':animation_cycle(0,-8,.55)}},'events':[{'time':0,'name':'Effect'}]}
    return dict(skeleton=dict(spine='4.3.00',x=-80,y=0,width=160,height=167 if mounted else 137),
        bones=bones, slots=slots, skins=[dict(name='default',attachments=attachments)], events=dict(Effect={}),
        animations=dict(Idle=idle,Move=move,Attack_A=attack,XX=ultimate,
            Stun={'bones':{'head':{'rotate':animation_cycle(-7,7,.5)}}},
            Death={'bones':{'torso':{'rotate':[{'value':0},{'time':.4,'value':72}]}}}))

def map_art():
    from map_field_art import map_art as field_art
    return field_art()


def generate():
    import_d69_heroes.generate()
    entries=[]
    for id,spec in ACTORS.items():
        if id in import_d69_heroes.MODELS: continue
        if id == 'liu_bei':
            import_liu_bei_158.generate()
            continue
        folder=BASE/id; (folder/'source').mkdir(parents=True,exist_ok=True)
        for name,body in parts(spec).items():
            size=liu_bei_art.dimensions(name) if spec['role']=='hero' else (128,128)
            relative=f'{id}/source/{name}.svg'; (BASE/relative).write_text(svg(body,dimensions=size),encoding='utf-8',newline='\n')
            density=2 if spec['role']=='hero' else 1
            entries.append(dict(svg=relative,png=f'{id}/source/{name}.png',pixels=128,width=size[0]*density,height=size[1]*density))
        (folder/f'{id}.spine-json').write_text(json.dumps(rig(spec),separators=(',',':')),encoding='utf-8')
        (folder/f'{id}-data.tres').write_text(f'''[gd_resource type="SpineSkeletonDataResource" load_steps=3 format=3]

[ext_resource type="SpineAtlasResource" path="res://assets/battle_visuals/{id}/{id}.atlas" id="1"]
[ext_resource type="SpineSkeletonFileResource" path="res://assets/battle_visuals/{id}/{id}.spine-json" id="2"]

[resource]
atlas_res = ExtResource("1")
skeleton_file_res = ExtResource("2")
default_mix = 0.08
''',encoding='utf-8',newline='\n')
    (BASE/'grass_camp/source').mkdir(parents=True,exist_ok=True)
    for name,body in map_art().items():
        relative=f'grass_camp/source/{name}.svg'; (BASE/relative).write_text(svg(body,False),encoding='utf-8',newline='\n')
        entries.append(dict(svg=relative,png=f'grass_camp/{name}.png',pixels=160))
    (BASE/'render_manifest.json').write_text(json.dumps(dict(entries=entries),indent=2),encoding='utf-8')
    print('GENERATED',len(entries),'original SVG parts')

def pack():
    import_d69_heroes.generate()
    from PIL import Image
    for id,spec in ACTORS.items():
        if id in import_d69_heroes.MODELS: continue
        if id == 'liu_bei':
            import_liu_bei_158.generate()
            continue
        folder=BASE/id; names=list(parts(spec)); height=1
        regions=[]; x=y=row_height=0
        for name in names:
            part=Image.open(folder/'source'/f'{name}.png').convert('RGBA')
            if x+part.width>512: x=0; y+=row_height; row_height=0
            regions.append((name,part,x,y))
            x+=part.width; row_height=max(row_height,part.height)
        while height < y+row_height: height*=2
        atlas=Image.new('RGBA',(512,height))
        text=f'{id}.png\nsize: 512,{height}\nformat: RGBA8888\nfilter: Linear,Linear\nrepeat: none\n'
        for name,part,x,y in regions:
            atlas.alpha_composite(part,(x,y))
            text+=f'{name}\n  rotate: false\n  xy: {x}, {y}\n  size: {part.width}, {part.height}\n  orig: {part.width}, {part.height}\n  offset: 0, 0\n  index: -1\n'
        atlas.save(folder/f'{id}.png'); (folder/f'{id}.atlas').write_text(text,encoding='utf-8')
    data={'version':1,'license':'Original project enemy/map SVG parts and rigs; Guan Yu and original #158/#072/#312/#314 heroes use ART_ASSETS D69 terms.','actors':ACTORS,'files':{}}
    for path in BASE.rglob('*'):
        if path.is_file() and 'variants' not in path.relative_to(BASE).parts and (path.suffix in ['.svg','.png','.atlas','.spine-json','.tres'] or (any(part.startswith('d69_') for part in path.parts) and path.suffix != '.import')):
            data['files'][path.relative_to(BASE).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
    (BASE/'manifest.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
    print('PACKED',len(ACTORS),'actors')

if __name__=='__main__':
    pack() if '--pack' in sys.argv else generate()

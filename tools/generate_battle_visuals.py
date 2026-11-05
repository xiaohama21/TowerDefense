"""Original battle SVG parts and Spine 4.3 rigs. Rasterize with Godot, then --pack.

No external character images are copied. Coordinate art stays editable in source/.
"""
from pathlib import Path
import json, sys, hashlib

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/battle_visuals'
INK = '#302b28'
ACTORS = {
    'liu_bei': dict(scale=.34, foot=8, top=139, width=102, coat='#438864', trim='#daba66', skin='#eac59b', role='hero'),
    'yellow_turban_soldier': dict(scale=.28, foot=16, top=131, width=95, coat='#a5966b', trim='#dbb450', skin='#daba8e', role='soldier'),
    'yellow_turban_cavalry': dict(scale=.30, foot=20, top=167, width=160, coat='#8b7858', trim='#ddbb53', skin='#daba8e', role='cavalry'),
    'yellow_turban_sergeant': dict(scale=.33, foot=18, top=134, width=126, coat='#5b6265', trim='#dbc259', skin='#daba8e', role='sergeant'),
    'yellow_turban_general': dict(scale=.43, foot=24, top=137, width=144, coat='#68594c', trim='#dab44c', skin='#cead85', role='boss'),
}

def path(d, fill, stroke=INK, width=3):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'

def ellipse(x,y,rx,ry,fill,stroke=INK,width=3):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'

def svg(body, part=True):
    box='-64 -64 128 128' if part else '0 0 80 80'
    size=128 if part else 80
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="{box}">{body}</svg>'

def parts(spec):
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
    grass='<rect width="80" height="80" fill="#365a40"/>'
    grass+='<path d="M0 27 Q28 14 52 27 T80 28 V60 Q42 45 0 62 Z" fill="#436548" opacity=".35"/>'
    for x,y in [(9,12),(54,51),(24,62),(69,17),(40,29)]: grass+=path(f'M{x-2} {y+3} L{x} {y-2} L{x+2} {y+3}', '#557554','none',0)
    road='<rect width="80" height="80" fill="#aa906e"/>'
    road+='<path d="M0 20 Q30 17 80 21 M0 57 Q45 65 80 56" fill="none" stroke="#c9b58e" stroke-width="6" opacity=".28"/>'
    for x,y in [(18,14),(68,37),(27,65),(44,43)]: road+=ellipse(x,y,2,1,'#8f7a5c','none',0)
    tree=ellipse(40,70,26,6,'#1e3e2d','none',0)+path('M34 40 L44 40 L45 69 L33 69 Z','#705237')
    tree+=path('M40 6 Q58 6 60 22 Q77 26 67 45 Q72 59 54 59 L29 57 Q8 55 12 37 Q7 21 24 17 Q25 6 40 6 Z','#3c7849')
    tree+=path('M30 14 Q48 5 54 21 Q63 20 64 34 Q40 25 18 36 Q15 22 30 14 Z','#62945b',INK,2)
    tree+=path('M20 45 Q33 53 50 46 M43 19 L48 29','none','#2b5c3b',2)
    rock=ellipse(40,67,27,6,'#254432','none',0)+path('M13 60 L20 36 L39 23 L58 32 L69 59 L48 67 L27 66 Z','#808b7d')
    rock+=path('M20 36 L39 23 L43 42 L13 60 Z','#a3aa91',INK,2)
    rock+=path('M43 42 L58 32 L69 59 L48 67 Z','#67766d',INK,2)
    flag=ellipse(38,69,15,4,'#254432','none',0)+path('M33 9 L38 9 L38 68 L33 68 Z','#86623d')
    flag+=path('M38 13 L65 16 L60 30 L67 43 L38 40 Z','#b69347')
    flag+=path('M42 20 L58 21 L56 33 L42 32 Z','#e1ca7b',INK,1.5)
    torch=ellipse(40,69,15,4,'#254432','none',0)+path('M36 31 L43 31 L44 69 L34 69 Z','#785535')
    torch+=path('M40 9 Q56 22 46 36 Q38 45 29 33 Q23 24 35 17 L35 27 Z','#d68b3a')
    torch+=path('M41 20 Q49 30 39 35 Q32 31 35 26 Z','#f0d980',INK,1.5)
    gate=ellipse(40,67,35,7,'#29442f','none',0)+path('M12 15 L20 15 L21 68 L11 68 Z M58 15 L66 15 L67 68 L57 68 Z','#8d6740')
    gate+=path('M9 13 L68 13 L68 23 L9 23 Z','#b48e54')
    gate+=path('M18 27 L61 27 L61 54 L18 54 Z','#665841',INK,2)
    gate+=path('M37 28 L43 28 L43 55 L37 55 Z M19 35 L60 35','none','#baa36c',2.5)
    base=ellipse(40,70,36,7,'#29442f','none',0)+path('M10 31 L63 21 L70 61 L41 73 L11 61 Z','#bda77b')
    base+=path('M10 32 L40 43 L70 30 L63 21 L36 17 Z','#42694b')
    base+=path('M40 43 L70 30 L70 61 L41 73 Z','#877354')
    base+=path('M26 42 L36 45 L36 65 L25 62 Z','#51422f')
    base+=path('M9 34 L6 21 L18 14 L22 36 Z M57 27 L57 8 L69 11 L71 32 Z','#ab9667')
    base+=path('M5 22 L17 13 L25 22 Z M53 9 L65 3 L74 14 Z','#45674d')
    base+=path('M50 17 L50 5 L40 6 L43 12 L50 12','#dcc675',INK,2)
    return dict(grass=grass,road=road,tree=tree,rock=rock,banner=flag,torch=torch,gate=gate,base=base)

def generate():
    entries=[]
    for id,spec in ACTORS.items():
        folder=BASE/id; (folder/'source').mkdir(parents=True,exist_ok=True)
        for name,body in parts(spec).items():
            relative=f'{id}/source/{name}.svg'; (BASE/relative).write_text(svg(body),encoding='utf-8')
            entries.append(dict(svg=relative,png=f'{id}/source/{name}.png',pixels=128))
        (folder/f'{id}.spine-json').write_text(json.dumps(rig(spec),separators=(',',':')),encoding='utf-8')
        (folder/f'{id}-data.tres').write_text(f'''[gd_resource type="SpineSkeletonDataResource" load_steps=3 format=3]

[ext_resource type="SpineAtlasResource" path="res://assets/battle_visuals/{id}/{id}.atlas" id="1"]
[ext_resource type="SpineSkeletonFileResource" path="res://assets/battle_visuals/{id}/{id}.spine-json" id="2"]

[resource]
atlas_res = ExtResource("1")
skeleton_file_res = ExtResource("2")
default_mix = 0.08
''',encoding='utf-8')
    (BASE/'grass_camp/source').mkdir(parents=True,exist_ok=True)
    for name,body in map_art().items():
        relative=f'grass_camp/source/{name}.svg'; (BASE/relative).write_text(svg(body,False),encoding='utf-8')
        entries.append(dict(svg=relative,png=f'grass_camp/{name}.png',pixels=80))
    (BASE/'render_manifest.json').write_text(json.dumps(dict(entries=entries),indent=2),encoding='utf-8')
    print('GENERATED',len(entries),'original SVG parts')

def pack():
    from PIL import Image
    for id,spec in ACTORS.items():
        folder=BASE/id; names=list(parts(spec)); atlas=Image.new('RGBA',(512,256))
        text=f'{id}.png\nsize: 512,256\nformat: RGBA8888\nfilter: Linear,Linear\nrepeat: none\n'
        for index,name in enumerate(names):
            x=(index%4)*128; y=(index//4)*128
            atlas.alpha_composite(Image.open(folder/'source'/f'{name}.png').convert('RGBA'),(x,y))
            text+=f'{name}\n  rotate: false\n  xy: {x}, {y}\n  size: 128, 128\n  orig: 128, 128\n  offset: 0, 0\n  index: -1\n'
        atlas.save(folder/f'{id}.png'); (folder/f'{id}.atlas').write_text(text,encoding='utf-8')
    data={'version':1,'license':'Original project SVG parts and rigs; existing Guan Yu remains under ART_ASSETS D69 terms.','actors':ACTORS,'files':{}}
    for path in BASE.rglob('*'):
        if path.is_file() and path.suffix in ['.svg','.png','.atlas','.spine-json','.tres']:
            data['files'][path.relative_to(BASE).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
    (BASE/'manifest.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
    print('PACKED',len(ACTORS),'actors')

if __name__=='__main__':
    pack() if '--pack' in sys.argv else generate()

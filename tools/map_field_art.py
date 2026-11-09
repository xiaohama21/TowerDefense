"""Original modular field art, in 80-unit SVG canvases; no external image inputs."""
import random

INK = '#303d2c'

def path(d, color, stroke=INK, width=1.2, extra=''):
    return f'<path d="{d}" fill="{color}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round" {extra}/>'

def ellipse(x,y,rx,ry,color,extra=''):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{color}" {extra}/>'

def gradient(id,top,bottom):
    return f'<defs><linearGradient id="{id}" x1="0" y1="0" x2=".5" y2="1"><stop stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient></defs>'

def grass(seed):
    rng=random.Random(seed)
    parts=[]
    for _ in range(17):
        x,y=rng.uniform(5,75),rng.uniform(5,75)
        h=rng.uniform(2,5)
        c=rng.choice(['#9bab72','#2f4c35','#758d59'])
        parts.append(path(f'M{x-2:.1f} {y:.1f} q1 {-h:.1f} 0 {-h:.1f} M{x:.1f} {y:.1f} l2 {-h+1:.1f}', 'none',c,.75,'opacity=".32"'))
    for _ in range(6):
        x,y=rng.uniform(3,77),rng.uniform(3,77)
        parts.append(ellipse(round(x,1),round(y,1),1.4,.6,'#b1aa7b','opacity=".16"'))
    return ''.join(parts)

def tree(variant=0):
    s=gradient('leaf','#90a76a','#3d633f')+gradient('wood','#a28854','#635138')
    s+=ellipse(41,70,29,6,'#1c3727','opacity=".24"')+ellipse(38,69,18,3,'#152b20','opacity=".25"')
    s+=path('M35 34 Q39 49 32 69 L44 69 Q40 48 47 32 Z','url(#wood)')
    s+=path('M38 59 L24 45 M41 48 L53 39','none','#635338',3)
    s+=path('M38 57 L39 68 M34 69 L30 71 M43 68 L48 70','none','#b49b66',1)
    lobes=[(23,32,15,13),(52,35,18,14),(39,21,21,17),(25,19,12,11),(54,19,12,11),(38,39,20,14)]
    if variant: lobes=[(20,39,13,12),(54,36,17,13),(38,24,19,20),(49,15,12,11),(24,24,13,12),(39,43,18,13)]
    for x,y,rx,ry in lobes:
        s+=ellipse(x,y+2,rx+1,ry+1,'#304c34')+ellipse(x,y,rx,ry,'url(#leaf)')
        s+=path(f'M{x-rx*.6} {y-2} Q{x-rx*.2} {y-ry*.7} {x+rx*.5} {y-ry*.45}', 'none','#b0bb7d',1.5,'opacity=".42"')
    s+=path('M21 42 q6 4 12 1 M46 40 q10 3 16 -4 M30 21 q8 -5 14 0','none','#345a36',1.1,'opacity=".65"')
    for x,y in [(22,61),(48,67),(55,62)]: s+=path(f'M{x-3} {y+4} l2 -5 2 4 3 -6', 'none','#658b4d',1.5)
    return s

def stone(x,y,k=1):
    return f'<g transform="translate({x} {y}) scale({k})">'+ellipse(0,14,18,3,'#28382b','opacity=".25"')+path('M-18 8 L-13 -8 L0 -15 L13 -7 L19 10 L7 16 L-11 14 Z','#7e8874')+path('M-13 -8 L0 -15 L3 0 L-18 8 Z','#abb49a','none')+path('M3 0 L13 -7 L19 10 L7 16 Z','#667460','none')+path('M-11 -6 L-3 -9 M4 4 L9 9 M-9 10 L0 12','none','#c2c3a8',.8)+'</g>'

def map_art():
    art={('grass' if i==0 else 'grass_'+str(i)):grass(412+i) for i in range(4)}
    road=''
    rng=random.Random(926)
    for _ in range(26):
        x,y=rng.uniform(4,76),rng.uniform(4,76)
        road+=ellipse(round(x,1),round(y,1),rng.choice([.6,1,1.8]),.55,rng.choice(['#766549','#f1dbac']),'opacity=".28"')
    road+=path('M6 31 Q22 28 35 31 M45 53 Q62 49 74 51','none','#ebd1a0',1.3,'opacity=".25"')
    art['road']=road
    art['tree']=tree();art['tree_1']=tree(1)
    s=ellipse(40,69,28,6,'#2c2820','opacity=".4"')
    s+=path('M32 70 L37 49 L31 32 L22 24 L19 13 L23 11 L28 22 L37 25 L35 8 L41 6 L46 35 L57 24 L59 14 L63 14 L63 28 L47 44 L46 61 L53 70 Z','#514b37','#37372d',1.1)
    s+=path('M40 13 L41 39 L37 62 M46 42 L56 30','none','#91815b',1)
    s+=path('M31 70 L27 68 M51 72 L57 70 M21 62 L24 62','none','#aa7040',1.8)
    art['stump']=s
    art['rock']=stone(31,47,.95)+stone(55,57,.55)+path('M14 63 l2 -5 3 5 3 -4 M56 68 l1 -6 3 4','none','#759258',1.3)
    s=ellipse(40,54,36,19,'#776f4b','opacity=".45"')+ellipse(38,61,34,12,'#97a073','opacity=".3"')
    for x,y,k in [(22,30,.68),(51,34,.83),(35,49,1.1),(65,55,.57),(14,59,.52)]: s+=stone(x,y,k)
    for x,y in [(10,43),(57,17),(44,71),(70,67)]:s+=path(f'M{x-4} {y} l2 -5 2 4 2 -6 2 5','none','#789352',1.4)
    art['rock_cluster']=s
    s=ellipse(40,70,20,4,'#1c3727','opacity=".24"')+path('M33 9 L37 9 L38 69 L33 69 Z','#90754b')
    s+=path('M35 9 L35 4 L39 8 Z','#d4bd7b')
    s+=path('M37 13 Q50 9 64 17 L60 29 L66 44 Q50 36 37 41 Z','#ba9c55')
    s+=path('M41 17 Q51 15 60 19 L57 30 L61 38 Q49 33 41 36 Z','#dbc17a','#6d6240',.7)
    s+=path('M47 20 L53 22 L51 27 L56 30 L51 33 L46 29 L48 25 L44 23 Z','#877348','none')
    s+=path('M33 61 L27 71 M37 58 L46 72','none','#65523a',1.3)
    art['banner']=s
    s=ellipse(40,70,17,4,'#223726','opacity=".28"')+path('M36 31 L43 31 L42 67 L36 67 Z','#8b7047')
    s+=path('M30 30 L47 30 L45 39 L33 39 Z','#5c6153')+path('M30 31 L47 31 M33 36 L45 36','none','#c1b089',1.1)
    s+=path('M38 8 Q39 19 46 17 Q53 30 42 32 Q24 33 30 20 Q35 21 38 8 Z','#dca34e','#7e5c35',1)
    s+=path('M38 20 Q47 31 37 30 Q32 28 38 20 Z','#f5dfa0','none')
    s+=path('M28 70 L37 56 M48 70 L42 56','none','#6a583d',2)
    art['torch']=s
    s=ellipse(40,69,36,6,'#183023','opacity=".3"')
    for x in [7,16,59,68]:
        s+=path(f'M{x} 20 l3 -7 4 7 v46 h-7 Z','#988054')
        s+=path(f'M{x+2} 25 v35','none','#d1b578',.8)
    s+=path('M8 35 H23 V40 H8 Z M57 35 H75 V40 H57 Z','#695439')
    s+=path('M19 17 L25 17 L26 69 L18 69 Z M54 17 L61 17 L62 69 L54 69 Z','#9d8252')
    s+=path('M15 15 L64 15 L68 25 L13 25 Z','#ad915b')
    s+=path('M14 15 L24 7 L55 7 L67 15 Z','#627554')
    s+=path('M24 10 L56 10 M19 18 H63','none','#d0b57b',1.2)
    s+=path('M25 27 L35 28 L34 44 L29 40 L25 44 Z M47 28 L54 27 L54 44 L50 41 L47 45 Z','#c4a65c','#665b3c',.7)
    s+=path('M23 47 L23 64 M58 47 L58 64','none','#d2bc84',1)
    art['gate']=s
    s=gradient('roof','#79916c','#405d48')+gradient('wall','#ddc798','#a99367')+ellipse(41,72,37,6,'#183023','opacity=".32"')
    s+=path('M12 35 L42 24 L68 36 V62 L40 74 L12 62 Z','url(#wall)')
    s+=path('M40 45 L68 36 V62 L40 74 Z','#9c895f')
    s+=path('M7 34 L38 12 L74 31 L66 39 L39 29 L16 44 Z','url(#roof)')
    s+=path('M7 34 L16 39 L39 24 L68 35 L74 31','none','#a8b393',1.1)
    for d in ['M18 31 L40 17 L62 29','M24 29 L43 19','M31 26 L49 22','M40 29 L40 25','M47 31 L47 27','M56 34 L56 30']:
        s+=path(d,'none','#344f3d',.8)
    s+=path('M24 48 Q30 42 36 47 V68 L24 63 Z','#3c4230')
    s+=path('M26 50 V61 M31 48 V64','none','#aa9060',1.1)
    s+=path('M48 46 L58 42 V51 L48 55 Z','#4b523b')
    s+=path('M53 44 V53 M49 50 L57 46','none','#cfb980',1)
    s+=path('M14 48 L20 51 M13 57 L21 60 M60 58 L66 55','none','#8a7957',1)
    s+=path('M59 21 V2 M60 3 L74 5 L69 11 L60 10 Z','#c9a858','#645439',1)
    s+=stone(12,68,.22)+stone(66,69,.22)
    art['base']=s
    return art

if __name__ == '__main__':
    from pathlib import Path
    import json
    base=Path(__file__).resolve().parents[1]/'assets/battle_visuals'
    entries=[]
    for name,body in map_art().items():
        relative='grass_camp/source/'+name+'.svg'
        (base/relative).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 80 80">'+body+'</svg>\n',encoding='utf-8',newline='\n')
        entries.append({'svg':relative,'png':'grass_camp/'+name+'.png','pixels':160})
    (base/'map_render_manifest.json').write_text(json.dumps({'entries':entries},indent=2),encoding='utf-8',newline='\n')
    print('MAP_SOURCES',len(entries))

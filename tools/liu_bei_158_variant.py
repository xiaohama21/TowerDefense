"""D69 #158 derivative Liu Bei study. Original reference and license stay in source/.

Run once with --source pointing to the supplied 158 folder. Later runs use the
archived inputs, so the candidate can be rebuilt without the external art pack.
"""
from pathlib import Path
import argparse, colorsys, copy, json, math, shutil
from PIL import Image, ImageDraw
from import_liu_bei_158 import convert

ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/battle_visuals/liu_bei/variants/a_158'


def paint(img,name):
    out=img.convert('RGBA'); result=[]
    for r,g,b,a in out.getdata():
        h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
        hair=name.startswith('Hair') or (name=='Face' and max(r,g,b)-min(r,g,b)<38 and v>.28)
        if a and hair:
            r,g,b=[round(x+y*v) for x,y in [(12,62),(23,76),(23,64)]]
        elif a and name in ('Face','Lhand','Rhand','Larm','Rarm') and r>g*1.12 and r>b*1.2 and r>130 and g>60:
            r,g,b=round(r*.95),min(255,round(g*1.08)),round(b*.87)
        elif a and .47<h<.74 and s>.2:
            r,g,b=[round(c*255) for c in colorsys.hsv_to_rgb(.405,s*.72,v*.9)]
        elif a and name in ('Body','SleeveA','SleeveB','Lcloth','Rcloth','Bcloth') and s<.2 and v>.55:
            r,g,b=round(v*242),round(v*239),round(v*213)
        elif a and .035<h<.15 and s>.4:
            r,g,b=[round(c*255) for c in colorsys.hsv_to_rgb(.112,s*.77,v*.92)]
        result.append((r,g,b,a))
    out.putdata(result)
    if name=='Face':
        d=ImageDraw.Draw(out)
        d.polygon([(27,58),(30,56),(33,58),(36,57),(38,59),(33,60),(30,59)],fill='#40362b')
        d.polygon([(29,64),(34,65),(38,63),(36,69),(32,70),(30,68)],fill='#36382d')
    return out

def crown():
    img=Image.new('RGBA',(34,42));d=ImageDraw.Draw(img)
    d.polygon([(4,31),(6,19),(11,17),(10,5),(17,2),(23,6),(24,18),(29,23),(30,33),(20,38),(10,36)],fill='#806034',outline='#25322c',width=2)
    d.polygon([(13,7),(17,5),(21,8),(21,20),(17,24),(14,19)],fill='#c2a260',outline='#533e2e')
    d.polygon([(8,25),(13,23),(18,27),(24,22),(27,30),(20,35),(11,33)],fill='#d3b774',outline='#52452e')
    d.polygon([(14,26),(18,24),(22,29),(18,33),(14,30)],fill='#397a5b',outline='#243c32')
    d.line([(2,26),(7,26)],fill='#b99e66',width=2); d.line([(28,26),(33,26)],fill='#d7ba7b',width=2)
    return img

def remap_times(value, mapping):
    if isinstance(value,dict):
        if 'time' in value:value['time']=mapping(float(value['time']))
        curve=value.get('curve')
        if isinstance(curve,list):
            for i in range(0,len(curve),4):curve[i]=mapping(curve[i]);curve[i+2]=mapping(curve[i+2])
        for key,child in value.items():
            if key not in ('time','curve'):remap_times(child,mapping)
    elif isinstance(value,list):
        for child in value:remap_times(child,mapping)

def posed_idle(idle,duration,peaks):
    result={'bones':{},'transform':{}}
    for kind in ('bones','transform'):
        for target,channels in idle.get(kind,{}).items():
            if kind=='transform':
                first=copy.deepcopy(channels[0]);first.pop('curve',None);first['time']=0
                result[kind][target]=[first]
            else:
                result[kind][target]={}
                for channel,frames in channels.items():
                    first=copy.deepcopy(frames[0]);first.pop('curve',None);first['time']=0
                    result[kind][target][channel]=[first]
    for bone,offset in peaks.items():
        base=result['bones'].get(bone,{}).get('rotate',[{}])[0].get('value',0)
        result['bones'].setdefault(bone,{})['rotate']=[{'value':base},{'time':duration*.32,'value':base+offset},{'time':duration*.65,'value':base+offset},{'time':duration,'value':base}]
    return result

def variant_rig(source):
    d=convert(source);skin=d['skins'][0]['attachments']
    # Keep existing bone indices intact: weighted vertices reference them.
    d['bones'] += [{'name':'LiuOffhand','parent':'Rhand','x':32,'y':-1,'rotation':-39},
                   {'name':'LiuCrown','parent':'Face','x':69,'y':-1,'rotation':-90}]
    d['slots'] += [{'name':'LiuOffhand','bone':'LiuOffhand','attachment':'Offhand'},
                   {'name':'LiuCrown','bone':'LiuCrown','attachment':'Crown'}]
    sword=copy.deepcopy(skin['WeaponA']['WeaponA']);sword['name']='Liu/Offhand';sword['width']*=.92
    skin['LiuOffhand']={'Offhand':sword}
    skin['LiuCrown']={'Crown':{'name':'Liu/Crown','width':34,'height':42}}
    for slot in d['slots']:
        if slot['name'] in ['HairA','HairB','HairC','AccA']:slot.pop('attachment',None)
    animations=d['animations']
    # Both jian are drawn in Liu Bei's guard; the reference's stored-sword pose
    # and wine flask belong to Li Bai rather than this candidate's identity.
    idle=animations['Idle']
    idle['bones']['Larm']['rotate']=[{'value':-40.75}]
    idle['bones']['Lhand']['rotate']=[{'value':-32.26}]
    hand_constraint={'mixRotate':1,'mixX':1,'mixY':1,'mixScaleX':0,'mixScaleY':0,'mixShearY':0}
    stored_constraint={'mixRotate':0,'mixX':0,'mixY':0,'mixScaleX':0,'mixScaleY':0,'mixShearY':0}
    idle['transform']['Weapon_Con1']=[hand_constraint]
    idle['transform']['Weapon_Con2']=[stored_constraint]
    for name,hit,total,new_total in [('Attack_A',.5333,.8667,.33),('Critical',.3,1.3667,.44)]:
        mapping=lambda t,h=hit,end=total,n=new_total: t/h*.11 if t<=h else .11+(t-h)/(end-h)*(n-.11)
        remap_times(animations[name],mapping)
        animations[name]['events']=[{'time':.11,'name':'Effect'}]
        for bone in ['Larm','Lhand']:
            frames=animations[name].get('bones',{}).get(bone,{}).get('rotate',[])
            if frames and frames[0].get('time',0)==0: frames[0]['value']=idle['bones'][bone]['rotate'][0]['value'];frames[0].pop('curve',None)
        # A tower's visual may lean and hop, but does not leave its build cell.
        for frame in animations[name].get('bones',{}).get('All',{}).get('translate',[]):
            frame['x']=max(-24,min(24,frame.get('x',0)));frame['y']=max(-8,min(18,frame.get('y',0)));frame.pop('curve',None)
    animations['Active_A']=posed_idle(animations['Idle'],.4,{'Rarm':45,'Rhand':15,'LiuOffhand':70})
    animations['XX']=posed_idle(animations['Idle'],.55,{'Larm':-59.25,'Lhand':92.26,'Rarm':90,'Rhand':50,'LiuOffhand':129})
    animations['XX']['transform']['Weapon_Con1']=[{'mixRotate':1,'mixX':1,'mixY':1,'mixScaleX':0,'mixScaleY':0,'mixShearY':0}]
    animations['XX']['transform']['Weapon_Con2']=[{'mixRotate':0,'mixX':0,'mixY':0,'mixScaleX':0,'mixScaleY':0,'mixShearY':0}]
    animations['XX']['events']=[{'time':0,'name':'Effect'}]
    d['skeleton']['images']='./source/painted/'
    return d

def run():
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path);args=parser.parse_args()
    raw=DEST/'source/d69_158';raw.mkdir(parents=True,exist_ok=True)
    if args.source:
        shutil.copy2(args.source/'Hero_LiBai_A.json',raw/'original.json')
        shutil.copytree(args.source/'0/A',raw/'parts',dirs_exist_ok=True)
        for license in args.source.glob('*.txt'):shutil.copy2(license,raw/license.name)
    original=json.loads((raw/'original.json').read_text(encoding='utf-8-sig'))
    painted=DEST/'source/painted';painted.mkdir(exist_ok=True)
    regions={}
    for file in sorted((raw/'parts').glob('*.png')):
        img=paint(Image.open(file),file.stem);regions['A/'+file.stem]=img
        img.save(painted/file.name)
    regions['Liu/Offhand']=regions['A/WeaponA'].copy();regions['Liu/Crown']=crown()
    placements=[];x=y=row=0
    for name,img in regions.items():
        if x+img.width+4>512:x=0;y+=row;row=0
        placements.append((name,img,x+2,y+2));x+=img.width+4;row=max(row,img.height+4)
    height=2**math.ceil(math.log2(y+row));atlas=Image.new('RGBA',(512,height))
    lines=f'liu_bei_158.png\nsize: 512,{height}\nformat: RGBA8888\nfilter: Linear,Linear\nrepeat: none\n'
    for name,img,x,y in placements:
        atlas.alpha_composite(img,(x,y))
        lines+=f'{name}\n  rotate: false\n  xy: {x}, {y}\n  size: {img.width}, {img.height}\n  orig: {img.width}, {img.height}\n  offset: 0, 0\n  index: -1\n'
    atlas.save(DEST/'liu_bei_158.png');(DEST/'liu_bei_158.atlas').write_text(lines,encoding='utf-8')
    rig=variant_rig(original);(DEST/'liu_bei_158.spine-json').write_text(json.dumps(rig,separators=(',',':')),encoding='utf-8')
    relative=DEST.relative_to(ROOT).as_posix()
    (DEST/'liu_bei_158-data.tres').write_text(f'[gd_resource type="SpineSkeletonDataResource" load_steps=3 format=3]\n[ext_resource type="SpineAtlasResource" path="res://{relative}/liu_bei_158.atlas" id="1"]\n[ext_resource type="SpineSkeletonFileResource" path="res://{relative}/liu_bei_158.spine-json" id="2"]\n[resource]\natlas_res=ExtResource("1")\nskeleton_file_res=ExtResource("2")\ndefault_mix=0.08\n',encoding='utf-8',newline='\n')
    (DEST/'README.md').write_text('# 刘备 A：Spine158底模改造试作\n\n用户指定D69序号158/Hero_LiBai_A参考，原骨架/网格/动作和部件衍生改造；黑发束冠、绿白甲袍、第二把剑与支援动作。不是全原创资产。沿ART_ASSETS §6开发用途许可；原声明位于source/d69_158/。\n\n重建：python tools/liu_bei_158_variant.py；source为必要输入，发行包排除。\n',encoding='utf-8',newline='\n')
    print('LIU_158_VARIANT',len(rig['bones']),'bones',len(regions),'regions')

if __name__=='__main__':run()

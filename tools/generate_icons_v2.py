"""Original icon masters. Render with Godot; preserve every legacy asset (ICONS v1.0)."""
from pathlib import Path
import argparse
import hashlib
import html
import json
import math
import os
import re
import subprocess
import shutil
import tempfile
import time
from skill_icon_art_v2 import build_skill_art, create_skill_previews
from talent_icon_art import build_talent_art, create_talent_previews

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/ui/icons/v2'
INK = '#243b36'
GOLD = '#efc765'
JADE = '#69cba6'
BLUE = '#8ac9e7'
RED = '#ee806c'
VIOLET = '#b996e3'
CREAM = '#fff0c6'
WOOD = '#cf9e6e'
ICONS = []

def write_generated_text(target, text):
    # Atomic replacement also works while desktop previews have the old file open.
    for attempt in range(3):
        temporary=None
        try:
            with tempfile.NamedTemporaryFile('w',encoding='utf-8',newline='\n',dir=target.parent,suffix='.tmp',delete=False) as stream:
                temporary=Path(stream.name)
                stream.write(text)
            temporary.replace(target)
            return
        except OSError:
            if attempt==2: raise
            time.sleep(.2)
        finally:
            if temporary is not None and temporary.exists(): temporary.unlink()

def write_generated_image(image, target, **options):
    for attempt in range(3):
        temporary=None
        try:
            with tempfile.NamedTemporaryFile('wb',dir=target.parent,suffix='.tmp',delete=False) as stream:
                temporary=Path(stream.name)
            image.save(temporary,format=target.suffix.removeprefix('.').upper(),**options)
            temporary.replace(target)
            return
        except OSError:
            if attempt==2: raise
            time.sleep(.2)
        finally:
            if temporary is not None and temporary.exists(): temporary.unlink()

def path(d, fill=GOLD, stroke=INK, width=5):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'

def circle(x, y, r, fill=GOLD, stroke=INK, width=5):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'

def rect(x,y,w,h,fill=GOLD,rx=5,stroke=INK,width=5):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'

def group(shape, transform):
    return f'<g transform="{transform}">{shape}</g>'

def star(x=48,y=48,r=31,fill=GOLD,points=5):
    coords=[]
    for i in range(points*2):
        a=-math.pi/2+i*math.pi/points
        s=r if i%2==0 else r*.46
        coords.append(f'{x+math.cos(a)*s:.2f},{y+math.sin(a)*s:.2f}')
    return path('M'+' L'.join(coords)+' Z',fill)

def heart(fill=RED):
    return path('M48 77 C39 69 16 54 16 36 C16 18 38 14 48 29 C58 14 80 18 80 36 C80 54 57 69 48 77 Z',fill)+path('M27 35 Q28 28 35 29','none',CREAM,4)

def sword(fill=BLUE):
    return path('M27 66 L64 18 L77 17 L78 30 L40 73 Z',fill)+path('M24 57 L47 76','none',GOLD,9)+path('M32 68 L18 83','none',WOOD,8)+path('M44 55 L66 29','none',CREAM,3)

def spear(fill=BLUE):
    return path('M31 82 L65 24','none',WOOD,7)+path('M61 42 L54 30 L71 12 L77 36 Z',fill)+path('M56 46 Q43 43 43 56 L59 54 Z',RED)

def bow(fill=WOOD):
    return path('M25 15 Q86 47 25 81 Q63 48 25 15 Z',fill)+path('M25 15 L44 48 L25 81','none',CREAM,3)+path('M16 48 H81 M69 37 L83 48 L69 59','none',BLUE,6)

def fan(fill=JADE):
    return path('M44 74 L14 36 Q11 21 25 21 L42 59 L33 19 Q37 8 48 17 L49 57 L57 19 Q68 9 72 22 L58 63 L74 29 Q89 23 86 39 L54 76 Z',fill)+path('M45 74 L54 84','none',WOOD,9)+path('M29 35 L45 63 M48 28 V63 M69 34 L54 64','none',CREAM,3)

def flame(fill=RED):
    return path('M47 12 C60 33 70 24 71 39 C92 60 75 84 49 84 C22 84 12 63 26 46 C32 40 35 31 32 25 C43 28 45 35 47 12 Z',fill)+path('M49 48 C66 60 61 73 49 75 C38 75 36 63 49 48 Z',GOLD,INK,3)

def bolt(fill=GOLD):
    return path('M54 12 L23 51 H44 L35 84 L76 39 H55 Z',fill)

def shield(fill=BLUE,broken=False):
    shape=path('M20 25 L48 14 L76 25 V50 Q74 70 48 84 Q22 70 20 50 Z',fill)
    return shape+(path('M49 19 L40 38 L55 46 L41 59 L49 79','none',RED,7) if broken else path('M48 25 V66 M34 39 H62','none',CREAM,4))

def armor(fill=BLUE,broken=False):
    shape=path('M30 15 L18 29 L25 42 L28 78 Q48 87 68 78 L71 42 L78 29 L66 15 L58 25 H38 Z',fill)
    return shape+(path('M52 28 L43 45 L58 54 L47 80','none',RED,7) if broken else path('M37 43 H59 M35 57 H61 M35 71 H61','none',CREAM,4))

def eye(fill=JADE):
    return path('M12 48 Q48 12 84 48 Q48 84 12 48 Z',fill)+circle(48,48,13,CREAM)+circle(48,48,5,INK,INK,0)

def scroll(fill=CREAM):
    return path('M25 18 H70 V74 H32 Q18 74 18 63 V30 Q18 18 25 18 Z',fill)+path('M27 19 V64 Q27 73 35 73 H72 Q80 73 80 81 H35 Q22 81 22 68','none',WOOD,6)+path('M40 36 H58 M40 47 H62 M40 58 H52','none',INK,4)

def book(fill=VIOLET):
    return path('M17 22 Q32 13 48 25 Q64 13 79 22 V77 Q64 70 48 80 Q32 70 17 77 Z',fill)+path('M48 25 V79 M28 34 L37 32 M60 34 L68 32','none',CREAM,4)

def drum(fill=RED):
    return rect(24,29,49,40,fill,8)+path('M24 37 H73 M24 61 H73','none',GOLD,7)+path('M32 39 L42 61 L54 39 L64 61','none',CREAM,3)+path('M16 15 L49 34 M80 15 L53 32','none',WOOD,7)+path('M27 73 L20 82 M68 73 L77 82','none',WOOD,6)

def flag(fill=RED):
    return path('M26 14 V83','none',WOOD,7)+path('M29 20 Q54 10 76 22 L65 37 L78 51 Q55 40 29 50 Z',fill)+circle(26,13,4,GOLD,INK,3)

def faction_flag(fill):
    # Faction names are rendered as always-visible UI labels beside the flags.
    return (path('M21 16 V84','none',WOOD,7)
            +path('M25 20 Q49 13 77 23 L71 42 L79 61 Q50 53 25 62 Z',fill)
            +path('M31 26 Q48 22 65 27 M31 54 Q48 50 65 54','none',CREAM,3)
            +path('M66 28 Q60 40 66 50','none',INK,2)
            +circle(21,13,5,GOLD,INK,3))

def coin(fill=GOLD):
    return circle(48,48,32,fill)+rect(38,38,20,20,'none',2)+path('M27 34 Q30 24 40 23','none',CREAM,4)+path('M57 72 Q65 69 69 62','none',INK,3)

def gate(fill=BLUE):
    return path('M18 33 V19 H31 V30 H41 V18 H55 V30 H65 V19 H78 V33 L73 40 V82 H23 V40 Z',fill)+path('M38 81 V59 Q48 42 58 59 V81 Z',WOOD)+path('M31 47 H34 M62 47 H65','none',CREAM,4)

def fist(fill=WOOD):
    return path('M25 74 L20 51 Q13 33 24 32 L33 39 V23 Q35 14 42 22 L46 36 V19 Q52 12 56 22 L58 37 V25 Q65 19 69 30 L70 43 Q83 42 82 54 L73 75 Z',fill)+path('M35 49 Q47 44 61 52 M33 63 H67','none',CREAM,4)

def reticle(fill=RED):
    return circle(48,48,24,'none',fill,7)+path('M48 13 V28 M48 68 V83 M13 48 H28 M68 48 H83','none',fill,6)+circle(48,48,6,GOLD,INK,3)

def feather(fill=JADE):
    return path('M23 80 Q29 40 67 15 Q89 42 56 63 L40 65 Z',fill)+path('M26 78 L64 28 M43 58 L44 40 M52 49 L66 48','none',CREAM,4)

def moon(fill=CREAM):
    return path('M65 15 A35 35 0 1 0 80 63 Q46 76 37 43 Q33 20 65 15 Z',fill)+star(69,30,12,GOLD,4)

def horse(fill=CREAM):
    return path('M26 82 L29 54 L18 47 L25 34 L44 30 L41 15 L55 24 L65 18 L65 33 Q84 44 74 65 L65 82 Z',fill)+path('M55 30 Q60 54 44 64','none',WOOD,7)+circle(55,39,3,INK,INK,1)+path('M27 43 L40 47','none',INK,4)

def catapult(fill=WOOD):
    return path('M20 75 H78 M31 73 L45 39 L66 73 M47 43 L74 20','none',fill,8)+circle(25,78,7,GOLD)+circle(73,78,7,GOLD)+path('M64 14 L82 19 L77 29 L62 24 Z',fill)+circle(74,17,6,BLUE,INK,3)

def tiger(fill=GOLD):
    return path('M22 23 L35 26 Q48 15 61 26 L75 23 L73 41 Q83 63 67 78 Q48 88 28 77 Q12 62 23 41 Z',fill)+path('M34 37 L39 47 M62 37 L57 47 M48 25 V40','none',INK,5)+path('M34 58 Q48 47 62 58 L58 72 H38 Z',CREAM)+path('M44 61 H52 L48 66 Z',INK)+path('M48 66 V72','none',INK,3)

def leaf(fill=JADE):
    return path('M20 75 Q11 27 75 18 Q84 79 20 75 Z',fill)+path('M23 74 L65 31 M41 56 V38 M43 54 H62','none',CREAM,4)

def ingot(fill=GOLD):
    return path('M13 38 Q28 50 37 27 Q48 15 59 27 Q68 50 83 38 L72 67 Q48 83 24 67 Z',fill)+path('M30 58 Q48 66 66 58','none',CREAM,5)

def gold_ingot():
    return (path('M14 34 Q27 50 37 31 Q48 20 59 31 Q69 50 82 34 L72 67 Q48 81 24 67 Z', GOLD)
            + path('M17 43 Q48 67 79 43 L72 67 Q48 81 24 67 Z', '#d3a344')
            + path('M31 43 Q48 54 65 43 Q62 31 48 28 Q34 31 31 43 Z', '#f6d77d', INK, 4)
            + path('M37 39 Q47 31 57 39 M32 66 Q48 73 64 66', 'none', CREAM, 3))

def lord_crown():
    return (path('M17 29 L32 43 L48 15 L64 43 L79 29 L72 62 H24 Z', GOLD)
            + path('M30 52 H66', 'none', CREAM, 4)
            + rect(31, 62, 34, 21, JADE, 4, INK, 4)
            + path('M42 72 H54', 'none', CREAM, 4))

def lord_experience():
    return (circle(48, 48, 36, 'none', INK, 9)
            + path('M48 12 A36 36 0 1 0 83 56', 'none', JADE, 5)
            + group(lord_crown(), 'translate(20 19) scale(.58)')
            + circle(81, 34, 6, GOLD, INK, 3))

def equipment_quality(tier, fill):
    # Metal lozenge and rivets distinguish gear quality from six-sided character rank.
    positions = [[(48,48)], [(36,48),(60,48)], [(48,34),(36,57),(60,57)],
                 [(37,37),(59,37),(37,59),(59,59)],
                 [(37,37),(59,37),(48,48),(37,59),(59,59)]][tier]
    return (path('M48 12 L82 48 L48 84 L14 48 Z', fill)
            + path('M23 48 L48 23 L73 48 M23 48 L48 73 L73 48', 'none', CREAM, 3)
            + ''.join(path(f'M{x} {y-5} L{x+5} {y} L{x} {y+5} L{x-5} {y} Z',
                           CREAM, INK, 2.5) for x,y in positions))

def pouch(fill=WOOD):
    return path('M33 16 Q48 22 63 16 L59 33 Q83 51 74 76 Q49 87 22 76 Q12 51 37 33 Z',fill)+path('M33 33 H63 M39 53 L49 69 L59 51','none',CREAM,5)

def stone(fill=BLUE):
    return path('M19 69 L15 48 L36 24 L69 28 L82 54 L70 76 L38 82 Z',fill)+path('M36 24 L42 51 L70 76 M42 51 L82 54','none',CREAM,4)

def lotus(fill=RED):
    return path('M48 82 Q22 71 15 42 Q36 39 48 59 Q41 28 48 14 Q62 28 55 59 Q71 37 83 42 Q77 72 48 82 Z',fill)+path('M29 65 Q48 84 70 65','none',GOLD,5)

def bell(fill=GOLD):
    return path('M22 65 Q32 51 32 33 Q32 20 48 20 Q64 20 64 33 Q64 51 74 65 Z',fill)+circle(48,74,7,fill)+path('M44 16 V12 M41 31 Q40 39 40 43','none',CREAM,4)

def add(key,label,category,shape,description='',planned=False):
    assert key not in {i['id'] for i in ICONS},key
    ICONS.append(dict(id=key,label=label,category=category,description=description or label,planned=planned,svg_body=shape))

def catalogue():
    hud=[
      ('coin','金币',coin()),('merit','军功',star(48,41,24)+path('M30 60 L26 85 L48 74 L70 85 L66 60',RED)),
      ('base_hp','基地生命',gate()+group(heart(), 'translate(30 38) scale(.38)')),
      ('wave_flag','波次',flag()+path('M18 79 Q28 71 39 79 T62 79 T83 79','none',BLUE,5)),
      ('dmg_physical','物理伤害',sword()),('dmg_magic','魔法伤害',star(fill=VIOLET,points=4)+circle(48,48,10,CREAM)),
      ('dmg_true','真实伤害',path('M48 13 L58 38 L83 48 L58 58 L48 83 L38 58 L13 48 L38 38 Z',CREAM)+circle(48,48,8,GOLD)),
      ('stat_attack','攻击力',group(sword(),'translate(-5 0)')+group(bolt(),'translate(44 40) scale(.45)')),
      ('stat_attack_speed','攻击速度',group(sword(),'translate(20 0) scale(.8)')+path('M12 30 H34 M12 44 H29 M12 58 H24','none',GOLD,6)),
      ('stat_range','射程',reticle(BLUE)),('stat_armor','护甲',armor()),('stat_armor_pen','穿甲',armor(broken=True)),
      ('stat_exp','经验',book(GOLD)+star(48,47,16,CREAM,4)),('stat_tenacity','韧性',fist()),
      ('stat_move_speed','移动速度',path('M34 17 H56 L59 53 L79 65 L80 77 H23 V58 H35 Z',JADE)+path('M12 29 H25 M11 42 H25','none',GOLD,5)),
      ('stat_hp','生命',heart()),('stat_crit_rate','暴击率',reticle(RED)+path('M41 48 L46 53 L56 40','none',CREAM,4)),
      ('stat_crit_damage','暴击伤害',star(fill=RED,points=7)+group(bolt(),'translate(23 20) scale(.55)')),
      ('stat_skill_amp','技能增幅',fan(VIOLET)+group(star(fill=GOLD,points=4),'translate(52 48) scale(.4)')),
      ('rage','怒气',flame(GOLD)),('uses','使用次数',circle(48,48,30,'none',BLUE)+circle(31,48,5,GOLD)+circle(48,48,5,GOLD)+circle(65,48,5,GOLD)),
      ('lock','锁定',path('M31 39 V28 Q31 12 48 12 Q65 12 65 28 V39','none',BLUE,7)+rect(21,38,54,43,GOLD,8)+circle(48,55,5,INK,INK,0)+path('M48 59 V67','none',INK,5)),
      ('cooldown','冷却',path('M25 14 H71 M25 82 H71 M31 16 Q28 34 46 48 Q28 63 31 80 M65 16 Q68 34 50 48 Q68 63 65 80','none',WOOD,5)+path('M34 28 H62 L48 44 Z',BLUE)+path('M35 73 L48 59 L61 73 Z',GOLD)),
      ('stat_splash','溅射范围',circle(48,48,31,'none',RED,4)+star(48,48,20,GOLD,7)),
      ('stat_projectile_speed','弹道速度',path('M27 23 L82 48 L27 73 L38 48 Z',BLUE)+path('M12 31 H23 M10 48 H23 M12 65 H23','none',GOLD,5)),
      ('stat_heal','治疗',heart(JADE)+path('M48 36 V60 M36 48 H60','none',CREAM,6)),
      ('stat_lifesteal','吸血',path('M48 13 C58 33 75 46 75 61 A27 27 0 0 1 21 61 C21 46 38 33 48 13 Z',RED)+path('M48 45 V68 M37 57 H59','none',CREAM,5)),
      ('stat_rage_gain','怒气获取',group(flame(GOLD),'translate(6 8) scale(.8)')+path('M74 53 V80 M64 70 L74 80 L84 70','none',JADE,5)),
      ('tech_point','科技点',book(BLUE)+group(bolt(),'translate(22 23) scale(.55)')),
      ('talent_point','天赋点',leaf()+star(55,42,13,GOLD,4)),('yuanbao','元宝',ingot()),('player_level','主公等级',path('M16 32 L30 46 L48 19 L66 46 L80 32 L74 72 H22 Z',GOLD)+path('M29 61 H66','none',CREAM,4)),
    ]
    for k,l,s in hud:add(k,l,'hud',s)
    add('ingot', '元宝', 'hud', gold_ingot(), '暖金舟形元宝；商店余额/价格/刷新与经济奖励')
    add('lord_level', '主公等级', 'hud', lord_crown(), '暖金冠与青玉方印；仅解锁商店货档')
    add('lord_exp', '主公经验', 'hud', lord_experience(), '进度环与冠印；区别武将经验书册')
    for tier, (label, color) in enumerate(zip(['凡品','良品','珍品','绝品','神品'],
                                            ['#c8d5dc', JADE, BLUE, VIOLET, GOLD])):
        add('equipment_rarity_'+str(tier), label, 'equipment_rarity', equipment_quality(tier,color),
            '独立装备菱形品质徽记；'+str(tier+1)+'枚铆钉；与武将六阶分开', planned=tier>0)
    statuses=[
      ('slow','减速',path('M20 44 Q23 21 50 24 Q74 24 78 47 H20 Z',BLUE)+path('M24 51 H74 M30 51 V68 M61 51 V68','none',WOOD,6)+circle(79,58,6,BLUE)),
      ('burn','灼烧',flame()),('vulnerable','易伤',shield(VIOLET,True)),
      ('stun','眩晕',star(48,43,26,GOLD)+path('M17 73 Q48 87 80 73','none',BLUE,5)),
      ('fear','恐惧',path('M25 73 V42 Q25 16 48 16 Q71 16 71 42 V80 L59 72 L48 80 L36 72 Z',VIOLET)+circle(39,44,4,INK,INK,0)+circle(57,44,4,INK,INK,0)+circle(48,62,5,INK,INK,0)),
      ('knockback','击退',path('M76 18 L52 48 L76 78 M48 18 L24 48 L48 78','none',WOOD,10)),
      ('poison','中毒',path('M38 16 H58 V37 L75 68 Q78 81 66 81 H30 Q18 81 21 68 L38 37 Z',JADE)+path('M29 62 H67','none',CREAM,4)+circle(44,69,3,CREAM,CREAM,0)+circle(58,69,3,CREAM,CREAM,0)),
      ('stealth','隐匿',eye(VIOLET)+path('M18 79 L78 17','none',INK,8)),('reveal','破隐',eye()+path('M24 15 L28 24 M72 15 L68 24 M48 9 V19','none',GOLD,4)),
      ('armor_aura','护甲光环',group(armor(),'translate(13 13) scale(.72)')+path('M13 66 A38 38 0 0 0 83 66','none',GOLD,5)),
      ('shield','护盾',shield(JADE)),('silence','沉默',bell(BLUE)+path('M17 79 L79 17','none',RED,7)),
    ]
    for k,l,s in statuses:add('status_'+k,l,'status',s,planned=k in ['poison','silence'])
    colors=['#c8d5dc',JADE,VIOLET,GOLD,'#ed9e54',RED]
    for r,(key,c) in enumerate(zip(['white','green','purple','yellow','orange','red'],colors)):
        marks=''.join(circle(33+i*12,53,3,CREAM,INK,1.5) for i in range(1+(r%3)))
        add('rank_'+key,['白阶','绿阶','紫阶','黄阶','橙阶','红阶'][r],'rank',path('M48 12 L76 29 V61 L48 84 L20 61 V29 Z',c)+path('M33 40 L48 29 L63 40','none',CREAM,4)+marks+(path('M33 68 H63','none',CREAM,4) if r>=3 else ''))
    for r in range(1,10):
        tiers=''.join(path(f'M31 {32+i*11} L48 {23+i*11} L65 {32+i*11}','none',CREAM,4) for i in range(1+(r-1)%3))
        dots=''.join(circle(39+i*9,70,2.8,CREAM,INK,1) for i in range(1+(r-1)//3))
        add('battle_rank_'+str(r),'战斗阶 '+str(r),'battle_rank',shield(colors[min(5,1+(r-1)//2)]) .split('<path')[0]+path('M20 25 L48 14 L76 25 V50 Q74 70 48 84 Q22 70 20 50 Z',colors[min(5,1+(r-1)//2)])+tiers+dots)
    objects=[
      ('general_seal','将印',path('M29 37 V25 Q48 11 67 25 V37 Z',JADE)+rect(20,36,56,26,GOLD,4)+path('M15 69 H81 V82 H15 Z',RED)+path('M31 48 H65','none',CREAM,4)),
      ('refined_iron','精铁',path('M16 61 L27 30 H68 L82 61 L69 79 H27 Z',BLUE)+path('M27 30 L35 62 H68 L68 30 M16 61 L35 62','none',CREAM,4)),
      ('ebony','乌木',path('M22 34 L64 19 L81 32 L76 68 L35 82 L20 66 Z',WOOD)+path('M35 82 V49 L81 32 M20 35 L35 49 M38 38 L65 27','none',CREAM,4)+path('M47 55 V69 M60 50 V64','none',INK,4)),
      ('skill_book','技能升级书',book(JADE)+group(bolt(),'translate(25 26) scale(.49)')),
      ('gacha_token','求贤令',scroll(GOLD)+group(star(),'translate(33 27) scale(.34)')),
      ('wolf_tooth','狼牙符',path('M35 16 Q62 16 64 43 Q65 62 39 82 Q43 58 31 45 Z',CREAM)+path('M29 23 Q47 32 66 22','none',RED,6)),
      ('iron_shield','铁盾徽记',shield(BLUE)+star(48,46,13,GOLD,4)),
      ('war_drums','战鼓',drum()),('scout_eye','鹰眼符',eye(GOLD)+path('M19 20 L36 34 M77 20 L60 34','none',WOOD,6)),
      ('provision_bag','军粮袋',pouch()+path('M46 47 V69 M37 51 L46 57 L56 49','none',JADE,5)),
      ('relic_guanyu_blade','青龙偃月断刃',sword(JADE)+path('M55 30 L66 37 L62 47','none',RED,5)),
      ('relic_huangfusong_torch','火攻图卷',scroll(WOOD)+group(flame(),'translate(42 40) scale(.45)')),
      ('relic_zhangfei_spear','蛇矛精锻',spear()+path('M62 32 Q79 50 69 57','none',GOLD,5)),
      ('relic_tiangong_leizhao','天公雷诏',scroll(VIOLET)+group(bolt(),'translate(25 19) scale(.6)')),
      ('relic_taiping_yaoshu','太平要术·残卷',scroll(JADE)+path('M50 32 L61 45 L46 60','none',GOLD,6)),
    ]
    for k,l,s in objects:add(k,l,'item',s)
    supply=[('repair','修整',gate(JADE)+path('M65 55 V77 M54 66 H77','none',CREAM,7)),
      ('fire_attack','火攻',path('M28 79 L24 48 Q23 39 34 32 V20 H62 V32 Q73 39 72 48 L67 79 Z',WOOD)+group(flame(),'translate(27 32) scale(.5)')),
      ('war_drum','擂鼓',drum(GOLD)+path('M10 49 V62 M85 49 V62','none',RED,4)),
      ('slow_down','缓兵',flag(BLUE)+path('M43 31 L54 40 L66 30','none',CREAM,4)),
      ('stone_volley','掷石齐射',group(stone(),'translate(2 31) scale(.65)')+group(stone(),'translate(42 4) scale(.52)')+path('M18 17 L26 28 M38 10 L44 21 M74 72 L82 82','none',GOLD,5)),
      ('reward_army','犒军',pouch(JADE)+group(flame(GOLD),'translate(35 40) scale(.4)'))]
    for k,l,s in supply:add('supply_'+k,l,'supply',s)
    profession=[('cavalry','骑兵',horse()),('tiger_guard','虎贲',tiger()),('archer','弓箭手',bow()),('strategist','术士',fan()),('dancer','舞娘',lotus()),('catapult','投石车',catapult())]
    for k,l,s in profession:add('profession_'+k,l,'profession',s)
    skills=[
      ('ultimate_cavalry_breaker','突击斩杀',spear(GOLD)+path('M16 25 L29 32 M13 39 L24 44','none',RED,5)),
      ('ultimate_tiger_guard_sweep','破阵横扫',group(sword(),'translate(4 16) scale(.85)')+path('M14 27 Q48 4 82 27 M14 72 Q48 90 82 72','none',RED,6)),
      ('ultimate_archer_volley','箭雨',group(bow(),'translate(0 13) scale(.8)')+path('M49 15 L81 32 M52 29 L83 46','none',BLUE,5)),
      ('ultimate_strategist_blaze','天火奇谋',fan(VIOLET)+group(flame(),'translate(46 45) scale(.4)')),
      ('ultimate_dancer_encourage','凤仪鼓舞',lotus()+group(star(fill=GOLD),'translate(47 10) scale(.38)')),
      ('ultimate_catapult_barrage','连环轰击',catapult()+path('M14 20 L27 23 M18 38 L31 39','none',RED,5)),
      ('char_green_dragon','青龙偃月',sword(JADE)+path('M18 33 Q30 14 49 16 M17 45 Q25 29 35 26','none',GOLD,6)),
      ('char_dangyang_roar','当阳怒吼',tiger(RED)+path('M9 45 V59 M87 45 V59','none',GOLD,4)),
      ('char_carry_people','携民渡江',path('M14 60 H82 L66 80 H30 Z',WOOD)+circle(34,33,8,CREAM)+circle(61,33,8,CREAM)+path('M24 55 V48 Q34 40 43 48 V55 M52 55 V48 Q61 40 71 48 V55','none',JADE,8)),
      ('char_dingjun','定军山',path('M14 77 L41 24 L57 48 L66 35 L83 77 Z',JADE)+group(reticle(RED),'translate(46 1) scale(.44)')),
      ('char_moon_dance','月舞',moon()+path('M18 71 Q38 55 60 83','none',RED,8)),
      ('char_burn_camp','长社焚营',path('M16 80 L48 29 L80 80 Z',WOOD)+group(flame(),'translate(19 0) scale(.68)')),
      ('char_seven_charges','七进七出',horse(BLUE)+path('M13 17 H29 M9 29 H22 M9 41 H17','none',GOLD,5)),
      ('char_death_fight','死战',sword(RED)+group(shield(),'translate(44 44) scale(.4)')),
      ('char_borrow_wind','借东风',fan(BLUE)+path('M14 72 Q25 58 33 70 M67 79 Q81 86 84 73','none',GOLD,5)),
      ('trait_wusheng','武圣',sword(JADE)+star(26,26,12,GOLD,4)),
      ('trait_yanyan_roar','燕人咆哮',tiger(WOOD)+group(bolt(),'translate(37 47) scale(.4)')),
      ('trait_benevolence','仁德',heart(JADE)+path('M17 76 Q48 91 79 76','none',GOLD,5)),
      ('trait_hundred_step','百步穿杨',bow(JADE)+group(leaf(),'translate(45 7) scale(.38)')),
      ('trait_moon_veil','月华',moon(VIOLET)+circle(74,75,5,JADE,INK,2)),
      ('trait_royal_fire','皇家火',flame()+path('M29 24 L20 12 L38 15','none',GOLD,5)),
      ('trait_dragon_spirit','龙魂',horse(JADE)+group(bolt(),'translate(1 43) scale(.42)')),
      ('trait_captain','陷阵',shield(WOOD,True)+group(sword(),'translate(50 1) scale(.42)')),
      ('trait_star_gazer','观星',star(48,32,23,VIOLET,4)+path('M17 71 Q48 90 79 71','none',BLUE,6)+circle(19,30,4,GOLD,INK,2)),
    ]
    for k,l,s in skills:add(k,l,'skill',s)
    add('trait_vanguard', '陷阵', 'skill', gate(JADE)+group(spear(BLUE),'translate(40 7) scale(.5)'),
        '周卫被动；城墙与矛尖，命中时增加穿甲')
    add('ultimate_death_fight', '麦城死战', 'skill', group(gate(WOOD),'translate(12 12) scale(.8)')
        +path('M50 27 L43 41 L53 51 L42 72','none',INK,4)
        +group(sword(RED),'translate(5 -3) scale(.88)'), '周卫大招；红斩刃与裂损城门，低基地生命时加强')
    future_passives=[('green_dragon_stance','青龙势',sword(JADE)),('warm_wine','温酒',path('M25 27 H70 L65 60 Q48 76 30 60 Z',RED)+path('M48 68 V83 M34 83 H62','none',GOLD,6)),('yanhan','燕颔',tiger(RED)),('diligence','砥砺',group(reticle(),'translate(8 8) scale(.8)')+path('M16 76 L25 85','none',JADE,6)),('sentry','哨戒',eye(BLUE)),('worship_moon','拜月',moon(JADE)),('fierce_flame','烈焰',flame(WOOD)),('detonation','爆燃',star(fill=RED,points=7)+group(flame(GOLD),'translate(24 20) scale(.5)')),('dragon_courage','龙胆',heart(BLUE)+group(bolt(),'translate(25 30) scale(.5)')),('momentum','乘势',path('M17 68 L43 43 L57 57 L79 19 M60 20 H79 V39','none',JADE,8))]
    for k,l,s in future_passives:add('passive_'+k,l,'planned_skill',s,planned=True)
    add('bond_taoyuan_oath','桃园结义','bond',lotus(JADE)+circle(28,28,5,RED,INK,2)+circle(68,28,5,RED,INK,2))
    add('bond_five_tigers','五虎将','bond',tiger()+path('M16 78 H27 M69 78 H80','none',RED,5))
    for k,l,c in [('wei','魏',BLUE),('shu','蜀',JADE),('wu','吴',RED),('qun','群',VIOLET)]:
        add('faction_'+k,l,'faction',faction_flag(c),'军旗图徽；运行时同时显示'+l+'字，颜色仅辅助识别')
    controls={
      'ui_close':path('M25 25 L71 71 M71 25 L25 71','none',RED,10),
      'ui_check':path('M18 47 L39 69 L79 25','none',JADE,11),
      'ui_plus':path('M48 20 V76 M20 48 H76','none',GOLD,10),
      'ui_minus':path('M20 48 H76','none',BLUE,10),
      'ui_menu':path('M20 27 H76 M20 48 H76 M20 69 H76','none',GOLD,7),
      'ui_play':path('M30 17 L79 48 L30 79 Z',JADE),
      'ui_pause':rect(23,19,18,58,GOLD)+rect(55,19,18,58,GOLD),
      'ui_restart':path('M73 29 A31 31 0 1 1 20 30 M20 15 V34 H39','none',JADE,7),
      'ui_info':circle(48,48,32,BLUE)+circle(48,30,4,CREAM,CREAM,0)+path('M48 44 V67','none',CREAM,7),
      'ui_help':circle(48,48,32,GOLD)+path('M36 36 Q36 23 49 23 Q69 25 62 42 L49 50 V55','none',CREAM,6)+circle(49,69,3,CREAM,CREAM,0),
      'ui_settings':path('M37 15 H59 L62 25 L72 21 L83 39 L76 48 L83 57 L72 75 L62 71 L59 81 H37 L34 71 L24 75 L13 57 L20 48 L13 39 L24 21 L34 25 Z',BLUE)+circle(48,48,13,CREAM),
      'ui_sound':path('M16 37 H31 L50 22 V74 L31 59 H16 Z',GOLD)+path('M63 34 Q79 48 63 62 M72 22 Q94 48 72 74','none',BLUE,5),
      'ui_mute':path('M16 37 H31 L50 22 V74 L31 59 H16 Z',BLUE)+path('M63 36 L80 60 M80 36 L63 60','none',RED,6),
      'ui_music':path('M37 70 V25 L73 16 V62 M37 37 L73 28','none',VIOLET,7)+circle(27,72,10,GOLD)+circle(63,64,10,GOLD),
      'ui_fullscreen':path('M17 37 V17 H37 M59 17 H79 V37 M79 59 V79 H59 M37 79 H17 V59','none',BLUE,7),
      'ui_windowed':rect(20,24,56,48,BLUE,6)+path('M20 39 H76','none',CREAM,4),
      'ui_save':path('M19 17 H66 L78 30 V79 H19 Z',JADE)+rect(31,17,32,24,CREAM,2)+rect(30,53,36,26,CREAM,2),
      'ui_trash':path('M20 28 H76 M38 17 H58 M29 32 L34 81 H62 L67 32 M42 42 V68 M54 42 V68','none',RED,6),
      'ui_equip':sword()+circle(70,73,12,JADE)+path('M64 73 L68 78 L77 67','none',CREAM,3),
      'ui_unequip':sword()+circle(70,73,12,RED)+path('M64 73 H76','none',CREAM,3),
      'ui_home':path('M15 43 L48 15 L81 43 M25 40 V81 H71 V40','none',JADE,7)+rect(39,58,18,23,WOOD,2),
      'ui_inventory':rect(16,33,64,45,WOOD,6)+path('M16 46 H80 M22 33 V21 H74 V33','none',GOLD,6)+rect(41,43,14,17,GOLD,2),
      'ui_formation':circle(48,26,11,JADE)+circle(24,61,11,BLUE)+circle(72,61,11,GOLD)+path('M48 40 V49 M35 45 L27 49 M61 45 L69 49','none',CREAM,5),
      'ui_map':path('M15 24 L35 15 L62 25 L81 15 V72 L62 82 L35 72 L15 82 Z',JADE)+path('M35 15 V72 M62 25 V82','none',CREAM,4),
      'ui_encyclopedia':book(BLUE)+group(eye(),'translate(27 27) scale(.45)'),
      'ui_develop':horse(GOLD)+group(leaf(),'translate(48 44) scale(.43)'),
      'ui_supply':pouch(BLUE)+group(drum(),'translate(35 41) scale(.4)'),
      'ui_shop':path('M19 35 V80 H77 V35 M14 35 L22 17 H74 L82 35 Z',WOOD)+path('M16 36 Q24 53 32 36 Q40 53 48 36 Q56 53 64 36 Q72 53 80 36','none',GOLD,7)+rect(39,56,18,24,BLUE,2),
      'ui_tavern':path('M24 25 H65 V69 Q43 85 24 69 Z',WOOD)+path('M65 32 H80 V61 H65','none',GOLD,7)+path('M37 39 V62 M49 39 V62','none',CREAM,4),
      'ui_pet':circle(48,60,21,WOOD)+circle(19,37,8,GOLD)+circle(39,23,8,GOLD)+circle(60,23,8,GOLD)+circle(79,38,8,GOLD),
      'ui_tech':book(BLUE)+group(bolt(),'translate(20 17) scale(.6)'),
      'ui_talent':leaf()+path('M19 78 H35 M69 18 H82','none',GOLD,5),
      'ui_victory':path('M29 18 H67 V50 Q67 70 48 71 Q29 70 29 50 Z',GOLD)+path('M29 27 H16 V42 Q16 56 30 56 M67 27 H80 V42 Q80 56 66 56 M48 71 V83 M34 83 H62','none',GOLD,6),
      'ui_defeat':shield(RED,True),
      'ui_empty':path('M21 25 H75 V76 H21 Z','none',BLUE,5)+path('M35 50 H61','none',CREAM,5),
    }
    labels={'ui_close':'关闭','ui_check':'确认','ui_help':'帮助','ui_info':'明细','ui_settings':'设置','ui_home':'主城','ui_supply':'军需','ui_inventory':'背包','ui_map':'关卡','ui_formation':'编队','ui_encyclopedia':'百科','ui_develop':'养成','ui_tech':'科技','ui_talent':'天赋','ui_shop':'商店','ui_tavern':'酒馆','ui_pet':'战宠','ui_equip':'装备','ui_unequip':'卸下','ui_victory':'胜利','ui_defeat':'失败'}
    for k,s in controls.items():add(k,labels.get(k,k.removeprefix('ui_')),'system',s,planned=k in ['ui_pet','ui_shop','ui_tavern','ui_talent'])
    for k,deg in [('right',0),('down',90),('left',180),('up',270)]:add('ui_arrow_'+k,'方向 '+k,'system',group(path('M32 20 L65 48 L32 76','none',BLUE,9),f'rotate({deg} 48 48)'))
    add('ui_star','星级','system',star())
    add('ui_star_outline','未获星级','system',star(fill='none').replace(INK,GOLD))
    add('ui_checkbox_off','未勾选','system',rect(20,20,56,56,'none',9,BLUE,6))
    add('ui_checkbox_on','已勾选','system',rect(20,20,56,56,JADE,9)+path('M29 47 L43 61 L69 33','none',CREAM,6))
    add('ui_radio_off','未选','system',circle(48,48,28,'none',BLUE,6))
    add('ui_radio_on','已选','system',circle(48,48,28,'none',JADE,6)+circle(48,48,14,GOLD))
    add('game_crest','烽火连营','system',gate(WOOD)+group(flame(GOLD),'translate(24 -2) scale(.55)')+path('M14 79 H82','none',JADE,5))
    equipment=[('ring_blade',['环首大刀','断岳刀','斩蛟刀','伏波刀','天威刀'],sword),('long_spear',['铁脊长枪','追云枪','龙骧枪','破阵枪','天裂枪'],spear),('horn_bow',['雕角弓','穿柳弓','落雁弓','惊弦弓','天狼弓'],bow),('silk_bells',['金铃绶带','流霞带','回雪绫','承云绫','天霓绫'],bell),('thunder_cart',['霹雳车','轰雷车','轰山砲','崩云砲','乾元砲'],catapult),('ritual_staff',['桃木法杖','青竹杖','玄玉杖','承星杖','天枢杖'],lambda c:path('M33 83 L62 21','none',WOOD,8)+star(64,24,18,c,4)),('bone_mace',['骨朵','虎头锤','镇军钺','撼山斧','玄天钺'],lambda c:path('M25 81 L64 33','none',WOOD,8)+circle(64,31,20,c)+path('M55 15 L72 48','none',CREAM,4)),('horse_sword',['斩马剑','断流剑','秋水剑','承光剑','玄光剑'],lambda c:group(sword(c),'rotate(-20 48 48)')),('mulberry_bow',['桑木弓','鸣镝弓','引风弓','星落弓','天陨弓'],lambda c:group(bow(c),'rotate(20 48 48)')),('clay_flute',['陶埙','和鸾笙','鸣凤箫','承露笛','九韶琴'],lambda c:path('M48 16 Q78 50 70 75 Q48 88 26 75 Q18 50 48 16 Z',c)+circle(40,51,4,INK,INK,1)+circle(56,51,4,INK,INK,1)+circle(48,67,4,INK,INK,1)),('wood_mortar',['木梢砲','裂石砲','摧城砲','承天砲','天崩砲'],lambda c:catapult(c)+path('M20 46 H35','none',RED,5)),('bamboo_banner',['竹节幡','七星幡','八卦幡','承曦幡','河洛幡'],lambda c:flag(c)+group(star(fill=CREAM,points=4),'translate(41 7) scale(.35)'))]
    for family,names,draw in equipment:
        for tier,name in enumerate(names):
            c=[WOOD,JADE,BLUE,VIOLET,GOLD][tier]
            decor=''.join(circle(14+i*9,84,2.5,c,INK,1.2) for i in range(tier))
            add('equipment_'+family+'_'+str(tier+1),name,'equipment',draw(c)+decor,planned=(tier > 0))
    # Technology has a symbolic concept and tier marker rather than a title initial.
    tech_map={'mil_dmg':sword(),'prof_tiger_guard':tiger(),'prof_cavalry':horse(),'prof_archer':bow(),'prof_strategist':fan(),'prof_dancer':lotus(),'prof_catapult':catapult(),'eco_gold':coin(),'eco_wave':flag(),'inf_hp':gate(),'strat_rage':flame(GOLD),'strat_refund':ingot(),'strat_upgrade':shield(),'strat_supply':pouch()}
    tech_text=(ROOT/'resources/tech/tech_tree.tres').read_text(encoding='utf-8')
    for tid in re.findall(r'^id = "([^"]+)"',tech_text,re.M):
        base,num=tid.rsplit('_',1)
        marks=''.join(circle(33+i*13,85,2.7,GOLD,INK,1) for i in range(int(num)))
        add('tech_'+tid,tid,'tech',group(tech_map.get(base,book()),'translate(7 2) scale(.85)')+marks)

def cursors():
    shapes={
      'pointer_toon_a':path('M9 9 L72 48 L47 54 L61 79 L45 87 L32 61 L12 78 Z',CREAM,INK,6),
      'pointer_a':path('M9 9 L69 48 L45 54 L59 80 L43 87 L31 60 L12 77 Z',BLUE,INK,6),
      'hand_point':path('M29 81 L18 59 Q15 49 24 47 L34 59 V15 Q40 7 46 16 V42 Q49 34 56 40 Q59 35 66 42 Q76 40 78 53 L74 76 L66 85 Z',CREAM,INK,5),
      'hand_closed':path('M24 76 L18 52 Q18 40 29 41 L34 49 V29 Q42 20 47 34 L48 42 Q56 27 63 40 Q77 33 80 51 L75 73 L65 83 Z',CREAM,INK,5),
      'cross_large':path('M48 10 V35 M48 61 V86 M10 48 H35 M61 48 H86','none',CREAM,8)+circle(48,48,8,JADE,INK,4),
      'drawing_pen':path('M11 11 L32 14 L78 62 L64 78 L16 32 Z',GOLD)+path('M11 11 L16 32 L32 14 Z',BLUE)+path('M64 78 L78 62 L86 71 L73 87 Z',RED),
      'drawing_brush':path('M21 17 L71 66','none',WOOD,14)+path('M61 57 Q83 57 86 86 Q58 86 57 66 Z',CREAM)+path('M77 69 L80 83','none',JADE,5),
      'drawing_eraser':path('M15 50 L48 16 L81 49 L48 82 H35 Z',RED)+path('M25 62 L58 29','none',CREAM,6),
      'cursor_disabled':path('M9 9 L58 40 L38 47 L48 69 L34 74 L26 52 L12 66 Z',BLUE)+circle(65,65,23,RED)+path('M52 52 L78 78','none',CREAM,7),
    }
    for key,shape in shapes.items():add(key,key,'cursor',shape)

def legacy_snapshot():
    files=[]
    for p in (ROOT/'assets/ui').rglob('*'):
        if p.is_file() and OUT not in p.parents and ('icons' in p.parts or 'cursors' in p.parts):files.append(p)
    for dirname in ['icons_hud','icons_battle','svg_icons','kenney_cursor_pack']:
        files.extend(p for p in (ROOT/'docs/ui_concept/src'/dirname).rglob('*') if p.is_file())
    files.extend(p for p in [ROOT/'icon.svg',ROOT/'icon.svg.import'] if p.is_file())
    target=OUT/'legacy_archive.json'
    tracked=set(subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode('utf-8').split('\0'))
    if target.exists():
        data=json.loads(target.read_text(encoding='utf-8'))
        changed=[name for name,sha in data.items() if not (ROOT/name).is_file() or hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=sha]
        assert not changed, f'Legacy files changed: {changed}'
    else:
        data={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(files))}
    # Machine-local experiments/import metadata remain untouched, outside the
    # portable repository baseline. Preserve their hashes in the ignored build dir.
    workspace_archive=ROOT/'build/icons_v2_legacy_workspace.json'
    if not workspace_archive.exists():
        workspace_archive.parent.mkdir(parents=True,exist_ok=True)
        write_generated_text(workspace_archive,json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    portable={name:sha for name,sha in data.items() if name in tracked}
    write_generated_text(target,json.dumps(portable,ensure_ascii=False,indent=2)+'\n')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',default=os.environ.get('GODOT_BIN') or shutil.which('godot') or 'F:/Godot/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe',help='Godot executable for SVG to PNG rendering')
    parser.add_argument('--render-all',action='store_true',help='Render every PNG even if its SVG is unchanged')
    args=parser.parse_args()
    godot=Path(args.godot)
    if not godot.is_file():parser.error('Godot executable not found; use --godot or GODOT_BIN')
    OUT.mkdir(parents=True,exist_ok=True)
    legacy_snapshot()
    catalogue();cursors()
    skill_art=build_skill_art(globals())
    assert set(skill_art)<=set(icon['id'] for icon in ICONS)
    for icon in ICONS:
        if icon['id'] in skill_art:
            icon.update(skill_art[icon['id']])
            icon['category']='skill'
    for talent in build_talent_art(globals()):
        add(talent['id'],talent['label'],'talent',talent['svg_body'],talent['description'])
    records=[]
    changed=[]
    for icon in ICONS:
        sub='cursors/' if icon['category']=='cursor' else ''
        key=icon['id']
        target=OUT/sub
        target.mkdir(parents=True,exist_ok=True)
        svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 96 96"><title>{html.escape(icon["label"])}</title>{icon["svg_body"]}</svg>\n'
        svg_path=target/(key+'.svg')
        if not svg_path.exists() or svg_path.read_text(encoding='utf-8')!=svg:
            write_generated_text(svg_path,svg)
            changed.append(key)
        elif (not (target/(key+'.png')).exists()
              or (target/(key+'.png')).stat().st_size==0
              or (target/(key+'.png')).stat().st_mtime_ns<svg_path.stat().st_mtime_ns
              or (sub and not (target/(key+'_2x.png')).exists())):
            changed.append(key)
        records.append({k:v for k,v in icon.items() if k!='svg_body'}|dict(svg=sub+key+'.svg',png=sub+key+'.png',pixels=32 if sub else 256))
    manifest=dict(version=2,source='original SVG; rendered by Godot',icons=records)
    write_generated_text(OUT/'manifest.json',json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    # No shell, no deleted files, no generation from old PNGs.
    if args.render_all or changed:
        command=[str(godot),'--headless','--path',str(ROOT),'--script',str(ROOT/'tools/render_icons_v2.gd')]
        if not args.render_all: command+=['--','--icons='+','.join(changed)]
        subprocess.run(command,check=True)
    from PIL import Image,ImageDraw,ImageFont
    crest=Image.open(OUT/'game_crest.png')
    write_generated_image(crest,OUT/'game_crest.ico',sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
    cards=[]
    for item in records:
        cards.append(f'<article data-category="{item["category"]}" data-name="{html.escape(item["id"]+item["label"])}"><div class="sample"><img src="../../assets/ui/icons/v2/{item["png"]}"><img class="small" src="../../assets/ui/icons/v2/{item["png"]}"></div><b>{html.escape(item["label"])}</b><code>{item["id"]}</code><small>{item["category"]}{" · 预备图" if item["planned"] else ""}</small></article>')
    overview='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>烽火连营 · 新版图标</title><style>*{box-sizing:border-box}body{margin:0;background:#10271f;color:#f8f0d6;font:15px system-ui}header{padding:36px 5%;position:sticky;top:0;background:#10271fee;z-index:1;border-bottom:1px solid #456256}h1{margin:0 0 10px;font-size:30px}input,select,button{font:inherit;padding:9px 16px;margin:12px 10px 0 0;border-radius:8px;border:1px solid #6d8f7c;background:#203b30;color:#fff0c6}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(170px,1fr));gap:14px;padding:28px 5%}article{padding:16px;background:#244234;border:1px solid #496551;border-radius:12px}article b,code,small{display:block;margin-top:7px}code{font-size:10px;overflow-wrap:anywhere;color:#b2d3c3}small{font-size:11px;color:#d1c49f}.sample{display:flex;align-items:center;justify-content:space-evenly;height:78px}.sample img{width:64px;height:64px}.sample .small{width:20px;height:20px}.light article{background:#f4f2e7;color:#243b36}.light code,.light small{color:#597069}article[hidden]{display:none}</style><header><h1>烽火连营 · 新版图标</h1><div>透明 SVG 母版 → Godot PNG · 大小双览 · 旧素材保留归档</div><input id="search" placeholder="搜索语义或文件名"><select id="category"><option value="">全部分类</option>'''+''.join(f'<option>{c}</option>' for c in sorted({i['category'] for i in records}))+'''</select><button onclick="document.body.classList.toggle('light')">切换亮／暗底</button><span id="count"></span></header><main>'''+''.join(cards)+'''</main><script>const s=document.querySelector('#search'),c=document.querySelector('#category');function filter(){let n=0;document.querySelectorAll('article').forEach(a=>{a.hidden=!(a.dataset.name.includes(s.value)&&(!c.value||a.dataset.category===c.value));if(!a.hidden)n++});document.querySelector('#count').textContent=n+' 枚'}s.oninput=c.onchange=filter;filter()</script></html>'''
    write_generated_text(ROOT/'docs/ui_concept/icons_v2.html',overview)
    fontpath=ROOT/'assets/fonts/ZCOOLKuaiLe-Regular.ttf'
    if not fontpath.exists():fontpath=Path('C:/Windows/Fonts/msyh.ttc')
    font=ImageFont.truetype(str(fontpath),17)
    cols=10;cellw=152;cellh=136;rows=math.ceil(len(records)/cols)
    sheet=Image.new('RGB',(cols*cellw,rows*cellh+100),'#11271f');draw=ImageDraw.Draw(sheet)
    draw.text((28,28),f'烽火连营 · 新版图标 / {len(records)} 枚',font=ImageFont.truetype(str(fontpath),30),fill='#fff0c6')
    for idx,item in enumerate(records):
        x=(idx%cols)*cellw;y=(idx//cols)*cellh+92
        draw.rounded_rectangle((x+5,y+3,x+cellw-6,y+cellh-5),10,fill='#274334')
        source=Image.open(OUT/item['png']).convert('RGBA')
        thumb=source.resize((72,72),Image.Resampling.LANCZOS);sheet.paste(thumb,(x+38,y+8),thumb)
        draw.text((x+8,y+86),item['label'][:9],font=font,fill='#fff0c6')
        draw.text((x+8,y+108),item['category'],font=ImageFont.truetype(str(fontpath),12),fill='#99b9a7')
    write_generated_image(sheet,ROOT/'docs/ui_concept/icons_v2.png')
    featured=[i for i in records if i['category'] in ['hud','equipment_rarity','status','rank','item','supply']][:78]
    preview=Image.new('RGB',(1200,820),'#11271f');pen=ImageDraw.Draw(preview)
    pen.text((24,16),'烽火连营 · 新版透明图标',font=ImageFont.truetype(str(fontpath),26),fill=CREAM)
    for idx,item in enumerate(featured):
        x=(idx%13)*92;y=(idx//13)*124+72
        bg='#f4f2e7' if idx//13>=3 else '#274334'
        pen.rounded_rectangle((x+4,y,x+88,y+112),7,fill=bg)
        original=Image.open(OUT/item['png']).convert('RGBA')
        thumb=original.resize((52,52),Image.Resampling.LANCZOS);preview.paste(thumb,(x+21,y+9),thumb)
        tiny=original.resize((15,15),Image.Resampling.LANCZOS);preview.paste(tiny,(x+39,y+68),tiny)
        pen.text((x+8,y+88),item['label'][:5],font=ImageFont.truetype(str(fontpath),12),fill=CREAM if idx//13<3 else INK)
    write_generated_image(preview,ROOT/'docs/ui_concept/icons_v2_preview.png')
    additions=[i for i in records if i['id'] in ['ingot','lord_level','lord_exp','trait_vanguard','ultimate_death_fight'] or i['category']=='equipment_rarity']
    sizes=[15,18,20,24,34,56]
    detail=Image.new('RGB',(1280,968),'#11271f');pen=ImageDraw.Draw(detail)
    pen.text((24,18),'经济、装备品质与技能 · 十枚图徽 / 亮暗底实际尺寸',font=ImageFont.truetype(str(fontpath),26),fill=CREAM)
    for base,bg,fg in [(200,'#274334',CREAM),(734,'#f4f2e7',INK)]:
        for column,pixels in enumerate(sizes):
            pen.text((base+column*84+18,65),str(pixels)+'px',font=font,fill=CREAM)
        pen.rounded_rectangle((base,94,base+508,952),10,fill=bg)
        for row,item in enumerate(additions):
            y=103+row*84
            source=Image.open(OUT/item['png']).convert('RGBA')
            for column,pixels in enumerate(sizes):
                thumb=source.resize((pixels,pixels),Image.Resampling.LANCZOS)
                detail.paste(thumb,(base+column*84+(84-pixels)//2,y+(76-pixels)//2),thumb)
    for row,item in enumerate(additions):
        y=103+row*84
        pen.text((20,y+16),item['label'],font=font,fill=CREAM)
        pen.text((20,y+42),item['id'],font=ImageFont.truetype(str(fontpath),12),fill=JADE)
    write_generated_image(detail,ROOT/'docs/ui_concept/icons_v2_additions.png')
    create_skill_previews(records,OUT,ROOT,fontpath,write_generated_image)
    create_talent_previews(records,OUT,ROOT,fontpath,write_generated_image)
    print(f'Generated {len(records)} original icon masters and PNGs; legacy hashes unchanged.')

if __name__=='__main__':main()

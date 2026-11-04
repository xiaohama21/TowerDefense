"""110 original talent compositions: distinct action, weapon and effect silhouettes."""
import json
from pathlib import Path


def build_talent_art(draw):
    p,c,g=(draw[k] for k in ('path','circle','group'))
    ink,gold,jade,blue,red,violet,cream,wood=(draw[k] for k in ('INK','GOLD','JADE','BLUE','RED','VIOLET','CREAM','WOOD'))
    skin='#ffe0ad'

    def line(points,color,width=4):
        d='M'+' L'.join(f'{x} {y}' for x,y in points)
        return p(d,'none',ink,width+2)+p(d,'none',color,width)

    def obj(name,x=73,y=26,scale=.35,color=gold):
        shape=draw[name]() if name=='lord_crown' else (draw[name](color) if name!='star' else draw['star'](fill=color))
        return g(shape,f'translate({x-48*scale} {y-48*scale}) scale({scale})')

    def weapon(kind,x,y,angle=0,color=blue):
        if kind in ('spear','glaive'):
            body=line([(0,8),(0,-35)],wood,3)
            body+=p('M0 -45 L-5 -32 L0 -25 L5 -32 Z',color,ink,2) if kind=='spear' else p('M0 -43 Q18 -39 10 -22 L0 -27 Z',jade,ink,2)
        elif kind=='sword': body=p('M-3 -6 L-4 -32 L0 -43 L4 -32 L3 -6 Z',color,ink,2)+line([(-6,-5),(6,-5)],gold,3)+line([(0,-4),(0,7)],wood,3)
        elif kind=='fan': body=p('M0 3 L-18 -17 Q0 -31 18 -17 Z',cream,ink,2)+p('M0 2 L-10 -17 M0 2 V-22 M0 2 L10 -17','none',jade,2)
        elif kind=='staff': body=line([(0,8),(0,-31)],wood,3)+c(0,-33,7,violet,ink,2)+p('M-4 -36 L3 -31','none',cream,2)
        elif kind=='bow': body=p('M0 -20 Q20 0 0 20','none',ink,6)+p('M0 -20 Q20 0 0 20','none',wood,3)+p('M0 -20 L-9 0 L0 20','none',cream,2)+line([(-16,0),(20,0)],blue,2)+p('M13 -5 L22 0 L13 5',blue,ink,2)
        elif kind=='flag': body=line([(0,10),(0,-37)],wood,3)+p('M1 -37 Q13 -42 23 -32 L18 -15 Q8 -22 1 -16 Z',color,ink,2)
        else: body=obj('bell',0,-10,.25,gold)
        return g(body,f'translate({x} {y}) rotate({angle}) scale(.65)')

    poses={
        'slash':((36,27),[(43,41),(51,31),(57,38)],[(29,42),(20,52),(14,56)],[(31,64),(19,82)],[(40,64),(59,78)]),
        'dash':((33,30),[(40,44),(52,48),(60,43)],[(26,44),(19,58),(11,62)],[(28,64),(14,81)],[(37,64),(59,76)]),
        'guard':((36,26),[(43,41),(53,49),(59,55)],[(29,41),(23,49),(29,56)],[(31,64),(23,82)],[(40,64),(52,82)]),
        'raise':((36,28),[(43,42),(51,34),(56,31)],[(29,42),(19,34),(17,26)],[(31,65),(22,82)],[(40,65),(52,81)]),
        'cast':((34,27),[(41,41),(52,44),(60,36)],[(27,41),(17,34),(11,27)],[(29,64),(22,81)],[(38,64),(50,81)]),
        'shout':((37,27),[(44,41),(55,34),(63,39)],[(30,41),(20,42),(13,33)],[(32,64),(22,82)],[(41,64),(57,81)]),
        'shoot':((29,26),[(36,40),(49,43),(59,42)],[(22,40),(34,33),(39,40)],[(25,63),(17,82)],[(34,63),(47,80)]),
        'kneel':((35,35),[(42,49),(48,36),(56,30)],[(28,49),(25,38),(31,32)],[(30,69),(19,82)],[(39,69),(55,79)]),
        'dance':((35,24),[(42,38),(52,28),(59,23)],[(28,38),(20,46),(12,51)],[(30,61),(22,80)],[(39,61),(53,69),(47,80)]),
        'command':((27,29),[(34,43),(46,35),(55,29)],[(20,43),(19,55),(26,58)],[(23,65),(17,82)],[(32,65),(44,82)]),
    }

    def actor(pose='slash',kind='sword',color=jade,angle=35,mage=False):
        (x,y),right,left,leg_a,leg_b=poses[pose]
        trim=violet if mage else wood
        body=p(f'M{x-7} {y+13} Q{x-20} {y+26} {x-15} {y+44} L{x-1} {y+36} Z',trim,ink,2)
        body+=line(leg_a,trim,4)+line(leg_b,trim,4)
        body+=p(f'M{x-8} {y+12} Q{x} {y+8} {x+8} {y+12} L{x+10} {y+34} Q{x} {y+40} {x-10} {y+34} Z',color,ink,2.5)
        body+=line(right,color,4)+line(left,color,4)+c(x,y,8,skin,ink,2.5)+c(x+3,y,1,ink,ink,0)
        if mage: body+=p(f'M{x-8} {y-3} L{x-5} {y-14} L{x+1} {y-9} L{x+7} {y-13} L{x+9} {y-3} Z',violet,ink,2)
        else: body+=p(f'M{x-9} {y-3} Q{x-8} {y-13} {x} {y-12} Q{x+9} {y-12} {x+9} {y-3} H{x-9} Z',blue,ink,2)+p(f'M{x} {y-12} Q{x-1} {y-22} {x+10} {y-16} Z',red,ink,2)
        body+=p(f'M{x-6} {y+28} H{x+7}','none',gold,3)
        body+=c(*right[-1],2.7,skin,ink,1.5)+c(*left[-1],2.7,skin,ink,1.5)
        return body+weapon(kind,*right[-1],angle,color)

    def arc(color=jade,double=False):
        shape=p('M15 37 Q42 6 83 20 Q54 21 25 48 Z',color,ink,2)
        if double: shape+=p('M22 61 Q47 35 86 39','none',color,4)
        return shape

    def clock(x=73,y=27,color=gold):
        return c(x,y,13,cream,ink,2)+c(x,y,10,'none',color,2)+p(f'M{x} {y-7} V{y} L{x+6} {y+4}','none',ink,2.5)

    def shards(): return p('M67 47 L75 42 L72 54 Z M81 59 L88 53 L86 66 Z M64 72 L73 67 L71 80 Z',blue,ink,2)

    def allies(color=blue):
        shape=''
        for x,y in [(72,51),(84,65)]: shape+=c(x,y,4,skin,ink,2)+p(f'M{x-5} {y+6} H{x+5} L{x+7} {y+18} H{x-7} Z',color,ink,2)
        return shape

    def net(color=blue):
        return p('M20 26 L72 26 L82 75 L10 75 Z',color,ink,3)+p('M29 28 L22 72 M42 28 L39 72 M55 28 L58 72 M65 28 L73 72 M16 43 H75 M13 58 H78','none',cream,3)

    def horn(color=gold): return p('M12 59 L19 39 Q48 47 74 16 L83 35 Q57 65 26 66 Z',color,ink,3)+p('M68 19 L77 37 M20 42 L26 64','none',wood,4)

    def tent(): return p('M11 76 L46 20 L83 76 Z',red,ink,3)+p('M46 25 V77 M31 76 L46 49 L60 76 Z',cream,ink,3)+weapon('flag',46,31,0,gold)

    def chest(color=wood): return p('M14 40 Q16 22 48 22 Q80 22 82 40 V76 H14 Z',color,ink,3)+p('M14 42 H82 M30 24 V76 M65 24 V76','none',gold,5)+p('M41 38 H55 V54 H41 Z',gold,ink,2)+c(48,45,2,ink,ink,0)

    def hourglass(): return p('M25 15 H71 V24 L53 48 L71 73 V83 H25 V73 L43 48 L25 24 Z',cream,ink,3)+p('M32 24 H64 L48 41 Z M31 74 L48 55 L65 74 Z',gold,ink,2)+p('M20 14 H77 M20 84 H77','none',wood,6)

    def dragon(): return p('M15 62 Q18 33 47 33 Q72 32 70 54 Q67 72 44 68 Q24 62 36 51 Q49 42 53 53 Q46 57 48 62 Q70 68 77 47 L82 27 L68 17 L50 23 L45 35 L58 39 Q59 19 75 26 L86 13 L79 33 Q90 62 67 80 Q28 91 15 62 Z',jade,ink,3)+p('M62 21 L61 8 L70 18 M74 20 L81 7 L79 25 M54 32 L67 33','none',gold,3)+c(70,27,2,ink,ink,0)

    A=actor; O=obj
    # Each ordered recipe corresponds to one actual data node; differences are semantic shapes and poses.
    recipes={
      'physical_burst':[
        (arc()+A('slash'), '跨步挥刀与单道斩弧'),
        (p('M8 48 H20 M9 59 H19 M7 70 H17','none',jade,4)+A('dash','sword',jade,58), '前冲剑士与疾速流线'),
        (A('shoot','bow',gold,0)+O('reticle',79,30,.28,red), '射手瞄准会心靶心'),
        (A('slash','spear',red,45)+O('lord_crown',76,62,.31,gold), '长矛刺向精英冠印'),
        (A('dash','spear',blue,60)+O('armor',77,45,.37,blue)+shards(), '贯革长矛穿过甲片'),
        (A('raise','sword',red,20)+O('star',74,62,.42,gold)+shards(), '高举利刃与碎裂暴击光'),
        (arc(jade,True)+A('slash','glaive',jade,40), '双重连斩的偃月刀动作'),
        (A('command','flag',jade,10)+allies()+O('sword',76,22,.3,blue), '持旗武将号令进攻'),
        (A('raise','flag',gold,10)+O('lord_crown',75,58,.4,gold), '胜利举旗与凯旋冠印'),
        (dragon()+O('glaive' if 'glaive' in draw else 'sword',20,60,.36,gold), '盘旋青龙环绕偃月刀锋'),
      ],
      'armor_break':[
        (O('sword',42,48,.78,blue)+p('M64 22 L80 12 M66 30 L88 24','none',cream,5), '剑刃磨砺与锋芒亮线'),
        (O('lord_crown',60,38,.58,gold)+O('spear',34,55,.72,blue), '长矛贯穿精英王冠'),
        (O('armor',48,44,.77,blue)+p('M24 75 H73 M32 65 V84 M65 65 V84','none',wood,7), '铆固钢甲与铁砧支架'),
        (O('shield',57,49,.78,blue)+weapon('spear',19,79,40,red)+shards(), '斜刺长矛与裂盾甲片'),
        (O('tiger',57,43,.76,gold)+O('sword',32,58,.61,blue), '重剑斩向Boss猛虎剪影'),
        (c(48,48,37,'none',violet,4)+O('armor',48,48,.67,blue)+weapon('sword',76,76,-38,gold), '护甲光环内的破竹剑锋'),
        (O('shield',52,50,.75,blue)+O('bolt',50,45,.8,gold)+shards(), '金色爆裂穿甲与盾牌碎片'),
        (O('armor',55,48,.72,blue)+weapon('sword',20,79,38,jade)+weapon('sword',74,78,-26,red), '两次连击的交叉剑刃'),
        (A('guard','sword',blue,18)+shards()+O('armor',75,28,.3,blue), '击杀破甲后持剑守势'),
        (O('shield',47,50,.83,blue)+weapon('spear',48,86,0,gold)+p('M16 21 L30 36 M75 23 L66 39','none',red,5)+shards(), '贯穿整面重盾的金色真伤长矛'),
      ],
      'rage':[
        (A('guard','glaive',red,0)+O('flame',73,32,.36,gold), '持刀蓄势与战意火苗'),
        (A('raise','spear',red,-10)+O('heart',77,61,.31,red), '举矛斗志与燃起的战心'),
        (O('eye',48,47,.89,red)+O('sword',48,74,.36,gold), '怒目凝视与大招剑锋'),
        (A('shout','sword',red,38)+O('flame',78,65,.35,red)+shards(), '击杀呐喊与怒火迸发'),
        (p('M8 71 Q25 34 47 59 Q65 22 88 39 L80 78 H14 Z',blue,ink,3)+O('flame',51,36,.65,red), '翻涌怒涛托起战火'),
        (O('gate',56,55,.76,blue)+O('flag',22,27,.35,red)+p('M21 72 Q52 52 84 66','none',gold,5), '漏怪关隘警旗与激昂波纹'),
        (O('flame',35,50,.82,red)+clock(73,27,gold), '恒燃怒焰与结束后计时'),
        (A('kneel','sword',red,0)+O('feather',73,32,.44,gold)+O('flame',77,70,.3,red), '再起武将与凤凰火羽'),
        (p('M8 57 H20 M8 71 H15','none',gold,5)+A('dash','glaive',red,48)+O('flame',73,18,.3,red), '冲锋武将拖曳烈焰'),
        (arc(red,True)+A('shout','glaive',red,20)+O('flame',77,65,.36,gold), '怒不可遏双烈焰斩击'),
      ],
      'physical_area':[
        (O('catapult',52,57,.85,wood)+O('sword',25,27,.36,blue), '投石机与锋芒刀锋'),
        (O('catapult',46,56,.86,wood)+O('stone',76,20,.27,gold)+clock(21,24), '蓄力投石与计时弹石'),
        (O('flag',48,48,.7,red)+allies(jade)+O('stone',21,67,.26,wood), '扩阵战旗与散布军士'),
        (O('stone',48,31,.58,wood)+allies()+p('M12 79 L35 57 M82 78 L62 55','none',red,5), '落石破众与双目标冲击'),
        (O('catapult',43,56,.78,wood)+O('reticle',76,29,.39,gold), '瞄准会心的投石机'),
        (O('flame',51,37,.69,red)+O('catapult',46,69,.56,wood), '火势覆盖燃石车'),
        (O('stone',41,57,.67,wood)+O('flame',70,27,.42,gold)+p('M17 31 H28 M12 39 H23','none',red,4), '滚动余烬与加速流线'),
        (O('gate',61,47,.76,blue)+O('catapult',23,65,.5,wood)+O('stone',33,23,.29,wood), '攻城投石与坚固关门'),
        (tent()+O('flame',75,60,.36,red)+O('flag',19,52,.28,red), '连营帐篷与火焰号旗'),
        (O('catapult',48,57,.8,wood)+O('flame',20,25,.32,red)+O('flame',48,18,.4,gold)+O('flame',80,29,.32,red), '三处火阵连环爆燃的投石车'),
      ],
      'magic_burst':[
        (A('kneel','staff',violet,0,True)+O('book',74,60,.39,violet), '凝神术士与咒术书'),
        (A('dash','staff',violet,35,True)+p('M10 35 H22 M10 47 H19','none',violet,4), '疾咒前冲与法杖流线'),
        (A('cast','staff',violet,30,True)+O('star',82,18,.3,gold), '远谋术士释放远处星光'),
        (O('book',46,57,.84,violet)+O('bolt',69,25,.5,gold), '灵术书中飞出雷咒'),
        (A('raise','staff',violet,-20,True)+O('reticle',79,61,.37,gold), '举杖施法与会心光靶'),
        (O('bolt',47,50,.9,violet)+O('shield',73,67,.32,blue)+shards(), '破咒闪电击碎护盾'),
        (O('book',32,54,.58,violet)+O('spear',61,48,.75,violet)+O('armor',74,62,.3,blue), '透法长锥穿甲的术式卷册'),
        (A('command','staff',violet,22,True)+O('moon',76,38,.41,violet)+O('heart',75,71,.26,red), '追魂术士锁定残血月影'),
        (A('command','fan',jade,15,True)+O('scroll',75,60,.4,cream), '玄谋军师执扇推演卷轴'),
        (O('book',47,59,.76,violet)+O('star',48,25,.56,gold)+O('moon',80,62,.28,violet), '玄策定局的星盘咒书'),
      ],
      'magic_area':[
        (A('cast','fan',jade,20,True)+O('flame',77,40,.42,red), '凝神施扇汇聚火球'),
        (A('raise','staff',red,-10,True)+O('bell',74,67,.38,gold), '疾吟法师与咒铃节奏'),
        (A('command','staff',blue,25,True)+O('eye',78,57,.4,jade), '远谋施法与侦察视野'),
        (O('flame',48,50,.91,red)+O('bolt',48,43,.41,gold), '天焰火心内的金雷'),
        (O('flame',47,31,.49,red)+p('M13 79 Q21 42 48 46 Q77 41 84 80 M25 79 Q29 58 48 61 Q67 56 72 79','none',red,4), '火焰向外扩散的双层范围'),
        (O('fan',43,55,.82,jade)+O('star',74,29,.39,gold), '慧心羽扇上的暴击星光'),
        (net(violet)+O('flame',48,46,.5,red), '火网困敌与受控灼压'),
        (A('kneel','fan',jade,30,True)+O('book',77,57,.4,violet)+O('star',74,18,.22,gold), '奇谋军师伏案推演'),
        (O('gate',51,56,.77,blue)+O('bolt',28,27,.45,gold)+O('flame',74,33,.38,red), '天火破阵与关门崩解'),
        (O('flame',47,53,.8,red)+O('flame',19,39,.36,gold)+O('flame',77,32,.43,red)+O('fan',49,80,.33,jade), '天火燎原三焰与军师羽扇'),
      ],
      'support_control':[
        (A('guard','spear',blue,-10)+O('eye',77,30,.34,jade), '持矛警戒与观察敌情'),
        (A('dash','flag',blue,27)+p('M9 32 H22 M9 43 H17','none',blue,4), '迅令持旗前冲'),
        (A('raise','spear',red,28)+O('tiger',77,65,.33,gold), '威势武将举矛虎啸'),
        (A('shout','spear',blue,25)+p('M71 17 Q89 32 76 49 M77 13 Q95 31 87 44','none',red,4), '震慑咆哮扩出声波'),
        (O('shield',48,48,.85,blue)+O('sword',48,50,.58,red), '压制盾牌上的镇军剑锋'),
        (A('guard','flag',red,10)+O('flame',75,33,.38,gold), '战意守旗与积怒火焰'),
        (O('shield',43,49,.8,blue)+hourglass_scaled(72,61,.38,hourglass,g), '迟滞重盾与沙漏时间'),
        (A('command','spear',blue,35)+O('bell',77,60,.37,gold), '号令长矛与指挥铜铃'),
        (A('raise','flag',jade,5)+allies(gold)+O('star',79,25,.3,gold), '振军举旗激励友军'),
        (A('shout','flag',red,10)+O('shield',76,60,.42,blue)+p('M62 14 Q90 23 78 40','none',gold,5), '镇军威令的战旗重盾与吼声'),
      ],
      'support_buff':[
        (A('guard','fan',jade,20,True)+allies(blue), '照应友军的执扇辅助'),
        (A('command','bell',jade,0,True)+O('feather',78,27,.4,jade), '迅令铜铃与飘动羽毛'),
        (A('kneel','bell',violet,0,True)+O('heart',74,53,.4,red), '聚志辅助祈愿战心'),
        (A('raise','flag',jade,-5)+allies()+O('sword',78,26,.32,gold), '激励战旗提升友军攻击'),
        (A('dance','bell',violet,0,True)+p('M65 16 Q88 22 81 37 M74 11 Q94 18 88 29','none',gold,3), '长歌舞者振铃与持续声纹'),
        (O('heart',38,45,.76,red)+O('heart',65,58,.52,jade)+O('star',74,20,.25,gold), '两颗同心战心与会心光'),
        (A('shout','flag',jade,10)+O('lord_crown',77,59,.4,gold), '齐心持旗大招号令'),
        (A('command','bell',red,0)+O('drum',73,62,.4,red), '鸣鼓辅助指挥脉冲'),
        (A('raise','sword',gold,20)+O('feather',78,58,.42,jade), '昂扬举剑与飞升羽翼'),
        (A('dance','fan',violet,24,True)+allies(jade)+O('flag',76,18,.28,gold), '同袍协力旋舞护佑友军'),
      ],
      'control':[
        (O('eye',48,39,.86,jade)+O('flag',48,74,.4,blue), '瞭望眼与哨塔标旗'),
        (p('M22 21 L33 73 M64 21 L55 73 M19 67 Q48 41 75 67','none',wood,5)+O('leaf',76,32,.4,jade), '绊足绳索与草丛陷阱'),
        (net(blue)+O('sword',49,48,.65,red), '制敌网中的压制剑'),
        (hourglass()+O('flag',78,66,.34,blue), '缓阵沙漏与阵旗'),
        (net(violet)+O('lord_crown',47,41,.55,gold), '困将铁网罩住Boss冠印'),
        (O('scroll',46,53,.8,cream)+O('bolt',74,25,.37,violet), '机变卷轴与应变雷光'),
        (p('M13 34 H79 M25 24 V72 M47 24 V80 M69 24 V72','none',wood,6)+O('shield',48,53,.46,blue), '牵制三叉铁栅与护盾'),
        (O('shield',52,51,.83,blue)+weapon('sword',24,80,30,violet)+O('bolt',77,26,.3,gold), '破势剑斩控制护盾'),
        (O('eye',47,41,.79,jade)+O('leaf',25,73,.37,jade)+O('leaf',74,71,.32,wood), '识伏探眼拨开隐匿草叶'),
        (net(jade)+O('lord_crown',26,24,.31,gold)+O('flag',75,75,.32,blue)+O('shield',47,48,.34,blue), '控场棋阵中的网、旗与将位'),
      ],
      'buff':[
        (horn()+O('sword',69,67,.39,blue), '鼓劲军号与攻击剑锋'),
        (O('bell',39,47,.8,gold)+p('M69 19 Q90 35 78 51 M77 16 Q98 37 87 59','none',violet,3), '余音铜铃与持续声波'),
        (O('flag',42,43,.78,jade)+allies()+O('heart',76,23,.25,red), '广济战旗覆盖两名友军'),
        (O('drum',40,55,.75,red)+O('flame',75,30,.4,gold), '积势战鼓汇聚怒火'),
        (O('fan',41,51,.83,jade)+O('star',77,22,.38,violet), '慧心羽扇与紫色暴击光'),
        (O('book',48,57,.75,violet)+O('flag',74,28,.39,jade), '谋略兵书与号旗'),
        (O('moon',41,39,.8,cream)+allies(violet)+O('flame',24,74,.26,gold), '协心月光连接友军积怒'),
        (A('dash','flag',jade,28)+O('drum',77,62,.34,red), '奋进持旗者与战鼓节奏'),
        (O('drum',48,52,.81,red)+weapon('spear',23,38,55,gold)+O('star',78,22,.28,gold), '振奋击鼓鼓槌与闪光'),
        (horn(jade)+O('drum',47,67,.55,red)+allies(gold)+O('flag',26,24,.27,gold), '鼓舞三军的军号、战鼓与友军'),
      ],
      'economy':[
        (tent()+O('coin',76,69,.31,gold), '营帐规划节省升阶费用'),
        (O('ingot',47,52,.87,gold)+O('sword',77,27,.39,blue), '聚财金锭与击杀剑锋'),
        (O('eye',48,39,.72,jade)+O('scroll',48,70,.55,cream), '远谋地图与侦察目光'),
        (O('pouch',42,53,.8,wood)+O('lord_crown',74,26,.35,gold), '军资钱袋与精英冠印'),
        (chest()+O('tiger',48,24,.33,gold), '攻城赏金宝箱上的猛虎徽'),
        (O('scroll',48,45,.85,cream)+p('M22 68 H71 M29 65 V79 M46 65 V79 M63 65 V79','none',wood,4), '筹算账册与拨算架'),
        (O('drum',46,50,.86,red)+O('flag',77,26,.37,gold), '后援战鼓与补给旗'),
        (O('book',40,54,.72,cream)+O('fan',72,29,.42,jade), '机谋军师兵书与羽扇'),
        (O('catapult',44,55,.8,wood)+O('coin',75,29,.35,gold)+O('scroll',79,72,.29,cream), '勤俭维修战车与用度账册'),
        (chest(gold)+O('lord_crown',48,20,.37,jade)+O('flag',79,60,.27,red)+O('scroll',21,65,.3,cream), '筹谋天下的冠印钱箱与军政卷册'),
      ],
    }
    root=draw['ROOT']; records=[]
    for tree_id,artworks in recipes.items():
        text=(root/'resources/talents'/f'{tree_id}.tres').read_text(encoding='utf-8')
        nodes=json.loads(text.split('nodes = Array[Dictionary](',1)[1].rsplit(')',1)[0])
        assert len(nodes)==len(artworks)==10
        for node,(shape,meaning) in zip(nodes,artworks):
            key='talent_'+str(node['id']).replace('.','_')
            records.append(dict(id=key,label=node['name'],category='talent',description=meaning+'；'+node['description'],planned=False,svg_body=g(shape,'translate(4 4) scale(.92)')))
    assert len(records)==110 and len({r['svg_body'] for r in records})==110
    return records


def hourglass_scaled(x,y,scale,recipe,group):
    return group(recipe(),f'translate({x-48*scale} {y-48*scale}) scale({scale})')


def create_talent_previews(records,base,root,fontpath,write_image):
    from PIL import Image,ImageDraw,ImageFont
    icons=[r for r in records if r['category']=='talent']
    font=ImageFont.truetype(str(fontpath),16)
    sheet=Image.new('RGB',(1400,1660),'#edf6fb');pen=ImageDraw.Draw(sheet)
    pen.text((24,20),'天赋节点专属图徽 · 11类 / 110枚',font=ImageFont.truetype(str(fontpath),28),fill='#1b4d78')
    for index,icon in enumerate(icons):
        x=(index%10)*140;y=(index//10)*142+65
        pen.rounded_rectangle((x+5,y+4,x+134,y+137),10,fill='#ffffff',outline='#c6dfe9')
        source=Image.open(base/icon['png']).convert('RGBA')
        thumb=source.resize((82,82),Image.Resampling.LANCZOS);sheet.paste(thumb,(x+28,y+8),thumb)
        pen.text((x+12,y+96),icon['label'],font=font,fill='#1b4d78')
        tiny=source.resize((32,32),Image.Resampling.LANCZOS);sheet.paste(tiny,(x+96,y+95),tiny)
    write_image(sheet,root/'docs/ui_concept/talent_icons_preview.png')
    proof=Image.new('RGB',(1460,2820),'#edf6fb');pen=ImageDraw.Draw(proof)
    pen.text((20,14),'110枚天赋图徽 · 24 / 34 / 40 / 56px · 亮暗底',font=ImageFont.truetype(str(fontpath),26),fill='#1b4d78')
    for index,icon in enumerate(icons):
        column=index%4;row=index//4;x=column*365;y=55+row*98
        pen.text((x+4,y+2),icon['label'],font=font,fill='#1b4d78')
        source=Image.open(base/icon['png']).convert('RGBA')
        for dark,bx in [(False,x+10),(True,x+183)]:
            pen.rounded_rectangle((bx,y+26,bx+168,y+87),5,fill='#183b4b' if dark else '#fff')
            cursor=bx+3
            for pixels in [24,34,40,56]:
                # The 56px specimen is placed above the baseline to remain entirely visible.
                thumb=source.resize((pixels,pixels),Image.Resampling.LANCZOS)
                proof.paste(thumb,(cursor,y+86-pixels),thumb);cursor+=pixels+2
    write_image(proof,root/'docs/ui_concept/talent_icons_sizes.png')

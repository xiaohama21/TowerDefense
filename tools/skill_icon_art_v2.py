"""Original miniature character/action compositions for the current 27 skills.

All coordinates use the existing 96px transparent SVG canvas (ICONS v1.4).
No gameplay logic or bitmap references are part of these artwork recipes.
"""

def build_skill_art(draw):
    p,c,g,star = (draw[key] for key in ('path','circle','group','star'))
    ink,gold,jade,blue,red,violet,cream,wood = (draw[key] for key in ('INK','GOLD','JADE','BLUE','RED','VIOLET','CREAM','WOOD'))
    skin='#ffe0ad'
    roles={
        'guan_yu': (jade,'#286851','long_beard'), 'zhang_fei':(red,'#704132','black_beard'),
        'liu_bei':(jade,gold,'crown'), 'huang_zhong':(gold,wood,'white_beard'),
        'diao_chan':(violet,red,'buns'), 'huang_fu_song':(red,wood,'general'),
        'zhao_yun':('#e5f1f4',blue,'plume'), 'zhou_wei':(violet,'#586871','soldier'),
        'zhuge_liang':(jade,violet,'scholar')}
    # Head, right arm, left arm, legs: the pose is visible without its effect symbols.
    poses={
        'guard':((38,25),[(46,40),(55,47),(61,54)],[(29,40),(23,50),(31,58)],[(34,64),(26,81)],[(43,64),(55,81)]),
        'drink':((40,28),[(48,43),(61,56),(66,60)],[(31,43),(24,36),(27,30)],[(36,66),(28,82)],[(45,66),(56,81)]),
        'thrust':((36,28),[(45,43),(55,48),(60,45)],[(28,43),(38,53),(49,51)],[(32,65),(20,81)],[(42,65),(61,79)]),
        'slash':((39,27),[(47,42),(52,35),(58,38)],[(30,42),(23,50),(15,55)],[(34,65),(21,82)],[(43,65),(62,79)]),
        'raise':((40,28),[(48,43),(56,40),(60,43)],[(31,43),(24,34),(22,27)],[(36,66),(28,82)],[(45,66),(56,81)]),
        'shout':((42,27),[(51,42),(63,36),(69,42)],[(33,42),(23,42),(15,34)],[(37,65),(24,81)],[(47,65),(60,81)]),
        'shoot':((31,26),[(40,41),(51,43),(60,44)],[(22,41),(36,36),(41,42)],[(28,64),(20,82)],[(36,64),(47,81)]),
        'crouch':((34,35),[(43,50),(54,51),(61,55)],[(25,50),(36,44),(43,48)],[(29,70),(19,82)],[(40,69),(55,74),(47,84)]),
        'open':((41,26),[(50,41),(63,43),(73,36)],[(32,41),(20,46),(13,39)],[(37,64),(29,81)],[(46,64),(57,81)]),
        'dance':((40,22),[(49,37),(58,26),(64,22)],[(31,37),(21,45),(15,52)],[(36,61),(28,79)],[(45,62),(57,71),(49,81)]),
        'kneel':((40,34),[(49,49),(53,39),(59,33)],[(31,49),(31,36),(38,28)],[(36,70),(27,82)],[(45,70),(61,82)]),
        'cast':((35,27),[(44,42),(54,44),(62,38)],[(26,42),(17,33),(11,29)],[(31,65),(24,81)],[(40,65),(50,81)]),
        'command':((28,28),[(37,43),(47,35),(57,32)],[(19,43),(18,55),(25,57)],[(24,66),(19,83)],[(33,66),(44,83)]),
        'dash':((35,30),[(44,45),(55,47),(60,45)],[(26,45),(21,58),(12,61)],[(31,67),(15,82)],[(40,67),(60,76)]),
    }

    def line(points,color,width=5):
        d='M'+' L'.join(f'{x} {y}' for x,y in points)
        return p(d,'none',ink,width+3)+p(d,'none',color,width)

    def little(x,y,color=blue,fallen=False):
        shape=c(x,y,4,skin,ink,2)+p(f'M{x-5} {y+6} Q{x} {y+2} {x+5} {y+6} L{x+7} {y+18} H{x-7} Z',color,ink,2)
        return g(shape,f'rotate(55 {x} {y})') if fallen else shape

    def hero(role,pose):
        (x,y),right,left,leg_a,leg_b=poses[pose]
        cloth,trim,hat=roles[role]
        # A flowing cape behind the legs emphasizes direction and separates the body.
        cape=p(f'M{x-8} {y+14} Q{x-23} {y+30} {x-18} {y+49} L{x-3} {y+39} Z',trim,ink,2.8)
        body=p(f'M{x-9} {y+13} Q{x} {y+9} {x+9} {y+13} L{x+11} {y+37} Q{x} {y+42} {x-11} {y+37} Z',cloth,ink,3)
        belt=p(f'M{x-8} {y+29} H{x+9}','none',trim,4)
        arms=line(right,cloth)+line(left,cloth)
        legs=line(leg_a,trim,5)+line(leg_b,trim,5)
        hands=c(*right[-1],3,skin,ink,1.8)+c(*left[-1],3,skin,ink,1.8)
        face=c(x,y,9,skin,ink,3)
        eyes=c(x+3,y+1,1.25,ink,ink,0)
        if hat=='long_beard':
            hair=p(f'M{x-9} {y-2} Q{x-9} {y-13} {x} {y-11} Q{x+10} {y-12} {x+9} {y-3} Z',trim,ink,2.5)
            hair+=p(f'M{x-5} {y+4} Q{x} {y+10} {x+5} {y+4} L{x+2} {y+24} L{x-3} {y+19} Z',ink,ink,1.5)
        elif hat=='black_beard':
            hair=p(f'M{x-10} {y-3} L{x-7} {y-12} L{x-2} {y-9} L{x+3} {y-12} L{x+9} {y-4}',ink,ink,2)
            hair+=p(f'M{x-8} {y+3} L{x-4} {y+14} L{x} {y+11} L{x+5} {y+14} L{x+8} {y+4}',ink,ink,2)
            hair+=c(x+2,y+7,2.3,red,ink,1)
        elif hat=='crown':
            hair=p(f'M{x-9} {y-5} L{x-10} {y-12} L{x-4} {y-9} L{x} {y-15} L{x+4} {y-9} L{x+9} {y-12} L{x+8} {y-5} Z',gold,ink,2.5)
            hair+=p(f'M{x-3} {y+6} L{x+1} {y+13} L{x+4} {y+6}',ink,ink,1.5)
        elif hat=='white_beard':
            hair=p(f'M{x-10} {y-4} Q{x-9} {y-13} {x} {y-13} Q{x+9} {y-12} {x+10} {y-4} Z',wood,ink,2.5)
            hair+=p(f'M{x-6} {y+5} Q{x} {y+11} {x+6} {y+5} L{x+1} {y+19} Z',cream,ink,2)
            hair+=p(f'M{x+3} {y-12} Q{x+9} {y-23} {x+12} {y-17}','none',cream,3)
        elif hat=='buns':
            hair=p(f'M{x-9} {y-2} Q{x-7} {y-14} {x+4} {y-10} Q{x+10} {y-6} {x+8} {y-1} Q{x} {y-4} {x-9} {y-2}',ink,ink,2)
            hair+=c(x-9,y-8,4,ink,ink,2)+c(x+9,y-8,4,ink,ink,2)+c(x+8,y-7,2,gold,ink,1)
            body=p(f'M{x-8} {y+13} Q{x} {y+9} {x+8} {y+13} L{x+14} {y+40} Q{x} {y+46} {x-14} {y+40} Z',cloth,ink,3)
        elif hat in ('general','soldier','plume'):
            helmet=wood if hat=='general' else (blue if hat=='plume' else '#667a81')
            hair=p(f'M{x-10} {y-2} Q{x-11} {y-12} {x} {y-13} Q{x+11} {y-12} {x+10} {y-2} L{x+6} {y-5} H{x-6} Z',helmet,ink,2.5)
            plume=red if hat=='general' else (cream if hat=='plume' else violet)
            hair+=p(f'M{x} {y-12} Q{x-1} {y-22} {x+11} {y-18} L{x+6} {y-12} Z',plume,ink,2)
        else:
            hair=p(f'M{x-10} {y-4} L{x-8} {y-14} L{x-2} {y-11} L{x+3} {y-15} L{x+9} {y-5} Z',ink,ink,2)
            hair+=p(f'M{x-5} {y+6} L{x} {y+17} L{x+5} {y+6}',ink,ink,1.5)
            hair+=p(f'M{x-6} {y-11} L{x+3} {y-9}','none',cream,2)
        return cape+legs+body+belt+arms+face+eyes+hair+hands

    def weapon(kind,hand,angle=0,scale=.7,color=blue):
        if kind in ('spear','glaive'):
            shape=line([(0,6),(0,-52)],wood,4)
            if kind=='spear': shape+=p('M0 -66 L-7 -49 L0 -40 L7 -49 Z',color,ink,3)
            else: shape+=p('M0 -62 Q23 -57 13 -32 L0 -38 Z',jade,ink,3)+p('M4 -51 Q13 -47 8 -39','none',gold,3)
            shape+=p('M-3 -43 Q-15 -44 -13 -32 L-3 -35 Z',red,ink,2)
        elif kind=='sword':
            shape=line([(0,4),(0,-13)],wood,5)+p('M-4 -14 L-5 -48 L0 -62 L5 -48 L4 -14 Z',color,ink,3)
            shape+=line([(-8,-13),(8,-13)],gold,3)+p('M0 -23 V-43','none',cream,2)
        elif kind=='bow':
            shape=p('M-3 -26 Q26 0 -3 26','none',ink,8)+p('M-3 -26 Q26 0 -3 26','none',wood,5)
            shape+=p('M-3 -26 L-14 0 L-3 26','none',cream,2)+line([(-23,0),(24,0)],color,2.8)+p('M16 -6 L26 0 L16 6',color,ink,2)
        elif kind=='fan':
            shape=p('M0 3 L-21 -24 Q0 -43 21 -24 Z',cream,ink,3)+p('M0 2 L-13 -24 M0 2 V-30 M0 2 L13 -24','none',jade,3)
            shape+=line([(0,0),(0,8)],wood,4)
        elif kind=='cup':
            shape=p('M-9 -9 H9 L6 3 Q0 9 -6 3 Z',gold,ink,2.5)+p('M-3 -13 Q-9 -19 -3 -25','none',cream,2.5)
        elif kind=='bell':
            shape=p('M-8 -5 Q-5 -10 -5 -16 Q0 -24 5 -16 Q5 -10 8 -5 Z',gold,ink,2.5)+c(0,0,3,gold,ink,2)
        else:
            shape=line([(0,5),(0,-45)],wood,4)+star(0,-44,10,color,4)
        return g(shape,f'translate({hand[0]} {hand[1]}) rotate({angle}) scale({scale})')

    def icon(role,pose,kind='sword',hand=None,angle=0,scale=.7,back='',front='',color=blue):
        hand=hand or poses[pose][1][-1]
        return back+hero(role,pose)+weapon(kind,hand,angle,scale,color)+front

    def armor_target(x,y):
        return p(f'M{x-7} {y-7} L{x} {y-10} L{x+7} {y-7} V{y+4} L{x} {y+10} L{x-7} {y+4} Z',blue,ink,2)+p(f'M{x+1} {y-7} L{x-3} {y} L{x+3} {y+3} L{x-1} {y+9}','none',red,3)

    def siege(x=52,y=39,scale=.53):
        return g(draw['catapult'](wood),f'translate({x} {y}) scale({scale})')

    def mist(d,color=blue,width=4): return p(d,'none',color,width)
    def blaze(x,y,scale=.35): return g(draw['flame'](red),f'translate({x} {y}) scale({scale})')
    def moon(x,y,scale=.38): return g(draw['moon'](cream),f'translate({x} {y}) scale({scale})')
    rows={}
    def add(key,label,shape,meaning): rows[key]={'label':label,'svg_body':shape,'description':meaning,'planned':False}

    add('passive_green_dragon_stance','青龙势',icon('guan_yu','guard','glaive',(63,70),-10,.82,
        back=mist('M10 35 Q24 20 31 22',jade,5),front=star(78,25,10,gold,4)+mist('M72 47 L82 40 M71 55 L82 48',gold,3)), '关羽持偃月刀蓄势；锁定同一目标与周期暴击闪光')
    add('passive_warm_wine','温酒',icon('guan_yu','drink','glaive',(66,75),0,.75,
        back=mist('M8 64 H22 M12 74 H24',gold,4),front=weapon('cup',(27,30),-10,.8)), '关羽举盏持刀；大招最后一击后攻速加快')
    add('char_green_dragon','青龙偃月',icon('guan_yu','slash','glaive',(58,39),48,.69,
        back=p('M13 33 Q39 5 85 17 Q54 17 30 46 Z',jade,ink,3),
        front=mist('M19 54 Q44 24 82 32 M24 65 Q51 37 84 44',jade,4)), '关羽跨步连续挥刀；青色斩弧与真实连斩')

    add('trait_yanyan_roar','燕人咆哮',icon('zhang_fei','shout','spear',(70,76),-3,.68,
        back=mist('M61 18 Q78 28 68 38 M72 13 Q90 28 78 42',gold,4),front=little(78,60,'#9fa9a7')+mist('M86 57 L91 52 M86 67 L91 62',red,3)), '张飞持蛇矛吼叫；命中追加伤害与恐惧后退')
    add('passive_yanhan','燕颔',icon('zhang_fei','guard','spear',(65,75),-5,.75,
        back=blaze(1,29,.32),front=little(25,68,'#9fa9a7',True)+mist('M14 53 V42 M9 47 L14 41 L19 47',gold,3)), '张飞持矛昂首；击杀敌影后怒气升起')
    add('char_dangyang_roar','当阳桥',icon('zhang_fei','shout','spear',(71,75),-5,.72,
        back=p('M12 74 Q48 56 84 74 V84 Q48 68 12 84 Z',wood,ink,3)+mist('M12 89 Q22 83 32 89 T55 89 T80 89',blue,3),
        front=mist('M59 17 Q81 26 69 40 M68 10 Q93 28 81 47',red,4)+little(80,52,'#9fa9a7')), '张飞桥上怒吼；环形声波与后退敌影')

    add('trait_benevolence','仁德',icon('liu_bei','open','sword',(14,62),-18,.55,
        back=mist('M10 64 Q40 35 85 64',jade,5),front=little(16,64,blue)+little(78,63,gold)+mist('M16 59 V50 M12 54 L16 49 L20 54 M78 58 V48',jade,3)), '刘备持剑张臂护友；友方基础攻击光环')
    add('passive_diligence','砥砺',icon('liu_bei','raise','sword',(60,43),42,.65,
        back=mist('M13 70 Q39 45 77 62',gold,4),front=little(76,65,blue)+star(76,25,10,gold,4)), '刘备举剑引导友军；暴击率闪光')
    add('char_carry_people','携民渡江',icon('liu_bei','guard','sword',(63,65),15,.62,
        back=little(77,50,blue),front=p('M10 70 H86 L72 84 H25 Z',wood,ink,3)+mist('M10 90 Q25 84 40 89 T84 89 M64 23 H82 M67 32 H87',blue,3)), '刘备舟上护送友军；攻速流线与渡江动作')

    add('trait_hundred_step','百步穿杨',icon('huang_zhong','shoot','bow',(61,44),0,.77,
        back=mist('M53 18 L78 23 M55 26 L82 30',gold,3),front=c(83,46,8,'none',gold,3)+mist('M83 34 V38 M83 55 V59',red,2)), '黄忠拉弓瞄准同一目标；箭线集中并累计增伤')
    add('passive_sentry','哨戒',icon('huang_zhong','crouch','bow',(62,55),0,.75,
        back=mist('M11 76 H25',jade,4),front=p('M83 60 Q92 71 83 76 Q74 71 83 60 Z',jade,ink,2)+c(75,79,2,jade,ink,1),color=jade), '黄忠蹲守放毒箭；命中持续中毒')
    add('char_dingjun','定军山',icon('huang_zhong','shoot','bow',(61,44),-28,.78,
        back=p('M9 81 L19 43 L34 65 L66 16 L86 80 Z',jade,ink,3)+mist('M13 75 Q47 50 83 76',gold,5),
        front=star(80,24,9,gold,4)+armor_target(77,68)), '黄忠山前扬弓；易伤与自身攻速/攻击/暴击增幅')

    add('trait_moon_veil','月华',icon('diao_chan','open','bell',(73,36),0,.73,
        back=moon(2,0,.4),front=mist('M14 61 Q44 80 79 57',violet,5)+little(15,64,blue)+little(78,65,jade)+c(16,58,3,gold,ink,1.5)+c(78,59,3,gold,ink,1.5)), '貂蝉持铃舒袖；月光覆盖友方怒气')
    add('passive_worship_moon','拜月',icon('diao_chan','kneel','fan',(59,34),20,.66,
        back=moon(59,0,.35),front=p('M12 85 V77 H24 V68 H35 V60','none',gold,4)+mist('M67 48 Q78 60 75 76',violet,4)), '貂蝉跪姿举扇拜月；局内阶数门槛后的技能增幅')
    add('char_moon_dance','凤仪鼓舞',icon('diao_chan','dance','fan',(64,25),25,.60,
        back=p('M14 21 Q34 6 67 10 L85 24 Q63 18 47 36 L30 31 Z',red,ink,2.5),
        front=mist('M12 62 Q32 81 79 51 M22 46 Q52 83 85 63',red,4)+little(15,69,blue)+little(80,70,jade)+mist('M8 50 V41 M84 44 V34',gold,3)), '貂蝉旋舞挥扇；凤形长袖与全队攻速节奏')

    add('passive_fierce_flame','烈焰',icon('huang_fu_song','command','sword',(57,34),48,.47,
        back=siege(48,38,.51)+mist('M47 21 Q85 14 87 50',red,4),front=blaze(63,0,.30)), '皇甫嵩执令指挥投石机；攻击/射程/溅射常驻扩大')
    add('passive_detonation','爆燃',icon('huang_fu_song','raise','sword',(60,43),48,.47,
        back=star(72,50,21,red,7)+siege(47,40,.48),front=blaze(60,26,.30)+little(77,70,'#9fa9a7',True)), '皇甫嵩挥令；被灼烧敌人死亡位置的范围爆炸')
    add('char_burn_camp','长社焚营',icon('huang_fu_song','cast','sword',(62,38),45,.45,
        back=siege(44,42,.52)+mist('M41 15 Q77 2 86 42',gold,4),
        front=blaze(65,26,.29)+p('M65 81 L77 62 L90 81 Z',wood,ink,2.5)+blaze(65,58,.25)), '皇甫嵩指挥抛石；火石飞弧轰击燃营并持续灼烧')

    add('trait_dragon_spirit','龙魂',icon('zhao_yun','thrust','spear',(60,45),74,.46,
        back=mist('M15 29 Q11 11 30 10 Q48 6 60 17 Q72 29 82 16',jade,4),front=armor_target(77,65)+star(80,24,8,gold,4)), '赵云挺枪破甲；龙形流光与暴击伤害')
    add('passive_dragon_courage','龙胆',icon('zhao_yun','guard','spear',(65,75),-7,.78,
        back=mist('M12 53 Q17 30 29 32',blue,5),front=star(79,22,11,gold,4)), '赵云白甲持枪蓄势；暴击率闪光')
    add('char_seven_charges','七进七出',icon('zhao_yun','dash','spear',(60,45),74,.46,
        back=g(hero('zhao_yun','dash'),'translate(-4 -1) scale(.9)') .replace('<g ', '<g opacity=".28" ',1)+mist('M8 29 H21 M6 41 H16 M8 54 H19',blue,4),
        front=little(78,66,'#9fa9a7')+little(63,72,'#9fa9a7')+star(85,36,7,gold,4)), '赵云前冲挺枪；速度残影与多个低血目标')

    add('trait_vanguard','陷阵',icon('zhou_wei','thrust','sword',(60,45),73,.52,
        back=mist('M13 51 H26',violet,4),front=armor_target(80,52)), '周卫挺刃刺破敌甲；常驻穿甲')
    add('char_death_fight','死战',icon('zhou_wei','slash','sword',(58,38),44,.66,
        back=mist('M17 31 Q39 9 77 18',red,4),front=star(79,51,12,red,4)+mist('M58 59 L81 39',gold,3),color=red), '周卫举刀重斩；命中后概率追加高额物理伤害')
    add('ultimate_death_fight','麦城死战',icon('zhou_wei','slash','sword',(58,38),46,.65,
        back=g(draw['gate'](wood),'translate(26 30) scale(.63)')+mist('M69 47 L62 60 L73 68 L66 82',red,3),
        front=p('M13 60 Q38 23 85 35 Q60 40 32 75 Z',red,ink,2.5)+mist('M27 80 Q51 49 87 54',gold,3),color=red), '周卫残门前奋力重斩；基地低血时加强的麦城死战')

    add('trait_star_gazer','观星',icon('zhuge_liang','cast','fan',(62,38),18,.67,
        back=star(75,17,9,gold,4)+mist('M18 18 L28 11 L46 15',blue,2)+c(18,18,2,gold,ink,1)+c(28,11,2,gold,ink,1),
        front=little(78,64,'#9fa9a7')+mist('M64 68 Q78 55 91 68',blue,4)), '诸葛亮举扇观星；扩大射程并持续减速')
    add('passive_momentum','乘势',icon('zhuge_liang','raise','fan',(60,43),-15,.68,
        back=little(76,16,'#9fa9a7')+little(82,57,'#9fa9a7')+mist('M70 36 Q63 44 64 47 M78 61 Q62 57 66 43 M15 70 Q35 82 59 65',violet,4),
        front=star(74,44,7,gold,4)), '诸葛亮挥扇聚势；受控敌影汇聚为本次技能增幅')
    add('char_borrow_wind','借东风',icon('zhuge_liang','dance','fan',(64,25),32,.60,
        back=mist('M10 18 Q36 4 82 15 M11 55 Q59 26 87 41 M14 73 Q49 48 87 62',blue,5),
        front=g(draw['eye'](jade),'translate(63 68) scale(.27)')+mist('M20 87 Q58 70 88 78',blue,4)), '诸葛亮转身挥扇；全场风流造成魔法伤害并使隐匿现形')
    assert len(rows)==27
    return rows


SKILL_GROUPS=[
    ('关羽',['passive_green_dragon_stance','passive_warm_wine','char_green_dragon']),
    ('张飞',['trait_yanyan_roar','passive_yanhan','char_dangyang_roar']),
    ('刘备',['trait_benevolence','passive_diligence','char_carry_people']),
    ('黄忠',['trait_hundred_step','passive_sentry','char_dingjun']),
    ('貂蝉',['trait_moon_veil','passive_worship_moon','char_moon_dance']),
    ('皇甫嵩',['passive_fierce_flame','passive_detonation','char_burn_camp']),
    ('赵云',['trait_dragon_spirit','passive_dragon_courage','char_seven_charges']),
    ('周卫',['trait_vanguard','char_death_fight','ultimate_death_fight']),
    ('诸葛亮',['trait_star_gazer','passive_momentum','char_borrow_wind']),
]


def create_skill_previews(records,base,root,fontpath,save_image):
    from PIL import Image,ImageDraw,ImageFont
    fonts={size:ImageFont.truetype(str(fontpath),size) for size in [12,15,18,24,28]}
    icons={entry['id']:entry for entry in records}
    preview=Image.new('RGB',(1200,684),'#11271f');pen=ImageDraw.Draw(preview)
    pen.text((20,14),'九将 · 27技能 / 人物、器物与动作',font=fonts[28],fill='#fff0c6')
    sheet=Image.new('RGB',(1280,1260),'#11271f');detail=ImageDraw.Draw(sheet)
    detail.text((20,16),'技能图徽 · 亮暗底与实际尺寸（56 / 38 / 20px）',font=fonts[28],fill='#fff0c6')
    for index,(character,keys) in enumerate(SKILL_GROUPS):
        x=(index%3)*400;y=(index//3)*210+54
        pen.rounded_rectangle((x+8,y,x+390,y+198),10,fill='#f4f2e7')
        pen.text((x+20,y+10),character,font=fonts[18],fill='#243b36')
        row_y=68+index*130
        detail.text((20,row_y+40),character,font=fonts[18],fill='#fff0c6')
        for slot,key in enumerate(keys):
            entry=icons[key];source=Image.open(base/entry['png']).convert('RGBA')
            thumb=source.resize((88,88),Image.Resampling.LANCZOS)
            preview.paste(thumb,(x+22+slot*122,y+42),thumb)
            pen.text((x+17+slot*122,y+138),entry['label'],font=fonts[15],fill='#243b36')
            pen.text((x+17+slot*122,y+167),'被动Ⅰ' if slot==0 else '被动Ⅱ' if slot==1 else '大招',font=fonts[12],fill='#597069')
            cell_x=120+slot*384
            detail.rounded_rectangle((cell_x,row_y,cell_x+370,row_y+122),8,fill='#274334')
            detail.text((cell_x+10,row_y+5),entry['label'],font=fonts[18],fill='#fff0c6')
            detail.rounded_rectangle((cell_x+8,row_y+35,cell_x+183,row_y+114),5,fill='#f4f2e7')
            for start in [cell_x+10,cell_x+193]:
                for pixels,offset in [(56,4),(38,68),(20,118)]:
                    thumb=source.resize((pixels,pixels),Image.Resampling.LANCZOS)
                    sheet.paste(thumb,(start+offset,row_y+44+(56-pixels)//2),thumb)
    save_image(preview,root/'docs/ui_concept/skill_icons_v2_preview.png')
    save_image(sheet,root/'docs/ui_concept/skill_icons_v2.png')

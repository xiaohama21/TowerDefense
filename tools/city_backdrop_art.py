"""Layered original SVG landscape for the fixed nine-building city.

The public ``backdrop(c)`` returns a 1280x720 SVG body.  Geometry remains
deterministic; the day/dusk colour dictionary controls all materials.
"""
import math
import random


def _rgb(value):
    value = value.lstrip('#')
    return tuple(int(value[i:i+2], 16) for i in (0, 2, 4))


def _mix(a, b, t):
    return '#' + ''.join(f'{round(x * (1-t) + y * t):02x}' for x, y in zip(_rgb(a), _rgb(b)))


def _pine(x, y, height, seed, dark, mid, light, wood, opacity=1):
    """Asymmetric tiered pine with lit foliage and branching rather than disks."""
    rng = random.Random(seed)
    w = height * .29
    s = [f'<g opacity="{opacity:.3f}">',
         f'<ellipse cx="{x+height*.15:.1f}" cy="{y+2:.1f}" rx="{w*1.35:.1f}" ry="{height*.065:.1f}" fill="{dark}" opacity=".35"/>',
         f'<path d="M{x-2:.1f} {y:.1f}L{x-1.3:.1f} {y-height*.76:.1f}L{x+1:.1f} {y-height*.86:.1f}L{x+3:.1f} {y:.1f}Z" fill="{wood}"/>']
    for tier in range(6):
        top = y-height+(tier*.12*height)
        spread = w * (.26+tier*.15)
        bottom = top+height*(.30 if tier < 4 else .25)
        asym = rng.uniform(-.1, .1) * spread
        pts = [(x+asym, top), (x-spread*.32, top+height*.10),
               (x-spread*.26, top+height*.13), (x-spread*.78, top+height*.20),
               (x-spread*.58, top+height*.22), (x-spread, bottom),
               (x-spread*.37, bottom-height*.025), (x-spread*.18, bottom+height*.025),
               (x+spread*.3, bottom-height*.015), (x+spread*.79, bottom+height*.015),
               (x+spread*.66, top+height*.22), (x+spread, top+height*.20),
               (x+spread*.44, top+height*.11), (x+spread*.51, top+height*.095)]
        s.append(f'<polygon points="{" ".join(f"{px:.1f},{py:.1f}" for px,py in pts)}" fill="{mid if tier%2 else dark}"/>')
        s.append(f'<path d="M{x+asym:.1f} {top+height*.02:.1f}L{x-spread*.42:.1f} {top+height*.155:.1f}L{x-spread*.18:.1f} {top+height*.147:.1f}L{x-spread*.68:.1f} {top+height*.25:.1f}L{x-spread*.13:.1f} {top+height*.227:.1f}L{x:.1f} {top+height*.30:.1f}Z" fill="{light}" opacity=".45"/>')
        s.append(f'<path d="M{x-spread*.59:.1f} {bottom-height*.03:.1f}L{x-spread*.18:.1f} {bottom-height*.085:.1f}M{x+spread*.13:.1f} {bottom-height*.022:.1f}L{x+spread*.42:.1f} {bottom-height*.059:.1f}" stroke="{light}" stroke-width=".8" opacity=".4"/>')
    s.append('</g>')
    return ''.join(s)


def _rock(x, y, w, dark, mid, light):
    h = w*.42
    return (f'<ellipse cx="{x+w*.08:.1f}" cy="{y+1:.1f}" rx="{w*.62:.1f}" ry="{h*.35:.1f}" fill="{dark}" opacity=".35"/>'
            f'<path d="M{x-w*.5:.1f} {y:.1f}L{x-w*.39:.1f} {y-h*.65:.1f}L{x-w*.07:.1f} {y-h:.1f}L{x+w*.28:.1f} {y-h*.84:.1f}L{x+w*.52:.1f} {y-h*.29:.1f}L{x+w*.41:.1f} {y:.1f}Z" fill="{mid}"/>'
            f'<path d="M{x-w*.39:.1f} {y-h*.65:.1f}L{x-w*.07:.1f} {y-h:.1f}L{x+w*.28:.1f} {y-h*.84:.1f}L{x+w*.02:.1f} {y-h*.46:.1f}L{x-w*.23:.1f} {y-h*.34:.1f}Z" fill="{light}"/>'
            f'<path d="M{x+w*.02:.1f} {y-h*.46:.1f}L{x+w*.28:.1f} {y-h*.84:.1f}L{x+w*.52:.1f} {y-h*.29:.1f}L{x+w*.41:.1f} {y:.1f}L{x+w*.12:.1f} {y-h*.10:.1f}Z" fill="{dark}" opacity=".6"/>')


def _shrub(x, y, w, seed, dark, mid, light):
    rng=random.Random(seed)
    s=[f'<ellipse cx="{x+3:.1f}" cy="{y+2:.1f}" rx="{w*.58:.1f}" ry="{w*.12:.1f}" fill="{dark}" opacity=".3"/>']
    # Individual interlocking, lobed sprays form irregular low foliage masses.
    for j in range(5):
        cx=x+(j-2)*w*.17+rng.uniform(-2,2)
        cy=y-rng.uniform(w*.12,w*.3)
        ww=w*rng.uniform(.19,.32);hh=ww*.68
        s.append(f'<path d="M{cx-ww:.1f} {cy+hh:.1f}Q{cx-ww*1.4:.1f} {cy:.1f} {cx-ww*.65:.1f} {cy-hh*.4:.1f}Q{cx-ww*.7:.1f} {cy-hh*1.4:.1f} {cx:.1f} {cy-hh:.1f}Q{cx+ww*.4:.1f} {cy-hh*1.45:.1f} {cx+ww*.66:.1f} {cy-hh*.4:.1f}Q{cx+ww*1.5:.1f} {cy:.1f} {cx+ww:.1f} {cy+hh:.1f}Z" fill="{mid if j%2 else dark}"/>')
        for k in range(5):
            lx=cx+rng.uniform(-ww*.7,ww*.5);ly=cy+rng.uniform(-hh*.75,hh*.25)
            s.append(f'<path d="M{lx:.1f} {ly:.1f}q-3 -3 -5 -1q2 3 5 1M{lx+2:.1f} {ly+2:.1f}q1 -4 4 -4q0 4 -4 4" fill="{light}" opacity=".5"/>')
    return ''.join(s)


def _road_outline(points, width, wobble):
    """Sampled road edges retain route centres and gently vary their shoulders."""
    left=[];right=[]
    for i,(x,y,nx,ny) in enumerate(points):
        half=width + math.sin(i*.77+wobble)*1.9+math.sin(i*1.93+wobble)*.7
        left.append((x+nx*half,y+ny*half))
        right.append((x-nx*(half+math.sin(i*.47)*1.8),y-ny*(half+math.sin(i*.47)*1.8)))
    return 'M'+'L'.join(f'{x:.1f} {y:.1f}' for x,y in left+right[::-1])+'Z'


def _torch(x, y, scale, dark, gold, wood):
    return (f'<g transform="translate({x},{y}) scale({scale})">'
            '<ellipse cx="7" cy="3" rx="13" ry="3" fill="#101d1b" opacity=".4"/>'
            f'<ellipse cx="0" cy="-10" rx="33" ry="15" fill="url(#bg_fireglow)"/>'
            f'<path d="M-2 0L-1 -42H2L3 0Z" fill="{wood}" stroke="{dark}" stroke-width="1.2"/>'
            f'<path d="M-6 -39H6L4 -32H-4Z" fill="{dark}"/>'
            f'<path d="M-4 -39Q-7 -47 1 -53Q0 -46 5 -44Q8 -40 3 -37Z" fill="{gold}"/>'
            '<path d="M-1 -39Q-2 -43 2 -46Q1 -41 3 -40L1 -38Z" fill="#fff1b6"/>'
            f'<path d="M-5 -33H5M-3 -25H3" stroke="{gold}" stroke-width="1" opacity=".6"/></g>')


def _flag(x, y, scale, dark, gold, wood, cloth):
    return (f'<g transform="translate({x},{y}) scale({scale})">'
            f'<path d="M-1 0L0 -98" stroke="{dark}" stroke-width="5"/>'
            f'<path d="M-1 -3L-1 -98" stroke="{wood}" stroke-width="2"/>'
            f'<path d="M0 -96L2 -104L4 -96Z" fill="{gold}"/>'
            f'<path d="M1 -91Q18 -99 35 -88L37 -48Q20 -59 2 -48Z" fill="{cloth}" stroke="{dark}" stroke-width="1.3"/>'
            f'<path d="M5 -88Q18 -94 30 -87M5 -54Q19 -60 33 -54" stroke="{gold}" stroke-width="1" opacity=".7"/>'
            f'<path d="M17 -81L26 -73L20 -63L12 -72Z" fill="{gold}" opacity=".7"/>'
            f'<path d="M0 0L-13 3L17 3Z" fill="{dark}" opacity=".5"/></g>')


def _fence(x1, x2, y, dark, wood, light, seed):
    rng=random.Random(seed)
    points=[]
    s=[]
    for i,x in enumerate(range(x1,x2,23)):
        base=y+math.sin(x*.011)*4
        h=rng.uniform(35,48)
        lean=rng.uniform(-3,3)
        w=rng.uniform(6,10)
        points.append((x,base-h*.48))
        s.append(f'<path d="M{x-w/2:.1f} {base:.1f}L{x+lean-w/2:.1f} {base-h+8:.1f}L{x+lean:.1f} {base-h:.1f}L{x+lean+w/2:.1f} {base-h+7:.1f}L{x+w/2:.1f} {base:.1f}Z" fill="{wood}" stroke="{dark}" stroke-width="1.4"/>')
        s.append(f'<path d="M{x+lean-1:.1f} {base-h+8:.1f}L{x-1:.1f} {base-4:.1f}" stroke="{light}" stroke-width="1.2" opacity=".5"/>')
    if len(points)>1:
        for off in [0,13]:
            path='M'+'L'.join(f'{x:.1f} {yy+off:.1f}' for x,yy in points)
            s.append(f'<path d="{path}" fill="none" stroke="{dark}" stroke-width="7"/>')
            s.append(f'<path d="{path}" fill="none" stroke="{wood}" stroke-width="4"/>')
    return ''.join(s)


def backdrop(c):
    sky,ground,dark,roof,light,wall,wood,gold,road=[c[k] for k in ['sky','ground','dark','roof','light','wall','wood','gold','road']]
    day=sum(_rgb(sky))>480
    sky_top=_mix(sky, dark,.13)
    horizon=_mix(sky, '#eebc91',.50 if day else .47)
    mountain_far=_mix(ground,sky,.55)
    mountain_mid=_mix(ground,dark,.28)
    soil=_mix(ground,wall,.13)
    field_light=_mix(ground,light,.2)
    road_top=_mix(road,wood,.22)
    rock=_mix(ground,wall,.26)
    grass_lit=_mix(light,ground,.3)
    s=[f'''<defs>
<linearGradient id="bg_sky" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="215"><stop stop-color="{sky_top}"/><stop offset=".35" stop-color="{sky}"/><stop offset="1" stop-color="{horizon}"/></linearGradient>
<linearGradient id="bg_ground" x1="0" y1="0" x2=".35" y2="1"><stop stop-color="{field_light}"/><stop offset=".5" stop-color="{ground}"/><stop offset="1" stop-color="{_mix(ground,dark,.3)}"/></linearGradient>
<linearGradient id="bg_road" x1="0" y1="0" x2=".3" y2="1"><stop stop-color="{road_top}"/><stop offset="1" stop-color="{_mix(road,ground,.22)}"/></linearGradient>
<radialGradient id="bg_sunset"><stop stop-color="{gold}" stop-opacity=".28"/><stop offset="1" stop-color="{gold}" stop-opacity="0"/></radialGradient>
<radialGradient id="bg_fireglow"><stop stop-color="{gold}" stop-opacity=".36"/><stop offset=".52" stop-color="{gold}" stop-opacity=".11"/><stop offset="1" stop-color="{gold}" stop-opacity="0"/></radialGradient>
<linearGradient id="bg_vignette" x1="0" y1="0" x2="0" y2="1"><stop stop-color="{dark}" stop-opacity="0"/><stop offset=".75" stop-color="{dark}" stop-opacity="0"/><stop offset="1" stop-color="{dark}" stop-opacity=".38"/></linearGradient>
</defs>''',
       '<rect width="1280" height="260" fill="url(#bg_sky)"/>',
       '<ellipse cx="968" cy="110" rx="365" ry="116" fill="url(#bg_sunset)"/>']
    # Uneven mountain peaks, fractured escarpments and warm horizontal haze.
    s.extend([
        f'<path d="M580 94Q740 78 1054 91T1280 86L1280 96Q1053 95 908 96T580 101Z" fill="{horizon}" opacity=".20"/>',
        f'<path d="M712 110Q915 99 1211 108L1280 112V120Q1015 112 712 120Z" fill="{horizon}" opacity=".27"/>',
        f'<path d="M12 141L64 106L98 118L144 81L180 94L224 129L262 100L291 112L340 74L371 99L405 86L468 135L529 114L568 84L594 100L630 67L672 101L710 132L750 111L790 80L813 94L858 52L894 89L921 74L978 122L1022 111L1067 62L1096 87L1118 78L1162 122L1206 99L1247 67L1280 81V205H0Z" fill="{mountain_far}" opacity=".70"/>',
        f'<path d="M144 81L180 94L224 129L209 127L182 111L153 112L133 142L91 166ZM340 74L371 99L405 86L468 135L392 127L369 111L342 99L307 139L277 156ZM630 67L672 101L710 132L661 120L642 100L619 115L580 150ZM858 52L894 89L921 74L978 122L923 110L898 101L883 94L860 76L837 120L806 148ZM1067 62L1096 87L1118 78L1162 122L1121 115L1094 101L1072 90L1042 131L1017 147Z" fill="{_mix(mountain_far,sky,.28)}" opacity=".62"/>',
        f'<path d="M144 83L150 106L138 127M340 77L345 95L333 124M630 70L638 99L624 116M858 55L870 88L857 103M1067 65L1077 90L1069 108M1247 70L1255 94L1245 108" fill="none" stroke="{_mix(mountain_far,horizon,.25)}" stroke-width="1.1" opacity=".42"/>'])
    s.extend([
       f'<path d="M0 180L38 161L62 166L97 134L119 143L151 128L179 149L226 175L270 156L301 131L320 137L350 117L371 133L397 128L458 166L496 149L538 130L575 143L611 112L641 137L669 128L712 167L750 153L790 128L812 139L850 108L878 119L899 110L956 156L1010 139L1046 111L1068 131L1096 118L1143 152L1196 130L1224 144L1257 113L1280 132V270H0Z" fill="{mountain_mid}" opacity=".83"/>',
       f'<path d="M97 134L112 155L133 161L151 128L179 149L205 158L170 161L157 150L141 183L99 188L60 197ZM350 117L371 133L397 128L420 144L392 147L371 141L352 133L333 157L314 178ZM611 112L641 137L669 128L694 151L652 156L635 144L616 133L594 159L559 184ZM850 108L878 119L899 110L919 137L885 145L858 130L834 157L802 185ZM1046 111L1068 131L1096 118L1128 140L1087 150L1053 133L1037 164L1009 176Z" fill="{_mix(mountain_mid,light,.19)}" opacity=".57"/>',
       f'<path d="M0 160Q335 124 631 157T1280 134" fill="none" stroke="{horizon}" stroke-width="7" opacity=".07"/>',
       f'<path d="M100 119Q145 108 184 114M488 97Q529 94 566 103M939 108Q1011 97 1092 109" fill="none" stroke="{horizon}" stroke-width="1.6" opacity=".2"/>'])
    # Distant rocky ridges catch the last amber light above the low forest.
    s.extend([
        f'<path d="M-20 185L44 146L106 94L129 123L178 83L204 139L251 168L311 138L387 42L408 93L454 72L485 137L551 169L613 124L682 52L707 103L744 91L783 155L840 127L908 31L932 86L966 66L1000 137L1052 157L1117 85L1141 117L1202 78L1255 156L1300 183V236H-20Z" fill="{mountain_far}"/>',
        f'<path d="M311 138L387 42L383 101L366 128L401 143L449 168ZM840 127L908 31L901 90L884 119L920 143L962 176ZM44 146L106 94L99 132L127 160ZM1052 157L1117 85L1108 132L1132 165Z" fill="{_mix(horizon,mountain_far,.6)}" opacity=".45"/>',
        f'<path d="M387 42L408 93L394 113L424 150L408 160M908 31L932 86L919 108L945 144L931 161M178 83L172 127L199 147M1202 78L1186 119L1215 158" fill="none" stroke="{mountain_mid}" stroke-width="2" opacity=".38"/>',
        f'<path d="M0 207Q170 161 307 189Q432 150 578 191Q735 158 858 187Q1010 153 1121 193Q1206 169 1280 193V261H0Z" fill="{mountain_mid}" opacity=".7"/>'])
    # Forest silhouette is behind the entire city; shorter trees near rooflines.
    rng=random.Random(171101)
    for x in range(-12,1300,23):
        y=177+math.sin(x*.009)*10+rng.uniform(-5,5)
        h=rng.uniform(22,43)
        s.append(_pine(x,y,h,x+19,dark,mountain_mid,_mix(mountain_mid,light,.2),wood,.54))
    s.append(f'<path d="M0 221Q209 160 415 171Q579 174 734 185Q1014 218 1280 180V720H0Z" fill="url(#bg_ground)"/>')
    # Meadow terraces, shallow banks and sparse earth patches.
    s.extend([
       f'<path d="M0 267Q207 181 380 225Q541 267 702 235Q1019 187 1280 260V297Q1020 246 760 268Q507 306 290 258Q134 237 0 291Z" fill="{light}" opacity=".065"/>',
       f'<path d="M0 374Q244 299 455 345Q737 399 997 326Q1154 289 1280 338V382Q1125 338 1003 369Q738 430 466 393Q211 344 0 415Z" fill="{dark}" opacity=".075"/>',
       f'<path d="M0 567Q234 500 478 550Q687 587 960 538Q1130 512 1280 550V720H0Z" fill="{dark}" opacity=".12"/>',
       f'<path d="M36 363Q105 327 190 354T319 374M484 329Q527 316 577 324M973 274Q1040 252 1105 262M921 622Q1074 590 1145 622" fill="none" stroke="{light}" stroke-width="1.1" opacity=".1"/>'])
    building_rects=[(x-107,y-84,x+107,y+121) for x,y in [(1100,300),(635,205),(374,313),(894,207),(159,482),(1057,510),(795,498),(493,520),(156,232)]]
    def free(x,y):
        return not any(a<x<b and d<y<e for a,d,b,e in building_rects)
    for i in range(135):
        x=rng.uniform(12,1268);y=rng.uniform(224,708)
        w=rng.uniform(10,49);h=rng.uniform(2,8)
        s.append(f'<path d="M{x-w:.1f} {y:.1f}Q{x-w*.7:.1f} {y-h:.1f} {x:.1f} {y-h*.7:.1f}T{x+w:.1f} {y+1:.1f}Q{x+w*.1:.1f} {y+h:.1f} {x-w:.1f} {y:.1f}Z" fill="{soil if i%3 else light}" opacity="{.055 if i%3 else .035}"/>')
    # Existing route geometry stays connected; a textured, softly lit earthen road.
    road_path='M-20 610Q207 624 350 515T629 403Q786 374 1080 421T1300 415M350 515Q302 376 155 320M629 403L635 286M785 416L883 280M479 459L489 594M171 499L281 553'
    s.extend([
       f'<path d="{road_path}" fill="none" stroke="{dark}" stroke-width="65" stroke-linecap="round" opacity=".2" transform="translate(4,6)"/>',
       f'<path d="{road_path}" fill="none" stroke="{_mix(ground,wood,.25)}" stroke-width="59" stroke-linecap="round"/>',
       f'<path d="{road_path}" fill="none" stroke="{light}" stroke-width="51" stroke-linecap="round" opacity=".16"/>',
       f'<path d="{road_path}" fill="none" stroke="url(#bg_road)" stroke-width="45" stroke-linecap="round"/>',
       f'<path d="{road_path}" fill="none" stroke="{wall}" stroke-width="2.4" stroke-linecap="round" opacity=".08" transform="translate(-3,-8)"/>',
       f'<path d="{road_path}" fill="none" stroke="{wood}" stroke-width="2" stroke-linecap="round" opacity=".08" transform="translate(7,7)"/>'])
    # Approximate route samples permit believable gravel and road-edge vegetation.
    segments=[((-20,610),(207,624),(350,515)),((350,515),(493,406),(629,403)),((629,403),(786,374),(1080,421)),((1080,421),(1250,447),(1300,415)),((350,515),(302,376),(155,320)),((629,403),(632,344),(635,286)),((785,416),(834,348),(883,280)),((479,459),(484,528),(489,594)),((171,499),(226,526),(281,553))]
    samples=[]
    for a,b,d in segments:
        for k in range(41):
            t=k/40;v=1-t
            px=v*v*a[0]+2*v*t*b[0]+t*t*d[0]
            py=v*v*a[1]+2*v*t*b[1]+t*t*d[1]
            samples.append((px,py))
            if k % 3 == 0 and rng.random() < .52:
                tx=2*v*(b[0]-a[0])+2*t*(d[0]-b[0])
                ty=2*v*(b[1]-a[1])+2*t*(d[1]-b[1])
                length=max(1,math.hypot(tx,ty));nx=-ty/length;ny=tx/length
                for side in [-1,1]:
                    edge=rng.uniform(20,26)*side
                    ex=px+nx*edge;ey=py+ny*edge
                    if free(ex,ey) and rng.random() < .7:
                        rw=rng.uniform(3,9);rh=rng.uniform(1,2.5)
                        s.append(f'<path d="M{ex-rw:.1f} {ey:.1f}l{rw*.7:.1f} {-rh:.1f} {rw*.9:.1f} {rh*.3:.1f} {rw*.5:.1f} {rh:.1f} {-rw*1.3:.1f} {rh*.4:.1f}Z" fill="{ground}" opacity=".42"/>')
                if k % 6 == 0:
                    s.append(f'<path d="M{px-8:.1f} {py-3:.1f}q8 -3 15 1l-3 3q-7 2 -12 -1Z" fill="{wood}" opacity=".2"/>')
                    s.append(f'<path d="M{px-5:.1f} {py+5:.1f}q5 -2 10 1" stroke="{wall}" stroke-width="1.2" fill="none" opacity=".32"/>')
            if k%2==0:
                for j in range(2):
                    gx=px+rng.uniform(-17,17);gy=py+rng.uniform(-11,11)
                    rx=rng.uniform(.7,2.5);ry=rng.uniform(.35,.9)
                    s.append(f'<ellipse cx="{gx:.1f}" cy="{gy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{wall if j else wood}" opacity=".17"/>')
    for i in range(760):
        x=rng.uniform(0,1280);y=rng.uniform(202,720)
        if not free(x,y) or 637<y<668:
            continue
        distance=min((x-a)**2+(y-b)**2 for a,b in samples)
        if distance<28**2:
            continue
        h=rng.uniform(3,9);w=rng.uniform(3,6)
        s.append(f'<path d="M{x-w:.1f} {y:.1f}Q{x-w*.5:.1f} {y-h*.7:.1f} {x-w*.9:.1f} {y-h*.9:.1f}M{x:.1f} {y+1:.1f}Q{x+1:.1f} {y-h:.1f} {x+4:.1f} {y-h-1:.1f}M{x+2:.1f} {y:.1f}L{x+w+2:.1f} {y-h*.55:.1f}" fill="none" stroke="{grass_lit if i%3 else dark}" stroke-width="{.8 if i%3 else 1.1}" stroke-linecap="round" opacity="{.45 if i%3 else .32}"/>')
    # Framing trees have irregular layered canopies; no canopy sits over an entry.
    for x,y,h,seed in [(20,222,81,30),(263,169,63,48),(465,208,68,70),(757,174,66,82),(1137,175,75,92),(1232,307,89,121),(26,618,80,201),(302,696,70,220),(669,660,69,245),(911,685,77,260),(1208,634,75,274)]:
        s.append(_pine(x,y,h,seed,dark,roof,_mix(light,roof,.25),wood,.9))
    for x,y,w in [(28,248,27),(265,195,16),(445,255,21),(507,297,22),(957,244,20),(1244,326,30),(41,441,16),(308,624,21),(674,585,19),(925,529,21),(1207,563,25),(858,668,19),(390,695,32)]:
        s.append(_rock(x,y,w,_mix(dark,wood,.15),rock,_mix(rock,wall,.2)))
    # Far boundary sections reinforce a fortified camp, without forming a grid.
    for x1,x2,y,seed in [(294,509,186,103),(959,1093,197,104)]:
        s.append(_fence(x1,x2,y,dark,_mix(wood,ground,.2),light,seed))
    # Amber light creates pools of life along the main route, not new UI icons.
    for x,y,scale in [(525,383,.72),(1021,411,.77),(85,603,.7),(703,441,.65),(1240,434,.72)]:
        s.append(_torch(x,y,scale,dark,gold,wood))
    s.append(_flag(21,408,.68,dark,gold,wood,_mix('#874d3e',gold,.12)))
    s.append(_flag(1249,474,.85,dark,gold,wood,_mix('#824735',dark,.2)))
    # Sparse foreground props and broken angled palisades frame a clear entrance.
    s.append(f'<path d="M0 700Q129 667 252 699L275 720H0ZM940 720Q1093 670 1280 690V720Z" fill="{dark}" opacity=".26"/>')
    s.append(_fence(-8,219,730,dark,wood,_mix(wood,wall,.35),403))
    s.append(_fence(1005,1290,732,dark,wood,_mix(wood,wall,.35),406))
    s.append(_pine(-20,739,151,501,dark,_mix(roof,dark,.15),_mix(roof,light,.15),wood,.98))
    s.append(_pine(1294,745,152,503,dark,_mix(roof,dark,.15),_mix(roof,light,.15),wood,.98))
    s.append('<rect width="1280" height="720" fill="url(#bg_vignette)" pointer-events="none"/>')
    return ''.join(s)

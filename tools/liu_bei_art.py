"""Original Liu Bei: long paired jian, ivory cross-collar robe and jade mantle.

Art coordinates equal rig units; the long weapon canvases retain the grip pivot.
"""
INK = '#242d2c'

def path(d, fill, stroke=INK, width=1.6):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'

def oval(x, y, rx, ry, fill, stroke=INK, width=1.6):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'

def dimensions(part):
    return (128,256) if part in ('weapon','offhand') else (128,128)

def defs():
    return '''<defs>
    <linearGradient id="jade" x1="0%" y1="0%" x2="100%" y2="65%"><stop stop-color="#628773"/><stop offset=".34" stop-color="#345f4d"/><stop offset=".75" stop-color="#234b3e"/><stop offset="1" stop-color="#173a32"/></linearGradient>
    <linearGradient id="cape" x1="0%" y1="0%" x2="100%" y2="70%"><stop stop-color="#315c4b"/><stop offset=".5" stop-color="#24483d"/><stop offset="1" stop-color="#142f2b"/></linearGradient>
    <linearGradient id="gold" x1="0%" x2="100%"><stop stop-color="#766344"/><stop offset=".3" stop-color="#b29c68"/><stop offset=".53" stop-color="#e3cf94"/><stop offset=".75" stop-color="#aa8e58"/><stop offset="1" stop-color="#725a3e"/></linearGradient>
    <linearGradient id="steel" x1="0%" x2="100%"><stop stop-color="#738f95"/><stop offset=".45" stop-color="#d8e6e2"/><stop offset=".49" stop-color="#f7f8e9"/><stop offset=".52" stop-color="#9bb6b9"/><stop offset="1" stop-color="#e7eee7"/></linearGradient>
    <linearGradient id="armor" x1="0%" y1="0%" x2="90%" y2="100%"><stop stop-color="#718081"/><stop offset=".35" stop-color="#4b6060"/><stop offset="1" stop-color="#2c3c3e"/></linearGradient>
    <linearGradient id="skin" x1="0%" y1="25%" x2="100%" y2="65%"><stop stop-color="#c99c78"/><stop offset=".38" stop-color="#edcda6"/><stop offset=".75" stop-color="#f2d6af"/><stop offset="1" stop-color="#cca17d"/></linearGradient>
    <linearGradient id="ivory" x1="0%" y1="0%" x2="100%" y2="80%"><stop stop-color="#f1e9cd"/><stop offset=".45" stop-color="#dfd9be"/><stop offset="1" stop-color="#a0ab94"/></linearGradient>
    <linearGradient id="leather" x1="0%" x2="100%"><stop stop-color="#695343"/><stop offset=".5" stop-color="#443a32"/><stop offset="1" stop-color="#302c29"/></linearGradient>
    </defs>'''

def sword(blade):
    tip = -10-blade
    art = path(f'M-5.5 -10 L-5 {tip+20} L0 {tip} L5 {tip+20} L5.5 -10 Z','url(#steel)','#394b4e',1.6)
    art += path(f'M-4 -14 L-4 {tip+21} L0 {tip+8} L0 -14 Z','#9bb6bb','none',0)
    art += path(f'M3 -17 L3 {tip+22} L0 {tip+5} L4 {tip+21} L4 -17 Z','#f4f5e7','none',0)
    art += path(f'M0 {tip+5} L0 -12','none','#f8f7e6',1.15)
    art += path('M-3 -17 L-3 -30 L0 -36 L3 -30 L3 -17','none','#607f82',.8)
    art += path('M-17 -9 L-13 -17 L-5 -13 L0 -17 L5 -13 L13 -17 L17 -9 L10 -4 L0 -8 L-10 -4 Z','#94733e',INK,1.6)
    art += path('M-14 -9 L-12 -14 L-4 -10 L-9 -7 Z M4 -10 L12 -14 L14 -9 L9 -7 Z','#d3b773',INK,.9)
    art += path('M-4 -11 L0 -15 L4 -11 L3 -7 L-3 -7 Z','url(#gold)',INK,1)
    art += path('M-2 -11 L0 -13 L2 -11 L0 -9 Z','#439174','#203f38',.7)
    art += path('M-3.5 -6 L3.5 -6 L3.5 12 L-3.5 12 Z','url(#leather)',INK,1.3)
    for y in [-3,1,5,9]: art += path(f'M-2.5 {y} L2.5 {y-2} M-2.5 {y} L2.5 {y+2}','none','#b9a080',.8)
    art += path('M-4 11 L4 11 L7 15 L5 20 L0 22 L-5 20 L-7 15 Z','url(#gold)',INK,1.3)
    art += path('M0 13 L3 16 L0 19 L-3 16 Z','#4e8d72',INK,.9)
    art += path('M1 22 Q11 24 8 29 Q4 31 4 26','none','#b5a077',1)
    art += path('M8 29 L4 39 M8 29 L8 40 M8 29 L11 38','none','#814938',1.5)
    return art

def parts():
    cape = path('M-18 -36 Q-36 -36 -42 -12 L-38 24 L-47 46 Q-25 48 -15 55 L14 42 L23 44 L19 -30 Z','url(#cape)')
    cape += path('M-27 -25 Q-34 0 -27 23 L-34 41 M-16 -27 Q-23 -1 -16 25','none','#517565',1.7)
    cape += path('M-45 44 Q-26 43 -15 52 L14 39','none','#a39367',1.3)
    tail = path('M8 -28 Q-11 -19 -26 8 Q-35 24 -57 37 Q-24 48 -6 28 L14 -6 Z','url(#jade)')
    tail += path('M-1 -10 Q-9 18 -33 33 M-30 29 L-49 36','none','#729080',1.2)
    tail += path('M-54 37 Q-24 45 -9 28','none','#ad9d74',1.2)
    body = path('M-16 -41 L14 -41 L23 -22 L20 8 L26 29 L34 53 L14 58 L1 44 L-16 57 L-31 50 L-23 23 L-22 -17 Z','url(#jade)')
    body += path('M-12 -40 L13 -39 L15 -14 L9 8 L15 47 L3 53 L-10 44 L-7 11 L-17 -18 Z','url(#ivory)')
    body += path('M10 -39 L17 -32 L-6 -6 L-15 -11 Z','#ece3c8','#83927e',1.1)
    body += path('M-14 -40 L-18 -32 L7 -13 L13 -20 Z','#e7dfc1','#8c9c85',1.1)
    body += path('M-19 -24 L-10 -15 L-12 4 L-21 7 Z M10 -13 L19 -23 L21 5 L11 7 Z','url(#armor)')
    for y in [-10,-4,2]: body += path(f'M-20 {y} L-12 {y+2} M13 {y+2} L20 {y}','none','#8b9990',.95)
    body += path('M-23 5 Q-3 10 22 4 L23 13 Q0 19 -24 13 Z','url(#leather)')
    body += path('M-3 9 L7 8 L8 15 L-2 16 Z','url(#gold)',INK,1.1)
    body += path('M0 11 L5 11 L5 13 L0 14 Z','#3d5044','none',0)
    body += path('M-18 18 Q-20 35 -25 47 M20 20 L29 49 M-2 21 L-5 41 M5 19 L10 46','none','#718d78',1.5)
    body += path('M-29 49 L-16 54 L-10 49 M17 54 L30 50','none','#a69b73',1.1)
    body += path('M-23 40 q3 -7 7 -2 q-5 -2 -6 4 M22 42 q-1 -6 -5 -3 q4 0 3 5','none','#879475',.8)
    trousers = path('M-16 -17 L15 -17 L17 16 L5 20 L0 -3 L-5 17 L-18 13 Z','#afb69d')
    trousers += path('M-10 -9 L-8 9 M9 -8 L10 11','none','#6f8475',1.4)
    boot = path('M-6 -18 L6 -18 L7 -1 Q11 4 19 5 L20 10 Q5 14 -9 9 L-9 -7 Z','url(#leather)')
    boot += path('M-6 -13 L6 -13 M-7 -8 L6 -8 M-8 7 Q5 11 17 8','none','#877965',1.4)
    boot += path('M-3 -14 L1 -14 L1 -11 L-3 -11 Z','url(#gold)','none',0)
    shoulder = path('M-10 -9 L-3 -14 L9 -9 L12 -1 L4 5 L-11 1 Z','url(#armor)')
    shoulder += path('M-10 -2 L4 2 L12 -2 L11 6 L3 10 L-10 5 Z','url(#armor)')
    shoulder += path('M-9 5 L3 9 L11 5 L9 12 L2 14 L-8 10 Z','url(#armor)')
    shoulder += path('M-9 -8 L-3 -11 L8 -7 M-9 1 L3 5 L10 1','none','#b3a579',1)
    upper = path('M-6 -4 Q-13 6 -8 21 L-4 29 L6 27 L9 13 L6 -3 Z','url(#ivory)')
    upper += path('M-8 8 L5 14 M-5 20 L6 18','none','#95a18d',1.3)
    fore = path('M-6 -2 L6 -2 L8 19 L5 27 L-5 26 L-8 15 Z','url(#leather)')
    fore += path('M-5 1 L4 0 L5 20 L-3 21 Z','url(#armor)',INK,1)
    fore += path('M-6 5 L6 3 M-6 15 L7 13 M-4 22 L5 22','none','#a39675',1)
    hand = path('M-5 -4 Q1 -7 5 -2 L6 5 L1 8 L-5 6 L-7 1 Z','url(#skin)',INK,1.4)
    hand += path('M-3 0 L-3 4 M0 -1 L1 4 M3 -1 L4 3','none','#a17e60',.9)
    head = oval(-20,2,4.5,7,'url(#skin)',INK,1.5)
    head += path('M-20 -16 Q-14 -27 1 -26 Q19 -25 23 -12 L23 7 Q19 21 5 24 Q-12 23 -19 11 Z','url(#skin)',INK,2)
    head += path('M-19 -10 L-14 11 L-6 19 L5 22 Q-11 22 -18 11 Z','#c99b75','none',0)
    head += path('M-21 6 L-24 -12 Q-25 -29 -9 -32 Q7 -39 20 -26 L25 -13 L18 -11 L12 -23 Q0 -17 -16 -21 L-17 8 Z','#26322d',INK,1.8)
    head += path('M-19 -22 L-9 -29 L8 -29 L15 -25 L-3 -26 Z','#48564a','none',0)
    head += path('M-18 -15 L-19 -2 M14 -23 L20 -16','none','#687260',1)
    head += path('M-14 -9 L-4 -6 L-4 -4 L-14 -6 Z M5 -6 L17 -9 L17 -6 L6 -4 Z','#2f352c','none',0)
    head += path('M-13 -1 Q-9 -4 -3 -1 L-4 3 L-11 3 Z M5 -1 Q11 -5 17 -2 L16 3 L7 3 Z','#f0e8d1','#4c4c3c',1.1)
    head += oval(-6,.4,2.1,2.7,'#29372e','none',0)+oval(12,.2,2.2,2.8,'#29372e','none',0)
    head += oval(-5.5,-.5,.65,.7,'#ffefd2','none',0)+oval(12.6,-.7,.7,.75,'#ffefd2','none',0)
    head += path('M4 5 L6 9 L3 10','none','#a07957',1.1)
    head += path('M-2 13 Q1 10 4 13 Q8 10 12 12 L9 15 L4 14 L0 16 Z','#4a4232','none',0)
    head += path('M1 17 L8 17','none','#795842',1)
    head += path('M-3 21 Q4 25 13 20 L10 28 L5 31 L0 28 Z','#3c3e31',INK,1.2)
    head += path('M3 25 L5 28 L7 24','none','#7e7958',.8)
    # Faceted bronze hair crown and jade inlay echo the reference's material hierarchy.
    head += path('M-11 -30 L-9 -45 Q0 -51 9 -45 L13 -30 Z','#293b30',INK,1.5)
    head += path('M-11 -32 L-10 -40 L-5 -42 L-6 -51 L0 -54 L7 -51 L8 -42 L12 -38 L13 -31 L6 -28 L-5 -28 Z','#99763d',INK,1.5)
    head += path('M-3 -50 L0 -51 L5 -49 L5 -40 L2 -37 L-1 -40 Z','#d7ba76',INK,.9)
    head += path('M-8 -35 L-5 -39 L2 -36 L8 -39 L10 -33 L4 -30 L-3 -30 Z','#d7ba76',INK,.9)
    head += path('M-2 -40 L3 -41 L6 -36 L2 -31 L-2 -34 Z','#3b8366',INK,1)
    head += path('M0 -38 L2 -39 L4 -36 L2 -34 Z','#89b595','none',0)
    head += path('M-16 -37 L-11 -37 M13 -37 L20 -37','none','#bfa06a',2)
    head += oval(21,-37,2,2,'#dec186',INK,.8)
    ribbon = path('M3 -5 Q-9 -11 -17 2 L-23 19 L-37 30 L-24 28 L-11 9 Q-7 2 3 3 Z','url(#cape)')
    ribbon += path('M-6 -4 Q-14 4 -16 14','none','#73927b',1)
    scabbard = path('M-4 -53 L4 -53 L5 42 L1 55 L-3 51 L-5 41 Z','url(#leather)',INK,1.2)
    scabbard += path('M-4 -50 L4 -50 M-4 -43 L4 -43 M-4 39 L5 39 M-2 48 L3 48','none','url(#gold)',2)
    scabbard += path('M0 -37 L1 34','none','#7c6c55',.8)
    pendant = path('M0 -18 Q-4 -8 0 -2','none','#b09e73',1.4)+oval(0,3,5.5,8,'#739881',INK,1.2)
    pendant += oval(0,2,2,3,'#b1c1a3','#547b6b',.8)
    pendant += path('M0 12 L-2 24 M0 12 L2 24','none','#865142',1.3)
    sash = path('M-4 -9 L4 -9 L7 21 L3 36 L-2 31 L-2 12 Z','#785247',INK,1.1)
    sash += path('M0 4 L3 26','none','#a18265',.9)
    insignia = oval(0,0,3.5,3.5,'url(#gold)',INK,.8)
    slash = path('M-61 45 Q-9 -61 62 -28 Q11 -39 -44 47 Z','#e7efd9','none',0)
    slash += path('M-51 33 Q-5 -47 57 -25','none','#fffce2',1.5)
    aura = oval(0,0,50,20,'none','#d6ca97',1.7)+oval(0,0,43,14,'none','#8fbb9d',1.3)
    aura += path('M-34 -2 Q-18 -22 1 -2 Q18 15 32 -2','none','#d7deac',1.4)
    return {key:defs()+value for key,value in dict(cape=cape,cape_tail=tail,trousers=trousers,boot=boot,body=body,shoulder=shoulder,upper_arm=upper,forearm=fore,hand=hand,head=head,hair_ribbon=ribbon,weapon=sword(112),offhand=sword(104),scabbard=scabbard,pendant=pendant,sash=sash,insignia=insignia,slash=slash,aura=aura).items()}

def keys(values,field='value'):
    return [{'time':time,field:value} for time,value in values]

def rotations(values):
    return {'rotate':keys(values)}

def rig():
    bones = [{'name':'root'},{'name':'torso','parent':'root','y':77},{'name':'cape','parent':'torso'},{'name':'cape_tail','parent':'cape','x':-11,'y':-8},
        {'name':'trousers','parent':'root','y':27},{'name':'boot_l','parent':'root','x':-13,'y':18,'rotation':8},{'name':'boot_r','parent':'root','x':15,'y':15,'rotation':-9},
        {'name':'scabbard_l','parent':'torso','x':-17,'y':-25,'rotation':-18},{'name':'scabbard_r','parent':'torso','x':-9,'y':-24,'rotation':-26},
        {'name':'shoulder_l','parent':'torso','x':-22,'y':24},{'name':'shoulder_r','parent':'torso','x':21,'y':26},
        {'name':'upper_l','parent':'shoulder_l','rotation':-5},{'name':'upper_r','parent':'shoulder_r','rotation':20},
        {'name':'fore_l','parent':'upper_l','y':-26,'rotation':-35},{'name':'fore_r','parent':'upper_r','y':-26,'rotation':50},
        {'name':'hand_l','parent':'fore_l','y':-23},{'name':'hand_r','parent':'fore_r','y':-23},
        {'name':'weapon','parent':'hand_r','rotation':-90},{'name':'offhand','parent':'hand_l','rotation':62},
        {'name':'head','parent':'torso','y':61,'x':1},{'name':'hair_ribbon','parent':'head','x':-14,'y':29},
        {'name':'pendant','parent':'torso','x':15,'y':-30},{'name':'sash','parent':'torso','x':-9,'y':-25},{'name':'insignia','parent':'torso','x':-18,'y':28},
        {'name':'slash','parent':'root','x':81,'y':91,'scaleX':1.3,'scaleY':1.15},{'name':'aura','parent':'root','y':12}]
    ordered = [('cape_tail','cape_tail'),('cape','cape'),('scabbard_l','scabbard'),('scabbard_r','scabbard'),('trousers','trousers'),('boot_l','boot'),('boot_r','boot'),('upper_l','upper_arm'),('fore_l','forearm'),('offhand','offhand'),('hand_l','hand'),('body','body'),('sash','sash'),('pendant','pendant'),('shoulder_l','shoulder'),('shoulder_r','shoulder'),('upper_r','upper_arm'),('fore_r','forearm'),('hair_ribbon','hair_ribbon'),('head','head'),('insignia','insignia'),('weapon','weapon'),('hand_r','hand'),('aura','aura'),('slash','slash')]
    slots=[]; attachments={}
    for bone,art in ordered:
        slots.append({'name':bone,'bone':'torso' if bone=='body' else bone,'attachment':art,**({'color':'ffffff00'} if art in ['aura','slash'] else {})})
        w,h=dimensions(art)
        attachments[bone]={art:{'path':art,'width':w,'height':h}}
    idle={'bones':{'torso':{'translate':keys([(0,0),(.65,1.4),(1.3,0)],'y')},'cape_tail':rotations([(0,-2),(.65,3),(1.3,-2)]),'pendant':rotations([(0,-2),(.65,2),(1.3,-2)])}}
    move={'bones':{'torso':{'translate':keys([(0,0),(.25,2.5),(.5,0)],'y')},'boot_l':rotations([(0,-14),(.25,14),(.5,-14)]),'boot_r':rotations([(0,14),(.25,-14),(.5,14)]),'cape_tail':rotations([(0,4),(.25,-8),(.5,4)])}}
    def swing(critical=False):
        end=.44 if critical else .33
        channels={
            'upper_r':[(0,0),(.05,-10),(.11,15),(end,0)],
            'fore_r':[(0,0),(.05,10),(.11,5),(end,0)],
            'weapon':[(0,0),(.05,35),(.11,-110 if critical else -90),(end,0)],
            'upper_l':[(0,0),(.05,15 if critical else 0),(.11,60 if critical else 0),(end,0)],
            'fore_l':[(0,0),(.11,20 if critical else 0),(end,0)],
            'offhand':[(0,0),(.11,-152 if critical else 0),(end,0)],
            'torso':[(0,0),(.05,4),(.11,-9 if critical else -5),(end,0)],
            'cape_tail':[(0,0),(.11,-17 if critical else -8),(end,0)],
            'pendant':[(0,0),(.11,10),(end,0)]}
        animation={'bones':{bone:rotations(values) for bone,values in channels.items()},'slots':{'slash':{'rgba':[{'time':0,'color':'ffffff00'},{'time':.095,'color':'fff6cee0' if critical else 'd7efe5a0'},{'time':.15,'color':'ffffff00'}]}},'events':[{'time':.11,'name':'Effect'}]}
        animation['bones']['torso']['translate']=keys([(0,0),(.11,8 if critical else 4),(end,0)],'x')
        return animation
    support={'bones':{},'slots':{'aura':{'rgba':[{'time':0,'color':'8ccba800'},{'time':.12,'color':'8ccba8a0'},{'time':.4,'color':'8ccba800'}]}}}
    for bone,angle in [('upper_r',90),('fore_r',-70),('weapon',-10)]: support['bones'][bone]=rotations([(0,0),(.12,angle),(.4,0)])
    ult={'bones':{},'slots':{'aura':{'rgba':[{'time':0,'color':'fff1bc00'},{'time':.03,'color':'fff1bcd0'},{'time':.4,'color':'fff1bc80'},{'time':.55,'color':'fff1bc00'}]}},'events':[{'time':0,'name':'Effect'}]}
    for bone,angle in [('upper_r',150),('upper_l',-165),('fore_r',-70),('fore_l',55),('weapon',-75),('offhand',103),('cape_tail',-14)]: ult['bones'][bone]=rotations([(0,0),(.18,angle),(.35,angle),(.55,0)])
    ult['bones']['aura']={'scale':[{'time':0,'x':.5,'y':.5},{'time':.4,'x':1.5,'y':1.5},{'time':.55,'x':1.7,'y':1.7}]}
    return {'skeleton':{'spine':'4.3.00','x':-120,'y':0,'width':240,'height':270},'bones':bones,'slots':slots,'skins':[{'name':'default','attachments':attachments}],'events':{'Effect':{}},'animations':{'Idle':idle,'Move':move,'Attack_A':swing(),'Critical':swing(True),'Active_A':support,'XX':ult,'Stun':{'bones':{'head':rotations([(0,-4),(.25,4),(.5,-4)])}},'Death':{'bones':{'torso':rotations([(0,0),(.4,70)])}}}}

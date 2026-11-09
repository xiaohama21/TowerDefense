"""Authored vector camp and nine distinct buildings; day/dusk share geometry."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
POSITIONS = {'map':(1100,300),'command':(635,205),'develop':(374,313),'tech':(894,207),'tavern':(159,482),'stable':(1057,510),'shop':(795,498),'inventory':(493,520),'encyclopedia':(156,232)}
LABELS = {'map':'城门 · 出征','command':'中军帐 · 查看','develop':'演武场 · 培养','tech':'军机帐 · 研习','tavern':'酒馆 · 施工','stable':'兽栏 · 施工','shop':'市集 · 选购','inventory':'库房 · 整理','encyclopedia':'藏书阁 · 查阅'}
PALETTES = {'day':{'sky':'#b5e0ec','ground':'#739b78','dark':'#314f59','roof':'#328bae','light':'#78bdd0','wall':'#ead6a1','wood':'#806147','gold':'#edbd65','road':'#b5bc93'}, 'dusk':{'sky':'#183b3b','ground':'#2b5044','dark':'#142a29','roof':'#3d6356','light':'#78917a','wall':'#c0b48a','wood':'#665741','gold':'#dfb76b','road':'#627960'}}

def svg(body,w,h): return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'
def building(key,c):
    d,r,l,w,t,g=[c[k] for k in ['dark','roof','light','wall','wood','gold']]
    s=f'<g stroke="{d}" stroke-width="2.5" stroke-linejoin="round"><ellipse cx="100" cy="155" rx="88" ry="15" fill="{d}" opacity=".25"/>'
    if key=='map':
        s+=f'<path d="M17 147V70H63V147M137 147V70H183V147" fill="{w}"/><path d="M52 150V78H148V150H122V111Q100 82 78 111V150Z" fill="{t}"/><path d="M7 69L25 40H53L74 69ZM126 69L144 40H172L193 69Z" fill="{r}"/><path d="M40 80L66 50H136L164 80Z" fill="{r}"/><path d="M20 60H62M139 60H181M55 70H150" stroke="{l}"/>'
        for x in [26,46,148,168]: s+=f'<path d="M{x} 80V123" stroke="{t}" stroke-width="7"/>'
    elif key in ['command','tech']:
        s+=f'<path d="M28 145L42 82H159L178 145Z" fill="{w}"/><path d="M16 87L99 28L185 87Z" fill="{r}"/><path d="M99 28V144M45 82L99 28L158 82" fill="none" stroke="{l}"/><path d="M79 145L88 94H111L126 145Z" fill="{d}"/><path d="M99 31V8L140 15L99 26" fill="{g}"/>'
        for x in [25,174]: s+=f'<path d="M{x} 95V152" stroke="{t}" stroke-width="4"/>'
        if key=='tech': s+=f'<path d="M18 149L42 117L100 126L82 157Z" fill="{t}"/><path d="M28 143L48 127L86 132L72 148Z" fill="{l}"/><path d="M51 137L57 119M69 137V115" stroke="{g}"/>'
    elif key=='develop':
        s+=f'<path d="M10 123L92 77L192 126L104 166Z" fill="{t}"/><path d="M22 122L93 90L178 127L104 153Z" fill="{w}"/><path d="M37 121V40M62 116V34M25 63H75" stroke="{d}" stroke-width="5"/><path d="M37 47L25 35M62 45L78 29" stroke="{g}" stroke-width="5"/>'
        for x,y in [(127,67),(160,84)]: s+=f'<path d="M{x} {y+13}V{y+59}" stroke="{t}" stroke-width="6"/><ellipse cx="{x}" cy="{y}" rx="20" ry="24" fill="{w}"/><ellipse cx="{x}" cy="{y}" rx="12" ry="15" fill="none" stroke="{r}" stroke-width="5"/><circle cx="{x}" cy="{y}" r="4" fill="{g}"/>'
    elif key=='stable':
        s+=f'<path d="M39 130V65H155V130" fill="{w}"/><path d="M20 66L63 29H139L181 66Z" fill="{r}"/><path d="M70 133V79H134V133" fill="{d}"/>'
        for x in range(18,188,24): s+=f'<path d="M{x} 156V115L{x+5} 109L{x+10} 115V156" fill="{t}"/>'
        s+=f'<path d="M15 127H189M15 145H189" stroke="{w}" stroke-width="6"/>'
    else:
        s+=f'<path d="M41 146V72H164V146Z" fill="{w}"/><path d="M22 75L59 36H148L184 75Z" fill="{r}"/><path d="M39 64H170M48 54H160" fill="none" stroke="{l}"/><path d="M88 145V96H120V145" fill="{d}"/>'
        for x in [48,139]: s+=f'<path d="M{x} 91H{x+17}V116H{x}Z" fill="{r}"/><path d="M{x+8} 91V116" stroke="{g}"/>'
        if key=='tavern':
            s+=f'<path d="M168 52V130M169 86H192V107H169" fill="{g}"/><ellipse cx="45" cy="141" rx="19" ry="12" fill="{t}"/><path d="M27 133Q42 116 63 133V145Q42 159 27 145Z" fill="{t}"/><path d="M27 137H63" stroke="{g}"/>'
        elif key=='shop':
            s+=f'<path d="M25 115L37 86H163L182 115Z" fill="{g}"/><path d="M35 115V150M171 115V151" stroke="{t}" stroke-width="5"/><path d="M38 134H174V155H38Z" fill="{t}"/>'
            for x in [52,80,136]: s+=f'<path d="M{x} 124H{x+20}V138H{x}Z" fill="{w}"/>'
        elif key=='inventory':
            s+=f'<path d="M24 136Q12 100 38 105Q57 111 55 141Z" fill="{g}"/><path d="M139 135H184V158H139Z" fill="{t}"/><path d="M143 137L180 155M179 137L143 155" stroke="{w}"/>'
        elif key=='encyclopedia':
            s+=f'<path d="M57 46V25H143V47" fill="{w}"/><path d="M43 27L69 8H133L156 27Z" fill="{r}"/><path d="M72 40V29M127 40V29" stroke="{g}"/><path d="M15 144V125L43 120L67 125V144L43 140Z" fill="{w}"/><path d="M43 123V140" stroke="{t}"/>'
    s+=f'<path d="M14 151V131M186 151V128" stroke="{t}"/><circle cx="14" cy="129" r="5" fill="{g}"/><circle cx="186" cy="126" r="5" fill="{g}"/></g>'
    return s

def backdrop(c):
    s=f'<rect width="1280" height="720" fill="{c["sky"]}"/><path d="M0 135L155 69L330 113L510 53L740 106L920 64L1110 117L1280 83V720H0Z" fill="{c["dark"]}" opacity=".42"/><path d="M0 208Q425 108 690 159T1280 146V720H0Z" fill="{c["ground"]}"/>'
    s+=f'<path d="M-20 610Q207 624 350 515T629 403Q786 374 1080 421T1300 415M350 515Q302 376 155 320M629 403L635 286M785 416L883 280M479 459L489 594M171 499L281 553" fill="none" stroke="{c["dark"]}" stroke-width="59" opacity=".25"/><path d="M-20 610Q207 624 350 515T629 403Q786 374 1080 421T1300 415M350 515Q302 376 155 320M629 403L635 286M785 416L883 280M479 459L489 594M171 499L281 553" fill="none" stroke="{c["road"]}" stroke-width="46"/>'
    for x,y in [(40,187),(247,175),(458,195),(759,149),(1130,155),(1218,268),(43,610),(304,655),(661,628),(901,645),(1196,605)]:
        s+=f'<ellipse cx="{x}" cy="{y+18}" rx="35" ry="9" fill="{c["dark"]}" opacity=".3"/><path d="M{x} {y+15}V{y-5}" stroke="{c["wood"]}" stroke-width="9"/><circle cx="{x-15}" cy="{y-12}" r="23" fill="{c["roof"]}"/><circle cx="{x+13}" cy="{y-19}" r="25" fill="{c["light"]}"/><circle cx="{x}" cy="{y-32}" r="23" fill="{c["roof"]}"/>'
    for x in range(20,1280,28): s+=f'<path d="M{x} 711V678L{x+5} 670L{x+10} 678V711" fill="{c["wood"]}" stroke="{c["dark"]}" stroke-width="2"/>'
    return s

def main():
    dest=ROOT/'assets/city'; concepts=ROOT/'docs/ui_concept/city_0.10.1'
    concepts.mkdir(parents=True,exist_ok=True);(concepts/'.gdignore').touch()
    for mode,c in PALETTES.items():
        folder=dest/mode;folder.mkdir(parents=True,exist_ok=True)
        bg=backdrop(c);(folder/'background.svg').write_text(svg(bg,1280,720),encoding='utf-8')
        comp=bg
        for key,(x,y) in POSITIONS.items():
            body=building(key,c);(folder/(key+'.svg')).write_text(svg(body,200,175),encoding='utf-8')
            comp+=f'<g transform="translate({x-100},{y-80})">{body}</g>'
        (concepts/(mode+'.svg')).write_text(svg(comp,1280,720),encoding='utf-8')
    html='<!doctype html><meta charset="utf-8"><title>主城昼暮对照</title><style>body{margin:20px;background:#172923;color:#ecdfb9;font-family:Microsoft Yahei}h1{font-size:24px}.row{display:flex;gap:16px}figure{margin:0;flex:1}img{width:100%}figcaption{padding:12px}</style><h1>主城 · 相同布局，两种色板</h1><div class="row">'+''.join(f'<figure><img src="{m}.svg"><figcaption>{n}</figcaption></figure>' for m,n in [('day','昼 · 亮蓝军营'),('dusk','暮 · 墨绿暖金军营')])+'</div>'
    (concepts/'comparison.html').write_text(html,encoding='utf-8')
    (dest/'layout.json').write_text(json.dumps(POSITIONS,indent=2)+'\n',encoding='utf-8')
    print('CITY_ART_READY',dest)

if __name__=='__main__': main()

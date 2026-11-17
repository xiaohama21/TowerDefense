"""Rebuild the original layered camp illustration and its nine building assets."""
from pathlib import Path
import json
from city_building_art import building
from city_backdrop_art import backdrop

ROOT = Path(__file__).resolve().parents[1]
POSITIONS = {'map':(1100,300),'command':(635,205),'develop':(374,313),'tech':(894,207),'tavern':(159,482),'stable':(1057,510),'shop':(795,498),'inventory':(493,520),'encyclopedia':(156,232)}
PALETTES = {
    'day': {'sky':'#a8c8c4','ground':'#607b5a','dark':'#273e34','roof':'#426451','light':'#9eac79','wall':'#d8c298','wood':'#806347','gold':'#ebba68','road':'#aa9973'},
    'dusk': {'sky':'#3d5d5a','ground':'#365344','dark':'#172d28','roof':'#426253','light':'#8d9b74','wall':'#c8b58e','wood':'#765940','gold':'#e5b76b','road':'#8b8562'},
}

def svg(body,w,h):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w*2}" height="{h*2}" viewBox="0 0 {w} {h}">{body}</svg>'

def main():
    dest=ROOT/'assets/city'
    concepts=ROOT/'docs/ui_concept/city_0.10.1.1'
    concepts.mkdir(parents=True,exist_ok=True)
    (concepts/'.gdignore').touch()
    for mode,c in PALETTES.items():
        folder=dest/mode
        folder.mkdir(parents=True,exist_ok=True)
        bg=backdrop(c)
        (folder/'background.svg').write_text(svg(bg,1280,720),encoding='utf-8')
        comp=bg
        for key,(x,y) in POSITIONS.items():
            body=building(key,c)
            (folder/(key+'.svg')).write_text(svg(body,200,175),encoding='utf-8')
            comp+=f'<g transform="translate({x-100},{y-80})">{body}</g>'
        (concepts/(mode+'.svg')).write_text(svg(comp,1280,720),encoding='utf-8')
    html='<!doctype html><meta charset="utf-8"><title>主城营地美术升级</title><style>body{margin:24px;background:#152b26;color:#e9dbb5;font-family:Microsoft Yahei}h1{font-size:24px}.row{display:flex;gap:20px}figure{margin:0;flex:1}img{width:100%}figcaption{padding:12px}</style><h1>主城营地 · 建筑与环境细化</h1><div class="row">'+''.join(f'<figure><img src="{m}.svg"><figcaption>{n}</figcaption></figure>' for m,n in [('day','昼色对照'),('dusk','暮色墨绿暖金')])+'</div>'
    (concepts/'comparison.html').write_text(html,encoding='utf-8')
    (concepts/'README.md').write_text('# 主城营地美术 · 0.10.1.1\n\n原创SVG源；暮色为默认，昼色保留对照。九建筑与地面材质独立重建，逻辑布局保持。\n\n[暮色](dusk.png) / [昼色](day.png) / [对照](comparison.html)。生成：python tools/generate_city_art.py；PNG由Godot原生SVG解析输出。\n',encoding='utf-8')
    (dest/'layout.json').write_text(json.dumps(POSITIONS,indent=2)+'\n',encoding='utf-8')
    print('CITY_ART_READY',dest)

if __name__=='__main__':
    main()

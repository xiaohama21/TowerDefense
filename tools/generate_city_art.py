"""Rebuild the original layered camp illustration and its nine building assets."""
from pathlib import Path
import json
from city_building_art import building
from city_backdrop_art import backdrop

ROOT = Path(__file__).resolve().parents[1]
POSITIONS = {'map':(1100,300),'command':(635,205),'develop':(374,313),'tech':(894,207),'tavern':(159,482),'stable':(1057,510),'shop':(795,498),'inventory':(493,520),'encyclopedia':(156,232)}
PALETTES = {
    'day': {'sky':'#d7dfc0','ground':'#94aa6a','dark':'#345947','roof':'#52775d','light':'#c6d092','wall':'#f0d8a6','wood':'#a57b50','gold':'#eac77b','road':'#d4bb8a'},
    'dusk': {'sky':'#a0bbb2','ground':'#7d996b','dark':'#38574a','roof':'#547465','light':'#b6c08a','wall':'#dfc69a','wood':'#99734e','gold':'#e4bc73','road':'#c2ad81'},
}

def svg(body,w,h):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w*2}" height="{h*2}" viewBox="0 0 {w} {h}">{body}</svg>'

def main():
    dest=ROOT/'assets/city'
    concepts=ROOT/'docs/ui_concept/city_0.10.1.2'
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
    html='<!doctype html><meta charset="utf-8"><title>明亮营地 · 九建筑辨识</title><style>body{margin:24px;background:#f4e7c9;color:#365441;font-family:Microsoft Yahei}h1{font-size:24px}.row{display:flex;gap:20px}figure{margin:0;flex:1}img{width:100%}figcaption{padding:12px}</style><h1>明亮营地 · 九建筑主体重绘</h1><div class="row">'+''.join(f'<figure><img src="{m}.svg"><figcaption>{n}</figcaption></figure>' for m,n in [('day','暖日照青绿 · 默认'),('dusk','提亮暮色 · 对照')])+'</div>'
    (concepts/'comparison.html').write_text(html,encoding='utf-8')
    (concepts/'README.md').write_text('# 明亮营地与建筑辨识 · 0.10.1.2\n\n原创SVG源；暖日照青绿为默认，提亮暮色保留对照。九建筑以门楼、双尖主帐、露天靶场、敞棚沙盘、窄高酒肆、圈养场、多彩货摊、狭长仓房和双层书楼区分。原逻辑布局保持，图像下缘为名称与动作牌预留。\n\n[日照](day.png) / [暮色](dusk.png) / [对照](comparison.html)。生成：python tools/generate_city_art.py；PNG由Godot原生SVG解析输出。历史0.10.1.1概念保留。\n',encoding='utf-8')
    (dest/'layout.json').write_text(json.dumps(POSITIONS,indent=2)+'\n',encoding='utf-8')
    print('CITY_ART_READY',dest)

if __name__=='__main__':
    main()

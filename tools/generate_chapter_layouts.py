"""Rebuild the authored chapter-one routes (GDD STAGES 5.9); keep combat data."""
from pathlib import Path
import json, re

ROOT = Path(__file__).resolve().parents[1]
# Coordinates are cell centers. Offscreen points use columns -1 and 16.
LAYOUTS = {
    1: {'name':'双弯入门', 'main':[(-1,3),(0,3),(8,3),(8,6),(13,6),(13,4),(15,4),(16,4)]},
    2: {'name':'不对称火场回折', 'main':[(-1,2),(0,2),(4,2),(4,4),(2,4),(2,6),(8,6),(8,3),(12,3),(12,5),(15,5),(16,5)]},
    3: {'name':'十字回穿', 'main':[(-1,4),(0,4),(8,4),(8,1),(5,1),(5,6),(12,6),(12,3),(15,3),(16,3)]},
    4: {'name':'双翼分流', 'main':[(-1,4),(0,4),(3,4),(3,1),(11,1),(11,4),(11,6),(14,6),(14,4),(15,4),(16,4)],
        'lower':[(-1,4),(0,4),(3,4),(3,7),(8,7),(8,4),(11,4),(11,6),(14,6),(14,4),(15,4),(16,4)], 'cycle':['main','lower']},
    5: {'name':'中央双环汇流', 'main':[(-1,5),(0,5),(2,5),(2,3),(2,1),(9,1),(9,3),(12,3),(12,6),(15,6),(16,6)],
        'lower':[(-1,5),(0,5),(2,5),(2,3),(5,3),(5,5),(9,5),(9,3),(12,3),(12,6),(15,6),(16,6)], 'cycle':['main','main','lower']},
    6: {'name':'逆向纵深', 'main':[(16,2),(15,2),(10,2),(10,6),(6,6),(6,1),(2,1),(2,5),(0,5),(-1,5)]},
    7: {'name':'交叉双路', 'main':[(-1,3),(0,3),(3,3),(3,1),(9,1),(9,5),(13,5),(13,7),(15,7),(15,4),(16,4)],
        'lower':[(-1,3),(0,3),(3,3),(6,3),(6,7),(11,7),(11,3),(13,3),(13,4),(15,4),(16,4)], 'cycle':['main','lower']},
    8: {'name':'双翼合围与场内援路', 'main':[(-1,3),(0,3),(2,3),(2,1),(8,1),(8,3),(11,3),(11,6),(13,6),(13,4),(15,4),(16,4)],
        'lower':[(-1,3),(0,3),(2,3),(2,5),(6,5),(6,3),(8,3),(11,3),(11,6),(13,6),(13,4),(15,4),(16,4)],
        'fork':[(-1,7),(0,7),(4,7),(4,3),(8,3),(11,3),(11,6),(13,6),(13,4),(15,4),(16,4)], 'cycle':['main','lower']},
}

def trace(points):
    cells=[]
    for (x,y),(xx,yy) in zip(points,points[1:]):
        assert (x==xx) != (y==yy),points
        dx,dy=(xx>x)-(xx<x),(yy>y)-(yy<y)
        for step in range(abs(xx-x)+abs(yy-y)+1):
            cell=x+dx*step,y+dy*step
            if 0<=cell[0]<16 and 0<=cell[1]<9 and (not cells or cells[-1]!=cell): cells.append(cell)
    return cells

def vectors(cells, kind='Vector2', pixel=True):
    return '['+', '.join(f'{kind}({x*80+40 if pixel else x}, {y*80+40 if pixel else y})' for x,y in cells)+']'

def packed(cells):
    return 'PackedVector2Array('+', '.join(str(n*80+40) for cell in cells for n in cell)+')'

def authored_slots(roads, count):
    occupied=set(sum(roads,[]))
    candidates=[(x,y) for y in range(1,8) for x in range(16) if (x,y) not in occupied]
    def nearest(cell):
        return min(((cell[0]-x)**2+(cell[1]-y)**2)**.5 for x,y in occupied)
    candidates=[c for c in candidates if nearest(c)<=3.125]
    far=[c for c in candidates if nearest(c)>=1.875]
    assert len(far)>=3
    # Favor repeat/crossing coverage while spacing the recommended positions.
    def exposure(cell):
        return sum(max(0,2.1-((cell[0]-x)**2+(cell[1]-y)**2)**.5) for road in roads for x,y in road)
    slots=[]
    for index in range(count):
        pool=far if index>=count-3 else [c for c in candidates if c not in far]
        choices=[c for c in pool if c not in slots]
        def score(c):
            spacing=min((abs(c[0]-s[0])+abs(c[1]-s[1]) for s in slots),default=4)
            return exposure(c)*(1 if spacing>=2 else .25),spacing,-c[1],-c[0]
        slots.append(max(choices,key=score))
    return slots

def generate():
    report={}
    for number,layout in LAYOUTS.items():
        file=ROOT/f'resources/stages/chapter_01/ch01_s{number:02d}.tres'
        text=file.read_text(encoding='utf-8')
        paths={key:value for key,value in layout.items() if key not in ['name','cycle']}
        roads=[trace(points) for points in paths.values()]
        assert all(all(1<=y<=7 for x,y in road) for road in roads)
        assert len({r[-1] for r in roads}) == 1
        occupied=set(sum(roads,[]))
        if number == 1:
            text=re.sub(r'^path_points = .*$', 'path_points = '+vectors(layout['main']),text,flags=re.M)
            file.write_text(text,encoding='utf-8',newline='\n')
            report['ch01_s01']={'name':layout['name'],'paths':paths,'cycle':['main'],'road_cells':len(occupied),'route_lengths_cells':{'main':len(roads[0])-1}}
            continue
        count=int(re.search(r'^build_slot_count = (\d+)',text,re.M)[1])
        slots=authored_slots(roads,count)
        forbidden=[]
        for cell in [(0,1),(15,1),(1,7),(14,7),(0,5),(15,7),(7,2),(10,7),(12,1),(1,3)]:
            if cell not in occupied and cell not in slots:
                forbidden.append(cell)
            if len(forbidden)==4: break
        decors=[]
        for y in [1,7,2,6,4]:
            for x in range(1,16,3):
                cell=(x,y)
                if cell not in occupied and cell not in forbidden and cell not in slots: decors.append(cell)
        decors=decors[:12]
        assignments={'path_points':vectors(layout['main']), 'fork_path_points':vectors(layout.get('fork',[])),
            'alternate_paths':'{'+', '.join(f'&"{key}": {packed(value)}' for key,value in paths.items() if key not in ['main','fork'])+'}',
            'normal_path_ids':'['+', '.join(f'&"{key}"' for key in layout.get('cycle',['main']))+']',
            'build_slot_positions':vectors(slots), 'decor_cells':vectors(decors,'Vector2i',False),
            'forbidden_cells':vectors(forbidden,'Vector2i',False)}
        for key in list(assignments)+['fork_alternate_paths','fork_normal_path_ids']:
            text=re.sub(r'^'+key+r' = .*\n','',text,flags=re.M)
        block='\n'.join(key+' = '+value for key,value in assignments.items())
        text=re.sub(r'^(theme = .*\n)',lambda m:m[0]+block+'\n',text,count=1,flags=re.M)
        structured_count=len(re.findall(r'^position = Vector2\(',text,re.M))
        assert structured_count <= len(slots)
        iterator=iter(slots)
        text=re.sub(r'^position = Vector2\([^\n]+$',lambda m:'position = '+vectors([next(iterator)])[1:-1],text,flags=re.M)
        file.write_text(text,encoding='utf-8',newline='\n')
        report[f'ch01_s{number:02d}']={'name':layout['name'],'paths':paths,'cycle':layout.get('cycle',['main']),'road_cells':len(occupied),'route_lengths_cells':{key:len(trace(points))-1 for key,points in paths.items()},'slots':slots,'forbidden':forbidden}
    output=ROOT/'build/map_topology_layouts.json'
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:{'shape':row['name'],'lengths':row['route_lengths_cells'],'road_cells':row['road_cells']} for key,row in report.items()},ensure_ascii=False))

if __name__=='__main__': generate()

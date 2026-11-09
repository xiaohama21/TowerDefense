"""Refresh only field-art metadata; keep character provenance and captures intact."""
from pathlib import Path
import hashlib,json,re

root=Path(__file__).resolve().parents[1]
base=root/'assets/battle_visuals'
manifest=json.loads((base/'manifest.json').read_text(encoding='utf-8'))
manifest['program']=re.search(r'config/version="([^"]+)"',(root/'project.godot').read_text(encoding='utf-8'))[1]
manifest['map_style']={'version':2,'themes':['grass','fire','night'],'texture_size':[160,160],'source_canvas':[80,80],'grid_size':80,'geometry':'authored orthogonal route union; connected shoulders and rounded external corners','generator':'tools/map_field_art.py','topology_version':1,'route_generator':'tools/generate_chapter_layouts.py'}
manifest['files']={p.relative_to(base).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(base.rglob('*')) if p.is_file() and 'variants' not in p.relative_to(base).parts and (p.suffix in ['.svg','.png','.atlas','.spine-json','.tres'] or (any(part.startswith('d69_') for part in p.parts) and p.suffix != '.import'))}
(base/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8',newline='\n')
print('MAP_MANIFEST_FINALIZED',manifest['program'],len(manifest['files']))

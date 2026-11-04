"""Check actual resource coverage, transparency, preview paths, and legacy preservation."""
from collections import Counter
from pathlib import Path
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/ui/icons/v2'
manifest=json.loads((BASE/'manifest.json').read_text(encoding='utf-8'))
ids={i['id'] for i in manifest['icons']}
entries={i['id']:i for i in manifest['icons']}
current_skills=set()
errors=[]
required=['ingot','lord_level','lord_exp']+['equipment_rarity_'+str(tier) for tier in range(5)]
errors += ['economic/quality coverage: '+key for key in required if key not in ids]
for icon in manifest['icons']:
    tree=ET.parse(BASE/icon['svg'])
    if any(n.tag.endswith('text') or n.tag.endswith('image') for n in tree.iter()):errors.append('non-vector content: '+icon['id'])
    image=Image.open(BASE/icon['png']).convert('RGBA')
    expected=icon['pixels']
    if image.size!=(expected,expected):errors.append('size: '+icon['id'])
    alpha=image.getchannel('A')
    if alpha.getextrema()!=(0,255) or not alpha.getbbox():errors.append('alpha: '+icon['id'])
    if icon['category']=='cursor':
        hi=Image.open(BASE/icon['png'].replace('.png','_2x.png'))
        if hi.size!=(64,64):errors.append('cursor 2x: '+icon['id'])
    else:
        bounds=alpha.point(lambda a:255 if a>32 else 0).getbbox()
        if bounds and (min(bounds[:2])<1 or max(bounds[2:])>expected-1):errors.append('clipped: '+icon['id'])
for folder,field,prefix in [('items','item_id',''),('relics','relic_id',''),('battle_relics','relic_id',''),('battle_supplies','supply_id','supply_'),('professions','profession_id','profession_'),('bonds','bond_id','bond_')]:
    for file in (ROOT/'resources'/folder).glob('*.tres'):
        text=file.read_text(encoding='utf-8')
        m=re.search(r'^'+field+r' = &?"([^"]+)"',text,re.M)
        if m and prefix+m[1] not in ids:errors.append('resource coverage: '+prefix+m[1])
for file in (ROOT/'resources/characters').glob('*.tres'):
    text=file.read_text(encoding='utf-8')
    keys=re.findall(r'^(?:ultimate_id|character_skill_id|trait_id) = &?"([^"]+)"',text,re.M)
    keys+=re.findall(r'&"([^"]+)"','\n'.join(line for line in text.splitlines() if line.startswith('passive_ids =')))
    for key in keys:
        current_skills.add(key)
        if key not in ids:errors.append('skill coverage: '+key)
names_text=(ROOT/'scripts/combat/SkillRegistry.gd').read_text(encoding='utf-8').split('const NAMES := {',1)[1].split('\n}',1)[0]
skill_names=dict(re.findall(r'"([^"]+)": "([^"]+)"',names_text))
skill_hashes=set()
for key in current_skills & ids:
    entry=entries[key]
    if entry['label']!=skill_names.get(key) or entry['planned'] or entry['category']!='skill':
        errors.append('current skill metadata: '+key)
    skill_hashes.add(hashlib.sha256((BASE/entry['png']).read_bytes()).hexdigest())
if len(current_skills)!=27 or len(skill_hashes)!=27:errors.append('current skill uniqueness/count')
legacy=json.loads((BASE/'legacy_archive.json').read_text(encoding='utf-8'))
workspace=ROOT/'build/icons_v2_legacy_workspace.json'
workspace_legacy=json.loads(workspace.read_text(encoding='utf-8')) if workspace.exists() else {}
checked_legacy=workspace_legacy|legacy
for name,sha in checked_legacy.items():
    p=ROOT/name
    if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=sha:errors.append('legacy changed: '+name)
for p in list((ROOT/'scripts').rglob('*.gd'))+list((ROOT/'scenes').rglob('*.tscn'))+list((ROOT/'resources').rglob('*.tres'))+[ROOT/'project.godot',ROOT/'assets/ui/ui_theme.tres']:
    for path in re.findall(r'res://assets/ui/(?:icons|cursors)/[^"\s]+',p.read_text(encoding='utf-8')):
        if '/icons/v2/' not in path:errors.append('legacy runtime reference: '+str(p.relative_to(ROOT))+': '+path)
preview=ROOT/'docs/ui_concept/icons_v2.html'
for path in re.findall(r'src="([^"]+)"',preview.read_text(encoding='utf-8')):
    if not (preview.parent/path).is_file():errors.append('preview path: '+path)
report={'count':len(manifest['icons']),'categories':dict(Counter(i['category'] for i in manifest['icons'])),'current_skill_icons':len(current_skills),'distinct_current_skill_pngs':len(skill_hashes),'legacy_files_preserved':len(checked_legacy),'tracked_legacy_files_preserved':len(legacy),'workspace_snapshot_checked':workspace.exists(),'errors':errors}
(ROOT/'docs/ui_concept/icons_v2_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
raise SystemExit(1 if errors else 0)

"""Finalize same-rig hero portraits and the measured authoring manifest.

Run after native capture_battle_visuals.tscn; no external art dependency.
"""
from pathlib import Path
import argparse, hashlib, json
from copy import deepcopy
from generate_battle_visuals import ACTORS
from PIL import Image, ImageDraw
from build_hero_expansion_previews import generate as generate_hero_portraits

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--frames-dir', type=Path, default=ROOT / 'build/battle_visual_frames_latest')
parser.add_argument('--hero-frames-dir', type=Path, default=ROOT / 'build/hero_models_skin_0.9.8.2')
parser.add_argument('--preview-dir', type=Path, default=ROOT / 'build/verify_heroes_0.9.8.2')
args = parser.parse_args()
base = ROOT / 'assets/battle_visuals'
frames = json.loads((args.frames_dir / 'frames.json').read_text(encoding='utf-8'))
assert not frames['failures'] and len(frames['frames']) >= 72
portrait = Image.open(args.frames_dir / 'liu_bei_portrait_frame.png').convert('RGBA')
portrait = portrait.crop((151,75,379,303)).resize((160,160), Image.Resampling.LANCZOS)
background = Image.new('RGBA',(160,160),(61,111,77,255)); background.alpha_composite(portrait)
mask = Image.new('L',(160,160)); ImageDraw.Draw(mask).ellipse((2,2,157,157),fill=255)
background.putalpha(mask)
ImageDraw.Draw(background).ellipse((2,2,157,157),outline=(234,215,163,255),width=3)
background.save(base / 'liu_bei/avatar.png')
manifest = json.loads((base / 'manifest.json').read_text(encoding='utf-8'))
manifest['version'] = 2
manifest['program'] = frames['program']
manifest['actors'] = deepcopy(ACTORS)
manifest['license'] = 'Original project enemy/map art; Guan Yu and original D69 #158/#072/#312/#314 heroes use ART_ASSETS section 6; see each hero provenance.json.'
manifest['native_measurements'] = [row for row in frames['frames'] if row['pose']=='Idle' and row['facing']==1]
manifest['portrait'] = {'source':'native Liu Bei Idle frame at scale 2','crop':[151,75,379,303],'size':[160,160]}
manifest['portraits'] = generate_hero_portraits(args.hero_frames_dir, args.preview_dir)
heads = {'yellow_turban_soldier':136,'yellow_turban_cavalry':170,'yellow_turban_sergeant':143,'yellow_turban_general':145}
for id,actor in manifest['actors'].items():
 actor['native_facing'] = int(actor.get('native_facing', 1))
 if id in heads: actor['top'] = heads[id]
 if id=='yellow_turban_cavalry': actor['width'] = 177
 if id=='liu_bei': actor.update(attack_time_scale=.5333/.11,critical_start=.3,critical_time_scale=(1.3667-.3)/.33,ult_time_scale=1.4667/.55)
manifest['files'] = {p.relative_to(base).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(base.rglob('*')) if p.is_file() and 'variants' not in p.relative_to(base).parts and (p.suffix in ['.svg','.png','.atlas','.spine-json','.tres'] or (any(part.startswith('d69_') for part in p.parts) and p.suffix != '.import'))}
manifest['export'] = 'Packed actor atlases/rigs, map PNGs, portrait and manifest; authoring sources and abandoned variants stay in repository.'
(base/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8',newline='\n')
print('BATTLE_MANIFEST_FINALIZED',len(manifest['files']),'files,',len(manifest['native_measurements']),'native measurements')

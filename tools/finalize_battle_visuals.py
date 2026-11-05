"""Finalize the same-rig Liu Bei portrait and measured authoring manifest.

Run after native capture_battle_visuals.tscn; no external art dependency.
"""
from pathlib import Path
import argparse, hashlib, json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--frames-dir', type=Path, default=ROOT / 'build/battle_visual_frames_latest')
args = parser.parse_args()
base = ROOT / 'assets/battle_visuals'
frames = json.loads((args.frames_dir / 'frames.json').read_text(encoding='utf-8'))
assert not frames['failures'] and len(frames['frames']) == 72
portrait = Image.open(args.frames_dir / 'liu_bei_portrait_frame.png').convert('RGBA')
portrait = portrait.crop((182,99,328,245)).resize((160,160), Image.Resampling.LANCZOS)
background = Image.new('RGBA',(160,160),(61,111,77,255)); background.alpha_composite(portrait)
mask = Image.new('L',(160,160)); ImageDraw.Draw(mask).ellipse((2,2,157,157),fill=255)
background.putalpha(mask)
ImageDraw.Draw(background).ellipse((2,2,157,157),outline=(234,215,163,255),width=3)
background.save(base / 'liu_bei/avatar.png')
manifest = json.loads((base / 'manifest.json').read_text(encoding='utf-8'))
manifest['version'] = 2
manifest['program'] = '0.9.8.0'
manifest['native_measurements'] = [row for row in frames['frames'] if row['pose']=='Idle' and row['facing']==1]
manifest['portrait'] = {'source':'native Liu Bei Idle frame at scale 2','crop':[182,99,328,245],'size':[160,160]}
heads = {'yellow_turban_soldier':136,'yellow_turban_cavalry':170,'yellow_turban_sergeant':143,'yellow_turban_general':145}
for id,actor in manifest['actors'].items():
 actor['native_facing'] = 1
 if id in heads: actor['top'] = heads[id]
 if id=='yellow_turban_cavalry': actor['width'] = 177
 if id=='liu_bei': actor.update(hit=.11,attack_duration=.33,ult_hit=0,ult_duration=.55)
manifest['files'] = {p.relative_to(base).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(base.rglob('*')) if p.is_file() and p.suffix in ['.svg','.png','.atlas','.spine-json','.tres']}
manifest['export'] = 'Packed actor atlases/rigs, map PNGs, portrait and manifest; source SVG/part PNGs stay in repository.'
(base/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('BATTLE_MANIFEST_FINALIZED',len(manifest['files']),'files, six native measurements')

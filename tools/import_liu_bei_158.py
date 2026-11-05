"""Import the user's unchanged D69 #158 as Liu Bei; only adapt Spine format.

First run: --source <158 directory>. Later runs rebuild from archived inputs.
No recoloring, pose edits, added bones, renamed animations or retiming in JSON.
"""
from pathlib import Path
import argparse, copy, hashlib, json, shutil
from spine_upgrade_38_to_43 import upgrade

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/battle_visuals/liu_bei'
SOURCE = DEST / 'source/d69_158'

def convert(source):
    data = copy.deepcopy(source)
    deforms = {name: anim.pop('deform', {}) for name, anim in data['animations'].items()}
    upgrade(data)
    for bone in data['bones']:
        if 'transform' in bone:
            bone['inherit'] = bone.pop('transform')
    for name, skins in deforms.items():
        result = {}
        for slots in skins.values():
            for slot, attachments in slots.items():
                for attachment, frames in attachments.items():
                    for index, frame in enumerate(frames):
                        curve = frame.get('curve')
                        if isinstance(curve, (int, float)) and index + 1 < len(frames):
                            at = frame.get('time', 0)
                            delta = frames[index + 1].get('time', 0) - at
                            frame['curve'] = [at + curve * delta, frame.get('c2', 0), at + frame.get('c3', 1) * delta, frame.get('c4', 1)]
                        for key in ['c2', 'c3', 'c4']:
                            frame.pop(key, None)
                    result.setdefault('default', {}).setdefault(slot, {})[attachment] = {'deform': frames}
        if result:
            data['animations'][name]['attachments'] = result
    return data

def generate(source=None):
    SOURCE.mkdir(parents=True, exist_ok=True)
    names = ['Hero_LiBai_A.json', 'Hero_LiBai_A.atlas', 'Hero_LiBai_A.png', '免责声明.txt']
    if source:
        for name in names:
            shutil.copy2(Path(source) / name, SOURCE / name)
    original = json.loads((SOURCE / names[0]).read_text(encoding='utf-8-sig'))
    data = convert(original)
    assert len(data['bones']) == len(original['bones']) == 46
    assert data['slots'] == original['slots']
    assert set(data['animations']) == set(original['animations'])
    shutil.copy2(SOURCE / names[1], DEST / 'liu_bei.atlas')
    shutil.copy2(SOURCE / names[2], DEST / names[2])
    (DEST / 'liu_bei.spine-json').write_text(json.dumps(data, separators=(',', ':')), encoding='utf-8')
    (DEST / 'liu_bei-data.tres').write_text('''[gd_resource type="SpineSkeletonDataResource" load_steps=3 format=3]
[ext_resource type="SpineAtlasResource" path="res://assets/battle_visuals/liu_bei/liu_bei.atlas" id="1"]
[ext_resource type="SpineSkeletonFileResource" path="res://assets/battle_visuals/liu_bei/liu_bei.spine-json" id="2"]
[resource]
atlas_res = ExtResource("1")
skeleton_file_res = ExtResource("2")
default_mix = 0.08
''', encoding='utf-8', newline='\n')
    provenance = {'identity': 'D69 #158 / Hero_LiBai_A', 'usage': 'User-selected original visual for Liu Bei; ART_ASSETS section 6',
                  'adaptation': 'Spine 3.8 to 4.3 format only; original images, slots, bones and animation poses/times retained',
                  'bones': 46, 'slots': 36, 'animations': list(original['animations']),
                  'files': {name: hashlib.sha256((SOURCE / name).read_bytes()).hexdigest() for name in names}}
    (DEST / 'provenance.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2), encoding='utf-8', newline='\n')
    print('LIU_ORIGINAL_158_IMPORTED: 46 bones; original atlas and PNG bytes retained')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path)
    generate(parser.parse_args().source)

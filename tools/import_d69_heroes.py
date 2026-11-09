"""Import user-selected original D69 #072, #312 and #314 without repainting.

First run with --source-root pointing to the supplied Spine collection.
Later runs use the committed source/d69_NNN inputs only.
"""
from pathlib import Path
import argparse, hashlib, json, shutil
from import_liu_bei_158 import convert

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/battle_visuals'
MODELS = {
    'diao_chan': {'number': '072', 'name': 'Hero_Diaochan_A', 'bones': 89, 'slots': 48, 'scale': .50,
                  'attack_start': .3333, 'attack_source_hit': .3333, 'attack_time_scale': 1.0, 'attack_duration': .6667,
                  'critical_start': .3333, 'critical_time_scale': .6667/.33, 'ultimate': 'Active_A', 'ult_duration': .7, 'ult_time_scale': 1.2333/.7},
    'zhao_yun': {'number': '312', 'name': 'Hero_ZhaoYun_A', 'bones': 97, 'slots': 47, 'scale': .46, 'root_motion_bone': 'Character', 'root_motion_scale': .08,
                 'attack_start': 0.0, 'attack_source_hit': .6333, 'attack_time_scale': .6333/.11, 'attack_duration': .9333*.11/.6333,
                 'critical_start': .4667, 'critical_time_scale': .5333/.33, 'ultimate': 'Active_A', 'ult_duration': .6, 'ult_time_scale': 1.3333/.6},
    'zhuge_liang': {'number': '314', 'name': 'Hero_ZhugeLiang_A', 'bones': 56, 'slots': 30, 'scale': .47,
                    'attack_start': .4333, 'attack_source_hit': .4333, 'attack_time_scale': 1.0, 'attack_duration': .3334,
                    'critical_start': .4667, 'critical_time_scale': .5333/.33, 'ultimate': 'Appear', 'ult_duration': .65, 'ult_time_scale': 1.3333/.65},
}

def actor_specs():
    return {id: dict(spec, skin="default", foot=8, native_facing=-1, hit=.11, ult_hit=0, critical='Critical', role='hero', source='D69 #'+spec['number'])
            for id, spec in MODELS.items()}

def generate(source_root=None):
    for id, spec in MODELS.items():
        folder = BASE / id
        archived = folder / 'source' / ('d69_' + spec['number'])
        archived.mkdir(parents=True, exist_ok=True)
        names = [spec['name'] + suffix for suffix in ['.png', '.atlas', '.json']] + ['免责声明.txt']
        if source_root:
            matches = list(Path(source_root).glob(spec['number'] + '*'))
            assert len(matches) == 1, f'Ambiguous source for {id}: {matches}'
            for name in names:
                shutil.copy2(matches[0] / name, archived / name)
        original = json.loads((archived / names[2]).read_text(encoding='utf-8-sig'))
        assert len(original['skins']) == 1, 'This importer expects a single original skin.'
        data = convert(original)
        assert len(data['bones']) == len(original['bones']) == spec['bones']
        assert data['slots'] == original['slots'] and len(data['slots']) == spec['slots']
        assert set(data['animations']) == set(original['animations'])
        for name, anim in original['animations'].items():
            assert data['animations'][name].get('events') == anim.get('events')
        shutil.copy2(archived / names[0], folder / names[0])
        shutil.copy2(archived / names[1], folder / (id + '.atlas'))
        (folder / (id + '.spine-json')).write_text(json.dumps(data, separators=(',', ':')), encoding='utf-8')
        (folder / (id + '-data.tres')).write_text(f'''[gd_resource type="SpineSkeletonDataResource" load_steps=3 format=3]
[ext_resource type="SpineAtlasResource" path="res://assets/battle_visuals/{id}/{id}.atlas" id="1"]
[ext_resource type="SpineSkeletonFileResource" path="res://assets/battle_visuals/{id}/{id}.spine-json" id="2"]
[resource]
atlas_res = ExtResource("1")
skeleton_file_res = ExtResource("2")
default_mix = 0.08
''', encoding='utf-8', newline='\n')
        provenance = {'identity': 'D69 #' + spec['number'] + ' / ' + spec['name'], 'character_id': id,
                      'usage': 'User-selected original visual; ART_ASSETS section 6',
                      'adaptation': 'Spine 3.8 to 4.3 format only; original PNG/atlas, bones, slots and animation poses/times retained',
                      'bones': spec['bones'], 'slots': spec['slots'], 'animations': list(original['animations']),
                      'files': {name: hashlib.sha256((archived / name).read_bytes()).hexdigest() for name in names}}
        (folder / 'provenance.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2), encoding='utf-8', newline='\n')
        print('D69_HERO_IMPORTED', id, spec['number'], spec['bones'], 'bones')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source-root', type=Path)
    generate(parser.parse_args().source_root)

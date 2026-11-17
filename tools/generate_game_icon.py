"""Generate only the application emblem; leave the other icon assets untouched."""
from pathlib import Path
import argparse
import html
import json
import subprocess
from PIL import Image
from game_icon_art import build_game_crest, build_game_ico_frames, DESCRIPTION
from generate_icons_v2 import write_generated_text, write_generated_image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/ui/icons/v2'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='F:/Godot/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
    args = parser.parse_args()
    manifest = json.loads((OUT / 'manifest.json').read_text(encoding='utf-8'))
    entries = [item for item in manifest['icons'] if item['id'] == 'game_crest']
    if len(entries) != 1:
        raise RuntimeError('Expected one game_crest record')
    entry = entries[0]
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 96 96"><title>' + html.escape(entry['label']) + '</title>' + build_game_crest() + '</svg>\n'
    write_generated_text(OUT / entry['svg'], svg)
    entry['description'] = DESCRIPTION
    write_generated_text(OUT / 'manifest.json', json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    subprocess.run([args.godot, '--headless', '--path', str(ROOT), '--script', str(ROOT / 'tools/render_icons_v2.gd'), '--', '--icons=game_crest'], check=True)
    crest = Image.open(OUT / entry['png']).convert('RGBA')
    sizes = [(n,n) for n in (16,24,32,48,64,128,256)]
    write_generated_image(crest, OUT / 'game_crest.ico', append_images=build_game_ico_frames(crest), sizes=sizes)
    print('GAME_ICON_GENERATED: SVG, PNG256, ICO7')


if __name__ == '__main__':
    main()

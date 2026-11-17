"""Render the bright, flame-free emblem and archive its actual-size comparison."""
from pathlib import Path
import argparse, subprocess
from PIL import Image, ImageDraw, ImageFont
from game_icon_art import build_game_crest

ROOT=Path(__file__).resolve().parents[1]
ARCHIVE=ROOT/'docs/ui_concept/game_icon_0.10.1.4'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',default='F:/Godot/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe')
    args=parser.parse_args()
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 96 96">'+build_game_crest()+'</svg>\n'
    (ARCHIVE/'bright.svg').write_text(svg,encoding='utf-8',newline='\n')
    subprocess.run([args.godot,'--headless','--path',str(ROOT),'--script',str(ROOT/'tools/render_game_icon_previews.gd'),'--','res://docs/ui_concept/game_icon_0.10.1.4/bright.svg'],check=True)
    sheet=Image.new('RGB',(780,700),'#faf4e6')
    draw=ImageDraw.Draw(sheet)
    font='C:/Windows/Fonts/msyh.ttc'
    for column,(name,label) in enumerate([('before','上一版'),('bright','明亮城楼 · 去火')]):
        x=column*390
        draw.text((x+27,18),label,font=ImageFont.truetype(font,25),fill='#293e43')
        master=Image.open(ARCHIVE/(name+'_1024.png')).convert('RGBA')
        large=master.resize((330,330),Image.Resampling.LANCZOS)
        sheet.paste(large,(x+30,55),large)
        png=Image.open(ARCHIVE/(name+'.png')).convert('RGBA')
        for row,size in enumerate((64,48,32,16)):
            y=405+row*69
            thumb=png.resize((size,size),Image.Resampling.LANCZOS)
            sheet.paste(thumb,(x+95+(64-size)//2,y+(64-size)//2),thumb)
            draw.text((x+200,y+19),str(size)+' px',font=ImageFont.truetype(font,17),fill='#415e61')
    sheet.save(ARCHIVE/'comparison.png')
    print('BRIGHT_GAME_ICON_PREVIEW_OK')

if __name__=='__main__':main()

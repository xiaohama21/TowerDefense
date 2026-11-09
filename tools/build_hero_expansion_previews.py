"""Build reproducible portraits and a same-scale sheet from native Spine frames."""
from pathlib import Path
import argparse, json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
PORTRAITS = {
    'guan_yu': {'crop': [666, 505, 862, 701], 'color': '#3d6f4d'},
    'diao_chan': {'crop': [664, 504, 904, 744], 'color': '#695077'},
    'zhao_yun': {'crop': [644, 507, 904, 767], 'color': '#405e7c'},
    'zhuge_liang': {'crop': [620, 448, 884, 712], 'color': '#826346'},
}

def avatar_path(id):
    relative = 'portraits/guan_yu.png' if id == 'guan_yu' else id+'/avatar.png'
    return ROOT/'assets/battle_visuals'/relative

def generate(frames_dir, output, portrait_frames=None):
    metadata = json.loads((frames_dir / 'frames.json').read_text(encoding='utf-8'))
    assert metadata['program'] == '0.9.8.2' and not metadata['clipped']
    output.mkdir(parents=True, exist_ok=True)
    for id, spec in PORTRAITS.items():
        source = id + '_right_Idle_00.png'
        source_path = frames_dir / source
        if id == 'diao_chan':
            portrait_frames = portrait_frames or ROOT/'build/hero_portraits_0.9.8.2'
            source_path = portrait_frames / 'diao_chan_portrait.png'
            spec['capture'] = json.loads((portrait_frames/'capture.json').read_text(encoding='utf-8'))
        portrait = Image.open(source_path).convert('RGBA').crop(spec['crop']).resize((160,160), Image.Resampling.LANCZOS)
        background = Image.new('RGBA', (160,160), spec['color'])
        background.alpha_composite(portrait)
        mask = Image.new('L',(160,160))
        ImageDraw.Draw(mask).ellipse((2,2,157,157),fill=255)
        background.putalpha(mask)
        ImageDraw.Draw(background).ellipse((2,2,157,157),outline=(234,215,163,255),width=3)
        avatar_path(id).parent.mkdir(parents=True, exist_ok=True)
        background.save(avatar_path(id))
        spec.update(source=source_path.name, size=[160,160], render_magnification=4)
    (output/'portraits.json').write_text(json.dumps(PORTRAITS,indent=2),encoding='utf-8',newline='\n')
    font_path = Path('C:/Windows/Fonts/msyh.ttc')
    font = ImageFont.truetype(str(font_path),26) if font_path.exists() else ImageFont.load_default()
    small = ImageFont.truetype(str(font_path),18) if font_path.exists() else font
    sheet = Image.new('RGB',(1640,600),'#182e40')
    draw = ImageDraw.Draw(sheet)
    draw.text((32,24),'原版模型 · 游戏同尺度（放大 3 倍）',font=font,fill='#f0dfb5')
    labels = [('guan_yu','关羽'),('liu_bei','刘备 · 158'),('diao_chan','貂蝉 · 072'),('zhao_yun','赵云 · 312'),('zhuge_liang','诸葛亮 · 314')]
    for i,(id,label) in enumerate(labels):
        frame = Image.open(frames_dir/(id+'_right_Idle_00.png')).convert('RGBA')
        crop = frame.crop((548,416,1096,816)).resize((411,300),Image.Resampling.LANCZOS)
        sheet.paste(crop,(i*320-25,85),crop)
        draw.text((i*320+75,400),label,font=font,fill='white')
        if avatar_path(id).exists():
            avatar=Image.open(avatar_path(id)).resize((110,110),Image.Resampling.LANCZOS)
            sheet.paste(avatar,(i*320+105,453),avatar)
        else:
            draw.text((i*320+85,485),'现有模型参照',font=small,fill='#9bb5c6')
    sheet.save(output/'heroes_same_scale.png')
    avatars = Image.new('RGB',(1200,300),'#182e40')
    draw = ImageDraw.Draw(avatars)
    for i,(id,label) in enumerate(labels):
        avatar=Image.open(avatar_path(id))
        avatars.paste(avatar,(i*240+40,35),avatar)
        for x,size in [(50,44),(120,64)]:
            thumb=avatar.resize((size,size),Image.Resampling.LANCZOS)
            avatars.paste(thumb,(i*240+x,205),thumb)
        draw.text((i*240+50,0),label,font=small,fill='white')
    avatars.save(output/'portraits_sizes.png')
    print('HERO_PORTRAITS_READY', output)
    return PORTRAITS

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--frames-dir',type=Path,default=ROOT/'build/hero_models_skin_0.9.8.2')
    parser.add_argument('--output',type=Path,default=ROOT/'build/verify_heroes_0.9.8.2')
    parser.add_argument('--portrait-frames',type=Path,default=ROOT/'build/hero_portraits_0.9.8.2')
    args=parser.parse_args()
    generate(args.frames_dir,args.output,args.portrait_frames)

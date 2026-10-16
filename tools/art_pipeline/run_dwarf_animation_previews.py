"""MCP preview renderer + compact contact sheets and looping video reviews."""
import argparse
import json
from pathlib import Path
import subprocess
import shutil
from PIL import Image, ImageDraw, ImageFont
from blender_mcp_client import execute
from dwarf_troop_assets import ROOT, OUT, WORK, FAMILIES

parser = argparse.ArgumentParser()
parser.add_argument('--families', nargs='*')
parser.add_argument('--contacts-only', action='store_true')
parser.add_argument('--assemble-only', action='store_true')
parser.add_argument('--tier', type=int, default=2)
args = parser.parse_args()
font_path = Path('C:/Windows/Fonts/segoeui.ttf')
font = ImageFont.truetype(str(font_path), 26)
dest = ROOT/'docs/previews/dwarf_troops/animations'; dest.mkdir(parents=True, exist_ok=True)
(dest/'.gdignore').touch()
source = ROOT/'tools/art_pipeline/render_dwarf_animation_previews.py'
for family in FAMILIES:
    if args.families and family not in args.families: continue
    label = family if args.tier == 2 else family+'_tier'+str(args.tier)
    if not args.assemble_only:
        execute(f'''import sys
from pathlib import Path
source=Path({str(source)!r}); sys.path.insert(0,str(source.parent))
ns={{'__file__':str(source)}}
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),ns)
ns['render_family']({family!r},contacts_only={args.contacts_only!r},tier={args.tier!r})
result={{'family':{family!r},'previews':'rendered'}}
''')
    manifest = json.loads((OUT/'animations'/(family+'_manifest.json')).read_text(encoding='utf-8'))
    for clip, info in manifest['clips'].items():
        fps = manifest['fps']
        frames = [1, 1+round(9*fps/24), info['impact_frame'], min(info['frames'], info['impact_frame']+round(6*fps/24)), info['frames']] if clip == 'attack' else [1, 1+(info['frames']-1)//4, 1+(info['frames']-1)//2, 1+3*(info['frames']-1)//4, info['frames']]
        sheet = Image.new('RGB', (560*5, 622), '#252b2e')
        draw = ImageDraw.Draw(sheet)
        for index, frame in enumerate(frames):
            path = WORK/'animation_frames'/label/clip/f'{frame:04d}.png'
            sheet.paste(Image.open(path).convert('RGB'), (index*560, 52))
            draw.text((index*560+20, 10), f'{FAMILIES[family][0]} • {clip} • quadro {frame}', font=font, fill='#e8e1cf')
        sheet.save(dest/f'{label}_{clip}_contact.jpg', quality=91)
        if args.contacts_only: continue
        sequence = [Image.open(WORK/'animation_frames'/label/clip/f'{f:04d}.png').convert('RGB') for f in range(1, info['frames'], 2)]
        sequence[0].save(dest/f'{label}_{clip}.webp', save_all=True, append_images=sequence[1:], duration=round(2000/fps), loop=0, quality=82)
    print('DWARF_PREVIEWS_DONE '+family, flush=True)

"""Encode deterministic Godot animation captures into review GIFs."""
from pathlib import Path
import argparse
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--race',choices=['human','elf','orc','dwarf'],default='human')
RACE=parser.parse_args().race; FAMILY={'human':'humans','elf':'elves','orc':'orcs','dwarf':'dwarves'}[RACE]
SOURCE=ROOT/f'art_source/{RACE}_builder_review/animation_frames'
OUT=ROOT/f'assets/generated/{FAMILY}/{RACE}_builder_v1/previews'
for clip,expected in [('idle',72),('walk',36),('work',72)]:
    files=sorted((SOURCE/clip).glob('*.png')); assert len(files)==expected,(clip,len(files))
    images=[]
    for path in files:
        with Image.open(path) as source:
            images.append(source.convert('RGB').quantize(colors=128))
    images[0].save(OUT/(clip+'.gif'),save_all=True,append_images=images[1:],duration=40,loop=0,disposal=2,optimize=False)
    print(str(OUT/(clip+'.gif')))

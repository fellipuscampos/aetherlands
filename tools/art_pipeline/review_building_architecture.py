"""Make contact sheets from existing renders; no assets are modified."""
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art_source/building_architecture_review'
OUT.mkdir(parents=True, exist_ok=True)

def sheets(suffix='before'):
    for civ in ('humans', 'elves', 'dwarves', 'orcs'):
        items = sorted((ROOT/'assets/generated'/civ/'buildings').glob('*/previews/three_quarter.png'))
        canvas = Image.new('RGB', (1500, ((len(items)+4)//5)*265), (24,28,32))
        draw = ImageDraw.Draw(canvas)
        for i, path in enumerate(items):
            im = ImageOps.contain(Image.open(path).convert('RGB'), (295,230))
            canvas.paste(im, ((i%5)*300, (i//5)*265))
            draw.text(((i%5)*300+3, (i//5)*265+234), path.parent.parent.name.replace('_hex_v1','').replace('_hex_v2',''), fill='white')
        canvas.save(OUT/(civ+'_'+suffix+'.jpg'))
        print(civ, len(items), flush=True)

if __name__ == '__main__':
    import sys
    sheets(sys.argv[1] if len(sys.argv)>1 else 'before')

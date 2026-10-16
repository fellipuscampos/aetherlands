"""Package generated terrain art as small indexed-palette game textures."""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/terrain_pixel_review'
DEST=ROOT/'assets/textures/terrain/pixel_v1'; DEST.mkdir(parents=True,exist_ok=True)
SOURCE=WORK/'sources'; SOURCE.mkdir(exist_ok=True)
generation=json.loads((WORK/'generation_manifest.json').read_text(encoding='utf-8'))
assert len(generation['images'])==15
rows=[]
for layer,row in enumerate(generation['images']):
    original=SOURCE/(row['stem']+'_source.png')
    if Path(row['source']).exists(): shutil.copy2(row['source'],original)
    assert original.exists(), 'Missing retained generation source: '+str(original)
    with Image.open(original) as source:
        assert source.width==source.height
        source_size=source.size
        # Nearest resampling and no dithering keep one uniform pixel grid.
        image=source.convert('RGB').resize((128,128),Image.Resampling.NEAREST)
        image=image.quantize(colors=24,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert('RGB')
    path=DEST/(row['stem']+'_albedo.png'); image.save(path,optimize=True)
    pixels=np.array(image,dtype=float)
    interior_x=np.mean(abs(np.diff(pixels,axis=1))); interior_y=np.mean(abs(np.diff(pixels,axis=0)))
    edge_x=np.mean(abs(pixels[:,0]-pixels[:,-1])); edge_y=np.mean(abs(pixels[0]-pixels[-1]))
    # Compare the wrap boundary with ordinary cuts through the material:
    # identical opposite texels aren't required for a discrete periodic tile.
    assert edge_x/max(interior_x,1)<3.0 and edge_y/max(interior_y,1)<3.0,(row['stem'],edge_x,edge_y)
    normalized=pixels/255
    linear=np.where(normalized<=.04045,normalized/12.92,((normalized+.055)/1.055)**2.4)
    luma=float(np.mean(linear@np.array([.2126,.7152,.0722])))
    rows.append(dict(stem=row['stem'],name=row['name'],layer=layer if layer<14 else None,path=path.relative_to(ROOT).as_posix(),source=original.relative_to(ROOT).as_posix(),source_resolution=list(source_size),resolution=[128,128],colors=len(image.getcolors(16384)),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),bytes=path.stat().st_size,linear_mean_luma=luma,wrap_boundary_ratio=[round(edge_x/max(interior_x,1),3),round(edge_y/max(interior_y,1),3)]))
manifest=dict(stage='pixel_terrain_v1',generator='built-in image_gen',textures=15,array_layers=14,pixels_per_world_unit=64,repeat_world_units=2,filter='nearest_mipmap',palette_colors_maximum=24,assets=rows)
(WORK/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(DEST/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
sheet=Image.new('RGB',(1500,960),(27,32,36)); draw=ImageDraw.Draw(sheet)
try: font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',19)
except OSError: font=ImageFont.load_default()
for index,row in enumerate(rows):
    x=(index%5)*300+22; y=(index//5)*320+18
    with Image.open(ROOT/row['path']) as tile:
        sheet.paste(tile.resize((256,256),Image.Resampling.NEAREST),(x,y))
    draw.text((x,y+266),row['name'],font=font,fill=(219,228,225))
sheet.save(WORK/'terrain_pixel_contact_sheet.png')
print(json.dumps(dict(status='PASS',textures=len(rows),runtime_png_bytes=sum(r['bytes'] for r in rows),largest_wrap_ratio=max(max(r['wrap_boundary_ratio']) for r in rows))))

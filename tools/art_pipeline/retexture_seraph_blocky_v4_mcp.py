"""Apply the image-generated reference mosaic to the six approved wings."""
import bpy, math, hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector, Euler

st=bpy.app.driver_namespace['seraph_blocky_v4']
OUT=Path(st['out']); parts=st['parts']; islands=st['islands']; SIZE=st['atlas']
before=[tuple(tuple(v.co) for v in o.data.vertices) for o in parts]
builder=(OUT.parents[3]/'tools/art_pipeline/build_seraph_blocky_v4_mcp.py').read_text(encoding='utf-8')
DENSITY=64; PAD=2
code=builder[builder.index('palette={'):builder.index('images=[]')]
exec(code)
for im,data in zip(st['images'],(pixels,energy)):
    im.pixels.foreach_set(data.reshape(-1)); im.save(); im.pack()
assert before==[tuple(tuple(v.co) for v in o.data.vertices) for o in parts]
st['scene']['wing_texture']='Irregular ivory, pale-grey and taupe pixel mosaic sampled from an image-generated map using the supplied reference.'
st['camera'].data.ortho_scale=6.4
st['scene'].frame_set(1)
st['scene'].render.filepath=str(OUT/'previews/three_quarter.png')
bpy.ops.render.render(write_still=True)
result={'geometry_unchanged':True,'reference_mosaic':True,'atlas':SIZE,'preview':str(OUT/'previews/three_quarter.png')}

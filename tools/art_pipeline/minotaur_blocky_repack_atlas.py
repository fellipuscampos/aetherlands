"""Replace the packed atlas inside a saved Minotaur .blend with the atlas PNG on
disk (minotaur_blocky_v1_atlas.png), then save. Only the image data changes.
Run headless:  blender -b --factory-startup <file.blend> --python tools/art_pipeline/minotaur_blocky_repack_atlas.py
Why: updating pixels of an already-packed image and calling pack() kept the OLD
packed bytes, so saved files/GLBs carried a stale atlas that no longer matched the UVs.
"""
import bpy
import hashlib
from pathlib import Path

def digest(image): return hashlib.md5(bytes(round(v*255) for v in image.pixels[:])).hexdigest()
bpy.context.preferences.filepaths.save_version=0   # do not overwrite the user's .blend1 backups
disk=Path(bpy.data.filepath).parent/'minotaur_blocky_v1_atlas.png'
reference=bpy.data.images.load(str(disk),check_existing=False); want=digest(reference); bpy.data.images.remove(reference)
image=bpy.data.images['Minotaur_Blocky_V1_PixelAtlas']
before=digest(image)
if image.packed_file: image.unpack(method='REMOVE')
image.filepath='//minotaur_blocky_v1_atlas.png'; image.reload(); image.pack()
image.colorspace_settings.name='sRGB'
after=digest(image)
assert after==want,(after,want)
bpy.ops.wm.save_mainfile(compress=True)
print('REPACKED',bpy.data.filepath,'changed' if before!=want else 'already-current')

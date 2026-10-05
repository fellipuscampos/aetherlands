"""Remove only venom-colored texels from the live MCP scene; preserve user deletions and UVs."""
import bpy
import json
import random
import hashlib
import shutil
from pathlib import Path
from datetime import datetime

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
OUT=ROOT/'assets/generated/spiders/giant_spider_v1'
scene=bpy.context.scene
assert scene.name=='Giant_Spider_V1'
assert bpy.context.mode=='OBJECT'
st=bpy.app.driver_namespace['spider']
old=bpy.data.images['Giant_Spider_V1_PixelAtlas']; width,height=old.size
assert (width,height)==(512,512)
def geometry_digest():
    payload=[]
    for o in sorted(scene.objects,key=lambda o:o.name):
        row=[o.name,o.type,list(map(list,o.matrix_world))]
        if o.type=='MESH':
            row += [[list(v.co) for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons],
                    [[list(v.uv) for v in layer.data] for layer in o.data.uv_layers]]
        payload.append(row)
    return hashlib.sha256(json.dumps(payload,sort_keys=True).encode()).hexdigest()
before=geometry_digest()
backup=ROOT/'art_source/giant_spider_v1'/('before_remove_green_'+datetime.now().strftime('%Y%m%d_%H%M%S'))
backup.mkdir(parents=True,exist_ok=True); (backup.parent/'.gdignore').write_text('',encoding='utf-8')
for filename in ('giant_spider_v1.blend','giant_spider_v1_atlas.png','giant_spider_v1_report.json'):
    if (OUT/filename).exists(): shutil.copy2(OUT/filename,backup/filename)
bpy.data.libraries.write(str(backup/'live_user_edits.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
original=list(old.pixels[:]); pixels=original.copy()
def green(k):
    r,g,b=original[k:k+3]
    return g>r*1.25 and g>b*1.5 and g>.2
mask={k for k in range(0,len(pixels),4) if green(k)}
assert mask,'No green pixels remain; nothing to change.'
# Execute only pure palette/painting definitions, never the model or UV writer.
code=(ROOT/'tools/art_pipeline/spider_paint_save.py').read_text(encoding='utf-8')
ns={'random':random}; exec('CHITIN='+code.split('\nCHITIN=',1)[1].split('\npixels=',1)[0],ns)
restored=set(); live=set(scene.objects)
for index,item in enumerate(st['islands']):
    try:
        if item['obj'] not in live: continue
        tile=ns['paint'](item,index)
    except ReferenceError:
        continue  # Deleted objects are deliberately not recreated.
    w,h=item['w'],item['h']; ox,oy=item['x'],item['y']; pad=st['pad']
    for y in range(-pad,h+pad):
        for x in range(-pad,w+pad):
            k=((oy+y)*width+ox+x)*4
            if k not in mask: continue
            rgb=tile[h-1-max(0,min(h-1,y))][max(0,min(w-1,x))]
            pixels[k:k+3]=[c/255 for c in rgb]; restored.add(k)
# Unused islands of deleted pieces retain their layout, but no green swatches.
for k in sorted(mask-restored):
    palette=ns['CHITIN']; rgb=palette[(k//4*1103515245+12345)%len(palette)]
    pixels[k:k+3]=[c/255 for c in rgb]
assert all(pixels[k:k+4]==original[k:k+4] for k in range(0,len(pixels),4) if k not in mask)
image=bpy.data.images.new('Giant_Spider_V1_Atlas_NoGreen',width=width,height=height,alpha=True)
image.colorspace_settings.name=old.colorspace_settings.name
image.pixels.foreach_set(pixels); image.update()
image.filepath_raw=str(OUT/'giant_spider_v1_atlas.png'); image.file_format='PNG'; image.save(); image.pack()
assert bytes(image.packed_file.data)==(OUT/'giant_spider_v1_atlas.png').read_bytes()
for mat in bpy.data.materials:
    if mat.use_nodes:
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image==old: node.image=image
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='IMAGE_EDITOR' and area.spaces.active.image==old: area.spaces.active.image=image
name=old.name; bpy.data.images.remove(old); image.name=name
assert before==geometry_digest(),'Scene geometry or UVs changed unexpectedly'
verified=list(image.pixels[:])
assert not any(verified[k+1]>verified[k]*1.25 and verified[k+1]>verified[k+2]*1.5 and verified[k+1]>.2 for k in range(0,len(pixels),4))
bpy.data.libraries.write(str(OUT/'giant_spider_v1.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
parts=[o for o in scene.objects if o.type=='MESH' and o.get('part')!='StudioGround']
report={'scope':'Texture only; live user geometry and UVs preserved',
        'green_texels_removed':len(mask),'restored_surface_texels':len(restored),
        'non_green_texels_unchanged':True,'geometry_uvs_unchanged':True,
        'packed_texture_matches_png':True,'live_mesh_parts':len(parts),
        'live_armatures':[o.name for o in scene.objects if o.type=='ARMATURE'],
        'backup':str(backup),'source':'giant_spider_v1.blend',
        'glb':'Existing GLB is from the previous revision; not re-exported during this texture-only edit.'}
(OUT/'texture_edit_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
result=report

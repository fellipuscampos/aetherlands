"""Refine the approved blocky asset, then metrically unwrap and paint each face.
Execute only inside the live Blender through blender_mcp_client.py.
"""
import bpy
import bmesh
import math
import json
import random
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
SOURCE=ROOT/'art_source/troll_blocky_v3'; OUT=ROOT/'assets/generated/trolls/troll_blocky_v3'
NAME='Troll_Blocky_V3_R2'; S=2.5/3.9
if NAME in bpy.data.scenes: raise RuntimeError('Refined scene already exists; preserve edits.')
old=bpy.data.scenes['Troll_Blocky_V3']
history=SOURCE/'history_before_refinement'; history.mkdir(exist_ok=True)
bpy.data.libraries.write(str(history/'troll_blocky_v3.blend'),{old},path_remap='RELATIVE',compress=True)
scene=bpy.data.scenes.new(NAME); bpy.context.window.scene=scene
with bpy.data.libraries.load(str(SOURCE/'troll_blocky_v3_blockout.blend')) as (src,dst):
    dst.collections=['Troll_Blocky_V3_01_CHARACTER']
parts=dst.collections[0]; parts.name=NAME+'_01_CHARACTER'; scene.collection.children.link(parts)
studio=bpy.data.collections.new(NAME+'_02_STUDIO'); scene.collection.children.link(studio)
for original in old.collection.children:
    if 'STUDIO' in original.name:
        for obj in original.objects:
            copy=obj.copy()
            if obj.data: copy.data=obj.data.copy()
            copy.name=NAME+'_'+obj.name.removeprefix('Troll_Blocky_V3_')
            studio.objects.link(copy)
            if copy.type=='CAMERA': scene.camera=copy
scene.world=old.world.copy()
scene.render.engine='CYCLES'; scene.cycles.samples=24; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.view_settings.view_transform='Standard'
scene.unit_settings.system='METRIC'; scene.render.fps=24
bone_specs=json.loads(old['bone_specs'])
clay=bpy.data.materials.new(NAME+'_TemporaryClay'); clay.diffuse_color=(.32,.45,.46,1)
objects={}
for obj in parts.objects:
    short=obj.name.removeprefix('Troll_Blocky_V3_').split('.')[0]
    obj.name=NAME+'_'+short; obj['part']=short; objects[short]=obj

# Reuse only the elementary cuboid/prism helpers from the approved blockout.
source=(ROOT/'tools/art_pipeline/troll_blocky_blockout.py').read_text(encoding='utf-8')
exec(source[source.index('def mesh('):source.index('# Three distinct')])

def remove(name):
    obj=objects.pop(name,None)
    if obj: bpy.data.objects.remove(obj,do_unlink=True)

for n in ['Neck','Ear_l','Ear_r','TuskBase_l','TuskBase_r','TuskTip_l','TuskTip_r',
          'Hand_r','Thumb_r','HideFront','HideBack','HideSide_l','HideSide_r',
          'Club_Handle','Club_Head','Club_End']:
    remove(n)

# Avoid coplanar overlap between jaw sides and head sides (black ray shadows).
for vertex in objects['Jaw'].data.vertices: vertex.co.x*=.86/.88
objects['Jaw'].data.update()

# Head directly nests into the shoulder girdle; no visible neck geometry.
# Flatten the former hump into a broad nape integrated with the head base.
remove('Back_Hump')
box('Nape',(0,.23,3.27),(1.25,.69,.29),'chest','skin')

def extrude_profile(name,outline,yfun,thickness,bone,region):
    n=len(outline)
    verts=[(x,yfun(x,z)+offset,z) for offset in (0,thickness) for x,z in outline]
    faces=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,bone,region,'extruded_polygon')

for side,suffix in [(1,'l'),(-1,'r')]:
    # Broad root penetrates the head side, with a thick tapered auricle.
    outline=[(side*x,z) for x,z in [(.38,3.38),(.57,3.41),(.91,3.68),
                                   (.86,3.75),(.53,3.69),(.38,3.68)]]
    extrude_profile('Ear_'+suffix,outline,lambda x,z:-.57+(abs(x)-.38)*.18,.16,'head','ear')
    # One continuous prism, planted inside the lower lip at the mouth corner.
    height_offset=0 if side==1 else -.055
    outline=[(side*x,z+(height_offset if z>3.4 else 0)) for x,z in
             [(.235,3.275),(.405,3.275),(.495,3.47),(.56,3.655),
              (.505,3.59),(.355,3.425),(.285,3.385)]]
    extrude_profile('Tusk_'+suffix,outline,lambda x,z:-1.055,.145,'jaw','bone')
    for j in range(3):
        box('Nail_'+suffix+str(j),(side*.49+(j-1)*.19,-.704,.14),(.155,.03,.13),'foot_'+suffix,'bone')
box('Mouth',(0,-.954,3.31),(.69,.07,.075),'head','mouth')
box('Buckle',(-.12,-.392,1.575),(.20,.04,.125),'pelvis','iron')

# Thick front hide flares away from the thighs and extends underneath the belt.
bone_specs['loincloth_front']=((0,-.37,1.54),(0,-.57,1.04),'pelvis')
bone_specs['loincloth_back']=((0,.43,1.52),(0,.56,1.09),'pelvis')
front=[(-.46,1.555),(.43,1.555),(.43,1.015),(.18,1.015),(.18,.97),
       (-.03,.97),(-.03,1.03),(-.18,1.03),(-.18,.99),(-.46,.99)]
extrude_profile('HideFront',front,lambda x,z:-.365-(1.55-z)*.52,.055,'loincloth_front','hide')
back=[(-.48,1.535),(.48,1.535),(.48,1.08),(.05,1.08),(.05,1.03),(-.48,1.03)]
extrude_profile('HideBack',back,lambda x,z:.41+(1.53-z)*.34,.045,'loincloth_back','hide')
for side,suffix in [(1,'l'),(-1,'r')]:
    # Slanted side panels sit outside the thigh envelope, attached under the belt.
    a=(side*.60,.07,1.49); b=(side*.80,.07,1.05)
    beam('HideSide_'+suffix,a,b,.052,.62,'pelvis','hide')

# A continuous square fist with an actual rectangular grip channel.
# The handle follows the channel axis, rather than crossing the palm diagonally.
grip=Vector((-1.46,-.09,1.185)); axis=Vector((0,-.97,-.24)).normalized()
u=Vector((1,0,0)); v=axis.cross(u).normalized()
outer=[(-.365,-.24),(.365,-.24),(.365,.24),(-.365,.24)]
inner=[(-.112,-.112),(.112,-.112),(.112,.112),(-.112,.112)]
verts=[]
for depth in (-.39,.39):
    for ring in (outer,inner):
        verts += [grip+axis*depth+u*x+v*z for x,z in ring]
faces=[]
for i in range(4):
    k=(i+1)%4
    faces += [(i,k,k+8,i+8),(i+4,i+12,k+12,k+4),
              (i,i+4,k+4,k),(i+8,k+8,k+12,i+12)]
mesh('Hand_r',verts,faces,'hand_r','hand','single_hollow_cuboid')
box('Thumb_r',(-1.135,-.355,1.225),(.17,.29,.25),'hand_r','skin')
bone_specs['weapon']=(tuple(grip),tuple(grip+axis*.55),'hand_r')
beam('Club_Handle',grip-axis*.45,grip+axis*.88,.197,.197,'weapon','wood')
beam('Club_Head',grip+axis*.78,grip+axis*1.57,.53,.53,'weapon','wood')
beam('Club_End',grip+axis*1.57,grip+axis*1.59,.53,.53,'weapon','endgrain')
for start,end in [(.40,.48),(.51,.58),(.61,.68)]:
    beam('GripWrap_'+str(start),grip+axis*start,grip+axis*end,.208,.208,'weapon','belt')
for obj in parts.objects:
    obj['part']=obj.name.removeprefix(NAME+'_')
    for p in obj.data.polygons: p.use_smooth=False
scene['bone_specs']=json.dumps(bone_specs)
scene['refinement_notes']='Integrated ears; continuous mouth-rooted tusks; solid hands; flared hide; aligned physical grip channel; no neck geometry.'

# Metric per-face UV unwrap. One Blender meter = exactly 64 texture pixels in
# both axes, including rectangular faces; no square swatches stretched to fit.
DENSITY=64.0; SIZE=512; PAD=2
islands=[]
for obj in parts.objects:
    me=obj.data
    bm=bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(me); bm.free(); me.update()
    region=obj['region']; bone=obj['bone']
    desired_up=Vector((0,0,1))
    if region in ('upper_arm','forearm','thigh','shin','wood','endgrain','belt') and bone!='pelvis':
        desired_up=(Vector(bone_specs[bone][1])-Vector(bone_specs[bone][0])).normalized()
        if desired_up.z<0 and bone!='weapon': desired_up=-desired_up
    for p in me.polygons:
        normal=p.normal.normalized()
        up=desired_up-normal*normal.dot(desired_up)
        if up.length<.001:
            desired=Vector((0,1,0))
            up=desired-normal*normal.dot(desired)
        if up.length<.001: up=Vector((1,0,0))-normal*normal.x
        up.normalize(); right=up.cross(normal).normalized()
        coords=[Vector((me.vertices[i].co.dot(right),me.vertices[i].co.dot(up))) for i in p.vertices]
        low=Vector((min(c.x for c in coords),min(c.y for c in coords)))
        coords=[c-low for c in coords]
        width=max(c.x for c in coords)*DENSITY; height=max(c.y for c in coords)*DENSITY
        islands.append({'obj':obj,'polygon':p.index,'coords':coords,'w':max(1,math.ceil(width)),
          'h':max(1,math.ceil(height)),'actual_w':width,'actual_h':height,'normal':normal,
          'region':region,'part':obj['part']})

# Shelf packing sorted by height; exact physical UV size is retained within
# each padded bounding rectangle. Islands never overlap, including hidden faces.
x=y=PAD; row_height=0
for island in sorted(islands,key=lambda r:(-r['h'],-r['w'])):
    w,h=island['w']+2*PAD,island['h']+2*PAD
    if x+w>SIZE-PAD: x=PAD; y+=row_height; row_height=0
    if y+h>SIZE-PAD: raise RuntimeError('Metric UV atlas exceeds 512; do not stretch islands to force fit.')
    island['x']=x+PAD; island['y']=y+PAD; x+=w; row_height=max(row_height,h)
scene['texel_density_px_per_meter']=DENSITY
scene['uv_atlas_size']=SIZE
scene['uv_island_count']=len(islands)
scene['uv_used_height']=y+row_height

# Save intermediate shape for recovery before painting; no headless fallback.
namespace=bpy.app.driver_namespace
namespace['troll_refinement']={'scene':scene,'parts':parts,'studio':studio,'islands':islands,
 'bone_specs':bone_specs,'source':str(SOURCE),'out':str(OUT),'name':NAME,'scale':S}
result={'stage':'geometry_and_metric_unwrap','parts':len(parts.objects),'islands':len(islands),
        'density_px_per_meter':DENSITY,'atlas':[SIZE,SIZE],'used_height':y+row_height,
        'style':'approved cuboids retained; only requested parts refined'}

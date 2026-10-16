import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
scene=bpy.data.scenes['Elemental_Dragon_V9_Animated']; bpy.context.window.scene=scene
rig=next(o for o in scene.objects if o.type=='ARMATURE')
parts=[o for o in scene.objects if o.type=='MESH' and 'part' in o]
material=parts[0].data.materials[0]
rest={bone.name:bone.matrix_local.copy() for bone in rig.data.bones}
core=rest['core'].translation.copy(); spine=['spine_%02d'%i for i in range(39)]
def ease(t):
    t=max(0.,min(1.,t)); return t*t*t*(t*(t*6-15)+10)
def pulse(t,start,rise,hold,end):
    if t<=start or t>=end: return 0.
    return ease((t-start)/(rise-start)) if t<rise else (1. if t<=hold else 1-ease((t-hold)/(end-hold)))
def rotated_at(matrix,axis,angle):
    value=(Matrix.Rotation(angle,3,axis)@matrix.to_3x3()).to_4x4(); value.translation=matrix.translation; return value
source=ROOT/'tools/art_pipeline/elemental_dragon_path_motion.py.inc'
exec(compile(source.read_text(encoding='utf-8'),str(source),'exec'),globals())
radius=max((v.co-core).length for obj in parts if obj['rig_bone']=='core' for v in obj.data.vertices)
rows=[]
for obj in parts:
    if obj['rig_bone']=='core': continue
    rows.append((obj['part'],[(v.co.copy(),[(obj.vertex_groups[g.group].name,g.weight) for g in v.groups]) for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons]))
worst=(100.,None,None); ground=(100.,None,None); determinant=1.
for sample in range(121):
    pose=frame_pose('walk',6.*sample/120,6.)
    transforms={name:matrix@rest[name].inverted() for name,matrix in pose.items()}
    center=pose['core'].translation
    for label,vertices,faces in rows:
        points=[sum(((transforms[n]@v)*w for n,w in influences),Vector()) for v,influences in vertices]
        distance=BVHTree.FromPolygons(points,faces).find_nearest(center)[3]-radius*1.22
        if distance<worst[0]: worst=(distance,sample,label)
        low=min(p.z for p in points)
        if low<ground[0]: ground=(low,sample,label)
result={'core_clearance':worst,'ground_clearance':ground,'path_m':_CIRCUMFERENCE}

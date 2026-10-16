"""Load the approved elven head/anatomy without touching source files."""
import bpy,json,hashlib,numpy as np
from pathlib import Path
from mathutils import Matrix
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/elf_school_mages_review'
WORK.mkdir(exist_ok=True); (WORK/'.gdignore').touch()
previous=bpy.context.scene
path=ROOT/'assets/generated/elves/elf_settler_v1/elf_settler_v1.blend'
with bpy.data.libraries.load(str(path),link=False) as (src,dst): dst.scenes=[src.scenes[0]]
scene=dst.scenes[0]; bpy.context.window.scene=scene
for o in scene.objects:
    if o.type=='ARMATURE':
        o.animation_data_clear()
        for b in o.pose.bones: b.matrix_basis=Matrix.Identity(4)
scene.frame_set(1); bpy.context.view_layer.update()
rows=[]
for o in scene.objects:
    if o.type!='MESH': continue
    pts=[o.matrix_world@v.co for v in o.data.vertices]
    rows.append(dict(part=o.get('part'),bone=o.get('future_bone'),lo=[min(p[i] for p in pts) for i in range(3)],hi=[max(p[i] for p in pts) for i in range(3)],vertices=len(pts)))
head=next(o for o in scene.objects if o.get('part')=='Head')
img=next(n.image for n in head.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
arr=np.rint(np.array(img.pixels[:]).reshape(512,512,4)*255).astype(np.uint8)
colors=[]
for f in head.data.polygons:
    uv=np.array([list(head.data.uv_layers.active.data[i].uv) for i in f.loop_indices])*512
    lo=np.floor(uv.min(axis=0)).astype(int); hi=np.ceil(uv.max(axis=0)).astype(int)
    colors.append(dict(face=f.index,colors=np.unique(arr[lo[1]:hi[1],lo[0]:hi[0],:3].reshape(-1,3),axis=0).tolist()))
report=dict(path=path.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),scene=scene.name,parts=rows,head_palette=colors)
(WORK/'base_probe.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.app.driver_namespace['elf_school_mage_base']=scene
bpy.context.window.scene=previous
result=report

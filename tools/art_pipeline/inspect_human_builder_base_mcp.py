"""Inspect the existing human settler for a derived builder asset."""
import bpy
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
SOURCE=ROOT/'assets/generated/humans/human_settler_v1/human_settler_v1.blend'
reference=bpy.app.driver_namespace.get('human_builder_reference')
if reference is None:
    with bpy.data.libraries.load(str(SOURCE),link=False) as (available,loaded):
        loaded.scenes=[available.scenes[0]]
    reference=loaded.scenes[0]; bpy.app.driver_namespace['human_builder_reference']=reference
rig=next(o for o in reference.objects if o.type=='ARMATURE')
result=dict(scene=reference.name,root=[dict(name=o.name,scale=list(o.scale)) for o in reference.objects if o.type=='EMPTY'],
    part_names=[o.get('part') for o in reference.objects if o.type=='MESH' and o.get('part')],
    grips=[dict(part=o['part'],coords=[list(v.co) for v in o.data.vertices]) for o in reference.objects if o.get('part') in ('Hand_l','Hand_r','Survey_scroll')],
    images=[dict(name=n.image.name,size=list(n.image.size)) for n in next(o for o in reference.objects if o.get('part')=='Head').data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE'],
    bones=[b.name for b in rig.data.bones],
    tracks=[dict(name=t.name,strips=[dict(name=s.name,action=s.action.name,start=s.frame_start,end=s.frame_end) for s in t.strips]) for t in rig.animation_data.nla_tracks],
    fps=reference.render.fps,current_frame=reference.frame_current)

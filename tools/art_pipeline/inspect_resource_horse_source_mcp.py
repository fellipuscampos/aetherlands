"""Inspect the existing cavalry mount without replacing live Blender scenes."""
import bpy
from pathlib import Path

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
SOURCE=ROOT/'assets/generated/humans/cavalier_v1/cavalier_v1.blend'
reference=bpy.app.driver_namespace.get('resource_horse_reference')
if reference is None:
    with bpy.data.libraries.load(str(SOURCE),link=False) as (available,loaded):
        loaded.scenes=[available.scenes[0]]
    reference=loaded.scenes[0]
    bpy.app.driver_namespace['resource_horse_reference']=reference
result=dict(source=str(SOURCE),scene=reference.name,
    parts=[dict(name=o.name,type=o.type,part=o.get('part'),region=o.get('region'),
                bone=o.get('rig_bone'),vertices=len(o.data.vertices) if o.type=='MESH' else None,
                materials=[m.name for m in o.data.materials] if o.type=='MESH' else [],
                modifiers=[m.type for m in o.modifiers])
           for o in reference.objects if o.get('part','').startswith('Horse')],
    frames=[reference.frame_start,reference.frame_end],current_frame=reference.frame_current)

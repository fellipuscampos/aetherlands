import bpy,sys,json
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from orc_troop_assets import ASSETS,OUT,WORK
from build_orc_troops import load_scene
from build_elf_troops import reset_pose
from build_orc_tribal_equipment import frame
previous=bpy.context.scene
data=[]
for key in ('squire','blade_hero','griffon_rider','shadow_master'):
    row=next(r for r in ASSETS if r['key']==key)
    scene=load_scene(OUT/row['stem']/(row['stem']+'.blend'));bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE');reset_pose(rig,scene)
    parts=[]
    for o in scene.objects:
        if o.type!='MESH' or not o.get('part'):continue
        item=dict(part=o['part'],bone=o.get('rig_bone'),region=o.get('region'),vertices=len(o.data.vertices))
        if len(o.data.vertices)==8:
            try:
                center,axes,size=frame(o);item.update(center=center.tolist(),axes=axes.tolist(),size=size.tolist())
            except AssertionError:pass
        parts.append(item)
    data.append(dict(key=key,root_scale=list(rig.parent.scale),parts=parts))
    bpy.context.window.scene=previous;bpy.data.scenes.remove(scene)
dest=WORK/'clothing_refinement';dest.mkdir(exist_ok=True)
(dest/'inspection.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
result=dict(status='PASS',models=len(data),parts=[len(d['parts']) for d in data])

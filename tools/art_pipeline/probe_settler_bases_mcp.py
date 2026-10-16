"""Read the approved editable anatomy in the live Blender MCP editor."""
import bpy, json
from pathlib import Path
from mathutils import Matrix

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/settlers_review'
WORK.mkdir(parents=True,exist_ok=True)
(WORK/'.gdignore').touch()
paths={
 'human':'assets/generated/humans/squire_v1/squire_v1.blend',
 'elf':'assets/generated/elves/elf_squire_v1/elf_squire_v1.blend',
 'dwarf':'assets/generated/dwarves/common/dwarf_base_v1.blend',
 'orc':'assets/generated/orcs/orc_squire_v1/orc_squire_v1.blend',
}
loaded_scenes={}; report={}
for race,path in paths.items():
    with bpy.data.libraries.load(str(ROOT/path),link=False) as (src,dst):
        dst.scenes=[src.scenes[0]]
    scene=dst.scenes[0]
    loaded_scenes[race]=scene
    bpy.context.window.scene=scene
    for obj in scene.objects:
        if obj.type=='ARMATURE':
            obj.animation_data_clear()
            for bone in obj.pose.bones: bone.matrix_basis=Matrix.Identity(4)
    scene.frame_set(1); bpy.context.view_layer.update()
    meshes=[]
    for obj in scene.objects:
        if obj.type!='MESH' or not obj.get('part'): continue
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        lo=[min(p[i] for p in points) for i in range(3)]
        hi=[max(p[i] for p in points) for i in range(3)]
        meshes.append(dict(name=obj.name,part=obj.get('part'),bone=obj.get('rig_bone',obj.get('future_bone')),
            region=obj.get('region',obj.get('surface')),anatomy=obj.get('shared_anatomy'),
            lo=lo,hi=hi,vertices=len(obj.data.vertices),faces=len(obj.data.polygons)))
    report[race]=dict(path=path,scene=scene.name,root_scales=[list(o.scale) for o in scene.objects if o.type=='EMPTY' and not o.parent],meshes=meshes)
    print(race,scene.name,'parts',len(meshes),'anatomy',[(o['part'],[round(v,3) for v in o['lo']],[round(v,3) for v in o['hi']]) for o in meshes if o['part'] in ['Head','Chest','Belly','Pelvis','Hand_l','Hand_r','body_head','body_chest','body_hand_L','body_hand_R']])
bpy.app.driver_namespace['settler_source_scenes_v1']=loaded_scenes
(WORK/'source_probe.json').write_text(json.dumps(report,indent=2),encoding='utf-8')

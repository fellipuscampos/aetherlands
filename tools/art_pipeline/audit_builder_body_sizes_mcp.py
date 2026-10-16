"""Read anatomical head/foot bounds from builders and their racial troop bases."""
import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
rows=[]
for race,family,reference in [('human','humans','squire_v1'),('elf','elves','elf_squire_v1'),
                              ('orc','orcs','orc_squire_v1'),('dwarf','dwarves','dwarf_shieldbearer_v1')]:
    for stem in [race+'_builder_v1',race+'_settler_v1',reference]:
        path=ROOT/f'assets/generated/{family}/{stem}/{stem}.blend'
        with bpy.data.libraries.load(str(path),link=False) as (available,loaded):
            loaded.scenes=[available.scenes[0]]
        scene=loaded.scenes[0]
        meshes=[o for o in scene.objects if o.type=='MESH']
        head=[o for o in meshes if o.get('part') in ('Head','body_head')]
        feet=[o for o in meshes if o.get('part') in ('Foot_l','Foot_r','body_foot_L','body_foot_R','body_foot_l','body_foot_r')]
        rows.append({'race':race,'stem':stem,
            'head_parts':[(o.name,o.get('part')) for o in head],
            'head_top':max((o.matrix_world@v.co).z for o in head for v in o.data.vertices) if head else None,
            'foot_floor':min((o.matrix_world@v.co).z for o in feet for v in o.data.vertices) if feet else None,
            'roots':[(o.name,list(o.scale)) for o in scene.objects if o.type in ('EMPTY','ARMATURE')],
            'parts':[o.get('part') for o in meshes[:8]]})
result={'assets':rows}
(ROOT/'art_source/builder_body_size_audit.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')

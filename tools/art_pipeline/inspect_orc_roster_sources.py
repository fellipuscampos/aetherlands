import bpy,json,sys
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
sys.path.insert(0,str(ROOT/'tools/art_pipeline'))
from elf_troop_assets import ASSETS
previous=bpy.context.scene
if bpy.context.screen.is_animation_playing: bpy.ops.screen.animation_cancel(restore_frame=False)
rows=[]
for row in ASSETS:
    path=ROOT/'assets/generated/elves'/row['stem']/(row['stem']+'.blend')
    with bpy.data.libraries.load(str(path),link=False) as (source,loaded): loaded.scenes=source.scenes
    scene=loaded.scenes[0]
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    rows.append(dict(stem=row['stem'],family=row['family'],tier=row['tier'],
      bones={b.name:dict(head=list(b.head_local),tail=list(b.tail_local),parent=b.parent.name if b.parent else None) for b in rig.data.bones},
      parts=[dict(part=o.get('part'),region=o.get('region'),bone=o.get('rig_bone'),verts=len(o.data.vertices),position=list(o.location),matrix=[list(r) for r in o.matrix_world]) for o in parts],
      clips=[dict(name=t.name,start=t.strips[0].frame_start,end=t.strips[0].frame_end,action=t.strips[0].action.name) for t in rig.animation_data.nla_tracks],fps=scene.render.fps))
    bpy.data.scenes.remove(scene)
(ROOT/'art_source/orc_squire/roster_source_inspection.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
bpy.context.window.scene=previous
result=dict(status='PASS',sources=len(rows),parts=sum(len(r['parts']) for r in rows))

"""Compare the carrying loops against the asset before the work correction."""
import bpy,json
from pathlib import Path
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
SOURCE=ROOT/'art_source/orc_builder_review/before_hinge_fix/orc_builder_v1.blend'
current=bpy.data.scenes['Orc_Builder_V1']
with bpy.data.libraries.load(str(SOURCE),link=False) as (available,loaded):
    loaded.scenes=[available.scenes[0]]
original=loaded.scenes[0]
def capture(scene):
    bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    old_mutes=[(t,t.mute) for t in rig.animation_data.nla_tracks]
    clips={}
    for track in rig.animation_data.nla_tracks:
        if track.name not in ('idle','walk'): continue
        for other in rig.animation_data.nla_tracks: other.mute=other!=track
        strip=track.strips[0]; frames=[]
        for frame in range(int(strip.frame_start),int(strip.frame_end)+1):
            scene.frame_set(frame); scene.view_layers[0].update()
            frames.append({b.name:b.matrix.copy() for b in rig.pose.bones})
        clips[track.name]=frames
    for track,muted in old_mutes: track.mute=muted
    scene.frame_set(1)
    return clips
before=capture(original); after=capture(current)
maximum=0.0
for clip in ('idle','walk'):
    assert len(before[clip])==len(after[clip])
    for a,b in zip(before[clip],after[clip]):
        for bone in a:
            maximum=max(maximum,max(abs(a[bone][row][col]-b[bone][row][col]) for row in range(4) for col in range(4)))
assert maximum<0.00001,maximum
result={'status':'PASS','idle_walk_unchanged':True,'maximum_pose_difference':maximum}
(ROOT/'assets/generated/orcs/orc_builder_v1/carry_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')

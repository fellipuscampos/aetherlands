"""Locate any unusually fast movement in the baked staff attack."""
import bpy,math
st=bpy.app.driver_namespace['elder_lich_blocky_v3_animated']
rig=st['rig']; scene=st['scene']; rig.animation_data.action=st['clips']['Attack']['action']
rest={b.name:b.matrix_local.inverted() for b in rig.data.bones}
previous=None; changes=[]
for step in range(73):
    frame=1+step/2; scene.frame_set(int(frame),subframe=frame%1)
    matrices={b.name:b.matrix@rest[b.name] for b in rig.pose.bones}
    points=[(o.name,v.index,matrices[o.vertex_groups[v.groups[0].group].name]@v.co) for o in st['parts'] for v in o.data.vertices]
    if previous is not None:
        index=max(range(len(points)),key=lambda i:(points[i][2]-previous[i][2]).length)
        changes.append(dict(frame=frame,distance=(points[index][2]-previous[index][2]).length,part=points[index][0],wristL_deg=math.degrees(rig.pose.bones['hand_L'].rotation_quaternion.angle)))
    previous=points
result={'largest_steps':sorted(changes,key=lambda p:p['distance'],reverse=True)[:8]}

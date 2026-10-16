import bpy,json
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
result=dict(scene=bpy.context.scene.name,use_nla=rig.animation_data.use_nla,
    bones={n:[list(x) for x in rig.data.bones[n].matrix_local] for n in ('root','chest','head')},
    tracks=[dict(name=t.name,slot=t.strips[0].action_slot.identifier if t.strips[0].action_slot else None,
        slots=[s.identifier for s in t.strips[0].action.slots]) for t in rig.animation_data.nla_tracks])

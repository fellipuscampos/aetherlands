# Rotate the broad faces outward, with the top edge touching the skirt's side surface.
attachments={}
for side,sign in [('L',-1),('R',1)]:
    prefix='stole_side_'+side+'_'
    pivot=rig.data.bones[prefix+'0'].head_local.copy()
    target=Vector((sign*(.3885811567+.045*.92519325/2),.1063972283,pivot.z))
    turn=Matrix.Rotation(sign*math.pi/2,3,'Z')
    for o in parts:
        if o['rig_bone'].startswith(prefix):
            for v in o.data.vertices: v.co=target+turn@(v.co-pivot)
            o.data.update()
    attachments[side]=(pivot,target,turn)
core=next(o for o in parts if o['rig_bone']=='core')
core.name=NAME+'_Core_Red_Energy_Cube'
old_center=rig.data.bones['core'].head_local.copy()
center=Vector((0,0,old_center.z)); edge=.24
tilt=Euler(tuple(math.radians(a) for a in (18,10,22))).to_matrix()
for v in core.data.vertices:
    delta=v.co-old_center
    corner=Vector(tuple(edge/2*(1 if delta[i]>0 else -1) for i in range(3)))
    v.co=center+tilt@corner
core['kind']='red_energy_cube'; core['edge_m']=edge; core.data.update()
# Uniform red atlas texels also cover the deeper faces; armor and cloth images stay byte-identical.
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for side,(pivot,target,turn) in attachments.items():
    for b in rig.data.edit_bones:
        if b.name.startswith('stole_side_'+side+'_'):
            b.head=target+turn@(b.head-pivot); b.tail=b.head+Vector((0,0,.15))
rig.data.edit_bones['core'].head=center; rig.data.edit_bones['core'].tail=center+Vector((0,0,.15))
bpy.ops.object.mode_set(mode='OBJECT')
scene['side_stoles_attachment']='Broad cloth faces lie on the two side planes of the skirt; top edges touch the armor.'
scene['core']='Single 24 cm red emissive cube, suspended and spinning inside the hollow cuirass.'


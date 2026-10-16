import bpy
s=bpy.data.scenes['Orc_Builder_V1']; bpy.context.window.scene=s
r=next(o for o in s.objects if o.type=='ARMATURE')
s.frame_set(249); s.view_layers[0].update()
initial=r.pose.bones['forearm_r'].matrix.inverted()@r.pose.bones['hand_r'].matrix
length=(r.pose.bones['forearm_r'].matrix.translation-r.pose.bones['hand_r'].matrix.translation).length
result={'bones':[{'name':b.name,'scale':list(b.scale)} for b in r.pose.bones],'samples':[]}
for f in [249,277,307,330,375,393]:
    s.frame_set(f); s.view_layers[0].update()
    fore=r.pose.bones['forearm_r']; hand=r.pose.bones['hand_r']
    m=fore.matrix.inverted()@hand.matrix
    result['samples'].append({'frame':f,'wrist_pos_error':(m.translation-initial.translation).length,
        'wrist_rot_error':initial.to_quaternion().rotation_difference(m.to_quaternion()).angle,
        'fore_scale':list(fore.scale),'hand_scale':list(hand.scale),
        'length_error':(fore.matrix.translation-hand.matrix.translation).length-length})

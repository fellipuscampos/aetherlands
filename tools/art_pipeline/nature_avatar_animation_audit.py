# Sample every half frame, checking real geometry, arm attachment and rotating-core clearance.
rest={b.name:b.matrix_local.inverted() for b in rig.data.bones}
channels=[]; validation={}; idle_first=None
for track in rig.animation_data.nla_tracks: track.mute=True
def transformed(o,matrices):
    return [matrices[o.vertex_groups[v.groups[0].group].name]@v.co for v in o.data.vertices]
def bounds(points):
    return Vector(tuple(min(v[i] for v in points) for i in range(3))),Vector(tuple(max(v[i] for v in points) for i in range(3)))
def intersects(a,b): return all(a[0][i]<=b[1][i] and b[0][i]<=a[1][i] for i in range(3))
core=next(o for o in parts if o['rig_bone']=='core')
targets=[o for o in parts if o!=core]
for name,data in st['clips'].items():
    rig.animation_data.action=data['action']; channel_set=set()
    for layer in data['action'].layers:
        for strip in layer.strips:
            for bag in strip.channelbags: channel_set.update((curve.data_path,curve.array_index) for curve in bag.fcurves)
    channels.append(channel_set)
    low=Vector((1e9,)*3); high=Vector((-1e9,)*3)
    first=previous=None; maximum_step=joint_error=wrist_angle=core_center_error=0.; collision_checks=0
    tips={}; root_anchor_error=0.
    samples=(data['end_frame']-1)*2+1
    for step in range(samples):
        frame=1+step/2; scene.frame_set(int(frame),subframe=frame%1)
        matrices={b.name:b.matrix@rest[b.name] for b in rig.pose.bones}
        assert matrices['root']==Matrix.Identity(4),name
        for bone,matrix in matrices.items():
            scales=[matrix.to_3x3().col[i].length for i in range(3)]
            assert abs(max(scales)-min(scales))<1e-5 and matrix.determinant()>0,(name,frame,bone)
            if bone!='core': assert max(abs(s-1) for s in scales)<1e-5,(name,frame,bone)
        for side,(shoulder,elbow,wrist) in st['arms'].items():
            for position,a,b in [(shoulder,'chest','upper_arm_'+side),(elbow,'upper_arm_'+side,'forearm_'+side),(wrist,'forearm_'+side,'hand_'+side)]:
                joint_error=max(joint_error,(matrices[a]@position-matrices[b]@position).length)
            wrist_angle=max(wrist_angle,math.degrees(rig.pose.bones['hand_'+side].rotation_quaternion.angle))
        assert joint_error<1e-5 and wrist_angle<15.01,(name,frame,joint_error,wrist_angle)
        posed={o.name:transformed(o,matrices) for o in parts}
        points=[p for vv in posed.values() for p in vv]
        for p in points:
            for k in range(3): low[k]=min(low[k],p[k]); high[k]=max(high[k],p[k])
        for bone in st['root_bones']:
            anchor=rig.data.bones[bone].head_local
            root_anchor_error=max(root_anchor_error,(matrices[bone]@anchor-matrices['body']@anchor).length)
            candidates=[o for o in parts if o['rig_bone']==bone]
            panel=min(candidates,key=lambda o:min(v.co.z for v in o.data.vertices))
            tip=min(range(len(panel.data.vertices)),key=lambda i:panel.data.vertices[i].co.z)
            tips.setdefault(bone,[]).append(matrices['body'].inverted()@posed[panel.name][tip])
        assert root_anchor_error<1e-5,(name,frame,'detached root',root_anchor_error)
        # The cube must remain clear of the actual posed bark, crown, arms and roots.
        if step%4==0 or name in ('Attack','Spell') and step%2==0:
            core_points=posed[core.name]; core_bounds=bounds(core_points)
            tree=None
            for target in targets:
                if not intersects(core_bounds,bounds(posed[target.name])): continue
                if tree is None: tree=BVHTree.FromPolygons(core_points,[tuple(p.vertices) for p in core.data.polygons])
                other=BVHTree.FromPolygons(posed[target.name],[tuple(p.vertices) for p in target.data.polygons])
                assert not tree.overlap(other),('Core/bark intersection',name,frame,target.name)
                collision_checks+=1
        if first is None: first=[p.copy() for p in points]
        if previous is not None: maximum_step=max(maximum_step,max((a-b).length for a,b in zip(previous,points)))
        previous=points
    seam=max((a-b).length for a,b in zip(first,points))
    assert seam<1e-5 and low.z>.20,(name,seam,low.z)
    assert maximum_step<.18,(name,maximum_step)
    if name=='Idle': idle_first=first
    if name in ('Attack','Spell'): assert max((a-b).length for a,b in zip(first,idle_first))<1e-5
    tip_ranges={bone:(Vector(tuple(max(v[i] for v in vv) for i in range(3)))-Vector(tuple(min(v[i] for v in vv) for i in range(3)))).length for bone,vv in tips.items()}
    assert min(tip_ranges.values())>.006,(name,'roots motion',tip_ranges)
    validation[name]=dict(samples=samples,loop=data['loop'],duration_s=data['duration_s'],description=data['description'],
      minimum_ground_clearance_m=low.z,bounds_min_m=list(low),bounds_max_m=list(high),seam_vertex_delta_m=seam,
      maximum_half_frame_vertex_step_m=maximum_step,maximum_joint_gap_m=joint_error,maximum_wrist_rotation_deg=wrist_angle,
      root_anchor_error_m=root_anchor_error,root_tip_motion_m=tip_ranges,core_collision_checks=collision_checks,
      core_clear_of_bark=True,body_and_limbs_rigid=True)
assert all(c==channels[0] for c in channels)
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=False
scene.frame_set(1)

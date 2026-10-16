# Sample actual evaluated half frames: rigid plates, loop seams, ground and collision clearance.
rest={b.name:b.matrix_local.inverted() for b in rig.data.bones}
channels=[];validation={};idle_first=None
for track in rig.animation_data.nla_tracks:track.mute=True
core=next(o for o in parts if o['kind']=='core')
plate_parts=[o for o in parts if o['kind']=='plate'];targets=[o for o in parts if o!=core]
faces={o.name:[tuple(p.vertices) for p in o.data.polygons] for o in parts}
def bounds(points):
    return Vector(tuple(min(v[i] for v in points) for i in range(3))),Vector(tuple(max(v[i] for v in points) for i in range(3)))
def overlaps(a,b):return all(a[0][i]<=b[1][i] and b[0][i]<=a[1][i] for i in range(3))
for name,data in st['clips'].items():
    rig.animation_data.action=data['action'];channel_set=set()
    for layer in data['action'].layers:
        for strip in layer.strips:
            for bag in strip.channelbags:channel_set.update((curve.data_path,curve.array_index) for curve in bag.fcurves)
    channels.append(channel_set)
    low=Vector((1e9,)*3);high=Vector((-1e9,)*3);first=previous=None
    maximum_step=0.;core_checks=plate_checks=collision_poses=0
    samples=(data['end_frame']-1)*2+1
    for step in range(samples):
        frame=1+step/2;scene.frame_set(int(frame),subframe=frame%1)
        matrices={b.name:b.matrix@rest[b.name] for b in rig.pose.bones}
        assert matrices['root']==Matrix.Identity(4),name
        for bone,matrix in matrices.items():
            scales=[matrix.to_3x3().col[i].length for i in range(3)]
            assert abs(max(scales)-min(scales))<1e-5 and matrix.determinant()>0,(name,frame,bone)
            if bone!='core':assert max(abs(s-1) for s in scales)<1e-5,(name,frame,bone)
        posed={o.name:[matrices[o['rig_bone']]@v.co for v in o.data.vertices] for o in parts}
        points=[p for vv in posed.values() for p in vv]
        frame_low,frame_high=bounds(points);low=Vector(tuple(min(low[i],frame_low[i]) for i in range(3)));high=Vector(tuple(max(high[i],frame_high[i]) for i in range(3)))
        if step%4==0 or name in ('Attack','Spell'):
            # Strip the shared shell rotation for stable and efficient collision bounds.
            inverse=matrices['shell'].inverted()
            local={o.name:[inverse@p for p in posed[o.name]] for o in parts}
            boxes={n:bounds(vv) for n,vv in local.items()};trees={}
            def tree(o):
                if o.name not in trees:trees[o.name]=BVHTree.FromPolygons(local[o.name],faces[o.name])
                return trees[o.name]
            for target in targets:
                if not overlaps(boxes[core.name],boxes[target.name]):continue
                assert not tree(core).overlap(tree(target)),('Core intersection',name,frame,target.name)
                core_checks+=1
            for i,a in enumerate(plate_parts):
                for b in plate_parts[i+1:]:
                    if not overlaps(boxes[a.name],boxes[b.name]):continue
                    assert not tree(a).overlap(tree(b)),('Runic plates intersect',name,frame,a.name,b.name)
                    plate_checks+=1
            collision_poses+=1
        if first is None:first=[p.copy() for p in points]
        if previous is not None:maximum_step=max(maximum_step,max((a-b).length for a,b in zip(previous,points)))
        previous=points
    seam=max((a-b).length for a,b in zip(first,points))
    assert seam<1e-5 and low.z>.20,(name,seam,low.z)
    assert maximum_step<.18,(name,maximum_step)
    if name=='Idle':idle_first=first
    if name in ('Attack','Spell'):assert max((a-b).length for a,b in zip(first,idle_first))<1e-5
    validation[name]=dict(samples=samples,loop=data['loop'],duration_s=data['duration_s'],description=data['description'],
      minimum_ground_clearance_m=low.z,bounds_min_m=list(low),bounds_max_m=list(high),seam_vertex_delta_m=seam,
      maximum_half_frame_vertex_step_m=maximum_step,collision_poses_checked=collision_poses,
      core_collision_checks=core_checks,runic_plate_collision_checks=plate_checks,
      core_clear_of_plates_and_lattice=True,runic_plate_intersections=0,rigid_parts=True)
assert all(c==channels[0] for c in channels)
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=False
scene.frame_set(1)

"""Upright rest, open serpent locomotion, and the approved orbit reserved for casting."""
approved=ROOT/'tools/art_pipeline/elemental_dragon_path_motion.py.inc'
exec(compile(approved.read_text(encoding='utf-8'),str(approved),'exec'),globals())
_approved_orbit=frame_pose
_CALM_NODES=[rig.data.bones[name].head_local.copy() for name in spine]+[rig.data.bones[spine[-1]].tail_local.copy()]
_ORBIT_START=_approved_orbit('walk',0.,6.)
_STAND_TILT=Matrix.Translation(core)@Matrix.Rotation(math.radians(15),4,'X')@Matrix.Translation(-core)
_STAND_POSE={name:_STAND_TILT@matrix for name,matrix in _ORBIT_START.items()}
_STAND_NODES=[_STAND_POSE[name].translation.copy() for name in spine]+[_STAND_POSE[spine[-1]]@Vector((0,_LENGTHS[-1],0))]
_STAND_FORWARD=(_STAND_POSE['head'].to_3x3()@rest['head'].to_3x3().transposed())@Vector((0,-1,0))
_STAND_UP=(Vector((0,0,1))-_STAND_FORWARD*_STAND_FORWARD.z).normalized()
_STAND_HEAD=Matrix((_STAND_UP.cross(_STAND_FORWARD),-_STAND_FORWARD,_STAND_UP)).transposed()
_WAVELENGTH=3.2; _WAVE_NUMBER=math.tau/_WAVELENGTH; _WAVE_AMPLITUDE=.85

def _assemble(nodes,ring_rotations,head_rotation,heart_scale,heart_angle,heart_offset=Vector(),bob=0.):
    pose={'root':rest['root'].copy()}; positions=[nodes[0].copy()]
    for j,name in enumerate(spine):
        direction=(nodes[j+1]-positions[-1]).normalized()
        rotation=(rig.data.bones[name].tail_local-rig.data.bones[name].head_local).normalized().rotation_difference(direction).to_matrix()@rest[name].to_3x3()
        matrix=rotation.to_4x4(); matrix.translation=positions[-1]; pose[name]=matrix
        positions.append(positions[-1]+direction*_LENGTHS[j])
    for ring in range(40):
        j=39-ring; name='ring_%02d'%ring
        normal=(positions[max(0,j-1)]-positions[min(39,j+1)]).normalized()
        rotation=ring_rotations[ring]
        current_normal=rotation@rest[name].to_3x3().transposed()@_SECTION_FRAMES[ring].col[2]
        rotation=current_normal.rotation_difference(normal).to_matrix()@rotation
        matrix=rotation.to_4x4(); matrix.translation=positions[j]; pose[name]=matrix
    head_transform=head_rotation.to_4x4()@Matrix.Translation(-_CALM_NODES[0])
    head_transform.translation+=positions[0]
    for bone in rig.data.bones:
        name=bone.name
        if name in pose: continue
        parent=bone.parent.name; pose[name]=pose[parent]@rest[parent].inverted()@rest[name]
        if name=='head': pose[name]=head_transform@rest[name]
        elif name=='core':
            pose[name]=rotated_at(rest[name],'Z',heart_angle)@Matrix.Diagonal((heart_scale,heart_scale,heart_scale,1.))
            pose[name].translation+=heart_offset
    G=Matrix.Translation((0,0,bob))
    return {name:G@matrix for name,matrix in pose.items()}

def _idle_pose(t,duration=6.):
    p=math.tau*t/duration
    desired=[]
    for j,point in enumerate(_STAND_NODES):
        s=j/39
        delta=Vector()
        amplitude=.022+.022*s
        lag=-math.tau*s
        delta+=Vector((amplitude*(math.sin(p+lag)-math.sin(lag)),.007*(math.cos(p+lag)-math.cos(lag)),0))
        if j==0: delta=Vector((.022*math.sin(p),0,0))
        desired.append(point+delta)
    rotations=[_STAND_POSE['ring_%02d'%i].to_3x3().copy() for i in range(40)]
    return _assemble(desired,rotations,_STAND_HEAD,1+.05*math.sin(2*p),p,bob=.018*math.sin(p))

def _walk_pose(t,duration=4.):
    p=math.tau*t/duration; head_parameter=p/_WAVE_NUMBER
    def point(u):
        return _CALM_NODES[0]+Vector((_WAVE_AMPLITUDE*math.sin(_WAVE_NUMBER*u),head_parameter-u,
                                     .10*(math.cos(_WAVE_NUMBER*u)-math.cos(p))))
    parameters=[head_parameter]; nodes=[point(head_parameter)]
    for length in _LENGTHS:
        lo=0.; hi=length*1.5
        for iteration in range(18):
            step=(lo+hi)*.5
            if (point(parameters[-1]-step)-nodes[-1]).length<length: lo=step
            else: hi=step
        u=parameters[-1]-(lo+hi)*.5
        direction=(point(u)-nodes[-1]).normalized()
        nodes.append(nodes[-1]+direction*length); parameters.append(u)
    rotations=[]
    for ring in range(40):
        j=39-ring; forward=(point(parameters[j]+.005)-point(parameters[j]-.005)).normalized()
        up=(Vector((0,0,1))-forward*forward.z).normalized()
        section=Matrix((-up.cross(forward),-up,forward)).transposed()
        rotations.append(section@_SECTION_FRAMES[ring].transposed()@rest['ring_%02d'%ring].to_3x3())
    forward=(point(head_parameter+.005)-point(head_parameter-.005)).normalized()
    forward.z*=.25; forward.normalize()
    up=(Vector((0,0,1))-forward*forward.z).normalized()
    head_rotation=Matrix((up.cross(forward),-forward,up)).transposed()
    return _assemble(nodes,rotations,head_rotation,1+.10*math.sin(2*p),p,
                     heart_offset=Vector((_WAVE_AMPLITUDE*math.sin(p),0,0)),bob=.018*math.sin(p))

def _transition_pose(a,b,weight):
    # The rest pose uses the same coil, raised slightly upright. Turning that coil
    # into its casting orientation does not fold or cross the body through itself.
    positions=[a[name].translation.lerp(b[name].translation,weight) for name in spine]
    positions.append((a[spine[-1]]@Vector((0,_LENGTHS[-1],0))).lerp(b[spine[-1]]@Vector((0,_LENGTHS[-1],0)),weight))
    heart_position=a['core'].translation.lerp(b['core'].translation,weight)
    rotations=[a['ring_%02d'%ring].to_quaternion().slerp(b['ring_%02d'%ring].to_quaternion(),weight).to_matrix() for ring in range(40)]
    head_global=a['head'].to_quaternion().slerp(b['head'].to_quaternion(),weight).to_matrix()
    head_rotation=head_global@rest['head'].to_3x3().transposed()
    scale=a['core'].to_scale().x*(1-weight)+b['core'].to_scale().x*weight
    result=_assemble(positions,rotations,head_rotation,scale,0.,heart_position-core)
    heart_rotation=a['core'].to_quaternion().slerp(b['core'].to_quaternion(),weight).to_matrix()
    result['core']=heart_rotation.to_4x4()@Matrix.Diagonal((scale,scale,scale,1.)); result['core'].translation=heart_position
    return result

def frame_pose(clip,t,duration):
    if clip=='idle': return _idle_pose(t,duration)
    if clip=='walk': return _walk_pose(t,duration)
    if clip=='attack': return _approved_orbit('attack',t,duration)
    calm=_idle_pose(0)
    orbit_start=_approved_orbit('walk',0.,6.)
    if t<1.:
        if t<=0.: return calm
        return _transition_pose(calm,orbit_start,ease(t))
    if t<=7.: return _approved_orbit('walk',t-1.,6.)
    if t>=duration: return calm
    return _transition_pose(orbit_start,calm,ease((t-7.)/(duration-7.)))

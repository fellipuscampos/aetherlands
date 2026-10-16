"""Locomotion along a closed spatial curve: every segment follows the head's route."""
import bisect
_LENGTHS=[rig.data.bones[name].length for name in spine]
_REST_FORWARD=Vector((0,-1,0))
_BODY=next(obj for obj in parts if obj['part']=='Continuous_serpentine_body')
_SECTION_FRAMES=[]
for ring in range(40):
    v=[_BODY.data.vertices[ring*4+j].co for j in range(4)]
    right=(v[1]-v[0]).normalized(); front=(v[2]-v[0]).normalized()
    _SECTION_FRAMES.append(Matrix((right,front,right.cross(front))).transposed())
_PATH_COUNT=4096
_PATH=[]
for i in range(_PATH_COUNT+1):
    u=math.tau*i/_PATH_COUNT
    radius=1.20+.23*math.cos(3*u)
    _PATH.append(core+Vector((radius*math.cos(2*u),radius*math.sin(2*u),.78*math.sin(3*u))))
_DIST=[0.]
for a,b in zip(_PATH,_PATH[1:]): _DIST.append(_DIST[-1]+(b-a).length)
_CIRCUMFERENCE=_DIST[-1]
_bsdf=material.node_tree.nodes['Principled BSDF']
_driver=_bsdf.inputs['Emission Strength'].driver_add('default_value').driver
for variable in list(_driver.variables): _driver.variables.remove(variable)
_driver.type='SCRIPTED'; _driver.expression='max(0.35,1+(pulse-1)*5)'
_variable=_driver.variables.new(); _variable.name='pulse'; _variable.type='SINGLE_PROP'
_variable.targets[0].id=rig; _variable.targets[0].data_path='pose.bones["core"].scale[0]'

def _point(distance):
    d=distance%_CIRCUMFERENCE
    i=min(_PATH_COUNT-1,bisect.bisect_right(_DIST,d)-1)
    return _PATH[i].lerp(_PATH[i+1],(d-_DIST[i])/(_DIST[i+1]-_DIST[i]))

def _frame(distance):
    forward=(_point(distance+.005)-_point(distance-.005)).normalized()
    radial=_point(distance)-core
    up=(radial-forward*radial.dot(forward)).normalized()
    right=up.cross(forward).normalized()
    return Matrix((right,-forward,up)).transposed()

def frame_pose(clip,t,duration):
    phase=t/duration; p=math.tau*phase
    wind=hit=charge=release=jaw=0.
    if clip=='attack':
        wind=pulse(t,0,.50,.62,1.10); hit=pulse(t,.58,.87,.97,1.75)
        jaw=25*pulse(t,.12,.49,.73,1.08)
    elif clip=='spell':
        charge=pulse(t,0,1.15,2.25,3.85); release=pulse(t,1.85,2.22,2.34,2.95)
        jaw=13*charge+6*release
    # Both loops and gestures complete a circuit. Gestures accelerate and recover
    # on the route, rather than reversing the body or bending it off the trajectory.
    travel=phase if clip in ('idle','walk') else ease(phase)
    distance=.12*_CIRCUMFERENCE+travel*_CIRCUMFERENCE
    distances=[distance]; nodes=[_point(distance)]
    # Find the next location on the trajectory by chord length, keeping every
    # vertebra at its original size instead of squeezing or stretching the mesh.
    for length in _LENGTHS:
        lo=0.; hi=length*1.7
        for iteration in range(15):
            step=(lo+hi)*.5
            if (_point(distances[-1]-step)-nodes[-1]).length<length: lo=step
            else: hi=step
        d=distances[-1]-(lo+hi)*.5
        direction=(_point(d)-nodes[-1]).normalized()
        nodes.append(nodes[-1]+direction*length); distances.append(d)
    pose={'root':rest['root'].copy()}
    for j,name in enumerate(spine):
        direction=(nodes[j+1]-nodes[j]).normalized()
        rotation=(rig.data.bones[name].tail_local-rig.data.bones[name].head_local).normalized().rotation_difference(direction).to_matrix()@rest[name].to_3x3()
        matrix=rotation.to_4x4(); matrix.translation=nodes[j]; pose[name]=matrix
    for ring in range(40):
        j=39-ring; name='ring_%02d'%ring
        # The frame is transported along the path. No sinusoidal local twisting.
        tangent=(_point(distances[j]+.005)-_point(distances[j]-.005)).normalized()
        basis=_frame(distances[j])
        desired=Matrix((-basis.col[0],-basis.col[2],tangent)).transposed()
        rotation=desired@_SECTION_FRAMES[ring].transposed()@rest[name].to_3x3()
        matrix=rotation.to_4x4(); matrix.translation=nodes[j]; pose[name]=matrix
    direction=(_point(distance+.005)-_point(distance-.005)).normalized()
    direction=Vector((direction.x,direction.y,direction.z*.25)).normalized()
    radial=_point(distance)-core
    up=Vector((radial.x,radial.y,.85))
    up=(up-direction*up.dot(direction)).normalized()
    head_rotation=Matrix((up.cross(direction),-direction,up)).transposed()
    head_transform=head_rotation.to_4x4()@Matrix.Translation(-rest[spine[0]].translation)
    head_transform.translation+=nodes[0]
    for bone in rig.data.bones:
        name=bone.name
        if name in pose: continue
        parent=bone.parent.name; pose[name]=pose[parent]@rest[parent].inverted()@rest[name]
        if name=='head':
            pose[name]=head_transform@rest[name]
        elif name=='jaw': pose[name]=pose[name]@Matrix.Rotation(math.radians(-jaw),4,'X')
        elif name.startswith('whisker_'):
            side=int(name.split('_')[1]); segment=int(name.split('_')[2])
            pose[name]=rotated_at(pose[name],'Z',math.radians(side*1.5)*math.sin(p-.24*segment))
        elif name=='core':
            scale=1+.10*math.sin(2*p) if clip=='idle' else (1+.13*math.sin(2*p) if clip=='walk' else (1-.10*wind+.20*hit if clip=='attack' else 1-.13*charge+.34*release))
            pose[name]=rotated_at(rest[name],'Z',p)@Matrix.Diagonal((scale,scale,scale,1.))
    G=Matrix.Translation((0,0,.018*math.sin(p)))
    return {name:G@matrix for name,matrix in pose.items()}

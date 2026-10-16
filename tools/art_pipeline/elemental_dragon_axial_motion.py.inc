"""Coiling about the heart axis and a traveling roll along the serpent's own spine."""
_NODES=[rig.data.bones[name].head_local.copy() for name in spine]+[rig.data.bones[spine[-1]].tail_local.copy()]
_LENGTHS=[rig.data.bones[name].length for name in spine]
_RADII=[(point-core).length for point in _NODES]
_HEART_RADIUS=max((v.co-core).length for obj in parts if obj['rig_bone']=='core' for v in obj.data.vertices)
_bsdf=material.node_tree.nodes['Principled BSDF']
_driver=_bsdf.inputs['Emission Strength'].driver_add('default_value').driver
for variable in list(_driver.variables): _driver.variables.remove(variable)
_driver.type='SCRIPTED'; _driver.expression='max(0.35,1+(pulse-1)*5)'
_variable=_driver.variables.new(); _variable.name='pulse'; _variable.type='SINGLE_PROP'
_variable.targets[0].id=rig; _variable.targets[0].data_path='pose.bones["core"].scale[0]'

def frame_pose(clip,t,duration):
    p=math.tau*t/duration; wind=hit=charge=release=jaw=0.
    activity=math.sin(p/2)**2
    gain=.72 if clip=='idle' else (1. if clip=='walk' else .9)
    lean=lift=advance=0.
    if clip=='idle':
        heart_scale=1+.10*math.sin(2*p); lift=.018*math.sin(p)
    elif clip=='walk':
        heart_scale=1+.13*math.sin(2*p); lean=2.5; lift=.024*math.sin(p)
    elif clip=='attack':
        wind=pulse(t,0,.50,.62,1.10); hit=pulse(t,.58,.87,.97,1.75)
        heart_scale=1-.10*wind+.20*hit; jaw=25*pulse(t,.12,.49,.73,1.08)
        advance=.03*wind-.12*hit; lean=-1.5*wind+2.5*hit; lift=.04*hit
    else:
        charge=pulse(t,0,1.15,2.25,3.85); release=pulse(t,1.85,2.22,2.34,2.95)
        heart_scale=1-.13*charge+.34*release
        jaw=13*charge+6*release; lift=.12*charge+.035*release; lean=-2*charge
    growth=_HEART_RADIUS*max(0.,heart_scale-1)
    opening=.025*activity+growth*1.4+.030*charge+.020*hit
    neck_delta=Vector((0,.06*wind-.24*hit,.08*wind-.04*hit+.15*charge))
    desired=[]; rolls=[]
    for j,point in enumerate(_NODES):
        s=j/39; neck_weight=ease(s/.27); relative=point-core
        # Rotate the turns around the forward axis, rather than translating them sideways.
        coil_angle=(.33*gain*math.sin(p)-.26*wind+.38*hit+.12*charge*math.sin(p))*neck_weight
        rotation=Matrix.Rotation(coil_angle,3,'Y')
        delta=rotation@relative
        delta*=1+opening/max(.65,relative.length)
        target=core+delta+neck_delta*(1-neck_weight)
        if j==0: target=point+neck_delta
        desired.append(target)
        # Each section rolls around its own longitudinal tangent, with a delay down the column.
        phase=-math.tau*.85*s
        rolls.append(.40*gain*neck_weight*(math.sin(p+phase)-math.sin(phase)))
    positions=[point.copy() for point in desired]
    safe_radii=[radius-.003+growth+.055*activity+.015*charge for radius in _RADII]
    for iteration in range(160):
        order=range(39) if iteration%2==0 else range(38,-1,-1)
        for j in order:
            difference=positions[j+1]-positions[j]; length=difference.length
            if length<1e-8: continue
            correction=difference*((length-_LENGTHS[j])/length)
            if j==0: positions[j+1]-=correction
            else:
                positions[j]+=correction*.5; positions[j+1]-=correction*.5
        for j in range(1,40):
            if _RADII[j]>1.15: continue
            difference=positions[j]-core; length=difference.length
            if length<safe_radii[j]: positions[j]=core+difference*(safe_radii[j]/max(length,1e-8))
        positions[0]=desired[0]
    pose={'root':rest['root'].copy()}; current=positions[0]
    posed_nodes=[]
    for j,name in enumerate(spine):
        bone=rig.data.bones[name]; direction=(positions[j+1]-current).normalized()
        swing=(bone.tail_local-bone.head_local).normalized().rotation_difference(direction).to_matrix()@rest[name].to_3x3()
        rotation=swing
        matrix=rotation.to_4x4(); matrix.translation=current; pose[name]=matrix
        posed_nodes.append(current.copy())
        current=current+direction*bone.length
    posed_nodes.append(current.copy())
    for ring in range(40):
        j=39-ring
        normal=(posed_nodes[max(0,j-1)]-posed_nodes[min(39,j+1)]).normalized()
        swing=_RING_NORMALS[ring].rotation_difference(normal).to_matrix()
        rotation=Matrix.Rotation(rolls[j],3,normal)@swing@rest['ring_%02d'%ring].to_3x3()
        matrix=rotation.to_4x4(); matrix.translation=posed_nodes[j]
        pose['ring_%02d'%ring]=matrix
    for bone in rig.data.bones:
        name=bone.name
        if name in pose: continue
        parent=bone.parent.name; pose[name]=pose[parent]@rest[parent].inverted()@rest[name]
        if name=='head':
            pose[name]=rest[name].copy(); pose[name].translation+=neck_delta
            pose[name]=rotated_at(pose[name],'X',math.radians(-3*wind+3*hit-5*charge))
        elif name=='jaw': pose[name]=rotated_at(pose[name],'X',math.radians(jaw))
        elif name.startswith('whisker_'):
            side=int(name.split('_')[1]); segment=int(name.split('_')[2]); lag=.30*segment
            pose[name]=rotated_at(pose[name],'Z',math.radians(side*2.0)*(math.sin(p-lag)-math.sin(-lag)))
        elif name=='core':
            angle=p if clip in ('idle','walk') else math.tau*(2 if clip=='spell' else 1)*ease(t/duration)
            pose[name]=rotated_at(rest[name],'Z',angle)@Matrix.Diagonal((heart_scale,heart_scale,heart_scale,1.))
    G=Matrix.Translation((0,advance,lift+.15))@Matrix.Translation(core)@Matrix.Rotation(math.radians(lean),4,'X')@Matrix.Translation(-core)
    return {name:G@matrix for name,matrix in pose.items()}

"""Traveling 3D bends, constrained spine and a breathing elemental heart."""
_NODES=[rig.data.bones[name].head_local.copy() for name in spine]+[rig.data.bones[spine[-1]].tail_local.copy()]
_LENGTHS=[rig.data.bones[name].length for name in spine]
_RADII=[(point-core).length for point in _NODES]
_HEART_RADIUS=max((v.co-core).length for obj in parts if obj['rig_bone']=='core' for v in obj.data.vertices)

# The Blender source also displays the energy pulse; Godot reconstructs this from the core scale track.
_bsdf=material.node_tree.nodes['Principled BSDF']
_driver=_bsdf.inputs['Emission Strength'].driver_add('default_value').driver
_driver.type='SCRIPTED'; _driver.expression='max(0.35,1+(pulse-1)*5)'
_variable=_driver.variables.new(); _variable.name='pulse'; _variable.type='SINGLE_PROP'
_variable.targets[0].id=rig; _variable.targets[0].data_path='pose.bones["core"].scale[0]'

def frame_pose(clip,t,duration):
    p=math.tau*t/duration; wind=hit=charge=release=jaw=0.
    activity=math.sin(p/2)**2
    gain=.70 if clip=='idle' else (1.05 if clip=='walk' else .95)
    lean=lift=advance=0.
    if clip=='idle':
        heart_scale=1+.10*math.sin(2*p); lift=.018*math.sin(p)
    elif clip=='walk':
        heart_scale=1+.13*math.sin(2*p); lean=2.5; lift=.024*math.sin(p)
    elif clip=='attack':
        wind=pulse(t,0,.50,.62,1.10); hit=pulse(t,.58,.87,.97,1.75)
        heart_scale=1-.10*wind+.20*hit
        jaw=25*pulse(t,.12,.49,.73,1.08)
        advance=.03*wind-.12*hit; lean=-1.5*wind+2.5*hit; lift=.04*hit
    else:
        charge=pulse(t,0,1.15,2.25,3.85); release=pulse(t,1.85,2.22,2.34,2.95)
        heart_scale=1-.13*charge+.34*release
        jaw=13*charge+6*release; lift=.12*charge+.035*release; lean=-2*charge
    growth=_HEART_RADIUS*max(0.,heart_scale-1)
    opening=.055*activity+growth*1.35+.045*charge+.025*hit
    desired=[]
    for j,point in enumerate(_NODES):
        s=j/39; phase=-math.tau*1.35*s; relative=point-core
        bend=.14*gain*(math.sin(p+phase)-math.sin(phase))
        twist=.085*gain*(math.cos(p+phase*.75)-math.cos(phase*.75))
        rotation=Matrix.Rotation(bend,3,'Y')@Matrix.Rotation(twist,3,'Z')
        delta=rotation@relative
        delta*=1+opening/max(.65,relative.length)
        delta.y+=.045*gain*(math.sin(p+phase+.6)-math.sin(phase+.6))
        neck=max(0.,1-s/.24)**3
        delta+=Vector((-.055*wind+.03*hit,.06*wind-.24*hit,.08*wind-.04*hit+.15*charge))*neck
        desired.append(core+delta)
    # Project the desired bends onto a chain of fixed-length links. The nearby turns breathe away from the heart.
    positions=[point.copy() for point in desired]
    safe_radii=[radius-.003+growth+.065*activity+.020*charge for radius in _RADII]
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
    for j,name in enumerate(spine):
        bone=rig.data.bones[name]; direction=(positions[j+1]-current).normalized()
        rotation=(bone.tail_local-bone.head_local).normalized().rotation_difference(direction).to_matrix()@rest[name].to_3x3()
        matrix=rotation.to_4x4(); matrix.translation=current; pose[name]=matrix
        current=current+direction*bone.length
    for bone in rig.data.bones:
        name=bone.name
        if name in pose: continue
        parent=bone.parent.name; pose[name]=pose[parent]@rest[parent].inverted()@rest[name]
        if name=='head':
            pose[name]=rotated_at(pose[name],'X',math.radians(-3*wind+3*hit-5*charge))
        elif name=='jaw': pose[name]=rotated_at(pose[name],'X',math.radians(jaw))
        elif name.startswith('whisker_'):
            side=int(name.split('_')[1]); segment=int(name.split('_')[2]); lag=.30*segment
            pose[name]=rotated_at(pose[name],'Z',math.radians(side*2.5)*(math.sin(p-lag)-math.sin(-lag)))
        elif name=='core':
            angle=p if clip in ('idle','walk') else math.tau*(2 if clip=='spell' else 1)*ease(t/duration)
            pose[name]=rotated_at(rest[name],'Z',angle)@Matrix.Diagonal((heart_scale,heart_scale,heart_scale,1.))
    G=Matrix.Translation((0,advance,lift))@Matrix.Translation(core)@Matrix.Rotation(math.radians(lean),4,'X')@Matrix.Translation(-core)
    return {name:G@matrix for name,matrix in pose.items()}

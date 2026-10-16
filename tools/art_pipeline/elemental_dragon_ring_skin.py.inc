"""Independent deformation rings keep the tube centered and smooth while its control chain rolls."""
body=next(obj for obj in parts if obj['part']=='Continuous_serpentine_body')
_RING_CENTERS=[]; _RING_NORMALS=[]
for ring in range(40):
    vertices=[body.data.vertices[ring*4+j].co.copy() for j in range(4)]
    _RING_CENTERS.append(sum(vertices,Vector())/4)
    _RING_NORMALS.append((vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized())
for obj in scene.objects: obj.select_set(False)
rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for ring in range(40):
    bone=rig.data.edit_bones.new('ring_%02d'%ring)
    bone.head=_RING_CENTERS[ring]; bone.tail=bone.head+_RING_NORMALS[ring]*.09
    bone.parent=rig.data.edit_bones['root']
bpy.ops.object.mode_set(mode='OBJECT')
body.vertex_groups.clear(); influences=[]
for ring in range(40):
    name='ring_%02d'%ring
    group=body.vertex_groups.get(name) or body.vertex_groups.new(name=name)
    group.add(list(range(ring*4,ring*4+4)),1.,'REPLACE')
    influences.extend([{name:1.}]*4)
body['_weights_json']=json.dumps(influences)
for obj in parts:
    if obj==body: continue
    label=obj['part']
    if label.startswith(('Belly_scale_','Side_scale_')):
        ring=int(label.split('_')[2])
    elif label.startswith('Tail_flame_'): ring=0
    else: continue
    name='ring_%02d'%ring
    obj.vertex_groups.clear(); group=obj.vertex_groups.new(name=name)
    group.add(list(range(len(obj.data.vertices))),1.,'REPLACE')
    obj['rig_bone']=name; obj['_weights_json']=''

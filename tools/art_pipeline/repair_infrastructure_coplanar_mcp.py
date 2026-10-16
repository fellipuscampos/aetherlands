"""Repair only identified exposed coplanar joints, in the running editor."""
import bpy
import hashlib
import json
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
REVIEW=ROOT/'art_source/infrastructure_roof_review'
audit_label=globals().get('REPAIR_AUDIT','before_face_repairs')
audit=json.loads((REVIEW/(audit_label+'.json')).read_text(encoding='utf-8'))
journal=REVIEW/'face_repairs.json'
assert not journal.exists() or audit_label!='before_face_repairs','Do not apply geometric adjustments twice.'
changes=json.loads(journal.read_text(encoding='utf-8')) if journal.exists() else []
for row in audit['assets']:
    if not row['overlaps']: continue
    plural={'human':'humans','elf':'elves','dwarf':'dwarves','orc':'orcs'}[row['civilization']]
    folder=row['asset']; out=ROOT/'assets/generated'/plural/'buildings'/folder
    report=json.loads((out/(folder+'_report.json')).read_text(encoding='utf-8'))
    scene=bpy.data.scenes[report['name']]
    parts={o['part']:o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio'}
    affected=set(); changed={}
    for pair in row['overlaps']: affected.update((pair['first'],pair['second']))
    def resize(obj,axis,size):
        lo=min(v.co[axis] for v in obj.data.vertices); hi=max(v.co[axis] for v in obj.data.vertices)
        center=(lo+hi)/2
        for vertex in obj.data.vertices: vertex.co[axis]=center+(vertex.co[axis]-center)*size/(hi-lo)
        obj.data.update()
    for name,obj in parts.items():
        reason=None
        if '_Canopy_' in name and any(n.startswith(name.rsplit('_Canopy_',1)[0]+'_Canopy_') for n in affected):
            i=int(name.rsplit('_',1)[1])
            if i in (1,2):
                depth=max(v.co.y for v in obj.data.vertices)-min(v.co.y for v in obj.data.vertices)
                resize(obj,1,depth*(.825 if i==1 else .45))
                reason='taper_canopy_depth'
        elif name.endswith('_Shaft') and name in affected:
            top=max(v.co.z for v in obj.data.vertices)
            for vertex in obj.data.vertices:
                if abs(vertex.co.z-top)<1e-6: vertex.co.z-=.010
            obj.data.update(); reason='terminate_shaft_inside_capital'
        elif '_Crop_' in name and any(n.startswith(name.split('_Crop_')[0]+'_Crop_') for n in affected):
            earth=parts[name.split('_Crop_')[0]+'_Earth']
            width=max(v.co.x for v in earth.data.vertices)-min(v.co.x for v in earth.data.vertices)
            resize(obj,0,min(.039,width*.16)); reason='separate_adjacent_crops'
        elif '_Edge_' in name and name in affected:
            prefix=name.rsplit('_Edge_',1)[0]
            left,right=parts[prefix+'_Jamb_-1'],parts[prefix+'_Jamb_1']
            span=min(v.co.x for v in right.data.vertices)-max(v.co.x for v in left.data.vertices)
            resize(obj,0,span); reason='butt_join_window_rails'
        elif '_Side_' in name and name in affected and name.split('_Side_')[0]+'_Earth' in parts:
            earth=parts[name.split('_Side_')[0]+'_Earth']
            depth=max(v.co.y for v in earth.data.vertices)-min(v.co.y for v in earth.data.vertices)
            resize(obj,1,depth-.002); reason='butt_join_planter_walls'
        elif name.endswith('_Back') and name in affected:
            width=max(v.co.x for v in obj.data.vertices)-min(v.co.x for v in obj.data.vertices)
            resize(obj,0,width-.008); reason='recess_bench_back_sides'
        elif name.startswith('Flue_Band_') and 'Flue_Band_0.56' in affected:
            resize(obj,1,.154); reason='project_flue_bands_beyond_masonry'
        elif name=='Mana_Root_Flow' and name in affected:
            a,b=Vector((.25,.05,.128)),Vector((-.07,-.13,.128))
            center=(a+b)/2; axis=(b-a).normalized(); length=(b-a).length
            for vertex in obj.data.vertices:
                distance=(vertex.co-center).dot(axis)
                vertex.co+=axis*(-distance*.016/length)
            obj.data.update(); reason='inset_flow_end_caps'
        elif name=='Granary_Hatch_Recess' and name in affected:
            for vertex in obj.data.vertices: vertex.co.y+=.003
            obj.data.update(); reason='recess_opening_behind_iron_strap'
        elif name=='Press_Gear_Bearing_Foot' and name in affected:
            top=max(v.co.z for v in obj.data.vertices)
            for vertex in obj.data.vertices:
                if abs(vertex.co.z-top)<1e-6: vertex.co.z-=.003
            obj.data.update(); reason='separate_adjacent_plinth_top_planes'
        if reason:
            data={'vertices':[[round(float(c),7) for c in v.co] for v in obj.data.vertices],'faces':[list(f.vertices) for f in obj.data.polygons]}
            changed[name]={'reason':reason,'sha256':hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()}
    assert changed,(folder,'No repair matches the detected overlaps')
    existing=next((r for r in changes if r['asset']==folder),None)
    if existing:
        assert not set(existing['parts']).intersection(changed),'A second repair of the same part needs explicit handling.'
        existing['parts'].update(changed)
        existing['exposed_overlap_faces_before']+=row['exposed_overlap_faces']
    else:
        changes.append({'asset':folder,'civilization':row['civilization'],'role':row['role'],'scene':scene.name,'exposed_overlap_faces_before':row['exposed_overlap_faces'],'parts':changed})
    scene['infrastructure_coplanar_review']=1
journal.write_text(json.dumps(changes,ensure_ascii=False,indent=2),encoding='utf-8')
result={'repaired_assets':len(changes),'repaired_parts':sum(len(r['parts']) for r in changes),'awaiting_reexport':True}

"""Verify preservation, straight roof edges and real support contact in Blender."""
import bpy
import hashlib
import json
import math
from pathlib import Path

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
REVIEW=ROOT/'art_source/infrastructure_roof_review'
before=json.loads((REVIEW/'source_before.json').read_text(encoding='utf-8'))
face_repairs=json.loads((REVIEW/'face_repairs.json').read_text(encoding='utf-8'))
verified=[]
for row in before:
    scene=bpy.data.scenes[row['scene']]
    parts={o['part']:o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio' and not o.get('preview_only')}
    plural={'human':'humans','elf':'elves','dwarf':'dwarves','orc':'orcs'}[row['civilization']]
    out=ROOT/'assets/generated'/plural/'buildings'/row['asset']
    report=json.loads((out/(row['asset']+'_report.json')).read_text(encoding='utf-8'))
    changed_assemblies=set(row['roofs'])
    protected=0
    surface_parts=next((r['parts'] for r in face_repairs if r['asset']==row['asset']),{})
    for name,original in row['geometry'].items():
        obj=parts[name]
        # Only the roof courses and ridge dimensions are authorized to change.
        if any(name.startswith(prefix+'_Tile_Course_') or name==prefix+'_Ridge' for prefix in changed_assemblies): continue
        data={'vertices':[[round(float(c),7) for c in v.co] for v in obj.data.vertices],'faces':[list(f.vertices) for f in obj.data.polygons]}
        signature=hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()
        expected=surface_parts.get(name,original)['sha256']
        assert signature==expected,(row['asset'],'unexpected detail changed',name)
        assert obj.get('region')==original['region']
        if name not in surface_parts: protected+=1
    support_contacts=0
    if changed_assemblies:
        assert scene['infrastructure_roof_review']==1
        revision=report['infrastructure_roof_review']
        for roof in revision['roofs']:
            courses=sorted([o for n,o in parts.items() if n.startswith(roof['roof']+'_Tile_Course_')],key=lambda o:int(o['part'].rsplit('_',1)[1]))
            assert len(courses)==roof['courses']
            assert abs(min(v.co.z for v in courses[0].data.vertices)-roof['base_height'])<1e-6
            for index,obj in enumerate(courses):
                assert all(not face.use_smooth for face in obj.data.polygons)
                bottom=min(v.co.z for v in obj.data.vertices)
                for edge in obj.data.edges:
                    a,b=[obj.data.vertices[i].co for i in edge.vertices]
                    if abs(a.z-bottom)>1e-6 or abs(b.z-bottom)>1e-6: continue
                    if abs(a.x-b.x)<1e-6 or abs(a.y-b.y)<1e-6: continue
                    # A diagonal is allowed only on the actual hex tile border.
                    assert any(abs(a.x*math.cos(math.radians(side*60))+a.y*math.sin(math.radians(side*60))-.9*math.sqrt(3)/2)<2e-6 and abs(b.x*math.cos(math.radians(side*60))+b.y*math.sin(math.radians(side*60))-.9*math.sqrt(3)/2)<2e-6 for side in range(6)),(row['asset'],obj['part'],'rounded corner remains')
                if index:
                    previous=courses[index-1]
                    assert abs(bottom-max(v.co.z for v in previous.data.vertices))<1e-6,(row['asset'],'disconnected tile courses')
            if roof['shape']=='straight_gable':
                depths=[max(v.co.y for v in obj.data.vertices)-min(v.co.y for v in obj.data.vertices) for obj in courses]
                assert max(depths)-min(depths)<1e-6
        for first,second in revision['support_contacts']:
            a,b=parts[first],parts[second]
            assert all(min(v.co[axis] for v in a.data.vertices)<=max(v.co[axis] for v in b.data.vertices)+1e-5 and min(v.co[axis] for v in b.data.vertices)<=max(v.co[axis] for v in a.data.vertices)+1e-5 for axis in range(3)),(row['asset'],'unsupported canopy',first,second)
            support_contacts+=1
    else:
        assert len(parts)==len(row['geometry'])
    verified.append({'asset':row['asset'],'status':'PASS','revised_roofs':len(changed_assemblies),'approved_parts_preserved':protected,'surface_parts_repaired':len(surface_parts),'new_support_contacts':support_contacts})
backup=ROOT/'art_source/infrastructure_before_roof_review'
manifest=json.loads((backup/'manifest.json').read_text(encoding='utf-8'))
assert all(hashlib.sha256((backup/r['path']).read_bytes()).hexdigest()==r['sha256'] for r in manifest['files'])
final_audit=json.loads((REVIEW/'after_face_repairs.json').read_text(encoding='utf-8'))
assert final_audit['exposed_overlap_faces']==0
summary={'status':'PASS','reviewed_assets':len(verified),'corrected_assets':sum(bool(r['revised_roofs'] or r['surface_parts_repaired']) for r in verified),'assets_with_corrected_roofs':sum(bool(r['revised_roofs']) for r in verified),'corrected_roofs':sum(r['revised_roofs'] for r in verified),'surface_parts_repaired':sum(r['surface_parts_repaired'] for r in verified),'exposed_coplanar_overlaps':0,'immutable_backup_verified':True,'assets':verified}
(ROOT/'docs/infrastructure_roof_review_validation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
result={k:v for k,v in summary.items() if k!='assets'}

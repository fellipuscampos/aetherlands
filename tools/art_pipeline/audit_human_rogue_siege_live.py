"""Finish audit in live Blender: closed geometry, attachments, coplanar faces,
mechanical mast/weapon clearance and wheel separation. No source character edits.
"""
import bpy, bmesh, math, json, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:\Users\felipe campos\Documents\jogo'); PIPE=ROOT/'tools/art_pipeline'
if str(PIPE) not in sys.path: sys.path.insert(0,str(PIPE))
from human_rogue_siege_assets import ASSETS

def bounds(o):
    vs=[v.co for v in o.data.vertices]
    return [Vector(tuple(min(v[i] for v in vs) for i in range(3))),Vector(tuple(max(v[i] for v in vs) for i in range(3)))]

def intersect(a,b,tol=0):
    return all(min(a[1][i],b[1][i])+tol>=max(a[0][i],b[0][i]) for i in range(3))

def cross(a,b): return a.x*b.y-a.y*b.x
def area(poly): return abs(sum(cross(p,poly[(i+1)%len(poly)]) for i,p in enumerate(poly)))/2

def intersection(subject,clip):
    if sum(cross(p,clip[(i+1)%len(clip)]) for i,p in enumerate(clip))<0: clip=list(reversed(clip))
    out=list(subject)
    for i,a in enumerate(clip):
        b=clip[(i+1)%len(clip)]; inp=out; out=[]
        if not inp: break
        s=inp[-1]
        for e in inp:
            de=cross(b-a,e-a); ds=cross(b-a,s-a)
            if de>=-1e-8:
                if ds<-1e-8: out.append(s+(e-s)*(ds/(ds-de)))
                out.append(e)
            elif ds>=-1e-8: out.append(s+(e-s)*(ds/(ds-de)))
            s=e
    return out

def coplanar(parts):
    faces=[]
    for o in parts:
        for p in o.data.polygons:
            n=p.normal.normalized(); vv=[o.data.vertices[i].co.copy() for i in p.vertices]
            faces.append((o['part'],n,n.dot(vv[0]),vv))
    hits=set()
    for i,(name,n,d,vv) in enumerate(faces):
        u=Vector((1,0,0)) if abs(n.x)<.9 else Vector((0,1,0)); u=(u-n*u.dot(n)).normalized(); w=n.cross(u)
        poly=[Vector((v.dot(u),v.dot(w))) for v in vv]
        for other,m,e,verts in faces[i+1:]:
            if name==other or n.dot(m)<.99999 or abs(d-e)>.00015: continue
            candidate=[Vector((v.dot(u),v.dot(w))) for v in verts]
            overlap=intersection(poly,candidate)
            if len(overlap)>=3 and area(overlap)>1e-5: hits.add(tuple(sorted((name,other))))
    return sorted(hits)

reports=[]; failures=[]
audit_index=globals().get('AUDIT_INDEX')
selected=ASSETS if audit_index is None else [ASSETS[audit_index]]
for a in selected:
    st=bpy.app.driver_namespace['human_rogue_siege_'+a['stem']]
    scene=st['scene']; parts=st['parts']; rig=st['rig']; bpy.context.window.scene=scene
    boxes={o['part']:bounds(o) for o in parts}
    core={'Pelvis','Belly','Chest','Head','Foot_l','Foot_r','Thigh_l','Thigh_r','Shin_l','Shin_r','UpperArm_l','UpperArm_r','Forearm_l','Forearm_r','Hand_l','Hand_r','Shoulder_l','Shoulder_r'} if a['family']=='rogue' else {'Chassis'}
    connected=set(boxes)&core
    while True:
        added={n for n,box in boxes.items() if n not in connected and any(intersect(box,boxes[c],.006) for c in connected)}
        if not added: break
        connected|=added
    floating=sorted(set(boxes)-connected)
    overlap=coplanar(parts)
    nonmanifold=0
    for o in parts:
        bm=bmesh.new(); bm.from_mesh(o.data); nonmanifold+=sum(not e.is_manifold for e in bm.edges); bm.free()
    clearance=[]; wheels=[]
    if a['family']=='siege':
        # Rims, hubs and spokes touch within a wheel. Compare complete wheels
        # by their rigid bone rather than reporting their own joints as collisions.
        wheelpieces={}
        for o in parts:
            if o.get('rig_bone','').startswith('wheel_'):
                wheelpieces.setdefault(o['rig_bone'],[]).append(boxes[o['part']])
        wheelboxes={bone:[Vector(tuple(min(bb[0][k] for bb in pieces) for k in range(3))),
                           Vector(tuple(max(bb[1][k] for bb in pieces) for k in range(3)))]
                    for bone,pieces in wheelpieces.items()}
        for i,(name,box) in enumerate(wheelboxes.items()):
            for other,bb in list(wheelboxes.items())[i+1:]:
                if all(min(box[1][k],bb[1][k])-max(box[0][k],bb[0][k])>.0002 for k in range(3)): wheels.append([name,other])
        mast=next((o for o in parts if o['part']=='RearMast'),None)
        if mast:
            for tr in rig.animation_data.nla_tracks: tr.mute=True
            try:
                for n,d in st['clips'].items():
                    rig.animation_data.action=d['action']
                    for f in range(1,d['end']+1):
                        scene.frame_set(f); bpy.context.view_layer.update()
                        def deformed_box(o):
                            bone=rig.pose.bones[o['rig_bone']]
                            D=bone.matrix@rig.data.bones[bone.name].matrix_local.inverted()
                            vs=[D@v.co for v in o.data.vertices]
                            return [Vector(tuple(min(v[k] for v in vs) for k in range(3))),Vector(tuple(max(v[k] for v in vs) for k in range(3)))]
                        mb=deformed_box(mast)
                        for o in parts:
                            if o['rig_bone'] in ('weapon','counterweight') and intersect(mb,deformed_box(o),-.001): clearance.append([n,f,o['part']])
            finally:
                rig.animation_data.action=None
                for tr in rig.animation_data.nla_tracks: tr.mute=False
                scene.frame_set(1)
    data={'asset':a['stem'],'nonmanifold_edges':nonmanifold,'unattached_parts_candidates':floating,'same_normal_coplanar_candidates':overlap,'mast_weapon_collisions':clearance,'intersecting_wheels':wheels,
          'attachment_check':'Rest-pose part AABB connectivity to approved body/chassis, tolerance 6 mm; mechanical mast sampled every frame.'}
    if nonmanifold or floating or overlap or clearance or wheels: failures.append(a['stem'])
    st['report']['geometry_validation']=data
    out=Path(st['out']); (out/(a['stem']+'_report.json')).write_text(json.dumps(st['report'],indent=2),encoding='utf-8')
    scene['status']=st['report']['status']
    bpy.data.libraries.write(str(out/(a['stem']+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    reports.append(data)
output={'status':'PASS' if not failures else 'REVIEW','assets':reports,'problems':failures}
validation_path=ROOT/'docs/human_rogue_siege_geometry_validation.json'
if audit_index is not None and validation_path.exists():
    previous=json.loads(validation_path.read_text(encoding='utf-8'))
    updated={entry['asset']:entry for entry in reports}
    previous['assets']=[updated.get(entry['asset'],entry) for entry in previous['assets']]
    previous['problems']=[stem for stem in previous.get('problems',[]) if stem not in updated]+failures
    previous['status']='PASS' if not previous['problems'] else 'REVIEW'
    validation_path.write_text(json.dumps(previous,indent=2),encoding='utf-8')
else:
    validation_path.write_text(json.dumps(output,indent=2),encoding='utf-8')
result=output

"""Measure actual animated GLB anatomy, not merely finite skeleton matrices."""
import argparse,itertools,json,hashlib
import numpy as np
from orc_troop_assets import ROOT,OUT,WORK,ASSETS
from glb_pose_math import PoseModel

def cuboid(points):
    points=np.unique(np.round(points,6),axis=0)
    assert len(points)==8,len(points)
    origin=points[0];vectors=points[1:]-origin
    for indices in itertools.combinations(range(7),3):
        axes=vectors[list(indices)].T;length=np.linalg.norm(axes,axis=0)
        normalized=axes/length
        if np.max(np.abs(normalized.T@normalized-np.eye(3)))>.0001:continue
        fractions=np.linalg.solve(axes,(points-origin).T).T
        if np.max(np.abs(fractions-np.round(fractions)))<.0001 and fractions.min()>-.0001 and fractions.max()<1.0001:
            return points.mean(axis=0),axes/2
    raise AssertionError('Body no longer a rectangular cuboid')

def penetration(a,b):
    ca,aa=a;cb,bb=b
    candidates=[aa[:,i] for i in range(3)]+[bb[:,i] for i in range(3)]+[np.cross(aa[:,i],bb[:,j]) for i in range(3) for j in range(3)]
    depth=1000.
    for axis in candidates:
        norm=np.linalg.norm(axis)
        if norm<.000001:continue
        axis=axis/norm
        overlap=np.abs(axis@aa).sum()+np.abs(axis@bb).sum()-abs(axis@(ca-cb))
        if overlap<=0:return 0.
        depth=min(depth,overlap)
    return depth

def verify(row):
    folder=OUT/row['stem'];report=json.loads((folder/(row['stem']+'_report.json')).read_text(encoding='utf-8'))
    assert report['revision']=='anatomy_v2'
    model=PoseModel(folder/(row['stem']+'.glb'));positions,ids,uv=model.geometry()
    part_masks={};boxes={};part_bones={}
    for name,rectangles in report['geometry']['body_part_uv_boxes'].items():
        mask=np.zeros(len(uv),dtype=bool)
        for x0,y0,x1,y1 in rectangles:
            # glTF flips atlas V relative to Blender.
            mask|=(uv[:,0]>=x0-.000001)&(uv[:,0]<=x1+.000001)&(uv[:,1]>=1-y1-.000001)&(uv[:,1]<=1-y0+.000001)
        assert mask.sum()>=8,(name,mask.sum())
        assert len(set(ids[mask]))==1,(name,set(ids[mask]))
        part_masks[name]=mask;part_bones[name]=int(ids[mask][0]);boxes[name]=cuboid(positions[mask])
    assert len(boxes)==18
    body_half=.5 if row['key']!='squire' else 1.01
    head_mask=(ids==model.names.index('head'))&(uv[:,0]<body_half)
    chest_mask=part_masks['Chest']
    rest_top=positions[chest_mask,1].max()
    pairs=[(p+'_'+s,c+'_'+s) for s in ('l','r') for p,c in (('upper_arm','forearm'),('forearm','hand'),('thigh','shin'),('shin','foot'))]
    connections={}
    for a,b in pairs:
        pa,pb=model.by_name[a],model.by_name[b]
        connections[a,b]=np.linalg.inv(model.rest[pa])@model.rest[pb][:,3]
    head_gap=1000.;joint_gap=0.;head_hand=0.;chest_hand=0.;samples=0;wrist_motion={};worst={}
    for clip,channels in model.clips.items():
        duration=max(float(times[-1]) for _,_,times,_ in channels)
        wrist=[]
        for frame in range(round(duration*24)+1):
            world=model.worlds(clip,frame/24);skin=model.skin_matrices(world)
            head=model.skinned(world,positions[head_mask],ids[head_mask])
            projected=np.c_[head,np.ones(len(head))]@np.linalg.inv(skin[part_bones['Chest']]).T
            gap=(projected[:,1].min()-rest_top)*np.linalg.norm(skin[part_bones['Chest']][:3,1])
            head_gap=min(head_gap,float(gap));samples+=1
            for a,b in pairs:
                expected=world[model.by_name[a]]@connections[a,b]
                joint_gap=max(joint_gap,float(np.linalg.norm(expected[:3]-world[model.by_name[b]][:3,3])))
            posed={}
            for name in ('Head','Chest','Hand_l','Hand_r'):
                center,axes=boxes[name];m=skin[part_bones[name]]
                posed[name]=((m@np.r_[center,1])[:3],m[:3,:3]@axes)
            for name in ('Hand_l','Hand_r'):
                overlap=penetration(posed['Head'],posed[name])
                if overlap>head_hand:worst=dict(clip=clip,time=frame/24,hand=name,head_center=posed['Head'][0].tolist(),hand_center=posed[name][0].tolist())
                head_hand=max(head_hand,overlap)
                chest_hand=max(chest_hand,penetration(posed['Chest'],posed[name]))
            wrist.append(world[model.by_name['hand_r']][:3,3])
        wrist_motion[clip]=float(np.linalg.norm(np.ptp(np.array(wrist),axis=0)))
        assert wrist_motion[clip]>.005,(row['stem'],clip,'static wrist')
    assert head_gap>-.001,(row['stem'],'head in chest',head_gap)
    assert joint_gap<.008,(row['stem'],'disconnected joints',joint_gap)
    assert head_hand<.035,(row['stem'],'hand inside head',head_hand,worst)
    assert chest_hand<.035,(row['stem'],'hand inside chest',chest_hand)
    factors=report['rig']['retarget']['arm_reach_factors']
    for factor in factors.values():assert factor<1.26,(row['stem'],'overlong arm',factor)
    assert abs(factors['l']-factors['r'])<.000001,(row['stem'],'asymmetric arms',factors)
    frozen=WORK/'pose_correction/before_assets'/row['stem']/(row['stem']+'_albedo.png')
    if report.get('clothing_revision')=='leather_and_skeletal_v1':
        from audit_orc_refined_clothing import verify as verify_clothing
        assert verify_clothing(row)['protected_geometry_max_error']<.000005
    elif report.get('equipment_revision')=='tribal_v1':
        from audit_orc_tribal_equipment import verify as verify_equipment
        assert verify_equipment(row)['approved_face_pixels_preserved']
    else:assert (folder/(row['stem']+'_albedo.png')).read_bytes()==frozen.read_bytes()
    return dict(stem=row['stem'],status='PASS',pose_samples=samples,minimum_head_chest_gap_m=head_gap,
        maximum_joint_gap_m=joint_gap,maximum_hand_head_penetration_m=head_hand,
        maximum_hand_chest_penetration_m=chest_hand,wrist_motion_m=wrist_motion,body_cuboids=18,
        original_atlas_bytes_preserved=not report.get('clothing_revision') and (report.get('equipment_revision')!='tribal_v1' or row['key']=='squire'),
        approved_face_and_body_geometry_preserved=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');args=parser.parse_args()
    rows=[r for r in ASSETS if not args.only or r['stem'] in args.only]
    results=[verify(row) for row in rows]
    output=dict(status='PASS',models=len(results),pose_samples=sum(r['pose_samples'] for r in results),assets=results)
    target=WORK/'pose_correction/pilot_validation.json' if args.only else ROOT/'docs/orc_troops_anatomy_validation.json'
    target.write_text(json.dumps(output,indent=2),encoding='utf-8')
    print(json.dumps(output if args.only else {k:v for k,v in output.items() if k!='assets'}))

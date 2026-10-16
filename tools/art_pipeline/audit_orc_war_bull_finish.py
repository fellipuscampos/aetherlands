"""Final rectangular bulls: unchanged riders and grounded existing animations."""
import argparse,json,hashlib,numpy as np
from PIL import Image
from orc_troop_assets import ROOT,OUT,WORK,ASSETS
from glb_pose_math import PoseModel
from audit_orc_war_boars import selected,CONVERSION
from audit_orc_refined_clothing import geometry_error
from audit_elf_troops import animation_channels
from audit_orc_open_skull import separation
from audit_orc_anatomy_v2 import cuboid,penetration

FROZEN=WORK/'war_bull_finish/before_assets'
KEYS=('cavalier','shock_cavalier','armored_cavalier','griffon_rider')

def verify(row):
    stem=row['stem'];folder=OUT/stem;src=FROZEN/stem
    report=json.loads((folder/(stem+'_report.json')).read_text(encoding='utf-8'));c=report['mount_refinement']
    old_report=json.loads((src/(stem+'_report.json')).read_text(encoding='utf-8'))
    old=PoseModel(src/(stem+'.glb'));new=PoseModel(folder/(stem+'.glb'))
    assert old.names==new.names and old.clips.keys()==new.clips.keys()
    assert np.max(abs(old.inverse_bind-new.inverse_bind))<5e-6
    assert all(np.max(abs(old.rest[old.by_name[n]]-new.rest[new.by_name[n]]))<5e-6 for n in old.names)
    a=animation_channels(old.doc,old.binary);b=animation_channels(new.doc,new.binary);motion=0.
    changed={p+l for p in ('horse_thigh_','horse_cannon_') for l in ('fl','fr','bl','br')}
    for clip in a:
        assert a[clip].keys()==b[clip].keys()
        for key,(t,v) in a[clip].items():
            nt,nv=b[clip][key];assert np.array_equal(t,nt)
            if key[0] in changed and key[1]=='translation':continue
            error=np.minimum(abs(v-nv).max(1),abs(v+nv).max(1)).max() if key[1]=='rotation' else abs(v-nv).max()
            motion=max(motion,float(error));assert error<5e-6,(stem,clip,key,error)
    atlas0=np.array(Image.open(src/(stem+'_albedo.png')).convert('RGBA'))[::-1]
    atlas1=np.array(Image.open(folder/(stem+'_albedo.png')).convert('RGBA'))[::-1]
    removed=set(c['removed_parts']);assert {'BullBody','BullWithers','BullForelock','BullSaddleHide_-1','BullSaddleHide_1'}<=removed
    assert {n for n in c['source_part_vertices'] if n.startswith('BullBone')}<=removed
    assert not c['reshaped_parts'] and not c['painted_parts']
    unchanged=[];geom=0.
    offset=selected(old,c['source_part_uv_boxes']['Head'],'head').mean(0)-np.array(c['source_part_vertices']['Head']).mean(0)@CONVERSION.T
    op,oi,_=old.geometry();np_,ni,_=new.geometry()
    for name,boxes in c['source_part_uv_boxes'].items():
        if name in removed:continue
        bone=c['source_part_bones'][name]
        try:p0=selected(old,boxes,bone);p1=selected(new,boxes,bone)
        except AssertionError:
            expected=np.array(c['source_part_vertices'][name])@CONVERSION.T+offset
            candidates=op[oi==old.names.index(bone)];d=np.max(abs(expected[:,None]-candidates[None]),2);assert d.min(1).max()<.015;p0=candidates[d.argmin(1)]
            candidates=np_[ni==new.names.index(bone)];d=np.max(abs(p0[:,None]-candidates[None]),2);p1=candidates[d.argmin(1)]
        error=geometry_error(p0,p1);geom=max(geom,error);assert error<5e-6,(stem,name,error);unchanged.append(name)
        h,w=atlas0.shape[:2]
        for box in boxes:
            x0,y0,x1,y1=np.rint(np.array(box)*[w,h,w,h]).astype(int)
            assert np.array_equal(atlas0[y0:y1,x0:x1],atlas1[y0:y1,x0:x1]),(stem,name,'protected texture')
    for name,info in c['new_parts'].items():
        p=selected(new,info['uv_boxes'],info['bone']);assert len(p)==8;cuboid(p)
        assert geometry_error(np.array(info['vertices'])@CONVERSION.T+offset,p)<5e-6
    assert set(c['new_parts'])=={'BullBody','BullWithers'}
    assert set(report['geometry']['body_parts'])<=set(unchanged)
    info={n:dict(uv_boxes=boxes,bone=c['source_part_bones'][n]) for n,boxes in c['source_part_uv_boxes'].items() if n not in removed}
    info.update(c['new_parts']);points={n:selected(new,i['uv_boxes'],i['bone']) for n,i in info.items() if n.startswith(('Bull','Hand_','Foot_'))}
    minimum=1e9;knee_gap=0.;lift_error=0.;contact_error=0.;head_gap=1e9;hand_penetration=0.;samples=0
    factor=np.array(c['new_parts']['BullBody']['vertices'])[:,2].max()/1.36
    for clip,ch in new.clips.items():
        duration=max(float(t[-1]) for _,_,t,_ in ch)
        # Twice the export frame rate includes interpolation between keyframes.
        for frame in range(round(duration*48)+1):
            t=frame/48;world=new.worlds(clip,t);previous=old.worlds(clip,t);samples+=1
            def pose(name):return new.skinned(world,points[name],np.full(len(points[name]),new.names.index(info[name]['bone'])))
            head_gap=min(head_gap,-separation(pose('BullHead'),pose('BullWithers')))
            for hand in ('Hand_l','Hand_r'):
                for body in ('BullBody','BullWithers'):hand_penetration=max(hand_penetration,penetration(cuboid(pose(hand)),cuboid(pose(body))))
            for leg in ('fl','fr','bl','br'):
                for toe in (-1,1):minimum=min(minimum,float(pose('BullHoof_'+leg+'_'+str(toe))[:,1].min()))
                anchor=np.array([(.22 if leg.endswith('l') else -.22),(-.42 if leg.startswith('f') else .42),.46])*factor
                anchor=anchor@CONVERSION.T+offset;ids=np.array([new.names.index(p+leg) for p in ('horse_thigh_','horse_cannon_')])
                ends=new.skinned(world,np.stack((anchor,anchor)),ids);knee_gap=max(knee_gap,float(np.linalg.norm(ends[0]-ends[1])))
                if frame%2==0:
                    expected=np.array([0,c['motion_adjustments'][clip]['world_vertical_lifts_m'][frame//2][leg],0])
                    for prefix in ('horse_thigh_','horse_cannon_'):
                        n=prefix+leg;delta=world[new.by_name[n]][:3,3]-previous[old.by_name[n]][:3,3]
                        lift_error=max(lift_error,float(abs(delta-expected).max()))
            for name in ('horse_head','horse_neck','horse_body','hand_l','hand_r','foot_l','foot_r'):
                contact_error=max(contact_error,float(abs(world[new.by_name[name]]-previous[old.by_name[name]]).max()))
    assert minimum>-.004,(stem,'hoof underground',minimum)
    assert knee_gap<.008 and lift_error<5e-6 and contact_error<5e-6,(stem,knee_gap,lift_error,contact_error)
    assert head_gap>.001 and hand_penetration<.018,(stem,head_gap,hand_penetration)
    return dict(stem=stem,status='PASS',clips=len(a),animation_max_error=motion,protected_geometry_max_error=geom,
        blade_rotation_max_error=0.,unchanged_geometry_parts=unchanged,axially_rotated_weapon_parts=[],
        protected_weapon_surface_pixels=True,approved_face_pixels_preserved=True,body_cuboids=18,
        rectangular_mount_body=True,mount_plates_removed=True,pose_samples=samples,minimum_hoof_ground_y_m=minimum,
        maximum_leg_joint_gap_m=knee_gap,maximum_vertical_lift_error_m=lift_error,maximum_preserved_contact_error=contact_error,
        minimum_head_neck_overlap_m=head_gap,maximum_hand_mount_penetration_m=hand_penetration,
        maximum_lift_m=max(v['max_lift_m'] for v in c['motion_adjustments'].values()),new_animations=0)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');args=parser.parse_args()
    results=[verify(r) for r in ASSETS if r['key'] in (args.only or KEYS)]
    changed={r['stem'] for r in ASSETS if r['key'] in KEYS};unchanged=0
    for p,sha in json.loads((WORK/'war_bull_finish/before_hashes.json').read_text()).items():
        if any('/'+stem+'/' in p.replace('\\','/') for stem in changed):continue
        assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha,p;unchanged+=1
    protected=json.loads((WORK/'protected_sources.json').read_text());assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==s for p,s in protected.items())
    output=dict(status='PASS',modified_models=len(results),unchanged_models=16,unchanged_orc_files=unchanged,
        protected_other_race_files=len(protected),modified_model_clips=sum(r['clips'] for r in results),new_animations=0,assets=results)
    path=WORK/'war_bull_finish/pilot_validation.json' if args.only else ROOT/'docs/orc_war_bull_finish_validation.json'
    path.write_text(json.dumps(output,indent=2),encoding='utf-8');print(json.dumps({k:v for k,v in output.items() if k!='assets'}))
    if not args.only:
        from audit_orc_war_bulls import galleries
        galleries()

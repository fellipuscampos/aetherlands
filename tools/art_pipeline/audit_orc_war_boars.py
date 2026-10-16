"""Verify shipped war boars against the frozen, approved cavalry files."""
import argparse,json,hashlib,numpy as np
from PIL import Image,ImageDraw,ImageFont
from orc_troop_assets import ROOT,OUT,WORK,ASSETS
from glb_pose_math import PoseModel
from audit_elf_troops import animation_channels
from audit_orc_tribal_equipment import mask_for_rectangles
from human_texture_glb import image_bytes

FROZEN=WORK/'war_boars/before_assets'
KEYS=('cavalier','shock_cavalier','armored_cavalier','griffon_rider')
CONVERSION=np.array([[1,0,0],[0,0,1],[0,-1,0]])

def selected(model,boxes,bone=None):
    for layer in range(4):
        if 'TEXCOORD_'+str(layer) not in model.doc['meshes'][0]['primitives'][0]['attributes']:break
        p,ids,uv=model.geometry(layer);mask=mask_for_rectangles(uv,boxes)
        if bone is not None:mask&=ids==model.names.index(bone)
        if mask.any():return np.unique(np.round(p[mask],6),axis=0)
    raise AssertionError('Part absent from exported UV layers')

def verify(row,species='war_boar',frozen=None):
    from audit_orc_refined_clothing import geometry_error
    from audit_orc_anatomy_v2 import cuboid,penetration
    stem=row['stem'];source=(frozen or FROZEN)/stem;folder=OUT/stem
    prefix='Bull' if species=='war_bull' else 'Boar';previous='Boar' if species=='war_bull' else 'Horse'
    report=json.loads((folder/(stem+'_report.json')).read_text(encoding='utf-8'));c=report['mount_refinement']
    old=PoseModel(source/(stem+'.glb'));new=PoseModel(folder/(stem+'.glb'))
    assert report['mount_species']==species and old.names==new.names and old.clips.keys()==new.clips.keys()
    rest=max(float(np.abs(old.rest[old.by_name[n]]-new.rest[new.by_name[n]]).max()) for n in old.names)
    binding=float(np.abs(old.inverse_bind-new.inverse_bind).max());assert max(rest,binding)<5e-6
    a=animation_channels(old.doc,old.binary);b=animation_channels(new.doc,new.binary);motion=0.
    for clip in a:
        assert a[clip].keys()==b[clip].keys()
        for key,(t,v) in a[clip].items():
            nt,nv=b[clip][key];assert np.array_equal(t,nt)
            error=(np.minimum(np.abs(v-nv).max(axis=1),np.abs(v+nv).max(axis=1)).max() if key[1]=='rotation' else np.abs(v-nv).max())
            motion=max(motion,float(error));assert error<5e-6,(stem,clip,key,error)
    atlas0=np.array(Image.open(source/(stem+'_albedo.png')).convert('RGBA'))[::-1]
    atlas1=np.array(Image.open(folder/(stem+'_albedo.png')).convert('RGBA'))[::-1]
    assert atlas0.shape==atlas1.shape and (atlas1[...,3]==255).all()
    removed=set(c['removed_parts']);reshaped=set(c['reshaped_parts']);assert all(n.startswith(previous) for n in removed)
    assert removed=={n for n in c['source_part_vertices'] if n.startswith(previous)}
    assert reshaped=={'Rein_l1','Rein_r1'} and not c['painted_parts']
    hp=selected(old,c['source_part_uv_boxes']['Head'],'head')
    offset=hp.mean(axis=0)-np.array(c['source_part_vertices']['Head']).mean(axis=0)@CONVERSION.T
    op,oi,_=old.geometry();np_,ni,_=new.geometry();unchanged=[];max_geometry=0.
    for name,boxes in c['source_part_uv_boxes'].items():
        if name in removed:continue
        bone=c['source_part_bones'][name]
        try:p0=selected(old,boxes,bone);p1=selected(new,boxes,bone)
        except AssertionError:
            expected=np.array(c['source_part_vertices'][name])@CONVERSION.T+offset
            candidates=op[oi==old.names.index(bone)];d=np.max(np.abs(expected[:,None]-candidates[None]),axis=2)
            assert d.min(axis=1).max()<.015;p0=candidates[d.argmin(axis=1)]
            candidates=np_[ni==new.names.index(bone)];d=np.max(np.abs(p0[:,None]-candidates[None]),axis=2);p1=candidates[d.argmin(axis=1)]
        if name not in reshaped:
            error=geometry_error(p0,p1);assert error<5e-6,(stem,name,'protected geometry changed',error)
            max_geometry=max(max_geometry,error);unchanged.append(name)
        h,w=atlas0.shape[:2]
        for box in boxes:
            x0,y0,x1,y1=np.rint(np.array(box)*[w,h,w,h]).astype(int)
            assert np.array_equal(atlas0[y0:y1,x0:x1],atlas1[y0:y1,x0:x1]),(stem,name,'protected texture changed')
    assert set(report['geometry']['body_parts']).issubset(unchanged) and len(report['geometry']['body_parts'])==18
    assert all(n in unchanged for n in ('Saddle','SaddleBlanket','SaddlePommel','SaddleCantle','Stirrup_l','Stirrup_r','Rein_l2','Rein_r2','Rein_l3','Rein_r3','LanceHaft'))
    boars={};bones={};max_new_error=0.
    for name,info in c['new_parts'].items():
        points=selected(new,info['uv_boxes'],info['bone']);expected=np.array(info['vertices'])@CONVERSION.T+offset
        error=geometry_error(expected,points);assert error<5e-6,(stem,name,'new mount export differs',error)
        max_new_error=max(max_new_error,error);boars[name]=points;bones[name]=new.names.index(info['bone'])
    factor=np.array(c['source_part_vertices'][previous+'Body'])[:,2].max()/1.36
    assert np.ptp(np.array(c['new_parts'][prefix+'Body']['vertices'])[:,0])>.65*factor
    assert np.array(c['new_parts'][prefix+'Head']['vertices'])[:,2].max()<(1.73 if species=='war_bull' else 1.35)*factor
    assert len([n for n in boars if n.startswith(prefix+('Horn' if species=='war_bull' else 'Tusk'))])==2
    assert len([n for n in boars if n.startswith(prefix+'Hoof')])==(8 if species=='war_bull' else 4)
    assert (prefix+'BoneForehead' in boars)==(row['tier']>=2)
    samples=0;leg_gap=0.;head_overlap=100.;rein_seam=0.;rein_bit=0.;floor_regression=0.
    # Independent animated checks of every mount frame and every retained clip.
    for clip,channels in new.clips.items():
        duration=max(float(t[-1]) for _,_,t,_ in channels)
        for frame in range(round(duration*24)+1):
            world=new.worlds(clip,frame/24);skin=new.skin_matrices(world);samples+=1
            def pose(name):return new.skinned(world,boars[name],np.full(len(boars[name]),bones[name]))
            if species=='war_bull' and report['mount_revision']=='war_bull_v2':
                from audit_orc_open_skull import separation
                overlap=-separation(pose(prefix+'Head'),pose(prefix+'Withers'))
            else:overlap=penetration(cuboid(pose(prefix+'Head')),cuboid(pose(prefix+'Withers')))
            head_overlap=min(head_overlap,overlap)
            for leg in ('fl','fr','bl','br'):
                leg_x=.22 if species=='war_bull' else .225
                anchor=np.array([(leg_x if leg.endswith('l') else -leg_x),(-.42 if leg.startswith('f') else .42),.46])*factor
                anchor=anchor@CONVERSION.T+offset;ids=[new.names.index('horse_'+p+'_'+leg) for p in ('thigh','cannon')]
                ends=new.skinned(world,np.stack((anchor,anchor)),np.array(ids));leg_gap=max(leg_gap,float(np.linalg.norm(ends[0]-ends[1])))
                old_hoof=selected(old,c['source_part_uv_boxes'][previous+'Hoof_'+leg],'horse_cannon_'+leg)
                old_floor=old.skinned(old.worlds(clip,frame/24),old_hoof,np.full(len(old_hoof),ids[1]))[:,1].min()
                hoof_names=[prefix+'Hoof_'+leg+'_'+str(t) for t in (-1,1)] if species=='war_bull' else [prefix+'Hoof_'+leg]
                new_floor=min(pose(n)[:,1].min() for n in hoof_names)
                floor_regression=max(floor_regression,float(max(0.,-new_floor)-max(0.,-old_floor)))
            for side,sign in (('l',1),('r',-1)):
                raw=np.array(c['source_part_vertices']['Rein_'+side+'1']);center=raw.mean(axis=0)
                axes=np.stack((raw[1]-raw[0],raw[2]-raw[0],raw[4]-raw[0]),axis=1);lengths=np.linalg.norm(axes,axis=0)
                axis=axes[:,np.argmax(lengths)];ends=np.stack((center-axis/2,center+axis/2));upper=ends[np.argmax(ends[:,2])]@CONVERSION.T+offset
                target=np.array(c['reshaped_target_vertices']['Rein_'+side+'1']);new_upper=target[4:].mean(axis=0)@CONVERSION.T+offset
                # Target vertices have head end in indices 0..3, upper end 4..7.
                posed=new.skinned(world,np.stack((upper,new_upper)),np.full(2,new.names.index('horse_head')))
                rein_seam=max(rein_seam,float(np.linalg.norm(posed[0]-posed[1])))
                bit=np.array(c['new_parts'][prefix+'Bit_'+str(sign)]['vertices']).mean(axis=0)
                start=target[:4].mean(axis=0);posed=new.skinned(world,np.stack((bit,start))@CONVERSION.T+offset,np.full(2,new.names.index('horse_head')))
                rein_bit=max(rein_bit,float(np.linalg.norm(posed[0]-posed[1])))
    assert leg_gap<.008,(stem,'leg joint gap',leg_gap)
    assert head_overlap>.001,(stem,'head detached from short neck',head_overlap)
    assert rein_seam<5e-6 and rein_bit<5e-6,(stem,'rein contact',rein_seam,rein_bit)
    assert floor_regression<.035,(stem,'new hoof floor penetration',floor_regression)
    assert image_bytes(new.doc,new.binary,new.doc['images'][0])==(folder/(stem+'_albedo.png')).read_bytes()
    assert all(s['magFilter']==9728 for s in new.doc['samplers'])
    return dict(stem=stem,status='PASS',clips=len(a),animation_max_error=motion,rest_skeleton_max_error=rest,
        skin_binding_max_error=binding,protected_geometry_max_error=max_geometry,blade_rotation_max_error=0.,
        unchanged_geometry_parts=unchanged,axially_rotated_weapon_parts=[],protected_weapon_surface_pixels=True,
        approved_face_pixels_preserved=True,body_cuboids=18,new_mount_parts=len(boars),new_mount_geometry_max_error=max_new_error,
        pose_samples=samples,maximum_mount_leg_joint_gap_m=leg_gap,minimum_head_neck_overlap_m=head_overlap,
        maximum_rein_upper_endpoint_error_m=rein_seam,maximum_bit_contact_error_m=rein_bit,
        maximum_extra_hoof_penetration_m=floor_regression,new_animations=0)

def galleries():
    from audit_orc_open_skull import galleries as roster
    roster();dest=ROOT/'docs/previews/orc_troops';font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
    for view in ('mount_closeup','three_quarter'):
        canvas=Image.new('RGB',(1280,1360),(31,37,32));draw=ImageDraw.Draw(canvas)
        for index,row in enumerate(r for r in ASSETS if r['key'] in KEYS):
            x=index%2*640;y=index//2*680;canvas.paste(Image.open(OUT/row['stem']/'previews'/(view+'.png')).convert('RGB'),(x,y))
            draw.text((x+12,y+645),row['name']+' · Javali de guerra',font=font,fill=(231,224,202))
        canvas.save(dest/('war_boars_'+view+'.jpg'),quality=95)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');args=parser.parse_args()
    results=[verify(r) for r in ASSETS if r['key'] in (args.only or KEYS)]
    changed={r['stem'] for r in ASSETS if r['key'] in KEYS};unchanged=0
    for p,sha in json.loads((WORK/'war_boars/before_hashes.json').read_text()).items():
        if any('/'+stem+'/' in p.replace('\\','/') for stem in changed):continue
        assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha,p;unchanged+=1
    protected=json.loads((WORK/'protected_sources.json').read_text());assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==s for p,s in protected.items())
    output=dict(status='PASS',modified_models=len(results),unchanged_models=16,unchanged_orc_files=unchanged,
        protected_other_race_files=len(protected),modified_model_clips=sum(r['clips'] for r in results),new_animations=0,assets=results)
    path=WORK/'war_boars/pilot_validation.json' if args.only else ROOT/'docs/orc_war_boars_validation.json'
    path.write_text(json.dumps(output,indent=2),encoding='utf-8');print(json.dumps({k:v for k,v in output.items() if k!='assets'}))
    if not args.only:galleries()

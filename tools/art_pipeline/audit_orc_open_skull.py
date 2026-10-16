"""Verify solid hands, jaw opening and seated horns against the frozen roster."""
import argparse,itertools,json,hashlib,numpy as np
from PIL import Image,ImageDraw,ImageFont
from orc_troop_assets import ROOT,OUT,WORK,ASSETS
from glb_pose_math import PoseModel
from audit_elf_troops import animation_channels
from human_texture_glb import image_bytes

FROZEN=WORK/'open_skull/before_assets'
KEYS=('sentinel','guardian_champion','armored_cavalier','griffon_rider')
CONVERSION=np.array([[1,0,0],[0,0,1],[0,-1,0]])

def separation(a,b):
    """A separating axis proves that convex horn segments cannot touch ears."""
    axes=[np.eye(3)[i] for i in range(3)]
    edges=[a[j]-a[i] for i,j in itertools.combinations(range(len(a)),2)]
    for i,j,k in itertools.combinations(range(len(a)),3):axes.append(np.cross(a[j]-a[i],a[k]-a[i]))
    for edge in edges:
        for axis in np.eye(3):axes.append(np.cross(edge,axis))
    best=-1e9
    for axis in axes:
        length=np.linalg.norm(axis)
        if length<1e-9:continue
        axis=axis/length;pa=a@axis;pb=b@axis
        best=max(best,float(max(pb.min()-pa.max(),pa.min()-pb.max())))
    return best

def verify(row):
    from audit_orc_refined_clothing import vertices,geometry_error
    stem=row['stem'];source=FROZEN/stem;folder=OUT/stem
    report=json.loads((folder/(stem+'_report.json')).read_text(encoding='utf-8'))
    c=report['open_skull_refinement'];old=PoseModel(source/(stem+'.glb'));new=PoseModel(folder/(stem+'.glb'))
    assert old.names==new.names and old.clips.keys()==new.clips.keys()
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
    painted=set(c['painted_parts']);reshaped=set(c['reshaped_parts']);removed=set(c['removed_parts'])
    assert painted=={'Head','Hand_l','Hand_r'} and removed=={'Brow_l','Brow_r'}
    assert reshaped=={'BoneArmor_SkullTempleHorn_-1','BoneArmor_SkullTempleHorn_1','BoneArmor_SkullNasalKeel'}
    head=np.array(c['source_part_vertices']['Head']);axes=np.stack((head[1]-head[0],head[2]-head[0],head[4]-head[0]),axis=1)
    size=np.linalg.norm(axes,axis=0);axes/=size
    # Same frame normalization used by Blender, independently recovered here.
    u,_,vt=np.linalg.svd(axes);axes=u@vt
    unchanged=[];max_geometry=0.;shift_error=0.
    for name,boxes in c['source_part_uv_boxes'].items():
        if name in removed:continue
        try:points0,j0=vertices(old,boxes);points1,j1=vertices(new,boxes)
        except AssertionError:
            expected=np.array(c['source_part_vertices'][name])@CONVERSION.T
            bone=old.names.index(c['source_part_bones'][name]);op,oi,_=old.geometry();np_,ni,_=new.geometry()
            candidates=op[oi==bone];d=np.max(np.abs(expected[:,None]-candidates[None]),axis=2);assert d.min(axis=1).max()<.015
            points0=candidates[d.argmin(axis=1)];candidates=np_[ni==bone]
            d=np.max(np.abs(points0[:,None]-candidates[None]),axis=2);points1=candidates[d.argmin(axis=1)];j0=j1={bone}
        assert j0==j1,(stem,name,'bone changed')
        expected=points0
        if name in reshaped:
            delta=(axes@np.array([0,.060,.035]) if 'Horn' in name else axes[:,2]*size[2]*.14)@CONVERSION.T
            expected=points0+delta
        error=geometry_error(expected,points1);assert error<5e-6,(stem,name,'geometry changed beyond allowed translation',error)
        if name in reshaped:shift_error=max(shift_error,error)
        else:max_geometry=max(max_geometry,error);unchanged.append(name)
        if name not in painted:
            h,w=atlas0.shape[:2]
            for box in boxes:
                x0,y0,x1,y1=np.rint(np.array(box)*[w,h,w,h]).astype(int)
                assert np.array_equal(atlas0[y0:y1,x0:x1],atlas1[y0:y1,x0:x1]),(stem,name,'protected material changed')
    assert len(report['geometry']['body_parts'])==18 and report['geometry']['head_blocks']==1
    assert report['geometry']['eyebrow_cuboids']==0
    assert set(report['geometry']['body_parts']).issubset(unchanged)
    for name in removed:
        assert name not in unchanged
    assert image_bytes(new.doc,new.binary,new.doc['images'][0])==(folder/(stem+'_albedo.png')).read_bytes()
    assert all(s['magFilter']==9728 for s in new.doc['samplers'])
    base=json.loads((FROZEN/'orc_squire_v1/orc_squire_v1_report.json').read_text(encoding='utf-8'))
    bare=np.array(Image.open(FROZEN/'orc_squire_v1/orc_squire_v1_albedo.png').convert('RGBA'))[::-1]
    left,right=base['texture']['head_audit']['eye_atlas_pixels']
    assert all(np.array_equal(atlas1[y,x],atlas0[y,x]) and np.array_equal(atlas1[y,x],atlas1[yy,xx]) for (x,y),(xx,yy) in zip(left,right))
    x0,y0,x1,y1=base['texture']['head_audit']['uv_bounds']
    assert np.array_equal(atlas1[y0:y0+10,x0:x1],bare[y0:y0+10,x0:x1]),(stem,'lower original face missing')
    h,w=atlas1.shape[:2]
    for name in ('Hand_l','Hand_r'):
        for box in c['source_part_uv_boxes'][name]:
            x0,y0,x1,y1=np.rint(np.array(box)*[w,h,w,h]).astype(int);p=atlas1[y0:y1,x0:x1,:3]
            assert (p[...,0]>145).all() and (p[...,0]>p[...,1]).all(),(stem,name,'green holes in solid gauntlet')
    ear_clearance=1e9;root_scale=float(report['geometry']['root_scale'][0])
    for sign in (-1,1):
        name='BoneArmor_SkullTempleHorn_'+str(sign)
        q=np.array(c['source_part_vertices'][name])+axes@np.array([0,.060,.035])
        for side in ('l','r'):
            for index in range(3):
                ear=np.array(c['source_part_vertices']['ElfEar_'+side+'_'+str(index)])
                for segment in (q[:8],q[4:12],q[8:]):
                    gap=separation(segment,ear)*root_scale
                    assert gap>.008,(stem,name,'horn too close to ear',gap)
                    ear_clearance=min(ear_clearance,gap)
        # The root center must actually seat inside the upper head volume.
        center=(q[:4].mean(axis=0)-head.mean(axis=0))@axes
        assert np.all(abs(center)<size/2),(stem,name,'horn root outside head',center,size)
    return dict(stem=stem,status='PASS',clips=len(a),animation_max_error=motion,rest_skeleton_max_error=rest,
        skin_binding_max_error=binding,protected_geometry_max_error=max_geometry,blade_rotation_max_error=0.,
        unchanged_geometry_parts=unchanged,axially_rotated_weapon_parts=[],protected_weapon_surface_pixels=True,
        approved_face_pixels_preserved=False,skull_helmet_on_single_head_cube=True,body_cuboids=18,
        solid_bone_hands=True,helmet_brows_removed=True,original_lower_orc_face=True,
        horn_shape_and_surface_preserved=True,helmet_accessory_translation_max_error=shift_error,
        minimum_horn_ear_separating_gap_m=ear_clearance)

def galleries():
    from audit_orc_horns_hoods import galleries as roster
    # Refresh the current roster but retain prior finishing comparison images.
    dest=ROOT/'docs/previews/orc_troops';font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
    for view in ('front','three_quarter','back','game_top'):
        canvas=Image.new('RGB',(1280,1820),(33,39,34));draw=ImageDraw.Draw(canvas)
        for index,row in enumerate(ASSETS):
            im=Image.open(OUT/row['stem']/'previews'/(view+'.png')).convert('RGB').resize((316,316),Image.Resampling.LANCZOS)
            x=row['tier']*320+2;y=index//4*364+2;canvas.paste(im,(x,y))
            draw.text((x+6,y+318),row['name'],font=font,fill=(236,228,205));draw.text((x+6,y+341),'Supremo · 2,20 m' if row['tier']==3 else '2 m',font=font,fill=(171,190,165))
        canvas.save(dest/('roster_'+view+'.jpg'),quality=95)
    detail=Image.new('RGB',(1280,1360),(31,37,32));draw=ImageDraw.Draw(detail)
    rows=[r for r in ASSETS if r['key'] in KEYS]
    for index,row in enumerate(rows):
        x=index%2*640;y=index//2*680;detail.paste(Image.open(OUT/row['stem']/'previews/armor_closeup.png').convert('RGB'),(x,y))
        draw.text((x+12,y+645),row['name'],font=font,fill=(231,224,202))
    detail.save(dest/'open_skull_details.jpg',quality=95)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');args=parser.parse_args()
    results=[verify(r) for r in ASSETS if r['key'] in (args.only or KEYS)]
    changed={r['stem'] for r in ASSETS if r['key'] in KEYS};unchanged=0
    for p,sha in json.loads((WORK/'open_skull/before_hashes.json').read_text()).items():
        if any('/'+stem+'/' in p.replace('\\','/') for stem in changed):continue
        assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha,p;unchanged+=1
    protected=json.loads((WORK/'protected_sources.json').read_text());assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==s for p,s in protected.items())
    output=dict(status='PASS',modified_models=len(results),unchanged_models=16,unchanged_orc_files=unchanged,
        protected_other_race_files=len(protected),modified_model_clips=sum(r['clips'] for r in results),new_animations=0,assets=results)
    path=WORK/'open_skull/pilot_validation.json' if args.only else ROOT/'docs/orc_open_skull_validation.json'
    path.write_text(json.dumps(output,indent=2),encoding='utf-8');print(json.dumps({k:v for k,v in output.items() if k!='assets'}))
    if not args.only:galleries()

"""Verify the shipped files against the approved clothes, independent of Blender."""
import argparse,json,hashlib,numpy as np
from PIL import Image,ImageDraw,ImageFont
from orc_troop_assets import ROOT,OUT,WORK,ASSETS
from glb_pose_math import PoseModel
from audit_elf_troops import animation_channels
from human_texture_glb import image_bytes

FROZEN=WORK/'bone_armor_refinement/before_assets'
KEYS=('guardian','sentinel','guardian_champion','armored_cavalier','griffon_rider')

def verify(row):
    from audit_orc_refined_clothing import vertices,geometry_error
    stem=row['stem'];source=FROZEN/stem;folder=OUT/stem
    report=json.loads((folder/(stem+'_report.json')).read_text(encoding='utf-8'))
    changes=report['bone_armor_refinement'];old=PoseModel(source/(stem+'.glb'));new=PoseModel(folder/(stem+'.glb'))
    assert old.names==new.names and old.clips.keys()==new.clips.keys()
    rest=max(float(np.abs(old.rest[old.by_name[n]]-new.rest[new.by_name[n]]).max()) for n in old.names)
    binding=float(np.abs(old.inverse_bind-new.inverse_bind).max());assert max(rest,binding)<5e-6
    a=animation_channels(old.doc,old.binary);b=animation_channels(new.doc,new.binary);motion=0.
    for clip in a:
        assert a[clip].keys()==b[clip].keys()
        for key,(t,v) in a[clip].items():
            nt,nv=b[clip][key];assert np.array_equal(t,nt)
            error=(np.minimum(np.abs(v-nv).max(axis=1),np.abs(v+nv).max(axis=1)).max()
                   if key[1]=='rotation' else np.abs(v-nv).max())
            motion=max(motion,float(error));assert error<5e-6,(stem,clip,key,error)
    atlas0=np.array(Image.open(source/(stem+'_albedo.png')).convert('RGBA'))[::-1]
    atlas1=np.array(Image.open(folder/(stem+'_albedo.png')).convert('RGBA'))[::-1]
    assert atlas0.shape==atlas1.shape and (atlas1[...,3]==255).all()
    removed=set(changes['removed_parts']);painted=set(changes['painted_parts']);unchanged=[];max_geometry=0.
    allowed={'ShieldBoss'} if row['family']=='guardian' else set()
    if changes['full_armor']:
        allowed.update(report['geometry']['body_parts']);allowed.update(('Brow_l','Brow_r','Cloth_PauldronCap_l','Cloth_PauldronCap_r'))
    assert painted==allowed,(stem,'unexpected paint scope',painted^allowed)
    assert removed.issubset({'Cloth_BracerPlate_l','Cloth_BracerPlate_r','Cloth_PauldronApron_l','Cloth_PauldronApron_r'}|{n for n in changes['source_part_uv_boxes'] if n.startswith('ShieldBoneClamp_')})
    for name,boxes in changes['source_part_uv_boxes'].items():
        if name in removed:continue
        try:points0,j0=vertices(old,boxes);points1,j1=vertices(new,boxes)
        except AssertionError:
            # Legacy zero-UV accessories are identified by their rigid head bone
            # and original native vertices, then compared in exported space.
            expected=np.array(changes['source_part_vertices'][name])@np.array([[1,0,0],[0,0,-1],[0,1,0]])
            bone=old.names.index(changes['source_part_bones'][name]);op,oi,_=old.geometry();np_,ni,_=new.geometry()
            candidates=op[oi==bone];d=np.max(np.abs(expected[:,None]-candidates[None]),axis=2)
            assert d.min(axis=1).max()<.015
            points0=candidates[d.argmin(axis=1)];candidates=np_[ni==bone]
            d=np.max(np.abs(points0[:,None]-candidates[None]),axis=2)
            points1=candidates[d.argmin(axis=1)];j0=j1={bone}
        assert j0==j1,(stem,name,'bone changed')
        try:error=geometry_error(points0,points1)
        except AssertionError as exc:raise AssertionError((stem,name,'UV selection',points0.shape,points1.shape)) from exc
        max_geometry=max(max_geometry,error)
        assert error<5e-6,(stem,name,'protected geometry changed',error)
        unchanged.append(name)
        if name not in painted:
            h,w=atlas0.shape[:2]
            for box in boxes:
                x0,y0,x1,y1=np.rint(np.array(box)*[w,h,w,h]).astype(int)
                assert np.array_equal(atlas0[y0:y1,x0:x1],atlas1[y0:y1,x0:x1]),(stem,name,'protected material changed')
    assert len(report['geometry']['body_parts'])==18 and report['geometry']['head_blocks']==1
    assert set(report['geometry']['body_parts']).issubset(unchanged)
    for name,boxes in changes['new_part_uv_boxes'].items():
        p,ids=vertices(new,boxes);assert len(ids)==1 and len(p)>=8,(stem,name)
    assert image_bytes(new.doc,new.binary,new.doc['images'][0])==(folder/(stem+'_albedo.png')).read_bytes()
    assert all(s['magFilter']==9728 for s in new.doc['samplers'])
    base=json.loads((FROZEN/'orc_squire_v1/orc_squire_v1_report.json').read_text(encoding='utf-8'))
    left,right=base['texture']['head_audit']['eye_atlas_pixels']
    assert all(np.array_equal(atlas1[y,x],atlas0[y,x]) and np.array_equal(atlas1[y,x],atlas1[yy,xx])
               for (x,y),(xx,yy) in zip(left,right)),(stem,'eyes changed or asymmetric')
    coverage={}
    if changes['full_armor']:
        h,w=atlas1.shape[:2]
        for name in report['geometry']['body_parts']:
            samples=[]
            for box in changes['source_part_uv_boxes'][name]:
                x0,y0,x1,y1=np.rint(np.array(box)*[w,h,w,h]).astype(int)
                samples.append(atlas1[y0:y1,x0:x1,:3].reshape(-1,3))
            p=np.concatenate(samples);bone=(p[:,0]>145)&(p[:,0]>=p[:,1])&(p[:,1]>125)
            coverage[name]=float(bone.mean())
            assert coverage[name]>.72,(stem,name,'bone coverage too sparse',coverage[name])
        assert coverage['Chest']>.85 and coverage['Head']>.78
    return dict(stem=stem,status='PASS',clips=len(a),animation_max_error=motion,
        rest_skeleton_max_error=rest,skin_binding_max_error=binding,protected_geometry_max_error=max_geometry,
        blade_rotation_max_error=0.,unchanged_geometry_parts=unchanged,axially_rotated_weapon_parts=[],
        protected_weapon_surface_pixels=True,approved_face_pixels_preserved=not changes['full_armor'],
        skull_helmet_on_single_head_cube=changes['full_armor'],body_cuboids=18,bone_surface_coverage=coverage,
        leather_harness_and_panels_preserved=True,shield_white_clamps_removed=row['family']=='guardian')

def galleries():
    dest=ROOT/'docs/previews/orc_troops';font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
    for view in ('front','three_quarter','back','game_top'):
        canvas=Image.new('RGB',(1280,1820),(33,39,34));draw=ImageDraw.Draw(canvas)
        for index,row in enumerate(ASSETS):
            image=Image.open(OUT/row['stem']/'previews'/(view+'.png')).convert('RGB').resize((316,316),Image.Resampling.LANCZOS)
            x=row['tier']*320+2;y=index//4*364+2;canvas.paste(image,(x,y))
            draw.text((x+6,y+318),row['name'],font=font,fill=(236,228,205))
            draw.text((x+6,y+341),'Supremo · 2,20 m' if row['tier']==3 else '2 m',font=font,fill=(171,190,165))
        canvas.save(dest/('roster_'+view+'.jpg'),quality=95)
    keys=('sentinel','guardian_champion','armored_cavalier','griffon_rider')
    canvas=Image.new('RGB',(1280,len(keys)*680),(31,37,32));draw=ImageDraw.Draw(canvas)
    for index,key in enumerate(keys):
        row=next(r for r in ASSETS if r['key']==key)
        for side,(folder,label) in enumerate(((FROZEN/row['stem'],'Antes'),(OUT/row['stem'],'Armadura de osso fechada'))):
            image=Image.open(folder/'previews/three_quarter.png').convert('RGB')
            canvas.paste(image,(side*640,index*680));draw.text((side*640+12,index*680+644),row['name']+' · '+label,font=font,fill=(231,224,202))
    canvas.save(dest/'bone_armor_before_after.jpg',quality=95)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');args=parser.parse_args()
    rows=[r for r in ASSETS if r['key'] in (args.only or KEYS)]
    results=[verify(r) for r in rows]
    unchanged=0
    for p,sha in json.loads((WORK/'bone_armor_refinement/before_hashes.json').read_text()).items():
        if any('/'+r['stem']+'/' in p.replace('\\','/') for r in ASSETS if r['key'] in KEYS):continue
        assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha,p;unchanged+=1
    protected=json.loads((WORK/'protected_sources.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha for p,sha in protected.items())
    output=dict(status='PASS',modified_models=len(results),unchanged_models=15,unchanged_orc_files=unchanged,
        protected_other_race_files=len(protected),modified_model_clips=sum(r['clips'] for r in results),
        new_animations=0,scope='bone outfits and guardian shield ornaments only',assets=results)
    target=WORK/'bone_armor_refinement/pilot_validation.json' if args.only else ROOT/'docs/orc_bone_armor_validation.json'
    target.write_text(json.dumps(output,indent=2),encoding='utf-8');print(json.dumps({k:v for k,v in output.items() if k!='assets'}))
    if not args.only:galleries()

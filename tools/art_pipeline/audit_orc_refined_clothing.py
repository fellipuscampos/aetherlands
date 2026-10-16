"""Independent shipped-GLB proof of clothing scope and pure blade rotations."""
import argparse,json,hashlib,numpy as np
from PIL import Image,ImageDraw,ImageFont
from orc_troop_assets import ROOT,OUT,WORK,ASSETS
from glb_pose_math import PoseModel
from audit_elf_troops import animation_channels
from audit_orc_tribal_equipment import vertices as primary_vertices,mask_for_rectangles
from human_texture_glb import image_bytes

FROZEN=WORK/'clothing_refinement/before_assets'
CONVERSION=np.array([[1,0,0],[0,0,1],[0,-1,0]])

def vertices(model,rectangles):
    for layer in range(4):
        if 'TEXCOORD_'+str(layer) not in model.doc['meshes'][0]['primitives'][0]['attributes']:break
        positions,ids,uv=model.geometry(layer);mask=mask_for_rectangles(uv,rectangles)
        if mask.any():return np.unique(np.round(positions[mask],6),axis=0),set(ids[mask])
    raise AssertionError('No exported UV layer contains this part')

def geometry_error(a,b):
    assert a.shape==b.shape,(a.shape,b.shape)
    distance=np.max(np.abs(a[:,None,:]-b[None,:,:]),axis=2)
    return float(max(distance.min(axis=0).max(),distance.min(axis=1).max()))

def verify(row):
    stem=row['stem'];folder=OUT/stem;source=FROZEN/stem
    report=json.loads((folder/(stem+'_report.json')).read_text(encoding='utf-8'))
    if report.get('mount_revision')=='war_bull_v3':
        from audit_orc_war_bull_finish import verify as verify_bull_finish
        return verify_bull_finish(row)
    if report.get('mount_revision') in ('war_bull_v1','war_bull_v2'):
        from audit_orc_war_bulls import verify as verify_bulls
        return verify_bulls(row)
    if report.get('mount_revision')=='war_boar_v1':
        from audit_orc_war_boars import verify as verify_boars
        return verify_boars(row)
    if report.get('open_skull_revision')=='jawless_skull_v1':
        from audit_orc_open_skull import verify as verify_open_skull
        return verify_open_skull(row)
    if report.get('finishing_revision')=='forward_horns_and_painted_hoods_v1':
        from audit_orc_horns_hoods import verify as verify_finishing
        return verify_finishing(row)
    if report.get('bone_armor_revision')=='closed_carapace_v1':
        from audit_orc_closed_bone_armor import verify as verify_bone
        return verify_bone(row)
    assert report['clothing_revision']=='leather_and_skeletal_v1'
    changes=report['clothing_refinement'];old=PoseModel(source/(stem+'.glb'));new=PoseModel(folder/(stem+'.glb'))
    assert old.names==new.names and old.clips.keys()==new.clips.keys()
    rest=max(float(np.abs(old.rest[old.by_name[n]]-new.rest[new.by_name[n]]).max()) for n in old.names)
    binding=float(np.abs(old.inverse_bind-new.inverse_bind).max());assert max(rest,binding)<5e-6
    a=animation_channels(old.doc,old.binary);b=animation_channels(new.doc,new.binary);motion=0.
    for clip in a:
        assert a[clip].keys()==b[clip].keys()
        for key,(t,v) in a[clip].items():
            nt,nv=b[clip][key];assert t.shape==nt.shape and v.shape==nv.shape
            assert np.max(np.abs(t-nt))<1e-6
            error=(np.minimum(np.abs(v-nv).max(axis=1),np.abs(v+nv).max(axis=1)).max()
                   if key[1]=='rotation' else np.abs(v-nv).max())
            motion=max(motion,float(error));assert error<5e-6,(stem,clip,key,error)
    rotated={name:data for data in changes['blade_rotations'].values() for name in data['parts']}
    atlas0=np.array(Image.open(source/(stem+'_albedo.png')).convert('RGBA'))[::-1]
    atlas1=np.array(Image.open(folder/(stem+'_albedo.png')).convert('RGBA'))[::-1]
    assert atlas0.shape==atlas1.shape and (atlas1[...,3]==255).all()
    removed=set(changes['removed_parts']);painted=set(changes['repainted_parts'])
    unchanged=[];rotated_names=[];max_geometry=0.;rotation_error=0.
    for name,boxes in changes['source_part_uv_boxes'].items():
        if name in removed:continue
        try:points0,j0=vertices(old,boxes);points1,j1=vertices(new,boxes)
        except AssertionError:
            # Older elf-derived ear/tusk cubes have an inactive zero UV layer
            # in glTF. Verify these against their native vertices and head bone.
            expected=np.array(changes['source_part_vertices'][name])@CONVERSION.T
            bone=old.names.index(changes['source_part_bones'][name]);op,oi,_=old.geometry();np_,ni,_=new.geometry()
            source_error=float(np.max(np.abs(expected[:,None]-op[oi==bone][None]),axis=2).min(axis=1).max())
            assert source_error<5e-6,(stem,name,'native source object has a transform',source_error)
            points0=expected
            if name in rotated:
                data=rotated[name];rotation=np.array(data['rotation']);pivot=np.array(data['pivot'])
                expected=((expected@CONVERSION-pivot)@rotation.T+pivot)@CONVERSION.T
            candidates=np_[ni==bone];distance=np.max(np.abs(expected[:,None]-candidates[None]),axis=2)
            assert distance.min(axis=1).max()<5e-6,(stem,name,'zero-layer source geometry changed')
            points1=candidates[distance.argmin(axis=1)];j0=j1={bone}
        assert j0==j1,(stem,name,'bone reassigned')
        expected=points0
        if name in rotated:
            data=rotated[name];rotation=np.array(data['rotation']);pivot=np.array(data['pivot'])
            assert np.allclose(rotation.T@rotation,np.eye(3),atol=1e-6) and abs(np.linalg.det(rotation)-1)<1e-6
            expected=(((points0@CONVERSION-pivot)@rotation.T+pivot)@CONVERSION.T)
            rotated_names.append(name)
        error=geometry_error(expected,points1)
        assert error<5e-6,(stem,name,'shape or position changed',error)
        if name in rotated:rotation_error=max(rotation_error,error)
        else:max_geometry=max(max_geometry,error);unchanged.append(name)
        if name not in painted:
            h,w=atlas0.shape[:2]
            for box in boxes:
                x0,y0,x1,y1=np.rint(np.array(box)*[w,h,w,h]).astype(int)
                assert np.array_equal(atlas0[y0:y1,x0:x1],atlas1[y0:y1,x0:x1]),(stem,name,'protected surface changed')
    for grip,data in changes['blade_rotations'].items():
        assert grip in unchanged
        axis=np.array(data['axis']);forward=np.array(data['forward_edge'])
        assert abs(np.dot(axis,forward))<1e-6 and forward[1]<-.5
    assert len(report['geometry']['body_parts'])==18 and report['geometry']['head_blocks']==1
    assert all(name in unchanged for name in report['geometry']['body_parts'])
    assert all(name in unchanged for name in ('Brow_l','Brow_r'))
    for name,boxes in changes['new_part_uv_boxes'].items():
        try:p,ids=primary_vertices(new,boxes)
        except AssertionError as error:raise AssertionError((stem,name,'new detail UV missing from glTF')) from error
        assert len(ids)==1 and len(p)>=8,(stem,name)
    png=(folder/(stem+'_albedo.png')).read_bytes()
    assert image_bytes(new.doc,new.binary,new.doc['images'][0])==png
    assert all(s['magFilter']==9728 for s in new.doc['samplers'])
    # Eyes remain paired and visible even inside painted skull helmets.
    base=json.loads((FROZEN/'orc_squire_v1/orc_squire_v1_report.json').read_text(encoding='utf-8'))
    left,right=base['texture']['head_audit']['eye_atlas_pixels']
    assert all(np.array_equal(atlas1[y,x],atlas1[yy,xx]) for (x,y),(xx,yy) in zip(left,right)),(stem,'eyes asymmetric')
    if changes['skull_helmet']:
        x0,y0,x1,y1=base['texture']['head_audit']['uv_bounds'];face=atlas1[y0:y1,x0:x1,:3]
        green=(face[...,1]>face[...,0])&(face[...,1]>face[...,2]+20)
        bone=(face[...,0]>160)&(face[...,1]>140)&(face[...,2]>110)
        assert green.sum()>30 and bone.sum()>150,(stem,'unreadable skull or missing green negative space')
    return dict(stem=stem,status='PASS',clips=len(a),animation_max_error=motion,
                rest_skeleton_max_error=rest,skin_binding_max_error=binding,
                protected_geometry_max_error=max_geometry,blade_rotation_max_error=rotation_error,
                unchanged_geometry_parts=unchanged,axially_rotated_weapon_parts=rotated_names,
                protected_weapon_surface_pixels=True,approved_face_pixels_preserved=not changes['skull_helmet'],
                skull_helmet_on_single_head_cube=changes['skull_helmet'],body_cuboids=18)

def galleries():
    from audit_orc_tribal_equipment import galleries as roster
    # Build the current roster only; keep the previous weapon comparison intact.
    dest=ROOT/'docs/previews/orc_troops';font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
    for view in ('front','three_quarter','back','game_top'):
        canvas=Image.new('RGB',(1280,1820),(33,39,34));draw=ImageDraw.Draw(canvas)
        for index,row in enumerate(ASSETS):
            image=Image.open(OUT/row['stem']/'previews'/(view+'.png')).convert('RGB').resize((316,316),Image.Resampling.LANCZOS)
            x=row['tier']*320+2;y=index//4*364+2;canvas.paste(image,(x,y))
            draw.text((x+6,y+318),row['name'],font=font,fill=(236,228,205))
            draw.text((x+6,y+341),'Supremo · 2,20 m' if row['tier']==3 else '2 m',font=font,fill=(171,190,165))
        canvas.save(dest/('roster_'+view+'.jpg'),quality=95)
    keys=('squire','blade_hero','legend_hunter','griffon_rider','shadow_master')
    canvas=Image.new('RGB',(1280,len(keys)*680),(31,37,32));draw=ImageDraw.Draw(canvas)
    for index,key in enumerate(keys):
        row=next(r for r in ASSETS if r['key']==key)
        for side,(folder,label) in enumerate(((FROZEN/row['stem'],'Antes'),(OUT/row['stem'],'Couro e armadura revisados'))):
            image=Image.open(folder/'previews/three_quarter.png').convert('RGB').resize((640,640),Image.Resampling.LANCZOS)
            canvas.paste(image,(side*640,index*680));draw.text((side*640+12,index*680+644),row['name']+' · '+label,font=font,fill=(231,224,202))
    canvas.save(dest/'clothing_before_after.jpg',quality=95)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');args=parser.parse_args()
    rows=[r for r in ASSETS if not args.only or r['key'] in args.only];results=[verify(r) for r in rows]
    protected=json.loads((WORK/'protected_sources.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha for p,sha in protected.items())
    output=dict(status='PASS',models=len(results),clips=sum(r['clips'] for r in results),protected_files=len(protected),
                anatomy_and_weapon_grips_unchanged=True,weapon_shape_changes='axial rotation only',new_animations=0,assets=results)
    target=WORK/'clothing_refinement/pilot_validation.json' if args.only else ROOT/'docs/orc_clothing_refinement_validation.json'
    target.write_text(json.dumps(output,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in output.items() if k!='assets'}))
    if not args.only:galleries()

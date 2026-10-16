"""Verify unchanged animations, grips, anatomy and protected face pixels."""
import argparse,hashlib,json
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from orc_troop_assets import ROOT,OUT,WORK,ASSETS
from glb_pose_math import PoseModel
from human_texture_glb import image_bytes
from audit_elf_troops import animation_channels

FROZEN=WORK/'tribal_equipment/before_assets'

def mask_for_rectangles(uv,rectangles):
    mask=np.zeros(len(uv),dtype=bool)
    for x0,y0,x1,y1 in rectangles:
        mask|=(uv[:,0]>=x0-.000001)&(uv[:,0]<=x1+.000001)&(uv[:,1]>=1-y1-.000001)&(uv[:,1]<=1-y0+.000001)
    return mask

def vertices(model,rectangles):
    positions,ids,uv=model.geometry();mask=mask_for_rectangles(uv,rectangles)
    assert mask.any()
    return np.unique(np.round(positions[mask],6),axis=0),set(ids[mask])

def verify(row):
    stem=row['stem'];folder=OUT/stem;source=FROZEN/stem
    report=json.loads((folder/(stem+'_report.json')).read_text(encoding='utf-8'))
    if report.get('clothing_revision')=='leather_and_skeletal_v1':
        from audit_orc_refined_clothing import verify as verify_clothing
        current=verify_clothing(row)
        current['bone_armor_parts']=report['texture'].get('mounted_bone_armor_parts',[])
        return current
    before_report=json.loads((source/(stem+'_report.json')).read_text(encoding='utf-8'))
    assert report['equipment_revision']=='tribal_v1'
    old=PoseModel(source/(stem+'.glb'));new=PoseModel(folder/(stem+'.glb'))
    assert old.names==new.names and old.clips.keys()==new.clips.keys()
    rest_error=max(float(np.abs(old.rest[old.by_name[n]]-new.rest[new.by_name[n]]).max()) for n in old.names)
    assert rest_error<.000005,(stem,'rest skeleton changed',rest_error)
    bind_error=float(np.abs(old.inverse_bind-new.inverse_bind).max())
    assert bind_error<.000005,(stem,'skin binding changed',bind_error)
    before=animation_channels(old.doc,old.binary);after=animation_channels(new.doc,new.binary)
    maximum_error=0.
    for clip in before:
        assert before[clip].keys()==after[clip].keys(),(stem,clip)
        for key,(t,a) in before[clip].items():
            nt,b=after[clip][key]
            assert t.shape==nt.shape and a.shape==b.shape,(stem,clip,key)
            assert np.max(np.abs(t-nt))<.000001
            if key[1]=='rotation':error=np.minimum(np.abs(a-b).max(axis=1),np.abs(a+b).max(axis=1)).max()
            else:error=np.abs(a-b).max()
            maximum_error=max(maximum_error,float(error))
            assert error<.000005,(stem,clip,key,float(error))
    geometry_error=0.
    for name,rectangles in before_report['geometry']['body_part_uv_boxes'].items():
        a,ja=vertices(old,rectangles);b,jb=vertices(new,rectangles)
        assert a.shape==b.shape==(8,3) and ja==jb,(stem,name)
        error=float(np.abs(a-b).max());geometry_error=max(geometry_error,error)
        assert error<.000005,(stem,'anatomy changed',name,error)
    if row['key']=='squire':
        for suffix in ('.blend','.glb','_albedo.png'):
            assert (folder/(stem+suffix)).read_bytes()==(source/(stem+suffix)).read_bytes()
        grips=['ShieldGrip']
    else:
        grips=[]
        for name,data in report['tribal_equipment']['grips'].items():
            a,ja=vertices(old,data['uv_boxes']);b,jb=vertices(new,data['uv_boxes'])
            assert a.shape==b.shape==(8,3) and ja==jb
            error=float(np.abs(a-b).max())
            assert error<.000005,(stem,'grip moved',name,error)
            grips.append(name)
        assert grips,(stem,'missing grip')
    old_pixels=np.array(Image.open(source/(stem+'_albedo.png')).convert('RGBA'))[::-1]
    pixels=np.array(Image.open(folder/(stem+'_albedo.png')).convert('RGBA'))[::-1]
    assert old_pixels.shape==pixels.shape and (pixels[...,3]==255).all()
    # Skin, hair, eyes, ears and angry brows retain the approved pixel art.
    protected_names=[n for n in before_report['geometry']['body_part_uv_boxes'] if n not in report['texture'].get('mounted_bone_armor_parts',[])]
    if row['family']!='cavalry':protected_names=list(before_report['geometry']['body_part_uv_boxes'])
    for name in protected_names:
        for x0,y0,x1,y1 in before_report['geometry']['body_part_uv_boxes'][name]:
            x0,x1=np.rint(np.array([x0,x1])*pixels.shape[1]).astype(int)
            y0,y1=np.rint(np.array([y0,y1])*pixels.shape[0]).astype(int)
            assert np.array_equal(old_pixels[y0:y1,x0:x1],pixels[y0:y1,x0:x1]),(stem,'protected body pixels',name)
    if row['family']=='ranger':
        # All animated string and arrow channels are included in the exact
        # curve comparison above; the bow contact positions stay unchanged.
        assert report['tribal_equipment']['bow_and_string_contact_geometry_preserved']
    png=(folder/(stem+'_albedo.png')).read_bytes()
    assert len(new.doc['images'])==1 and image_bytes(new.doc,new.binary,new.doc['images'][0])==png
    assert all(s['magFilter']==9728 for s in new.doc['samplers'])
    return dict(stem=stem,status='PASS',clips=len(before),animation_max_error=maximum_error,
        rest_skeleton_max_error=rest_error,anatomy_vertex_max_error=geometry_error,
        skin_binding_max_error=bind_error,
        unchanged_grips=grips,approved_face_pixels_preserved=True,
        bone_armor_parts=report['texture'].get('mounted_bone_armor_parts',[]),
        initial_shield_preserved=row['key']=='squire')

def galleries():
    dest=ROOT/'docs/previews/orc_troops';dest.mkdir(exist_ok=True,parents=True)
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
    for view in ('three_quarter','front','back','game_top'):
        canvas=Image.new('RGB',(1280,5*364),(33,39,34));draw=ImageDraw.Draw(canvas)
        for index,row in enumerate(ASSETS):
            image=Image.open(OUT/row['stem']/'previews'/(view+'.png')).convert('RGB').resize((316,316),Image.Resampling.LANCZOS)
            x=row['tier']*320+2;y=index//4*364+2;canvas.paste(image,(x,y))
            draw.text((x+6,y+318),row['name'],font=font,fill=(236,228,205))
            draw.text((x+6,y+341),'Supremo • 2,20 m' if row['tier']==3 else '2 m',font=font,fill=(171,190,165))
        canvas.save(dest/('roster_'+view+'.jpg'),quality=95)
    pairs=[next(r for r in ASSETS if r['key']==k) for k in ('warrior','swordsman','archer','griffon_rider','shadow_master')]
    canvas=Image.new('RGB',(1024,len(pairs)*548),(31,37,32));draw=ImageDraw.Draw(canvas)
    for index,row in enumerate(pairs):
        for side,(folder,label) in enumerate(((FROZEN/row['stem'],'Antes'),(OUT/row['stem'],'Equipamento tribal'))):
            image=Image.open(folder/'previews/three_quarter.png').convert('RGB').resize((512,512),Image.Resampling.LANCZOS)
            canvas.paste(image,(side*512,index*548))
            draw.text((side*512+12,index*548+516),row['name']+' • '+label,font=font,fill=(231,224,202))
    canvas.save(dest/'tribal_equipment_before_after.jpg',quality=95)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');args=parser.parse_args()
    rows=[r for r in ASSETS if not args.only or r['stem'] in args.only]
    results=[verify(row) for row in rows]
    protected=json.loads((WORK/'protected_sources.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha for p,sha in protected.items())
    output=dict(status='PASS',models=len(results),clips=sum(r['clips'] for r in results),
        no_new_animations=True,protected_files=len(protected),assets=results)
    target=WORK/'tribal_equipment/pilot_validation.json' if args.only else ROOT/'docs/orc_tribal_equipment_validation.json'
    target.write_text(json.dumps(output,indent=2),encoding='utf-8')
    print(json.dumps(output if args.only else {k:v for k,v in output.items() if k!='assets'}))
    if not args.only:galleries()

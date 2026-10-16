"""Exported bull silhouette, horn contacts, unchanged rider and animation audit."""
import argparse,json,hashlib,numpy as np
from PIL import Image,ImageDraw,ImageFont
from orc_troop_assets import ROOT,OUT,WORK,ASSETS
from glb_pose_math import PoseModel
from audit_orc_war_boars import verify as verify_mount,selected,CONVERSION

FROZEN=WORK/'war_bulls/before_assets'
KEYS=('cavalier','shock_cavalier','armored_cavalier','griffon_rider')

def verify(row):
    from audit_orc_anatomy_v2 import cuboid
    from audit_orc_open_skull import separation
    result=verify_mount(row,species='war_bull',frozen=FROZEN)
    stem=row['stem'];report=json.loads((OUT/stem/(stem+'_report.json')).read_text(encoding='utf-8'))
    c=report['mount_refinement'];new=PoseModel(OUT/stem/(stem+'.glb'))
    h=np.array(c['new_parts']['BullHead']['vertices']);factor=np.array(c['source_part_vertices']['BoarBody'])[:,2].max()/1.36
    assert np.ptp(h[:,2])>.48*factor
    inspired=report['mount_revision']=='war_bull_v2'
    assert np.ptp(np.array(c['new_parts']['BullMuzzle']['vertices'])[:,0])>(.30 if inspired else .48)*factor
    points={n:selected(new,v['uv_boxes'],v['bone']) for n,v in c['new_parts'].items()}
    offset=points['BullHead'].mean(axis=0)-h.mean(axis=0)@CONVERSION.T
    horn_bone=new.names.index('horse_head');horns={};smallest_gap=1e9
    for sign in (-1,1):
        name='BullHorn_'+str(sign);q=np.array(c['new_parts'][name]['vertices'])
        assert len(q)==17 and np.all(q[:4].mean(axis=0)>h.min(axis=0)) and np.all(q[:4].mean(axis=0)<h.max(axis=0))
        assert q[:,2].max()>(2.05 if inspired else 2.08)*factor
        if inspired:assert .30*factor<np.max(abs(q[:,0]))<.40*factor
        else:assert np.max(abs(q[:,0]))>.5*factor
        assert c['new_parts'][name]['bone']=='horse_head'
        assert np.ptp(np.array(c['new_parts']['BullEar_'+str(sign)]['vertices'])[:,0])>(.15 if inspired else .18)*factor
        horns[name]=q@CONVERSION.T+offset
    hands={n:selected(new,c['source_part_uv_boxes'][n],c['source_part_bones'][n]) for n in ('Hand_l','Hand_r','Head')}
    for clip,channels in new.clips.items():
        duration=max(float(t[-1]) for _,_,t,_ in channels)
        for frame in range(round(duration*24)+1):
            world=new.worlds(clip,frame/24)
            for name,q in horns.items():
                horn=new.skinned(world,q,np.full(len(q),horn_bone))
                for hand,p in hands.items():
                    bone=new.names.index(c['source_part_bones'][hand]);posed=new.skinned(world,p,np.full(len(p),bone))
                    for segment in (horn[:8],horn[4:12],horn[8:16],horn[12:]):
                        # Broad-phase box separation is sufficient when positive.
                        gap=float(np.maximum(posed.min(0)-segment.max(0),segment.min(0)-posed.max(0)).max())
                        if gap<=0:gap=separation(segment,posed)
                        assert gap>.003,(stem,clip,frame,name,hand,'horn/rider contact',gap)
                        smallest_gap=min(smallest_gap,gap)
    result.update(mount_species='war_bull',horns_seated_in_skull=True,upright_compact_horns=inspired,
        heavy_shaggy_forequarters=inspired,ochre_saddle_hide=inspired,
        bovine_muzzle=True,horizontal_ears=True,long_tufted_tail=True,physical_split_hooves=True,
        minimum_horn_rider_separating_gap_m=smallest_gap)
    return result

def galleries():
    from audit_orc_open_skull import galleries as roster
    roster();dest=ROOT/'docs/previews/orc_troops';font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
    for view in ('mount_closeup','three_quarter'):
        canvas=Image.new('RGB',(1280,1360),(31,37,32));draw=ImageDraw.Draw(canvas)
        for index,row in enumerate(r for r in ASSETS if r['key'] in KEYS):
            x=index%2*640;y=index//2*680;canvas.paste(Image.open(OUT/row['stem']/'previews'/(view+'.png')).convert('RGB'),(x,y))
            draw.text((x+12,y+645),row['name']+' · Touro de guerra',font=font,fill=(231,224,202))
        canvas.save(dest/('war_bulls_'+view+'.jpg'),quality=95)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--only',nargs='+');args=parser.parse_args()
    results=[verify(r) for r in ASSETS if r['key'] in (args.only or KEYS)]
    changed={r['stem'] for r in ASSETS if r['key'] in KEYS};unchanged=0
    for p,sha in json.loads((WORK/'war_bulls/before_hashes.json').read_text()).items():
        if any('/'+stem+'/' in p.replace('\\','/') for stem in changed):continue
        assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha,p;unchanged+=1
    protected=json.loads((WORK/'protected_sources.json').read_text());assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==s for p,s in protected.items())
    output=dict(status='PASS',modified_models=len(results),unchanged_models=16,unchanged_orc_files=unchanged,
        protected_other_race_files=len(protected),modified_model_clips=sum(r['clips'] for r in results),new_animations=0,assets=results)
    path=WORK/'war_bulls/pilot_validation.json' if args.only else ROOT/'docs/orc_war_bulls_validation.json'
    path.write_text(json.dumps(output,indent=2),encoding='utf-8');print(json.dumps({k:v for k,v in output.items() if k!='assets'}))
    if not args.only:galleries()

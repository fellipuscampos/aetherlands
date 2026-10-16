"""Rectangular bovine body, no decorative plates, and grounded existing gaits."""
import sys,importlib,numpy as np
from pathlib import Path
from mathutils import Matrix,Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from orc_troop_assets import WORK
from build_orc_refined_clothing import pack,uvboxes,gutter
from build_orc_troops import action_curves
from build_elf_troops import reset_pose
from glb_pose_math import PoseModel
import build_orc_horns_hoods as shared
importlib.reload(shared)

FROZEN=WORK/'war_bull_finish/before_assets'
KEYS=('cavalier','shock_cavalier','armored_cavalier','griffon_rider')
REVISION='war_bull_v3'
DESCRIPTION='Blocky rectangular war bull, without mount armor plates or added saddle panels. Existing mounted animations adapted only at leg translations to keep cloven hooves above the ground; original riders, weapons, saddle, skull, horns and rein contacts preserved.'

def selected(model,boxes,bone):
    for layer in range(4):
        if 'TEXCOORD_'+str(layer) not in model.doc['meshes'][0]['primitives'][0]['attributes']:break
        p,ids,uv=model.geometry(layer);mask=np.zeros(len(p),dtype=bool)
        for x0,y0,x1,y1 in boxes:mask|=(uv[:,0]>=x0-1e-6)&(uv[:,0]<=x1+1e-6)&(uv[:,1]>=1-y1-1e-6)&(uv[:,1]<=1-y0+1e-6)
        mask&=ids==model.names.index(bone)
        if mask.any():return np.unique(np.round(p[mask],6),axis=0)
    raise AssertionError(bone)

def modify(g,canvas):
    factor=max(v.co.z for v in g.by['BullBody'].data.vertices)/1.36
    g.remove([n for n in g.by if n in ('BullBody','BullWithers','BullForelock') or n.startswith(('BullBone','BullSaddleHide'))])
    for name,center,size,bone in (
        ('BullBody',[0,-.015,.975],[.54,1.31,.77],'horse_body'),
        ('BullWithers',[0,-.60,1.055],[.44,.60,.83],'horse_neck')):
        g.box(name,np.zeros(3),np.eye(3),np.array(center)*factor,np.array(size)*factor,'leather',bone)
    pack(canvas,g.new,[o for o in g.parts if o not in g.new],False)
    h,w=canvas.shape[:2];coat=np.array(((74,32,16),(65,33,19),(49,31,20),(35,28,20))[g.row['tier']])
    for obj in g.new:
        for poly,b in zip(obj.data.polygons,uvboxes(obj)):
            x0,y0,x1,y1=np.rint(np.array(b)*[w,h,w,h]).astype(int)
            shape=(y1-y0,x1-x0);rng=np.random.default_rng(sum(map(ord,obj['part']))+poly.index*137)
            clusters=rng.integers(-6,7,((shape[0]+3)//4,(shape[1]+3)//4,1)).repeat(4,0).repeat(4,1)[:shape[0],:shape[1]]
            base=coat-np.array([22,11,5]) if obj['part']=='BullWithers' else coat
            shade=(-8,7,0,0,-3,-3)[poly.index]
            canvas[y0:y1,x0:x1,:3]=np.clip(base+shade+clusters,0,255).astype(np.uint8);gutter(canvas,x0,y0,x1,y1)
        obj.data.uv_layers.active.name=g.parts[0].data.uv_layers[0].name
    g.war_boar_new={o['part']:dict(vertices=[list(v.co) for v in o.data.vertices],bone=o['rig_bone'],uv_boxes=uvboxes(o)) for o in g.new}
    return [],[]

def prepare_motion(g,path):
    import json
    old=PoseModel(path);report=json.loads(path.with_name(path.stem+'_report.json').read_text(encoding='utf-8'))
    c=report['mount_refinement'];hooves={n:selected(old,i['uv_boxes'],i['bone']) for n,i in c['new_parts'].items() if n.startswith('BullHoof')}
    fps=g.scene.render.fps/g.scene.render.fps_base;rig=g.rig;tracks=list(rig.animation_data.nla_tracks)
    conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
    inverse_rig=rig.matrix_world.inverted().to_3x3();adjustments={}
    for track in tracks:
        clip=track.name;strip=track.strips[0];original=strip.action
        curves={(fc.data_path,fc.array_index):fc for _,fc in action_curves(original)}
        copy=original.copy();copy.name=original.name+'_BullContacts';strip.action=copy
        strip.action_slot=copy.slots[0];rig.animation_data.action=copy;rig.animation_data.action_slot=copy.slots[0]
        duration=max(float(t[-1]) for _,_,t,_ in old.clips[clip]);rows=[]
        samples=round(duration*fps)
        floors=[]
        # Include interpolation, so rotated hoof corners cannot pass through
        # the floor between the existing 24 fps keys.
        for subframe in range(samples*4+1):
            world=old.worlds(clip,subframe/(fps*4));entry={}
            for leg in ('fl','fr','bl','br'):
                j=old.names.index('horse_cannon_'+leg)
                entry[leg]=min(old.skinned(world,hooves['BullHoof_'+leg+'_'+str(t)],np.full(len(hooves['BullHoof_'+leg+'_'+str(t)]),j))[:,1].min() for t in (-1,1))
            floors.append(entry)
        for fr in range(round(duration*fps)+1):
            world=old.worlds(clip,fr/fps)
            root_native=conversion@Matrix((np.linalg.inv(world[old.parent[old.by_name['root']]])@world[old.by_name['root']]).tolist())
            row={}
            for leg in ('fl','fr','bl','br'):
                bone='horse_cannon_'+leg;j=old.names.index(bone)
                floor=min(floors[k][leg] for k in range(max(0,fr*4-3),min(len(floors),fr*4+4)))
                lift=float(-floor+.0015) if floor<-.002 else 0.;row[leg]=lift
                shift=inverse_rig@Vector((0,0,lift))
                for prefix in ('horse_thigh_','horse_cannon_'):
                    name=prefix+leg;b=rig.data.bones[name]
                    local_rest=b.parent.matrix_local.inverted()@b.matrix_local
                    delta=local_rest.inverted().to_3x3()@root_native.inverted().to_3x3()@shift
                    frame=strip.action_frame_start+fr
                    data_path='pose.bones["'+name+'"].location'
                    values=[curves[data_path,axis].evaluate(frame) if (data_path,axis) in curves else 0. for axis in range(3)]
                    rig.pose.bones[name].location=Vector(values)+delta
                    rig.pose.bones[name].keyframe_insert('location',frame=frame,group=name)
            rows.append(row)
        rig.animation_data.action=None
        adjustments[clip]=dict(fps=fps,world_vertical_lifts_m=rows,max_lift_m=max(max(r.values()) for r in rows))
        for _,fc in action_curves(copy):
            if fc.data_path.startswith('pose.bones["horse_') and fc.data_path.endswith('.location'):
                for point in fc.keyframe_points:point.interpolation='LINEAR'
    import hashlib
    reset_pose(rig,g.scene);g.motion_adjustments=adjustments
    g.scene['mount_motion_signature']=hashlib.sha256(json.dumps(adjustments,sort_keys=True).encode()).hexdigest()

def update_report(report,changes):
    import hashlib,json
    changes['motion_signature']=hashlib.sha256(json.dumps(changes['motion_adjustments'],sort_keys=True).encode()).hexdigest()
    report['mount_revision']=REVISION;report['mount_species']='war_bull';report['mount_refinement']=changes
    changes.update(rectangular_body=True,mount_plates_removed=True,rider_and_weapon_curves_preserved=True,
        mount_leg_translations_adjusted=True,new_animation_clips=0)
    changes['anatomy_and_animation_curves_preserved']=False
    changes['rider_anatomy_and_animation_curves_preserved']=True
    report['texture']['equipment_materials']={n:v for n,v in report['texture'].get('equipment_materials',{}).items() if n not in changes['removed_parts']}

def build(row):return shared.build(row,refinement=sys.modules[__name__])

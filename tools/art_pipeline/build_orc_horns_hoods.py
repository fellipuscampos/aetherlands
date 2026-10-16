"""Open-Blender-only finishing pass: forward horns, painted hoods, no arm shields."""
import bpy,bmesh,json,sys,hashlib,importlib,numpy as np
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from orc_troop_assets import ROOT,OUT,WORK
from build_elf_troops import BODY,reset_pose,pixels
from build_orc_troops import load_scene,save_atlas
from build_orc_squire import rectangle,cuboid_axes
from build_orc_tribal_equipment import Gear,frame,actual_pose
from build_orc_refined_clothing import uvboxes,gutter
import export_orc_clothing_glb
importlib.reload(export_orc_clothing_glb)
from glb_pose_math import PoseModel

FROZEN=WORK/'horns_and_hoods/before_assets'
KEYS=('sentinel','guardian_champion','armored_cavalier','griffon_rider','archer','hunter','elite_marksman','legend_hunter')

def hood(poly,frac,original,tier):
    x,y,z=(frac[...,i] for i in range(3));vertical=poly.index>=2
    u=x if poly.index in (0,1,2,3) else y;v=z if vertical else y
    base=np.array(((76,83,48),(65,73,42),(55,64,37),(45,55,31))[tier])
    # Quiet linen weave, sewn center seam and shaded fold at the face opening.
    xx=np.floor(u*34).astype(int);yy=np.floor(v*34).astype(int)
    tile=np.broadcast_to(base,original.shape).astype(np.int16).copy()
    tile+=((xx*3+yy*5)%7-3)[...,None]
    tile[(xx+yy)%11==0]-=[4,4,3]
    if poly.index==2:
        distance=abs(x-.5)
        # A slightly pointed brow opening and squared, tucked lower hem.
        top=.82-.19*distance;bottom=.085+.11*distance
        border=.355-.085*np.maximum(.36-z,0)
        window=(distance<border)&(z>bottom)&(z<top)
        rim=(distance<border+.035)&(z>bottom-.03)&(z<top+.035)&~window
        tile[rim]=base+[16,17,10]
        crease=(distance<border+.055)&(z>bottom-.05)&(z<top+.055)&~(window|rim)
        tile[crease]=base-[17,18,10]
        tile[window]=original[window]
        stitch=crease&((xx+yy)%4==0);tile[stitch]=base+[25,25,14]
        # Original brows and symmetrical amber eyes remain completely visible.
    else:
        fold=abs(u-.5)<.03;tile[fold]=base-[15,16,9]
        tile[(abs(u-.5)>.035)&(abs(u-.5)<.065)]=base+[13,14,8]
        tile[(abs(u-.5)<.03)&(yy%5==1)]=base+[24,24,13]
        tile[(v<.08)|(v>.93)]=base-[10,11,7]
    return np.clip(tile,0,255).astype(np.uint8)

def horns(g,canvas):
    obj=g.by['Head'];origin,axes,size=frame(obj);tier=g.row['tier']
    factor=1.12 if tier==3 else 1.
    changed=[];h,w=canvas.shape[:2]
    for sign in (-1,1):
        name='BoneArmor_SkullTempleHorn_'+str(sign);horn=g.by[name];verts=[]
        # Large tapering crescents root on the front temples and rise forward.
        # The anatomy stays 2/2.2 m; projecting armor can rise above the crown.
        centers=(([sign*size[0]*.44,-size[1]*.47,size[2]*.18],.058*factor),
                 ([sign*(size[0]*.50+.085*factor),-size[1]*.47-.070*factor,size[2]*.43],.050*factor),
                 ([sign*(size[0]*.50+.11*factor),-size[1]*.47-.155*factor,size[2]*(.76 if tier==3 else .70)],.027*factor))
        for center,radius in centers:
            verts.extend((np.array(center)+[0,np.cos(a)*radius,np.sin(a)*radius]).tolist()
                         for a in (0,np.pi/2,np.pi,np.pi*1.5))
        verts.append([sign*(size[0]*.49+.06*factor),-size[1]*.47-.245*factor,size[2]*(1.03 if tier==3 else .95)])
        assert len(horn.data.vertices)==len(verts)==13
        for vertex,point in zip(horn.data.vertices,np.array(verts)@axes.T+origin):vertex.co=point
        horn.data.update()
        for poly,box in zip(horn.data.polygons,uvboxes(horn)):
            x0,y0,x1,y1=np.rint(np.array(box)*[w,h,w,h]).astype(int)
            yy,xx=np.mgrid[:y1-y0,:x1-x0];t=(yy+.5)/(y1-y0)
            segment=0 if poly.index<5 else 1 if poly.index<9 else 2
            base=np.array(((171,150,107),(208,188,142),(233,217,175))[segment])
            shade=np.rint(np.cos((xx+.5)/(x1-x0)*np.pi)*8+((yy*3+xx)%7)-3)
            tile=np.broadcast_to(base,(y1-y0,x1-x0,3)).astype(np.int16).copy()+shade[...,None].astype(int)
            tile[(yy%7==0)&(segment<2)]-=np.array([14,12,8])
            canvas[y0:y1,x0:x1,:3]=np.clip(tile,0,255).astype(np.uint8);gutter(canvas,x0,y0,x1,y1)
        changed.append(name)
    return changed

def build(row,refinement=None):
    stem=row['stem'];source=(refinement.FROZEN if refinement else FROZEN)/stem;out=OUT/stem
    report=json.loads((source/(stem+'_report.json')).read_text(encoding='utf-8'))
    if bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
    scene=load_scene(source/(stem+'.blend'));bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE');root=rig.parent
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    for obj in parts:obj.data=obj.data.copy()
    reset_pose(rig,scene)
    original_geometry={o['part']:np.array([tuple(v.co) for v in o.data.vertices]) for o in parts}
    original_uv={o['part']:uvboxes(o) for o in parts};original_bones={o['part']:o['rig_bone'] for o in parts}
    material=parts[0].data.materials[0].copy()
    image=bpy.data.images.load(str(source/(stem+'_albedo.png')),check_existing=False);image.colorspace_settings.name='Non-Color'
    canvas=pixels(image).copy();h,w=canvas.shape[:2];g=Gear(scene,rig,parts,row);painted=[];reshaped=[]
    if refinement:
        painted,reshaped=refinement.modify(g,canvas)
        if hasattr(refinement,'prepare_motion'):refinement.prepare_motion(g,source/(stem+'.glb'))
    elif row['family']=='ranger':
        obj=g.by['Head']
        for poly in obj.data.polygons:
            lo,hi,frac=rectangle(obj,poly,w,h);x0,y0=lo;x1,y1=hi
            old=canvas[y0:y1,x0:x1,:3].copy();canvas[y0:y1,x0:x1,:3]=hood(poly,frac,old,row['tier']);gutter(canvas,x0,y0,x1,y1)
        painted.append('Head')
    else:
        if row['family']=='cavalry':g.remove([n for n in g.by if n=='Shield' or n.startswith('RiderShield')])
        reshaped=horns(g,canvas);painted.extend(reshaped)
    atlas=save_atlas(canvas,out/(stem+'_albedo.png'),stem+'_HornsHoods_Albedo')
    for node in material.node_tree.nodes:
        if node.type=='TEX_IMAGE':node.image=atlas;node.interpolation='Closest'
    for obj in parts:
        obj.data.materials.clear();obj.data.materials.append(material)
        if obj['part'] not in reshaped and obj not in g.new:continue
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
        assert all(e.is_manifold for e in bm.edges);bm.to_mesh(obj.data);bm.free()
    for name in BODY:assert np.array_equal(original_geometry[name],np.array([tuple(v.co) for v in g.by[name].data.vertices]))
    bpy.context.view_layer.update()
    coords=np.array([tuple(o.matrix_world@v.co) for o in parts for v in o.data.vertices]);lo=coords.min(axis=0);hi=coords.max(axis=0)
    point=Vector(((lo+hi)/2).tolist());camera=scene.camera;camera.data.type='ORTHO'
    scale=max(2.85,float((hi-lo)[2])*1.18,float((hi-lo)[0])+.50)
    scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    idle=next(n for n in report['clips'] if n.endswith('_Idle'));actual_pose(scene,rig,source/(stem+'.glb'),idle,0.)
    views=('front','three_quarter','back','game_top','armor_closeup')+ (('mount_closeup',) if hasattr(g,'war_boar_new') else ())
    for view in views:
        if view=='mount_closeup':
            target=root.matrix_world@Vector((0,-.36,.88));camera.data.ortho_scale=2.65;delta=(5,-10,3.4)
        elif view=='armor_closeup':
            bpy.context.view_layer.update();deformed=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
            target=rig.matrix_world@deformed.pose.bones['head'].matrix.translation-Vector((0,0,.26))
            camera.data.ortho_scale=1.75;delta=(3,-10,2.1)
        else:
            target=point;camera.data.ortho_scale=scale
            delta={'front':(0,-12,1.2),'three_quarter':(6,-12,5.6),'back':(-6,12,5),'game_top':(5,-7,11)}[view]
        camera.location=target+Vector(delta);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/'previews'/(view+'.png'));bpy.ops.render.render(write_still=True)
    reset_pose(rig,scene)
    retained={n:b for n,b in original_uv.items() if n not in g.removed and n not in reshaped}
    gltf=export_orc_clothing_glb.export(row,scene,parts,rig,root,out,retained,approved_path=source/(stem+'.glb'))
    reset_pose(rig,scene)
    for track in rig.animation_data.nla_tracks:track.mute=False;track.is_solo=False
    scene.frame_set(1)
    scene['description']='Painted olive cloth hood on the original head cube; approved bare orc face retained.' if row['family']=='ranger' else 'Closed bone armor with large forward-rising skull horns. Mounted arm shield removed.'
    if refinement:
        scene['description']=refinement.DESCRIPTION
        scene['asset_revision']=getattr(refinement,'REVISION','jawless_skull_v1');scene['asset_stem']=stem
    bpy.data.libraries.write(str(out/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    for obj in parts:obj.data.calc_loop_triangles()
    change_record=dict(source=str(source.relative_to(ROOT)),painted_parts=painted,reshaped_parts=reshaped,
        removed_parts=g.removed,source_part_uv_boxes=original_uv,source_part_vertices={n:p.tolist() for n,p in original_geometry.items()},
        source_part_bones=original_bones,hood_painted_on_head=row['family']=='ranger',forward_horns=bool(reshaped),
        head_blocks=1,anatomy_and_animation_curves_preserved=True)
    if hasattr(g,'war_boar_new'):
        change_record['new_parts']=g.war_boar_new
        change_record['reshaped_target_vertices']={n:[list(v.co) for v in g.by[n].data.vertices] for n in reshaped}
        change_record['forward_horns']=False
    if hasattr(g,'motion_adjustments'):change_record['motion_adjustments']=g.motion_adjustments
    if refinement:refinement.update_report(report,change_record)
    else:
        report['finishing_revision']='forward_horns_and_painted_hoods_v1'
        report['finishing_refinement']=change_record
    exported=PoseModel(out/(stem+'.glb'));p,ids,_=exported.geometry()
    native=exported.skinned(exported.rest,p,ids)@np.array([[1,0,0],[0,0,1],[0,-1,0]])
    lo=native.min(axis=0);hi=native.max(axis=0)
    report['geometry'].update(editable_parts=len(parts),triangles=sum(len(o.data.loop_triangles) for o in parts),
        bounds_min=lo.tolist(),bounds_max=hi.tolist(),dimensions=(hi-lo).tolist())
    report['texture']['albedo_sha256']=hashlib.sha256((out/(stem+'_albedo.png')).read_bytes()).hexdigest()
    if 'finishing_revision' in report:report['texture']['finishing_revision']=report['finishing_revision']
    if row['family']=='ranger':
        report['texture']['head_style']='painted_cloth_hood_with_approved_face'
        if 'head_audit' in report['texture']:report['texture']['head_audit']['mode']='painted_cloth_hood'
    report['texture']['equipment_materials']={k:v for k,v in report['texture'].get('equipment_materials',{}).items() if k in g.by}
    (out/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    return dict(status='PASS',stem=stem,removed=g.removed,reshaped=reshaped,painted_hood=row['family']=='ranger',clips=len(gltf['animations']))

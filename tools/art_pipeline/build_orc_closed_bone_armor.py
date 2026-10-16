"""Revise only the four skeletal outfits and the guardian shield ornaments."""
import bpy,bmesh,json,sys,hashlib,importlib,numpy as np
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from orc_troop_assets import ROOT,OUT,WORK
from build_elf_troops import BODY,reset_pose,pixels
from build_orc_troops import load_scene,save_atlas
from build_orc_squire import rectangle,cuboid_axes
from build_orc_tribal_equipment import Gear,frame,actual_pose
from build_orc_refined_clothing import uvboxes,gutter,pack,repaint
import export_orc_clothing_glb
importlib.reload(export_orc_clothing_glb)
import orc_closed_bone_armor_paint as paint
importlib.reload(paint)
from glb_pose_math import PoseModel

FROZEN=WORK/'bone_armor_refinement/before_assets'
KEYS=('guardian','sentinel','guardian_champion','armored_cavalier','griffon_rider')

def sculpt(g):
    # Keep the approved leather harness, panels, metal buckles and horn mounts.
    # Replace only the narrow skeletal bracer/apron ornaments with wide armor.
    g.remove(['Cloth_BracerPlate_'+s for s in ('l','r')]+['Cloth_PauldronApron_'+s for s in ('l','r')])
    for side in ('l','r'):
        for body,label,width,height,depth in (('Forearm_','Vambrace',.90,.91,.028),('Shoulder_','Pauldron',1.06,.98,.036)):
            obj=g.by[body+side];origin,axes,size=frame(obj);bone=obj['rig_bone']
            ww=size[0]*width;hh=size[2]*height
            profile=[(-ww*.38,hh/2),(ww*.38,hh/2),(ww/2,hh*.33),
                     (ww/2,-hh*.25),(ww*.30,-hh*.47),(0,-hh*.54),
                     (-ww*.30,-hh*.47),(-ww/2,-hh*.25),(-ww/2,hh*.33)]
            g.plate('BoneArmor_'+label+'_'+side,origin,axes,profile,depth,-size[1]/2-.021,'bone',bone)
    # A shallow, tapered snout keel gives the painted animal skull actual relief.
    # It does not duplicate or enlarge the head cube or extend above its crown.
    obj=g.by['Head'];origin,axes,size=frame(obj)
    ww=size[0]*.19;hh=size[2]*.56
    profile=[(-ww*.20,hh*.49),(ww*.20,hh*.49),(ww*.38,hh*.08),
             (ww/2,-hh*.32),(ww*.33,-hh*.48),(-ww*.33,-hh*.48),(-ww/2,-hh*.32),(-ww*.38,hh*.08)]
    g.plate('BoneArmor_SkullNasalKeel',origin,axes,profile,.035,-size[1]/2-.018,'bone',obj['rig_bone'])
    # Low, swept animal horns wrap the temples. Their tops remain below the
    # existing head crown, preserving the character's approved total height.
    for sign in (-1,1):
        verts=[]
        for center,radius in (([sign*size[0]*.44,0,size[2]*.27],.042),
                              ([sign*(size[0]*.50+.105),-.025,size[2]*.35],.035),
                              ([sign*(size[0]*.50+.14),-.075,size[2]*.17],.024)):
            verts.extend((np.array(center)+[0,np.cos(a)*radius,np.sin(a)*radius]).tolist()
                         for a in (0,np.pi/2,np.pi,np.pi*1.5))
        verts.append([sign*(size[0]*.50+.09),-.105,-size[2]*.10])
        faces=[(3,2,1,0)]+[(i+r,(i+1)%4+r,(i+1)%4+r+4,i+r+4) for r in (0,4) for i in range(4)]
        faces.extend((i+8,(i+1)%4+8,12) for i in range(4))
        g.mesh('BoneArmor_SkullTempleHorn_'+str(sign),(np.array(verts)@axes.T+origin).tolist(),faces,'horn',obj['rig_bone'])

def build(row):
    stem=row['stem'];source=FROZEN/stem;out=OUT/stem
    report=json.loads((source/(stem+'_report.json')).read_text(encoding='utf-8'))
    full=row['key']!='guardian'
    if bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
    scene=load_scene(source/(stem+'.blend'));bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE');root=rig.parent
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    for obj in parts:obj.data=obj.data.copy()
    reset_pose(rig,scene)
    original_geometry={o['part']:np.array([tuple(v.co) for v in o.data.vertices]) for o in parts}
    original_uv={o['part']:uvboxes(o) for o in parts}
    original_bones={o['part']:o['rig_bone'] for o in parts}
    material=parts[0].data.materials[0].copy()
    image=bpy.data.images.load(str(source/(stem+'_albedo.png')),check_existing=False);image.colorspace_settings.name='Non-Color'
    canvas=pixels(image).copy();h,w=canvas.shape[:2]
    g=Gear(scene,rig,parts,row);changed=[]
    if row['family']=='guardian':
        g.remove([name for name in g.by if name.startswith('ShieldBoneClamp_')])
        repaint(canvas,g.by['ShieldBoss'],'iron',row['tier']);changed.append('ShieldBoss')
    if full:
        sculpt(g)
        for obj in parts:
            if obj in g.new:continue
            name=obj['part']
            if name in BODY:
                for poly in obj.data.polygons:
                    lo,hi,frac=rectangle(obj,poly,w,h);x0,y0=lo;x1,y1=hi
                    vertices,axes=cuboid_axes(obj);position=frac@axes.T+vertices[0]
                    old=canvas[y0:y1,x0:x1,:3].copy()
                    canvas[y0:y1,x0:x1,:3]=paint.plates(obj,poly,frac,position,row,old)
                    gutter(canvas,x0,y0,x1,y1)
                changed.append(name)
            elif name.startswith(('Brow','Cloth_PauldronCap_')):
                for poly,box in zip(obj.data.polygons,uvboxes(obj)):
                    x0,y0,x1,y1=np.rint(np.array(box)*[w,h,w,h]).astype(int)
                    canvas[y0:y1,x0:x1,:3]=paint.detail((y1-y0,x1-x0),poly.index)
                    gutter(canvas,x0,y0,x1,y1)
                changed.append(name)
        pack(canvas,g.new,[o for o in parts if o not in g.new],False)
        for obj in g.new:
            for poly,box in zip(obj.data.polygons,uvboxes(obj)):
                x0,y0,x1,y1=np.rint(np.array(box)*[w,h,w,h]).astype(int)
                canvas[y0:y1,x0:x1,:3]=paint.detail((y1-y0,x1-x0),poly.index*31)
                gutter(canvas,x0,y0,x1,y1)
        for obj in g.new:obj.data.uv_layers.active.name=parts[0].data.uv_layers[0].name
    atlas=save_atlas(canvas,out/(stem+'_albedo.png'),stem+'_ClosedBone_Albedo')
    for node in material.node_tree.nodes:
        if node.type=='TEX_IMAGE':node.image=atlas;node.interpolation='Closest'
    for obj in parts:
        obj.data.materials.clear();obj.data.materials.append(material)
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
        assert all(e.is_manifold for e in bm.edges),obj.name
        bm.to_mesh(obj.data);bm.free()
    for name in BODY:assert np.array_equal(original_geometry[name],np.array([tuple(v.co) for v in g.by[name].data.vertices]))
    bpy.context.view_layer.update()
    coords=np.array([tuple(o.matrix_world@v.co) for o in parts for v in o.data.vertices]);lo=coords.min(axis=0);hi=coords.max(axis=0)
    point=Vector(((lo+hi)/2).tolist());camera=scene.camera;camera.data.type='ORTHO'
    scale=max(2.85,float((hi-lo)[2])*1.18,float((hi-lo)[0])+.50)
    scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    idle=next(n for n in report['clips'] if n.endswith('_Idle'));actual_pose(scene,rig,source/(stem+'.glb'),idle,0.)
    for view in ('front','three_quarter','back','game_top','armor_closeup'):
        if view=='armor_closeup':
            bpy.context.view_layer.update()
            deformed=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
            head=rig.matrix_world@deformed.pose.bones['head'].matrix.translation
            target=head-Vector((0,0,.35));camera.data.ortho_scale=1.65
            delta=(3,-10,1.8)
        else:
            target=point;camera.data.ortho_scale=scale
            delta={'front':(0,-12,1.2),'three_quarter':(6,-12,5.6),'back':(-6,12,5),'game_top':(5,-7,11)}[view]
        camera.location=target+Vector(delta);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/'previews'/(view+'.png'));bpy.ops.render.render(write_still=True)
    reset_pose(rig,scene)
    retained_uv={name:boxes for name,boxes in original_uv.items() if name not in g.removed}
    gltf=export_orc_clothing_glb.export(row,scene,parts,rig,root,out,retained_uv,approved_path=source/(stem+'.glb'))
    reset_pose(rig,scene)
    for track in rig.animation_data.nla_tracks:track.mute=False;track.is_solo=False
    scene.frame_set(1)
    scene['description']='Closed cortical bone carapace and painted boar-skull helmet. Approved anatomy, leather, weapons and animations preserved.' if full else 'Guardian shield: wooden face and central iron boss only.'
    bpy.data.libraries.write(str(out/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    for obj in parts:obj.data.calc_loop_triangles()
    report['bone_armor_revision']='closed_carapace_v1'
    report['bone_armor_refinement']=dict(source=str(source.relative_to(ROOT)),full_armor=full,
        painted_parts=changed,removed_parts=g.removed,added_parts=[o['part'] for o in g.new],
        source_part_uv_boxes=original_uv,source_part_vertices={n:p.tolist() for n,p in original_geometry.items()},
        source_part_bones=original_bones,new_part_uv_boxes={o['part']:uvboxes(o) for o in g.new},
        head_style='closed_boar_skull_painted_on_single_head' if full else 'approved_bare_orc_face',
        preserved=['anatomy','height','rig','all_animation_curves','weapons','grips','leather_harness_and_panels'])
    exported=PoseModel(out/(stem+'.glb'));p,ids,_=exported.geometry()
    native=exported.skinned(exported.rest,p,ids)@np.array([[1,0,0],[0,0,1],[0,-1,0]])
    lo=native.min(axis=0);hi=native.max(axis=0)
    report['geometry'].update(editable_parts=len(parts),triangles=sum(len(o.data.loop_triangles) for o in parts),
        bounds_min=lo.tolist(),bounds_max=hi.tolist(),dimensions=(hi-lo).tolist())
    report['texture'].update(albedo_sha256=hashlib.sha256((out/(stem+'_albedo.png')).read_bytes()).hexdigest(),
        bone_armor_revision='closed_carapace_v1')
    if full:report['texture']['head_style']='closed_painted_boar_skull'
    report['texture']['equipment_materials']={k:v for k,v in report['texture'].get('equipment_materials',{}).items() if k in g.by}
    report['texture']['equipment_materials'].update({o['part']:o['tribal_material'] for o in g.new})
    (out/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    return dict(status='PASS',stem=stem,full_armor=full,removed=g.removed,added=len(g.new),clips=len(gltf['animations']))

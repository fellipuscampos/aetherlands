"""Clothing-only revision in open Blender, plus authorized axial blade rotations."""
import bpy,bmesh,json,hashlib,sys,math,numpy as np
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from orc_troop_assets import ROOT,OUT,WORK
from build_elf_troops import BODY,FACES,reset_pose,pixels,export_glb
from build_orc_squire import rectangle,cuboid_axes
from build_orc_troops import load_scene,save_atlas
from build_orc_tribal_equipment import Gear,frame,actual_pose
from export_orc_clothing_glb import export as clothing_export
from glb_pose_math import PoseModel
import orc_refined_clothing_paint as paint

FROZEN=WORK/'clothing_refinement/before_assets'

def uvboxes(obj):
    uv=obj.data.uv_layers.active
    return [np.r_[np.min([tuple(uv.data[i].uv) for i in p.loop_indices],axis=0),
                  np.max([tuple(uv.data[i].uv) for i in p.loop_indices],axis=0)].tolist() for p in obj.data.polygons]

def buckle(g,name,origin,axes,center,width,height,bone):
    for index,(offset,size) in enumerate((([-width/2,0,0],[.009,.017,height]),
        ([width/2,0,0],[.009,.017,height]),([0,0,-height/2],[width,.017,.009]),
        ([0,0,height/2],[width,.017,.009]),([0,-.003,0],[width*.85,.015,.006]))):
        g.box(name+str(index),origin,axes,np.array(center)+offset,size,'hardware',bone)

def spike(g,name,origin,axes,base,length,radius,bone):
    # Four-sided, tapered, slightly hooked horn. Flat facets match the game.
    vertices=[]
    for z,r,x in ((0,radius,0),(length*.62,radius*.52,length*.15)):
        vertices.extend((np.array(base)+[math.cos(a)*r,math.sin(a)*r,z]+[x,0,0]).tolist()
                        for a in (0,math.pi/2,math.pi,math.pi*1.5))
    vertices.append((np.array(base)+[length*.23,0,length]).tolist())
    faces=[(3,2,1,0)]+[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)]
    faces.extend((i+4,(i+1)%4+4,8) for i in range(4))
    g.mesh(name,(np.array(vertices)@axes.T+origin).tolist(),faces,'horn',bone)

def apparel(g):
    tier=g.row['tier'];family=g.row['family'];full=paint.heavy(g.row)
    g.remove(['Buckle','BeltSeal','ShoulderPlate','ShoulderLame_l','ShoulderLame_r','Gorget',
              'ShoulderBoneTusk_l','ShoulderBoneTusk_r'])
    pelvis=g.by['Pelvis'];origin,axes,size=frame(pelvis);bone=pelvis['rig_bone']
    belt_z=size[2]*.28;belt_height=.052*(size[0]/.545)
    for side in (-1,1):
        g.box('Cloth_BeltFace_'+str(side),origin,axes,[0,side*(size[1]/2+.007),belt_z],
              [size[0]+.026,.024,belt_height],'strap',bone)
        g.box('Cloth_BeltSide_'+str(side),origin,axes,[side*(size[0]/2+.007),0,belt_z],
              [.024,size[1]+.02,belt_height],'strap',bone)
    buckle(g,'Cloth_BeltBuckle_',origin,axes,[0,-size[1]/2-.026,belt_z],.098,.068,bone)
    # Deliberate layered hide loincloth, with straight sewn panels and stepped ends.
    for index in (-1,0,1):
        width=size[0]*(.28 if index==0 else .25);cx=index*size[0]*.275
        length=.20 if family!='cavalry' else .115
        length*=size[0]/.545
        top=-.018;bottom=-size[2]/2-length
        outline=[(cx-width/2,top),(cx+width/2,top),(cx+width/2,bottom+.035),
                 (cx+width*.26,bottom+.035),(cx+width*.26,bottom),
                 (cx-width*.34,bottom),(cx-width*.34,bottom+.023),(cx-width/2,bottom+.023)]
        g.plate('Cloth_HidePanel_'+str(index),origin,axes,outline,.015,
                -size[1]/2-.019-(.012 if index==0 else 0),'leather',bone)
    if tier>=1:
        width=size[0]*.19;bottom=-size[2]/2-(.23 if family!='cavalry' else .15)*size[0]/.545
        g.plate('Cloth_FabricUnderlay',origin,axes,[(-width/2,-.025),(width/2,-.025),(width/2,bottom),(-width/2,bottom)],
                .009,-size[1]/2-.010,'darkcloth' if family=='rogue' else 'olive' if family=='ranger' else 'cloth',bone)
    # A surface-following baldric; chest and belly get their own rigid sections.
    chest=g.by['Chest'];chest_origin,chest_axes,chest_size=frame(chest)
    belly=g.by['Belly'];belly_origin,belly_axes,belly_size=frame(belly)
    top=chest_origin[2]+chest_size[2]/2;bottom=belly_origin[2]-belly_size[2]/2
    for obj in (chest,belly):
        origin,axes,size=frame(obj)
        z0=origin[2]-size[2]/2;z1=origin[2]+size[2]/2
        # Exact same x(z) on both pieces, avoiding stair-step painted seams.
        def line(z):return chest_size[0]*(-.26+.65*(z-bottom)/(top-bottom))
        a=line(z0)-origin[0];b=line(z1)-origin[0];width=.060*(chest_size[0]/.706)
        for side in (-1,1):
            profile=[(a-width/2,-size[2]/2),(a+width/2,-size[2]/2),
                     (b+width/2,size[2]/2),(b-width/2,size[2]/2)]
            g.plate('Cloth_Baldric_'+obj['part']+'_'+str(side),origin,axes,profile,.012,
                    side*(size[1]/2+.008),'strap',obj['rig_bone'])
    # Close the baldric over the shoulder and across the chest/belly depth
    # step. These connectors reuse its leather UVs, without extra atlas tiles.
    g.shared_uv={}
    strap_width=.060*(chest_size[0]/.706)
    obj=g.box('Cloth_BaldricTop',chest_origin,chest_axes,[chest_size[0]*.39,0,chest_size[2]/2+.003],
              [strap_width,chest_size[1]+.030,.012],'strap',chest['rig_bone'])
    g.shared_uv[obj.name]='Cloth_Baldric_Chest_-1'
    z_step=(chest_origin[2]-chest_size[2]/2+belly_origin[2]+belly_size[2]/2)/2
    x_step=chest_size[0]*(-.26+.65*(z_step-bottom)/(top-bottom))
    for side in (-1,1):
        a=chest_origin[1]+side*chest_size[1]/2;b=belly_origin[1]+side*belly_size[1]/2
        center=(np.array([x_step,(a+b)/2+side*.008,z_step])-chest_origin)@chest_axes
        obj=g.box('Cloth_BaldricStep_'+str(side),chest_origin,chest_axes,center,
                  [strap_width,abs(a-b)+.014,.014],'strap',chest['rig_bone'])
        g.shared_uv[obj.name]='Cloth_Baldric_Chest_'+str(side)
    # One or two leather pauldrons. Horns remain outside the head/ear envelope.
    shoulders=('l','r') if tier>=2 and family in ('guardian','warrior','cavalry') else ('l',)
    for side in shoulders:
        obj=g.by['Shoulder_'+side];origin,axes,size=frame(obj);bone=obj['rig_bone'];sign=1 if side=='l' else -1
        z=size[2]/2+.012
        g.box('Cloth_PauldronCap_'+side,origin,axes,[0,0,z],[size[0]*1.07,size[1]*1.06,.042],
              'bone' if full else 'iron' if tier>=2 else 'leather',bone)
        width=size[0]*1.06;profile=[(-width/2,z-.025),(width/2,z-.025),(width/2,-size[2]*.23),
                                    (width*.25,-size[2]*.46),(-width*.30,-size[2]*.46),(-width/2,-size[2]*.23)]
        g.plate('Cloth_PauldronApron_'+side,origin,axes,profile,.030,-size[1]/2-.012,
                'bone' if full else 'leather',bone)
        for i in (-1,1):
            g.box('Cloth_PauldronBinding_'+side+str(i),origin,axes,[i*size[0]*.31,0,z+.023],
                  [.026,size[1]*1.09,.020],'strap',bone)
        for i in (-1,1):
            spike(g,'Cloth_ShoulderHorn_'+side+str(i),origin,axes,
                  [sign*size[0]*.36,i*size[1]*.23,z+.029],.08+tier*.017,.027+tier*.003,bone)
    for side in ('l','r'):
        obj=g.by['Forearm_'+side];origin,axes,size=frame(obj);bone=obj['rig_bone']
        width=size[0]*.65;height=size[2]*.63
        profile=[(-width*.38,-height/2),(width*.38,-height/2),(width/2,-height*.28),
                 (width/2,height*.32),(width*.32,height/2),(-width*.32,height/2),
                 (-width/2,height*.32),(-width/2,-height*.28)]
        if full:
            # A narrow shaft between broad joint ends reads as an actual bone,
            # with green forearm visible beside it instead of a white plaque.
            profile=[(-width*.45,-height/2),(width*.45,-height/2),(width*.50,-height*.35),
                     (width*.17,-height*.23),(width*.17,height*.23),(width*.50,height*.35),
                     (width*.45,height/2),(-width*.45,height/2),(-width*.50,height*.35),
                     (-width*.17,height*.23),(-width*.17,-height*.23),(-width*.50,-height*.35)]
        g.plate('Cloth_BracerPlate_'+side,origin,axes,profile,.022,-size[1]/2-.014,
                'bone' if full else 'iron' if tier>=1 else 'leather',bone)
        # A single short outward spike stays well clear of the held weapon.
        if tier>=1:
            horn_axes=axes@np.array([[1,0,0],[0,0,-1],[0,1,0]])
            spike(g,'Cloth_BracerSpike_'+side,origin,horn_axes,[size[0]*.26,0,size[1]/2+.023],
                  .047+tier*.010,.018,bone)
        for index,z in enumerate((-.28,.28)):
            g.box('Cloth_BracerRivet_'+side+str(index),origin,axes,[0,-size[1]/2-.031,z*size[2]],
                  [.023,.018,.023],'hardware',bone)

def rotate_blades(g):
    groups=[]
    if 'AxeHaft' in g.by:
        groups.append(('AxeHaft',[n for n in g.by if n.startswith(('AxeBoneSocket','TribalAxeBlade','AxeHonedEdge','AxeSocketTie'))]))
    if 'SwordGrip' in g.by:
        groups.append(('SwordGrip',[n for n in g.by if n.startswith(('TribalCleaver','CleaverHoned','BoneCrossguard',
                     'GuardLeatherTie','BonePommel','CleaverBoneSpine','SpineBinding'))]))
    for side in ('l','r'):
        if 'DaggerGrip_'+side in g.by:
            groups.append(('DaggerGrip_'+side,[n for n in g.by if n.endswith('_'+side) and n.startswith(
                ('TribalKnifeBlade','KnifeBoneGuard','KnifeHeelTie','KnifeBonePommel'))]))
    if 'LanceHaft' in g.by:
        groups.append(('LanceHaft',[n for n in g.by if n.startswith(('TuskLanceHead','LanceHeadSocket','LanceHeadBinding','LanceBarb'))]))
    result={}
    for grip,names in groups:
        origin,axes,size=frame(g.by[grip]);z=axes[:,2]
        forward=np.array([0.,-1.,0.]);forward-=z*np.dot(z,forward);forward/=np.linalg.norm(forward)
        edge=-axes[:,1] if grip=='AxeHaft' else axes[:,0]
        angle=math.atan2(np.dot(z,np.cross(edge,forward)),np.dot(edge,forward))
        cross=np.array([[0,-z[2],z[1]],[z[2],0,-z[0]],[-z[1],z[0],0]])
        rotation=np.eye(3)+math.sin(angle)*cross+(1-math.cos(angle))*(cross@cross)
        for name in names:
            obj=g.by[name];v=np.array([tuple(v.co) for v in obj.data.vertices]);v=(v-origin)@rotation.T+origin
            for vertex,co in zip(obj.data.vertices,v):vertex.co=co
            obj.data.update()
        result[grip]=dict(parts=names,pivot=origin.tolist(),axis=z.tolist(),rotation=rotation.tolist(),angle_degrees=math.degrees(angle),forward_edge=forward.tolist())
    return result

def repaint(canvas,obj,kind,tier):
    h,w=canvas.shape[:2]
    for poly,box in zip(obj.data.polygons,uvboxes(obj)):
        x0,y0,x1,y1=np.rint(np.array(box)*[w,h,w,h]).astype(int)
        canvas[y0:y1,x0:x1,:3]=paint.surface(kind,(y1-y0,x1-x0),tier,sum(map(ord,obj['part']))+poly.index*43)
        gutter(canvas,x0,y0,x1,y1)

def gutter(canvas,x0,y0,x1,y1):
    if x0:canvas[y0:y1,x0-1]=canvas[y0:y1,x0]
    if x1<canvas.shape[1]:canvas[y0:y1,x1]=canvas[y0:y1,x1-1]
    if y0:canvas[y0-1,x0:x1]=canvas[y0,x0:x1]
    if y1<canvas.shape[0]:canvas[y1,x0:x1]=canvas[y1-1,x0:x1]

def pack(canvas,objects,existing,squire):
    h,w=canvas.shape[:2]
    occupied=np.zeros((h,w),dtype=bool)
    for obj in existing:
        for layer in obj.data.uv_layers:
            for poly in obj.data.polygons:
                points=np.array([tuple(layer.data[i].uv) for i in poly.loop_indices])*[w,h]
                lo=np.floor(points.min(axis=0)).astype(int)-3;hi=np.ceil(points.max(axis=0)).astype(int)+3
                occupied[max(0,lo[1]):min(h,hi[1]+1),max(0,lo[0]):min(w,hi[0]+1)]=True
    slots=[]
    for y in range(4,h-24,28):
        for x in range(4 if squire else w//2+4,w-24,28):
            if not occupied[y:y+24,x:x+24].any():slots.append((x,y))
    assert len(slots)>=sum(len(o.data.polygons) for o in objects),(len(slots),'insufficient unused atlas cells')
    first=0
    for obj in objects:
        uv=obj.data.uv_layers.active
        for poly in obj.data.polygons:
            x,y=slots[first];first+=1
            coords=np.array([tuple(obj.data.vertices[i].co) for i in poly.vertices]);normal=np.array(poly.normal)
            edge=coords[1]-coords[0];edge/=np.linalg.norm(edge);other=np.cross(normal,edge)
            p=coords@np.stack((edge,other),axis=1);lo=p.min(axis=0);size=np.ptp(p,axis=0)
            assert min(size)>1e-8,(obj.name,poly.index)
            for loop,point in zip(poly.loop_indices,p):
                pixel=np.array([x+2,y+2])+(point-lo)/size*20;uv.data[loop].uv=(pixel[0]/w,pixel[1]/h)
            canvas[y:y+24,x:x+24,:3]=paint.surface(obj['tribal_material'],(24,24),0,sum(map(ord,obj['part']))+poly.index*53)

def build(row,views=('front','three_quarter','back','game_top')):
    stem=row['stem'];source=FROZEN/stem;out=OUT/stem
    report=json.loads((source/(stem+'_report.json')).read_text(encoding='utf-8'))
    if bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
    scene=load_scene(source/(stem+'.blend'));bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE');root=rig.parent
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    for obj in parts:obj.data=obj.data.copy()
    reset_pose(rig,scene);original_geometry={o['part']:np.array([tuple(v.co) for v in o.data.vertices]) for o in parts}
    original_uv={o['part']:uvboxes(o) for o in parts}
    material=parts[0].data.materials[0].copy()
    image=bpy.data.images.load(str(source/(stem+'_albedo.png')),check_existing=False);image.colorspace_settings.name='Non-Color'
    canvas=pixels(image).copy();h,w=canvas.shape[:2]
    last=-1
    if row['key']!='squire':
        for boxes in original_uv.values():
            for x0,y0,x1,y1 in boxes:
                if x0*w<w//2:continue
                last=max(last,round((y0*h-6)/28)*18+round((x0*w-w//2-6)/28))
    g=Gear(scene,rig,parts,row);apparel(g);rotations=rotate_blades(g)
    changed=[]
    for obj in parts:
        if obj in g.new:continue
        name=obj['part']
        if name in BODY and (name!='Head' or paint.heavy(row)):
            for poly in obj.data.polygons:
                lo,hi,frac=rectangle(obj,poly,w,h);x0,y0=lo;x1,y1=hi
                vertices,axes=cuboid_axes(obj);position=frac@axes.T+vertices[0]
                original=canvas[y0:y1,x0:x1,:3].copy()
                canvas[y0:y1,x0:x1,:3]=(paint.skull(poly,frac,position,original) if name=='Head'
                                                    else paint.body(obj,poly,frac,position,row,original))
                gutter(canvas,x0,y0,x1,y1)
            changed.append(name)
        elif paint.heavy(row) and name.startswith('Brow'):
            repaint(canvas,obj,'bone',row['tier']);changed.append(name)
        elif any(tag in name.lower() for tag in ('cape','mantle','tabard','satchel','pouch','strap','clasp')) and not name.startswith(('Guard','Knife','Spine','Horse')):
            kind='hardware' if 'clasp' in name.lower() else 'strap' if 'strap' in name.lower() else 'leather' if any(tag in name.lower() for tag in ('satchel','pouch')) else 'darkcloth' if row['family']=='rogue' else 'olive' if row['family']=='ranger' else 'cloth'
            repaint(canvas,obj,kind,row['tier']);changed.append(name)
    pack(canvas,[o for o in g.new if o.name not in g.shared_uv],
         [o for o in parts if o not in g.new],row['key']=='squire')
    for obj in g.new:
        if obj.name not in g.shared_uv:continue
        source_obj=g.by[g.shared_uv[obj.name]];source_uv=source_obj.data.uv_layers.active
        for poly,source_poly in zip(obj.data.polygons,source_obj.data.polygons):
            for loop,source_loop in zip(poly.loop_indices,source_poly.loop_indices):
                obj.data.uv_layers.active.data[loop].uv=source_uv.data[source_loop].uv
    # Joining meshes exports the first source UV layer. Give every new detail
    # that exact layer name so its leather/hardware survives Godot import.
    export_uv_name=parts[0].data.uv_layers[0].name
    for obj in g.new:obj.data.uv_layers.active.name=export_uv_name
    atlas=save_atlas(canvas,out/(stem+'_albedo.png'),stem+'_Clothing_Albedo')
    for node in material.node_tree.nodes:
        if node.type=='TEX_IMAGE':node.image=atlas;node.interpolation='Closest'
    for obj in parts:
        obj.data.materials.clear();obj.data.materials.append(material)
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
        assert all(e.is_manifold for e in bm.edges),obj.name;bm.to_mesh(obj.data);bm.free()
    for name in BODY:assert np.array_equal(original_geometry[name],np.array([tuple(v.co) for v in g.by[name].data.vertices]))
    bpy.context.view_layer.update()
    coords=np.array([tuple(o.matrix_world@v.co) for o in parts for v in o.data.vertices]);lo=coords.min(axis=0);hi=coords.max(axis=0)
    point=Vector(((lo+hi)/2).tolist());camera=scene.camera;camera.data.type='ORTHO'
    camera.data.ortho_scale=max(2.85,float((hi-lo)[2])*1.18,float((hi-lo)[0])+.50)
    scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    idle=next(n for n in report['clips'] if n.endswith('_Idle'));actual_pose(scene,rig,source/(stem+'.glb'),idle,0.)
    for view in views:
        camera.location=point+Vector({'front':(0,-12,1.2),'three_quarter':(6,-12,5.6),'back':(-6,12,5),'game_top':(5,-7,11)}[view])
        camera.rotation_euler=(point-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/'previews'/(view+'.png'));bpy.ops.render.render(write_still=True)
    reset_pose(rig,scene);gltf=clothing_export(row,scene,parts,rig,root,out,original_uv,rotations);reset_pose(rig,scene)
    for track in rig.animation_data.nla_tracks:track.mute=False;track.is_solo=False
    scene.frame_set(1)
    scene['description']='Refined orc clothing: sewn hide, wrapped leather, real buckles, horned pauldrons; skeletal armor over green skin. Approved bodies and animations unchanged. Blade edges face forward.'
    bpy.data.libraries.write(str(out/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    for obj in parts:obj.data.calc_loop_triangles()
    report['clothing_revision']='leather_and_skeletal_v1'
    report['clothing_refinement']=dict(source=str((source/(stem+'.blend')).relative_to(ROOT)),added_parts=[o['part'] for o in g.new],removed_parts=g.removed,
        repainted_parts=changed,skull_helmet=paint.heavy(row),green_skin_between_bones=paint.heavy(row),
        blade_rotations=rotations,source_part_uv_boxes=original_uv,source_part_vertices={n:p.tolist() for n,p in original_geometry.items()},
        source_part_bones={n:o['rig_bone'] for n,o in g.by.items() if n in original_geometry},
        new_part_uv_boxes={o['part']:uvboxes(o) for o in g.new},
        anatomy_preserved=True,animations_preserved=True,weapon_shapes_and_grips_preserved=True)
    exported=PoseModel(out/(stem+'.glb'));p,ids,_=exported.geometry()
    native=exported.skinned(exported.rest,p,ids)@np.array([[1,0,0],[0,0,1],[0,-1,0]])
    lo=native.min(axis=0);hi=native.max(axis=0)
    report['geometry'].update(editable_parts=len(parts),triangles=sum(len(o.data.loop_triangles) for o in parts),
                              bounds_min=lo.tolist(),bounds_max=hi.tolist(),dimensions=(hi-lo).tolist(),bounds_source='exported_rest_skin')
    report['texture'].update(albedo_sha256=hashlib.sha256((out/(stem+'_albedo.png')).read_bytes()).hexdigest(),
                            clothing_revision='leather_and_skeletal_v1',head_style='painted_skull_bone_helmet' if paint.heavy(row) else 'approved_bare_orc_face')
    report['texture'].pop('unchanged_atlas_sha256',None)
    report['texture']['equipment_materials']={k:v for k,v in report['texture'].get('equipment_materials',{}).items() if k in g.by}
    report['texture']['equipment_materials'].update({o['part']:o['tribal_material'] for o in g.new})
    (out/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    return dict(status='PASS',stem=stem,added_parts=len(g.new),skull_helmet=paint.heavy(row),rotated_blade_grips=list(rotations),clips=len(gltf['animations']))

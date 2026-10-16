"""Change only equipment and mounted armor in the running Blender MCP.

Approved anatomy, rig, animations and contact geometry are read-only inputs.
New pieces are rigidly weighted to existing bones, in the old weapon frame.
"""
import bpy,bmesh,hashlib,json,sys,numpy as np
from pathlib import Path
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from orc_troop_assets import ROOT,OUT,WORK
from build_elf_troops import BODY,FACES,reset_pose,pixels,export_glb
from build_orc_squire import cuboid_axes,rectangle,resize
from build_orc_troops import load_scene,save_atlas
from orc_tribal_paint import surface,mounted_armor
from glb_pose_math import PoseModel

FROZEN=WORK/'tribal_equipment/before_assets'
GRIPS=('SwordGrip','BowGrip','AxeHaft','LanceHaft','ShieldGrip','DaggerGrip_r','DaggerGrip_l')

def frame(obj):
    v,axes=cuboid_axes(obj);length=np.linalg.norm(axes,axis=0)
    u,_,vt=np.linalg.svd(axes/length)
    return v.mean(axis=0),u@vt,length

class Gear:
    def __init__(self,scene,rig,parts,row):
        self.scene,self.rig,self.parts,self.row=scene,rig,parts,row
        self.by={o['part']:o for o in parts};self.new=[];self.removed=[]
    def remove(self,names):
        for name in names:
            obj=self.by.pop(name,None)
            if obj is None:continue
            self.parts.remove(obj);self.removed.append(name)
            bpy.data.objects.remove(obj,do_unlink=True)
    def mesh(self,name,vertices,faces,kind,bone):
        mesh=bpy.data.meshes.new(self.row['stem']+'_'+name+'_Mesh')
        mesh.from_pydata(vertices,[],faces);mesh.update()
        obj=bpy.data.objects.new(self.row['stem']+'_'+name,mesh);self.scene.collection.objects.link(obj)
        obj.parent=self.rig;obj['part']=name;obj['region']='tribal_'+kind;obj['rig_bone']=bone
        obj['tribal_material']=kind
        group=obj.vertex_groups.new(name=bone);group.add(list(range(len(vertices))),1.,'REPLACE')
        modifier=obj.modifiers.new('Rigid_Equipment_Skin','ARMATURE');modifier.object=self.rig
        mesh.uv_layers.new(name='UVMap')
        self.parts.append(obj);self.by[name]=obj;self.new.append(obj)
        return obj
    def box(self,name,origin,axes,center,size,kind,bone):
        local=np.array([(x*size[0]/2,y*size[1]/2,z*size[2]/2) for z in (-1,1) for y in (-1,1) for x in (-1,1)])+center
        return self.mesh(name,(local@axes.T+origin).tolist(),FACES,kind,bone)
    def plate(self,name,origin,axes,outline,depth,y,kind,bone):
        n=len(outline)
        vertices=np.array([(x,yy+y,z) for yy in (-depth/2,depth/2) for x,z in outline])
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        return self.mesh(name,(vertices@axes.T+origin).tolist(),faces,kind,bone)
    def bounds(self,names,origin,axes):
        points=np.array([tuple(v.co) for name in names if name in self.by for v in self.by[name].data.vertices])
        p=(points-origin)@axes
        return p.min(axis=0),p.max(axis=0)

def sword(g):
    grip=g.by['SwordGrip'];origin,axes,size=frame(grip);bone=grip['rig_bone'];tier=g.row['tier']
    names=[name for name in g.by if name.startswith('Sword') and name!='SwordGrip']
    lo,hi=g.bounds([n for n in names if n in ('SwordBlade','SwordTip','SwordRicasso')],origin,axes)
    pommel_lo,pommel_hi=g.bounds([n for n in names if 'Pommel' in n or 'Gem' in n],origin,axes)
    g.remove(names)
    start=size[2]/2+.065;length=(hi[2]-start)*(.88 if tier==1 else .94)
    width=max(.17,(hi[0]-lo[0])*1.60);width=min(width,.30)
    outline=[(-width*.46,start),(width*.38,start),(width*.42,start+length*.58),
             (width*.70,start+length*.83),(width*.35,start+length),(-width*.52,start+length*.94),(-width*.45,start+length*.52)]
    g.plate('TribalCleaverBlade',origin,axes,outline,.035+tier*.004,0,'iron',bone)
    # A continuous sharpened front edge and a bone spine rooted above the hand.
    edge=[(width*.30,start+.04),(width*.38,start+.04),(width*.42,start+length*.58),
          (width*.70,start+length*.83),(width*.35,start+length),(width*.29,start+length*.97),
          (width*.61,start+length*.82),(width*.34,start+length*.58)]
    g.plate('CleaverHonedEdge',origin,axes,edge,.042+tier*.004,0,'edge',bone)
    guard_z=size[2]/2+.022
    guard=[(-.16,guard_z-.02),(.15,guard_z-.02),(.18,guard_z+.035),(.13,guard_z+.065),(-.17,guard_z+.052)]
    g.plate('BoneCrossguard',origin,axes,guard,.07,0,'bone',bone)
    g.box('GuardLeatherTie',origin,axes,[0,0,guard_z+.019],[.085,.076,.035],'leather',bone)
    g.box('BonePommel',origin,axes,[0,0,(pommel_lo[2]+pommel_hi[2])/2],[size[0]*1.1,size[1]*1.2,pommel_hi[2]-pommel_lo[2]],'bone_dark',bone)
    if tier>=2:
        g.box('CleaverBoneSpine',origin,axes,[-width*.38,0,start+length*.22],[width*.15,.055,length*.30],'bone',bone)
        for z in (start+length*.10,start+length*.33):
            g.box('SpineBinding_'+str(round(z,3)),origin,axes,[-width*.34,0,z],[width*.21,.060,.023],'leather',bone)
    if 'Scabbard' in g.by:resize(g.by['Scabbard'],(1.5,1.,1.))

def axe(g):
    grip=g.by['AxeHaft'];origin,axes,size=frame(grip);bone=grip['rig_bone']
    # The original axe cuts in its Y/Z plane. Retain that plane as well as
    # the handle, so the existing swing still leads with the cutting edge.
    axes=np.stack((-axes[:,1],axes[:,0],axes[:,2]),axis=1)
    lo,hi=g.bounds(['AxeHead','AxeBit'],origin,axes);g.remove(['AxeHead','AxeBit'])
    z=(lo[2]+hi[2])/2;width=max(.35,hi[0]*1.4);height=max(.29,hi[2]-lo[2])
    g.box('AxeBoneSocket',origin,axes,[0,0,z],[.12,.12,height*.82],'bone',bone)
    outline=[(-.03,z-height*.43),(width*.62,z-height*.57),(width*.81,z-height*.30),
             (width*.81,z+height*.48),(width*.62,z+height*.61),(-.03,z+height*.42)]
    g.plate('TribalAxeBlade',origin,axes,outline,.065,0,'iron',bone)
    edge=[(width*.68,z-height*.52),(width*.81,z-height*.30),(width*.81,z+height*.48),
          (width*.66,z+height*.58),(width*.61,z+height*.49),(width*.70,z+height*.40),(width*.70,z-height*.29)]
    g.plate('AxeHonedEdge',origin,axes,edge,.073,0,'edge',bone)
    for side in (-1,1):
        g.box('AxeSocketTie_'+str(side),origin,axes,[0,0,z+side*height*.26],[.138,.135,.037],'leather',bone)

def knives(g):
    tier=g.row['tier']
    for side in ('r','l'):
        name='DaggerGrip_'+side
        if name not in g.by:continue
        grip=g.by[name];origin,axes,size=frame(grip);bone=grip['rig_bone']
        lo,hi=g.bounds(['DaggerBlade_'+side],origin,axes)
        g.remove(['DaggerGuard_'+side,'DaggerBlade_'+side])
        start=size[2]/2+.048;length=(hi[2]-start)*.91;width=max(.10,(hi[0]-lo[0])*1.40)
        width=min(width,.17)
        outline=[(-width*.35,start),(width*.45,start),(width*.58,start+length*.64),
                 (width*.08,start+length),(-width*.41,start+length*.78)]
        g.plate('TribalKnifeBlade_'+side,origin,axes,outline,.032,0,'bone' if tier==0 else 'iron',bone)
        g.box('KnifeBoneGuard_'+side,origin,axes,[0,0,size[2]/2+.018],[width*1.4,.075,.043],'bone',bone)
        g.box('KnifeHeelTie_'+side,origin,axes,[0,0,start+.027],[width*.9,.047,.052],'leather',bone)
        g.box('KnifeBonePommel_'+side,origin,axes,[0,0,-size[2]/2-.018],[size[0]*1.1,size[1]*1.1,.04],'bone_dark',bone)

def bows(g):
    tier=g.row['tier']
    for name in ('BowLimb_u2','BowLimb_d2','BowLimb_u3','BowLimb_d3'):
        obj=g.by[name];origin,axes,size=frame(obj)
        g.box('BoneBacking_'+name,origin,axes,[0,-size[1]/2-.006,0],[size[0]*.88,.014,size[2]*.76],'bone',obj['rig_bone'])
        # A narrow strip wraps the backing and wood together.
        g.box('Binding_'+name,origin,axes,[0,0,size[2]*.19],[size[0]+.012,size[1]+.029,.022],'leather',obj['rig_bone'])
    arrow=g.by['ArrowHead'];origin,axes,size=frame(arrow);bone=arrow['rig_bone'];g.remove(['ArrowHead'])
    w=size[0]*.60;h=size[2]/2
    g.plate('BoneArrowPoint',origin,axes,[(-w,-h),(w,-h),(w*.76,h*.12),(0,h*1.1),(-w*.76,h*.12)],max(.012,size[1]),0,'bone',bone)
    if tier>=1:
        quiver=g.by['Quiver'];origin,axes,size=frame(quiver)
        for sign in (-1,1):
            g.box('QuiverBoneClamp_'+str(sign),origin,axes,[sign*size[0]*.29,-size[1]/2-.008,size[2]*.36],[size[0]*.20,.024,size[2]*.13],'bone_dark',quiver['rig_bone'])

def lances(g):
    haft=g.by['LanceHaft'];origin,axes,size=frame(haft);bone=haft['rig_bone'];tier=g.row['tier']
    lo,hi=g.bounds(['LanceHead','LanceTip'],origin,axes)
    guard_z=None
    if 'LanceVamplate' in g.by:
        guard_lo,guard_hi=g.bounds(['LanceVamplate'],origin,axes)
        guard_z=(guard_lo[2]+guard_hi[2])/2
    g.remove(['LanceHead','LanceTip','LanceVamplate','Pennant'])
    start=lo[2]-.035;length=max(.24,hi[2]-start+.04+tier*.018);width=.12+tier*.021
    outline=[(-width*.52,start),(width*.50,start),(width*.60,start+length*.48),
             (width*.24,start+length*.78),(-width*.16,start+length),(-width*.48,start+length*.70)]
    g.plate('TuskLanceHead',origin,axes,outline,.048+tier*.007,0,'bone',bone)
    g.box('LanceHeadSocket',origin,axes,[0,0,start+.018],[width*.76,.078,.094],'iron',bone)
    for offset in (-.048,.043):
        g.box('LanceHeadBinding_'+str(offset),origin,axes,[0,0,start+offset],[width*.81,.087,.029],'leather',bone)
    if guard_z is not None:
        # Small bone guard above the fingers; the approved shaft stays exact.
        g.box('LanceBoneStop',origin,axes,[0,0,guard_z],[.12,.10,.040],'bone_dark',bone)
    if tier>=2:
        for sign in (-1,1):
            z=start+length*.29
            profile=[(sign*width*.40,z),(sign*width*.91,z-.055),(sign*width*.81,z+.060),(sign*width*.40,z+.09)]
            g.plate('LanceBarb_'+str(sign),origin,axes,profile,.048,0,'bone_dark',bone)

def shields(g):
    if 'ShieldMid' in g.by:
        obj=g.by['ShieldMid'];origin,axes,size=frame(obj);bone=obj['rig_bone']
        for x,z in ((-1,-1),(1,-1),(-1,1),(1,1)):
            g.box('ShieldBoneClamp_'+str(x)+'_'+str(z),origin,axes,[x*size[0]*.32,-size[1]/2-.015,z*size[2]*.34],
                  [size[0]*.17,.04,size[2]*.13],'bone_dark',bone)
    elif 'Shield' in g.by:
        obj=g.by['Shield'];origin,axes,size=frame(obj)
        for sign in (-1,1):
            g.box('RiderShieldBoneClamp_'+str(sign),origin,axes,[sign*size[0]*.28,-size[1]/2-.016,0],
                  [size[0]*.19,.042,size[2]*.67],'bone',obj['rig_bone'])

def cavalry(g):
    tier=g.row['tier']
    if tier>=1:
        for side in ('l','r'):
            obj=g.by['Shoulder_'+side];origin,axes,size=frame(obj);sign=1 if side=='l' else -1
            # A short tusk at the outside edge, leaving the face and neck free.
            profile=[(sign*size[0]*.28,size[2]*.30),(sign*size[0]*.53,size[2]*.34),
                     (sign*size[0]*.68,size[2]*.79),(sign*size[0]*.35,size[2]*.65)]
            g.plate('ShoulderBoneTusk_'+side,origin,axes,profile,.07,0,'bone_dark',obj['rig_bone'])
    if tier>=2:
        head=g.by['HorseHead'];origin,axes,size=frame(head)
        g.box('HorseBoneForehead',origin,axes,[0,-size[1]*.18,size[2]/2+.010],
              [size[0]*.78,size[1]*.40,.031],'bone',head['rig_bone'])
        g.box('HorseForeheadBinding',origin,axes,[0,-size[1]*.04,size[2]/2+.017],
              [size[0]*.83,.027,.039],'leather',head['rig_bone'])
        body=g.by['HorseBody'];origin,axes,size=frame(body)
        for side in (-1,1):
            for index in range(3):
                g.box('HorseBoneRib_'+str(side)+'_'+str(index),origin,axes,[side*(size[0]/2+.014),(index-1)*size[1]*.19,0],
                      [.035,size[1]*.13,size[2]*.72],'bone_dark',body['rig_bone'])

def equipment_kind(obj):
    name=obj['part']
    if name.startswith(('Rein','String')):return None
    if name in GRIPS:return 'wood' if name in ('AxeHaft','LanceHaft') else 'leather'
    if name.startswith('BowLimb') or name=='ArrowShaft':return 'wood'
    if name.startswith(('BowCap','BowHorn')) or name in ('Gorget','ShoulderLame_l','ShoulderLame_r','ShoulderPlate','BeltSeal','ToolClasp','ShieldBoss'):return 'bone'
    if name in ('Knife','Dagger') or name.startswith('Tool_'):return 'bone_dark'
    if name=='Scabbard':return 'leather'
    return None

def paint_existing(canvas,obj,kind,tier):
    for poly in obj.data.polygons:
        lo,hi,_=rectangle(obj,poly,canvas.shape[1],canvas.shape[0]);x0,y0=lo;x1,y1=hi
        canvas[y0:y1,x0:x1,:3]=surface(kind,(y1-y0,x1-x0),tier,seed=sum(map(ord,obj['part']))+poly.index*37)
        if x0>0:canvas[y0:y1,x0-1]=canvas[y0:y1,x0]
        if x1<canvas.shape[1]:canvas[y0:y1,x1]=canvas[y0:y1,x1-1]
        if y0>0:canvas[y0-1,x0:x1]=canvas[y0,x0:x1]
        if y1<canvas.shape[0]:canvas[y1,x0:x1]=canvas[y1-1,x0:x1]

def pack_new(canvas,objects,first,tier):
    h,w=canvas.shape[:2]
    for obj in objects:
        uv=obj.data.uv_layers.active
        for poly in obj.data.polygons:
            x=w//2+4+(first%18)*28;y=4+(first//18)*28;first+=1
            assert x+24<w and y+24<h,(obj.name,first)
            coords=np.array([tuple(obj.data.vertices[i].co) for i in poly.vertices]);normal=np.array(poly.normal)
            edge=coords[1]-coords[0];edge/=np.linalg.norm(edge);other=np.cross(normal,edge)
            projection=coords@np.stack((edge,other),axis=1);lo=projection.min(axis=0);size=np.ptp(projection,axis=0)
            for loop,point in zip(poly.loop_indices,projection):
                p=np.array([x+2,y+2])+(point-lo)/size*20
                uv.data[loop].uv=(p[0]/w,p[1]/h)
            canvas[y:y+24,x:x+24,:3]=surface(obj['tribal_material'],(24,24),tier,seed=sum(map(ord,obj['part']))+poly.index*53)

def actual_pose(scene,rig,path,clip,time):
    reset_pose(rig,scene);model=PoseModel(path);world=model.worlds(clip,time)
    inverse=np.linalg.inv(world[model.parent[model.by_name['root']]])
    conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
    for name in ['root']+[n for n in model.names if n!='root']:
        rig.pose.bones[name].matrix=conversion@Matrix((inverse@world[model.by_name[name]]).tolist())
    bpy.context.view_layer.update()

def build(row,views=('front','three_quarter','back','game_top'),attack_view=False):
    stem=row['stem'];frozen=FROZEN/stem;out=OUT/stem
    report=json.loads((frozen/(stem+'_report.json')).read_text(encoding='utf-8'))
    if row['key']=='squire':
        for suffix in ('.blend','.glb','_albedo.png'):
            assert (out/(stem+suffix)).read_bytes()==(frozen/(stem+suffix)).read_bytes()
        report['equipment_revision']='tribal_v1'
        report['tribal_equipment']=dict(initial_approved_shield_preserved=True,animations_unchanged=True)
        (out/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        return dict(status='PASS',stem=stem,approved_initial_shield_preserved=True)
    if bpy.context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
    scene=load_scene(frozen/(stem+'.blend'));bpy.context.window.scene=scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    root=next(o for o in scene.objects if o.type=='EMPTY' and o.parent is None)
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('region') not in (None,'studio')]
    for obj in parts:obj.data=obj.data.copy()
    reset_pose(rig,scene)
    source_geometry={o['part']:np.array([tuple(v.co) for v in o.data.vertices]) for o in parts}
    source_rig={b.name:np.array(b.matrix_local) for b in rig.data.bones}
    material=parts[0].data.materials[0].copy()
    old_image=bpy.data.images.load(str(frozen/(stem+'_albedo.png')),check_existing=False)
    old_image.colorspace_settings.name='Non-Color'
    canvas=pixels(old_image).copy();h,w=canvas.shape[:2]
    last=-1
    for obj in parts:
        for poly in obj.data.polygons:
            points=np.array([tuple(obj.data.uv_layers.active.data[i].uv) for i in poly.loop_indices])*[w,h]
            if points[:,0].min()<w//2:continue
            col=round((points[:,0].min()-w//2-6)/28);line=round((points[:,1].min()-6)/28)
            last=max(last,line*18+col)
    g=Gear(scene,rig,parts,row)
    if row['family']=='warrior':axe(g) if row['key']=='warrior' else sword(g)
    if row['family']=='rogue':knives(g)
    if row['family']=='ranger':bows(g)
    if row['family']=='cavalry':lances(g);cavalry(g)
    if row['family'] in ('guardian','cavalry'):shields(g)
    changed_existing={};body_paint=[]
    for obj in parts:
        if obj in g.new:continue
        kind=equipment_kind(obj)
        if kind:
            paint_existing(canvas,obj,kind,row['tier']);changed_existing[obj['part']]=kind
        if row['family']=='cavalry' and obj['part'] in BODY:
            changed=False
            for poly in obj.data.polygons:
                lo,hi,frac=rectangle(obj,poly,w,h)
                changed|=mounted_armor(canvas,obj,poly,lo,hi,frac,row['tier'])
                x0,y0=lo;x1,y1=hi
                if x0>0:canvas[y0:y1,x0-1]=canvas[y0:y1,x0]
                if x1<w//2:canvas[y0:y1,x1]=canvas[y0:y1,x1-1]
                if y0>0:canvas[y0-1,x0:x1]=canvas[y0,x0:x1]
                if y1<h:canvas[y1,x0:x1]=canvas[y1-1,x0:x1]
            if changed:body_paint.append(obj['part'])
    pack_new(canvas,g.new,last+1,row['tier'])
    atlas=save_atlas(canvas,out/(stem+'_albedo.png'),stem+'_Tribal_Albedo')
    for node in material.node_tree.nodes:
        if node.type=='TEX_IMAGE':node.image=atlas;node.interpolation='Closest'
    for obj in parts:
        obj.data.materials.clear();obj.data.materials.append(material)
        bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges),obj.name;bm.free()
    by={o['part']:o for o in parts}
    for name in BODY:
        assert np.array_equal(source_geometry[name],np.array([tuple(v.co) for v in by[name].data.vertices])),name
    grips={}
    for name in GRIPS:
        if name not in by:continue
        original=source_geometry[name];current=np.array([tuple(v.co) for v in by[name].data.vertices])
        assert np.array_equal(original,current),(stem,name)
        grips[name]=dict(bone=by[name]['rig_bone'],vertices=original.tolist(),
            uv_boxes=[[float(v) for v in np.r_[np.min([tuple(by[name].data.uv_layers.active.data[i].uv) for i in p.loop_indices],axis=0),np.max([tuple(by[name].data.uv_layers.active.data[i].uv) for i in p.loop_indices],axis=0)]] for p in by[name].data.polygons])
    assert all(np.array_equal(source_rig[b.name],np.array(b.matrix_local)) for b in rig.data.bones)
    # Newly linked pieces need their parent's scale evaluated before bounds.
    bpy.context.view_layer.update()
    coords=[o.matrix_world@v.co for o in parts for v in o.data.vertices]
    lo=[min(v[i] for v in coords) for i in range(3)];hi=[max(v[i] for v in coords) for i in range(3)]
    point=Vector([(a+b)/2 for a,b in zip(lo,hi)])
    camera=scene.camera;camera.data.type='ORTHO';camera.data.ortho_scale=max(2.85,(hi[2]-lo[2])*1.2,hi[0]-lo[0]+.5)
    scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
    idle=next(n for n in report['clips'] if n.endswith('_Idle'))
    actual_pose(scene,rig,frozen/(stem+'.glb'),idle,0.)
    for view in views:
        offset={'front':(0,-12,1.2),'three_quarter':(6,-12,5.6),'back':(-6,12,5),'game_top':(5,-7,11)}[view]
        camera.location=point+Vector(offset);camera.rotation_euler=(point-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/'previews'/(view+'.png'));bpy.ops.render.render(write_still=True)
    if attack_view:
        attack=next(n for n in report['clips'] if n.endswith('_Attack'))
        actual_pose(scene,rig,frozen/(stem+'.glb'),attack,report['clips'][attack]*.35)
        camera.location=point+Vector((5,-12,4));camera.rotation_euler=(point-camera.location).to_track_quat('-Z','Y').to_euler()
        dest=WORK/'tribal_equipment/attack_previews';dest.mkdir(exist_ok=True)
        scene.render.filepath=str(dest/(stem+'.png'));bpy.ops.render.render(write_still=True)
    reset_pose(rig,scene);gltf=export_glb(row,scene,parts,rig,root,out)
    reset_pose(rig,scene)
    for track in rig.animation_data.nla_tracks:track.mute=False;track.is_solo=False
    scene.frame_set(1)
    scene['description']='Tribal orc equipment: bone, bound wood, leather and rough forged edges. Approved anatomy, grips, skeleton and all class animations unchanged.'
    bpy.data.libraries.write(str(out/(stem+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    report['equipment_revision']='tribal_v1'
    report['geometry'].update(editable_parts=len(parts),bounds_min=lo,bounds_max=hi,dimensions=[b-a for a,b in zip(lo,hi)])
    for obj in parts:obj.data.calc_loop_triangles()
    report['geometry']['triangles']=sum(len(o.data.loop_triangles) for o in parts)
    report['texture']['tribal_materials']=changed_existing|{o['part']:o['tribal_material'] for o in g.new}
    report['texture']['equipment_materials']={n:k for n,k in report['texture'].get('equipment_materials',{}).items() if n in by}
    report['texture']['equipment_materials'].update(report['texture']['tribal_materials'])
    report['texture']['mounted_bone_armor_parts']=body_paint
    report['texture']['albedo_sha256']=hashlib.sha256((out/(stem+'_albedo.png')).read_bytes()).hexdigest()
    if 'unchanged_atlas_sha256' in report['texture']:
        report['texture']['prior_anatomy_v2_albedo_sha256']=report['texture'].pop('unchanged_atlas_sha256')
    report['tribal_equipment']=dict(source=str((frozen/(stem+'.blend')).relative_to(ROOT)),
        source_blend_sha256=hashlib.sha256((frozen/(stem+'.blend')).read_bytes()).hexdigest(),
        added_parts=[o['part'] for o in g.new],removed_parts=g.removed,grips=grips,
        anatomy_geometry_preserved=True,rig_rest_preserved=True,animations_unchanged=True,
        bow_and_string_contact_geometry_preserved=row['family']=='ranger')
    (out/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    return dict(status='PASS',stem=stem,added_parts=len(g.new),grips=list(grips),bone_armor=body_paint,clips=len(gltf['animations']))

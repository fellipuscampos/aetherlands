"""Reference-driven western dragon. Execute in the live Blender session via MCP.

Standalone asset: does not replace the approved elemental serpent or wyvern.
Four legs, raised bat wings, curled tail; dark burgundy clustered pixel scales.
"""
import bpy, bmesh, math, json, hashlib, ast
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix, Euler

ROOT = Path(r'C:\Users\felipe campos\Documents\jogo')
STEM = globals().get('DRAGON_STEM','dark_red_dragon_v1')
NAME = globals().get('DRAGON_NAME','Dark_Red_Dragon_V1')
OUT = ROOT / 'assets/generated/dragons' / STEM
REBUILD = globals().get('DRAGON_REBUILD',False)
assert REBUILD or not (OUT / (STEM + '.glb')).exists(), 'Preserve completed asset.'
if NAME in bpy.data.scenes:
    assert REBUILD, 'Preserve existing scene.'
    owned = bpy.data.scenes[NAME]
    assert all(o.name.startswith(STEM) for o in owned.objects), 'Unexpected object; preserve edits.'
    if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.window.scene=next(s for s in bpy.data.scenes if s!=owned)
    for obj in list(owned.objects): bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.scenes.remove(owned)
    for blocks in (bpy.data.meshes,bpy.data.armatures,bpy.data.materials,bpy.data.images,bpy.data.cameras,bpy.data.lights,bpy.data.worlds):
        for item in list(blocks):
            if item.name.startswith(STEM) and item.users==0: blocks.remove(item)
OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'previews').mkdir(exist_ok=True)
protected = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in (ROOT / 'assets/generated').rglob('*.glb') if p.parent!=OUT}
previous_scenes = set(bpy.data.scenes.keys())
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
scene = bpy.data.scenes.new(NAME)
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'
root = bpy.data.objects.new(STEM, None)
scene.collection.objects.link(root)
root['description'] = 'Western dragon, four legs, raised wings, dark red pixel scales'
parts = []
pivots = {'root': (Vector((0, 0, 0)), Vector((0, 0, .2)), None)}
FACES = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]

# Established closed-prism helpers, also used by the approved elemental model.
helper_path = ROOT / 'tools/art_pipeline/build_elemental_dragon_mcp.py'
helper_source = helper_path.read_text(encoding='utf-8')
helper_tree = ast.parse(helper_source)
for node in helper_tree.body:
    if isinstance(node, ast.FunctionDef) and node.name in ('mesh','box','beam','spike'):
        exec(compile(ast.Module(body=[node], type_ignores=[]), str(helper_path), 'exec'), globals())

def bone(name, a, b, parent='chest'):
    pivots[name] = (Vector(a), Vector(b), parent)

def tapered(label, a, b, wa, da, wb, db, joint, kind):
    a, b = Vector(a), Vector(b)
    axis = (b-a).normalized()
    x = Vector((1,0,0)); x -= axis * x.dot(axis)
    if x.length < .01:
        x = Vector((0,1,0)); x -= axis*x.dot(axis)
    x.normalize(); y = axis.cross(x)
    verts = [c+x*sx*w/2+y*sy*d/2
             for c,w,d in ((a,wa,da),(b,wb,db))
             for sy in (-1,1) for sx in (-1,1)]
    return mesh(label, verts, FACES, joint, kind)

def tube(label, path, widths, depths, joints, kind, bevel=.12):
    # A continuous rectangular section with small clipped corners. Flat shading.
    verts=[]; influences=[]; frames=[]
    cross=[(-1,-1+bevel),(-1+bevel,-1),(1-bevel,-1),(1,-1+bevel),
           (1,1-bevel),(1-bevel,1),(-1+bevel,1),(-1,1-bevel)]
    last_axis=None; last_x=None
    for i,p in enumerate(path):
        p=Vector(p)
        axis=(Vector(path[min(i+1,len(path)-1)])-Vector(path[max(0,i-1)])).normalized()
        x=Vector((1,0,0)) if last_axis is None else last_axis.rotation_difference(axis)@last_x
        x-=axis*x.dot(axis); x.normalize(); y=axis.cross(x).normalized()
        frames.append((x,y,axis))
        verts.extend(p+x*sx*widths[i]/2+y*sy*depths[i]/2 for sx,sy in cross)
        influences.extend([{joints[i]:1.0}]*8)
        last_axis,last_x=axis,x
    faces=[tuple(reversed(range(8))),tuple(8*(len(path)-1)+j for j in range(8))]
    for i in range(len(path)-1):
        faces.extend((i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j) for j in range(8))
    return mesh(label,verts,faces,joints[0],kind,influences),frames

def membrane(label, points, joint):
    # Piecewise planar closed panels. Exact shared boundaries, real thickness.
    pts=[Vector(p) for p in points]
    triangles=bpy_extras_tessellate([pts])
    # One shell avoids stacked, coplanar prism caps at triangle interfaces.
    normal=sum(((pts[i]-pts[0]).cross(pts[i+1]-pts[0]) for i in range(1,len(pts)-1)),Vector()).normalized()
    n=len(pts); offset=normal*.012
    verts=[p-offset for p in pts]+[p+offset for p in pts]
    faces=[]
    for tri in triangles:
        idx=[int(v) if isinstance(v,int) else next(i for i,p in enumerate(pts) if (p-v).length<1e-6) for v in tri]
        faces.extend([tuple(reversed(idx)),tuple(n+i for i in idx)])
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return mesh(label,verts,faces,joint,'membrane')

from mathutils.geometry import tessellate_polygon as bpy_extras_tessellate

bone('chest',(0,-.25,1.65),(0,-.25,2.0),'root')
bone('hips',(0,.65,1.55),(0,1,1.55))
bone('neck_01',(0,-.55,1.78),(0,-.95,2.05))
bone('neck_02',(0,-.95,2.05),(0,-1.38,2.16),'neck_01')
bone('head',(0,-1.38,2.16),(0,-1.95,2.16),'neck_02')
bone('jaw',(0,-1.55,2.01),(0,-2.21,1.84),'head')

torso,_=tube('Continuous_chest_and_hips',[(0,-.55,1.69),(0,-.15,1.73),(0,.46,1.62),(0,.97,1.53)],
    [.56,.92,.81,.52],[.53,.86,.73,.44],['chest','chest','hips','hips'],'body',.16)
neck,neck_frames=tube('Rising_neck',[(0,-.53,1.81),(0,-.88,2.04),(0,-1.26,2.16),(0,-1.54,2.14)],
    [.54,.46,.39,.37],[.55,.45,.37,.33],['neck_01','neck_01','neck_02','head'],'body',.13)
for i,(y,z,w) in enumerate([(-.73,1.83,.39),(-.98,1.94,.34),(-1.20,2.00,.30)]):
    box('Throat_plate_%02d'%i,(0,y,z-.13),(w,.18,.042),'neck_01' if i<2 else 'neck_02','belly',Euler((.38,0,0)).to_matrix())
for i,y in enumerate([-.43,-.19,.05,.29,.53,.74]):
    z=1.34 if y<0 else 1.24
    box('Belly_plate_%02d'%i,(0,y,z),(.59 if y<.4 else .46,.19,.052),'chest' if y<.1 else 'hips','belly')

# Strong, square face: cheek armor, nostrils, recessed hot eyes and long snout.
box('Skull',(0,-1.64,2.17),(.53,.57,.40),'head','body')
box('Long_upper_muzzle',(0,-2.09,2.10),(.43,.59,.23),'head','body')
box('Nose_armour',(0,-2.37,2.13),(.44,.11,.20),'head','scale')
box('Mouth_interior',(0,-1.95,1.995),(.32,.65,.13),'head','mouth')
jaw_rot=Euler((math.radians(-9),0,0)).to_matrix()
box('Lower_jaw',(0,-2.02,1.84),(.35,.79,.135),'jaw','body',jaw_rot)
box('Jaw_ivory_rim',(0,-2.03,1.784),(.36,.77,.029),'jaw','belly',jaw_rot)
for s,suffix in [(1,'L'),(-1,'R')]:
    box('Cheek_'+suffix,(s*.247,-1.59,2.11),(.105,.34,.255),'head','scale',Euler((0,0,s*.11)).to_matrix())
    box('Eye_socket_'+suffix,(s*.272,-1.81,2.225),(.026,.19,.13),'head','dark')
    box('Fiery_eye_'+suffix,(s*.288,-1.84,2.222),(.018,.125,.074),'head','eye')
    box('Eye_slit_'+suffix,(s*.299,-1.849,2.222),(.009,.025,.077),'head','dark')
    box('Eye_brow_armour_'+suffix,(s*.269,-1.83,2.286),(.084,.235,.057),'head','scale',Euler((math.radians(-13),0,0)).to_matrix())
    box('Nostril_'+suffix,(s*.118,-2.429,2.153),(.065,.011,.038),'head','dark')
    # Large rearward horns and smaller cheek horns, charcoal with red roots.
    tapered('Horn_root_'+suffix,(s*.16,-1.44,2.33),(s*.25,-1.12,2.58),.14,.14,.09,.09,'head','horn')
    spike('Horn_tip_'+suffix,(s*.25,-1.12,2.58),(s*.33,-.84,2.72),.095,.095,'head','horn')
    spike('Cheek_horn_'+suffix,(s*.29,-1.4,2.11),(s*.48,-1.02,2.20),.13,.115,'head','horn')
    for k,y in enumerate([-1.87,-2.02,-2.17,-2.31]):
        spike('Upper_fang_%s_%d'%(suffix,k),(s*.165,y,1.996),(s*.165,y-.007,1.907 if k==0 else 1.931),.047,.050,'head','ivory')
    for k,y in enumerate([-1.89,-2.08,-2.25]):
        z=1.92+(y+1.89)*.155
        spike('Lower_tooth_%s_%d'%(suffix,k),(s*.129,y,z),(s*.129,y,z+.075),.041,.045,'jaw','ivory')

# Four distinct bent legs; separate hands/feet and forward black talons.
for s,suffix in [(1,'L'),(-1,'R')]:
    for label,upper,knee,ankle,foot,thighw in [
        ('Front',(s*.38,-.37,1.65),(s*.58,-.75,1.20),(s*.55,-.73,.73),(s*.55,-.84,.67),.32),
        ('Hind',(s*.38,.69,1.50),(s*.62,.98,1.08),(s*.55,.68,.79),(s*.55,.58,.73),.36)]:
        parent='chest' if label=='Front' else 'hips'
        a=label+'_upper_'+suffix; b=label+'_lower_'+suffix; c=label+'_foot_'+suffix
        bone(a,upper,knee,parent); bone(b,knee,ankle,a); bone(c,ankle,(foot[0],foot[1]-.23,foot[2]),b)
        tapered(label+'_upper_limb_'+suffix,upper,knee,thighw,thighw*.92,.24,.25,a,'body')
        tapered(label+'_lower_limb_'+suffix,knee,ankle,.225,.24,.19,.20,b,'body')
        box(label+'_knee_armour_'+suffix,knee,(.26,.27,.20),b,'scale')
        box(label+'_foot_'+suffix,foot,(.28,.31,.17),c,'body')
        for k,dx in enumerate([-.086,0,.086]):
            base=Vector(foot)+Vector((dx,-.15,-.015))
            tip=base+Vector((dx*.24,-.145,-.115))
            spike(label+'_claw_%s_%d'%(suffix,k),base,tip,.061,.063,c,'horn')

# Raised shoulder / elbow / wrist, swept bat fingers and scalloped membranes.
for s,suffix in [(1,'L'),(-1,'R')]:
    shoulder=Vector((s*.39,-.12,1.97))
    elbow=Vector((s*.92,-.03,2.43))
    wrist=Vector((s*1.34,.04,3.30))
    leading=Vector((s*2.07,.37,3.96))
    tips=[leading,Vector((s*2.20,.73,3.14)),Vector((s*2.02,1.14,2.38)),Vector((s*1.48,1.32,1.91))]
    flank=Vector((s*.33,.89,1.78))
    a='wing_upper_'+suffix; b='wing_fore_'+suffix; c='wing_fan_'+suffix
    bone(a,shoulder,elbow); bone(b,elbow,wrist,a); bone(c,wrist,leading,b)
    tapered('Wing_upper_arm_'+suffix,shoulder,elbow,.23,.22,.18,.17,a,'body')
    tapered('Wing_forearm_'+suffix,elbow,wrist,.18,.17,.13,.13,b,'scale')
    box('Wing_wrist_'+suffix,wrist,(.20,.21,.20),c,'scale')
    spike('Wing_thumb_'+suffix,wrist+Vector((0,-.10,.02)),wrist+Vector((s*.07,-.32,.20)),.10,.095,c,'horn')
    for i,tip in enumerate(tips):
        tapered('Wing_finger_%s_%d'%(suffix,i),wrist,tip,.125 if i==0 else .078,.10 if i==0 else .067,.070 if i==0 else .036,.060 if i==0 else .035,c,'scale')
        d=(tip-wrist).normalized()
        spike('Wing_tip_%s_%d'%(suffix,i),tip-d*.018,tip+d*.10,.073,.061,c,'horn')
    for i in range(len(tips)-1):
        middle=wrist.lerp(tips[i].lerp(tips[i+1],.5),.77)
        # A stepped scallop echoes the serrated pixel outline of the reference.
        e0=tips[i].lerp(middle,.60); e1=middle.lerp(tips[i+1],.46)
        membrane('Wing_web_%s_%d'%(suffix,i),[wrist,tips[i],e0,middle,e1,tips[i+1]],c)
    middle=wrist.lerp(tips[-1].lerp(flank,.5),.84)
    membrane('Wing_inner_web_'+suffix,[wrist,tips[-1],middle,flank],c)
    membrane('Wing_arm_web_'+suffix,[shoulder,elbow,wrist,flank],a)

# Continuous tapered tail, with the tip curling into a loose hooked loop.
tail_path=[(0,.91,1.53),(.04,1.34,1.33),(.29,1.84,1.16),(.70,2.23,1.13),
    (1.20,2.42,1.23),(1.70,2.40,1.43),(2.09,2.18,1.70),(2.34,1.84,1.94),
    (2.37,1.47,2.09),(2.18,1.20,2.12),(1.92,1.23,2.01),(1.82,1.47,1.88)]
tail_joints=[]
for i in range(len(tail_path)):
    name='tail_%02d'%i
    a=tail_path[i]; b=tail_path[min(i+1,len(tail_path)-1)]
    if i==len(tail_path)-1: b=Vector(a)+Vector((-.04,.08,-.04))
    bone(name,a,b,'hips' if i==0 else tail_joints[-1]); tail_joints.append(name)
tail_width=[.47,.39,.32,.265,.215,.17,.13,.10,.074,.053,.037,.012]
tail,frames=tube('Continuous_curled_tail',tail_path,tail_width,[w*.88 for w in tail_width],tail_joints,'body',.08)
for i in range(9):
    p=Vector(tail_path[i]); axis=frames[i][2]
    up=Vector((0,0,1)); up-=axis*up.dot(axis); up.normalize()
    base=p+up*(tail_width[i]*.43)
    spike('Tail_crest_%02d'%i,base,base+up*(.15-.012*i)+axis*.045,.09-.006*i,.07-.004*i,tail_joints[i],'horn')
for i,(y,z) in enumerate([(-1.12,2.36),(-.82,2.32),(-.42,2.16),(-.05,2.19),(.31,2.03),(.62,1.92)]):
    joint='neck_02' if i==0 else 'neck_01' if i==1 else 'chest' if i<4 else 'hips'
    spike('Dorsal_crest_%02d'%i,(0,y,z),(0,y+.09,z+.20),.12,.12,joint,'horn')

# Native 3 m from lowest claw to highest wing, with a small flight clearance.
coords=[v.co for o in parts for v in o.data.vertices]
low=min(v.z for v in coords); high=max(v.z for v in coords)
factor=3.0/(high-low)
def normalized(v): return Vector((v.x*factor,v.y*factor,(v.z-low)*factor+.25))
for obj in parts:
    for v in obj.data.vertices: v.co=normalized(v.co)
    obj.data.update()
pivots={name:(normalized(a),normalized(b),parent) if name!='root' else (a,b,parent)
        for name,(a,b,parent) in pivots.items()}

# Metric per-face UVs. Large coherent rectangular scale clusters, not speckled noise.
DENSITY=64; PAD=3; islands=[]
for obj in parts:
    obj.data.uv_layers.new(name='PixelUV')
    for face in obj.data.polygons:
        n=face.normal.normalized(); up=Vector((0,0,1)); up-=n*up.dot(n)
        if up.length<.001: up=Vector((0,1,0)); up-=n*up.dot(n)
        up.normalize(); right=up.cross(n).normalized()
        co=[Vector((obj.data.vertices[i].co.dot(right),obj.data.vertices[i].co.dot(up))) for i in face.vertices]
        lo=Vector((min(c.x for c in co),min(c.y for c in co))); co=[c-lo for c in co]
        islands.append(dict(obj=obj,face=face.index,coords=co,
            w=max(1,math.ceil(max(c.x for c in co)*DENSITY)),h=max(1,math.ceil(max(c.y for c in co)*DENSITY))))
def pack(size):
    x=y=PAD; row=0
    for it in sorted(islands,key=lambda d:(-d['h'],-d['w'])):
        w,h=it['w']+2*PAD,it['h']+2*PAD
        if x+w>size-PAD: x=PAD; y+=row; row=0
        if y+h>size-PAD: return False
        it.update(x=x+PAD,y=y+PAD); x+=w; row=max(row,h)
    return True
SIZE=next(s for s in (1024,2048) if pack(s))
palette={'body':(77,24,32),'scale':(94,32,41),'belly':(151,128,93),
    'ivory':(227,211,164),'horn':(31,22,27),'eye':(255,93,9),
    'dark':(15,10,16),'mouth':(42,8,16),'membrane':(107,36,41)}
pixels=np.ones((SIZE,SIZE,4),dtype=np.float32); pixels[:,:,:3]=0
emission=pixels.copy()
for index,it in enumerate(islands):
    w,h=it['w'],it['h']; kind=it['obj']['surface']; base=np.array(palette[kind],dtype=float)
    rng=np.random.default_rng(42117+index); yy,xx=np.indices((h,w))
    rgb=np.broadcast_to(base,(h,w,3)).copy(); energy=np.zeros((h,w,3))
    if kind in ('body','scale'):
        # Staggered dark seams and elongated, asymmetrical rectangular scales.
        sh=7; sw=11
        for ry in range(-1,math.ceil(h/sh)+1):
            shift=sw//2 if ry%2 else 0
            for rx in range(-1,math.ceil(w/sw)+1):
                x0=rx*sw+shift; y0=ry*sh
                shade=int(rng.choice([-12,-5,0,8,16]))
                x1=max(0,x0); x2=min(w,x0+sw); y1=max(0,y0); y2=min(h,y0+sh)
                if x2<=x1 or y2<=y1: continue
                rgb[y1:y2,x1:x2]=np.clip(base+shade,0,255)
                if 0<=y0<h: rgb[y0:y0+1,x1:x2]=base*.49
                if 0<=x0<w: rgb[y1:y2,x0:x0+1]=base*.57
                if 0<=y0+2<h:
                    rgb[y0+2:y0+3,max(0,x0+2):min(w,x0+8)]=np.clip(base+[21,9,10]+shade,0,255)
    elif kind=='membrane':
        broad=rng.integers(-9,10,(math.ceil(h/9),math.ceil(w/9))).repeat(9,0).repeat(9,1)[:h,:w]
        rgb=np.clip(base+broad[:,:,None],0,255)
        # Sparse stepped veins, and a slightly darkened leather border.
        mask=((xx+yy//3)%31<2)&(yy%17<12)
        rgb[mask]=base*.71
        edge=(xx<2)|(yy<2)|(xx>=w-2)|(yy>=h-2)
        rgb[edge]=base*.65
    elif kind=='belly':
        rgb[(yy%9<1)]=base*.72
        rgb[(yy%9==2)&(xx%14<10)]=base+[19,17,13]
    elif kind=='horn':
        rgb[(xx%7<2)&(yy%11<8)]=base+[22,12,13]
    elif kind=='eye':
        rgb[:]=base; rgb[(xx%6<2)]=(255,192,47); energy=rgb/255*1.7
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=rgb/255
    pixels[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD]=np.pad(tile,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    emission[it['y']-PAD:it['y']+h+PAD,it['x']-PAD:it['x']+w+PAD,:3]=np.pad(energy,((PAD,PAD),(PAD,PAD),(0,0)),mode='edge')
    face=it['obj'].data.polygons[it['face']]
    for li,c in zip(face.loop_indices,it['coords']):
        it['obj'].data.uv_layers.active.data[li].uv=((it['x']+c.x*DENSITY)/SIZE,(it['y']+c.y*DENSITY)/SIZE)

# Reuse the established packed-atlas / single-skinned-mesh export implementation.
start=helper_source.index('images=[]')
end=helper_source.index('\ndef aim(obj,point):',start)
exec(compile(helper_source[start:end],str(helper_path),'exec'),globals())

def aim(obj,point): obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new(STEM+'_World'); world.use_nodes=True; scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.19,.16,.14,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.55
for label,pos,power in [('Key',(-4,-6,7),1150),('Fill',(5,-3,5),700),('Rim',(0,5,6),1250)]:
    light=bpy.data.lights.new(STEM+'_'+label,'AREA'); light.energy=power; light.size=5
    obj=bpy.data.objects.new(light.name,light); scene.collection.objects.link(obj); obj.location=pos; aim(obj,(0,0,1.7))
camera_data=bpy.data.cameras.new(STEM+'_Camera'); camera_data.type='ORTHO'; camera_data.ortho_scale=5.0
camera=bpy.data.objects.new(camera_data.name,camera_data); scene.collection.objects.link(camera); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=1100; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
scene.render.film_transparent=False; scene.view_settings.view_transform='Standard'
scene.render.image_settings.file_format='PNG'; scene.frame_start=scene.frame_end=1
coords=[v.co for obj in parts for v in obj.data.vertices]
lo=[min(v[j] for v in coords) for j in range(3)]; hi=[max(v[j] for v in coords) for j in range(3)]
report={'name':'Dragao vermelho escuro','pipeline':'live Blender MCP','stem':STEM,
    'height_m':hi[2]-lo[2],'flight_clearance_m':lo[2],'size_m':[b-a for a,b in zip(lo,hi)],
    'editable_parts':len(parts),'triangles':triangles,'meshes':1,'materials':1,'atlas_size':SIZE,
    'prepared_bones':list(arm.bones.keys()),'animations':0,'four_legs':True,'wings':True,
    'pixel_density':DENSITY,'pixel_filter':'NEAREST','source_front':'Blender -Y / Godot +Z',
    'standalone_asset':True,'protected_glbs':len(protected),'reference':'User supplied western blocky dragon image'}
(OUT/(STEM+'_report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.app.driver_namespace[STEM]={'scene':scene,'rig':rig,'root':root,'parts':parts,'report':report,'images':images,'out':OUT}
for view,pos in [('three_quarter',(6,-10,5.2)),('front',(0,-10,3.1)),('side',(10,0,3.5)),('game_top',(5,-8,9))]:
    camera.location=pos; aim(camera,(.18,.04,1.73))
    scene.render.filepath=str(OUT/'previews'/(view+'.png')); bpy.ops.render.render(write_still=True)
camera.location=(6,-10,5.2); aim(camera,(.18,.04,1.73))
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=5.5
        area.spaces.active.region_3d.view_location=Vector((.15,0,1.7))
        area.spaces.active.region_3d.view_rotation=camera.rotation_euler.to_quaternion()
        area.spaces.active.region_3d.view_perspective='ORTHO'
        area.spaces.active.shading.type='MATERIAL'
for obj in scene.objects: obj.select_set(False)
rig.select_set(True); bpy.context.view_layer.objects.active=rig
bpy.data.libraries.write(str(OUT/(STEM+'.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
assert previous_scenes.issubset(set(bpy.data.scenes.keys()))
for p,digest in protected.items(): assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==digest,p
result=report
print(json.dumps(report))

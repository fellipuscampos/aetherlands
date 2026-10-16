"""Four editable civilian settlers, built from approved anatomy in Blender MCP.

No animation, no rig creation, no edits to any source asset. Run after
probe_settler_bases_mcp.py in the same open Blender.
"""
import bpy, bmesh, json, hashlib, math, numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/settlers_review'
PREFIX='Settlers_V1'
PROBE=json.loads((WORK/'source_probe.json').read_text(encoding='utf-8'))
SOURCES=bpy.app.driver_namespace['settler_source_scenes_v1']
FACES=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
BODY_NAMES=['Head','Chest','Belly','Pelvis']+[p+'_'+s for s in ('l','r') for p in ('Thigh','Shin','Foot','Shoulder','UpperArm','Forearm','Hand')]
PROFILE={
 'human':dict(folder='humans',name='Colonizador Humano',cloth=(63,96,146),linen=(206,191,151),pants=(84,78,63),skin=(203,155,113),hair=(76,53,34),leather=(112,74,44),wood=(130,97,57),blanket=(167,146,110),metal=(123,130,132),trim=(184,150,81)),
 'elf':dict(folder='elves',name='Colonizador Elfo',cloth=(69,111,79),linen=(194,193,153),pants=(93,107,80),skin=(237,221,209),hair=(216,190,124),leather=(119,92,56),wood=(135,113,69),blanket=(111,135,94),metal=(154,171,150),trim=(180,162,100)),
 'dwarf':dict(folder='dwarves',name='Colonizador Anão',cloth=(71,90,106),linen=(178,171,135),pants=(65,66,62),skin=(211,165,119),hair=(68,59,48),leather=(105,73,47),wood=(112,81,47),blanket=(135,74,52),metal=(97,108,116),trim=(177,118,64)),
 'orc':dict(folder='orcs',name='Colonizador Orc',cloth=(113,78,45),linen=(163,139,93),pants=(79,73,46),skin=(99,125,65),hair=(37,38,28),leather=(86,59,36),wood=(106,80,44),blanket=(91,102,66),metal=(101,106,87),trim=(164,150,107)),
}
SCENE=None; ROOT_OBJ=None; PARTS=[]; BODY={}; PRESERVED={}; RACE=None; P=None; FOLDER=None

def stage(value):
    (WORK/'current_stage.json').write_text(json.dumps(dict(race=RACE,stage=value)),encoding='utf-8')

def mesh(name,vertices,faces,region,bone='chest'):
    data=bpy.data.meshes.new(ROOT_OBJ.name+'_'+name+'_Mesh')
    data.from_pydata(vertices,[],faces); data.update()
    bm=bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.normal_update()
    assert all(e.is_manifold for e in bm.edges),name
    assert bm.calc_volume(signed=True)>0,name
    bm.to_mesh(data); bm.free()
    obj=bpy.data.objects.new(ROOT_OBJ.name+'_'+name,data); SCENE.collection.objects.link(obj)
    obj.parent=ROOT_OBJ; obj['part']=name; obj['surface']=region; obj['future_bone']=bone
    obj['settler_asset']=True
    for poly in data.polygons: poly.use_smooth=False
    PARTS.append(obj); return obj

def box(name,center,size,region,bone='chest'):
    center=Vector(center)
    return mesh(name,[center+Vector((sx*size[0]/2,sy*size[1]/2,sz*size[2]/2)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)],FACES,region,bone)

def beam(name,a,b,width,depth,region,bone='chest'):
    a,b=Vector(a),Vector(b); axis=(b-a).normalized()
    right=Vector((1,0,0)); right-=axis*right.dot(axis)
    if right.length<.001: right=Vector((0,1,0)); right-=axis*right.dot(axis)
    right.normalize(); forward=axis.cross(right).normalized()
    frame=Matrix((right,forward,axis)).transposed(); midpoint=(a+b)/2
    length=(b-a).length
    return mesh(name,[midpoint+frame@Vector((sx*width/2,sy*depth/2,sz*length/2)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)],FACES,region,bone)

def bounds(obj):
    pts=[v.co for v in obj.data.vertices]
    return Vector(tuple(min(v[i] for v in pts) for i in range(3))),Vector(tuple(max(v[i] for v in pts) for i in range(3)))

def center(obj): return sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)

def name_for(part):
    if not part.startswith('body_'): return part
    raw=part[5:]; names={'head':'Head','chest':'Chest','belly':'Belly','pelvis':'Pelvis','upper_arm':'UpperArm','forearm':'Forearm','shoulder':'Shoulder','thigh':'Thigh','shin':'Shin','foot':'Foot','hand':'Hand'}
    if raw in names: return names[raw]
    return names[raw[:-2]]+'_'+raw[-1].lower()

def region_for(part):
    if part=='Head': return 'skin'
    if part=='Chest': return 'cloth'
    if part=='Belly': return 'cloth' if RACE in ('elf','orc') else 'linen'
    if part.startswith(('Pelvis','Thigh')): return 'pants'
    if part.startswith(('Foot','Shin')): return 'leather'
    if part.startswith('Hand'): return 'skin'
    if part.startswith('UpperArm'): return 'skin' if RACE in ('orc','dwarf') else 'linen'
    if part.startswith('Forearm'): return 'skin'
    if part.startswith('Shoulder'): return 'cloth'
    if any(k in part.lower() for k in ['hair','beard','moustache','sideburn','brow']): return 'hair'
    if part.startswith('Tusk'): return 'ivory'
    return 'skin'

def image_pixels(image):
    pixels=np.empty(len(image.pixels),dtype=np.float32); image.pixels.foreach_get(pixels)
    return np.rint(pixels.reshape(image.size[1],image.size[0],4)*255).astype(np.uint8)

def clone_anatomy():
    src=SOURCES[RACE]; bpy.context.window.scene=src; bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    approved=[]; shared_images={}
    for original in src.objects:
        raw=original.get('part',''); part=name_for(raw) if raw.startswith('body_') else raw
        keep=part in BODY_NAMES or (RACE=='dwarf' and original.get('future_bone')=='head') or (RACE in ('elf','orc') and raw.startswith(('ElfEar','Tusk','Brow')))
        if original.type!='MESH' or not keep: continue
        evaluated=original.evaluated_get(deps)
        data=evaluated.to_mesh(preserve_all_data_layers=True,depsgraph=deps)
        verts=[evaluated.matrix_world@v.co for v in data.vertices]
        faces=[tuple(f.vertices) for f in data.polygons]
        obj=mesh(part,verts,faces,region_for(part),original.get('rig_bone',original.get('future_bone','head')))
        obj['anatomy_source']=PROBE[RACE]['path']; obj['source_part']=raw
        if part in BODY_NAMES: BODY[part]=obj
        approved.append(dict(part=part,source=raw,dimensions=[round(v,6) for v in bounds(obj)[1]-bounds(obj)[0]]))
        if part=='Head' or part.startswith(('ElfEar','Tusk','Brow')):
            material=original.data.materials[0]
            bsdf=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            node=next(l.from_node for l in bsdf.inputs['Base Color'].links)
            assert node.type=='TEX_IMAGE'
            if node.image not in shared_images: shared_images[node.image]=image_pixels(node.image)
            PRESERVED[obj.name]={'pixels':shared_images[node.image],
                'uvs':[[list(data.uv_layers.active.data[i].uv) for i in poly.loop_indices] for poly in data.polygons]}
        evaluated.to_mesh_clear()
    assert len(BODY)==18, (RACE,sorted(BODY))
    bpy.context.window.scene=SCENE; bpy.context.view_layer.update()
    return approved

def reframe(obj,new_center,axis):
    coords=np.array([list(v.co) for v in obj.data.vertices]); midpoint=coords.mean(axis=0)
    basis=np.stack([coords[i]-coords[0] for i in (1,2,4)],axis=1)
    basis/=np.linalg.norm(basis,axis=0)
    assert np.max(np.abs(basis.T@basis-np.eye(3)))<.0001,obj.name
    up=Vector(axis).normalized(); right=Vector((1,0,0)); right-=up*right.dot(up); right.normalize()
    frame=np.array(Matrix((right,up.cross(right),up)).transposed())
    updated=(coords-midpoint)@basis@frame.T+np.array(new_center)
    for vertex,value in zip(obj.data.vertices,updated): vertex.co=value
    obj.data.update()

def relaxed_pose():
    for side in ('l','r'):
        shoulder=BODY['Shoulder_'+side]; lo,hi=bounds(shoulder); c=center(shoulder)
        sign=1 if c.x>0 else -1
        anchor=Vector((c.x,c.y,lo.z+.013))
        direction=Vector((sign*.19,-.16,-1)).normalized()
        for name in ('UpperArm','Forearm','Hand'):
            obj=BODY[name+'_'+side]; vs=[v.co for v in obj.data.vertices]
            length=(vs[4]-vs[0]).length
            reframe(obj,anchor+direction*(length/2),-direction)
            anchor+=direction*(length-.003)
        BODY['Hand_'+side]['pose']='relaxed_travel_review'

def ring(name,c,w,d,h,region,bone='hips',thick=.021):
    x,y,z=c
    box(name+'_front',(x,y-d/2,z),(w,thick,h),region,bone)
    box(name+'_back',(x,y+d/2,z),(w,thick*.98,h*.99),region,bone)
    for s in (-1,1): box(name+'_side_'+str(s),(x+s*(w/2-thick/2),y,z),(thick,d-thick*1.05,h*.98),region,bone)

def bedroll(c,w,d,h,region='blanket'):
    # Stepped rectangular textile bundle, no cylinder / smooth tube.
    x,y,z=c
    box('Bedroll_main',(x,y,z),(w,d,h),region)
    box('Bedroll_fold',(x,y-d/2-.008,z-.006),(w*.90,.018,h*.68),region)
    for s in (-1,1):
        bx=x+s*w*.28
        for side in (-1,1):
            box('Bedroll_tie_face_'+str((s,side)),(bx,y+side*(d/2+.004),z),(.027,.018,h+.017),'leather')
            box('Bedroll_tie_cap_'+str((s,side)),(bx,y,z+side*(h/2+.004)),(.027,d-.011,.018),'leather')

def clothing_and_pack():
    chest_lo,chest_hi=bounds(BODY['Chest']); pel_lo,pel_hi=bounds(BODY['Pelvis'])
    head_lo,head_hi=bounds(BODY['Head']); width=chest_hi.x-chest_lo.x; cz=(chest_lo.z+chest_hi.z)/2
    waist=(pel_hi.z+pel_lo.z)/2; front=chest_lo.y; back=chest_hi.y
    belt_width=pel_hi.x-pel_lo.x+.026; belt_depth=pel_hi.y-pel_lo.y+.023
    ring('Travel_belt',(0,(pel_lo.y+pel_hi.y)/2,waist+.035),belt_width,belt_depth,.060,'leather')
    box('Belt_buckle',(0,pel_lo.y-.029,waist+.035),(.058,.020,.066),'trim','hips')
    box('Belt_pouch',(-belt_width*.36,pel_lo.y-.065,waist-.054),(width*.24,.099,.137),'leather','hips')
    box('Belt_pouch_flap',(-belt_width*.36,pel_lo.y-.119,waist-.012),(width*.25,.017,.054),'leather','hips')
    # Pack anchored against the upper back, straps actually pass over shoulders.
    pw=width*(.98 if RACE=='dwarf' else .83); pd=.20 if RACE!='orc' else .27
    ph=(.43 if RACE in ('human','elf') else .39 if RACE=='dwarf' else .50)
    py=back+pd/2-.012; pz=cz-.040
    pack_region='wicker' if RACE=='elf' else 'wood' if RACE=='dwarf' else 'leather'
    box('Backpack',(0,py,pz),(pw,pd,ph),pack_region)
    for s in (-1,1):
        x=s*pw*.34
        box('Pack_frame_'+str(s),(x,py+pd/2+.006,pz),(.031,.026,ph+.043),'wood' if RACE!='dwarf' else 'metal')
        box('Shoulder_strap_front_'+str(s),(s*width*.26,front-.008,cz+.020),(.033,.024,chest_hi.z-chest_lo.z-.004),'leather')
        beam('Shoulder_strap_over_'+str(s),(s*width*.26,front+.007,chest_hi.z+.012),(s*width*.26,py,pz+ph/2-.024),.035,.019,'leather')
    if RACE!='dwarf':
        box('Backpack_lid',(0,py+.006,pz+ph/2-.012),(pw+.028,pd+.022,.073),pack_region)
        box('Backpack_latch',(0,py+pd/2+.028,pz+ph*.27),(.045,.020,.130),'leather')
    else:
        for z in (pz-ph*.35,pz+ph*.35): box('Toolbox_rail_'+str(z),(0,py+pd/2+.023,z),(pw+.048,.026,.034),'metal')
        box('Toolbox_lid',(0,py,pz+ph/2+.006),(pw+.023,pd+.025,.037),'wood')
        box('Toolbox_latch',(0,py+pd/2+.03,pz+ph*.20),(.073,.025,.075),'trim')
    bedroll((0,py,pz+ph/2+.095),pw+.060,pd*.80,.13 if RACE!='orc' else .17)
    if RACE=='human':
        # Blue wool travel cap, linen shirt, short blue coat panels.
        box('Travel_cap_band',(0,-.009,head_hi.z+.016),(head_hi.x-head_lo.x+.017,.283,.034),'cloth','head')
        box('Travel_cap_crown',(-.019,.004,head_hi.z+.059),(.234,.251,.059),'cloth','head')
        box('Travel_cap_peak',(0,-.152,head_hi.z+.003),(.255,.083,.023),'cloth','head')
        for s in (-1,1): box('Coat_tail_'+str(s),(s*.106,pel_lo.y-.014,pel_lo.z-.034),(.153,.026,.133),'cloth','hips')
        box('Linen_shirt_front',(0,front-.012,cz+.016),(.078,.019,.249),'linen')
        box('Linen_collar',(0,front-.021,chest_hi.z-.020),(.181,.018,.031),'linen')
        for z in (cz-.050,cz+.011,cz+.072): box('Coat_button_'+str(z),(.055,front-.029,z),(.015,.012,.015),'trim')
        # Survey spade securely lashed to one side of the backpack.
        tx=-pw/2-.035
        beam('Spade_handle',(tx,py,pz-.25),(tx,py,pz+.42),.029,.030,'wood')
        box('Spade_blade',(tx,py-.016,pz-.22),(.111,.047,.145),'metal')
        box('Spade_socket',(tx,py-.026,pz-.12),(.047,.038,.107),'metal')
        box('Spade_grip',(tx,py,pz+.42),(.111,.042,.028),'wood')
        hand=center(BODY['Hand_l'])
        beam('Survey_scroll',hand+Vector((-.123,0,0)),hand+Vector((.123,0,0)),.059,.058,'parchment','hand_l')
        for s in (-1,1): box('Scroll_cap_'+str(s),hand+Vector((s*.132,0,0)),(.028,.067,.067),'wood','hand_l')
    elif RACE=='elf':
        box('Hair_crown',(0,.010,head_hi.z+.025),(.268,.263,.051),'hair','head')
        box('Hair_back',(0,head_hi.y+.012,head_hi.z-.111),(.230,.048,.276),'hair','head')
        box('Hair_tied_tail',(0,head_hi.y+.048,head_lo.z-.016),(.069,.060,.127),'hair','head')
        ring('Hair_tie',(0,head_hi.y+.048,head_lo.z+.019),.074,.065,.030,'trim','head',thick=.012)
        for s in (-1,1):
            box('Tunic_tail_'+str(s),(s*.107,pel_lo.y-.008,pel_lo.z-.071),(.155,.036,.198),'cloth','hips')
            box('Leaf_collar_'+str(s),(s*.058,front-.014,chest_hi.z-.023),(.071,.020,.048),'linen')
        box('Leaf_clasp',(0,front-.035,chest_hi.z-.055),(.034,.023,.044),'trim')
        for s in (-1,1):
            box('Pack_wicker_corner_'+str(s),(s*pw*.5,py+.008,pz),(.029,pd+.023,ph*.84),'wood')
        # Rectangular sapling/seed case; gives an agricultural travel silhouette.
        box('Seed_case',(pw/2+.045,py,pz-.074),(.119,.135,.229),'wood')
        ring('Seed_case_binding',(pw/2+.045,py,pz-.075),.126,.141,.049,'leather',thick=.012)
        hand=center(BODY['Hand_r']); sx=hand.x; sy=hand.y
        beam('Walking_staff',(sx,sy,.018),(sx,sy,hand.z+.379),.036,.037,'wood','hand_r')
        beam('Staff_crook',(sx,sy,hand.z+.35),(sx-.079,sy,hand.z+.425),.036,.037,'wood','hand_r')
        box('Staff_binding',(sx,sy,hand.z+.188),(.048,.047,.076),'linen','hand_r')
    elif RACE=='dwarf':
        box('Workshop_cap_band',(0,-.015,head_hi.z+.027),(.407,.369,.055),'cloth','head')
        box('Workshop_cap_crown',(0,.009,head_hi.z+.067),(.346,.324,.040),'cloth','head')
        box('Workshop_cap_peak',(0,-.207,head_hi.z+.011),(.309,.100,.024),'leather','head')
        for s in (-1,1):
            box('Apron_lobe_'+str(s),(s*.135,pel_lo.y-.024,waist-.065),(.227,.050,.263),'leather','hips')
            box('Apron_pocket_'+str(s),(s*.135,pel_lo.y-.055,waist-.054),(.131,.033,.114),'cloth','hips')
        # Iron pick strapped at the side, square construction lantern on the belt.
        tx=pw/2+.065
        beam('Pick_handle',(tx,py,pz-.224),(tx,py,pz+.41),.037,.039,'wood')
        beam('Pick_crossbar',(tx-.117,py,pz+.387),(tx+.117,py,pz+.387),.046,.044,'metal')
        beam('Pick_tip',(tx+.112,py,pz+.387),(tx+.176,py,pz+.315),.043,.038,'metal')
        lc=Vector((-.343,pel_lo.y-.055,waist-.118))
        box('Lantern_glass',lc,(.125,.102,.142),'glass','hips')
        for s in (-1,1):
            box('Lantern_stile_'+str(s),lc+Vector((s*.065,0,0)),(.021,.108,.164),'metal','hips')
        for dz in (-.082,.082): box('Lantern_cap_'+str(dz),lc+Vector((0,0,dz)),(.157,.120,.027),'trim','hips')
        beam('Lantern_hanger',lc+Vector((0,0,.080)),lc+Vector((0,.025,.177)),.027,.027,'metal','hips')
    else:
        # Loose hide shirt, exposed green arms, practical patched traveling kit.
        for s in (-1,1):
            box('Hide_coat_lobe_'+str(s),(s*.155,pel_lo.y-.019,pel_lo.z-.055),(.238,.041,.200),'leather','hips')
        box('Hide_coat_patch',(-.167,front-.026,cz-.054),(.132,.025,.117),'linen')
        box('Tunic_lacing',(0,front-.033,cz+.033),(.071,.029,.215),'leather')
        for z in (cz-.029,cz+.025,cz+.079): box('Tunic_lace_'+str(z),(0,front-.054,z),(.094,.019,.017),'linen')
        for s in (-1,1): box('Pack_rope_'+str(s),(s*pw*.27,py+pd/2+.022,pz),(.043,.034,ph+.040),'linen')
        box('Pack_hide_patch',(pw*.19,py+pd/2+.042,pz-.080),(.178,.025,.133),'blanket')
        # Coarse rope-lashed seed sack, stone working mallet (no armor / shield).
        box('Seed_sack',(-pw/2-.080,py,pz-.121),(.196,.193,.251),'linen')
        box('Sack_tie',(-pw/2-.080,py,pz+.014),(.084,.071,.060),'leather')
        hand=center(BODY['Hand_r'])
        beam('Mallet_handle',hand+Vector((0,0,-.13)),hand+Vector((0,0,.36)),.048,.049,'wood','hand_r')
        box('Mallet_stone_head',hand+Vector((0,0,.325)),(.282,.138,.137),'stone','hand_r')
        ring('Mallet_binding',hand+Vector((0,0,.325)),.065,.146,.112,'linen','hand_r',thick=.016)

def paint_tile(obj,face,w,h,points):
    region=obj['surface']; base=P.get(region)
    if base is None: base={'wicker':P['wood'],'parchment':(216,203,162),'ivory':(187,177,138),'stone':(112,117,102),'glass':(198,166,94)}[region]
    yy,xx=np.mgrid[:h,:w]; rng=np.random.default_rng(int(hashlib.sha256((RACE+obj['part']+str(face.index)).encode()).hexdigest()[:8],16))
    blocks=rng.choice([-7,-4,0,0,0,3,5],((h+1)//2,(w+1)//2))
    noise=np.repeat(np.repeat(blocks,2,axis=0),2,axis=1)[:h,:w]
    tile=np.clip(np.array(base)+noise[...,None],0,255).astype(np.int16)
    if obj.name in PRESERVED:
        # Resample the approved face art using its original corner UVs;
        # retain mirrored eyes, mouth, orc scalp and ear/tusk detail.
        source=PRESERVED[obj.name]; pixels=source['pixels']; uv=np.array(source['uvs'][face.index])
        coords=np.stack((xx,yy),axis=-1)/64
        pp=np.array([list(p) for p in points])
        basis=np.stack((pp[1]-pp[0],pp[-1]-pp[0]),axis=1)
        frac=(coords-pp[0])@np.linalg.inv(basis).T
        sampled=uv[0]+frac[...,0,None]*(uv[1]-uv[0])+frac[...,1,None]*(uv[-1]-uv[0])
        ix=np.clip(np.floor(sampled[...,0]*pixels.shape[1]).astype(int),0,pixels.shape[1]-1)
        iy=np.clip(np.floor(sampled[...,1]*pixels.shape[0]).astype(int),0,pixels.shape[0]-1)
        return pixels[iy,ix,:3]
    if region in ('cloth','linen','pants','blanket'):
        woven=(xx%4==0)&(yy%3==0); tile[woven]=np.array(base)-8
        if region=='blanket': tile[(yy%9)<2]=np.array(base)-24
    elif region=='wicker':
        tile[((xx//2+yy//2)%2)==0]=np.array(base)-18
        tile[(yy%5)==0]=np.array(base)+11
    elif region in ('wood','hair'):
        tile[(xx+yy//7)%5==0]=np.array(base)-13
        tile[(xx+yy//11)%9==0]=np.array(base)+10
    elif region=='leather':
        edge=np.minimum.reduce((xx,yy,w-1-xx,h-1-yy))
        tile[edge==0]=np.array(base)-22
        tile[(edge==2)&((xx+yy)%4==0)]=np.array(base)+27
    elif region in ('metal','trim'):
        tile[:,0]=np.clip(np.array(base)+24,0,255); tile[:,-1]=np.maximum(np.array(base)-21,0)
    elif region=='glass':
        tile[(xx//3)%3==0]=(217,185,111)
    elif region=='parchment':
        tile[(xx%11==0)&(yy>2)&(yy<h-3)]=(135,114,77)
    return np.clip(tile,0,255).astype(np.uint8)

def atlas():
    density=64; pad=3; islands=[]
    for obj in PARTS:
        obj.data.uv_layers.new(name='UVMap')
        for face in obj.data.polygons:
            n=face.normal; up=Vector((0,0,1)); up-=n*up.dot(n)
            if up.length<.01: up=Vector((0,1,0)); up-=n*up.dot(n)
            up.normalize(); right=up.cross(n).normalized()
            points=[Vector((obj.data.vertices[obj.data.loops[li].vertex_index].co.dot(right),obj.data.vertices[obj.data.loops[li].vertex_index].co.dot(up))) for li in face.loop_indices]
            low=Vector((min(p.x for p in points),min(p.y for p in points))); points=[p-low for p in points]
            w=math.ceil(max(p.x for p in points)*density)+1; h=math.ceil(max(p.y for p in points)*density)+1
            islands.append(dict(obj=obj,face=face,points=points,w=max(2,w),h=max(2,h)))
    islands.sort(key=lambda f:(-f['h'],-f['w'])); size=256
    while True:
        x=y=pad; rowh=0; fits=True
        for f in islands:
            if x+f['w']+pad>size: x=pad; y+=rowh+pad*2; rowh=0
            if y+f['h']+pad>size: fits=False; break
            f['x']=x; f['y']=y; x+=f['w']+pad*2; rowh=max(rowh,f['h'])
        if fits: break
        size*=2
    canvas=np.zeros((size,size,4),dtype=np.uint8); canvas[...,3]=255
    for f in islands:
        tile=paint_tile(f['obj'],f['face'],f['w'],f['h'],f['points'])
        rgba=np.concatenate((tile,np.full((*tile.shape[:2],1),255,dtype=np.uint8)),axis=-1)
        ox,oy=f['x'],f['y']; canvas[oy-pad:oy+f['h']+pad,ox-pad:ox+f['w']+pad]=np.pad(rgba,((pad,pad),(pad,pad),(0,0)),mode='edge')
        for li,p in zip(f['face'].loop_indices,f['points']): f['obj'].data.uv_layers.active.data[li].uv=((ox+.5+p.x*density)/size,(oy+.5+p.y*density)/size)
    image=bpy.data.images.new(ROOT_OBJ.name+'_albedo',width=size,height=size,alpha=False)
    image.pixels.foreach_set((canvas.astype(np.float32)/255).ravel()); image.file_format='PNG'
    image.filepath_raw=str(FOLDER/(ROOT_OBJ.name+'_albedo.png')); image.save(); image.pack()
    material=bpy.data.materials.new(ROOT_OBJ.name+'_Pixel_Material'); material.use_nodes=True; material.use_backface_culling=True
    bsdf=material.node_tree.nodes.get('Principled BSDF'); bsdf.inputs['Roughness'].default_value=.89; bsdf.inputs['Specular IOR Level'].default_value=.22
    texture=material.node_tree.nodes.new('ShaderNodeTexImage'); texture.image=image; texture.interpolation='Closest'
    material.node_tree.links.new(texture.outputs['Color'],bsdf.inputs['Base Color'])
    for obj in PARTS: obj.data.materials.append(material)
    return dict(size=[size,size],density_px_per_m=64,padding_px=3,face_islands=len(islands),materials=1,nearest=True,opaque=True)

def validation():
    bpy.context.view_layer.update(); points=[]; triangles=0; max_uv_error=0
    for obj in PARTS:
        bm=bmesh.new(); bm.from_mesh(obj.data)
        assert all(e.is_manifold for e in bm.edges),obj.name
        assert bm.calc_volume(signed=True)>0,obj.name
        assert all(f.calc_area()>1e-10 for f in bm.faces),obj.name
        bm.free(); triangles+=sum(len(f.vertices)-2 for f in obj.data.polygons)
        assert obj.animation_data is None and not obj.modifiers,obj.name
        assert obj.matrix_basis==Matrix.Identity(4),obj.name
        size=obj.data.materials[0].node_tree.nodes.get('Image Texture').image.size[0]
        uv=obj.data.uv_layers.active.data
        for poly in obj.data.polygons:
            assert not poly.use_smooth
            loops=list(poly.loop_indices)
            for a,b in zip(loops,loops[1:]+loops[:1]):
                v1=obj.data.vertices[obj.data.loops[a].vertex_index].co; v2=obj.data.vertices[obj.data.loops[b].vertex_index].co
                ratio=(uv[a].uv-uv[b].uv).length*size/(v1-v2).length
                max_uv_error=max(max_uv_error,abs(ratio-64))
        points.extend(v.co for v in obj.data.vertices)
        assert all(-.00001<=c<=1.00001 for loop in uv for c in loop.uv),obj.name
    assert max_uv_error<.005,max_uv_error
    low=[min(p[i] for p in points) for i in range(3)]; high=[max(p[i] for p in points) for i in range(3)]
    assert abs(low[2])<.00001,(RACE,low[2]); assert triangles<1600
    assert not any(o.type=='ARMATURE' for o in SCENE.objects)
    return dict(status='PASS',editable_parts=len(PARTS),body_parts=18,triangles=triangles,dimensions=[round(high[i]-low[i],6) for i in range(3)],bounds_min=low,bounds_max=high,closed_meshes=True,positive_volume=True,degenerate_faces=0,uv_density_max_error=max_uv_error,ground_pivot=True,identity_transforms=True,flat_shading=True,animations=0,rigs=0)

reports=[]; assets=[]
for race,profile in PROFILE.items():
    RACE=race; P=profile; PARTS=[]; BODY={}; PRESERVED={}
    stem=race+'_settler_v1'; FOLDER=ROOT/'assets/generated'/P['folder']/stem
    assert not (FOLDER/(stem+'.blend')).exists(),'Existing settler source would be overwritten'
    FOLDER.mkdir(parents=True,exist_ok=True); (FOLDER/'previews').mkdir(exist_ok=True)
    assert not bpy.data.scenes.get(PREFIX+'_'+race)
    SCENE=bpy.data.scenes.new(PREFIX+'_'+race); SCENE['settler_factory_owned']=True
    SCENE.unit_settings.system='METRIC'; SCENE.frame_start=1; SCENE.frame_end=1
    ROOT_OBJ=bpy.data.objects.new(stem,None); SCENE.collection.objects.link(ROOT_OBJ)
    ROOT_OBJ['race']=race; ROOT_OBJ['name_pt']=P['name']; ROOT_OBJ['asset_stage']='static_settler_review'; ROOT_OBJ['front']='minus_Y'; ROOT_OBJ['no_animations']=True
    stage('clone_anatomy'); source_sha=hashlib.sha256((ROOT/PROBE[race]['path']).read_bytes()).hexdigest()
    anatomy=clone_anatomy(); relaxed_pose(); clothing_and_pack(); stage('pixel_atlas')
    texture=atlas(); stage('validation'); geometry=validation()
    report=dict(stem=stem,name=P['name'],race=race,pipeline='Live Blender MCP localhost:9876',source=PROBE[race]['path'],source_sha256=source_sha,source_body=anatomy,geometry=geometry,texture=texture,static_review=True,animations=0,rigging_deferred=True)
    reports.append(report); assets.append(dict(scene=SCENE,root=ROOT_OBJ,parts=PARTS.copy(),folder=FOLDER,report=report))
    (FOLDER/(stem+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('SETTLER_MODELED',race,geometry['triangles'],len(PARTS),texture['size'])
bpy.app.driver_namespace['settlers_v1_assets']=assets
(WORK/'modeling_validation.json').write_text(json.dumps(dict(status='PASS',assets=reports),ensure_ascii=False,indent=2),encoding='utf-8')
stage('modeling_complete')

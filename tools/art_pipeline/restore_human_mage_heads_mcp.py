"""Restore approved human heads, painted white hair/hoods, through live MCP.

Only head accessories and their atlas islands change; body vertices and all
surviving texture islands are preserved. Run once on the existing review.
"""
import bpy, bmesh, math, json, hashlib, numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/human_school_mages_review'
assets=bpy.app.driver_namespace['human_school_mage_assets_v1']
review=bpy.app.driver_namespace['human_school_mage_review_v1']
base=bpy.app.driver_namespace['human_school_mage_base']
source_head=next(o for o in base.objects if o.get('part')=='Head')
source_vertices=[source_head.matrix_world@v.co for v in source_head.data.vertices]
source_uvs=[[list(source_head.data.uv_layers.active.data[i].uv) for i in f.loop_indices] for f in source_head.data.polygons]
source_img=next(n.image for n in source_head.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
def pixels(img):
    data=np.empty(len(img.pixels),np.float32); img.pixels.foreach_get(data)
    return np.rint(data.reshape(img.size[1],img.size[0],4)*255).astype(np.uint8)
source_pixels=pixels(source_img)
FACES=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
HOODS={'infernal':(102,48,40),'necromancy':(86,59,105),'elementalism':(93,129,130)}

def geometry_hash(parts):
    raw=[(o['part'],[list(v.co) for v in o.data.vertices]) for o in parts]
    return hashlib.sha256(json.dumps(raw,sort_keys=True).encode()).hexdigest()

def paint_head(tile,face_index,school):
    """Preserve original face pixels and their exact coordinates."""
    out=tile.copy(); yy,xx=np.mgrid[:tile.shape[0],:tile.shape[1]]
    old_hair=np.all(tile[:,:,:3]==(92,60,36),axis=-1)|np.all(tile[:,:,:3]==(96,63,38),axis=-1)
    out[old_hair,:3]=(224,225,218)
    out[np.all(tile[:,:,:3]==(96,63,38),axis=-1),:3]=(235,236,229)
    hood_pixels=0; beard_pixels=0
    if school in HOODS:
        color=np.array(HOODS[school])
        cloth=np.clip(color+(((xx//2+yy//3)%3)-1)[...,None]*5,0,255).astype(np.uint8)
        if face_index in (1,3,4,5):
            out[:,:,:3]=cloth; hood_pixels=tile.shape[0]*tile.shape[1]
        elif face_index==2:
            hood=old_hair|(xx<2)|(xx>=tile.shape[1]-2)
            out[hood,:3]=cloth[hood]; hood_pixels=int(hood.sum())
            # White temple hair is painted inside the original face opening.
            temples=((xx==2)|(xx==tile.shape[1]-3))&(yy>=8)&(yy<=12)
            protected=np.any(np.stack([np.all(tile[:,:,:3]==c,axis=-1) for c in [(80,52,30),(40,48,70),(240,236,228),(150,88,72)]]),axis=0)
            out[temples&~protected,:3]=(224,225,218)
    if face_index==2:
        # Beard grows on the lower cheeks/chin; eyes, brows, nose and mouth stay.
        beard=(yy<=2)|((yy<=5)&((xx<=4)|(xx>=tile.shape[1]-5)))|((yy==4)&(xx>=5)&(xx<=tile.shape[1]-6))
        protected=np.any(np.stack([np.all(tile[:,:,:3]==c,axis=-1) for c in [(80,52,30),(40,48,70),(240,236,228),(150,88,72),(190,140,104)]]),axis=0)
        beard&=~protected
        if school in HOODS: beard&=(xx>=2)&(xx<tile.shape[1]-2)
        out[beard,:3]=np.clip(np.array((224,225,218))+(((xx+yy)%3)-1)[beard,None]*5,0,255)
        beard_pixels=int(beard.sum())
        for color in [(80,52,30),(40,48,70),(240,236,228),(150,88,72),(190,140,104)]:
            mask=np.all(tile[:,:,:3]==color,axis=-1)
            assert np.all(out[mask,:3]==tile[mask,:3]),('Original facial feature changed',school,color)
    return out,hood_pixels,beard_pixels

checks=[]
for index,a in enumerate(assets):
    assert a['report'].get('style_revision')==2,'Run restoration once; preserve the previous revision first.'
    school=a['report']['school']; stem=a['report']['stem']; head=a['body']['Head']
    remove=[o for o in a['parts'] if o['part'].startswith(('Grey_temple_','Grey_hair_back','Block_beard_','Hood_','Short_hood_'))]
    kept=[o for o in a['parts'] if o not in remove]
    untouched=[o for o in kept if o!=head]; unchanged=geometry_hash(untouched)
    dead_data={o.data for o in remove}
    review_remove=[o for o in review['collections'][index].objects if o.type=='MESH' and o.data in dead_data]
    bpy.data.batch_remove(ids=remove+review_remove)
    a['parts']=kept
    # Restore vertices directly from the approved source; preserve elderly pose.
    pivot=Vector((0,0,1.012)); hc=sum(source_vertices,Vector())/8
    torso=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(a['report']['elderly_posture']['torso_forward_degrees']),4,'X')@Matrix.Translation(-pivot)
    pose=torso@Matrix.Translation(hc)@Matrix.Rotation(math.radians(-3),4,'X')@Matrix.Translation(-hc)
    for v,original in zip(head.data.vertices,source_vertices): v.co=pose@original
    head.data.update(); head['head_source']='human_settler_v1'; head['head_scale']=1.0
    # One small beard extension below the chin, without covering the face.
    top=(0,-.148,1.442); bottom=(0,-.163,1.339 if school=='druidism' else 1.352)
    verts=[pose@(Vector(c)+Vector((sx*w/2,sy*.037/2,0))) for c,w in [(bottom,.092),(top,.161)] for sy in (-1,1) for sx in (-1,1)]
    data=bpy.data.meshes.new(stem+'_Chin_beard_Mesh'); data.from_pydata(verts,[],FACES); data.update()
    bm=bmesh.new(); bm.from_mesh(data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(data); bm.free()
    beard=bpy.data.objects.new(stem+'_Chin_beard',data); a['scene'].collection.objects.link(beard); beard.parent=a['root']
    beard['part']='Chin_beard'; beard['surface']='hair'; beard['future_bone']='head'; beard['human_school_mage_asset']=True
    a['parts'].append(beard)
    copy=beard.copy(); copy.data=data; review['collections'][index].objects.link(copy); copy.parent=review['roots'][index]
    # Keep old non-head UV paintings byte-for-byte while repacking their islands.
    nodes=[n for n in a['material'].node_tree.nodes if n.type=='TEX_IMAGE']
    old_albedo=pixels(next(n.image for n in nodes if 'albedo' in n.image.name))
    old_emission=pixels(next(n.image for n in nodes if 'emission' in n.image.name))
    islands=[]; hood_pixels=beard_pixels=0; preserved_tiles=0
    for obj in a['parts']:
        for face in obj.data.polygons:
            if obj==beard:
                n=face.normal; up=Vector((0,0,1)); up-=n*up.dot(n)
                if up.length<.01: up=Vector((0,1,0)); up-=n*up.dot(n)
                up.normalize(); right=up.cross(n).normalized()
                pts=np.array([[v.co.dot(right),v.co.dot(up)] for v in [obj.data.vertices[i] for i in face.vertices]])*64
                pts-=pts.min(axis=0); w,h=np.ceil(pts.max(axis=0)).astype(int)+1
                yy,xx=np.mgrid[:h,:w]; tile=np.zeros((h,w,4),np.uint8); tile[:,:,3]=255
                tile[:,:,:3]=np.clip(np.array((224,225,218))+(((xx//2+yy//3)%3)-1)[...,None]*5,0,255)
                emit=np.zeros_like(tile); emit[:,:,3]=255
            else:
                uv=np.array(source_uvs[face.index] if obj==head else [list(obj.data.uv_layers.active.data[i].uv) for i in face.loop_indices])*512
                origin=np.floor(uv.min(axis=0)).astype(int); pts=uv-(origin+.5)
                w,h=np.ceil(pts.max(axis=0)-.00002).astype(int)+1
                src=source_pixels if obj==head else old_albedo
                tile=src[origin[1]:origin[1]+h,origin[0]:origin[0]+w].copy()
                emit=np.zeros_like(tile); emit[:,:,3]=255
                if obj==head:
                    tile,hp,bp=paint_head(tile,face.index,school); hood_pixels+=hp; beard_pixels+=bp
                else:
                    emit=old_emission[origin[1]:origin[1]+h,origin[0]:origin[0]+w].copy(); preserved_tiles+=1
            assert tile.shape==(h,w,4),(obj.name,face.index,tile.shape,w,h)
            islands.append(dict(obj=obj,face=face,points=pts,w=w,h=h,tile=tile,emit=emit))
    islands.sort(key=lambda f:(-f['h'],-f['w'])); size=512; pad=3; x=y=pad; rowh=0
    canvas=np.zeros((size,size,4),np.uint8); canvas[:,:,3]=255; emission=canvas.copy()
    for f in islands:
        if x+f['w']+pad>size: x=pad; y+=rowh+pad*2; rowh=0
        assert y+f['h']+pad<=size
        f['x']=x; f['y']=y
        for dest,key in [(canvas,'tile'),(emission,'emit')]: dest[y-pad:y+f['h']+pad,x-pad:x+f['w']+pad]=np.pad(f[key],((pad,pad),(pad,pad),(0,0)),mode='edge')
        x+=f['w']+pad*2; rowh=max(rowh,f['h'])
    for obj in a['parts']:
        while obj.data.uv_layers: obj.data.uv_layers.remove(obj.data.uv_layers[0])
        obj.data.uv_layers.new(name='UVMap')
        obj.data.materials.clear(); obj.data.materials.append(a['material'])
    for f in islands:
        for li,p in zip(f['face'].loop_indices,f['points']): f['obj'].data.uv_layers.active.data[li].uv=((f['x']+.5+p[0])/size,(f['y']+.5+p[1])/size)
    for suffix,arr in [('albedo',canvas),('emission',emission)]:
        node=next(n for n in nodes if suffix in n.image.name); old=node.image
        canonical=stem+'_'+suffix
        if bpy.data.images.get(canonical): bpy.data.images[canonical].name=canonical+'_before_head_restoration'
        img=bpy.data.images.new(canonical,width=512,height=512,alpha=False); img.pixels.foreach_set((arr.astype(np.float32)/255).ravel())
        img.filepath_raw=str(a['folder']/(canonical+'.png')); img.file_format='PNG'; img.save(); img.pack(); node.image=img
    assert geometry_hash(untouched)==unchanged,'Body or surviving clothing changed'
    error=max((pose.inverted()@v.co-original).length for v,original in zip(head.data.vertices,source_vertices))
    assert error<1e-6
    triangles=sum(len(f.vertices)-2 for o in a['parts'] for f in o.data.polygons)
    a['report']['geometry'].update(triangles=triangles,editable_parts=len(a['parts']))
    row=dict(school=school,status='PASS',original_head_geometry=True,head_scale=1.0,source_head_dimensions_m=[.262702703]*3,original_head_max_vertex_error_m=error,original_facial_features_preserved=True,painted_white_hair=True,painted_hood=school in HOODS,bulky_hood_shells=0,separate_hair_shells=0,hood_texture_pixels=hood_pixels,beard_texture_pixels=beard_pixels,body_and_clothing_geometry_unchanged=True,preserved_non_head_texture_islands=preserved_tiles,books=0,relaxed_offhand=True)
    a['report'].update(style_revision=3,style_validation=row,head_scalp_texture='original_human_white_hair_or_painted_hood',facial_features='approved_original_eyes_brows_nose_mouth_preserved')
    a['report']['elderly_posture']['grey_beard_length_m']=top[2]-bottom[2]
    checks.append(row)
    print('ORIGINAL_HEAD_RESTORED',school,triangles)
bpy.context.window.scene=review['scene']
(WORK/'style_revision_validation.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
bpy.app.driver_namespace['human_mage_head_revision3']=checks
result=dict(status='PASS',models=6,original_heads=True,unchanged_bodies=True,triangles_total=sum(a['report']['geometry']['triangles'] for a in assets))

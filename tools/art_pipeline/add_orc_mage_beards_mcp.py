"""Add modest grey beards to the six approved orcs, through live Blender MCP.

Existing head/body geometry, UV islands and paintings stay unchanged.
"""
import bpy,bmesh,ast,math,json,hashlib,shutil,numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo'); WORK=ROOT/'art_source/orc_school_mages_review'
assets=bpy.app.driver_namespace['orc_school_mage_assets_v1']
review=bpy.app.driver_namespace['orc_school_mage_review_v1']
backup=WORK/'before_beards'; assert not backup.exists(),'Preserve the previous approved models'
backup.mkdir()
for a in assets: shutil.copytree(a['folder'],backup/a['report']['stem'])
for p in WORK.iterdir():
    if p.is_file() and p.suffix in ('.blend','.png','.json','.html','.md'): shutil.copy2(p,backup/p.name)
FACES=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
ns=dict(bpy=bpy,bmesh=bmesh,np=np,hashlib=hashlib,Vector=Vector,FACES=FACES,RACE='orc',PRESERVED={})
source=(ROOT/'tools/art_pipeline/build_settlers_mcp.py').read_text(encoding='utf-8')
for n in ast.parse(source).body:
    if isinstance(n,ast.FunctionDef) and n.name in ('mesh','paint_tile'): exec(compile(ast.get_source_segment(source,n),'<approved_beard_geometry_and_pixels>','exec'),ns)
def geometry_hash(parts):
    data=[dict(part=o['part'],vertices=[list(v.co) for v in o.data.vertices],faces=[list(f.vertices) for f in o.data.polygons],uvs=[list(v.uv) for v in o.data.uv_layers.active.data]) for o in parts]
    return hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()

rows=[]
for index,a in enumerate(assets):
    report=a['report']; assert report['style_revision']==1
    old_parts=a['parts'].copy(); before=geometry_hash(old_parts)
    ns.update(SCENE=a['scene'],ROOT_OBJ=a['root'],PARTS=[],P={'hair':tuple(report['palette']['hair'])})
    bottom=1.522 if report['school']=='druidism' else 1.554
    # Beard starts below the mouth and tusk roots, tapering away from the collar.
    sections=[((0,-.249,bottom),(.113,.040)),((0,-.207,1.725),(.295,.063))]
    vertices=[a['head_pose']@(Vector(c)+Vector((sx*w/2,sy*d/2,0))) for c,(w,d) in sections for sy in (-1,1) for sx in (-1,1)]
    ns['mesh']('Orc_chin_beard',vertices,FACES,'hair','head')
    for sign in (-1,1):
        c=Vector((sign*.158,-.187,1.770)); dims=(.041,.034,.109)
        vertices=[a['head_pose']@(c+Vector((sx*dims[0]/2,sy*dims[1]/2,sz*dims[2]/2))) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
        ns['mesh']('Orc_cheek_beard_'+str(sign),vertices,FACES,'hair','head')
    added=ns['PARTS']; node=next(n for n in a['material'].node_tree.nodes if n.type=='TEX_IMAGE' and Path(n.image.filepath_raw).stem.endswith('_albedo'))
    old_image=node.image; pixels=np.rint(np.array(old_image.pixels[:]).reshape(512,512,4)*255).astype(np.uint8)
    old_pixels=pixels.copy(); occupied=np.zeros((512,512),dtype=bool)
    for obj in old_parts:
        uv=obj.data.uv_layers.active.data
        for f in obj.data.polygons:
            coords=np.array([list(uv[i].uv) for i in f.loop_indices])*512
            lo=np.floor(coords.min(axis=0)).astype(int); w,h=np.ceil(coords.max(axis=0)-lo-.5-.00002).astype(int)+1
            occupied[lo[1]-3:lo[1]+h+3,lo[0]-3:lo[0]+w+3]=True
    old_occupied=occupied.copy()
    emission_hash=hashlib.sha256((a['folder']/(report['stem']+'_emission.png')).read_bytes()).hexdigest()
    emission=next(n.image for n in a['material'].node_tree.nodes if n.type=='TEX_IMAGE' and Path(n.image.filepath_raw).stem.endswith('_emission'))
    emission_pixels=np.rint(np.array(emission.pixels[:]).reshape(512,512,4)*255).astype(np.uint8)
    islands=0
    for obj in added:
        obj.data.materials.append(a['material']); obj['orc_school_mage_asset']=True
        if 'settler_asset' in obj: del obj['settler_asset']
        uv=obj.data.uv_layers.new(name='UVMap')
        for f in obj.data.polygons:
            n=f.normal; up=Vector((0,0,1)); up-=n*up.dot(n)
            if up.length<.01: up=Vector((0,1,0)); up-=n*up.dot(n)
            up.normalize(); right=up.cross(n).normalized()
            pts=[Vector((obj.data.vertices[obj.data.loops[i].vertex_index].co.dot(right),obj.data.vertices[obj.data.loops[i].vertex_index].co.dot(up))) for i in f.loop_indices]
            low=Vector((min(p.x for p in pts),min(p.y for p in pts))); pts=[p-low for p in pts]
            w=max(2,math.ceil(max(p.x for p in pts)*64)+1); h=max(2,math.ceil(max(p.y for p in pts)*64)+1)
            rw,rh=w+6,h+6
            integral=np.pad(occupied.astype(np.int32),((1,0),(1,0))).cumsum(axis=0).cumsum(axis=1)
            sums=integral[rh:,rw:]-integral[:-rh,rw:]-integral[rh:,:-rw]+integral[:-rh,:-rw]
            locations=np.argwhere(sums==0); assert len(locations),'Beard islands must fit the existing atlas'
            y,x=map(int,locations[0]); assert not emission_pixels[y:y+rh,x:x+rw,:3].any()
            ox,oy=x+3,y+3
            tile=ns['paint_tile'](obj,f,w,h,pts)
            rgba=np.concatenate((tile,np.full((h,w,1),255,np.uint8)),axis=-1)
            pixels[y:y+rh,x:x+rw]=np.pad(rgba,((3,3),(3,3),(0,0)),mode='edge')
            occupied[y:y+rh,x:x+rw]=True
            for i,p in zip(f.loop_indices,pts): uv.data[i].uv=((ox+.5+p.x*64)/512,(oy+.5+p.y*64)/512)
            islands+=1
        copy=obj.copy(); review['collections'][index].objects.link(copy); copy.parent=review['roots'][index]
    assert np.array_equal(pixels[old_occupied],old_pixels[old_occupied])
    assert geometry_hash(old_parts)==before
    old_image.name=report['stem']+'_albedo_before_beards'
    image=bpy.data.images.new(report['stem']+'_albedo',width=512,height=512,alpha=False)
    image.colorspace_settings.name=old_image.colorspace_settings.name
    image.pixels.foreach_set((pixels.astype(np.float32)/255).ravel()); image.file_format='PNG'
    image.filepath_raw=str(a['folder']/(report['stem']+'_albedo.png')); image.save(); image.pack(); node.image=image
    assert image.packed_file.data==Path(image.filepath_raw).read_bytes()
    assert hashlib.sha256((a['folder']/(report['stem']+'_emission.png')).read_bytes()).hexdigest()==emission_hash
    a['parts'].extend(added)
    sat=bpy.app.driver_namespace['orc_school_mage_sat_v1']
    tusks=[o for o in old_parts if o['part'].startswith('Tusk')]
    assert all(not sat(beard,tusk) for beard in added for tusk in tusks),'Keep tusks clear of beard'
    assert all(sat(beard,a['body']['Head']) for beard in added),'Beard must attach to the original jaw'
    report['style_revision']=2
    report['style_validation'].update(orc_beard=True,beard_parts=3,beard_color=list(report['palette']['hair']),beard_tusks_clear=True,beard_attached_to_jaw=True)
    report['geometry'].update(editable_parts=len(a['parts']),triangles=sum(len(f.vertices)-2 for o in a['parts'] for f in o.data.polygons))
    row=dict(school=report['school'],status='PASS',beard_parts=3,beard_triangles=36,new_uv_islands=islands,old_geometry_and_uvs_unchanged=True,old_geometry_uv_sha256=before,old_atlas_islands_unchanged=True,emission_unchanged=True,tusks_clear=True,attached_to_jaw=True)
    report['beard_validation']=row; rows.append(row)
    print('ORC_BEARD',report['school'],'3 parts, 36 triangles, original head and face unchanged')
output=dict(status='PASS',models=6,backup=backup.relative_to(ROOT).as_posix(),assets=rows)
(WORK/'beard_validation.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
(ROOT/'docs/orc_school_mages_beard_validation.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
bpy.context.window.scene=review['scene']
result=dict(status='PASS',models=6,beard_parts=18,added_triangles=216,original_geometry_and_face_paintings_unchanged=True)

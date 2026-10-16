"""Apply human school robe colors to approved elves through live Blender MCP.

Geometry, UVs, faces, ears, staff shapes and emission remain unchanged.
"""
import ast, bpy, hashlib, json, math, shutil
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/elf_school_mages_review'
assets=bpy.app.driver_namespace['elf_school_mage_assets_v1']
backup=WORK/'before_school_colors'
assert not backup.exists(), 'Preserve the first approved green version'
backup.mkdir()
for a in assets:
    shutil.copytree(a['folder'],backup/a['report']['stem'])
for p in WORK.iterdir():
    if p.is_file() and p.suffix in ('.blend','.png','.json','.html','.md'):
        shutil.copy2(p,backup/p.name)

source=(ROOT/'tools/art_pipeline/build_human_school_mages_mcp.py').read_text(encoding='utf-8')
recipe_node=next(n for n in ast.parse(source).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='SCHOOLS' for t in n.targets))
recipe_ns={}
exec(compile(ast.Module(body=[recipe_node],type_ignores=[]),'<approved_school_palettes>','exec'),recipe_ns)
recipes=recipe_ns['SCHOOLS']
human={p['school']:p for p in recipes}
base=bpy.app.driver_namespace['elf_school_mage_base']
original=next(o for o in base.objects if o.get('part')=='Head')
source_image=next(n.image for n in original.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
source_pixels=np.rint(np.array(source_image.pixels[:]).reshape(512,512,4)*255).astype(np.uint8)
source_uvs=[[list(original.data.uv_layers.active.data[i].uv) for i in f.loop_indices] for f in original.data.polygons]
ns=dict(np=np,hashlib=hashlib,RACE='elf',PRESERVED={})
source=(ROOT/'tools/art_pipeline/build_settlers_mcp.py').read_text(encoding='utf-8')
for n in ast.parse(source).body:
    if isinstance(n,ast.FunctionDef) and n.name=='paint_tile':
        exec(compile(ast.get_source_segment(source,n),'<approved_pixel_art>','exec'),ns)
head_ns=dict(np=np,HOODS={s:human[s]['linen'] for s in ('infernal','necromancy')})
source=(ROOT/'tools/art_pipeline/build_elf_school_mages_mcp.py').read_text(encoding='utf-8')
for n in ast.parse(source).body:
    if isinstance(n,ast.FunctionDef) and n.name=='paint_head':
        exec(compile(ast.get_source_segment(source,n),'<approved_head_paint>','exec'),head_ns)

def shape_hash(parts):
    data=[dict(part=o['part'],vertices=[list(v.co) for v in o.data.vertices],faces=[list(f.vertices) for f in o.data.polygons],uvs=[list(v.uv) for v in o.data.uv_layers.active.data],matrix=[list(v) for v in o.matrix_basis]) for o in parts]
    return hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest()

checks=[]
for a in assets:
    report=a['report']; school=report['school']; stem=report['stem']
    assert report['style_revision']==1
    before=shape_hash(a['parts'])
    palette=dict(report['palette']); palette.update(cloth=human[school]['cloth'],linen=human[school]['linen'])
    ns['P']=palette
    node=next(n for n in a['material'].node_tree.nodes if n.type=='TEX_IMAGE' and Path(n.image.filepath_raw).stem.endswith('_albedo'))
    old=node.image
    canvas=np.rint(np.array(old.pixels[:]).reshape(512,512,4)*255).astype(np.uint8)
    emission_hash=hashlib.sha256((a['folder']/(stem+'_emission.png')).read_bytes()).hexdigest()
    changed=[]
    for o in a['parts']:
        green=o['part'].startswith(('Leaf_hem_','Elven_collar_','Arcane_leaf_rune_')) or o['part']=='Hat_leaf_badge'
        if green: o['surface']='elf_green'
        is_head=o['part']=='Head' and school in head_ns['HOODS']
        if not (green or o['surface'] in ('cloth','linen') or is_head): continue
        changed.append(o['part'])
        ns['PRESERVED']={o.name:dict(pixels=source_pixels,uvs=source_uvs)} if is_head else {}
        for f in o.data.polygons:
            normal=f.normal; up=Vector((0,0,1)); up-=normal*up.dot(normal)
            if up.length<.01: up=Vector((0,1,0)); up-=normal*up.dot(normal)
            up.normalize(); right=up.cross(normal).normalized()
            pts=[Vector((o.data.vertices[o.data.loops[i].vertex_index].co.dot(right),o.data.vertices[o.data.loops[i].vertex_index].co.dot(up))) for i in f.loop_indices]
            lo=Vector((min(p.x for p in pts),min(p.y for p in pts))); pts=[p-lo for p in pts]
            w=max(2,math.ceil(max(p.x for p in pts)*64)+1); h=max(2,math.ceil(max(p.y for p in pts)*64)+1)
            uv=np.array([list(o.data.uv_layers.active.data[i].uv) for i in f.loop_indices])*512
            x,y=np.floor(uv.min(axis=0)).astype(int)
            sampled=ns['paint_tile'](o,f,w,h,pts)
            rgba=np.concatenate((sampled,np.full((h,w,1),255,np.uint8)),axis=-1)
            if is_head: rgba=head_ns['paint_head'](rgba,f.index,school)[0]
            canvas[y-3:y+h+3,x-3:x+w+3]=np.pad(rgba,((3,3),(3,3),(0,0)),mode='edge')
    old.name=stem+'_albedo_before_school_colors'
    image=bpy.data.images.new(stem+'_albedo',width=512,height=512,alpha=False)
    image.pixels.foreach_set((canvas.astype(np.float32)/255).ravel())
    image.file_format='PNG'; image.filepath_raw=str(a['folder']/(stem+'_albedo.png'))
    image.save(); image.pack(); node.image=image
    assert image.packed_file.data==Path(image.filepath_raw).read_bytes()
    assert shape_hash(a['parts'])==before
    assert hashlib.sha256((a['folder']/(stem+'_emission.png')).read_bytes()).hexdigest()==emission_hash
    report['palette'].update(cloth=list(palette['cloth']),linen=list(palette['linen']))
    report['style_revision']=2
    report['school_color_validation']=dict(status='PASS',human_school_cloth=list(palette['cloth']),human_school_linen=list(palette['linen']),green_elven_details=list(palette['elf_green']),geometry_and_uvs_unchanged=True,geometry_uv_sha256=before,emission_unchanged=True,changed_parts=changed)
    checks.append(dict(school=school,**report['school_color_validation']))
    print('ELF_SCHOOL_COLORS',school,len(changed),'geometry and UVs unchanged')
output=dict(status='PASS',models=6,backup=backup.relative_to(ROOT).as_posix(),assets=checks)
(WORK/'school_color_validation.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
(ROOT/'docs/elf_school_mages_color_validation.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
result=dict(status='PASS',models=6,geometry_and_uvs_unchanged=True,emission_unchanged=True)

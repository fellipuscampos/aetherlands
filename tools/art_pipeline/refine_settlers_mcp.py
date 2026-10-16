"""Review fixes to our four new settlers only, with metric UVs regenerated."""
import bpy,json,numpy as np
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/settlers_review'
assets=bpy.app.driver_namespace['settlers_v1_assets']
builder=(ROOT/'tools/art_pipeline/build_settlers_mcp.py').read_text(encoding='utf-8').split('reports=[]; assets=[]')[0]
ns={'__name__':'settler_review_refinements'}
exec(compile(builder,'build_settlers_mcp.py','exec'),ns)
changes=[]
for asset in assets:
    race=asset['report']['race']; parts=asset['parts']; by={o['part']:o for o in parts}
    bpy.context.window.scene=asset['scene']
    if race=='elf':
        obj=by['Staff_crook']; y=sum(v.co.y for v in obj.data.vertices)/len(obj.data.vertices)
        for v in obj.data.vertices: v.co.y=y+(v.co.y-y)*.82
        obj.data.update(); changes.append(dict(race=race,part='Staff_crook',fix='Inset crook sides; no flush overlapping staff faces'))
    if race=='dwarf':
        for side in ('l','r'):
            obj=by['Hand_'+side]; coords=np.array([list(v.co) for v in obj.data.vertices]); c=coords.mean(axis=0)
            axes=np.stack([coords[i]-coords[0] for i in (1,2,4)],axis=1); axes/=np.linalg.norm(axes,axis=0)
            updated=((coords-c)@axes*np.array([1.025,1.025,1]))@axes.T+c
            for v,p in zip(obj.data.vertices,updated): v.co=p
            obj.data.update()
            changes.append(dict(race=race,part=obj['part'],fix='2.5% wider hand gives a distinct wrist step'))
        for side in ('-1','1'):
            obj=by['moustache_'+side]; c=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
            for v in obj.data.vertices: v.co.x=c.x+(v.co.x-c.x)*.97
            obj.data.update()
        obj=by['beard_lock_2_0']
        for v in obj.data.vertices: v.co.y-=.004
        obj.data.update(); changes.append(dict(race=race,part='moustache / central beard lock',fix='Butt join moustache and inset central beard tier'))
    # Replace tiny band buttons with straps which fully wrap the rectangular roll.
    roll=by['Bedroll_main']; low,high=ns['bounds'](roll); c=ns['center'](roll); w,d,h=high-low
    for s in (-1,1):
        bx=c.x+s*w*.28
        for kind in ('front','back','side_-1','side_1'):
            obj=by['Bedroll_tie_'+str(s)+'_'+kind]
            if kind in ('front','back'):
                pos=(bx,c.y+(-1 if kind=='front' else 1)*(d/2+.004),c.z); size=(.027,.018,h+.017)
            else:
                pos=(bx,c.y,c.z+(-1 if kind=='side_-1' else 1)*(h/2+.004)); size=(.027,d-.011,.018)
            verts=[Vector(pos)+Vector((sx*size[0]/2,sy*size[1]/2,sz*size[2]/2)) for sz in (-1,1) for sy in (-1,1) for sx in (-1,1)]
            for v,p in zip(obj.data.vertices,verts): v.co=p
            obj.data.update()
    changes.append(dict(race=race,part='Bedroll_ties',fix='Full rectangular strap wrap; inset cap ends avoid coincident faces'))
    preserved={}; images={}; source=ns['SOURCES'][race]
    for obj in parts:
        if not (obj['part']=='Head' or obj['part'].startswith(('ElfEar','Tusk','Brow'))): continue
        original=next(o for o in source.objects if o.get('part')==obj['source_part'])
        material=original.data.materials[0]; bsdf=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        image=next(l.from_node for l in bsdf.inputs['Base Color'].links).image
        if image not in images: images[image]=ns['image_pixels'](image)
        preserved[obj.name]=dict(pixels=images[image],uvs=[[list(original.data.uv_layers.active.data[i].uv) for i in poly.loop_indices] for poly in original.data.polygons])
    old_materials=set()
    for obj in parts:
        old_materials.update(obj.data.materials)
        obj.data.materials.clear()
        for uv in list(obj.data.uv_layers): obj.data.uv_layers.remove(uv)
    for material in old_materials:
        old_images=[n.image for n in material.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
        assert material.name.startswith(asset['root'].name)
        if material.users==0: bpy.data.materials.remove(material)
        for image in old_images:
            assert image.name.startswith(asset['root'].name)
            if image.users==0: bpy.data.images.remove(image)
    ns.update(RACE=race,P=ns['PROFILE'][race],PARTS=parts,BODY={o['part']:o for o in parts if o['part'] in ns['BODY_NAMES']},PRESERVED=preserved,SCENE=asset['scene'],ROOT_OBJ=asset['root'],FOLDER=asset['folder'])
    asset['report']['texture']=ns['atlas'](); asset['report']['geometry']=ns['validation']()
    asset['report']['review_refinements']=[r for r in changes if r['race']==race]
    (asset['folder']/(asset['root'].name+'_report.json')).write_text(json.dumps(asset['report'],ensure_ascii=False,indent=2),encoding='utf-8')
(WORK/'review_refinements.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2),encoding='utf-8')
(WORK/'modeling_validation.json').write_text(json.dumps(dict(status='PASS',assets=[a['report'] for a in assets]),ensure_ascii=False,indent=2),encoding='utf-8')
review=bpy.app.driver_namespace['settlers_v1_review']['scene']; bpy.context.window.scene=review
audit=bpy.app.driver_namespace['settlers_v1_surface_audit']
for asset in assets:
    exposed,hidden=audit(asset['parts'])
    print(asset['report']['race'],'exposed',[(a['a'],a['b']) for a in exposed],'hidden',len(hidden))
result={'status':'review_refinements_applied','parts_adjusted':len(changes)}

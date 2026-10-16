"""Remove applied garment ornaments from approved elves in live Blender MCP."""
import bpy,json,hashlib,shutil
from pathlib import Path
ROOT=Path(r'C:/Users/felipe campos/Documents/jogo')
WORK=ROOT/'art_source/elf_school_mages_review'
assets=bpy.app.driver_namespace['elf_school_mage_assets_v1']
review=bpy.app.driver_namespace['elf_school_mage_review_v1']
backup=WORK/'before_clothing_cleanup'
assert not backup.exists(), 'Preserve the approved school-color version'
backup.mkdir()
for a in assets: shutil.copytree(a['folder'],backup/a['report']['stem'])
for p in WORK.iterdir():
    if p.is_file() and p.suffix in ('.blend','.png','.json','.html','.md'): shutil.copy2(p,backup/p.name)

prefixes=('Leaf_hem_','Ivory_leaf_stole_','Gold_stole_leaf_','Copper_ash_leaf_',
          'Silver_funeral_chain_','Ash_leaf_talisman_','Leaf_shoulder_mantle_',
          'Pouch_herb_','Silver_vine_stole_','Arcane_leaf_rune_','Element_leaf_clasp_')
exact={'Leaf_belt_clasp','Leaf_chest_clasp','Emberwood_sash','Violet_memory_gem'}
def unwanted(name): return name in exact or name.startswith(prefixes)
def shape(o):
    return dict(vertices=[list(v.co) for v in o.data.vertices],faces=[list(f.vertices) for f in o.data.polygons],uvs=[list(v.uv) for v in o.data.uv_layers.active.data],matrix=[list(v) for v in o.matrix_basis])
rows=[]
for index,a in enumerate(assets):
    report=a['report']; assert report['style_revision']==2
    removed=[o for o in a['parts'] if unwanted(o['part'])]
    names=[o['part'] for o in removed]; assert len(removed)>=7
    kept=[o for o in a['parts'] if not unwanted(o['part'])]
    snapshots={o['part']:shape(o) for o in kept}
    atlas_hashes={suffix:hashlib.sha256((a['folder']/(report['stem']+'_'+suffix+'.png')).read_bytes()).hexdigest() for suffix in ('albedo','emission')}
    preview_removed=[o for o in review['collections'][index].objects if o.type=='MESH' and unwanted(o.get('part',''))]
    assert len(preview_removed)==len(removed)
    bpy.data.batch_remove(ids=removed+preview_removed)
    a['parts']=kept
    assert all(shape(o)==snapshots[o['part']] for o in kept)
    assert all(o in kept for o in a['body'].values()) and a['staff'] in kept
    assert all(hashlib.sha256((a['folder']/(report['stem']+'_'+s+'.png')).read_bytes()).hexdigest()==h for s,h in atlas_hashes.items())
    triangles=sum(len(f.vertices)-2 for o in kept for f in o.data.polygons)
    old_triangles=report['geometry']['triangles']
    report['geometry'].update(editable_parts=len(kept),triangles=triangles)
    report['style_revision']=3
    report['clothing_cleanup']=dict(status='PASS',removed_parts=names,triangles_before=old_triangles,triangles_after=triangles,surviving_geometry_and_uvs_unchanged=True,school_colors_preserved=True,atlas_hashes=atlas_hashes,heads_and_staves_preserved=True,green_details='plain collars and belt weave')
    report['school_color_validation']={k:v for k,v in report['school_color_validation'].items() if k in ('status','human_school_cloth','human_school_linen','green_elven_details','emission_unchanged')}
    rows.append(dict(school=report['school'],**report['clothing_cleanup']))
    print('CLOTHING_CLEANUP',report['school'],len(names),'ornaments removed',old_triangles,'->',triangles)
output=dict(status='PASS',models=6,backup=backup.relative_to(ROOT).as_posix(),assets=rows)
(WORK/'clothing_cleanup_validation.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
(ROOT/'docs/elf_school_mages_clothing_validation.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
color=dict(status='PASS',models=6,style_revision=3,assets=[dict(school=a['report']['school'],**a['report']['school_color_validation']) for a in assets])
(ROOT/'docs/elf_school_mages_color_validation.json').write_text(json.dumps(color,indent=2),encoding='utf-8')
(WORK/'school_color_validation.json').write_text(json.dumps(color,indent=2),encoding='utf-8')
bpy.context.window.scene=review['scene']
result=dict(status='PASS',models=6,ornaments_removed=sum(len(r['removed_parts']) for r in rows),triangles=[r['triangles_after'] for r in rows])

"""A single editable Blender scene containing the twelve finished lairs at their native scale."""
import bpy
import json
import importlib.util
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
OUT=ROOT/'assets/generated/monster_lairs_v1'
spec=importlib.util.spec_from_file_location('lair_catalog_tools',ROOT/'art_source/monster_lairs_v1/build_lairs.py')
module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
rows=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
original=bpy.context.window.scene
before=set(bpy.data.scenes)
catalog=bpy.data.scenes.new('Monster_Lairs_V1_Catalog')

def label(name,text,position,size,color):
    curve=bpy.data.curves.new(name,'FONT'); curve.body=text; curve.align_x='CENTER'; curve.size=size
    obj=bpy.data.objects.new(name,curve); catalog.collection.objects.link(obj); obj.location=position
    mat=bpy.data.materials.get('Catalog_label_'+color)
    if not mat:
        mat=bpy.data.materials.new('Catalog_label_'+color); mat.use_nodes=True
        c={'gold':(.82,.65,.38,1),'white':(.68,.78,.82,1)}[color]
        mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=c
        mat.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value=c
        mat.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value=.30
    curve.materials.append(mat)
    return obj

try:
    bpy.context.window.scene=catalog
    for i,row in enumerate(rows):
        stem=row['stem']; source_path=OUT/stem/(stem+'.blend')
        with bpy.data.libraries.load(str(source_path),link=False) as (src,dst): dst.scenes=src.scenes
        source=dst.scenes[0]; source_objects=list(source.objects)
        group=bpy.data.collections.new(row['kind']); catalog.collection.children.link(group)
        root=bpy.data.objects.new(row['name'],None); group.objects.link(root)
        x=(i%4-1.5)*2.05; y=(i//4-1)*2.25
        root.location=(x,y,0); root['monster_kind']=row['kind']
        count=0
        for obj in source.objects:
            if obj.type=='MESH' and not obj.name.startswith('STUDIO'):
                copy=obj.copy(); copy.parent=root; group.objects.link(copy); count+=1
        assert count==row['editable_parts']
        label(stem+'_label',row['kind'],(x,y-.95,.002),.105,'white')
        bpy.data.scenes.remove(source)
        for obj in source_objects:
            if obj.users==0: bpy.data.objects.remove(obj)
    for i,tier in enumerate(('BASICOS','INTERMEDIARIOS','AVANCADOS')):
        label('Tier_'+tier,tier,(0,(i-1)*2.25+.99,.005),.17,'gold')
    cam=module.studio(catalog,'CATALOG')
    cam.location=(5.3,-10.2,13.5); cam.data.ortho_scale=10.9
    cam.rotation_euler=(Vector((0,0,.1))-cam.location).to_track_quat('-Z','Y').to_euler()
    catalog.render.resolution_x=1600; catalog.render.resolution_y=1250
    catalog['description']='12 covis, escala nativa 1:1, agrupados por especie. Apenas arte.'
    catalog['original_source_files']='Cada subpasta contem a fonte isolada e o GLB.'
    bpy.data.libraries.write(str(OUT/'monster_lairs_v1_catalog.blend'),{catalog},path_remap='RELATIVE',fake_user=True,compress=True)
    result=dict(status='PASS',models=len(rows),scene=catalog.name,file=str(OUT/'monster_lairs_v1_catalog.blend'))
finally:
    bpy.context.window.scene=original
    assert before.issubset(set(bpy.data.scenes))

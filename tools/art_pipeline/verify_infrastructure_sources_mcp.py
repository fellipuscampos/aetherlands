"""Validate the editable sources in the live Blender editor."""
import bpy
import hashlib
import json
from pathlib import Path

ROOT=Path(r'C:\Users\felipe campos\Documents\jogo')
entries=json.loads((ROOT/'art_source/infrastructure_buildings_review/completed.json').read_text(encoding='utf-8'))
assert len(entries)==20
plurals={'human':'humans','elf':'elves','dwarf':'dwarves','orc':'orcs'}
roof_colors={'human':[49,79,127],'elf':[48,122,88],'dwarf':[67,82,89],'orc':[130,58,39]}
verified=[]
for entry in entries:
    folder=entry['asset']; out=ROOT/'assets/generated'/plurals[entry['civilization']]/'buildings'/folder
    report=json.loads((out/(folder+'_report.json')).read_text(encoding='utf-8'))
    scene=bpy.data.scenes[report['name']]
    assert scene['infrastructure_only_version']
    assert list(scene['palette_overrides']['roof'])==roof_colors[entry['civilization']]
    parts=[o for o in scene.objects if o.type=='MESH' and o.get('part') and o.get('region')!='studio']
    assert len(parts)==report['editable_parts']
    by_part={o['part']:o for o in parts}
    contact_pairs={
        ('human','workshop'):[('Finished_Wheel_Wheel','Finished_Wheel_Axle'),('Finished_Wheel_Axle','Finished_Wheel_Rack_Post'),('Finished_Wheel_Rack_Post','Finished_Wheel_Rack_Foot')],
        ('dwarf','farm'):[('Pump_Wheel_Wheel','Pump_Axle'),('Pump_Axle','Pump_Post_Shaft')],
        ('dwarf','workshop'):[('Press_Gear_Wheel','Press_Gear_Axle'),('Press_Gear_Axle','Press_Gear_Bearing_Shaft')],
        ('dwarf','arcane_shrine'):[('Mana_Regulator_Wheel','Mana_Regulator_Axle'),('Mana_Regulator_Hub','Mana_Regulator_Axle'),('Mana_Regulator_Axle','Regulator_Bearing'),('Regulator_Bearing','Regulator_Base')],
    }.get((entry['civilization'],entry['role']),[])
    for a,b in contact_pairs:
        first,second=by_part[a],by_part[b]
        assert all(min(v.co[axis] for v in first.data.vertices)<=max(v.co[axis] for v in second.data.vertices)+.0001 and min(v.co[axis] for v in second.data.vertices)<=max(v.co[axis] for v in first.data.vertices)+.0001 for axis in range(3)),(folder,'disconnected mechanism',a,b)
    triangles=0
    for obj in parts:
        assert not obj.modifiers and obj.location.length<1e-7 and all(abs(s-1)<1e-7 for s in obj.scale)
        assert obj.data.uv_layers.active and len(obj.data.uv_layers.active.data)==len(obj.data.loops)
        obj.data.calc_loop_triangles(); triangles+=len(obj.data.loop_triangles)
    assert triangles==report['triangles']
    if entry['role']=='arcane_shrine':
        crystals=[o for o in parts if o['region']=='mana']
        roofs=[o for o in parts if o['region']=='roof']
        assert max(v.co.z for o in crystals for v in o.data.vertices)<=min(v.co.z for o in roofs for v in o.data.vertices)-.019,folder+' crystal clips through roof'
    material=parts[0].data.materials[0]
    images=[node.image for node in material.node_tree.nodes if node.type=='TEX_IMAGE']
    assert len(images)==2
    for image in images:
        assert image.packed_file
        assert hashlib.sha256(bytes(image.packed_file.data)).hexdigest()==hashlib.sha256((out/Path(image.filepath_raw).name).read_bytes()).hexdigest()
    with bpy.data.libraries.load(str(out/(folder+'.blend')),link=False) as (available,loaded):
        assert available.scenes==[report['name']]
    verified.append({'asset':folder,'editable_parts':len(parts),'triangles':triangles,'packed_textures':True,'isolated_scene':True,'mechanical_contacts_checked':len(contact_pairs)})
summary={'status':'PASS','verified':len(verified),'method':'live Blender MCP','assets':verified}
(ROOT/'docs/infrastructure_buildings_source_validation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
result={'status':'PASS','verified_sources':len(verified),'method':'live Blender MCP'}

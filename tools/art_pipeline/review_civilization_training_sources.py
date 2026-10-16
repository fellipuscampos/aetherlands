"""Read-only source checks in the live Blender session; show the last asset."""
import bpy
from pathlib import Path

PROJECT=Path(r'C:\Users\felipe campos\Documents\jogo')
stems=('guardian_hall','warrior_hall','ranger_camp','war_stable','rogue_guild','siege_arsenal')
reviewed=[]
seated=0
for civ,plural in (('Dwarf','dwarves'),('Elf','elves')):
    for stem in stems:
        folder=civ.lower()+'_'+stem+'_hex_v1'
        name=civ+'_'+stem.title()+'_Hex_V1'
        scene=bpy.data.scenes[name]
        assert scene['civilization']==civ.lower() and scene['asset_only']
        assert not scene.get('includes_perimeter_walls',False)
        source_file=PROJECT/'assets/generated'/plural/'buildings'/folder/(folder+'.blend')
        with bpy.data.libraries.load(str(source_file),link=False) as (available,loaded):
            assert available.scenes==[name],(folder,available.scenes)
        if civ=='Dwarf' and stem not in ('guardian_hall','warrior_hall'):
            source=bpy.data.scenes['Orc_'+stem.title()+'_Hex_V1']
            original={o.get('part'):o for o in source.objects if o.type=='MESH'}
            assert scene['copper_caps_seated']
            for obj in scene.objects:
                part=obj.get('part','')
                if not part.startswith('Copper_Runestone_'): continue
                previous=original[part[len('Copper_Runestone_'):]]
                assert abs(min(v.co.z for v in obj.data.vertices)-min(v.co.z for v in previous.data.vertices))<.00001
                seated+=1
            if stem=='siege_arsenal':
                assert not any(o.get('part')=='Crane_Clan_Horn' for o in scene.objects)
        reviewed.append(folder)

bpy.context.window.scene=bpy.data.scenes['Elf_Siege_Arsenal_Hex_V1']
result={'isolated_sources_verified':len(reviewed),'copper_caps_seated':seated,
        'active_scene':bpy.context.scene.name,'assets':reviewed}

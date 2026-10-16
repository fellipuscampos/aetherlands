"""Validate the complete dwarf/elf military sets and write the preview catalog."""
import hashlib
import json
import math
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
ROLES={'tank':('guardian_hall','Tanks'),'warrior':('warrior_hall','Guerreiros'),
       'ranged':('ranger_camp','Patrulheiros'),'cavalry':('war_stable','Cavaleiros'),
       'rogue':('rogue_guild','Ladinos'),'siege':('siege_arsenal','Máquinas de guerra')}
expected={'scripts/city/City.gd':'6bdbf60b2f9947f08ec8e69aafdad17bfb49b2ee0e57deb4e692d310dc57bf36',
          'scripts/data/BuildingDatabase.gd':'3a65e312d3ec8bee5881d324bbbde0353f5b998d9186543c18e600cf28b3c713'}
for filename,digest in expected.items():
    assert hashlib.sha256((ROOT/filename).read_bytes()).hexdigest()==digest,filename
scripts=[p.read_text(encoding='utf-8-sig') for p in (ROOT/'scripts').rglob('*.gd')]
catalog=[]
for civ,plural in (('dwarf','dwarves'),('elf','elves')):
    for role,(stem,label) in ROLES.items():
        folder=civ+'_'+stem+'_hex_v1'
        out=ROOT/'assets/generated'/plural/'buildings'/folder
        files=[out/(folder+x) for x in ('.blend','.glb','_albedo.png','_emission.png','_report.json')]
        files += [out/'README.md']+[out/'previews'/(v+'.png') for v in ('three_quarter','game_top','top','back')]
        assert all(p.exists() and p.stat().st_size>0 for p in files),folder
        r=json.loads((out/(folder+'_report.json')).read_text(encoding='utf-8'))
        assert r['civilization']==civ and r['unit_class']==role
        assert r['asset_only'] and not r['integrated_in_game'] and not r['includes_perimeter_walls']
        assert r['nonmanifold_edges']==0 and r['materials']==1 and not r['rig'] and not r['animations']
        assert r['trains'] and len(r['excludes'])==1
        assert not any(folder in s for s in scripts),folder
        raw=(out/(folder+'.glb')).read_bytes()
        assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
        length=struct.unpack_from('<I',raw,12)[0]
        g=json.loads(raw[20:20+length]); binary=raw[28+length:]
        assert len(g['meshes'])==8 and len(g['materials'])==1 and len(g['images'])==2
        assert not g.get('skins') and not g.get('animations') and not g.get('cameras')
        assert 'KHR_lights_punctual' not in g.get('extensionsUsed',[])
        for node in g['nodes']:
            assert node.get('translation',[0,0,0])==[0,0,0]
            assert node.get('rotation',[0,0,0,1])==[0,0,0,1]
            assert node.get('scale',[1,1,1])==[1,1,1]
            assert node.get('matrix',[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1])==[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
        assert all(s['magFilter']==9728 and s['minFilter'] in (9728,9984,9986) for s in g['samplers'])
        digests={hashlib.sha256((out/(folder+'_'+suffix+'.png')).read_bytes()).hexdigest() for suffix in ('albedo','emission')}
        for image in g['images']:
            bv=g['bufferViews'][image['bufferView']]; start=bv.get('byteOffset',0)
            assert hashlib.sha256(binary[start:start+bv['byteLength']]).hexdigest() in digests
        triangles=0; maximum=0
        for mesh in g['meshes']:
            for primitive in mesh['primitives']:
                triangles+=g['accessors'][primitive['indices']]['count']//3
                a=g['accessors'][primitive['attributes']['POSITION']]
                assert a['type']=='VEC3' and a['componentType']==5126
                bv=g['bufferViews'][a['bufferView']]
                start=bv.get('byteOffset',0)+a.get('byteOffset',0); stride=bv.get('byteStride',12)
                for i in range(a['count']):
                    x,_,z=struct.unpack_from('<fff',binary,start+i*stride)
                    maximum=max(maximum,max(x*math.cos(math.radians(n*60))-z*math.sin(math.radians(n*60)) for n in range(6)))
        assert triangles==r['triangles']
        assert maximum<=math.sqrt(3)/2-.030,(folder,maximum)
        assert abs(maximum-r['hex_tile']['max_half_plane_blender'])<.0001
        if role=='cavalry':
            assert r['horse_props']['count']==2 and not r['horse_props']['riders']
        catalog.append({'civilization':civ,'role':role,'name':r['display_name'],
            'folder':out.relative_to(ROOT).as_posix(),'triangles':triangles,
            'parts':r['editable_parts'],'hex_margin':math.sqrt(3)/2-maximum})

doc='# Construções militares — Anões e Elfos\n\n'
doc+='As duas famílias têm as seis construções comuns. **Assets preparados, sem integração no jogo.** '
doc+='Cada pasta contém `.blend`, `.glb`, dois atlas PNG, relatório, README e quatro prévias. '
doc+='Base militar hexadecimal pointy-top de raio 0,92 para tile de raio 1; unidades supremas ficam nos prédios próprios.\n\n'
doc+='Anões: granito, ardósia escura, cobre e detalhes azuis. Elfos: pedra clara, madeira, telhados verdes, folhas douradas e vegetação.\n\n'
doc+='| Construção | Anões — prévia | Elfos — prévia |\n|---|---|---|\n'
for role,(_,label) in ROLES.items():
    row=[entry for entry in catalog if entry['role']==role]
    doc+='| '+label+' | '+' | '.join('[Ver modelo](../'+e['folder']+'/previews/three_quarter.png)' for e in row)+' |\n'
doc+='\n| Modelo | Triângulos | Peças editáveis |\n|---|---:|---:|\n'
for entry in catalog:
    doc+='| ['+entry['name']+'](../'+entry['folder']+'/README.md) | '+str(entry['triangles'])+' | '+str(entry['parts'])+' |\n'
doc+='\nVerificados: encaixe hexadecimal de todos os vértices do GLB, malhas fechadas, atlas embutidos iguais aos PNGs, filtro nearest, oito malhas/um material, ausência de rig/animações/câmeras/luzes no GLB e código de jogo intacto.\n'
(ROOT/'docs/TRAINING_BUILDINGS_CATALOG.md').write_text(doc,encoding='utf-8')
print(json.dumps({'verified_buildings':len(catalog),'files':len(catalog)*10,'runtime_unchanged':True,
                  'catalog':'docs/TRAINING_BUILDINGS_CATALOG.md','assets':catalog},ensure_ascii=True,indent=2))

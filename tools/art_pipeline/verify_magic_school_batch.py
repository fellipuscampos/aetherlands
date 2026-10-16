"""Verify exported magic assets and assemble race preview catalogs."""
import argparse
import hashlib
import json
import math
import struct
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RECIPES = {
    'sacred':('sacred_temple','Templo Sagrado','sacred_cleric'),
    'infernal':('infernal_sanctum','Santuário Infernal','infernal_warlock'),
    'necromancy':('necromancy_ossuary','Ossuário','necromancer'),
    'druidism':('druidic_circle','Círculo Druídico','druid'),
    'arcanism':('arcane_conclave','Conclave Arcano','arcanist'),
    'elementalism':('elemental_observatory','Observatório Elemental','elementalist'),
}
CIVS = {'human':('humans','Humanos'),'orc':('orcs','Orcs'),'dwarf':('dwarves','Anões'),'elf':('elves','Elfos')}
VIEWS = ('three_quarter','game_top','top','back')
EXPECTED_CODE = {
    'scripts/data/BuildingDatabase.gd':'3a65e312d3ec8bee5881d324bbbde0353f5b998d9186543c18e600cf28b3c713',
    'scripts/data/BuildingData.gd':'cff409aef8dea1d0b3fd43708933c2145d99b165e3d45c0dbd90e120348b9580',
    'scripts/city/Building.gd':'eb6ddcdfe5efb2c6291558f0f00fa4becb2feeccee629d6b864d412cecf166c8',
    'scripts/city/City.gd':'6bdbf60b2f9947f08ec8e69aafdad17bfb49b2ee0e57deb4e692d310dc57bf36',
}

def validate(civ,school,recipes=None,unit_prefix='v2_unit_',role_field='magic_school'):
    plural,_ = CIVS[civ]
    stem,label,unit = (recipes or RECIPES)[school]
    folder = ('' if civ=='human' else civ+'_')+stem+'_hex_v1'
    out = ROOT/'assets/generated'/plural/'buildings'/folder
    files = [out/(folder+s) for s in ('.blend','.glb','_albedo.png','_emission.png','_report.json')]
    files += [out/'README.md']+[out/'previews'/(v+'.png') for v in VIEWS]
    assert all(p.exists() and p.stat().st_size>0 for p in files),folder
    report = json.loads((out/(folder+'_report.json')).read_text(encoding='utf-8'))
    assert report['civilization']==civ and report[role_field]==school
    assert report['trains']==[unit_prefix+unit]
    assert report['gameplay_building_id']=='v2_building_'+stem
    assert report['nonmanifold_edges']==0 and report['materials']==1
    assert report['asset_only'] and not report['integrated_in_game']
    raw = (out/(folder+'.glb')).read_bytes()
    assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
    length = struct.unpack_from('<I',raw,12)[0]
    gltf = json.loads(raw[20:20+length])
    binary = raw[28+length:]
    assert len(gltf['materials'])==1 and len(gltf['images'])==2
    assert not gltf.get('skins') and not gltf.get('animations') and not gltf.get('cameras')
    assert 'KHR_lights_punctual' not in gltf.get('extensionsUsed',[])
    assert all(s['magFilter']==9728 and s['minFilter'] in (9728,9984,9986) for s in gltf['samplers'])
    for node in gltf['nodes']:
        assert node.get('translation',[0,0,0])==[0,0,0]
        assert node.get('rotation',[0,0,0,1])==[0,0,0,1]
        assert node.get('scale',[1,1,1])==[1,1,1]
    hashes = {hashlib.sha256((out/(folder+'_'+s+'.png')).read_bytes()).hexdigest() for s in ('albedo','emission')}
    for im in gltf['images']:
        bv = gltf['bufferViews'][im['bufferView']]
        start = bv.get('byteOffset',0)
        assert hashlib.sha256(binary[start:start+bv['byteLength']]).hexdigest() in hashes
    triangles,maximum,minimum_y = 0,0,100
    for mesh in gltf['meshes']:
        for primitive in mesh['primitives']:
            assert 'TEXCOORD_0' in primitive['attributes']
            triangles += gltf['accessors'][primitive['indices']]['count']//3
            acc = gltf['accessors'][primitive['attributes']['POSITION']]
            assert acc['type']=='VEC3' and acc['componentType']==5126
            bv = gltf['bufferViews'][acc['bufferView']]
            start = bv.get('byteOffset',0)+acc.get('byteOffset',0)
            stride = bv.get('byteStride',12)
            for i in range(acc['count']):
                x,y,z = struct.unpack_from('<fff',binary,start+i*stride)
                minimum_y = min(minimum_y,y)
                maximum = max(maximum,max(x*math.cos(math.radians(n*60))-z*math.sin(math.radians(n*60)) for n in range(6)))
    assert abs(minimum_y)<1e-6
    assert triangles==report['triangles']
    assert maximum<=math.sqrt(3)/2-.030,(folder,maximum)
    assert abs(maximum-report['hex_tile']['max_half_plane_blender'])<1e-5
    for view in VIEWS:
        with Image.open(out/'previews'/(view+'.png')) as im:
            im.verify()
    return {'civilization':civ,'school':school,'label':label,'folder':out.relative_to(ROOT).as_posix(),
            'triangles':triangles,'parts':report['editable_parts'],'meshes':len(gltf['meshes']),
            'hex_margin':math.sqrt(3)/2-maximum,'glb_sha256':hashlib.sha256(raw).hexdigest()}

def sheet(civ,entries,view,catalog_name='magic_schools',catalog_title='Escolas de magia'):
    plural,label = CIVS[civ]
    canvas = Image.new('RGB',(1200,870),(26,33,43))
    draw = ImageDraw.Draw(canvas)
    font_path = Path('C:/Windows/Fonts/segoeui.ttf')
    font = ImageFont.truetype(str(font_path),22)
    small = ImageFont.truetype(str(font_path),18)
    draw.text((22,12),label+' — '+catalog_title,font=font,fill=(233,224,193))
    for i,entry in enumerate(entries):
        x,y = (i%3)*400,50+(i//3)*410
        with Image.open(ROOT/entry['folder']/'previews'/(view+'.png')) as im:
            canvas.paste(im.convert('RGB').resize((390,370),Image.Resampling.LANCZOS),(x+5,y))
        draw.text((x+14,y+376),entry['label'],font=small,fill=(231,233,237))
    path = ROOT/'assets/generated'/plural/'buildings'/(catalog_name+'_'+view+'.jpg')
    canvas.save(path,quality=94)
    return path.relative_to(ROOT).as_posix()

if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--civ',choices=tuple(CIVS))
    parser.add_argument('--require-polish',action='store_true')
    args = parser.parse_args()
    for path,digest in EXPECTED_CODE.items():
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,path
    catalog,sheets = [],{}
    for civ in ([args.civ] if args.civ else CIVS):
        entries = [validate(civ,s) for s in RECIPES]
        if args.require_polish:
            expected_roof = {'human':[49,79,127],'orc':[130,58,39],'dwarf':[67,82,89],'elf':[48,122,88]}[civ]
            for entry in entries:
                p=ROOT/entry['folder'];r=json.loads((p/(p.name+'_report.json')).read_text(encoding='utf-8'))
                finish=r['finish_pass']
                assert finish['revision']==1 and finish['original_structure_preserved']
                assert finish['roof_rgb']==expected_roof
                assert not finish['physical_attachment_remaining'], (p.name,finish['physical_attachment_remaining'])
        catalog += entries
        sheets[civ] = {v:sheet(civ,entries,v) for v in ('three_quarter','game_top')}
    if not args.civ:
        doc = '# Escolas de magia — modelos 3D\n\n'
        doc += '24 prédios criados pelo Blender MCP, um por vez, na ordem humanos, orcs, anões e elfos.\n\n'
        doc += 'Cada pasta possui `.blend`, `.glb`, atlas albedo/emissão, relatório, README e quatro prévias. Assets preparados; integração no jogo pendente.\n\n'
        for civ,(_,label) in CIVS.items():
            doc += '## '+label+'\n\n'
            doc += '[Visão geral](../'+sheets[civ]['three_quarter']+') · [Visão de mapa](../'+sheets[civ]['game_top']+')\n\n'
            doc += '| Escola | Modelo e arquivos | Triângulos |\n|---|---|---:|\n'
            for entry in catalog:
                if entry['civilization']==civ:
                    doc += '| '+entry['label']+' | [Abrir](../'+entry['folder']+'/README.md) | '+str(entry['triangles'])+' |\n'
            doc += '\n'
        doc += 'Verificados: arquivos e imagens válidos, seis bordas do hex, origem no solo, UVs, atlas embutidos idênticos aos PNGs, nearest, malhas fechadas, ausência de rig/animação/câmeras/luzes no GLB e código de jogo preservado.\n'
        if args.require_polish:
            doc += '\nAcabamento revisado sobre os modelos existentes: volumes principais preservados, mastros fundados e tecido fixado, apoios físicos conferidos, telhados uniformes por civilização e detalhes próprios de cada raça. Ossuários usam a caveira, mandíbula e pintura das costelas do esqueleto aprovado, com relevos de ossos e prateleiras.\n'
        godot_path = ROOT/'docs/magic_schools_godot_validation.json'
        if godot_path.exists():
            godot = json.loads(godot_path.read_text(encoding='utf-8'))
            assert godot['status']=='PASS' and godot['verified']==24
            doc += '\nImportação direta dos 24 GLBs no Godot 4.7.1: PASS. [Relatório do Godot](magic_schools_godot_validation.json).\n'
        doc += '\n[Relatório dos assets](magic_schools_validation.json).\n'
        doc += '\nScripts de produção: `tools/art_pipeline/magic_school_model.py`, `magic_school_finish.py` e `run_magic_school_batch.py`. Cada modelo foi finalizado e salvo antes de iniciar o próximo.\n'
        if args.require_polish:
            doc += '\nA revisão usa `tools/art_pipeline/magic_school_polish.py` e `run_magic_school_polish.py` para ajustar as cenas existentes pelo Blender MCP, sem executar o construtor original. [Detalhes da revisão](MAGIC_SCHOOLS_FINISH_REVIEW.md). Cópias anteriores preservadas em `art_source/magic_schools_before_finish_pass/`.\n'
        (ROOT/'docs/MAGIC_SCHOOLS_CATALOG.md').write_text(doc,encoding='utf-8')
        (ROOT/'docs/magic_schools_validation.json').write_text(json.dumps({'verified':24,'runtime_unchanged':True,'assets':catalog,'sheets':sheets},ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'verified':len(catalog),'runtime_unchanged':True,'sheets':sheets},ensure_ascii=True,indent=2))

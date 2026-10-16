"""Validate exported machinery and document its four distinct constructions."""
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from elf_siege_assets import ROOT,OUT,WORK,SIEGE_ASSETS
from human_texture_glb import read_glb,image_bytes
from audit_elf_troops import accessor,animation_channels


def verify():
    protected=json.loads((WORK/'protected_assets.json').read_text(encoding='utf-8'))
    assert all(hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha for path,sha in protected.items())
    checks=[]; silhouettes=[]
    for row in SIEGE_ASSETS:
        folder=OUT/row['stem']; report=json.loads((folder/(row['stem']+'_report.json')).read_text(encoding='utf-8'))
        doc,binary=read_glb((folder/(row['stem']+'.glb')).read_bytes())
        human,humanbin=read_glb((ROOT/'assets/generated/humans'/row['source_stem']/(row['source_stem']+'.glb')).read_bytes())
        clips={clip['name']:max(doc['accessors'][s['input']]['max'][0] for s in clip['samplers']) for clip in doc['animations']}
        humanclips={clip['name']:max(human['accessors'][s['input']]['max'][0] for s in clip['samplers']) for clip in human['animations']}
        assert clips==humanclips==report['clips'],(row['stem'],clips,humanclips)
        assert len(doc['skins'])==1 and len(doc['meshes'])==1
        assert len(doc['skins'][0]['joints'])==len(report['rig']['bones'])
        triangles=0; positions=[]
        for primitive in doc['meshes'][0]['primitives']:
            attrs=primitive['attributes']
            p=accessor(doc,binary,attrs['POSITION']); positions.append(p)
            uv=accessor(doc,binary,attrs['TEXCOORD_0']); weights=accessor(doc,binary,attrs['WEIGHTS_0'])
            assert np.isfinite(p).all() and np.isfinite(uv).all()
            assert (uv>=0).all() and (uv<=1).all()
            assert np.allclose(weights.sum(axis=1),1) and np.all((weights>.0001).sum(axis=1)==1)
            triangles+=accessor(doc,binary,primitive['indices']).size//3
        positions=np.concatenate(positions)
        assert triangles==report['geometry']['triangles']
        assert abs(positions[:,1].max()-row['character_height_m'])<.0001
        assert abs(positions[:,1].min())<.0001
        signature=hashlib.sha256(positions.tobytes()).hexdigest(); silhouettes.append(signature)
        png=(folder/(row['stem']+'_albedo.png')).read_bytes()
        assert len(doc['images'])==1 and image_bytes(doc,binary,doc['images'][0])==png
        assert all(s['magFilter']==9728 for s in doc['samplers'])
        assert any(material['pbrMetallicRoughness'].get('metallicFactor',1)>.5 for material in doc['materials'])
        assert any(material['pbrMetallicRoughness'].get('metallicFactor',1)==0 for material in doc['materials'])
        channels=animation_channels(doc,binary)
        for clip,bones in channels.items():
            changing=max(float(np.max(np.abs(values-values[0]))) for _,values in bones.values())
            assert changing>.01 if not clip.endswith('_Idle') else changing<.00001,(clip,changing)
        wheel_count=sum(name.startswith('wheel_') for name in report['rig']['bones'])
        assert wheel_count==(6 if row['tier']==3 else 4)
        if row['tier']==3:
            names=report['rig']['part_bones']
            assert all(key in names for key in ('TorsionBridge','TriggerSled','LoadedBolt','WinchPlatform','Bowstring_l','Bowstring_r'))
            assert not any('boiler' in name.lower() or 'barrel' in name.lower() for name in names)
            assert all(key in report['rig']['bones'] for key in ('bow_l','bow_r','sled'))
        checks.append(dict(stem=row['stem'],status='PASS',clips=len(clips),triangles=triangles,
                           wheels=wheel_count,height_m=row['character_height_m'],embedded_atlas_matches=True,
                           motion_recovery=report['motion'],geometry_signature=signature))
    assert len(set(silhouettes))==4
    result=dict(status='PASS',verified=4,clips=19,protected_files=len(protected),assets=checks)
    (ROOT/'docs/elf_siege_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({key:result[key] for key in ('status','verified','clips','protected_files')}))


def document():
    dest=ROOT/'docs/previews/elf_siege'; dest.mkdir(parents=True,exist_ok=True)
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
    large=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',25)
    for view in ('three_quarter','front','game_top','back'):
        gallery=Image.new('RGB',(4*420,490),(31,42,36)); draw=ImageDraw.Draw(gallery)
        draw.text((16,8),'Cerco élfico — quatro evoluções',font=large,fill=(232,225,192))
        for row in SIEGE_ASSETS:
            image=Image.open(OUT/row['stem']/'previews'/(view+'.png')).convert('RGB').resize((420,420),Image.Resampling.LANCZOS)
            gallery.paste(image,(row['tier']*420,44))
            draw.text((row['tier']*420+10,467),row['name'],font=font,fill=(232,225,192))
        gallery.save(dest/('progression_'+view+'.jpg'),quality=94)
    comparison=Image.new('RGB',(4*350,3*400),(31,42,36)); draw=ImageDraw.Draw(comparison)
    for band,(race,label,view) in enumerate((('humans','Humanos','threequarter'),('dwarves','Anões','three_quarter'),('elves','Elfos','three_quarter'))):
        draw.text((12,band*400+6),label,font=large,fill=(232,225,192))
        for row in SIEGE_ASSETS:
            stem=row['source_stem'] if race=='humans' else ('dwarf_'+row['source_stem'] if race=='dwarves' else row['stem'])
            image=Image.open(ROOT/'assets/generated'/race/stem/'previews'/(view+'.png')).convert('RGB').resize((350,350),Image.Resampling.LANCZOS)
            comparison.paste(image,(row['tier']*350,band*400+40))
    comparison.save(dest/'three_races_comparison.jpg',quality=94)
    if (dest/'colossus_attack_115.png').exists():
        contact=Image.new('RGB',(4*384,420),(31,42,36)); draw=ImageDraw.Draw(contact)
        for index,frame in enumerate((115,130,142,162)):
            contact.paste(Image.open(dest/('colossus_attack_'+str(frame)+'.png')).convert('RGB'),(index*384,0))
            draw.text((index*384+12,389),['Pronto','Tensão e guincho','Disparo','Recuperado'][index],font=font,fill=(232,225,192))
        contact.save(dest/'colossus_attack_contact.jpg',quality=94)
    catalog='''# Máquinas de cerco dos elfos

Quatro modelos originais construídos, pintados e animados pelo MCP do Blender aberto. A linha usa madeira clara de freixo, madeira escura nas peças de carga, bronze, aço, cordas de fibra, couro e tecidos verdes. Os acabamentos dourados do Colosso correspondem a ferragens e proteções de metal. As formas continuam feitas de blocos e prismas de poucas faces.

| Evolução | Construção | Altura funcional em repouso |
|---|---|---|
| Catapulta Élfica | Mangonel leve, quatro rodas abertas, torsão em corda, braço de lançamento e guincho traseiro | 1,80 m |
| Trebuchet Élfico | Estrutura em A, contrapeso articulado, funda e trilho de preparação | 1,80 m |
| Bombarda Élfica | Tubo longo de bronze, boca rebaixada, cintas de aço, apoios de madeira e recuo sobre trilhos | 1,80 m |
| Colosso de Guerra Élfico | Grande balista de torsão com seis rodas, dois braços laminados, cabos, trilho de virote e guincho | 2 m |

As três primeiras máquinas preservam os tipos de seus equivalentes humanos e anões com proporções, suportes e materiais próprios. O Colosso tem uma construção diferente: grande balista móvel, enquanto o humano usa uma grande bombarda e o anão um morteiro com caldeira.

Os 19 clipes mantêm os nomes, funções e durações da linha humana: Idle, Walk, Attack, DemolitionAmmo e, a partir do Trebuchet, PreparedBombardment. Os movimentos foram adaptados à mecânica de cada modelo. Idle permanece imóvel; as rodas giram no deslocamento, os braços lançam, a bombarda recua e a balista move braços, cordas, guincho e virote. Os contrapesos articulados e as pontas dos cabos acompanham seus pontos de fixação.

Abra `res://_elf_siege_models_review.tscn` no Godot e pressione F6 para começar na categoria Cerco. A cena geral `_elf_troop_models_review.tscn` também inclui a sexta categoria. Os arquivos `.blend`, `.glb`, atlas e relatórios ficam em `assets/generated/elves/elf_*_v1/`. A revisão `assets/generated/elves/elf_siege_review.blend` mostra as quatro máquinas juntas: Espaço pausa/reproduz; desative Preview Range para percorrer todas as técnicas.

- [Galeria das quatro máquinas](previews/elf_siege/progression_three_quarter.jpg)
- [Comparação entre as três raças](previews/elf_siege/three_races_comparison.jpg)
- [Disparo do Colosso](previews/elf_siege/colossus_attack_contact.jpg)
- [Revisão no Blender](previews/elf_siege/blender_review.png)
- `elf_siege_validation.json`: geometria exportada, alturas, skins, movimentos, nomes/durações dos clipes, atlas embutido, materiais, rodas e hashes dos modelos existentes.
- `elf_siege_blender_review_validation.json`: reprodução real do ataque das quatro máquinas na revisão.
- `elf_troops_project_validation.json`: importação no projeto Godot das 24 unidades élficas e execução da revisão de seis classes.

Para regenerar no Blender aberto: `python tools/art_pipeline/run_elf_siege_mcp.py`. Para uma máquina: `--only elf_siege_colossus_v1`. Os modelos fazem parte do catálogo de arte e revisão; a seleção racial de modelos no gameplay segue a integração das demais tropas.
'''
    (ROOT/'docs/ELF_SIEGE_CATALOG.md').write_text(catalog,encoding='utf-8')


if __name__=='__main__':
    verify(); document()

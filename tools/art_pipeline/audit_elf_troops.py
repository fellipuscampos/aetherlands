"""Check actual GLB geometry, embedded atlases and inherited animation samples."""
import hashlib
import json
import re
from pathlib import Path
from collections import Counter

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from elf_troop_assets import ROOT, OUT, WORK, ASSETS, FAMILIES
from human_texture_glb import read_glb, image_bytes

def accessor(doc,binary,index):
    info=doc['accessors'][index]; view=doc['bufferViews'][info['bufferView']]
    dtype={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}[info['componentType']]
    size={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[info['type']]
    stride=view.get('byteStride',np.dtype(dtype).itemsize*size)
    return np.ndarray((info['count'],size),dtype=dtype,buffer=binary,
                      offset=view.get('byteOffset',0)+info.get('byteOffset',0),
                      strides=(stride,np.dtype(dtype).itemsize)).copy()

def normalized_name(name):
    return re.sub(r'\.\d+$','',name.removeprefix('Elf_'))

def animation_channels(doc,binary):
    result={}
    for clip in doc['animations']:
        channels={}
        for channel in clip['channels']:
            sampler=clip['samplers'][channel['sampler']]
            key=(normalized_name(doc['nodes'][channel['target']['node']]['name']),channel['target']['path'])
            channels[key]=(accessor(doc,binary,sampler['input']),accessor(doc,binary,sampler['output']))
        result[clip['name']]=channels
    return result

def triangles(doc,binary):
    # UVs are intentionally repacked; compare inherited shape and skinning per triangle.
    result=Counter()
    skin=doc['skins'][0]
    joints=[doc['nodes'][j]['name'] for j in skin['joints']]
    for mesh in doc['meshes']:
        for prim in mesh['primitives']:
            attrs=prim['attributes']
            pos=accessor(doc,binary,attrs['POSITION'])
            normal=accessor(doc,binary,attrs['NORMAL'])
            weights=accessor(doc,binary,attrs['WEIGHTS_0'])
            indices=accessor(doc,binary,attrs['JOINTS_0'])
            assert np.isfinite(pos).all() and np.isfinite(normal).all()
            assert np.allclose(weights.sum(axis=1),1) and np.all((weights>.0001).sum(axis=1)==1)
            uv=accessor(doc,binary,attrs['TEXCOORD_0'])
            assert (uv>=0).all() and (uv<=1).all()
            order=accessor(doc,binary,prim['indices']).ravel().reshape(-1,3)
            for tri in order:
                corners=[]
                for idx in tri:
                    bone=joints[indices[idx,np.argmax(weights[idx])]]
                    corners.append(tuple(np.round(np.r_[pos[idx],normal[idx]],5))+ (bone,))
                result[tuple(sorted(corners))]+=1
    return result

def verify():
    results=[]
    baseline=json.loads((WORK/'protected_source_baseline.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==sha for p,sha in baseline.items()),'Source asset changed'
    for row in ASSETS:
        folder=OUT/row['stem']; report=json.loads((folder/(row['stem']+'_report.json')).read_text(encoding='utf-8'))
        doc,binary=read_glb((folder/(row['stem']+'.glb')).read_bytes())
        source,sbinary=read_glb((ROOT/'assets/generated/humans'/row['source_stem']/(row['source_stem']+'.glb')).read_bytes())
        assert len(doc['skins'])==1 and len(doc['materials'])==1 and len(doc['meshes'])==1
        oldtri,newtri=triangles(source,sbinary),triangles(doc,binary)
        removed=Counter()
        for decoration in report['geometry'].get('removed_head_decorations',[]):
            for tri in decoration['triangles']:
                corners=[tuple(np.round(np.array(c['position']+c['normal'],dtype=np.float32),5))+(c['bone'],) for c in tri]
                removed[tuple(sorted(corners))]+=1
        assert oldtri-newtri==removed,row['stem']+': changed geometry beyond documented head attachments'
        extras=newtri-oldtri
        assert sum(extras.values())==72,row['stem']+': expected six closed ear cuboids'
        assert all(corner[-1]=='head' for tri in extras for corner in tri),row['stem']+': ears not attached to head'
        before,after=animation_channels(source,sbinary),animation_channels(doc,binary)
        assert before.keys()==after.keys()
        max_error=0.0
        for name,channels in before.items():
            assert channels.keys()==after[name].keys(),(row['stem'],name)
            for key,old in channels.items():
                new=after[name][key]
                for a,b in zip(old,new):
                    assert a.shape==b.shape,(row['stem'],name,key,a.shape,b.shape)
                    difference=float(np.max(np.abs(a-b)))
                    max_error=max(max_error,difference)
                    assert difference<.00005,(row['stem'],name,key,difference)
        for texture in doc['images']:
            suffix='_albedo.png' if 'albedo' in texture['name'] else '_emission.png'
            assert image_bytes(doc,binary,texture)==(folder/(row['stem']+suffix)).read_bytes()
        assert all(s['magFilter']==9728 and s['minFilter'] in (9728,9984) for s in doc['samplers'])
        assert report['pipeline']=='Open Blender MCP localhost:9876'
        assert report['character_height_m']==(2 if row['tier']==3 else 1.8)
        assert len(report['geometry']['body_parts'])==18
        assert report['geometry']['head_blocks']==1
        png=np.array(Image.open(folder/(row['stem']+'_albedo.png')).convert('RGB'))[::-1]
        for face in report['texture']['head_audit']:
            assert face['left_eye_pixels']==face['right_eye_pixels'],row['stem']+': unequal eyes'
            if face['mode']=='closed_helmet':
                assert face['left_visor_pixels']==face['right_visor_pixels']
            else:
                assert face['eyes_mirrored']
                left,right=face['eye_atlas_pixels']
                assert len(left)==len(right)==face['left_eye_pixels']
                assert all(np.array_equal(png[a[1],a[0]],png[b[1],b[0]]) for a,b in zip(left,right)),row['stem']+': atlas eye mismatch'
        if report['geometry']['closed_helmet']:
            assert report['texture']['head_audit'][0]['mode']=='closed_helmet'
        if row['tier']==3:
            rgb=report['texture']['armor_profile'][1]
            assert rgb[0]>rgb[1]>rgb[2] and rgb[0]-rgb[2]>70
        results.append(dict(stem=row['stem'],status='PASS',triangles=sum(newtri.values()),ear_triangles=72,
            retained_source_triangles_preserved=True,removed_helmet_decoration_triangles=sum(removed.values()),
            head_blocks=1,eyes_mirrored=True,legendary_gold_armor=row['tier']==3,embedded_textures_match=True,clips=len(before),
            inherited_animation_max_error=max_error,character_height_m=row['character_height_m']))
    output=dict(status='PASS',verified=len(results),classes=5,protected_files=len(baseline),
        protected_human_and_dwarf_sources_unchanged=True,assets=results)
    (ROOT/'docs/elf_troops_validation.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
    print(json.dumps(dict(status='PASS',verified=len(results),protected_files=len(baseline),animation_max_error=max(r['inherited_animation_max_error'] for r in results))))

def galleries():
    dest=ROOT/'docs/previews/elf_troops'; dest.mkdir(parents=True,exist_ok=True)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
    small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15)
    for view in ('three_quarter','front','game_top','back'):
        gallery=Image.new('RGB',(4*330,5*385),(34,42,43)); draw=ImageDraw.Draw(gallery)
        for i,row in enumerate(ASSETS):
            col=row['tier']; band=i//4
            frame=Image.open(OUT/row['stem']/'previews'/(view+'.png')).convert('RGB').resize((326,326),Image.Resampling.LANCZOS)
            x=col*330+2; y=band*385+2; gallery.paste(frame,(x,y))
            draw.text((x+8,y+329),row['name'],fill=(239,231,207),font=font)
            draw.text((x+8,y+356),row['family_name']+' | '+('Lendário 2 m' if col==3 else '1,80 m'),fill=(173,199,183),font=small)
        gallery.save(dest/('roster_'+view+'.jpg'),quality=93)
    # Compare the human reference art with each direct elf derivative.
    comparison=Image.new('RGB',(5*320,690),(34,42,43)); draw=ImageDraw.Draw(comparison)
    for index,family in enumerate(FAMILIES):
        row=next(a for a in ASSETS if a['family']==family and a['tier']==0)
        for band,race,stem in ((0,'humans',row['source_stem']),(1,'elves',row['stem'])):
            path=ROOT/'assets/generated'/race/stem/'previews/three_quarter.png'
            if not path.exists(): path=path.with_name('threequarter.png')
            frame=Image.open(path).convert('RGB')
            frame=frame.resize((316,316),Image.Resampling.LANCZOS)
            x=index*320+2; y=band*345+2; comparison.paste(frame,(x,y))
            draw.text((x+10,y+317),('Humano — ' if band==0 else 'Elfo — ')+row['family_name'],font=font,fill=(239,231,207))
    comparison.save(dest/'human_elf_comparison.jpg',quality=93)
    focus=['squire','sentinel','guardian_champion','legend_hunter','griffon_rider','shadow_master']
    before_after=Image.new('RGB',(6*260,2*326),(34,42,43)); draw=ImageDraw.Draw(before_after)
    for index,key in enumerate(focus):
        row=next(a for a in ASSETS if a['source_stem']==key+'_v1')
        for band,folder in ((0,WORK/'before_refinement_v2'/row['stem']),(1,OUT/row['stem'])):
            frame=Image.open(folder/'previews/front.png').convert('RGB').resize((256,256),Image.Resampling.LANCZOS)
            x=index*260+2; y=band*326+2; before_after.paste(frame,(x,y))
            draw.text((x+6,y+258),'Primeira versão' if band==0 else 'Revisão: olhos, cabeça e materiais',font=small,fill=(239,231,207))
            draw.text((x+6,y+285),row['name'],font=small,fill=(173,199,183))
    before_after.save(dest/'refinement_before_after.jpg',quality=94)
    heads=Image.new('RGB',(4*176,5*186),(34,42,43)); draw=ImageDraw.Draw(heads)
    for index,row in enumerate(ASSETS):
        report=json.loads((OUT/row['stem']/(row['stem']+'_report.json')).read_text(encoding='utf-8'))
        x0,y0,x1,y1=report['texture']['head_audit'][0]['uv_bounds']
        image=np.array(Image.open(OUT/row['stem']/(row['stem']+'_albedo.png')).convert('RGB'))[::-1]
        face=Image.fromarray(image[y0:y1,x0:x1][::-1].copy())
        scale=min(150/face.width,150/face.height)
        face=face.resize((round(face.width*scale),round(face.height*scale)),Image.Resampling.NEAREST)
        x=row['tier']*176; y=(index//4)*186
        heads.paste(face,(x+(176-face.width)//2,y+4+(150-face.height)//2))
        draw.text((x+8,y+158),row['family_name']+' • '+str(row['tier']+1),font=small,fill=(239,231,207))
    heads.save(dest/'head_faces.png')
    catalog='''# Tropas élficas — derivadas dos humanos

20 modelos criados no Blender aberto através do MCP: cinco classes, quatro evoluções por classe. Os arquivos `.blend` mantêm as peças editáveis; os `.glb` têm texturas embutidas, rig e todos os clipes dos humanos de origem.

O corpo humano foi reutilizado diretamente: cabeça, peito, barriga, pélvis e, dos dois lados, coxa, canela, pé, ombro, braço, antebraço e mão. Cada orelha é uma ponta em três blocos retangulares fechados, ligados ao osso da cabeça. As faces têm pele pálida, cabelos loiros e olhos verdes desenhados com pixels exatamente espelhados.

## Revisão de rosto, capacetes e materiais

A cabeça permanece um único bloco. Rosto, cabelo, capuz, coifa e capacete completo são desenhados nesse bloco, sem outro rosto ou casco sobreposto. Os capacetes completos de Sentinela, Campeão Guardião, Cavaleiro Couraçado e Campeão da Cavalaria têm faceplate metálica fechada, viseiras simétricas e respiradouros. Suas cristas e plumas geométricas foram retiradas. O Espadachim e o Herói da Lâmina também tiveram os volumes externos de cabelo e seus acessórios retirados; o cabelo está pintado no cubo. Chapéus, gorros e capacetes abertos do tipo chapéu mantêm seus volumes externos. As alturas em pé foram recalibradas para 1,80 m/2 m sem depender dos volumes removidos.

As roupas e armaduras foram repintadas no próprio corpo, com materiais distintos dos humanos: linho oliva, tecido marfim, couro castanho e musgo, bronze, aço claro e aço escurecido. Os cinco lendários usam placas ou lâminas sobrepostas de metal dourado, com couro e tecido nas articulações. A paleta considera marfim, verdes, bronze e dourado dos edifícios élficos existentes. Escudos, mantos e roupas usam construção material: costuras, rebites, juntas de placas, aros e bordas discretas. Os brasões humanos foram removidos.

- [Antes e depois da revisão](previews/elf_troops/refinement_before_after.jpg)
- [Cabeças ampliadas, sem interpolação](previews/elf_troops/head_faces.png)

As três primeiras evoluções mantêm a escala humana de **1,80 m**; a quarta é lendária de **2 m**. Na cavalaria, esse valor corresponde ao cavaleiro em pé; a altura total inclui cavalo e lança. A montaria continua sendo o cavalo blocky dos humanos. O nome interno `griffon_rider` é herdado do jogo, sem acrescentar grifo.

## Animações humanas equivalentes

Os 20 elfos usam os 93 clipes de seus humanos equivalentes: repouso, caminhada, ataque e técnicas próprias de cada evolução. As amostras dos GLBs são idênticas às dos humanos, inclusive durações e movimentos da montaria. As trilhas NLA dos arquivos editáveis estão habilitadas, com marcadores para localizar os clipes na linha do tempo.

A revisão `assets/generated/elves/elf_troops_review.blend` abre com o intervalo de caminhada selecionado. Pressione **Espaço** para reproduzir. Desative **Preview Range** para percorrer a sequência completa: repouso no quadro 1, caminhada no 91, ataque no 201 e técnicas a partir do 331. Cada arquivo individual conserva a linha do tempo original do humano correspondente.

- `elf_troops_animation_blender_validation.json`: comparação das matrizes de todos os ossos em seis instantes por clipe, movimento real de caminhada/ataque e reabertura dos 20 arquivos salvos para verificar as trilhas habilitadas.
- Para aplicar essa configuração pelo MCP do Blender aberto: `python tools/art_pipeline/blender_mcp_client.py tools/art_pipeline/activate_elf_animations_mcp.py`.

## Revisão

- Abra `res://_elf_troop_models_review.tscn` no Godot e pressione **F6**.
- Escolha a classe para ver as quatro evoluções, girar a câmera e testar clipes e técnicas.
- Marque a comparação para exibir a base humana da mesma classe.
- [Galeria das 20 tropas](previews/elf_troops/roster_three_quarter.jpg)
- [Frente](previews/elf_troops/roster_front.jpg), [visão de jogo](previews/elf_troops/roster_game_top.jpg), [costas](previews/elf_troops/roster_back.jpg)
- [Comparação humano/elfo](previews/elf_troops/human_elf_comparison.jpg)

## Modelos

| Classe | Primeira evolução | Segunda | Terceira | Lendária |
|---|---|---|---|---|
'''
    for family,(title,_) in FAMILIES.items():
        rows=[a for a in ASSETS if a['family']==family]
        cells=['['+a['name']+'](../assets/generated/elves/'+a['stem']+'/'+a['stem']+'.blend)' for a in rows]
        catalog+='| '+title+' | '+' | '.join(cells)+' |\n'
    catalog+='''
## Validação e reprodução

- `elf_troops_validation.json`: preservação da anatomia e pesos, remoção apenas dos enfeites de capacetes completos, 72 triângulos de orelhas ligados à cabeça, igualdade dos pixels reais de ambos os olhos no PNG, uma cabeça por modelo, dourado dos lendários, amostras das animações, atlas embutidos, filtragem nearest e hashes dos humanos/anões protegidos.
- `elf_troops_godot_validation.json`: importação dos 20 GLBs, dimensões, materiais, skins, reprodução de todos os clipes e cena de revisão com cinco classes.
- `elf_troops_project_validation.json`: os mesmos 20 modelos e a cena executados no projeto real do jogo.
- `elf_troops_head_blender_validation.json`: inspeção das malhas reais de cabeça no Blender, volumes externos permitidos e alturas em pé após as remoções.
- `assets/generated/elves/elf_troops_review.blend`: revisão das cinco linhas no Blender, também deixada visível na sessão aberta.
- `assets/generated/elves/elf_troops_manifest.json`: caminhos, classe, evolução, referência de ID e altura do personagem.
- Para regenerar através do Blender aberto: `python tools/art_pipeline/run_elf_troop_mcp.py`. Use `--only elf_squire_v1` para uma variante.

Este lote entrega arte e a cena de revisão. A seleção racial no gameplay permanece para uma integração posterior; os modelos humanos e anões não foram substituídos. A classe de cerco não foi criada.
'''
    from elf_siege_assets import SIEGE_ASSETS
    if all((OUT/row['stem']/(row['stem']+'.glb')).exists() for row in SIEGE_ASSETS):
        catalog=catalog.replace('20 modelos criados no Blender aberto através do MCP: cinco classes, quatro evoluções por classe.',
            '24 modelos em seis classes: 20 personagens derivados dos humanos e quatro máquinas de cerco de construção própria, todos feitos pelo MCP do Blender aberto.')
        catalog=catalog.replace('A classe de cerco não foi criada.',
            'A linha de cerco está disponível no [catálogo das máquinas élficas](ELF_SIEGE_CATALOG.md), com Catapulta, Trebuchet, Bombarda e o Colosso de Guerra em forma de grande balista.')
        catalog=catalog.replace('os mesmos 20 modelos e a cena executados no projeto real do jogo.',
            'os 24 modelos, 112 clipes e a revisão de seis classes executados no projeto real do jogo.')
        catalog=catalog.replace('cena de revisão com cinco classes.', 'cena de revisão com seis classes.')
        catalog=catalog.replace('importação dos 20 GLBs, dimensões, materiais, skins, reprodução de todos os clipes',
            'importação dos 24 GLBs, dimensões, materiais, skins, reprodução dos 112 clipes')
    (ROOT/'docs/ELF_TROOPS_CATALOG.md').write_text(catalog,encoding='utf-8')

if __name__=='__main__':
    verify()
    galleries()

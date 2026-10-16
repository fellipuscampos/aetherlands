"""Publish native-rendered loop previews and update the existing settler gallery."""
import json,re,hashlib
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]; WORK=ROOT/'art_source/settlers_review'
for clip,durations in [('idle',[83,83,84]*12),('walk',[42,41,42]*12)]:
    paths=sorted((WORK/'animation_frames'/clip).glob('*.png')); assert len(paths)==36
    frames=[Image.open(path).convert('RGB') for path in paths]
    output=WORK/('settlers_'+clip+'.webp')
    frames[0].save(output,save_all=True,append_images=frames[1:],duration=durations,loop=0,quality=88,method=4)
    with Image.open(output) as image: assert image.n_frames==36
validation=json.loads((ROOT/'docs/settlers_blender_validation.json').read_text(encoding='utf-8'))
assert validation['status']=='PASS' and validation['animations']==8
manifest=json.loads((WORK/'manifest.json').read_text(encoding='utf-8'))
manifest.update(stage='animated_review',animations=2,total_clips=8,animation_clips=['idle','walk'],fps=48,rigging_deferred=False,walk_in_place=True,blender_ranges={'idle':[1,145],'walk':[161,233]},loop_seconds={'idle':3.0,'walk':1.5})
for row,asset in zip(manifest['assets'],validation['assets']):
    row.pop('static_glb_meshes',None); row.pop('static_glb_surfaces',None)
    row.update(animations=2,animation_clips=['idle','walk'],meshes=1,surfaces=1,skins=1,bones=16,height=round(asset['geometry']['dimensions'][2],3),walk_speed_m_per_s=asset['animation']['walk_speed_m_per_s'],arm_correction=asset['arm_correction'])
(WORK/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
page=(WORK/'index.html').read_text(encoding='utf-8')
page=page.replace('Modelos estáticos, sem animações. A cena do Blender reúne os quatro lado a lado na escala original.','Idle e walk em loop para os quatro. Antebraços do humano, elfo e orc ajustados à largura dos braços; anão preservado. A cena do Blender reúne os quatro lado a lado na escala original.')
page=page.replace('GLB estático','GLB animado')
if 'data-view="walk"' not in page:
    page=page.replace('<nav aria-label="Vistas">','<nav aria-label="Vistas"><button data-view="walk" aria-pressed="true">Walk</button><button data-view="idle" aria-pressed="false">Idle</button>')
page=page.replace('data-view="three_quarter" aria-pressed="true"','data-view="three_quarter" aria-pressed="false"')
page=page.replace('href="settlers_three_quarter.png"><img id="overview" class="overview" src="settlers_three_quarter.png"','href="settlers_walk.webp"><img id="overview" class="overview" src="settlers_walk.webp"')
page=page.replace("const path='settlers_'+button.dataset.view+'.png';","const animated=['idle','walk'].includes(button.dataset.view);const path='settlers_'+button.dataset.view+(animated?'.webp':'.png');")
if 'href="settlers_idle_review.blend"' not in page:
    page=page.replace('<a href="README.md">Guia dos arquivos</a>','<a href="README.md">Guia dos arquivos</a> · <a href="settlers_idle_review.blend">Cena idle</a> · <a href="settlers_walk_review.blend">Cena walk</a>')
(WORK/'index.html').write_text(page,encoding='utf-8')
text='''# Colonizadores — idle e walk

Quatro personagens criados e animados no Blender aberto via MCP: humano, elfo, anão e orc. As roupas, texturas e equipamentos aprovados foram preservados. Apenas os antebraços do humano, elfo e orc receberam a seção transversal dos braços, com os encaixes ajustados; a geometria do anão permanece igual à aprovada.

## Conferir no Blender

Abra [cena comparativa](settlers_four_civilizations_review.blend) e pressione **Espaço**. Os quatro ficam lado a lado, da esquerda para a direita: humano, elfo, anão e orc. A prévia está configurada para reproduzir a caminhada em loop.

- [Revisão idle](settlers_idle_review.blend): prévia entre quadros 1 e 145, três segundos.
- [Revisão walk](settlers_walk_review.blend): prévia entre quadros 161 e 233, um segundo e meio.
- Ambas usam 48 fps, com as duas ações disponíveis em cada esqueleto.
- As fontes individuais abrem com a prévia idle; o walk está na segunda faixa NLA, começando em 161.

## Arquivos individuais

| Civilização | Fonte editável | GLB com idle e walk | Triângulos |
|---|---|---|---:|
'''
for row in manifest['assets']:
    text+=f'| {row["name"].replace("Colonizador ","")} | [BLEND](../../{row["blend"]}) | [GLB](../../{row["glb"]}) | {row["triangles"]} |\n'
text+='''
Cada GLB tem uma malha, uma superfície, um material, uma textura e um esqueleto de 16 ossos. As peças continuam separadas, nomeadas e editáveis nos arquivos BLEND. A influência de cada vértice é rígida, com peso 1 em um único osso, preservando os blocos durante o movimento.

O idle tem respiração discreta, pequenos movimentos de cabeça e braços, com os pés no chão. O walk usa joelhos articulados, contrapeso dos braços e pés nivelados. Mochilas, mantas e ferramentas acompanham seus ossos; o cajado do elfo fica erguido e não atravessa o chão.

## Uso no jogo

Os clipes exportados chamam-se `idle` e `walk` e começam no tempo zero. Ambos são loops. A caminhada é **no lugar**: o engine deve deslocar a unidade. A velocidade de referência, em metros por segundo na escala nativa, está em `walk_speed_m_per_s` no manifesto. Multiplique essa velocidade pela escala visual e pela velocidade de reprodução para manter o apoio dos pés.

O script de importação `tools/art_pipeline/settler_model_import.gd`, associado aos quatro `.glb.import`, marca os dois clipes como loops e configura Nearest com mipmaps. Os clipes foram importados e exercitados no Godot com 200 amostras de pose, além da validação nativa de cada quadro.

As texturas PNG aprovadas permanecem iguais. Os UVs dos antebraços ajustados mantêm 64 px/m; os atlas têm 512 × 512 pixels e margem de três pixels. A origem permanece no chão, frente em −Y no Blender e eixo vertical +Y no glTF. Ainda não houve substituição no catálogo ou no mapa do jogo.

O estado aprovado anterior está preservado em `art_source/settlers_before_idle_walk`, acompanhado de hashes. Os modelos base das tropas não foram alterados.

[Galeria com animações](index.html) · [Manifesto](manifest.json) · [Validação Blender](../../docs/settlers_animation_blender_validation.json) · [Validação Godot](../../docs/settlers_animation_godot_validation.json)
'''
if (ROOT/'docs/settlers_grip_validation.json').exists():
    text+='\nA pega das ferramentas foi revisada: o cotovelo do elfo dobra para trás da mão, que segura o cajado à frente; o maço de pedra do orc fica à frente e para fora do antebraço. Os dois clipes foram conferidos quadro a quadro. A versão anterior está em `art_source/settlers_before_grip_fix`. [Validação dos encaixes](../../docs/settlers_grip_validation.json).\n'
(WORK/'README.md').write_text(text,encoding='utf-8')
backup=ROOT/'art_source/settlers_before_idle_walk'
snapshot=json.loads((backup/'snapshot.json').read_text(encoding='utf-8'))
assert all(hashlib.sha256((backup/row['path']).read_bytes()).hexdigest()==row['sha256'] for row in snapshot['files'])
print(json.dumps(dict(status='PASS',models=4,clips=8,animated_previews=2,backup_files_verified=len(snapshot['files']))))

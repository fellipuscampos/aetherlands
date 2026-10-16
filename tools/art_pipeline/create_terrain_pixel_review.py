"""Generate the local terrain review gallery and material inventory."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'art_source/terrain_pixel_review'
DEST = ROOT / 'assets/textures/terrain/pixel_v1'
manifest = json.loads((WORK / 'manifest.json').read_text(encoding='utf-8'))
biomes = {
    'grass': ['Pradaria'], 'dry_grass': ['Planície', 'Savana'],
    'forest_floor': ['Floresta', 'Taiga', 'Selva'], 'tundra': ['Tundra'],
    'dirt': ['Colinas'], 'snow': ['Neve', 'Cobertura de picos'],
    'ice': ['Gelo eterno'], 'sand': ['Deserto'],
    'rock': ['Montanhas', 'Paredes e falésias'],
    'basalt': ['Rocha vulcânica', 'Colinas vulcânicas', 'Picos vulcânicos'],
    'ash': ['Cinzas vulcânicas'],
    'crystal': ['Campos de cristal', 'Picos de cristal', 'Fonte mística'],
    'mystic_soil': ['Solo místico'], 'magma': ['Lava solidificada'],
    'water': ['Oceano', 'Costa', 'Oceano congelado'],
}
rows = [dict(stem=r['stem'], name=r['name'], biomes=biomes[r['stem']]) for r in manifest['assets']]
html = '''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Aetherlands · Terrenos em pixel art</title>
<style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#171e1c;color:#e3e9df}*{box-sizing:border-box}body{margin:0}main{max-width:1440px;margin:auto;padding:32px 24px 70px}h1{font-size:clamp(25px,4vw,40px);margin:8px 0 16px;letter-spacing:-1px}h2{font-size:24px;margin:36px 0 14px}p{color:#b7c4b5;line-height:1.6;max-width:850px}small,.eyebrow{color:#a8bb9b}.eyebrow{letter-spacing:2px;font-size:12px}button,a{font:inherit;color:inherit}button{border:1px solid #586452;background:#293326;padding:9px 14px;border-radius:6px;cursor:pointer}button[aria-pressed=true]{background:#c1d2a5;color:#18201a}button:focus-visible,a:focus-visible{outline:3px solid #b3ce91;outline-offset:3px}.controls{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin:18px 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px}.card{background:#222a24;border:1px solid #3e493c;border-radius:9px;overflow:hidden}.swatch{height:220px;background-repeat:repeat;background-position:center;image-rendering:pixelated}.info{padding:14px}.info h3{font-size:17px;margin:0 0 8px}.info p{font-size:13px;margin:0;min-height:40px}.info a{font-size:12px;color:#c1d2a5}.preview{display:block;width:100%;border:1px solid #3e493c;border-radius:9px}.renders{display:grid;grid-template-columns:1fr 1fr;gap:18px}.renders img{width:100%;border-radius:8px}.renders p{font-size:14px;margin:8px 0}.legend{display:grid;grid-template-columns:repeat(5,1fr);gap:6px;font-size:12px;color:#becbb8;margin-top:12px}.legend span{padding:8px;background:#222a24}a{color:#c1d2a5}.downloads{display:flex;gap:24px;flex-wrap:wrap;margin-top:24px}@media(max-width:700px){.renders{grid-template-columns:1fr}.legend{font-size:10px}.swatch{height:200px}}
</style>
<main>
<div class="eyebrow">AETHERLANDS · TERRENOS</div>
<h1>O mapa na mesma linguagem do elenco.</h1>
<p>Quinze materiais em pixel art, com paletas naturais e formas simples. Grama, folhas, areia, neve, gelo, rochas e solos mágicos mantêm os biomas legíveis junto das árvores e dos personagens.</p>
<h2>Materiais</h2>
<div class="controls"><span>Visualização:</span><button id="single" aria-pressed="true">Textura inteira</button><button id="repeat" aria-pressed="false">Repetição 3 × 3</button></div>
<div id="grid" class="grid"></div>
<h2>Comparação no Godot</h2>
<p>Os mesmos terrenos, enquadramento e iluminação. Cada grupo mostra um dos 25 tipos de terreno, na ordem abaixo.</p>
<div class="controls"><button data-shot="terrain_before.png" aria-pressed="false">Chão anterior</button><button data-shot="terrain_pixel_biomes.png" aria-pressed="true">Chão em pixel art</button><button data-shot="terrain_pixel_with_nature.png" aria-pressed="false">Com vegetação</button></div>
<img id="comparison" class="preview" src="terrain_pixel_biomes.png" alt="Visão geral dos terrenos em pixel art renderizados no Godot">
<div class="legend">__LEGEND__</div>
<h2>Escala junto dos personagens</h2>
<img class="preview" src="terrain_pixel_characters.png" alt="Colonizadores das quatro civilizações sobre a nova grama, junto do gelo e da floresta">
<p>Os pixels seguem a mesma escala no chão e nas paredes. A água conserva as ondas e a transparência; o magma líquido conserva sua animação.</p>
<div class="downloads"><a href="terrain_pixel_contact_sheet.png">Prancha dos 15 materiais</a><a href="../../assets/textures/terrain/pixel_v1/README.md">Arquivos para o jogo</a><a href="generation_manifest.json">Prompts usados na geração</a><a href="README.md">Inventário e validação</a></div>
</main>
<script>
const materials=__DATA__;
const grid=document.getElementById('grid');
for(const m of materials){const card=document.createElement('article');card.className='card';const swatch=document.createElement('div');swatch.className='swatch';swatch.style.backgroundImage=`url("../../assets/textures/terrain/pixel_v1/${m.stem}_albedo.png")`;swatch.style.backgroundSize='220px 220px';swatch.setAttribute('role','img');swatch.setAttribute('aria-label',m.name);const info=document.createElement('div');info.className='info';const title=document.createElement('h3');title.textContent=m.name;const description=document.createElement('p');description.textContent=m.biomes.join(' · ');const link=document.createElement('a');link.href=`../../assets/textures/terrain/pixel_v1/${m.stem}_albedo.png`;link.textContent='Abrir PNG';info.append(title,description,link);card.append(swatch,info);grid.append(card);}
function repeatMode(repeat){document.getElementById('single').setAttribute('aria-pressed',String(!repeat));document.getElementById('repeat').setAttribute('aria-pressed',String(repeat));for(const el of document.querySelectorAll('.swatch')){const size=el.clientHeight/(repeat?3:1);el.style.backgroundSize=`${size}px ${size}px`;}}
document.getElementById('single').onclick=()=>repeatMode(false);document.getElementById('repeat').onclick=()=>repeatMode(true);window.addEventListener('resize',()=>repeatMode(document.getElementById('repeat').getAttribute('aria-pressed')==='true'));repeatMode(false);
for(const button of document.querySelectorAll('[data-shot]'))button.onclick=()=>{document.getElementById('comparison').src=button.dataset.shot;for(const other of document.querySelectorAll('[data-shot]'))other.setAttribute('aria-pressed',String(other===button));};
</script></html>'''
terrain_names = ['Oceano','Neve','Tundra','Taiga','Deserto','Savana','Selva','Planície','Pradaria','Floresta','Colinas','Montanhas','Oceano congelado','Gelo eterno','Lava','Campos de cristal','Mar de lava','Rocha vulcânica','Colinas vulcânicas','Picos vulcânicos','Cinzas vulcânicas','Picos de cristal','Solo místico','Fonte mística','Costa']
html = html.replace('__DATA__', json.dumps(rows, ensure_ascii=False)).replace('__LEGEND__', ''.join('<span>'+name+'</span>' for name in terrain_names))
(WORK / 'index.html').write_text(html, encoding='utf-8')
table = '\n'.join('| '+r['name']+' | `'+r['stem']+'_albedo.png` | '+', '.join(r['biomes'])+' |' for r in rows)
readme = '''# Terrenos em pixel art — v1

15 materiais originais gerados com a ferramenta integrada `image_gen`, organizados em 14 superfícies de chão e um detalhe de água. O jogo usa 25 tipos de terreno: 21 terrestres e quatro líquidos. Biomas da mesma família compartilham a superfície, com sua tintura e seus efeitos específicos.

| Material | PNG | Uso |
| --- | --- | --- |
'''+table+'''

O **mar de lava** continua no shader líquido procedural, com a animação existente; o PNG `magma` é usado nos tiles sólidos de lava. Oceano, costa e oceano congelado recebem o detalhe pixelizado de água, preservando profundidade, ondas, espuma e congelamento. O gelo terrestre tem sua própria textura. As falésias recebem rocha, as encostas respeitam a família mineral e os picos conservam a neve.

## Uso no projeto

- PNGs RGB de **128 × 128**, opacos, até **24 cores** por material.
- **64 pixels por unidade** de mundo; repetição a cada duas unidades, projetada em espaço mundo. Mesma densidade no chão e nas paredes, sem UVs esticados.
- Filtro `nearest_mipmap`, com mipmaps: pixels nítidos no zoom próximo e menos cintilação na visão do mapa.
- `terrain_surfaces.res`: uma `Texture2DArray` com 14 camadas, sem compressão de blocos destrutiva. A textura de água é independente. A seleção fica em `INSTANCE_CUSTOM.b` do mesmo MultiMesh existente: não cria uma draw call por bioma.
- `TerrainTextureCatalog.gd` define a ordem das camadas. Alterar essa ordem exige reconstruir a array e atualizar o catálogo juntos.
- Alterações de terreno por magia atualizam a superfície, a altura e os efeitos, mantendo a variação da instância. Saves, IDs de bioma e geração procedural permanecem compatíveis.
- Os JPEGs anteriores foram preservados, mas o material do mapa não os carrega. Normal e roughness fotográficas continuam sem uso.
- O preset Windows exporta todos os recursos: array e PNGs acompanham o jogo; não há dependência do JSON de revisão em runtime.

## Revisão e reconstrução

A galeria local `art_source/terrain_pixel_review/index.html` exibe cada material, repetição 3 × 3, comparação antes/depois e capturas com os modelos existentes. Os originais de geração ficam em `sources/`; os prompts completos estão em `generation_manifest.json`. Os PNGs do jogo foram reduzidos com nearest e quantizados sem dithering; os originais continuam preservados.

`package_terrain_pixels.py` prepara os PNGs e o inventário. `run_terrain_pixel_review.py` constrói a array, verifica os pixels das camadas e captura o resultado no renderer nativo do Godot. A construção da array exige GPU; o renderer dummy de `--headless` não fornece o readback necessário. Os testes de regressão, por sua vez, podem rodar headless com `check_terrain_pixel_regressions.py`.

Validação: PNGs distintos e opacos; resolução, paleta, hashes e bordas de repetição conferidos. Renderização nativa Forward+ com os 25 tipos de terreno, 21 superfícies terrestres, quatro capturas e transformação dinâmica de terreno. Relatórios em `docs/terrain_pixel_*_validation.json`.

Regressão: **167 testes funcionais passaram** (materiais, geração, movimento, modificação de terreno e vegetação). O único teste restante exige geração do mapa especial em menos de 5 s e falhou. Na comparação com a mesma seed 999 e os mesmos 26.880 tiles, o chão fotográfico levou 6.786/7.182 ms e o chão pixelizado 6.461/6.553 ms: ambos ultrapassam esse limite, sem piora observada causada pelos novos materiais. Há carga de outros processos durante a medição; esses tempos são de CPU e não medem FPS. O log combinado GUT também avisa sobre 46 objetos e sete recursos no encerramento; o teste isolado dos materiais e a revisão nativa terminaram sem esses avisos. Nenhum limite de teste ou parâmetro do gerador foi alterado.
'''
(DEST / 'README.md').write_text(readme, encoding='utf-8')
(WORK / 'README.md').write_text(readme+'\n[Galeria](index.html) · [PNGs de runtime](../../assets/textures/terrain/pixel_v1/) · [Prompts completos](generation_manifest.json)\n', encoding='utf-8')
readme_path = ROOT / 'README.md'
text = readme_path.read_text(encoding='utf-8')
start = text.index('- Shader proprio (`shaders/terrain.gdshader`)')
end = text.index('Normal corrigida por face', start)
text = text[:start]+'''- Shader proprio (`shaders/terrain.gdshader`) em Forward+, com 15 materiais
  em **pixel art** coerentes com as árvores e os personagens blocky.
  Uma array de 14 superfícies atende os biomas terrestres; uma textura
  separada detalha a água. Projeção em espaço mundo mantém 64 pixels por
  unidade no chão e nas paredes, com filtro nearest e mipmaps. Ondas,
  congelamento, magma líquido, neve nos picos e brilho mágico continuam
  nos shaders. As fotografias anteriores foram preservadas como fontes,
  mas não são carregadas pelo material atual. Inventário e revisão:
  [`pixel_v1/README.md`](assets/textures/terrain/pixel_v1/README.md).
  '''+text[end:]
text = text.replace('**Integrado**: o terreno (`shaders/terrain.gdshader`) agora projeta a', '**Histórico, substituído por pixel art v1**: o terreno (`shaders/terrain.gdshader`) projetava a', 1)
text = text.replace('**Integrado**: os 4 biomas especiais (roadmap item 27', '**Histórico, substituído por pixel art v1**: os 4 biomas especiais (roadmap item 27', 1)
text = text.replace('2000+ materiais PBR CC0. **Usado**:', '2000+ materiais PBR CC0. **Fontes antigas preservadas**:', 1)
readme_path.write_text(text, encoding='utf-8')
print(json.dumps(dict(status='PASS', cards=len(rows), terrain_inventory=len(terrain_names))))

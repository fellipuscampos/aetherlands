"""Write the local review for the static Arcanism manifestation."""
from pathlib import Path
import json,html
ROOT=Path(__file__).resolve().parents[2]
STEM='elemental_primordial_blocky_v4'; ASSET=ROOT/'assets/generated/grand_manifestations'/STEM
OUT=ROOT/'art_source'/f'{STEM}_review'
report=json.loads((ASSET/(STEM+'_report.json')).read_text(encoding='utf-8'))
assert json.loads((ASSET/'godot_validation.json').read_text(encoding='utf-8'))['status']=='PASS'
prefix=f'../../assets/generated/grand_manifestations/{STEM}/'
views=[('godot_three_quarter','Godot · três quartos'),('front','Godot · frente'),('godot_game_view','Godot · câmera do mapa'),('back','Godot · costas'),('side','Godot · perfil'),('three_quarter','Blender · três quartos')]
buttons=''
for i,(stem,label) in enumerate(views):
    assert (ASSET/'previews'/f'{stem}.png').is_file()
    src=prefix+f'previews/{stem}.png'
    buttons+=f'<button data-src="{src}" aria-pressed="{str(i==0).lower()}"><img src="{src}" alt=""><span>{html.escape(label)}</span></button>'
page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Primordial dos Elementos</title><style>
:root{color-scheme:dark;font:16px/1.6 system-ui;background:#131a29;color:#e4ecf6}*{box-sizing:border-box}body{max-width:1350px;margin:auto;padding:32px}h1{font-size:clamp(28px,5vw,44px);line-height:1.15}p{color:#b3c2d9;max-width:900px}a{color:#9dcafa}main{display:grid;grid-template-columns:minmax(0,1fr) 280px;gap:24px}figure{margin:0;background:#26303e;border:1px solid #3a4c68;border-radius:10px;overflow:hidden}#hero{width:100%;display:block;aspect-ratio:1;object-fit:contain}figcaption{padding:16px}.views{display:grid;grid-template-columns:1fr 1fr;gap:10px}button{padding:0;border:1px solid #3a4c68;border-radius:6px;background:#26303e;color:#d5e0f1;cursor:pointer;overflow:hidden;text-align:left}button[aria-pressed=true]{border-color:#8dbff5}button img{width:100%;display:block;aspect-ratio:1}button span{display:block;padding:9px;font-size:12px}aside a{display:block;margin:12px 0}aside p{font-size:14px}.tags{display:flex;gap:10px;flex-wrap:wrap;margin:20px 0 26px}.tags span{border:1px solid #3a4c68;padding:7px 12px;border-radius:6px;font-size:13px}.lineup{width:100%;display:block;border-radius:10px}.note{font-size:13px;color:#839abb}@media(max-width:750px){body{padding:20px}main{grid-template-columns:1fr}}
</style><header><p>Elementalismo · Grande invocação</p><h1>Primordial dos Elementos</h1><p>Uma criatura rochosa corcunda, com membros dianteiros enormes e patas traseiras menores. Placas de carvão e pedra envolvem uma cabeça pequena de seis olhos luminosos e um núcleo cúbico ciano encaixado no tórax. Cinco grandes colunas de cristal saem das costas, com dois afloramentos nos ombros. A referência enviada orienta a silhueta e a paleta; os volumes têm seções quadradas e recortes em degraus.</p><div class="tags"><span>3 metros</span><span>Mini boss</span><span>Núcleo ciano</span><span>Blocky / voxel</span><span>Modelo estático</span></div></header>
<main><figure><img id="hero" src="PREFIXpreviews/godot_three_quarter.png" alt="Primordial dos Elementos"><figcaption id="caption">Godot · três quartos</figcaption></figure><aside><div class="views">BUTTONS</div><h2>Arquivos</h2><a href="PREFIXelemental_primordial_blocky_v4.glb">Modelo para Godot · GLB</a><a href="PREFIXelemental_primordial_blocky_v4.blend">Fonte editável · Blender</a><a href="PREFIXgodot_validation.json">Conferência no Godot</a><p>TRIANGLES triângulos · 1 malha · 1 material · textura pixelada com filtro NEAREST.</p><p>Revisão no editor: <code>scenes/art_review/ElementalPrimordialModelReviewV4.tscn</code>. F6 abre a cena; setas giram e R restaura.</p></aside></main>
<h2>Escala e referências do jogo</h2><p>Elementalista humano, Primordial dos Elementos e Arconte do Véu, na mesma escala, câmera e iluminação do Godot. O elementalista e os edifícios atuais da escola fornecem a paleta e os quatro focos elementais. A referência enviada orienta o corpo corcunda, os membros enormes, a cabeça abrigada e os cristais das costas; o jogo orienta os volumes blocky e a escala.</p><a href="comparison.png"><img class="lineup" src="comparison.png" alt="Elementalista, Primordial e Arconte na mesma escala"></a>
<p class="note">Modelo compartilhado pelas civilizações, com articulações preparadas. O giro completo do núcleo foi conferido contra a geometria real do corpo mineral.</p>
<script>document.querySelectorAll('button[data-src]').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('button[data-src]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));document.querySelector('#hero').src=button.dataset.src;document.querySelector('#caption').textContent=button.textContent;}));</script></html>'''
assert (OUT/'comparison.png').is_file()
page=page.replace('PREFIX',prefix).replace('BUTTONS',buttons).replace('TRIANGLES',str(report['triangles']))
(OUT/'index.html').write_text(page,encoding='utf-8')
(ASSET/'README.md').write_text(f'''# Primordial dos Elementos

Grande manifestação do Elementalismo, compartilhada pelas civilizações. Modelo estático blocky de 3 m, com pés no plano do solo.

Criatura rochosa quadrúpede de 3 metros, inspirada na referência enviada: corpo corcunda, enormes membros dianteiros, patas traseiras menores, cabeça de seis olhos ciano, placas de pedra escura e grandes cristais ciano enraizados nas costas. O núcleo cúbico fica encaixado no tórax. A paleta se baseia no elementalista e nos focos dos edifícios atuais; o corpo segue a linguagem blocky dos monstros atuais.

- {report['parts']} peças editáveis; {report['triangles']} triângulos; {len(report['prepared_bones'])} articulações preparadas.
- 1 malha exportada, 1 material, atlas de {report['atlas_size']} px e densidade 64 px/m com filtro NEAREST.
- Frente Blender -Y / Godot +Z; raiz em (0,0,0).
- GLB com cor e emissão embutidas; fonte Blender com apenas a cena do Primordial e seu estúdio.
- Giro completo do núcleo conferido contra as massas elementais nos três eixos, em 144 ângulos.
- `godot_validation.json`: escala, skin, texturas, material e revisão verificados nativamente.
- Revisão: `scenes/art_review/ElementalPrimordialModelReviewV4.tscn`.
- Galeria: `art_source/{STEM}_review/index.html`.
''',encoding='utf-8')
print(OUT/'index.html')

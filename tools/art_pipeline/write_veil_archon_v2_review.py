"""Write the local review for the static Arcanism manifestation."""
from pathlib import Path
import json,html
ROOT=Path(__file__).resolve().parents[2]
STEM='veil_archon_blocky_v2'; ASSET=ROOT/'assets/generated/grand_manifestations'/STEM
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
page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Arconte do Véu</title><style>
:root{color-scheme:dark;font:16px/1.6 system-ui;background:#131a29;color:#e4ecf6}*{box-sizing:border-box}body{max-width:1350px;margin:auto;padding:32px}h1{font-size:clamp(28px,5vw,44px);line-height:1.15}p{color:#b3c2d9;max-width:900px}a{color:#9dcafa}main{display:grid;grid-template-columns:minmax(0,1fr) 280px;gap:24px}figure{margin:0;background:#26303e;border:1px solid #3a4c68;border-radius:10px;overflow:hidden}#hero{width:100%;display:block;aspect-ratio:1;object-fit:contain}figcaption{padding:16px}.views{display:grid;grid-template-columns:1fr 1fr;gap:10px}button{padding:0;border:1px solid #3a4c68;border-radius:6px;background:#26303e;color:#d5e0f1;cursor:pointer;overflow:hidden;text-align:left}button[aria-pressed=true]{border-color:#8dbff5}button img{width:100%;display:block;aspect-ratio:1}button span{display:block;padding:9px;font-size:12px}aside a{display:block;margin:12px 0}aside p{font-size:14px}.tags{display:flex;gap:10px;flex-wrap:wrap;margin:20px 0 26px}.tags span{border:1px solid #3a4c68;padding:7px 12px;border-radius:6px;font-size:13px}.lineup{width:100%;display:block;border-radius:10px}.note{font-size:13px;color:#839abb}@media(max-width:750px){body{padding:20px}main{grid-template-columns:1fr}}
</style><header><p>Arcanismo · Grande invocação</p><h1>Arconte do Véu</h1><p>Uma entidade flutuante com capuz aberto, ombros cerimoniais de prata e um manto azul-escuro com dobras e barra irregular. O núcleo cúbico azul ocupa a abertura do capuz; mãos quadradas simples e fragmentos de portal completam sua silhueta. A figura segue a identidade do Arcanismo: espaço, teleporte e interferência mágica.</p><div class="tags"><span>3 metros</span><span>Mini boss</span><span>Núcleo azul</span><span>Blocky / voxel</span><span>Modelo estático</span></div></header>
<main><figure><img id="hero" src="PREFIXpreviews/godot_three_quarter.png" alt="Arconte do Véu"><figcaption id="caption">Godot · três quartos</figcaption></figure><aside><div class="views">BUTTONS</div><h2>Arquivos</h2><a href="PREFIXveil_archon_blocky_v2.glb">Modelo para Godot · GLB</a><a href="PREFIXveil_archon_blocky_v2.blend">Fonte editável · Blender</a><a href="PREFIXgodot_validation.json">Conferência no Godot</a><p>TRIANGLES triângulos · 1 malha · 1 material · textura pixelada com filtro NEAREST.</p><p>Revisão no editor: <code>scenes/art_review/VeilArchonModelReviewV2.tscn</code>. F6 abre a cena; setas giram e R restaura.</p></aside></main>
<h2>Escala e referências do jogo</h2><p>Arcanista humano, Arconte do Véu e Avatar da Natureza, na mesma escala, câmera e iluminação do Godot. A paleta azul e prata vem do arcanista atual.</p><a href="comparison.png"><img class="lineup" src="comparison.png" alt="Arcanista, Arconte e Avatar na mesma escala"></a>
<p class="note">Modelo compartilhado pelas civilizações, com articulações preparadas. O giro completo do núcleo foi conferido contra a geometria real do manto, da coroa e do portal.</p>
<script>document.querySelectorAll('button[data-src]').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('button[data-src]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));document.querySelector('#hero').src=button.dataset.src;document.querySelector('#caption').textContent=button.textContent;}));</script></html>'''
assert (OUT/'comparison.png').is_file()
page=page.replace('PREFIX',prefix).replace('BUTTONS',buttons).replace('TRIANGLES',str(report['triangles']))
(OUT/'index.html').write_text(page,encoding='utf-8')
(ASSET/'README.md').write_text(f'''# Arconte do Véu

Grande manifestação do Arcanismo, compartilhada pelas civilizações. Modelo estático blocky de 3 m, suspenso 0,35 m acima do solo.

Manto azul-escuro com dobras e barra irregular, capuz aberto sem rosto, placas de ombro cerimoniais em prata, mãos quadradas suspensas, núcleo cúbico azul exposto e um portal dimensional fragmentado. A paleta segue o arcanista humano atual; o conceito segue os feitiços de mobilidade e interferência da escola.

- {report['parts']} peças editáveis; {report['triangles']} triângulos; {len(report['prepared_bones'])} articulações preparadas.
- 1 malha exportada, 1 material, atlas de {report['atlas_size']} px e densidade 64 px/m com filtro NEAREST.
- Frente Blender -Y / Godot +Z; raiz em (0,0,0).
- GLB com cor e emissão embutidas; fonte Blender com apenas a cena do Arconte e seu estúdio.
- Giro completo do núcleo conferido contra as peças sólidas em 48 ângulos.
- `godot_validation.json`: escala, skin, texturas, material e revisão verificados nativamente.
- Revisão: `scenes/art_review/VeilArchonModelReviewV2.tscn`.
- Galeria: `art_source/{STEM}_review/index.html`.
''',encoding='utf-8')
print(OUT/'index.html')

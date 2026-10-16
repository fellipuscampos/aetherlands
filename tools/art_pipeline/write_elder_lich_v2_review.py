"""Write the revised Lich gallery with matched native before/after images."""
import html
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
STEM='elder_lich_blocky_v2'
ASSET=ROOT/'assets/generated/grand_manifestations'/STEM
OUT=ROOT/'art_source'/f'{STEM}_review'
report=json.loads((ASSET/(STEM+'_report.json')).read_text(encoding='utf-8'))
validation=json.loads((ASSET/'godot_validation.json').read_text(encoding='utf-8'))
assert validation['status']=='PASS'
prefix='../../assets/generated/grand_manifestations/'+STEM+'/'
views=[
    (prefix+'previews/godot_three_quarter.png','Godot · três quartos'),
    (prefix+'previews/front.png','Godot · frente'),
    ('skull_detail.png','Godot · detalhe do crânio'),
    (prefix+'previews/godot_game_view.png','Godot · câmera do mapa'),
    (prefix+'previews/back.png','Godot · costas'),
    (prefix+'previews/side.png','Godot · perfil'),
    (prefix+'previews/three_quarter.png','Blender · três quartos'),
]
for image,_ in views:
    assert (OUT/image).resolve().is_file(),image
assert (OUT/'comparison_after.png').is_file()
assert (OUT/'../elder_lich_style_review/lich.png').resolve().is_file()
buttons=''.join(f'<button data-src="{html.escape(image)}" aria-pressed="{str(i==0).lower()}"><img src="{image}" alt=""><span>{label}</span></button>' for i,(image,label) in enumerate(views))
page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Lich Ancião · revisão 2</title><style>
:root{color-scheme:dark;font:16px/1.6 system-ui,sans-serif;background:#14131c;color:#ece9df}*{box-sizing:border-box}body{max-width:1350px;margin:auto;padding:32px}h1{font-size:clamp(28px,5vw,44px);line-height:1.15}h2{font-size:23px;margin-top:36px}p{color:#bbc0ce;max-width:900px}a{color:#a5d8b9}main{display:grid;grid-template-columns:minmax(0,1fr) 280px;gap:24px}figure{margin:0;background:#202633;border:1px solid #394050;border-radius:10px;overflow:hidden}#hero{width:100%;display:block;aspect-ratio:1;object-fit:contain}figcaption{padding:16px}.views{display:grid;grid-template-columns:1fr 1fr;gap:10px}button{padding:0;border:1px solid #394050;border-radius:6px;background:#202633;color:#d6dbe3;cursor:pointer;overflow:hidden;text-align:left}button[aria-pressed="true"]{border-color:#92c7a8}button img{width:100%;display:block;aspect-ratio:1}button span{display:block;padding:9px;font-size:12px}aside a{display:block;margin:12px 0}aside p{font-size:14px}.tags{display:flex;gap:10px;flex-wrap:wrap;margin:20px 0 26px}.tags span{border:1px solid #51475d;padding:7px 12px;border-radius:6px;font-size:13px}.compare{position:relative;max-width:850px;aspect-ratio:1;background:#52627a;border-radius:10px;overflow:hidden}.compare img{width:100%;height:100%;display:block}.compare .new{position:absolute;inset:0;clip-path:inset(0 50% 0 0)}.compare .line{position:absolute;left:50%;top:0;bottom:0;width:2px;background:#d6dbe3;pointer-events:none}.slider{display:block;width:min(850px,100%);margin:14px 0}.lineup{width:100%;display:block;border-radius:10px}.note{font-size:13px;color:#8795a6;overflow-wrap:anywhere}@media(max-width:750px){body{padding:20px}main{grid-template-columns:1fr}}
</style><header><p>Necromancia · Grande invocação · Revisão 2</p><h1>Lich Ancião</h1><p>Crânio revisado a partir do esqueleto atual: órbitas amplas, cavidade nasal pintada, dentes e mandíbula separada. Vestes roxas com variação de pixels, dobras e desgaste, seguindo a paleta do necromante humano. O mago espectral mantém seu cajado, grimório e corpo flutuante.</p><div class="tags"><span>3 metros</span><span>Mini boss</span><span>Blocky / voxel</span><span>Modelo estático</span></div></header>
<main><figure><img id="hero" src="PREFIXpreviews/godot_three_quarter.png" alt="Lich Ancião com crânio e vestes revisados"><figcaption id="caption">Godot · três quartos</figcaption></figure><aside><div class="views">BUTTONS</div><h2>Arquivos</h2><a href="PREFIXelder_lich_blocky_v2.glb">Modelo para Godot · GLB</a><a href="PREFIXelder_lich_blocky_v2.blend">Fonte editável · Blender</a><a href="PREFIXgodot_validation.json">Validação no Godot</a><p>1.404 triângulos · 1 malha · 1 material · texturas com filtro de pixels.</p><p>Para inspecionar no editor: <code>scenes/art_review/ElderLichModelReviewV2.tscn</code>, F6. Setas giram o modelo; R restaura.</p></aside></main>
<h2>Antes e depois</h2><p>V2 à esquerda, V1 à direita. Arraste o controle para comparar o rosto e as vestes. As duas imagens foram renderizadas no Godot com a mesma câmera, iluminação e escala.</p>
<div class="compare"><img src="../elder_lich_style_review/lich.png" alt="Versão anterior do Lich"><img class="new" src="lich.png" alt="Nova versão do Lich"><div class="line"></div></div><label for="compare-slider">Quanto mostrar da versão nova</label><input class="slider" id="compare-slider" type="range" min="0" max="100" value="50">
<h2>Com os modelos de referência</h2><p>Esqueleto atual, necromante humano, Lich V2, Arcdemônio V5 e Serafim V4 na mesma escala.</p><a href="comparison_after.png"><img class="lineup" src="comparison_after.png" alt="Comparação entre os cinco modelos atuais"></a>
<p class="note">Modelo conferido no Blender e importado no Godot 4.7.1. A V1 está preservada. Esta etapa modifica o modelo; animações e integração da unidade ficam para as próximas etapas.</p>
<script>document.querySelectorAll('button[data-src]').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('button[data-src]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));document.querySelector('#hero').src=button.dataset.src;document.querySelector('#caption').textContent=button.textContent;}));document.querySelector('#compare-slider').addEventListener('input',event=>{const amount=Number(event.target.value);document.querySelector('.new').style.clipPath=`inset(0 ${100-amount}% 0 0)`;document.querySelector('.line').style.left=amount+'%';});</script></html>'''
page=page.replace('PREFIX',prefix).replace('BUTTONS',buttons)
(OUT/'index.html').write_text(page,encoding='utf-8')
(ASSET/'README.md').write_text('''# Lich Ancião — revisão 2

Grande invocação da necromancia: mago que transcendeu a morte, com capuz, ossos expostos, cajado e grimório. Modelo compartilhado pelas civilizações.

A revisão usa o crânio do Skeleton Warrior atual como referência para órbitas, cavidade nasal, dentes, mandíbula e pintura do osso. As vestes usam a paleta roxa do necromante humano, com grupos de pixels, dobras e barras gastas.

- Altura de 3 m; distância do solo de 0,20 m; frente Blender -Y / Godot +Z.
- 79 peças editáveis, 1.404 triângulos, 22 articulações preparadas, 1 malha exportada e 1 material.
- Atlas de 512 px, densidade de 64 px/m, filtro NEAREST; mapas de cor e emissão embutidos.
- `elder_lich_blocky_v2.blend`: cena isolada editável e estúdio.
- `elder_lich_blocky_v2.glb`: modelo estático, sem animações.
- `godot_validation.json`: geometria, escala, skin, textura e materiais conferidos na importação nativa.
- Cena de revisão: `scenes/art_review/ElderLichModelReviewV2.tscn` (F6; setas giram, R restaura).
- Galeria: `art_source/elder_lich_blocky_v2_review/index.html`, com comparação V1/V2 e referências atuais.

A V1 e os demais modelos estão preservados. Esta etapa não modifica o cadastro da unidade no jogo.
''',encoding='utf-8')
print(OUT/'index.html')

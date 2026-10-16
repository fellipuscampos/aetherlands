"""Publish the local model gallery after native Godot verification."""
from pathlib import Path
import json, html
ROOT=Path(__file__).resolve().parents[2]
STEM='nature_avatar_blocky_v2'
ASSET=ROOT/'assets/generated/grand_manifestations'/STEM
OUT=ROOT/'art_source'/f'{STEM}_review'
r=json.loads((ASSET/(STEM+'_report.json')).read_text(encoding='utf-8'))
v=json.loads((ASSET/'godot_validation.json').read_text(encoding='utf-8'))
assert v['status']=='PASS'
prefix=f'../../assets/generated/grand_manifestations/{STEM}/'
views=[('godot_three_quarter','Godot · três quartos'),('front','Godot · frente'),('godot_game_view','Godot · câmera do mapa'),('back','Godot · costas'),('side','Godot · perfil'),('three_quarter','Blender · três quartos')]
buttons=''
for i,(stem,label) in enumerate(views):
    assert (ASSET/'previews'/f'{stem}.png').is_file()
    src=prefix+f'previews/{stem}.png'
    buttons+=f'<button data-src="{src}" aria-pressed="{str(i==0).lower()}"><img src="{src}" alt=""><span>{html.escape(label)}</span></button>'
page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Avatar da Natureza</title><style>
:root{color-scheme:dark;font:16px/1.6 system-ui;background:#141c17;color:#e9eddf}*{box-sizing:border-box}body{max-width:1350px;margin:auto;padding:32px}h1{font-size:clamp(28px,5vw,44px);line-height:1.15}p{color:#b9c6b5;max-width:920px}a{color:#c9de97}main{display:grid;grid-template-columns:minmax(0,1fr) 280px;gap:24px}figure{margin:0;background:#26303e;border:1px solid #3d5140;border-radius:10px;overflow:hidden}#hero{width:100%;display:block;aspect-ratio:1;object-fit:contain}figcaption{padding:16px}.views{display:grid;grid-template-columns:1fr 1fr;gap:10px}button{padding:0;border:1px solid #3d5140;border-radius:6px;background:#26303e;color:#d6e3d4;cursor:pointer;overflow:hidden;text-align:left}button[aria-pressed=true]{border-color:#c9de97}button img{width:100%;display:block;aspect-ratio:1}button span{display:block;padding:9px;font-size:12px}aside a{display:block;margin:12px 0}aside p{font-size:14px}.tags{display:flex;gap:10px;flex-wrap:wrap;margin:20px 0 26px}.tags span{border:1px solid #3d5140;padding:7px 12px;border-radius:6px;font-size:13px}.refs{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-top:24px}.refs img{width:100%;display:block}.refs figcaption{font-size:14px}.note{font-size:13px;color:#8eab8e}@media(max-width:750px){body{padding:20px}main{grid-template-columns:1fr}.refs{grid-template-columns:1fr}}
</style><header><p>Druidismo · Grande invocação</p><h1>Avatar da Natureza</h1><p>Uma entidade de raízes com o corpo vazado, braços pesados e baixos, madeira envelhecida e galhos quebrados. Um arco de raízes envolve o núcleo cúbico verde exposto no alto do corpo. A silhueta segue a referência enviada, traduzida para a estética blocky do jogo.</p><div class="tags"><span>3 metros</span><span>Mini boss</span><span>Blocky / voxel</span><span>Modelo estático</span></div></header>
<main><figure><img id="hero" src="PREFIXpreviews/godot_three_quarter.png" alt="Avatar da Natureza"><figcaption id="caption">Godot · três quartos</figcaption></figure><aside><div class="views">BUTTONS</div><h2>Arquivos</h2><a href="PREFIXnature_avatar_blocky_v2.glb">Modelo para Godot · GLB</a><a href="PREFIXnature_avatar_blocky_v2.blend">Fonte editável · Blender</a><a href="PREFIXgodot_validation.json">Validação no Godot</a><p>TRIANGLES triângulos · 1 malha · 1 material · textura pixelada com filtro NEAREST.</p><p>Revisão no editor: <code>scenes/art_review/NatureAvatarModelReviewV2.tscn</code>. F6 abre a cena; setas giram e R restaura.</p></aside></main>
<h2>Referências do jogo</h2><p>Referência principal: conceito Root Brute Rot enviado pelo usuário. A madeira e o musgo seguem a identidade druídica e a escala das grandes manifestações do jogo.</p><div class="refs"><figure><img src="../../assets/generated/nature/temperate_forest_v1/models/tree_oak_a/previews/three_quarter.png" alt="Carvalho do jogo"><figcaption>Madeira e folhagem · carvalho atual</figcaption></figure><figure><img src="../../assets/generated/elves/elf_druid_v1/previews/three_quarter.png" alt="Druida élfico do jogo"><figcaption>Paleta · druida élfico</figcaption></figure><figure><img src="../../assets/generated/grand_manifestations/elder_lich_blocky_v3_animated/previews/godot_three_quarter.png" alt="Lich Ancião"><figcaption>Outra grande invocação · Lich Ancião</figcaption></figure></div>
<p class="note">Modelo estático conferido na importação nativa do Godot. Compartilhado pelas civilizações; articulações preparadas para a próxima etapa de animação.</p>
<script>document.querySelectorAll('button[data-src]').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('button[data-src]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));document.querySelector('#hero').src=button.dataset.src;document.querySelector('#caption').textContent=button.textContent;}));</script></html>'''
page=page.replace('PREFIX',prefix).replace('BUTTONS',buttons).replace('TRIANGLES',str(r['triangles']))
page=page.replace('elder_lich_blocky_v3_animated/previews/godot_three_quarter.png','elder_lich_blocky_v3_animated/previews/Idle.png')
for ref in ['../../assets/generated/nature/temperate_forest_v1/models/tree_oak_a/previews/three_quarter.png','../../assets/generated/elves/elf_druid_v1/previews/three_quarter.png','../../assets/generated/grand_manifestations/elder_lich_blocky_v3_animated/previews/Idle.png']:
    assert (OUT/ref).resolve().is_file(), ref
(OUT/'index.html').write_text(page,encoding='utf-8')
(ASSET/'README.md').write_text(f'''# Avatar da Natureza

Grande invocação druídica compartilhada pelas civilizações. Modelo estático blocky: raízes entrelaçadas, corpo vazado, arco superior, núcleo cúbico verde exposto, madeira envelhecida, musgo e galhos quebrados.

- Altura: 3 m; apoiado no solo; frente Blender -Y / Godot +Z.
- {r['parts']} peças editáveis; {r['triangles']} triângulos; {len(r['prepared_bones'])} articulações preparadas; 1 malha e 1 material.
- Atlas de {r['atlas_size']} px, 64 px/m, filtro NEAREST; cor e emissão embutidos no GLB.
- Fonte Blender contém apenas a cena do Avatar e seu estúdio.
- Revisão: `scenes/art_review/NatureAvatarModelReviewV2.tscn`.
- Galeria: `art_source/{STEM}_review/index.html`.
- Conferência nativa: `godot_validation.json`.
''',encoding='utf-8')
print(OUT/'index.html')

"""Package the static elder lich review using actual Blender and Godot views."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
STEM='elder_lich_blocky_v1'; ASSET=ROOT/'assets/generated/grand_manifestations'/STEM
OUT=ROOT/'art_source'/f'{STEM}_review'
report=json.loads((ASSET/(STEM+'_report.json')).read_text(encoding='utf-8'))
validation=json.loads((ASSET/'godot_validation.json').read_text(encoding='utf-8'))
assert validation['status']=='PASS' and report['animations']==0
prefix='../../assets/generated/grand_manifestations/'+STEM+'/'
views=[('godot_three_quarter','Godot · três quartos'),('front','Godot · frente'),('godot_game_view','Godot · câmera do mapa'),('back','Godot · costas'),('side','Godot · perfil'),('three_quarter','Blender · três quartos')]
assert all((ASSET/'previews'/(name+'.png')).exists() for name,_ in views)
buttons=''.join(f'<button data-view="{name}" aria-pressed="{str(i==0).lower()}"><img src="{prefix}previews/{name}.png" alt=""><span>{label}</span></button>' for i,(name,label) in enumerate(views))
html='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Lich Ancião · Grande invocação</title><style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#14131c;color:#ece9df}*{box-sizing:border-box}body{max-width:1180px;margin:auto;padding:32px}.eyebrow{font-size:12px;letter-spacing:.14em;color:#92c7a8;text-transform:uppercase}h1{font-size:clamp(28px,5vw,44px);margin:10px 0 12px}p{line-height:1.6;color:#bbc0ce;max-width:790px}.tags{display:flex;gap:10px;flex-wrap:wrap;margin:20px 0 26px}.tags span{border:1px solid #51475d;padding:7px 12px;border-radius:6px;font-size:13px}main{display:grid;grid-template-columns:minmax(0,1fr) 260px;gap:24px}figure{margin:0;background:#202633;border:1px solid #394050;border-radius:10px;overflow:hidden}#hero{width:100%;display:block;aspect-ratio:1;object-fit:contain}figcaption{padding:16px}.views{display:grid;grid-template-columns:1fr 1fr;gap:10px}button{padding:0;border:1px solid #394050;border-radius:6px;background:#202633;color:#d6dbe3;cursor:pointer;overflow:hidden;text-align:left}button[aria-pressed="true"]{border-color:#92c7a8}button img{width:100%;display:block;aspect-ratio:1}button span{display:block;padding:9px;font-size:12px}aside h2{font-size:16px;margin:22px 0 10px}aside p{font-size:14px}a{color:#a5d8b9;display:block;margin:12px 0}footer{font-size:13px;color:#8795a6;margin-top:24px;line-height:1.6}@media(max-width:750px){body{padding:20px}main{grid-template-columns:1fr}}</style>
<header><div class="eyebrow">Necromancia · Grande invocação</div><h1>Lich Ancião</h1><p>Um mago que sobreviveu à própria morte. O crânio permanece sob um capuz profundo; vestes roxas gastas, cajado ancestral e grimório aberto preservam sua identidade de estudioso. Sob o manto rasgado, o corpo se desfaz em vestígios espectrais.</p><div class="tags"><span>3 metros</span><span>Mini boss</span><span>Comum às civilizações</span><span>Blocky / voxel</span><span>Modelo</span></div></header>
<main><figure><img id="hero" src="PREFIXpreviews/godot_three_quarter.png" alt="Lich Ancião espectral, com capuz, crânio, vestes roxas, cajado e grimório"><figcaption id="caption">Godot · três quartos</figcaption></figure><aside><div class="views">BUTTONS</div><h2>Arquivos</h2><a href="PREFIXelder_lich_blocky_v1.glb">Modelo para Godot · GLB</a><a href="PREFIXelder_lich_blocky_v1.blend">Fonte editável · Blender</a><a href="PREFIXgodot_validation.json">Conferência no Godot</a><p>TRIANGLES triângulos · 1 malha · 1 material. Textura pixelada, faces planas e articulações preparadas.</p><h2>No editor</h2><p>Abra <code>scenes/art_review/ElderLichModelReview.tscn</code> e pressione F6. Setas giram o modelo; R restaura a orientação.</p></aside></main><footer>Etapa de modelagem, sem animações. A unidade anterior continua preservada.</footer><script>document.querySelectorAll('button[data-view]').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('button[data-view]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));document.querySelector('#hero').src='PREFIXpreviews/'+button.dataset.view+'.png';document.querySelector('#caption').textContent=button.textContent;}));</script></html>'''
html=html.replace('PREFIX',prefix).replace('BUTTONS',buttons).replace('TRIANGLES',f'{report["triangles"]:,}'.replace(',','.'))
(OUT/'index.html').write_text(html,encoding='utf-8')
(ASSET/'README.md').write_text(f'''# Lich Ancião — grande invocação da necromancia

Mago mortal transformado em uma existência espectral pela necromancia, em vez de uma entidade composta de mana. Capuz profundo, crânio cúbico envelhecido, olhos verdes, braços conectados, vestes roxas antigas com acabamentos de bronze gasto, cajado e grimório de pesquisa aberto. A parte inferior se dissolve sob as barras irregulares do manto, sem pernas ou botas comuns. Silhueta compartilhada por todas as civilizações.

- Altura: 3,00 m. Origem no terreno; menor ponto a 0,20 m do chão. Frente: Blender -Y / Godot +Z.
- {report['parts']} peças editáveis, {report['triangles']} triângulos, uma malha exportada, um material, atlas de {report['atlas_size']} px e filtro NEAREST.
- `{STEM}.blend`: cena isolada com peças editáveis, articulações preparadas e estúdio de apresentação.
- `{STEM}.glb`: modelo estático, texturas de cor e emissão embutidas, esqueleto preparado, sem animações.
- `godot_validation.json`: escala, geometria, skin, materiais, emissão e filtro pixelado conferidos na importação nativa.
- `previews`: vistas reais do Blender e Godot, incluindo frente, costas, perfil e câmera elevada.
- Cena de revisão: `scenes/art_review/ElderLichModelReview.tscn` (F6; setas giram, R restaura).

O Lich anterior, Serafim, Arcdemônio e demais cenas estão preservados. Esta etapa não altera UnitDatabase nem as regras da necromancia.
''',encoding='utf-8')
print(OUT/'index.html')

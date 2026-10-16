"""Create the review page for the reference wings and their feather texture."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
ASSET=ROOT/'assets/generated/grand_manifestations/seraph_blocky_v4'
OUT=ROOT/'art_source/seraph_blocky_v4_review'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'.gdignore').write_text('')
report=json.loads((ASSET/'seraph_blocky_v4_report.json').read_text(encoding='utf-8'))
validation=json.loads((ASSET/'godot_validation.json').read_text(encoding='utf-8'))
assert validation['status']=='PASS' and report['approved_center_parts_preserved']==30
prefix='../../assets/generated/grand_manifestations/seraph_blocky_v4/'
views=[('three_quarter','Blender · três quartos'),('front','Godot · frente'),
       ('godot_three_quarter','Godot · três quartos'),('back','Godot · costas'),
       ('side','Godot · perfil'),('godot_game_view','Godot · câmera do jogo')]
buttons=''.join(f'<button data-view="{name}" aria-pressed="{str(name=="three_quarter").lower()}"><img src="{prefix}previews/{name}.png" alt=""><span>{label}</span></button>' for name,label in views)
buttons+=f'<button data-view="rotation" aria-pressed="false"><img src="{prefix}previews/godot_three_quarter.png" alt=""><span>Rotação · 24 segundos</span></button>'
html='''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Serafim · Asas de marfim</title>
<style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#10151d;color:#ece9dd}*{box-sizing:border-box}
body{max-width:1180px;margin:auto;padding:32px}header{margin-bottom:24px}h1{font-size:clamp(28px,5vw,44px);margin:10px 0}p{line-height:1.6;color:#bbc5d2;max-width:780px}.eyebrow{font-size:12px;letter-spacing:.12em;color:#e3c071;text-transform:uppercase}
main{display:grid;grid-template-columns:minmax(0,1fr) 260px;gap:24px}figure{margin:0;background:#1b242f;border:1px solid #354150;border-radius:10px;overflow:hidden}
#hero,#rotation{width:100%;display:block;aspect-ratio:1;object-fit:contain}[hidden]{display:none!important}figcaption{padding:16px;color:#d6dbe3}.views{display:grid;grid-template-columns:1fr 1fr;gap:10px}
button{padding:0;border:1px solid #354150;border-radius:6px;background:#1b242f;color:#d6dbe3;cursor:pointer;overflow:hidden;text-align:left}button[aria-pressed="true"]{border-color:#e3c071;box-shadow:0 0 0 1px #e3c071}button img{width:100%;display:block;aspect-ratio:1}button span{display:block;font-size:12px;padding:9px}
aside h2{font-size:16px;margin:24px 0 8px}aside p{font-size:14px}a{color:#f0d48d}aside a{display:block;margin:12px 0}footer{font-size:13px;color:#8795a6;margin-top:24px;line-height:1.6}@media(max-width:750px){body{padding:20px}main{grid-template-columns:1fr}.views{grid-template-columns:repeat(3,1fr)}}
</style>
<header><div class="eyebrow">Escola sagrada · Grande manifestação</div><h1>Serafim · Asas de marfim</h1>
<p>Seis asas com base larga, borda serrilhada e penas externas irregulares. A textura usa um mosaico irregular de pixels de marfim, cinza-claro e bege, criado a partir da imagem de referência.</p>
<p>O cubo de energia, os nove cubos de apoio e o movimento das duas auréolas foram preservados. Altura: 3 metros.</p></header>
<main><figure><img id="hero" src="PREFIXpreviews/three_quarter.png" alt="Entidade sagrada blocky com seis asas de penas de marfim, cubos e auréolas douradas.">
<video id="rotation" hidden loop muted playsinline controls poster="PREFIXpreviews/godot_three_quarter.png" src="PREFIXpreviews/animations/Seraph_CoreOrbit.mp4"></video><figcaption id="caption">Blender · três quartos</figcaption></figure>
<aside><div class="views">BUTTONS</div><h2>Arquivos</h2><a href="PREFIXseraph_blocky_v4.glb">Modelo para o Godot · GLB</a><a href="PREFIXseraph_blocky_v4.blend">Fonte editável · Blender</a><a href="PREFIXpreviews/animations/Seraph_CoreOrbit.gif">Prévia animada · GIF</a><a href="PREFIXgodot_validation.json">Validação no Godot</a><a href="../seraph_blocky_v3_review/index.html">Versão anterior</a>
<p>TRIANGLES triângulos · 1 malha · 1 material.<br>Ciclo contínuo de 24 segundos; 577 poses verificadas.</p>
<h2>Revisão no editor</h2><p>Abra <code>scenes/art_review/SeraphModelV4Review.tscn</code> e pressione F6. Setas para girar; espaço para pausar.</p></aside></main>
<footer>Modelo compartilhado entre civilizações. Esta etapa inclui a revisão das asas e o giro do núcleo e das auréolas.</footer>
<script>
const hero=document.querySelector('#hero'),rotation=document.querySelector('#rotation'),caption=document.querySelector('#caption');
document.querySelectorAll('button[data-view]').forEach(button=>button.addEventListener('click',()=>{
 document.querySelectorAll('button[data-view]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));
 const moving=button.dataset.view==='rotation';hero.hidden=moving;rotation.hidden=!moving;
 if(moving){rotation.play().catch(()=>{});caption.textContent='Rotação do núcleo e das auréolas · Godot · 24 segundos';}
 else{rotation.pause();hero.src='PREFIXpreviews/'+button.dataset.view+'.png';caption.textContent=button.textContent;}
}));
</script></html>'''.replace('PREFIX',prefix).replace('BUTTONS',buttons).replace('TRIANGLES',f"{report['triangles']:,}".replace(',','.'))
(OUT/'index.html').write_text(html,encoding='utf-8')
triangles=f"{report['triangles']:,}".replace(',','.')
(ASSET/'README.md').write_text(f'''# Serafim — asas de marfim

Grande manifestação compartilhada entre civilizações, com 3,00 m de altura. As seis asas seguem o contorno da referência: base larga, borda inferior serrilhada e penas externas irregulares. A textura usa um mosaico irregular de pixels de marfim, cinza-claro e bege, criado com image_gen usando a imagem enviada como referência. As 30 peças do núcleo, dos cubos de apoio e das auréolas mantêm a geometria e os pivôs da V3.

- `seraph_blocky_v4.glb`: 1 malha, 1 material, {triangles} triângulos, 11 ossos, texturas embutidas de 1.024 px com filtro NEAREST.
- `wing_reference_texture.png`: mapa de textura criado com a ferramenta integrada image_gen; prompt completo em `wing_reference_texture_prompt.txt`.
- `seraph_blocky_v4.blend`: cena isolada com 36 peças editáveis. O estúdio não entra no GLB.
- `Seraph_CoreOrbit`: ciclo de 24 segundos. O cubo gira lentamente; as auréolas giram em eixos diferentes e sentidos opostos. As asas, os cubos de apoio e a raiz ficam fixos.
- `seraph_rotation_import.gd`: marca esse clipe como loop no Godot.
- Origem no terreno; folga mínima de 0,22 m. Escala de importação 1. Frente: Godot +Z / Blender -Y.
- `godot_validation.json`: verifica 577 poses, dimensões, rigidez, pivôs e continuidade do ciclo. As prévias animadas usam o GLB importado no Godot.
- Revisão: `scenes/art_review/SeraphModelV4Review.tscn` (F6; setas para girar; espaço para pausar).

Sem alterações na UnitDatabase. As versões anteriores e os outros modelos estão preservados.
''',encoding='utf-8')
assert (ASSET/'previews/animations/Seraph_CoreOrbit.mp4').exists()
assert all((ASSET/'previews'/(name+'.png')).exists() for name,_ in views)
print(OUT/'index.html')

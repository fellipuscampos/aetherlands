"""Local review of the approved wings, new energy cube and its slow rotation."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
ASSET=ROOT/'assets/generated/grand_manifestations/seraph_blocky_v3'
OUT=ROOT/'art_source/seraph_blocky_v3_review'
OUT.mkdir(parents=True,exist_ok=True); (OUT/'.gdignore').write_text('')
report=json.loads((ASSET/'seraph_blocky_v3_report.json').read_text(encoding='utf-8'))
validation=json.loads((ASSET/'godot_validation.json').read_text(encoding='utf-8'))
assert validation['status']=='PASS' and report['approved_wing_parts_preserved']==66
prefix='../../assets/generated/grand_manifestations/seraph_blocky_v3/'
views=[('three_quarter','Blender · três quartos'),('front','Godot · frente'),
       ('godot_three_quarter','Godot · três quartos'),('back','Godot · costas'),
       ('side','Godot · perfil'),('godot_game_view','Godot · câmera do jogo')]
buttons='<button type="button" data-view="rotation" aria-pressed="true"><img src="'+prefix+'previews/godot_three_quarter.png" alt=""><span>Rotação · 24 segundos</span></button>'
buttons+='\n'.join(f'<button type="button" data-view="{name}" aria-pressed="false"><img src="{prefix}previews/{name}.png" alt=""><span>{label}</span></button>' for name,label in views)
html='''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Serafim · Núcleo e auréolas</title>
<style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#10151d;color:#ece9dd}*{box-sizing:border-box}
body{max-width:1180px;margin:auto;padding:32px}header{margin-bottom:24px}.eyebrow{font-size:12px;letter-spacing:.15em;color:#e3c071;text-transform:uppercase}
h1{font-size:clamp(28px,5vw,44px);margin:10px 0 12px}p{line-height:1.6;color:#bbc5d2;max-width:780px}
.tags{display:flex;gap:10px;flex-wrap:wrap}.tags span{border:1px solid #46515e;padding:7px 12px;border-radius:6px;font-size:13px}
main{display:grid;grid-template-columns:minmax(0,1fr) 260px;gap:24px}.viewer{background:#1b242f;border:1px solid #354150;border-radius:10px;overflow:hidden}
#hero,#rotation{width:100%;height:auto;display:block;aspect-ratio:1;object-fit:contain}.viewer [hidden]{display:none!important}
figure{margin:0}figcaption{padding:16px;color:#d6dbe3}.views{display:grid;grid-template-columns:1fr 1fr;gap:10px}
button{padding:0;border:1px solid #354150;border-radius:6px;background:#1b242f;color:#d6dbe3;cursor:pointer;overflow:hidden;text-align:left}
button[aria-pressed="true"]{border-color:#e3c071;box-shadow:0 0 0 1px #e3c071}button img{width:100%;display:block;aspect-ratio:1}button span{display:block;font-size:12px;padding:9px}
aside h2{font-size:16px;margin:24px 0 8px}aside p{font-size:14px}a{color:#f0d48d}aside a{display:block;margin:12px 0}.status{color:#a0d2b4;font-size:13px}
footer{font-size:13px;color:#8795a6;margin-top:24px;line-height:1.6}@media(max-width:750px){body{padding:20px}main{grid-template-columns:1fr}.views{grid-template-columns:repeat(3,1fr)}}
</style>
<header><div class="eyebrow">Escola sagrada · Grande manifestação</div><h1>Serafim · Núcleo de luz</h1>
<p>Um cubo de energia sagrada gira entre duas auréolas douradas. Nove cubos atrás do núcleo sustentam os três pares de asas de marfim, com as penas escalonadas em camadas.</p>
<div class="tags"><span>3 metros</span><span>Comum às civilizações</span><span>Blocky / voxel</span><span>Núcleo e auréolas · ciclo de 24 s</span></div></header>
<main><figure class="viewer"><video id="rotation" autoplay loop muted playsinline controls poster="PREFIXpreviews/godot_three_quarter.png" src="PREFIXpreviews/animations/Seraph_CoreOrbit.mp4"></video>
<img id="hero" hidden src="PREFIXpreviews/three_quarter.png" alt="Serafim blocky com um cubo luminoso, duas auréolas douradas e seis asas em camadas."><figcaption id="caption">Rotação do núcleo e das auréolas · Godot · 24 segundos</figcaption></figure>
<aside><div class="views">BUTTONS</div><h2>Arquivos</h2>
<a href="PREFIXseraph_blocky_v3.glb">Modelo para o Godot · GLB</a><a href="PREFIXseraph_blocky_v3.blend">Fonte editável · Blender</a>
<a href="PREFIXpreviews/animations/Seraph_CoreOrbit.gif">Prévia animada · GIF</a>
<a href="PREFIXgodot_validation.json">Validação nativa no Godot</a><a href="../seraph_blocky_v2_review/index.html">Ver a versão anterior</a>
<p class="status">577 poses conferidas: ciclo contínuo, peças separadas e asas fixas.</p>
<p>4.200 triângulos · 1 malha · 1 material. Núcleo e auréolas com pivôs independentes.</p>
<h2>Revisão no editor</h2><p>Abra <code>scenes/art_review/SeraphModelV3Review.tscn</code> e pressione F6. Setas para girar o conjunto; espaço para pausar.</p></aside></main>
<footer>Esta revisão inclui o modelo e o movimento lento do núcleo e das auréolas. As outras animações e a integração da unidade ficam para a próxima etapa.</footer>
<script>
const hero=document.querySelector('#hero'),rotation=document.querySelector('#rotation'),caption=document.querySelector('#caption');
document.querySelectorAll('button[data-view]').forEach(button=>button.addEventListener('click',()=>{
 document.querySelectorAll('button[data-view]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));
 const moving=button.dataset.view==='rotation';hero.hidden=moving;rotation.hidden=!moving;
 if(moving){rotation.play().catch(()=>{});caption.textContent='Rotação do núcleo e das auréolas · Godot · 24 segundos';}
 else{rotation.pause();hero.src='PREFIXpreviews/'+button.dataset.view+'.png';caption.textContent=button.textContent;}
}));
</script></html>'''.replace('PREFIX',prefix).replace('BUTTONS',buttons)
(OUT/'index.html').write_text(html,encoding='utf-8')
(ASSET/'README.md').write_text('''# Serafim — núcleo sagrado e auréolas

Grande manifestação compartilhada entre civilizações, com 3,00 m de altura. As 66 peças de penas e bases das seis asas aprovadas na V2 têm exatamente a mesma geometria e posição. A revisão substitui o olho/relicário por um cubo de luz, nove cubos de apoio atrás dele e duas auréolas angulares concêntricas.

- `seraph_blocky_v3.glb`: 1 malha, 1 material, 4.200 triângulos, 11 ossos e texturas embutidas de 1.024 px com filtro NEAREST.
- `seraph_blocky_v3.blend`: cena isolada com 96 peças editáveis, pivôs e um estudo de rotação. Estúdio excluído do GLB.
- `Seraph_CoreOrbit`: um ciclo de 24 segundos. O cubo gira lentamente; as auréolas giram em eixos diferentes e sentidos opostos. As asas, os cubos de apoio e a raiz ficam fixos.
- `seraph_rotation_import.gd`: marca esse único clipe como loop no Godot.
- Origem no plano do terreno; folga mínima de 0,22 m. Escala de importação 1. Frente: Godot +Z / Blender -Y.
- Os limites radiais comprovam separação durante toda rotação: aproximadamente 14 cm entre cubo e auréola interna, 9,5 cm entre auréolas e 10 cm entre a auréola externa e as partes fixas.
- `godot_validation.json`: verificação de 577 poses, dimensões, materiais, rigidez, pivôs comuns e continuidade do ciclo. As prévias animadas usam o GLB importado no Godot.
- Revisão: `scenes/art_review/SeraphModelV3Review.tscn` (F6; setas para girar; espaço para pausar).

Esta etapa inclui apenas a revisão do modelo e o movimento solicitado para núcleo/auréolas. Não inclui locomoção, cura ou combate, e não altera UnitDatabase. As versões anteriores e os outros modelos continuam preservados.
''',encoding='utf-8')
assert (ASSET/'previews/animations/Seraph_CoreOrbit.mp4').exists()
assert all((ASSET/'previews'/(name+'.png')).exists() for name,_ in views)
print(OUT/'index.html')

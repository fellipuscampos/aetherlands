"""Package a model review with actual Blender and native Godot renders."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
STEM='archdemon_blocky_v2'
ASSET=ROOT/'assets/generated/grand_manifestations'/STEM
OUT=ROOT/'art_source/archdemon_blocky_v2_review'
report=json.loads((ASSET/(STEM+'_report.json')).read_text(encoding='utf-8'))
validation=json.loads((ASSET/'godot_validation.json').read_text(encoding='utf-8'))
assert validation['status']=='PASS' and report['animations']==0
prefix='../../assets/generated/grand_manifestations/'+STEM+'/'
views=[('godot_three_quarter','Godot · três quartos'),('front','Godot · frente'),
    ('godot_game_view','Godot · vista do jogo'),('back','Godot · costas'),
    ('side','Godot · perfil'),('three_quarter','Blender · três quartos')]
assert all((ASSET/'previews'/(name+'.png')).exists() for name,_ in views)
buttons='\n'.join(f'<button data-view="{name}" aria-pressed="{str(i==0).lower()}"><img src="{prefix}previews/{name}.png" alt=""><span>{label}</span></button>' for i,(name,label) in enumerate(views))
html='''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Arquidemônio · Grande manifestação infernal</title>
<style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#14131a;color:#eee9e5}*{box-sizing:border-box}
body{max-width:1180px;margin:auto;padding:32px}.eyebrow{font-size:12px;letter-spacing:.14em;color:#ef985e;text-transform:uppercase}
h1{font-size:clamp(28px,5vw,44px);margin:10px 0 12px}p{line-height:1.6;color:#bdc3d0;max-width:780px}
.tags{display:flex;gap:10px;flex-wrap:wrap;margin:20px 0 26px}.tags span{border:1px solid #50424a;padding:7px 12px;border-radius:6px;font-size:13px}
main{display:grid;grid-template-columns:minmax(0,1fr) 260px;gap:24px}figure{margin:0;background:#202331;border:1px solid #3c3e4e;border-radius:10px;overflow:hidden}
#hero{width:100%;aspect-ratio:1;object-fit:contain;display:block}figcaption{padding:16px;color:#d6dbe3}.views{display:grid;grid-template-columns:1fr 1fr;gap:10px}
button{padding:0;border:1px solid #3e3b49;border-radius:6px;background:#23222e;color:#d6dbe3;cursor:pointer;overflow:hidden;text-align:left}
button[aria-pressed="true"]{border-color:#ed9764;box-shadow:0 0 0 1px #ed9764}button img{width:100%;aspect-ratio:1;display:block}button span{display:block;font-size:12px;padding:9px}
aside h2{font-size:16px;margin:24px 0 8px}aside p{font-size:14px}aside a{display:block;color:#ffc59a;margin:12px 0}.status{color:#a0d2b4}
footer{margin-top:24px;color:#9399aa;font-size:13px;line-height:1.6}@media(max-width:750px){body{padding:20px}main{grid-template-columns:1fr}.views{grid-template-columns:repeat(3,1fr)}}
</style>
<header><div class="eyebrow">Escola infernal · Invocação máxima</div><h1>Arquidemônio</h1>
<p>Uma relíquia infernal suspensa: armadura ancestral oca, ombreiras inclinadas e punhos pesados envolvem um núcleo vermelho. Três faixas carmesim pendem abaixo do torso; fragmentos da armadura flutuam atrás dos ombros. Modelo inspirado na referência enviada.</p>
<div class="tags"><span>3 metros</span><span>Mini boss</span><span>Comum às civilizações</span><span>Blocky / voxel</span><span>Modelo estático</span></div></header>
<main><figure><img id="hero" src="PREFIXpreviews/godot_three_quarter.png" alt="Entidade infernal de armadura vazia, ombreiras largas, núcleo vermelho e três faixas pendentes."><figcaption id="caption">Godot · três quartos</figcaption></figure>
<aside><div class="views">BUTTONS</div><h2>Arquivos</h2>
<a href="PREFIXarchdemon_blocky_v2.glb">Modelo para Godot · GLB</a>
<a href="PREFIXarchdemon_blocky_v2.blend">Fonte editável · Blender</a>
<a href="PREFIXarchdemon_blocky_v2_report.json">Dados do modelo</a>
<a href="PREFIXgodot_validation.json">Validação nativa no Godot</a>
<p class="status">Escala, materiais, filtro pixelado e pesos rígidos conferidos.</p>
<p>1.416 triângulos · 1 malha · 1 material · Atlas de 1.024 px. Pivôs separados para o torso, a coroa vazia, o núcleo, as ombreiras, os punhos, os fragmentos e as faixas.</p>
<h2>Revisão no editor</h2><p>Abra <code>scenes/art_review/ArchdemonModelV2Review.tscn</code> e pressione F6. Setas para girar e R para restaurar a orientação.</p></aside></main>
<footer>Modelo pronto para a etapa de animação. O arquidemônio anterior continua preservado; este modelo ainda não substitui a unidade em jogo.</footer>
<script>
const hero=document.querySelector('#hero'),caption=document.querySelector('#caption');
document.querySelectorAll('button[data-view]').forEach(button=>button.addEventListener('click',()=>{
 document.querySelectorAll('button[data-view]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));
 hero.src='PREFIXpreviews/'+button.dataset.view+'.png';caption.textContent=button.textContent;
}));
</script></html>'''.replace('PREFIX',prefix).replace('BUTTONS',buttons)
(OUT/'index.html').write_text(html,encoding='utf-8')
(ASSET/'README.md').write_text('''# Arquidemônio — grande manifestação infernal

Modelo compartilhado entre as quatro civilizações, inspirado na referência de revenant enviada pelo usuário. Entidade suspensa de armadura ancestral oca, com ombreiras inclinadas, grandes punhos, um núcleo infernal vermelho, três faixas carmesim e quatro fragmentos flutuantes de armadura. Texturas quadradas de ferro e pedra em cinza azulado; a luz se concentra no núcleo.

- Altura total: **3,00 m**, da ponta da faixa inferior aos fragmentos superiores. Menor ponto a 0,20 m do chão; origem no plano do terreno. Escala nativa 1. Frente: Blender -Y / Godot +Z.
- 97 peças editáveis, 1.416 triângulos, 1 malha exportada, 1 material e atlas de 1.024 px com 64 pixels por metro e filtro NEAREST.
- `archdemon_blocky_v2.glb`: texturas de cor e emissão embutidas, pesos rígidos e esqueleto preparado. **Sem animações.**
- `archdemon_blocky_v2.blend`: somente a cena deste modelo, com peças editáveis, câmera e iluminação de apresentação. O estúdio não entra no GLB.
- 27 ossos: raiz, corpo, peito, coroa vazia, núcleo, ombreiras, antebraços, punhos, quatro fragmentos flutuantes e quatro segmentos em cada uma das três faixas. Cada vértice pertence integralmente a um osso; sem suavização ou deformação orgânica.
- `previews`: seis vistas do Blender e do Godot, incluindo uma câmera elevada para avaliar a leitura no mapa.
- `godot_validation.json`: importação nativa aprovada, conferindo dimensões, skin, texturas, emissão e cena de revisão.
- Revisão: `scenes/art_review/ArchdemonModelV2Review.tscn` (F6; setas para girar, R para restaurar).

O arquidemônio anterior, o Serafim, o Devorador de Mana e as outras cenas do Blender foram preservados. A UnitDatabase e as regras da escola infernal não foram alteradas nesta etapa de modelagem.
''',encoding='utf-8')
print(OUT/'index.html')

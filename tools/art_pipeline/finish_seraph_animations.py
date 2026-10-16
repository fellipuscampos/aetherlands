"""Encode native previews and write the four-animation review page."""
import json, shutil, subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

ROOT=Path(__file__).resolve().parents[2]
STEM='seraph_blocky_v4_animated'
ASSET=ROOT/'assets/generated/grand_manifestations'/STEM
OUT=ROOT/'art_source/seraph_blocky_v4_animated_review'
ANIM=ASSET/'previews/animations'; ANIM.mkdir(parents=True,exist_ok=True)
report=json.loads((ASSET/'godot_validation.json').read_text(encoding='utf-8'))
assert report['status']=='PASS'
ffmpeg=shutil.which('ffmpeg'); assert ffmpeg

def encode(clip):
    spec=report['previews'][clip]; frames=OUT/'native_frames'/clip
    assert len(list(frames.glob('*.png')))==spec['frames']
    command=[ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate',str(spec['fps']),
        '-start_number','1','-i',str(frames/'%04d.png'),'-frames:v',str(spec['frames'])]
    subprocess.run(command+['-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(ANIM/(clip+'.mp4'))],check=True)
    subprocess.run(command+['-filter_complex_threads','1','-filter_complex',
        '[0:v]split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none','-loop','0',str(ANIM/(clip+'.gif'))],check=True)
    return clip

with ThreadPoolExecutor(max_workers=2) as pool: assert set(pool.map(encode,['Idle','Walk','Attack','Spell']))==set(report['clips'])
(ANIM/'manifest.json').write_text(json.dumps(report['previews'],indent=2),encoding='utf-8')
prefix='../../assets/generated/grand_manifestations/'+STEM+'/'
descriptions={'Idle':'Flutuação suave e giro lento do núcleo e das auréolas.',
    'Walk':'Voo no lugar, com inclinação para a frente e batidas suaves das asas.',
    'Attack':'Preparação, impulso frontal do núcleo e recuperação.',
    'Spell':'Abertura das asas, auréola voltada para a frente e pulsos de energia sagrada.'}
clips={n:{'description':descriptions[n],'duration':report['clips'][n]['duration_s'],
          'loop':report['clips'][n]['loop']} for n in descriptions}
buttons=''.join(f'<button data-clip="{clip}" aria-pressed="{str(clip=="Idle").lower()}"><img src="{prefix}previews/{clip}.png" alt=""><span>{clip}</span></button>' for clip in descriptions)
html='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Serafim · Animações</title><style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#10151d;color:#ece9dd}*{box-sizing:border-box}body{max-width:1180px;margin:auto;padding:32px}header{margin-bottom:24px}.eyebrow{font-size:12px;letter-spacing:.12em;color:#e3c071;text-transform:uppercase}h1{font-size:clamp(28px,5vw,44px);margin:10px 0}p{line-height:1.6;color:#bbc5d2;max-width:780px}
main{display:grid;grid-template-columns:minmax(0,1fr) 260px;gap:24px}figure{margin:0;background:#1b242f;border:1px solid #354150;border-radius:10px;overflow:hidden}video,#pose{width:100%;display:block;aspect-ratio:1;object-fit:contain}[hidden]{display:none!important}figcaption{padding:16px;color:#d6dbe3}.clips{display:grid;grid-template-columns:1fr 1fr;gap:10px}
button{padding:0;border:1px solid #354150;border-radius:6px;background:#1b242f;color:#d6dbe3;cursor:pointer;overflow:hidden;text-align:left}button[aria-pressed="true"]{border-color:#e3c071;box-shadow:0 0 0 1px #e3c071}button img{width:100%;display:block;aspect-ratio:1}button span{display:block;font-size:13px;padding:9px}#view-toggle{padding:10px 14px;margin-top:14px}aside h2{font-size:16px;margin:24px 0 8px}aside p{font-size:14px}a{color:#f0d48d}aside a{display:block;margin:12px 0}footer{font-size:13px;color:#8795a6;margin-top:24px;line-height:1.6}@media(max-width:750px){body{padding:20px}main{grid-template-columns:1fr}}
</style><header><div class="eyebrow">Escola sagrada · Grande manifestação</div><h1>Serafim · Animações</h1><p>O modelo e a textura aprovados, agora com repouso, voo, ataque e conjuração. O núcleo gira entre as auréolas; as seis asas se movem pelos seus pontos de apoio.</p></header>
<main><figure><video id="video" autoplay loop muted playsinline controls poster="PREFIXpreviews/Idle.png" src="PREFIXpreviews/animations/Idle.mp4"></video><img id="pose" hidden src="PREFIXpreviews/Idle.png" alt="Pose da animação selecionada"><figcaption id="caption">Idle · 24 s · Ciclo contínuo</figcaption></figure>
<aside><div class="clips">BUTTONS</div><button id="view-toggle">Ver pose</button><h2 id="clip-title">Idle</h2><p id="description">Flutuação suave e giro lento do núcleo e das auréolas.</p><p id="mode">Ciclo contínuo no jogo.</p>
<h2>Arquivos</h2><a href="PREFIXseraph_blocky_v4_animated.glb">Modelo com 4 clipes · GLB</a><a href="PREFIXseraph_blocky_v4_animated.blend">Fonte editável · Blender</a><a id="gif" href="PREFIXpreviews/animations/Idle.gif">Prévia animada · GIF</a><a href="PREFIXgodot_validation.json">Validação no Godot</a><a href="../seraph_blocky_v4_review/index.html">Modelo aprovado</a>
<h2>No editor</h2><p>Abra <code>scenes/art_review/SeraphAnimationReview.tscn</code> e pressione F6. Teclas 1–4 escolhem o clipe; setas giram; espaço pausa; R repete a ação.</p></aside></main>
<footer>Idle e Walk repetem no jogo. Attack e Spell executam uma vez e retornam ao repouso; nesta página, os vídeos repetem para facilitar a revisão. Walk não desloca a raiz: o jogo controla o movimento entre os tiles.</footer>
<script>
const clips=CLIPDATA,prefix='PREFIX',video=document.querySelector('#video'),pose=document.querySelector('#pose'),toggle=document.querySelector('#view-toggle');let selected='Idle',still=false;
function update(){const clip=clips[selected];video.src=prefix+'previews/animations/'+selected+'.mp4';video.poster=prefix+'previews/'+selected+'.png';pose.src=video.poster;video.hidden=still;pose.hidden=!still;toggle.textContent=still?'Ver animação':'Ver pose';document.querySelector('#clip-title').textContent=selected;document.querySelector('#description').textContent=clip.description;document.querySelector('#mode').textContent=clip.loop?'Ciclo contínuo no jogo.':'Uma execução no jogo.';document.querySelector('#caption').textContent=selected+' · '+clip.duration+' s · '+(clip.loop?'Ciclo contínuo':'Uma execução');document.querySelector('#gif').href=prefix+'previews/animations/'+selected+'.gif';if(!still)video.play().catch(()=>{});}
document.querySelectorAll('button[data-clip]').forEach(button=>button.addEventListener('click',()=>{selected=button.dataset.clip;document.querySelectorAll('button[data-clip]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));update();}));
toggle.addEventListener('click',()=>{still=!still;if(still)video.pause();video.hidden=still;pose.hidden=!still;toggle.textContent=still?'Ver animação':'Ver pose';if(!still)video.play().catch(()=>{});});
</script></html>'''.replace('PREFIX',prefix).replace('BUTTONS',buttons).replace('CLIPDATA',json.dumps(clips,ensure_ascii=False))
(OUT/'index.html').write_text(html,encoding='utf-8')
(ASSET/'README.md').write_text('''# Serafim — quatro animações

Modelo e textura da V4 preservados, com 36 peças editáveis, 2.072 triângulos, 1 malha, 1 material e 11 ossos. Frente: Blender -Y / Godot +Z. Altura da pose de referência: 3,00 m.

| Clipe | Duração | Repetição | Movimento |
| --- | --- | --- | --- |
| Idle | 24 s | Sim | Flutuação suave, movimento contido das asas e giro lento do núcleo e das auréolas. |
| Walk | 8 s | Sim | Voo no lugar, inclinação para a frente e batidas suaves das asas. |
| Attack | 1,5 s | Não | Preparação, impulso frontal do núcleo e recuperação. Impacto aos 0,625 s. |
| Spell | 3 s | Não | Abertura das asas, alinhamento frontal da auréola externa e pulsos de energia sagrada. Conjuração aos 1,375 s. |

- `seraph_blocky_v4_animated.glb`: os quatro clipes no AnimationPlayer, com texturas embutidas e filtro NEAREST.
- `seraph_blocky_v4_animated.blend`: cena isolada com quatro ações e faixas NLA separadas. Peças articuladas rigidamente; núcleo com pulsos de escala uniforme.
- `seraph_animation_import.gd`: marca Idle/Walk como loop e Attack/Spell como execução única. A importação mantém os canais constantes, permitindo interromper Spell e retornar ao Idle sem deixar escala ou asas na pose anterior.
- A raiz permanece fixa em todos os clipes. O jogo controla o deslocamento de Walk.
- `animation_report.json`: 1.756 poses e meios de quadro conferidos no Blender; asas sem cruzamentos, peças separadas e sem contato com o chão.
- `godot_validation.json`: 880 poses verificadas no Godot, inclusive repetição, rigidez e transição de Spell para Idle. Todas as prévias usam o GLB importado no Godot.
- Revisão: `scenes/art_review/SeraphAnimationReview.tscn` (F6; 1–4 para escolher, setas para girar, espaço para pausar e R para repetir).

Integrado em `UnitDatabase` como `v2_manifestation_seraph`, compartilhado entre humanos, elfos, orcs e anões, na escala nativa de 3 metros. O controlador da unidade aciona Idle, Walk e Spell, com transição de 0,2 s e retorno automático após conjurar. Attack está disponível, mantendo a regra atual de não ter ataque básico. O AnimationPlayer original não inicia sozinho, evitando dois controladores sobre os mesmos ossos.

`game_integration_validation.json`: 39 testes passaram, com 705 verificações, incluindo movimento, conjuração, produção, efeitos sagrados, IA e save/load.

O modelo estático da V4 e as versões anteriores continuam preservados. As regras de cura, combate, produção e deslocamento permanecem as mesmas.
''',encoding='utf-8')
print(json.dumps({'review':str(OUT/'index.html'),'clips':list(clips),'native_validation':'PASS'},ensure_ascii=False))

"""Encode native playback previews and write the Avatar animation review."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json,shutil,subprocess,html
ROOT=Path(__file__).resolve().parents[2]
STEM='nature_avatar_blocky_v5_animated'
ASSET=ROOT/'assets/generated/grand_manifestations'/STEM
OUT=ROOT/'art_source'/f'{STEM}_review'
ANIM=ASSET/'previews/animations'; ANIM.mkdir(parents=True,exist_ok=True)
native=json.loads((ASSET/'godot_validation.json').read_text(encoding='utf-8'))
source=json.loads((ASSET/'animation_report.json').read_text(encoding='utf-8'))
assert native['status']=='PASS'
ffmpeg=shutil.which('ffmpeg'); assert ffmpeg
def encode(clip):
 spec=native['previews'][clip]; frames=OUT/'native_frames'/clip
 assert len(list(frames.glob('*.png')))==spec['frames']
 command=[ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate',str(spec['fps']),'-start_number','1','-i',str(frames/'%04d.png'),'-frames:v',str(spec['frames'])]
 subprocess.run(command+['-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(ANIM/(clip+'.mp4'))],check=True)
 subprocess.run(command+['-filter_complex_threads','1','-filter_complex','[0:v]split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none','-loop','0',str(ANIM/(clip+'.gif'))],check=True)
with ThreadPoolExecutor(max_workers=2) as pool: list(pool.map(encode,native['clips']))
(ANIM/'manifest.json').write_text(json.dumps(native['previews'],indent=2),encoding='utf-8')
prefix='../../assets/generated/grand_manifestations/'+STEM+'/'
clips={name:dict(description=data['description'],duration=data['duration_s'],loop=data['loop']) for name,data in source['clips'].items()}
buttons=''.join(f'<button data-clip="{name}" aria-pressed="{str(name=="Idle").lower()}"><img src="{prefix}previews/{name}.png" alt=""><span>{name}</span></button>' for name in clips)
page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Avatar da Natureza · Animações</title><style>
:root{color-scheme:dark;font:16px/1.6 system-ui;background:#131b16;color:#e7eddc}*{box-sizing:border-box}body{max-width:1250px;margin:auto;padding:32px}h1{font-size:clamp(26px,5vw,44px);line-height:1.2}p{color:#b7c6b2;max-width:900px}a{color:#b5df82}main{display:grid;grid-template-columns:minmax(0,1fr) 280px;gap:24px}figure{margin:0;background:#18202b;border:1px solid #394d3b;border-radius:10px;overflow:hidden}video{width:100%;display:block;aspect-ratio:1;background:#18202b}figcaption{padding:16px}.clips{display:grid;grid-template-columns:1fr 1fr;gap:10px}button{border:1px solid #394d3b;border-radius:6px;background:#202c25;color:#d6e0d4;cursor:pointer;overflow:hidden}button[data-clip]{padding:0;text-align:left}button[aria-pressed=true]{border-color:#a5d77a}button img{width:100%;display:block;aspect-ratio:1}button span{display:block;padding:9px;font-size:13px}aside a{display:block;margin:10px 0}aside p{font-size:14px}.tags{display:flex;gap:10px;flex-wrap:wrap;margin:20px 0 24px}.tags span{border:1px solid #394d3b;padding:7px 12px;border-radius:6px;font-size:13px}#replay{padding:8px 16px}select{padding:8px}.poses{display:flex;gap:20px;flex-wrap:wrap}footer{font-size:13px;color:#8eab89;margin-top:32px}@media(max-width:750px){body{padding:20px}main{grid-template-columns:1fr}}
</style><header><p>Druidismo · Grande invocação</p><h1>Avatar da Natureza</h1><p>O modelo flutuante aprovado, agora com repouso, deslocamento, ataque e conjuração. O núcleo verde gira, os braços seguem suas articulações e as raízes suspensas acompanham os movimentos.</p><div class="tags"><span>Idle</span><span>Walk</span><span>Attack</span><span>Spell</span><span>Flutuante</span></div></header><main><figure><video id="video" src="PREFIXpreviews/animations/Idle.mp4" poster="PREFIXpreviews/Idle.png" autoplay muted loop playsinline controls></video><figcaption><h2 id="title">Idle · 12 s · ciclo</h2><p id="description">Flutuação suave, giro lento do núcleo e raízes suspensas balançando.</p><button id="replay">Repetir</button> <label for="speed">Velocidade</label> <select id="speed"><option value="1">Normal</option><option value="0.5">Metade</option><option value="0.25">Um quarto</option></select></figcaption></figure><aside><div class="clips">BUTTONS</div><h2>Arquivos</h2><a href="PREFIXnature_avatar_blocky_v5_animated.glb">Modelo animado · GLB</a><a href="PREFIXnature_avatar_blocky_v5_animated.blend">Fonte editável · Blender</a><a href="PREFIXgodot_validation.json">Conferência no Godot</a><p>Idle e Walk repetem. Attack e Spell executam uma vez e recuperam a pose de repouso.</p><p>Walk desliza no lugar: o controlador do jogo define o deslocamento entre os tiles.</p><a href="../nature_avatar_blocky_v4_review/index.html">Modelo aprovado · V4</a></aside></main><h2>Conferência das poses</h2><div class="poses"><a href="PREFIXpreviews/Spell_front.png">Spell de frente</a><a href="PREFIXpreviews/Spell_side.png">Spell de lado</a><a href="PREFIXpreviews/Attack_side.png">Attack de lado</a></div><h2>No editor</h2><p>Abra <code>scenes/art_review/NatureAvatarAnimationReview.tscn</code> e execute com F6. Teclas 1–4 escolhem o clipe; setas giram o modelo, espaço pausa e R repete.</p><footer>Malha e texturas aprovadas preservadas. Reprodução conferida na importação nativa do Godot; braços conectados, raízes articuladas e núcleo livre da madeira. A V4 permanece disponível.</footer>
<script>const clips=CLIPDATA;const prefix='PREFIX';const video=document.querySelector('#video');document.querySelectorAll('button[data-clip]').forEach(button=>button.addEventListener('click',()=>{const name=button.dataset.clip;const data=clips[name];document.querySelectorAll('button[data-clip]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));video.src=prefix+'previews/animations/'+name+'.mp4';video.poster=prefix+'previews/'+name+'.png';video.loop=data.loop;video.playbackRate=Number(document.querySelector('#speed').value);document.querySelector('#title').textContent=name+' · '+data.duration+' s · '+(data.loop?'ciclo':'ação');document.querySelector('#description').textContent=data.description;video.play().catch(()=>{});}));document.querySelector('#replay').addEventListener('click',()=>{video.currentTime=0;video.play().catch(()=>{});});document.querySelector('#speed').addEventListener('change',event=>{video.playbackRate=Number(event.target.value);});</script></html>'''
page=page.replace('PREFIX',prefix).replace('BUTTONS',buttons).replace('CLIPDATA',json.dumps(clips,ensure_ascii=False))
(OUT/'index.html').write_text(page,encoding='utf-8')
rows='\n'.join(f'| {name} | {data["duration"]} s | {"Sim" if data["loop"] else "Não"} | {data["description"]} |' for name,data in clips.items())
(ASSET/'README.md').write_text(f'''# Avatar da Natureza — quatro animações

Modelo flutuante V4, mantendo as 86 peças, {source['triangles']} triângulos, as texturas pixeladas e os 18 ossos. 1 malha exportada, 1 material e mapas de cor/emissão embutidos. Frente Blender -Y / Godot +Z.

| Clipe | Duração | Repetição | Movimento |
| --- | --- | --- | --- |
{rows}

- Impacto de Attack: 0,875 s. Liberação de Spell: 1,75 s.
- Raiz imóvel em todos os clipes. O controlador do jogo faz o deslocamento de Walk.
- Braços conectados, comprimento constante, punhos com gestos limitados. Partes permanecem rígidas.
- Raízes balançam pelos pontos em que se ligam ao tronco.
- O núcleo tem um pequeno afastamento frontal para girar sem atravessar a casca; mantém sua geometria e recebe pulsação uniforme durante as ações.
- Idle/Walk repetem; Attack/Spell recuperam a pose inicial de Idle. Todos têm os mesmos canais.
- `animation_report.json`: amostragem dos meios de quadro, articulações, ciclos, distância do solo, movimento das raízes e colisões do núcleo.
- `godot_validation.json`: reprodução e repetição reais no Godot, reset de Spell para Idle e prévias nativas.
- `nature_avatar_animation_import.gd`: configuração dos ciclos na importação.
- `scenes/art_review/NatureAvatarAnimationReview.tscn`: revisão com teclas 1–4 e controle de câmera.
- MP4/GIF em `previews/animations`; galeria em `art_source/{STEM}_review/index.html`.

As versões estáticas e os outros bosses estão preservados.
''',encoding='utf-8')
print(json.dumps(dict(review=str(OUT/'index.html'),clips=list(clips),native_validation='PASS'),ensure_ascii=False))

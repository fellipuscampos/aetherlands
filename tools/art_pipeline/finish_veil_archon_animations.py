"""Encode the native four-clip previews and write the runic entity's local review."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json,shutil,subprocess,html
ROOT=Path(__file__).resolve().parents[2];STEM='veil_archon_blocky_v9_animated'
ASSET=ROOT/'assets/generated/grand_manifestations'/STEM;OUT=ROOT/'art_source'/f'{STEM}_review'
ANIM=ASSET/'previews/animations';ANIM.mkdir(parents=True,exist_ok=True)
native=json.loads((ASSET/'godot_validation.json').read_text(encoding='utf-8'))
source=json.loads((ASSET/'animation_report.json').read_text(encoding='utf-8'))
assert native['status']=='PASS' and source['external_purple_trails_removed']==6
ffmpeg=shutil.which('ffmpeg');assert ffmpeg
def encode(clip):
    spec=native['previews'][clip];frames=OUT/'native_frames'/clip
    assert len(list(frames.glob('*.png')))==spec['frames']
    command=[ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate',str(spec['fps']),'-start_number','1','-i',str(frames/'%04d.png'),'-frames:v',str(spec['frames'])]
    subprocess.run(command+['-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(ANIM/(clip+'.mp4'))],check=True)
    subprocess.run(command+['-filter_complex_threads','1','-filter_complex','[0:v]split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none','-loop','0',str(ANIM/(clip+'.gif'))],check=True)
with ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(encode,native['clips']))
(ANIM/'manifest.json').write_text(json.dumps(native['previews'],indent=2),encoding='utf-8')
prefix='../../assets/generated/grand_manifestations/'+STEM+'/'
clips={name:dict(description=data['description'],duration=data['duration_s'],loop=data['loop']) for name,data in source['clips'].items()}
buttons=''.join(f'<button data-clip="{name}" aria-pressed="{str(name=="Idle").lower()}"><img src="{prefix}previews/{name}.png" alt=""><span>{name}</span></button>' for name in clips)
page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Arconte do Véu · Animações</title><style>
:root{color-scheme:dark;font:16px/1.6 system-ui;background:#171321;color:#e9e4f5}*{box-sizing:border-box}body{max-width:1250px;margin:auto;padding:32px}h1{font-size:clamp(26px,5vw,44px);line-height:1.2}p{color:#c1b7d4;max-width:900px}a{color:#c9b5ff}main{display:grid;grid-template-columns:minmax(0,1fr) 280px;gap:24px}figure{margin:0;background:#18202b;border:1px solid #4a3c62;border-radius:10px;overflow:hidden}video{width:100%;display:block;aspect-ratio:1;background:#18202b}figcaption{padding:16px}.clips{display:grid;grid-template-columns:1fr 1fr;gap:10px}button{border:1px solid #4a3c62;border-radius:6px;background:#282135;color:#e4dcef;cursor:pointer;overflow:hidden}button[data-clip]{padding:0;text-align:left}button[aria-pressed=true]{border-color:#b497e9}button img{width:100%;display:block;aspect-ratio:1}button span{display:block;padding:9px;font-size:13px}aside a{display:block;margin:10px 0}aside p{font-size:14px}.tags{display:flex;gap:10px;flex-wrap:wrap;margin:20px 0 24px}.tags span{border:1px solid #4a3c62;padding:7px 12px;border-radius:6px;font-size:13px}#replay{padding:8px 16px}select{padding:8px}.poses{display:flex;gap:20px;flex-wrap:wrap}footer{font-size:13px;color:#a897ba;margin-top:32px}@media(max-width:750px){body{padding:20px}main{grid-template-columns:1fr}}
</style><header><p>Arcanismo · Grande invocação</p><h1>Arconte do Véu</h1><p>O poliedro rúnico aprovado, com os seis arcos roxos externos removidos. O núcleo gira dentro da estrutura branca, enquanto as placas flutuam, abrem o acesso frontal no ataque e expandem a casca durante a conjuração.</p><div class="tags"><span>Idle</span><span>Walk</span><span>Attack</span><span>Spell</span><span>Flutuante</span></div></header><main><figure><video id="video" src="PREFIXpreviews/animations/Idle.mp4" poster="PREFIXpreviews/Idle.png" autoplay muted loop playsinline controls></video><figcaption><h2 id="title">Idle · 24 s · ciclo</h2><p id="description">Giro lento da casca, núcleo girando em sentido contrário e pulsação suave das placas.</p><button id="replay">Repetir</button> <label for="speed">Velocidade</label> <select id="speed"><option value="1">Normal</option><option value="0.5">Metade</option><option value="0.25">Um quarto</option></select></figcaption></figure><aside><div class="clips">BUTTONS</div><h2>Arquivos</h2><a href="PREFIXveil_archon_blocky_v9_animated.glb">Modelo animado · GLB</a><a href="PREFIXveil_archon_blocky_v9_animated.blend">Fonte editável · Blender</a><a href="PREFIXgodot_validation.json">Conferência no Godot</a><p>Idle e Walk repetem. Attack e Spell executam uma vez e recuperam a pose de repouso.</p><p>Walk se move no lugar: o controlador do jogo define o deslocamento entre os tiles.</p><a href="../veil_archon_blocky_v8_review/index.html">Modelo aprovado · V8</a></aside></main><h2>Conferência das poses</h2><div class="poses"><a href="PREFIXpreviews/Spell_front.png">Spell de frente</a><a href="PREFIXpreviews/Spell_side.png">Spell de lado</a><a href="PREFIXpreviews/Attack_side.png">Attack de lado</a></div><h2>No editor</h2><p>Abra <code>scenes/art_review/VeilArchonAnimationReview.tscn</code> e execute com F6. Teclas 1–4 escolhem o clipe; setas giram o modelo, espaço pausa e R repete.</p><footer>Geometria das placas, estrutura interna e texturas aprovadas preservadas. Reprodução conferida no Godot, com reset de Spell para Idle e partes rígidas. A V8 permanece disponível.</footer>
<script>const clips=CLIPDATA;const prefix='PREFIX';const video=document.querySelector('#video');document.querySelectorAll('button[data-clip]').forEach(button=>button.addEventListener('click',()=>{const name=button.dataset.clip;const data=clips[name];document.querySelectorAll('button[data-clip]').forEach(item=>item.setAttribute('aria-pressed',String(item===button)));video.src=prefix+'previews/animations/'+name+'.mp4';video.poster=prefix+'previews/'+name+'.png';video.loop=data.loop;video.playbackRate=Number(document.querySelector('#speed').value);document.querySelector('#title').textContent=name+' · '+data.duration+' s · '+(data.loop?'ciclo':'ação');document.querySelector('#description').textContent=data.description;video.play().catch(()=>{});}));document.querySelector('#replay').addEventListener('click',()=>{video.currentTime=0;video.play().catch(()=>{});});document.querySelector('#speed').addEventListener('change',event=>{video.playbackRate=Number(event.target.value);});</script></html>'''
page=page.replace('PREFIX',prefix).replace('BUTTONS',buttons).replace('CLIPDATA',json.dumps(clips,ensure_ascii=False))
(OUT/'index.html').write_text(page,encoding='utf-8')
rows='\n'.join(f'| {name} | {data["duration"]} s | {"Sim" if data["loop"] else "Não"} | {data["description"]} |' for name,data in clips.items())
(ASSET/'README.md').write_text(f'''# Arconte do Véu — quatro animações

Modelo rúnico V8 animado, com os seis arcos externos roxos removidos. Mantém a geometria das 47 peças restantes e as texturas aprovadas. {source['triangles']} triângulos, {source['bones']} ossos, 1 malha e 1 material, mapas de cor/emissão embutidos. Frente Blender -Y / Godot +Z.

| Clipe | Duração | Repetição | Movimento |
| --- | --- | --- | --- |
{rows}

- Attack libera o pulso em 0,875 s; Spell conjura em 2,0 s.
- Raiz imóvel; o controlador do jogo faz o deslocamento de Walk.
- Placas permanecem rígidas, com expansão radial e pivôs individuais.
- Núcleo cúbico com giro independente e pulsação uniforme nas ações.
- Idle/Walk repetem; Attack/Spell recuperam a pose inicial de Idle. Todos têm os mesmos canais.
- `animation_report.json`: amostragem dos meios de quadro, ciclos, chão e colisões do núcleo e das placas.
- `godot_validation.json`: reprodução nativa, pesos rígidos, ciclos, reset de Spell para Idle e prévias.
- `veil_archon_animation_import.gd`: configura os ciclos na importação.
- `scenes/art_review/VeilArchonAnimationReview.tscn`: revisão com teclas 1–4.
- MP4/GIF em `previews/animations`; galeria em `art_source/{STEM}_review/index.html`.
''',encoding='utf-8')
print(json.dumps(dict(review=str(OUT/'index.html'),clips=list(clips),native_validation='PASS'),ensure_ascii=False))

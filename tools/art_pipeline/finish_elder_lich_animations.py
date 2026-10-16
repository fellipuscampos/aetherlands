"""Encode the imported Godot animations and publish their local review gallery."""
import json,shutil,subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[2]
STEM='elder_lich_blocky_v3_animated'
ASSET=ROOT/'assets/generated/grand_manifestations'/STEM
OUT=ROOT/'art_source'/f'{STEM}_review'
ANIM=ASSET/'previews/animations'; ANIM.mkdir(parents=True,exist_ok=True)
report=json.loads((ASSET/'godot_validation.json').read_text(encoding='utf-8'))
source_report=json.loads((ASSET/'animation_report.json').read_text(encoding='utf-8'))
assert report['status']=='PASS'
ffmpeg=shutil.which('ffmpeg'); assert ffmpeg
def encode(clip):
    spec=report['previews'][clip]; frames=OUT/'native_frames'/clip
    assert len(list(frames.glob('*.png')))==spec['frames']
    command=[ffmpeg,'-hide_banner','-loglevel','error','-y','-framerate',str(spec['fps']),'-start_number','1','-i',str(frames/'%04d.png'),'-frames:v',str(spec['frames'])]
    subprocess.run(command+['-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(ANIM/(clip+'.mp4'))],check=True)
    subprocess.run(command+['-filter_complex_threads','1','-filter_complex','[0:v]split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none','-loop','0',str(ANIM/(clip+'.gif'))],check=True)
with ThreadPoolExecutor(max_workers=2) as pool: list(pool.map(encode,report['clips']))
(ANIM/'manifest.json').write_text(json.dumps(report['previews'],indent=2),encoding='utf-8')
prefix='../../assets/generated/grand_manifestations/'+STEM+'/'
descriptions={name:data['description'] for name,data in source_report['clips'].items()}
clips={name:dict(description=description,duration=report['clips'][name]['duration_s'],loop=report['clips'][name]['loop']) for name,description in descriptions.items()}
buttons=''.join(f'<button data-clip="{clip}" aria-pressed="{str(clip=="Idle").lower()}"><img src="{prefix}previews/{clip}.png" alt=""><span>{clip}</span></button>' for clip in clips)
template=(ROOT/'tools/art_pipeline/finish_seraph_animations.py').read_text(encoding='utf-8')
page=template.split("html='''",1)[1].split("'''.replace('PREFIX'",1)[0]
page=page.replace('Serafim','Lich Ancião').replace('Escola sagrada','Necromancia')
page=page.replace('O modelo e a textura aprovados, agora com repouso, voo, ataque e conjuração. O núcleo gira entre as auréolas; as seis asas se movem pelos seus pontos de apoio.',
    'O Lich revisado, agora com flutuação, deslocamento pairando, ataque com o cajado e conjuração com o grimório. O manto acompanha os movimentos; braços e punhos usam as articulações do corpo.')
page=page.replace('Flutuação suave e giro lento do núcleo e das auréolas.',descriptions['Idle'])
page=page.replace('seraph_blocky_v4_animated',STEM).replace('seraph_blocky_v4_review','elder_lich_blocky_v2_review').replace('SeraphAnimationReview','ElderLichAnimationReview')
page=page.replace('Idle · 24 s','Idle · 6 s').replace('#e3c071','#a898d6').replace('#f0d48d','#c8bde8')
page=page.replace('Idle e Walk repetem no jogo. Attack e Spell executam uma vez e retornam ao repouso;',
    'Idle e Walk são ciclos. Attack e Spell executam uma vez; a cena de revisão retorna ao repouso;')
page=page.replace('Walk não desloca a raiz: o jogo controla o movimento entre os tiles.',
    'Walk não desloca a raiz, permitindo que o controlador da unidade faça o movimento entre os tiles.')
page=page.replace('PREFIX',prefix).replace('BUTTONS',buttons).replace('CLIPDATA',json.dumps(clips,ensure_ascii=False))
page=page.replace('<h2>No editor</h2>',f'<h2>Conferência das poses</h2><a href="{prefix}previews/Spell_front.png">Spell de frente</a><a href="{prefix}previews/Spell_side.png">Spell de lado</a><a href="{prefix}previews/Attack_side.png">Attack de lado</a><h2>No editor</h2>')
page=page.replace('<h2 id="clip-title">', '<p><label for="speed">Velocidade da prévia</label><br><select id="speed"><option value="1">Normal</option><option value="0.5">Metade</option><option value="0.25">Um quarto</option></select></p><h2 id="clip-title">')
page=page.replace('</script>', "document.querySelector('#speed').addEventListener('change',event=>{video.playbackRate=Number(event.target.value);});</script>")
(OUT/'index.html').write_text(page,encoding='utf-8')
rows='\n'.join(f'| {name} | {data["duration"]} s | {"Sim" if data["loop"] else "Não"} | {data["description"]} |' for name,data in clips.items())
(ASSET/'README.md').write_text(f'''# Lich Ancião — quatro animações

Modelo aprovado V2, mantendo o crânio do esqueleto atual, as vestes roxas, o cajado, o grimório e o corpo espectral. Altura de referência: 3 m. Frente Blender -Y / Godot +Z.

79 peças editáveis, {source_report['triangles']} triângulos, 1 malha exportada, 1 material, {source_report['bones']} ossos e atlas de 512 px com filtro NEAREST. Texturas e superfícies rígidas da V2 preservadas. Somente as superfícies do manto foram divididas em segmentos articulados, conservando a silhueta, espessura e UVs. Um osso por vértice, faces planas, sem arredondamentos.

| Clipe | Duração | Repetição | Movimento |
| --- | --- | --- | --- |
{rows}

- Ataque: impacto aos 0,625 s; conjuração: liberação aos 1,45 s. Attack e Spell terminam na pose inicial de Idle.
- Raiz imóvel em todos os clipes; o movimento de Walk é controlado pelo jogo.
- Braços conectados com segmentos de comprimento fixo. Punhos limitados a 35 graus em relação à pose inicial do antebraço. Cajado permanece preso à mão; grimório levita ligeiramente durante Spell.
- Partes superiores das vestes fixas ao torso/cintura; dobras e barras respondem com movimentos defasados.
- `{STEM}.glb`: quatro clipes, texturas embutidas e skin pronto para Godot.
- `{STEM}.blend`: cena isolada com quatro ações e faixas NLA.
- `elder_lich_animation_import.gd`: Idle/Walk em loop; Attack/Spell em execução única; sem autoplay.
- `animation_report.json`: poses e meios de quadro auditados no Blender, incluindo ciclos, articulações, punhos, distância do chão e interseções de adereços com torso/crânio.
- `godot_validation.json`: importação e reprodução reais, canais constantes, repetição dos ciclos e reinício de Spell para Idle.
- Prévias MP4/GIF renderizadas no Godot em `previews/animations`.
- Cena de revisão `scenes/art_review/ElderLichAnimationReview.tscn` (F6; 1–4 para escolher clipe, setas para girar, espaço para pausar e R para repetir).

A V2 está preservada. Esta etapa fornece as animações; não altera a entrada da unidade no jogo.
''',encoding='utf-8')
print(json.dumps(dict(review=str(OUT/'index.html'),clips=list(clips),native_validation='PASS'),ensure_ascii=False))

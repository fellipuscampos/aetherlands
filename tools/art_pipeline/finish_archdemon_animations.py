"""Encode native Godot previews and write an animation review."""
import json,shutil,subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[2]
STEM='archdemon_blocky_v4_animated'
ASSET=ROOT/'assets/generated/grand_manifestations'/STEM
OUT=ROOT/'art_source'/f'{STEM}_review'
ANIM=ASSET/'previews/animations'; ANIM.mkdir(parents=True,exist_ok=True)
report=json.loads((ASSET/'godot_validation.json').read_text(encoding='utf-8'))
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
descriptions={'Idle':'Flutuação suave, peças suspensas e giro lento do cubo vermelho.',
    'Walk':'Deslizamento no lugar, leve inclinação frontal e movimento das faixas.',
    'Attack':'Preparação e golpe frontal com as duas mãos flutuantes.',
    'Spell':'Mãos abertas em conjuração, elevação e giro acelerado do núcleo.'}
clips={n:dict(description=descriptions[n],duration=report['clips'][n]['duration_s'],loop=report['clips'][n]['loop']) for n in descriptions}
buttons=''.join(f'<button data-clip="{clip}" aria-pressed="{str(clip=="Idle").lower()}"><img src="{prefix}previews/{clip}.png" alt=""><span>{clip}</span></button>' for clip in descriptions)
# Keep the established local review controls, rewriting all model-specific copy.
source=(ROOT/'tools/art_pipeline/finish_seraph_animations.py').read_text(encoding='utf-8')
html=source.split("html='''",1)[1].split("'''.replace('PREFIX'",1)[0]
html=html.replace('Serafim','Arcdemônio').replace('Escola sagrada','Escola infernal')
html=html.replace('O modelo e a textura aprovados, agora com repouso, voo, ataque e conjuração. O núcleo gira entre as auréolas; as seis asas se movem pelos seus pontos de apoio.','Faixas laterais giradas e presas às placas da cintura. Um único cubo vermelho gira dentro do peito; mãos e ombros continuam flutuantes. Quatro animações com peças rígidas e estética blocky.')
html=html.replace('Flutuação suave e giro lento do núcleo e das auréolas.',descriptions['Idle'])
html=html.replace('seraph_blocky_v4_animated',STEM).replace('seraph_blocky_v4_review','archdemon_blocky_v3_review').replace('SeraphAnimationReview','ArchdemonAnimationReview')
html=html.replace('Ciclo contínuo no jogo.','Ciclo contínuo.').replace('Uma execução no jogo.','Uma execução.')
html=html.replace('Idle e Walk repetem no jogo. Attack e Spell executam uma vez e retornam ao repouso;','Idle e Walk são ciclos. Attack e Spell executam uma vez; a cena de revisão retorna ao repouso;')
html=html.replace('Walk não desloca a raiz: o jogo controla o movimento entre os tiles.','Walk não desloca a raiz, permitindo que o controlador da unidade mova o modelo entre os tiles.')
html=html.replace('PREFIX',prefix).replace('BUTTONS',buttons).replace('CLIPDATA',json.dumps(clips,ensure_ascii=False))
(OUT/'index.html').write_text(html,encoding='utf-8')
rows='\n'.join(f'| {n} | {v["duration"]} s | {"Sim" if v["loop"] else "Não"} | {v["description"]} |' for n,v in clips.items())
(ASSET/'README.md').write_text(f'''# Arcdemônio — quatro animações

Revisão da V3: faixas laterais giradas 90° e encaixadas na superfície das placas da cintura; núcleo substituído por um único cubo emissivo vermelho de 24 cm, dentro da cavidade do peito. Ombros e mãos permanecem separados. Texturas da armadura e faixas preservadas.

Altura de referência: 3 m. Frente: Blender -Y / Godot +Z. 74 peças editáveis, 1.084 triângulos, 1 malha, 1 material e 29 ossos. Cada vértice pertence rigidamente a um osso.

| Clipe | Duração | Repetição | Movimento |
| --- | --- | --- | --- |
{rows}

- `{STEM}.glb`: quatro clipes, texturas embutidas e filtro NEAREST.
- `{STEM}.blend`: cena isolada, quatro ações e faixas NLA separadas.
- `archdemon_animation_import.gd`: Idle/Walk em loop e Attack/Spell em execução única; canais constantes mantidos para reiniciar as poses após interrupções.
- `animation_report.json`: poses e meios de quadro conferidos no Blender; cubo dentro do peito, mãos sem interseção com ombros, raiz imóvel e folga do chão.
- `godot_validation.json`: quatro clipes exercitados na importação nativa, com rigidez, fechamento dos ciclos e reinício de Spell para Idle verificados.
- Prévias: `previews/animations/*.mp4` e `*.gif`, renderizadas no Godot.
- Cena de revisão: `scenes/art_review/ArchdemonAnimationReview.tscn`. F6; 1–4 escolhem o clipe; setas giram; espaço pausa; R repete.

Esta revisão fornece o modelo e as animações. A entrada da unidade em UnitDatabase permanece na versão anterior. A V3 e as demais cenas estão preservadas.
''',encoding='utf-8')
print(json.dumps(dict(review=str(OUT/'index.html'),clips=list(clips),native_validation='PASS'),ensure_ascii=False))

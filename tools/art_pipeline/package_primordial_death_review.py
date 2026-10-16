"""Verify serialized channels and package the Primordial Death and playable preview."""
import hashlib
import bisect
import json
import math
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT/'art_source/primordial_death_review'
OUT = ROOT/'assets/generated/grand_manifestations/primordial_death_v1'
OUT.mkdir(parents=True, exist_ok=True)


def load(path):
    raw = path.read_bytes()
    length = struct.unpack_from('<I', raw, 12)[0]
    return json.loads(raw[20:20+length]), raw, 28+length


def channels(doc, raw, binary):
    result = {}
    for animation in doc['animations']:
        rows = {}
        for c in animation['channels']:
            sampler = animation['samplers'][c['sampler']]
            values = []
            for key in ('input', 'output'):
                a = doc['accessors'][sampler[key]]
                v = doc['bufferViews'][a['bufferView']]
                assert a['componentType'] == 5126
                width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[a['type']]
                stride = v.get('byteStride', width*4)
                offset = binary+v.get('byteOffset', 0)+a.get('byteOffset', 0)
                values.append([struct.unpack_from('<'+'f'*width, raw, offset+i*stride)
                               for i in range(a['count'])])
            rows[doc['nodes'][c['target']['node']]['name'], c['target']['path']] = values
        result[animation['name']] = rows
    return result


doc, raw, binary = load(REVIEW/'primordial_death.glb')
clips = channels(doc, raw, binary)
assert set(clips) == {'Summon', 'Death', 'idle', 'walk', 'attack', 'spell'}
original_path = ROOT/'assets/generated/grand_manifestations/primordial_summon_v1/primordial_summon.glb'
original = channels(*load(original_path))


def embedded_images(document, data, offset):
    result = []
    for image in document.get('images', []):
        view = document['bufferViews'][image['bufferView']]
        start = offset+view.get('byteOffset', 0)
        result.append(hashlib.sha256(data[start:start+view['byteLength']]).hexdigest())
    return sorted(result)


assert embedded_images(doc, raw, binary) == embedded_images(*load(original_path))
max_original_error = 0.


def evaluate(values, time, rotation):
    times = [row[0] for row in values[0]]
    index = max(0, min(len(times)-2, bisect.bisect_right(times, time)-1))
    if len(times) == 1:
        return values[1][0]
    weight = max(0., min(1., (time-times[index])/(times[index+1]-times[index])))
    a, b = values[1][index], values[1][index+1]
    if rotation:
        a = tuple(x/math.sqrt(sum(v*v for v in a)) for x in a)
        b = tuple(x/math.sqrt(sum(v*v for v in b)) for x in b)
        dot = sum(x*y for x,y in zip(a,b))
        if dot < 0:
            b, dot = tuple(-x for x in b), -dot
        if dot < .9995:
            angle = math.acos(max(-1., min(1., dot)))
            return tuple((x*math.sin((1-weight)*angle)+y*math.sin(weight*angle))/math.sin(angle)
                         for x,y in zip(a,b))
    result = tuple(x+(y-x)*weight for x,y in zip(a,b))
    if rotation:
        norm = math.sqrt(sum(x*x for x in result))
        result = tuple(x/norm for x in result)
    return result


for name, expected in original.items():
    assert expected.keys() == clips[name].keys(), name
    for key, old_values in expected.items():
        new_values = clips[name][key]
        assert abs(old_values[0][-1][0]-new_values[0][-1][0]) < 1e-6
        # The source compacts constant tracks to two keys. Compare their motion
        # at the union of key times and midpoints, allowing quaternion signs.
        times = sorted({row[0] for values in (old_values, new_values) for row in values[0]})
        probes = times+[(a+b)/2 for a,b in zip(times, times[1:])]
        for time in probes:
            a, b = evaluate(old_values, time, key[1]=='rotation'), evaluate(new_values, time, key[1]=='rotation')
            error = max(abs(x-y) for x,y in zip(a,b))
            if key[1] == 'rotation':
                error = min(error, max(abs(x+y) for x,y in zip(a,b)))
            max_original_error = max(max_original_error, error)
assert max_original_error < 1e-5, max_original_error
assert clips['Death'].keys() == clips['idle'].keys()
join_error = 0.
for key in clips['idle']:
    a, b = clips['Death'][key][1][0], clips['idle'][key][1][0]
    error = max(abs(x-y) for x, y in zip(a, b))
    if key[1] == 'rotation':
        error = min(error, max(abs(x+y) for x, y in zip(a, b)))
    join_error = max(join_error, error)
assert join_error < 1e-5, join_error
assert max(clips['Death'][key][0][-1][0] for key in clips['Death']) == 5.
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == 91
report = json.loads((REVIEW/'validation.json').read_text(encoding='utf-8'))
report.update(original_five_clips_preserved=True, serialized_original_clip_error=max_original_error,
              serialized_death_to_idle_error=join_error, embedded_textures_preserved=True)
if '--validate-only' in sys.argv:
    print(json.dumps(report, indent=2))
    raise SystemExit(0)
assert len(list((REVIEW/'frames').glob('*.png'))) == 151
for name in ('primordial_death.blend', 'primordial_death.glb'):
    shutil.copy2(REVIEW/name, OUT/name)
(OUT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
ffmpeg = shutil.which('ffmpeg')
assert ffmpeg
subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
                '-framerate', '30', '-start_number', '1', '-i', str(REVIEW/'frames/%04d.png'),
                '-frames:v', '151', '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p',
                '-movflags', '+faststart', str(OUT/'Morte.mp4')], check=True)
shutil.copy2(REVIEW/'frames/0073.png', OUT/'preview.png')
(OUT/'index.html').write_text('''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Primordial dos Elementos · Morte</title><style>
body{margin:0;background:#142024;color:#e6f1ef;font:16px system-ui;display:grid;place-items:center;min-height:100vh}
main{max-width:800px;padding:24px}h1{font-size:26px}p{color:#b8ccce;line-height:1.6}
video{width:100%;max-height:72vh;border-radius:8px;background:#263b41;display:block}
a{color:#a6e0e3;margin-right:18px}button{background:#a6d6d3;border:0;border-radius:5px;padding:10px 18px;cursor:pointer;margin:16px 0;font:inherit}
</style><main><h1>Primordial dos Elementos · Morte</h1>
<video id="v" controls playsinline preload="auto" poster="preview.png?v=fluido2" src="Morte.mp4?v=fluido2"></video>
<button onclick="const v=document.getElementById('v');v.currentTime=0;v.play()">Reproduzir do início</button>
<p>O núcleo colapsa primeiro. Uma onda percorre a coluna, e pescoço, corpo e cauda cedem com atraso entre si. A serpente se curva, afunda e se desfaz da cauda até a cabeça. Duração: 5 segundos. Sem partículas; os efeitos serão feitos no Godot.</p>
<p><a href="primordial_death.blend">Fonte Blender</a><a href="primordial_death.glb">Modelo com seis animações</a><a href="../primordial_summon_v1/index.html">Ver invocação</a></p>
</main></html>''', encoding='utf-8')
(OUT/'README.md').write_text('''# Primordial dos Elementos — morte V1

Revisão criada no Blender aberto, via MCP. O núcleo se contrai, gira e desaparece antes de 0,84 s. Uma onda percorre a coluna, com atraso na perda de sustentação entre pescoço, meio do corpo e cauda. A serpente muda de curvatura e afunda com os segmentos seguindo uma curva suave, mantendo o comprimento original. O corpo se desfaz da cauda a partir de 1,55 s, deixando pescoço e cabeça por último. A cabeça cede e desaparece sob o chão. Duração: 5 s. Sem partículas ou VFX adicionais.

- `index.html` / `Morte.mp4`: prévia com controles, 800 × 800, 30 fps, 151 quadros incluindo a pose final.
- `primordial_death.blend`: cena independente, Death selecionada, quadros 1–151. Espaço reproduz/pausa. Shift+Seta Esquerda volta ao início.
- `primordial_death.glb`: Death, Summon, idle, walk, attack e spell; uma malha, um material, 91 ossos e 1.738 triângulos. Mesma geometria, pesos, UVs, texturas e 125 peças editáveis da invocação aprovada. Nomes dos clipes antigos preservados.
- `validation.json`: 301 poses e meios de quadro; início igual ao repouso, raiz fixa, núcleo desaparecido antes da perda do corpo, coluna conectada, mudança real da curvatura, limite de dobra entre segmentos, malha contínua, final invisível e corpo sob o piso. Os cinco clipes anteriores e as texturas embutidas foram comparados com o GLB da invocação.

A curva da coluna é interpolada com Catmull–Rom e percorrida respeitando o comprimento de cada segmento. As 40 seções existentes acompanham as tangentes da nova curva. Na dissolução, as seções da cauda se recolhem na ponta remanescente, mantendo a malha contínua. Nenhum fragmento, osso adicional ou sistema de partículas foi acrescentado. O movimento fica gravado nos ossos, sem física em tempo real.

Death deve executar uma vez e manter a pose final até remover a unidade, sem retornar a idle. O terreno deve ocultar a geometria que afunda abaixo da superfície. O piso de estúdio existe apenas para revisão e não acompanha o GLB. A revisão ainda não está ligada ao evento de morte no jogo. A invocação aprovada e os assets em uso foram preservados.

Fontes: `tools/art_pipeline/animate_primordial_death_mcp.py`, `finish_primordial_death_mcp.py`, `render_primordial_death_mcp.py` (via `blender_mcp_client.py`) e `package_primordial_death_review.py`.
''', encoding='utf-8')
print(json.dumps(dict(output=str(OUT), validation='PASS', original_clip_error=max_original_error), indent=2))

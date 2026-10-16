"""Check the serialized core-first Summon and package its playable review."""
import bisect
import hashlib
import json
import math
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT/'art_source/seraph_summon_review'
OUT = ROOT/'assets/generated/grand_manifestations/seraph_summon_v1'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT/'assets/generated/grand_manifestations/seraph_blocky_v4_animated/seraph_blocky_v4_animated.glb'


def load(path):
    raw = path.read_bytes()
    length = struct.unpack_from('<I', raw, 12)[0]
    return json.loads(raw[20:20+length]), raw, 28+length


def channels(document, raw, binary):
    result = {}
    for animation in document['animations']:
        rows = {}
        for channel in animation['channels']:
            sampler = animation['samplers'][channel['sampler']]
            values = []
            assert sampler.get('interpolation', 'LINEAR') == 'LINEAR'
            for key in ('input', 'output'):
                accessor = document['accessors'][sampler[key]]
                view = document['bufferViews'][accessor['bufferView']]
                assert accessor['componentType'] == 5126
                width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[accessor['type']]
                stride = view.get('byteStride', width*4)
                offset = binary+view.get('byteOffset', 0)+accessor.get('byteOffset', 0)
                values.append([struct.unpack_from('<'+'f'*width, raw, offset+i*stride)
                               for i in range(accessor['count'])])
            rows[document['nodes'][channel['target']['node']]['name'], channel['target']['path']] = values
        result[animation['name']] = rows
    return result


def evaluate(values, time, rotation):
    times = [row[0] for row in values[0]]
    if len(times) == 1:
        return values[1][0]
    index = max(0, min(len(times)-2, bisect.bisect_right(times, time)-1))
    weight = max(0., min(1., (time-times[index])/(times[index+1]-times[index])))
    a, b = values[1][index], values[1][index+1]
    if rotation:
        a = tuple(x/math.sqrt(sum(v*v for v in a)) for x in a)
        b = tuple(x/math.sqrt(sum(v*v for v in b)) for x in b)
        dot = sum(x*y for x, y in zip(a, b))
        if dot < 0:
            b, dot = tuple(-x for x in b), -dot
        if dot < .9995:
            angle = math.acos(max(-1., min(1., dot)))
            return tuple((x*math.sin((1-weight)*angle)+y*math.sin(weight*angle))/math.sin(angle)
                         for x, y in zip(a, b))
    value = tuple(x+(y-x)*weight for x, y in zip(a, b))
    if rotation:
        norm = math.sqrt(sum(x*x for x in value))
        value = tuple(x/norm for x in value)
    return value


def delta(a, b, rotation):
    error = max(abs(x-y) for x, y in zip(a, b))
    if rotation:
        error = min(error, max(abs(x+y) for x, y in zip(a, b)))
    return error


def image_hashes(document, raw, offset):
    result = []
    for image in document.get('images', []):
        view = document['bufferViews'][image['bufferView']]
        start = offset+view.get('byteOffset', 0)
        result.append(hashlib.sha256(raw[start:start+view['byteLength']]).hexdigest())
    return sorted(result)


doc, raw, binary = load(REVIEW/'seraph_summon.glb')
clips = channels(doc, raw, binary)
original = channels(*load(SOURCE))
assert set(clips) == {'Summon', 'Idle', 'Walk', 'Attack', 'Spell'}
assert image_hashes(doc, raw, binary) == image_hashes(*load(SOURCE))
original_error = 0.
for name, expected in original.items():
    assert expected.keys() <= clips[name].keys()
    for key, old in expected.items():
        new = clips[name][key]
        assert abs(old[0][-1][0]-new[0][-1][0]) < 1e-6
        times = sorted({row[0] for values in (old, new) for row in values[0]})
        for time in times+[(a+b)/2 for a, b in zip(times, times[1:])]:
            original_error = max(original_error, delta(evaluate(old, time, key[1] == 'rotation'),
                evaluate(new, time, key[1] == 'rotation'), key[1] == 'rotation'))
    # Added assembly and flexion joints must remain at their Idle rest transforms.
    for key in clips[name].keys()-expected.keys():
        reference = clips['Idle'][key][1][0]
        for row in clips[name][key][1]:
            assert delta(reference, row, key[1] == 'rotation') < 1e-5, (name, key)
assert original_error < 1e-5, original_error
assert clips['Summon'].keys() == clips['Idle'].keys()
join_error = max(delta(values[1][-1], clips['Idle'][key][1][0], key[1] == 'rotation')
                 for key, values in clips['Summon'].items())
assert join_error < 1e-5, join_error
assert max(values[0][-1][0] for values in clips['Summon'].values()) == 5
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == 56
report = json.loads((REVIEW/'validation.json').read_text(encoding='utf-8'))
report.update(original_four_clips_preserved=True, serialized_original_clip_error=original_error,
              serialized_summon_to_idle_error=join_error, embedded_textures_preserved=True)
if '--validate-only' in sys.argv:
    print(json.dumps(report, indent=2))
    raise SystemExit(0)
assert len(list((REVIEW/'frames_core_first').glob('*.png'))) == 121
for name in ('seraph_summon.blend', 'seraph_summon.glb'):
    shutil.copy2(REVIEW/name, OUT/name)
(OUT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
subprocess.run([shutil.which('ffmpeg'), '-hide_banner', '-loglevel', 'error', '-y',
    '-framerate', '24', '-start_number', '1', '-i', str(REVIEW/'frames_core_first/%04d.png'),
    '-frames:v', '121', '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p',
    '-movflags', '+faststart', str(OUT/'Invocacao.mp4')], check=True)
shutil.copy2(REVIEW/'frames_core_first/0091.png', OUT/'preview.png')
(OUT/'index.html').write_text('''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Serafim · Invocação</title><style>
body{margin:0;background:#151a22;color:#eee7d8;font:16px system-ui;display:grid;place-items:center;min-height:100vh}
main{max-width:800px;padding:24px}h1{font-size:26px}p{color:#bdc2cc;line-height:1.6}
video{width:100%;max-height:72vh;border-radius:8px;background:#232a34;display:block}
a{color:#ebc477;margin-right:18px}button{background:#ebc477;border:0;border-radius:5px;padding:10px 18px;cursor:pointer;margin:16px 0;font:inherit}
</style><main><h1>Serafim · Invocação</h1>
<video id="v" controls playsinline preload="auto" poster="preview.png?v=nucleo2" src="Invocacao.mp4?v=nucleo2"></video>
<button onclick="const v=document.getElementById('v');v.currentTime=0;v.play()">Reproduzir do início</button>
<p>O núcleo surge sozinho. As peças douradas se encaixam, as auréolas giram e a estrutura se forma atrás dele. Os três pares de asas crescem e se abrem em ondas, com flexão e acomodação suave. Duração: 5 segundos. Sem partículas.</p>
<p><a href="seraph_summon.blend">Fonte Blender</a><a href="seraph_summon.glb">Modelo animado GLB</a></p>
</main></html>''', encoding='utf-8')
(OUT/'README.md').write_text('''# Serafim — invocação revisada: núcleo primeiro

Revisão criada no Blender aberto, via MCP. O cubo luminoso aparece entre 0,08 e 0,65 s e permanece sozinho até 0,9 s. Depois, as 12 arestas douradas se encaixam ao redor dele, as duas auréolas crescem atrás do núcleo e avançam girando, e as peças da estrutura traseira se montam. As bases douradas e os pares de asas entram em sequência: coroa, principais e inferiores. As asas crescem a partir das raízes, flexionam e abrem com leve ultrapassagem e acomodação. O movimento termina exatamente na primeira pose de Idle.

- `index.html` / `Invocacao.mp4`: prévia com controles, 800 × 800, 24 fps, 121 quadros incluindo a pose final (5 segundos de movimento).
- `seraph_summon.blend`: cena independente, Summon selecionada, quadros 1–121. Espaço reproduz/pausa; Shift+Seta Esquerda volta ao início.
- `seraph_summon.glb`: Summon, Idle, Walk, Attack e Spell. Uma malha, um material, 56 ossos e os mesmos 2.072 triângulos. Geometria, UVs e texturas da V4 preservados. Foram acrescentados 27 controles de montagem e 18 de flexão; novos pesos nas asas conservam o movimento original com os controles em repouso.
- `validation.json`: 241 poses e meios de quadro; início invisível, núcleo isolado na abertura, raiz fixa, geometria acima do piso, nenhum novo cruzamento das asas após a formação e pose final idêntica a Idle. As quatro animações existentes e as texturas embutidas foram comparadas com o GLB original; a deformação original também foi conferida antes e depois dos novos controles.

Sem partículas ou malhas adicionais de efeitos. A animação fica gravada nos ossos e não depende de física ou visibilidade específica do Blender. O estúdio serve apenas à revisão e não acompanha o GLB. Summon deve executar uma vez e seguir para Idle. A revisão ainda não está ligada ao evento de nascimento no jogo. Os assets em uso, a morte do Serafim e as outras manifestações permanecem preservados.

Fontes: `tools/art_pipeline/animate_seraph_summon_mcp.py` (encaminha para `animate_seraph_assembly_mcp.py`), `finish_seraph_summon_mcp.py`, `render_seraph_summon_mcp.py` e `package_seraph_summon_review.py` (encaminha para `package_seraph_assembly_review.py`). Os scripts de Blender executam pelo cliente MCP local.
''', encoding='utf-8')
print(json.dumps(dict(output=str(OUT), validation='PASS', original_clip_error=original_error), indent=2))

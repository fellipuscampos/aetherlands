"""Check serialized Death channels and package its playable, particle-free review."""
import hashlib
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT/'art_source/seraph_death_review'
OUT = ROOT/'assets/generated/grand_manifestations/seraph_death_v1'
OUT.mkdir(parents=True, exist_ok=True)
raw = (REVIEW/'seraph_death.glb').read_bytes()
length = struct.unpack_from('<I', raw, 12)[0]
doc = json.loads(raw[20:20+length])
binary = 28+length


def values(accessor_id):
    a = doc['accessors'][accessor_id]
    v = doc['bufferViews'][a['bufferView']]
    assert a['componentType'] == 5126
    width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[a['type']]
    stride = v.get('byteStride', width*4)
    offset = binary+v.get('byteOffset', 0)+a.get('byteOffset', 0)
    return [struct.unpack_from('<'+'f'*width, raw, offset+i*stride)
            for i in range(a['count'])]


def channels(animation):
    result = {}
    for c in animation['channels']:
        s = animation['samplers'][c['sampler']]
        result[c['target']['node'], c['target']['path']] = values(s['output'])
    return result


animations = {a['name']: a for a in doc['animations']}
assert set(animations) == {'Death', 'Summon', 'Idle', 'Walk', 'Attack', 'Spell'}
death = channels(animations['Death'])
idle = channels(animations['Idle'])
assert death.keys() == idle.keys()
seam = max(abs(x-y) for k in idle for x, y in zip(death[k][0], idle[k][0]))
assert seam < 1e-5, seam
body = next(i for i, n in enumerate(doc['nodes']) if n.get('name') == 'body')
assert max(death[body, 'scale'][-1]) <= .000011
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
# Existing clips are byte-identical at their sampled channels, even after re-export.
original = ROOT/'assets/generated/grand_manifestations/seraph_summon_v1/seraph_summon.glb'
old_raw = original.read_bytes()
old_length = struct.unpack_from('<I', old_raw, 12)[0]
old_doc = json.loads(old_raw[20:20+old_length])
old_binary = 28+old_length


def signatures(document, data, bin_offset):
    result = {}
    for animation in document['animations']:
        clips = {}
        for c in animation['channels']:
            s = animation['samplers'][c['sampler']]
            fingerprints = []
            for key in ('input', 'output'):
                a = document['accessors'][s[key]]
                v = document['bufferViews'][a['bufferView']]
                width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[a['type']]*4
                stride = v.get('byteStride', width)
                offset = bin_offset+v.get('byteOffset', 0)+a.get('byteOffset', 0)
                fingerprints.append(hashlib.sha256(b''.join(
                    data[offset+i*stride:offset+i*stride+width] for i in range(a['count'])
                )).hexdigest())
            target = document['nodes'][c['target']['node']]['name']
            clips[target, c['target']['path']] = fingerprints
        result[animation['name']] = clips
    return result


new_sig = signatures(doc, raw, binary)
old_sig = signatures(old_doc, old_raw, old_binary)
for name, signature in old_sig.items():
    assert new_sig[name] == signature, ('Existing clip changed', name)
report = json.loads((REVIEW/'validation.json').read_text(encoding='utf-8'))
report.update(serialized_death_to_idle_start_error=seam,
              existing_five_clips_unchanged=True, particles_included=False)
if '--validate-only' in sys.argv:
    print(json.dumps(report, indent=2))
    raise SystemExit(0)
frames = sorted((REVIEW/'frames').glob('*.png'))
assert len(frames) == 85, f'Render incomplete: {len(frames)}/85'
for name in ['seraph_death.blend', 'seraph_death.glb']:
    shutil.copy2(REVIEW/name, OUT/name)
(OUT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
ffmpeg = shutil.which('ffmpeg')
assert ffmpeg
subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
                '-framerate', '24', '-start_number', '1', '-i', str(REVIEW/'frames/%04d.png'),
                '-frames:v', '85', '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p',
                '-movflags', '+faststart', str(OUT/'Morte.mp4')], check=True)
shutil.copy2(REVIEW/'frames/0037.png', OUT/'preview.png')
(OUT/'index.html').write_text('''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Serafim · Morte</title><style>
body{margin:0;background:#151a22;color:#eee7d8;font:16px system-ui;display:grid;place-items:center;min-height:100vh}
main{max-width:800px;padding:24px}h1{font-size:26px}p{color:#bdc2cc;line-height:1.6}
video{width:100%;max-height:72vh;border-radius:8px;background:#232a34;display:block}
a{color:#ebc477;margin-right:18px}button{background:#ebc477;border:0;border-radius:5px;padding:10px 18px;cursor:pointer;margin:16px 0;font:inherit}
</style><main><h1>Serafim · Morte</h1>
<video id="v" controls playsinline preload="auto" poster="preview.png" src="Morte.mp4"></video>
<button onclick="const v=document.getElementById('v');v.currentTime=0;v.play()">Reproduzir do início</button>
<p>Impacto, perda de sustentação, recolhimento das asas e colapso do núcleo e das auréolas. Duração: 3,5 segundos. Sem partículas; os efeitos serão feitos no Godot.</p>
<p><a href="seraph_death.blend">Fonte Blender</a><a href="seraph_death.glb">Modelo animado GLB</a><a href="../seraph_summon_v1/index.html">Ver invocação</a></p>
</main></html>''', encoding='utf-8')
(OUT/'README.md').write_text('''# Serafim — morte V1

Criada no Blender aberto por MCP, somente com animação dos ossos. Sem partículas, selo ou outros efeitos; VFX serão feitos no Godot.

- `index.html` / `Morte.mp4`: prévia de 800 × 800, 24 fps, com botão de reprodução.
- `seraph_death.blend`: cena independente, Death selecionada; quadros 1–85 (3,5 s). Espaço: reproduzir/pausar. Shift+Seta Esquerda: início.
- `seraph_death.glb`: Death, Summon, Idle, Walk, Attack e Spell. Uma malha, um material e 11 ossos; texturas incorporadas. As cinco animações anteriores são preservadas.
- `validation.json`: 169 poses verificadas, incluindo meios de quadro; início idêntico ao repouso, raiz fixa, asas sem novos cruzamentos antes de se extinguirem e sem atravessar o chão.

Death começa no repouso com uma reação curta ao impacto. As asas cedem com atraso entre os lados; as auréolas perdem alinhamento, caem e desaceleram. O núcleo se contrai e desaparece, seguido pelo restante da manifestação. No final, a escala positiva mínima mantém o rig válido, com a geometria imperceptível.

Na integração, Death deve executar uma vez, conservar o último quadro e remover a unidade ao terminar; não retornar a Idle. A cena é uma revisão e ainda não está ligada ao evento de morte no jogo.

Fontes: `tools/art_pipeline/animate_seraph_death_mcp.py`, `finish_seraph_death_mcp.py`, `render_seraph_death_mcp.py` e `package_seraph_death_review.py`. Os três primeiros usam `blender_mcp_client.py`. A invocação aprovada e os assets usados pelo jogo permanecem preservados.
''', encoding='utf-8')
print(json.dumps({'output': str(OUT), 'validation': 'PASS',
                  'existing_clips_unchanged': True}, indent=2))

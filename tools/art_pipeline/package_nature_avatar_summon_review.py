"""Verify serialized channels and package the Nature Avatar Summon and playable preview."""
import hashlib
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT/'art_source/nature_avatar_summon_review'
OUT = ROOT/'assets/generated/grand_manifestations/nature_avatar_summon_v1'
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


doc, raw, binary = load(REVIEW/'nature_avatar_summon.glb')
clips = channels(doc, raw, binary)
assert set(clips) == {'Summon', 'Idle', 'Walk', 'Attack', 'Spell'}
original_path = ROOT/'assets/generated/grand_manifestations/nature_avatar_blocky_v5_animated/nature_avatar_blocky_v5_animated.glb'
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
max_assembly_rest_error = 0.
for name, expected in original.items():
    assert expected.keys() <= clips[name].keys(), name
    for key, old_values in expected.items():
        for old_rows, new_rows in zip(old_values, clips[name][key]):
            assert len(old_rows) == len(new_rows), (name, key)
            max_original_error = max(max_original_error, max(abs(a-b) for old_row, new_row in zip(old_rows, new_rows)
                                                             for a, b in zip(old_row, new_row)))
    for key in clips[name].keys()-expected.keys():
        assert key[0].startswith('assemble_'), key
        values = clips[name][key][1]
        max_assembly_rest_error = max(max_assembly_rest_error,
            max(abs(a-b) for row in values for a, b in zip(row, values[0])))
assert max_original_error < 1e-5, max_original_error
assert max_assembly_rest_error < 1e-5, max_assembly_rest_error
assert clips['Summon'].keys() == clips['Idle'].keys()
join_error = 0.
for key in clips['Idle']:
    a, b = clips['Summon'][key][1][-1], clips['Idle'][key][1][0]
    error = max(abs(x-y) for x, y in zip(a, b))
    if key[1] == 'rotation':
        error = min(error, max(abs(x+y) for x, y in zip(a, b)))
    join_error = max(join_error, error)
assert join_error < 1e-5, join_error
assert max(clips['Summon'][key][0][-1][0] for key in clips['Summon']) == 5.
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == 103
report = json.loads((REVIEW/'validation.json').read_text(encoding='utf-8'))
report.update(original_four_clips_preserved=True, serialized_original_clip_error=max_original_error,
              serialized_summon_to_idle_error=join_error, embedded_textures_preserved=True,
              old_clips_assembly_joints_constant=True, assembly_joint_rest_error=max_assembly_rest_error)
if '--validate-only' in sys.argv:
    print(json.dumps(report, indent=2))
    raise SystemExit(0)
assert len(list((REVIEW/'frames').glob('*.png'))) == 121
for name in ('nature_avatar_summon.blend', 'nature_avatar_summon.glb'):
    shutil.copy2(REVIEW/name, OUT/name)
(OUT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
ffmpeg = shutil.which('ffmpeg')
assert ffmpeg
subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
                '-framerate', '24', '-start_number', '1', '-i', str(REVIEW/'frames/%04d.png'),
                '-frames:v', '121', '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p',
                '-movflags', '+faststart', str(OUT/'Invocacao.mp4')], check=True)
shutil.copy2(REVIEW/'frames/0049.png', OUT/'preview.png')
(OUT/'index.html').write_text('''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Avatar da Natureza · Invocação</title><style>
body{margin:0;background:#151d18;color:#eee7d8;font:16px system-ui;display:grid;place-items:center;min-height:100vh}
main{max-width:800px;padding:24px}h1{font-size:26px}p{color:#bdc9bf;line-height:1.6}
video{width:100%;max-height:72vh;border-radius:8px;background:#232e27;display:block}
a{color:#bbdba8;margin-right:18px}button{background:#b3cf9c;border:0;border-radius:5px;padding:10px 18px;cursor:pointer;margin:16px 0;font:inherit}
</style><main><h1>Avatar da Natureza · Invocação</h1>
<video id="v" controls playsinline preload="auto" poster="preview.png?v=montagem" src="Invocacao.mp4?v=montagem"></video>
<button onclick="const v=document.getElementById('v');v.currentTime=0;v.play()">Reproduzir do início</button>
<p>Primeiro surge o núcleo. Depois, 85 peças de madeira aparecem ao redor, giram e se encaixam para formar o tronco, a coroa, os braços e as raízes do Avatar. Duração: 5 segundos. Sem partículas; os efeitos serão feitos no Godot.</p>
<p><a href="nature_avatar_summon.blend">Fonte Blender</a><a href="nature_avatar_summon.glb">Modelo animado GLB</a></p>
</main></html>''', encoding='utf-8')
(OUT/'README.md').write_text('''# Avatar da Natureza — invocação V1

Animação criada no Blender aberto, via MCP. Primeiro o núcleo aparece sozinho. Em seguida, as 85 peças de madeira do próprio modelo se formam ao redor, descrevem arcos e se encaixam para montar o Avatar: tronco, coroa, braços e raízes. O conjunto se acomoda na pose inicial de Idle. Sem partículas ou efeitos adicionais; VFX serão feitos no Godot. O núcleo verde é a geometria original.

- `index.html` / `Invocacao.mp4`: prévia com controles de reprodução, 800 × 800, 24 fps, 121 quadros incluindo a pose final (5 segundos de movimento).
- `nature_avatar_summon.blend`: cena independente, Summon selecionada, quadros 1–121. Espaço reproduz/pausa. Shift+Seta Esquerda volta ao início.
- `nature_avatar_summon.glb`: Summon, Idle, Walk, Attack e Spell; uma malha, um material, 103 ossos e 2.060 triângulos. As 86 peças editáveis, geometria, UVs e texturas foram preservados. Os 18 ossos originais recebem 85 filhos, um por peça de madeira, permitindo a montagem independente sem alterar as quatro animações anteriores.
- `validation.json`: 241 poses e meios de quadro; núcleo sozinho aos 0,625 s, raiz fixa, peças acima do chão, núcleo sem interseção com a madeira, encaixe final e pose final igual ao início de Idle. Os canais dos 18 ossos originais e as texturas embutidas foram comparados com o GLB original; os novos ossos ficam em repouso nas quatro animações anteriores. A deformação dos clipes originais também foi comparada antes e depois de adicionar os ossos de montagem.

Summon deve executar uma vez e seguir para Idle. A formação e os encaixes são gravados nos ossos; não dependem de física em tempo real, partículas, scripts de visibilidade ou helpers no jogo. O piso de estúdio é apenas para revisão e não acompanha o GLB.

Revisão de arte, ainda sem ligação ao evento de nascimento no jogo. Os modelos em uso, suas quatro animações e as animações anteriores das outras manifestações foram preservados.

Fontes: `tools/art_pipeline/animate_nature_avatar_summon_mcp.py` chama `animate_nature_avatar_assembly_mcp.py`; `finish_nature_avatar_summon_mcp.py`, `render_nature_avatar_summon_mcp.py` (via `blender_mcp_client.py`) e `package_nature_avatar_summon_review.py` validam, exportam e empacotam.
''', encoding='utf-8')
print(json.dumps(dict(output=str(OUT), validation='PASS', original_clip_error=max_original_error), indent=2))

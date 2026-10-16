"""Verify serialized channels and package the Lich Summon and playable preview."""
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT/'art_source/elder_lich_summon_review'
OUT = ROOT/'assets/generated/grand_manifestations/elder_lich_summon_v1'
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


doc, raw, binary = load(REVIEW/'elder_lich_summon.glb')
clips = channels(doc, raw, binary)
assert set(clips) == {'Summon', 'Idle', 'Walk', 'Attack', 'Spell'}
original_path = ROOT/'assets/generated/grand_manifestations/elder_lich_blocky_v3_animated/elder_lich_blocky_v3_animated.glb'
original = channels(*load(original_path))
max_original_error = 0.
for name, expected in original.items():
    assert clips[name].keys() == expected.keys(), name
    for key, old_values in expected.items():
        for old_rows, new_rows in zip(old_values, clips[name][key]):
            assert len(old_rows) == len(new_rows), (name, key)
            max_original_error = max(max_original_error, max(abs(a-b) for old_row, new_row in zip(old_rows, new_rows)
                                                             for a, b in zip(old_row, new_row)))
assert max_original_error < 1e-5, max_original_error
assert clips['Summon'].keys() == clips['Idle'].keys()
join_error = max(abs(a-b) for key in clips['Idle']
                 for a, b in zip(clips['Summon'][key][1][-1], clips['Idle'][key][1][0]))
assert join_error < 1e-5, join_error
assert max(clips['Summon'][key][0][-1][0] for key in clips['Summon']) == 4.
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == 37
report = json.loads((REVIEW/'validation.json').read_text(encoding='utf-8'))
report.update(original_four_clips_preserved=True, serialized_original_clip_error=max_original_error,
              serialized_summon_to_idle_error=join_error)
if '--validate-only' in sys.argv:
    print(json.dumps(report, indent=2))
    raise SystemExit(0)
assert len(list((REVIEW/'frames').glob('*.png'))) == 97
for name in ('elder_lich_summon.blend', 'elder_lich_summon.glb'):
    shutil.copy2(REVIEW/name, OUT/name)
(OUT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
ffmpeg = shutil.which('ffmpeg')
assert ffmpeg
subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
                '-framerate', '24', '-start_number', '1', '-i', str(REVIEW/'frames/%04d.png'),
                '-frames:v', '97', '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p',
                '-movflags', '+faststart', str(OUT/'Invocacao.mp4')], check=True)
shutil.copy2(REVIEW/'frames/0049.png', OUT/'preview.png')
(OUT/'index.html').write_text('''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ancião Lich · Invocação</title><style>
body{margin:0;background:#151a22;color:#eee7d8;font:16px system-ui;display:grid;place-items:center;min-height:100vh}
main{max-width:800px;padding:24px}h1{font-size:26px}p{color:#bdc2cc;line-height:1.6}
video{width:100%;max-height:72vh;border-radius:8px;background:#232a34;display:block}
a{color:#d0b3ed;margin-right:18px}button{background:#bda0d5;border:0;border-radius:5px;padding:10px 18px;cursor:pointer;margin:16px 0;font:inherit}
</style><main><h1>Ancião Lich · Invocação</h1>
<video id="v" controls playsinline preload="auto" poster="preview.png" src="Invocacao.mp4"></video>
<button onclick="const v=document.getElementById('v');v.currentTime=0;v.play()">Reproduzir do início</button>
<p>O Lich emerge do chão com a cabeça baixa, ergue o cajado e o grimório e se acomoda na flutuação de repouso. Duração: 4 segundos. Sem partículas; os efeitos serão feitos no Godot.</p>
<p><a href="elder_lich_summon.blend">Fonte Blender</a><a href="elder_lich_summon.glb">Modelo animado GLB</a></p>
</main></html>''', encoding='utf-8')
(OUT/'README.md').write_text('''# Ancião Lich — invocação V1

Animação criada no Blender aberto, via MCP. O Lich emerge debaixo do piso com a cabeça baixa, desperta, ergue o cajado e o grimório e se acomoda na flutuação de repouso. Sem partículas ou efeitos adicionais; VFX serão feitos no Godot. A geometria espectral que já faz parte do modelo aprovado foi preservada.

- `index.html` / `Invocacao.mp4`: prévia com controles de reprodução; 800 × 800, 24 fps, 97 quadros incluindo a pose final (4 segundos de movimento).
- `elder_lich_summon.blend`: cena independente, Summon selecionada, quadros 1–97. Espaço: reproduzir/pausar. Shift+Seta Esquerda: início.
- `elder_lich_summon.glb`: Summon, Idle, Walk, Attack e Spell; uma malha, um material, 37 ossos e 1.548 triângulos. Modelo, textura, pesos e UVs originais preservados.
- `validation.json`: 193 poses e meios de quadro; raiz fixa, início abaixo do piso, corpo acima do chão ao terminar a emergência, braços conectados, punhos dentro do limite de 35°, vestes presas ao torso e adereços sem interseção com corpo/cabeça. Os quatro clipes existentes foram comparados no GLB exportado e a ligação ao Idle foi conferida.

Summon deve executar uma vez e seguir para Idle. O clipe move o osso do corpo verticalmente debaixo do chão até a pose de referência, mantendo a raiz da unidade fixa; o terreno deve ocultar a parte ainda subterrânea. A cena de estúdio fornece esse piso apenas para revisão: ele não é exportado no GLB.

Revisão de arte, ainda sem ligação ao evento de nascimento no jogo. Os assets em uso pelo jogo, as animações do Serafim e as do Arquidemônio foram preservados.

Fontes: `tools/art_pipeline/animate_elder_lich_summon_mcp.py`, `finish_elder_lich_summon_mcp.py`, `render_elder_lich_summon_mcp.py` (via `blender_mcp_client.py`) e `package_elder_lich_summon_review.py`.
''', encoding='utf-8')
print(json.dumps(dict(output=str(OUT), validation='PASS', original_clip_error=max_original_error), indent=2))

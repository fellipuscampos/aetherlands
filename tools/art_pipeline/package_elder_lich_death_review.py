"""Verify serialized channels and package the Lich Death and playable preview."""
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT/'art_source/elder_lich_death_review'
OUT = ROOT/'assets/generated/grand_manifestations/elder_lich_death_v1'
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


doc, raw, binary = load(REVIEW/'elder_lich_death.glb')
clips = channels(doc, raw, binary)
assert set(clips) == {'Summon', 'Death', 'Idle', 'Walk', 'Attack', 'Spell'}
original_path = ROOT/'assets/generated/grand_manifestations/elder_lich_summon_v1/elder_lich_summon.glb'
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
assert clips['Death'].keys() == clips['Idle'].keys()
join_error = max(abs(a-b) for key in clips['Idle']
                 for a, b in zip(clips['Death'][key][1][0], clips['Idle'][key][1][0]))
assert join_error < 1e-5, join_error
assert max(clips['Death'][key][0][-1][0] for key in clips['Death']) == 5.
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == 37
report = json.loads((REVIEW/'validation.json').read_text(encoding='utf-8'))
report.update(original_five_clips_preserved=True, serialized_original_clip_error=max_original_error,
              serialized_death_to_idle_error=join_error)
if '--validate-only' in sys.argv:
    print(json.dumps(report, indent=2))
    raise SystemExit(0)
assert len(list((REVIEW/'frames').glob('*.png'))) == 121
for name in ('elder_lich_death.blend', 'elder_lich_death.glb'):
    shutil.copy2(REVIEW/name, OUT/name)
(OUT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
ffmpeg = shutil.which('ffmpeg')
assert ffmpeg
subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
                '-framerate', '24', '-start_number', '1', '-i', str(REVIEW/'frames/%04d.png'),
                '-frames:v', '121', '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p',
                '-movflags', '+faststart', str(OUT/'Morte.mp4')], check=True)
shutil.copy2(REVIEW/'frames/0053.png', OUT/'preview.png')
(OUT/'index.html').write_text('''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ancião Lich · Morte</title><style>
body{margin:0;background:#151a22;color:#eee7d8;font:16px system-ui;display:grid;place-items:center;min-height:100vh}
main{max-width:800px;padding:24px}h1{font-size:26px}p{color:#bdc2cc;line-height:1.6}
video{width:100%;max-height:72vh;border-radius:8px;background:#232a34;display:block}
a{color:#d0b3ed;margin-right:18px}button{background:#bda0d5;border:0;border-radius:5px;padding:10px 18px;cursor:pointer;margin:16px 0;font:inherit}
</style><main><h1>Ancião Lich · Morte</h1>
<video id="v" controls playsinline preload="auto" poster="preview.png?v=agonia2" src="Morte.mp4?v=agonia2"></video>
<button onclick="const v=document.getElementById('v');v.currentTime=0;v.play()">Reproduzir do início</button>
<p>O Lich afunda enquanto agoniza: força o cajado, ergue a cabeça em três tentativas de resistir e perde força a cada esforço, até desaparecer sob o chão. Duração: 5 segundos. Sem partículas; os efeitos serão feitos no Godot.</p>
<p><a href="elder_lich_death.blend">Fonte Blender</a><a href="elder_lich_death.glb">Modelo com seis animações</a><a href="../elder_lich_summon_v1/index.html">Ver invocação</a></p>
</main></html>''', encoding='utf-8')
(OUT/'README.md').write_text('''# Ancião Lich — morte V1

Revisão da morte criada no Blender aberto, via MCP. O Lich afunda enquanto agoniza: reage ao impacto, curva o tronco e tenta se erguer apoiado no cajado. Três esforços assimétricos erguem a cabeça e os braços, com tremores breves; entre eles o corpo cede e afunda mais. O braço do grimório perde força gradualmente. Cajado, livro e vestes acompanham o corpo até tudo desaparecer abaixo do chão. A escala permanece igual durante os 5 segundos; o desaparecimento ocorre por submersão. Sem partículas ou efeitos adicionais: VFX serão feitos no Godot.

- `index.html` / `Morte.mp4`: prévia com controles de reprodução; 800 × 800, 24 fps, 121 quadros incluindo a pose final (5 segundos de movimento).
- `elder_lich_death.blend`: cena independente, Death selecionada, quadros 1–121. Espaço: reproduzir/pausar. Shift+Seta Esquerda: início.
- `elder_lich_death.glb`: Death, Summon, Idle, Walk, Attack e Spell; uma malha, um material, 37 ossos e 1.548 triângulos. Geometria, textura, pesos e UVs preservados.
- `validation.json`: 241 poses e meios de quadro; início no repouso, raiz fixa, braços conectados, vestes presas ao corpo, escala constante, ausência de colisões dos adereços com o tronco e submersão completa na pose final. Os cinco clipes anteriores foram comparados no GLB exportado.

Death deve executar uma vez e manter a pose final até remover a unidade, sem retornar a Idle. O movimento é gravado nos ossos; não depende de física em tempo real. O terreno do jogo precisa ocultar a geometria que afunda abaixo da superfície. O piso de estúdio é apenas para revisão e não acompanha o GLB.

Revisão de arte, ainda sem ligação ao evento de morte no jogo. A invocação aprovada, os assets em uso e as cenas das outras manifestações foram preservados.

Fontes: `tools/art_pipeline/animate_elder_lich_death_mcp.py`, `finish_elder_lich_death_mcp.py`, `render_elder_lich_death_mcp.py` (via `blender_mcp_client.py`) e `package_elder_lich_death_review.py`.
''', encoding='utf-8')
print(json.dumps(dict(output=str(OUT), validation='PASS', original_clip_error=max_original_error), indent=2))

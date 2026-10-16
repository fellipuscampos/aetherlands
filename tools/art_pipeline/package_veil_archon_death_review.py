"""Verify serialized channels and package the Veil Archon Death and playable preview."""
import hashlib
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT/'art_source/veil_archon_death_review'
OUT = ROOT/'assets/generated/grand_manifestations/veil_archon_death_v1'
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


doc, raw, binary = load(REVIEW/'veil_archon_death.glb')
clips = channels(doc, raw, binary)
assert set(clips) == {'Summon', 'Death', 'Idle', 'Walk', 'Attack', 'Spell'}
original_path = ROOT/'assets/generated/grand_manifestations/veil_archon_summon_v1/veil_archon_summon.glb'
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
for name, expected in original.items():
    assert expected.keys() == clips[name].keys(), name
    for key, old_values in expected.items():
        for old_rows, new_rows in zip(old_values, clips[name][key]):
            assert len(old_rows) == len(new_rows), (name, key)
            max_original_error = max(max_original_error, max(abs(a-b) for old_row, new_row in zip(old_rows, new_rows)
                                                             for a, b in zip(old_row, new_row)))
assert max_original_error < 1e-5, max_original_error
assert clips['Death'].keys() == clips['Idle'].keys()
join_error = 0.
for key in clips['Idle']:
    a, b = clips['Death'][key][1][0], clips['Idle'][key][1][0]
    error = max(abs(x-y) for x, y in zip(a, b))
    if key[1] == 'rotation':
        error = min(error, max(abs(x+y) for x, y in zip(a, b)))
    join_error = max(join_error, error)
assert join_error < 1e-5, join_error
assert max(clips['Death'][key][0][-1][0] for key in clips['Death']) == 5.
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == 39
report = json.loads((REVIEW/'validation.json').read_text(encoding='utf-8'))
report.update(original_five_clips_preserved=True, serialized_original_clip_error=max_original_error,
              serialized_death_to_idle_error=join_error, embedded_textures_preserved=True)
if '--validate-only' in sys.argv:
    print(json.dumps(report, indent=2))
    raise SystemExit(0)
assert len(list((REVIEW/'frames').glob('*.png'))) == 121
for name in ('veil_archon_death.blend', 'veil_archon_death.glb'):
    shutil.copy2(REVIEW/name, OUT/name)
(OUT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
ffmpeg = shutil.which('ffmpeg')
assert ffmpeg
subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
                '-framerate', '24', '-start_number', '1', '-i', str(REVIEW/'frames/%04d.png'),
                '-frames:v', '121', '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p',
                '-movflags', '+faststart', str(OUT/'Morte.mp4')], check=True)
shutil.copy2(REVIEW/'frames/0073.png', OUT/'preview.png')
(OUT/'index.html').write_text('''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Arconte do Véu · Morte</title><style>
body{margin:0;background:#181522;color:#eee7f4;font:16px system-ui;display:grid;place-items:center;min-height:100vh}
main{max-width:800px;padding:24px}h1{font-size:26px}p{color:#c4bdd1;line-height:1.6}
video{width:100%;max-height:72vh;border-radius:8px;background:#282334;display:block}
a{color:#cab9ee;margin-right:18px}button{background:#c4ace2;border:0;border-radius:5px;padding:10px 18px;cursor:pointer;margin:16px 0;font:inherit}
</style><main><h1>Arconte do Véu · Morte</h1>
<video id="v" controls playsinline preload="auto" poster="preview.png" src="Morte.mp4"></video>
<button onclick="const v=document.getElementById('v');v.currentTime=0;v.play()">Reproduzir do início</button>
<p>O núcleo colapsa, a estrutura luminosa desaparece e as placas rúnicas perdem sustentação. Elas caem perto da posição original, repousam no chão e depois desaparecem. Duração: 5 segundos. Sem partículas; os efeitos serão feitos no Godot.</p>
<p><a href="veil_archon_death.blend">Fonte Blender</a><a href="veil_archon_death.glb">Modelo com seis animações</a><a href="../veil_archon_summon_v1/index.html">Ver invocação</a></p>
</main></html>''', encoding='utf-8')
(OUT/'README.md').write_text('''# Arconte do Véu — morte V1

Animação criada no Blender aberto, via MCP. O núcleo se contrai e gira até desaparecer aos 0,76 s. A armação luminosa se fecha em seguida e desaparece aos 1,13 s. As 34 placas rúnicas ficam suspensas até esse colapso terminar, depois se soltam em sequência, caem e se acomodam perto da posição original. Permanecem em tamanho integral até 4 s e desaparecem entre 4 e 4,8 s. O clipe termina aos 5 s. Sem partículas ou VFX adicionais; núcleo e estrutura são a geometria original do modelo.

- `index.html` / `Morte.mp4`: prévia com controles, 800 × 800, 24 fps, 121 quadros incluindo a pose final (5 segundos de movimento).
- `veil_archon_death.blend`: cena independente, Death selecionada, quadros 1–121. Espaço reproduz/pausa. Shift+Seta Esquerda volta ao início.
- `veil_archon_death.glb`: Death, Summon, Idle, Walk, Attack e Spell; uma malha, um material, 39 ossos e 1.364 triângulos. Mesma geometria, pesos, UVs, textura e rig da invocação aprovada; 47 peças editáveis na fonte.
- `validation.json`: 241 poses e meios de quadro; início no repouso, raiz fixa, núcleo e armação desaparecidos antes da queda, placas imóveis durante o colapso, contato com o chão, tamanho integral até 4 s e desaparecimento posterior. A pilha ocupa cerca de 3,26 × 3,30 m, próxima do diâmetro original. Os cinco clipes existentes e as texturas embutidas foram comparados com o GLB da invocação.

A queda das 34 placas usa Bullet durante a criação, com gravidade de −9,81 m/s², 32 subpassos e 50 iterações. As placas usam camadas de colisão para evitar impulsos de facetas vizinhas na posição inicial. Piso e limites temporários mantêm a queda compacta. Toda a animação é gravada nos ossos existentes; helpers, colisores e física não acompanham o asset.

Death deve executar uma vez e manter a pose final até remover a unidade, sem retornar a Idle. O piso de estúdio é apenas para revisão e não acompanha o GLB. Revisão de arte ainda sem ligação ao evento de morte no jogo. A invocação aprovada, os outros clipes e os assets em uso foram preservados.

Fontes: `tools/art_pipeline/animate_veil_archon_death_mcp.py`, `finish_veil_archon_death_mcp.py`, `render_veil_archon_death_mcp.py` (via `blender_mcp_client.py`) e `package_veil_archon_death_review.py`.
''', encoding='utf-8')
print(json.dumps(dict(output=str(OUT), validation='PASS', original_clip_error=max_original_error), indent=2))

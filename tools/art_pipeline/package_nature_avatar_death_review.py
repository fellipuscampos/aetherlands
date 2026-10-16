"""Verify serialized channels and package the Nature Avatar Death and playable preview."""
import hashlib
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT/'art_source/nature_avatar_death_review'
OUT = ROOT/'assets/generated/grand_manifestations/nature_avatar_death_v1'
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


doc, raw, binary = load(REVIEW/'nature_avatar_death.glb')
clips = channels(doc, raw, binary)
assert set(clips) == {'Summon', 'Death', 'Idle', 'Walk', 'Attack', 'Spell'}
original_path = ROOT/'assets/generated/grand_manifestations/nature_avatar_summon_v1/nature_avatar_summon.glb'
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
assert len(doc['skins'][0]['joints']) == 103
report = json.loads((REVIEW/'validation.json').read_text(encoding='utf-8'))
report.update(original_five_clips_preserved=True, serialized_original_clip_error=max_original_error,
              serialized_death_to_idle_error=join_error, embedded_textures_preserved=True)
if '--validate-only' in sys.argv:
    print(json.dumps(report, indent=2))
    raise SystemExit(0)
assert len(list((REVIEW/'frames').glob('*.png'))) == 121
for name in ('nature_avatar_death.blend', 'nature_avatar_death.glb'):
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
<title>Avatar da Natureza · Morte</title><style>
body{margin:0;background:#151d18;color:#eee7d8;font:16px system-ui;display:grid;place-items:center;min-height:100vh}
main{max-width:800px;padding:24px}h1{font-size:26px}p{color:#bdc9bf;line-height:1.6}
video{width:100%;max-height:72vh;border-radius:8px;background:#232e27;display:block}
a{color:#bbdba8;margin-right:18px}button{background:#b3cf9c;border:0;border-radius:5px;padding:10px 18px;cursor:pointer;margin:16px 0;font:inherit}
</style><main><h1>Avatar da Natureza · Morte</h1>
<video id="v" controls playsinline preload="auto" poster="preview.png?v=nucleo-primeiro" src="Morte.mp4?v=nucleo-primeiro"></video>
<button onclick="const v=document.getElementById('v');v.currentTime=0;v.play()">Reproduzir do início</button>
<p>Primeiro o núcleo se contrai, gira e desaparece dentro do peito. Só depois a madeira perde sustentação e cai em uma pilha compacta. As peças repousam no chão antes de desaparecer. Duração: 5 segundos. Sem partículas; os efeitos serão feitos no Godot.</p>
<p><a href="nature_avatar_death.blend">Fonte Blender</a><a href="nature_avatar_death.glb">Modelo com seis animações</a><a href="../nature_avatar_summon_v1/index.html">Ver invocação</a></p>
</main></html>''', encoding='utf-8')
(OUT/'README.md').write_text('''# Avatar da Natureza — morte V1

Animação criada no Blender aberto, via MCP. Primeiro o núcleo se contrai e gira dentro do peito até desaparecer aos 0,9 s. A madeira permanece intacta até 1,05 s; só então perde sustentação e desaba. As 85 peças caem com gravidade e se acomodam em uma pilha compacta, preservando a queda da revisão anterior. A madeira permanece em tamanho integral até 4 s, depois desaparece localmente, terminando o clipe aos 5 s. Sem partículas ou VFX adicionais.

- `index.html` / `Morte.mp4`: prévia com controles, 800 × 800, 24 fps, 121 quadros incluindo a pose final (5 segundos de movimento).
- `nature_avatar_death.blend`: cena independente, Death selecionada, quadros 1–121. Espaço reproduz/pausa. Shift+Seta Esquerda volta ao início.
- `nature_avatar_death.glb`: Death, Summon, Idle, Walk, Attack e Spell; uma malha, um material, 103 ossos e 2.060 triângulos. Mesma geometria, UVs, textura e rig da invocação aprovada.
- `validation.json`: 241 poses e meios de quadro; início no repouso, raiz fixa, núcleo invisível antes da queda, madeira imóvel durante o colapso do núcleo, madeira apoiada no piso, tamanho integral até 4 s e desaparecimento posterior. Área da pilha próxima de 2,74 × 2,23 m. Os cinco clipes existentes e as texturas embutidas foram comparados com o GLB da invocação.

A queda da madeira usa Bullet durante a criação, com gravidade de −9,81 m/s², 32 subpassos e 50 iterações. O movimento gravado é reposicionado no tempo para começar após o desaparecimento do núcleo, que colapsa no peito sem cair. As facetas interligadas do modelo começam sobrepostas: camadas distintas de colisão evitam impulsos artificiais entre essas partes. Piso e limites temporários mantêm a queda compacta. Toda a animação é gravada nos ossos; helpers, colisores e física não acompanham o asset.

Death deve executar uma vez e manter a pose final até remover a unidade, sem retornar a Idle. O piso de estúdio é apenas para revisão e não acompanha o GLB. Revisão de arte ainda sem ligação ao evento de morte no jogo. A invocação aprovada e os assets em uso foram preservados.

Fontes: `tools/art_pipeline/animate_nature_avatar_death_mcp.py` chama `retime_nature_avatar_death_core_first_mcp.py`; `finish_nature_avatar_death_mcp.py`, `render_nature_avatar_death_mcp.py` (via `blender_mcp_client.py`) e `package_nature_avatar_death_review.py` validam e empacotam.
''', encoding='utf-8')
print(json.dumps(dict(output=str(OUT), validation='PASS', original_clip_error=max_original_error), indent=2))

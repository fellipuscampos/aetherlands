"""Package playable Archdemon clips and verify the serialized rig and original animations."""
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT/'art_source/archdemon_lifecycle_review'
OUT = ROOT/'assets/generated/grand_manifestations/archdemon_lifecycle_v1'
OUT.mkdir(parents=True, exist_ok=True)


def load_glb(path):
    raw = path.read_bytes()
    length = struct.unpack_from('<I', raw, 12)[0]
    return json.loads(raw[20:20+length]), raw, 28+length


def channels_by_name(document, raw, binary):
    result = {}
    for animation in document['animations']:
        clip = {}
        for c in animation['channels']:
            sampler = animation['samplers'][c['sampler']]
            values = []
            for key in ('input', 'output'):
                a = document['accessors'][sampler[key]]
                v = document['bufferViews'][a['bufferView']]
                assert a['componentType'] == 5126
                width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[a['type']]
                offset = binary+v.get('byteOffset', 0)+a.get('byteOffset', 0)
                stride = v.get('byteStride', width*4)
                values.append([struct.unpack_from('<'+'f'*width, raw, offset+i*stride)
                               for i in range(a['count'])])
            target = document['nodes'][c['target']['node']]['name']
            clip[target, c['target']['path']] = values
        result[animation['name']] = clip
    return result


doc, raw, binary = load_glb(REVIEW/'archdemon_lifecycle.glb')
report = json.loads((REVIEW/'validation.json').read_text(encoding='utf-8'))
clips = channels_by_name(doc, raw, binary)
assert set(clips) == {'Idle', 'Walk', 'Attack', 'Spell', 'Summon', 'Death'}
old_path = ROOT/'assets/generated/grand_manifestations/archdemon_blocky_v5_animated/archdemon_blocky_v5_animated.glb'
old = channels_by_name(*load_glb(old_path))
max_old_error = 0.
for name, original in old.items():
    assert original.keys() <= clips[name].keys(), name
    for key, old_values in original.items():
        for old_rows, new_rows in zip(old_values, clips[name][key]):
            assert len(old_rows) == len(new_rows), (name, key)
            max_old_error = max(max_old_error, max(abs(a-b) for old_row, new_row in zip(old_rows, new_rows)
                                                  for a, b in zip(old_row, new_row)))
assert max_old_error < 1e-5, max_old_error
for name, boundary in [('Summon', -1), ('Death', 0)]:
    assert clips[name].keys() == clips['Idle'].keys()
    error = max(abs(a-b) for key in clips['Idle']
                for a, b in zip(clips[name][key][1][boundary], clips['Idle'][key][1][0]))
    assert error < 1e-5, (name, error)
    assert max(clips[name][key][0][-1][0] for key in clips[name]) == report['clips'][name]['duration_s']
assert len(doc['meshes']) == len(doc['materials']) == len(doc['skins']) == 1
assert len(doc['skins'][0]['joints']) == report['bones']
assert sum(doc['accessors'][p['indices']]['count']//3 for p in doc['meshes'][0]['primitives']) == 1084
previous = REVIEW/'before_ground_death.glb'
if previous.exists():
    previous_summon = channels_by_name(*load_glb(previous))['Summon']
    for key, expected in previous_summon.items():
        assert clips['Summon'][key] == expected, ('Summon changed', key)
    report['approved_summon_preserved'] = True
for name in ('Idle', 'Walk', 'Attack', 'Spell', 'Summon'):
    for (bone, path), (_, rows) in clips[name].items():
        if bone.startswith('vanish_'):
            node = next(n for n in doc['nodes'] if n.get('name') == bone)
            default = (1.,1.,1.) if path == 'scale' else ((0.,0.,0.,1.) if path == 'rotation' else (0.,0.,0.))
            expected = node.get(path, default)
            assert all(max(abs(a-b) for a,b in zip(row,expected)) < 1e-5 for row in rows), (name,bone,path)
report['serialized_original_clip_error'] = max_old_error
report['original_four_clips_preserved'] = True
if '--validate-only' in sys.argv:
    print(json.dumps(report, indent=2))
    raise SystemExit(0)
ffmpeg = shutil.which('ffmpeg')
assert ffmpeg
for name in ('Summon', 'Death'):
    count = report['clips'][name]['frames']
    frames = REVIEW/'frames'/name
    assert len(list(frames.glob('*.png'))) == count
    subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
                    '-framerate', '24', '-start_number', '1', '-i', str(frames/'%04d.png'),
                    '-frames:v', str(count), '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p',
                    '-movflags', '+faststart', str(OUT/(name+'.mp4'))], check=True)
    shutil.copy2(frames/('0061.png' if name == 'Summon' else '0073.png'), OUT/(name+'.png'))
for name in ('archdemon_lifecycle.glb', 'archdemon_summon.blend', 'archdemon_death.blend'):
    shutil.copy2(REVIEW/name, OUT/name)
(OUT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
(OUT/'index.html').write_text('''<!doctype html>
<html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Arquidemônio · Invocação e morte</title><style>
body{margin:0;background:#151a22;color:#eee7d8;font:16px system-ui;display:grid;place-items:center;min-height:100vh}
main{max-width:800px;padding:24px}h1{font-size:26px}p{color:#bdc2cc;line-height:1.6}
video{width:100%;max-height:68vh;border-radius:8px;background:#232a34;display:block}
a{color:#ebc477;margin-right:18px}button{background:#252e3b;color:#eee7d8;border:1px solid #506078;border-radius:5px;padding:10px 18px;cursor:pointer;margin:8px 8px 12px 0;font:inherit}
button[aria-pressed="true"]{background:#b43c35;border-color:#d75b52}small{color:#bdc2cc}
</style><main><h1>Arquidemônio · Invocação e morte</h1>
<button data-clip="Summon" aria-pressed="false">Invocação · 4 s</button><button data-clip="Death" aria-pressed="true">Morte · 5 s</button>
<video id="v" controls playsinline preload="auto" poster="Death.png?v=compact-v3" src="Death.mp4?v=compact-v3"></video>
<button id="replay">Reproduzir do início</button>
<p id="description">As peças se soltam e caem próximas ao centro, formando uma pilha compacta no chão. Só depois desaparecem.</p>
<small>Sem partículas. Os efeitos serão feitos no Godot.</small>
<p><a id="blend" href="archdemon_death.blend">Fonte Blender</a><a href="archdemon_lifecycle.glb">Modelo com seis animações</a></p>
<script>
const video=document.getElementById('v');
const descriptions={Summon:'A armadura se materializa; coroa, ombros e mãos se reúnem ao redor do núcleo, com balanço das faixas e acomodação no repouso.',Death:'As peças se soltam e caem próximas ao centro, formando uma pilha compacta no chão. Só depois desaparecem.'};
document.querySelectorAll('[data-clip]').forEach(button=>button.addEventListener('click',()=>{
const clip=button.dataset.clip; video.src=clip+'.mp4?v=compact-v3';video.poster=clip+'.png?v=compact-v3';
document.getElementById('description').textContent=descriptions[clip];document.getElementById('blend').href='archdemon_'+clip.toLowerCase()+'.blend';
document.querySelectorAll('[data-clip]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));video.play().catch(()=>{});}));
document.getElementById('replay').addEventListener('click',()=>{video.currentTime=0;video.play().catch(()=>{});});
</script></main></html>''', encoding='utf-8')
(OUT/'README.md').write_text('''# Arquidemônio — invocação e morte V1

Criadas no Blender aberto, via MCP. Somente a armadura original animada; partículas e demais efeitos ficam para o Godot. Revisão de arte, ainda sem integração com os eventos de nascimento e morte do jogo.

- `index.html`: alternar entre invocação e morte, reproduzir, pausar e repetir.
- `Summon.mp4`: invocação de 4 s, 97 quadros incluindo o final; `Death.mp4`: morte de 5 s, 121 quadros incluindo o final. Ambos em 800 × 800, 24 fps.
- `archdemon_summon.blend` e `archdemon_death.blend`: mesma cena editável, com o respectivo clipe já selecionado e intervalo pronto. Espaço: play/pausa. Shift+Seta Esquerda: início.
- `archdemon_lifecycle.glb`: Idle, Walk, Attack, Spell, Summon e Death. Uma malha, um material, 57 ossos e 1.084 triângulos. Os 28 pivôs adicionais controlam apenas o desaparecimento das peças; preservam os movimentos dos 29 ossos originais, as malhas e os UVs.
- `validation.json`: 434 poses e meios de quadro; raiz fixa, 16 conjuntos apoiados no piso ou na pilha entre 3 e 4 s, área de repouso próxima de 2,1 × 2,2 m, tamanho normal até 4 s, faixas sem abrir nas junções e poses de ligação ao Idle conferidas. Os quatro clipes originais e a invocação aprovada foram comparados no GLB exportado.

Summon: surgimento do corpo, coroa e ombros convergindo, mãos chegando com atraso entre os lados, expansão contida e acomodação no repouso. Deve executar uma vez e seguir para Idle.

Death: 16 conjuntos de armadura e tecido se soltam em momentos diferentes e caem por simulação de corpos rígidos do Blender, com gravidade, colisão no piso e pequenos ressaltos. Impulsos voltados para dentro, maior amortecimento e limites usados apenas na simulação de autoria mantêm as peças próximas, formando uma pilha de aproximadamente 2,1 × 2,2 m, quase na área de um tile de raio 1 m. As peças permanecem apoiadas no chão ou em outras peças, em tamanho normal, até 4 s; então desaparecem no próprio lugar. O movimento foi convertido em keyframes: o GLB e o Blender salvo não dependem de física em tempo real, e os limites temporários não são exportados. Deve executar uma vez, manter o último quadro e remover a unidade; não retornar a Idle.

As versões do jogo e as animações do Serafim foram preservadas. Fontes reproduzíveis em `tools/art_pipeline/{animate,finish,render}_archdemon_lifecycle_mcp.py`, `revise_archdemon_death_ground_mcp.py` (executada automaticamente pelo script de animação) e `package_archdemon_lifecycle_review.py`.
''', encoding='utf-8')
print(json.dumps({'output': str(OUT), 'validation': 'PASS', 'original_clips_error': max_old_error}, indent=2))

"""Install the complete validated human texture pass and write its review record."""
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw
from human_texture_glb import read_glb, image_bytes, verify_unchanged
from human_texture_style import VERSION

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT/'art_source/human_texture_repair'
ASSETS = ROOT/'assets/generated/humans'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def atomic_copy(source, destination):
    temporary = destination.with_name(destination.name+'.texture_repair.tmp')
    shutil.copy2(source,temporary)
    temporary.replace(destination)


def preview_image(unit, after):
    folder = WORK/'staged'/unit/'previews' if after else ASSETS/unit/'previews'
    for name in ('three_quarter.png','threequarter.png'):
        if (folder/name).exists():
            return Image.open(folder/name).convert('RGB')
    return None


baseline = json.loads((WORK/'baseline.json').read_text(encoding='utf-8'))
pixels = json.loads((WORK/'pixel_validation.json').read_text(encoding='utf-8'))
native = json.loads((WORK/'native_validation_all.json').read_text(encoding='utf-8'))
godot = json.loads((ROOT/'docs/human_texture_repair_godot_validation.json').read_text(encoding='utf-8'))
assert godot['status'] == 'PASS' and godot['verified'] == 22
changed = [row for row in pixels['units'] if row['status'] in ('staged','applied')]
assert len(changed) == 20 and len(pixels['units']) == 22
assert {row['unit'] for row in native} == {row['unit'] for row in changed}
for row in native:
    assert row['source_geometry_uv_skinning_animations_unchanged'] and row['packed_albedo_matches_png']

# Validate every input before replacing anything, including concurrent edits.
for row in changed:
    unit = row['unit']
    stage = WORK/'staged'/unit
    for name in (unit+'_albedo.png',unit+'.glb',unit+'.blend',unit+'_report.json'):
        assert sha(ASSETS/unit/name) == baseline[unit][name], unit+': current file changed during review: '+name
    assert (stage/(unit+'.blend')).exists()
    for view in ('three_quarter','front','side','back','game_top'):
        assert (stage/'previews'/(view+'.png')).exists(), (unit,view)
    raw = (stage/(unit+'.glb')).read_bytes()
    doc,binary = read_glb(raw)
    for image in doc['images']:
        name = image['name']+'.png'
        file = stage/name if 'albedo' in name else WORK/'before'/unit/name
        assert image_bytes(doc,binary,image) == file.read_bytes(), (unit,name)
    verify_unchanged((WORK/'before'/unit/(unit+'.glb')).read_bytes(),raw)

previews = ROOT/'docs/previews/human_texture_repair'
previews.mkdir(parents=True,exist_ok=True)
comparison = Image.new('RGB',(1800,7*336),(26,30,38))
draw = ImageDraw.Draw(comparison)
for index,row in enumerate(changed):
    unit = row['unit']
    x = (index%3)*600
    y = (index//3)*336
    draw.text((x+12,y+5),unit,fill=(240,242,246))
    draw.text((x+12,y+23),'ANTES',fill=(194,200,210))
    draw.text((x+312,y+23),'DEPOIS',fill=(194,200,210))
    for after in (False,True):
        im = preview_image(unit,after)
        assert im is not None
        im.thumbnail((294,288))
        comparison.paste(im,(x+(300 if after else 0)+(300-im.width)//2,y+43))
comparison.save(previews/'before_after.jpg',quality=92)

installed = []
for row in changed:
    unit = row['unit']
    folder = ASSETS/unit
    stage = WORK/'staged'/unit
    for name in (unit+'_albedo.png',unit+'.glb',unit+'.blend'):
        atomic_copy(stage/name,folder/name)
    duplicate = folder/(unit+'_'+unit+'_albedo.png')
    if duplicate.exists():
        atomic_copy(stage/(unit+'_albedo.png'),duplicate)
    for name in ('three_quarter','front','side','back','game_top'):
        destination = 'threequarter' if unit in {'rogue_v1','saboteur_v1','assassin_v1','shadow_master_v1'} and name == 'three_quarter' else name
        atomic_copy(stage/'previews'/(name+'.png'),folder/'previews'/(destination+'.png'))
    report_path = folder/(unit+'_report.json')
    report = json.loads(report_path.read_text(encoding='utf-8'))
    report['texture']['cleanup'] = {'version':VERSION,'changed_pixels':row['changed_pixels'],
        'geometry_uv_skinning_animations_preserved':True,'embedded_albedo_matches_png':True,
        'editable_source_packed_albedo_matches_png':True,'emission_unchanged':True}
    report_path.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    row['status'] = 'applied'
    installed.append(unit)
    print('INSTALLED',unit,flush=True)

# Both the legacy units and every siege unit must remain byte-for-byte intact.
unchanged = {}
for unit in ('guard_blocky','settler_blocky','bombard_v1','catapult_v1','trebuchet_v1','siege_colossus_v1'):
    count = 0
    for name,digest in baseline[unit].items():
        if name.startswith('_'):
            continue
        assert sha(ASSETS/unit/name) == digest, (unit,name)
        count += 1
    unchanged[unit] = count
final = {'status':'PASS','version':VERSION,'reviewed':22,'repaired':20,
         'reviewed_without_changes':['guard_blocky','settler_blocky'],
         'excluded_siege':['bombard_v1','catapult_v1','trebuchet_v1','siege_colossus_v1'],
         'original_backups':'art_source/human_texture_repair/before',
         'unchanged_file_counts':unchanged,'units':pixels['units'],'editable_sources':native,
         'godot_validation':'docs/human_texture_repair_godot_validation.json'}
(ROOT/'docs/human_texture_repair_validation.json').write_text(json.dumps(final,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
(WORK/'pixel_validation.json').write_text(json.dumps(pixels,indent=2)+'\n',encoding='utf-8')
lines = ['# Revisão das texturas humanas — 06/10/2026','',
    '22 unidades revisadas; 20 corrigidas e aplicadas aos arquivos usados pelo jogo.',
    'O guarda e o colonizador do conjunto antigo foram revisados e mantidos. Catapulta, trebuchet, bombard e colosso de cerco foram excluídos.',
    '', '## Correções','',
    '- Remoção de riscos nas luvas e das colunas escuras interrompidas nas calças.',
    '- Redução do ruído de cores em couro, tecido, pele, madeira e metal, com a mesma paleta de cada unidade.',
    '- Costura acolchoada com contraste mais equilibrado; emblemas, rebites, fivelas, cintos, lâminas, olhos e boca mantêm o desenho original.',
    '- PNG principal, PNG extraído pelo Godot, albedo embutido no GLB e imagem empacotada no Blender sincronizados.',
    '- Regra compartilhada nos 16 pintores humanos; os quatro ladinos a herdam. A regra exclui a família de cerco.',
    '', '## Comparação','', '![Antes e depois das 20 unidades](previews/human_texture_repair/before_after.jpg)',
    '', '## Validação','',
    '- Metadados não relacionados a imagens e todos os buffers de geometria, UV, pesos, esqueleto e animação dos GLBs são idênticos aos originais.',
    '- Arquivos Blender reabertos e comparados por digest dos objetos, malhas, UVs, pesos, ossos, trilhas e curvas de animação.',
    '- Importação real no Godot 4.7.1: 22 modelos aprovados; pixels de albedo, filtros, ossos, durações, loops e poses finitas verificados.',
    '- Emissão e resolução das texturas mantidas. Todos os arquivos originais do cerco e das duas unidades antigas mantidos.',
    '', 'Relatórios: [arquivos e fontes](human_texture_repair_validation.json) e [Godot](human_texture_repair_godot_validation.json).',
    '', 'Os originais estão em `art_source/human_texture_repair/before/`. As vistas estáticas foram atualizadas; vídeos de prévia de animação anteriores permanecem arquivados.',
    '', '## Unidades corrigidas','', '| Unidade | Pixels corrigidos no atlas |', '|---|---:|']
lines += [f"| `{row['unit']}` | {row['changed_pixels']} |" for row in changed]
lines += ['', '## Reprodução da correção','',
    'Fluxo nativo autorizado pelo usuário: Python/Pillow para os pixels e Blender para UVs, imagens empacotadas e revisão. A imagem generativa de exploração não foi aplicada.',
    '', '1. Executar `audit_human_textures.py` no Blender para criar o inventário UV e preservar os arquivos iniciais.',
    '2. Executar `repair_human_textures.py` com Python para preparar PNGs e GLBs.',
    '3. Executar `pack_human_texture_sources.py` no Blender para empacotar as fontes e renderizar as vistas.',
    '4. Executar `run_human_texture_godot_validation.py --godot CAMINHO_DO_EXECUTAVEL`.',
    '5. Executar `install_human_texture_repair.py` para instalar o conjunto completo validado.', '']
(ROOT/'docs/HUMAN_TEXTURE_REPAIR.md').write_text('\n'.join(lines),encoding='utf-8')
print('COMPLETE',len(installed),'repaired; 22 reviewed; siege unchanged',flush=True)

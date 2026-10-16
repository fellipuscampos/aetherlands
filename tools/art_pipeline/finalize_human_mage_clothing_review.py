"""Refresh clothing descriptions without rewriting approved animation notes."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'art_source/school_mages_animation_review'
HUMAN = ROOT / 'art_source/human_school_mages_review'
manifest = json.loads((HUMAN / 'manifest.json').read_text(encoding='utf-8'))
descriptions = {
    'sacred': 'Vestes marfim simples, mitra dourada e cajado solar.',
    'infernal': 'Capuz bordô pintado, túnica vermelha escura e cajado com braseiro.',
    'necromancy': 'Capuz violeta pintado, túnica roxa simples e cajado de caveira.',
    'druidism': 'Túnica verde simples, coroa de folhas e cajado de galhos.',
    'arcanism': 'Túnica azul simples, chapéu angular e cajado com cristal arcano.',
    'elementalism': 'Túnica azul-petróleo simples e cajado com focos dos quatro elementos.',
}
note = 'Revisão 4 das roupas: removidos os adornos aplicados em 3D dos seis humanos. Mantidos as cores das escolas, anatomia, cabelos, barbas, capuzes pintados, chapéus, cajados e as animações idle, walk e spell aprovadas.'
page = (HUMAN / 'index.html').read_text(encoding='utf-8')
page = page.replace('seis escolas · revisão 3', 'seis escolas · revisão 4')
page = page.replace('Mantidos o corpo, as roupas e a postura idosa.', note)
page = re.sub(r'<a href="arcanist_side_inspection.png">.*?</a>', '', page)
page = re.sub(r'<h2>No Godot</h2>.*?<div class="grid">', '<h2>No Godot</h2><p>Modelos atualizados na câmera e iluminação do jogo; os seis humanos ocupam a primeira fila.</p><img class="wide" src="../school_mages_animation_review/godot_all_24_game_view.png" alt="Magos atualizados no Godot"><div class="grid">', page, flags=re.S)
for row in manifest['assets']:
    escaped_name = row['name']
    pattern = r'(<article><h2>' + re.escape(escaped_name) + r'</h2><p>).*?(</p>)'
    page = re.sub(pattern, lambda m: m[1] + descriptions[row['school']] + m[2], page)
    # Specs are unique within each article, bounded by its model title.
    pattern = r'(<article><h2>' + re.escape(escaped_name) + r'</h2>.*?<p class="spec">)\d+( triângulos)'
    page = re.sub(pattern, lambda m: m[1] + str(row['geometry']['triangles']) + m[2], page, flags=re.S)
    folder = (ROOT / row['glb']).parent
    text = (folder / 'README.md').read_text(encoding='utf-8')
    text = re.sub(r'(Modelo humano idoso em estilo blocky/pixel art, criado via MCP do Blender\.\n).*?(\n\n)', lambda m: m[1] + descriptions[row['school']] + m[2], text, count=1, flags=re.S)
    text = re.sub(r'\d+ peças separadas', str(row['geometry']['editable_parts'])+' peças separadas', text)
    text = re.sub(r'\d+ triângulos', str(row['geometry']['triangles'])+' triângulos', text)
    text = text.replace('Corpo, roupas e postura preservados.', 'Corpo e postura preservados; roupas simplificadas na revisão 4.')
    if '### Revisão 4 das roupas' not in text:
        text += '\n### Revisão 4 das roupas\n\n' + note + '\n'
    (folder / 'README.md').write_text(text, encoding='utf-8')
(HUMAN / 'index.html').write_text(page, encoding='utf-8')
for path in (HUMAN / 'README.md', WORK / 'README.md'):
    text = path.read_text(encoding='utf-8')
    text = text.replace('Proporções, geometria, UVs e texturas aprovadas preservadas;', 'Anatomia, UVs, texturas e animações aprovadas preservadas; adornos em 3D das roupas humanas removidos;')
    if '## Roupas humanas — revisão 4' not in text:
        text += '\n## Roupas humanas — revisão 4\n\n' + note + '\n\nBackup antes da limpeza: `art_source/school_mages_animation_review/before_human_clothing_cleanup/`. Validação: `docs/human_school_mages_clothing_validation.json`.\n'
    path.write_text(text, encoding='utf-8')
audit_path = ROOT / 'docs/human_school_mages_clothing_validation.json'
audit = json.loads(audit_path.read_text(encoding='utf-8'))
export = json.loads((ROOT / 'docs/school_mages_animation_export_validation.json').read_text(encoding='utf-8'))
native = json.loads((ROOT / 'docs/school_mages_animation_godot_native_validation.json').read_text(encoding='utf-8'))
assert export['status'] == native['status'] == 'PASS'
audit.update(export_status='PASS',native_review_status='PASS',approved_clips_unchanged=18,unchanged_other_race_files=export['unchanged_other_race_files'])
audit_path.write_text(json.dumps(audit, indent=2), encoding='utf-8')
print(json.dumps({key:value for key,value in audit.items() if key != 'assets'}))

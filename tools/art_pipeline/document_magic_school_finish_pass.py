"""Document the completed finish pass, retaining the original backup unchanged."""
import hashlib
import json
from pathlib import Path
from verify_magic_school_batch import CIVS, RECIPES

ROOT = Path(__file__).resolve().parents[2]
BACKUP = ROOT / 'art_source/magic_schools_before_finish_pass'
DETAILS = {
    'human': ('Azul', 'Alvenaria, pilastras, vitrais e travamentos de madeira.'),
    'orc': ('Terracota', 'Madeira reforçada com ferro, rebites, travamentos de clã e bandeiras recortadas.'),
    'dwarf': ('Ardósia cinza', 'Pilares de granito, faixas de cobre gravadas, mobiliário de pedra e engrenagens.'),
    'elf': ('Verde', 'Madeira entalhada, galhos, folhas fixadas, trepadeiras e detalhes pontiagudos.'),
}

if __name__ == '__main__':
    manifest = json.loads((BACKUP / 'manifest.json').read_text(encoding='utf-8'))
    for row in manifest:
        assert hashlib.sha256((BACKUP / row['path']).read_bytes()).hexdigest() == row['sha256']
    audit = json.loads((ROOT / 'docs/magic_school_attachment_audit_after.json').read_text(encoding='utf-8'))
    assert len(audit) == 24 and all(row['polished'] and not row['detached'] for row in audit)
    lines = [
        '# Revisão do acabamento das escolas de magia', '',
        'Os 24 prédios existentes foram ajustados pelo Blender MCP, um por vez, na ordem humanos, orcs, anões e elfos. Cada prédio foi salvo antes de iniciar o seguinte. Bases, corpos principais, disposição e geometria dos telhados foram preservados.', '',
        'Bandeiras receberam mastros fundados, travessas e amarrações. Sinos, aros, símbolos, pedestais, nichos e adereços receberam apoios ou encaixes. A cor dos telhados foi uniformizada dentro de cada civilização.', '',
        'Os ossuários reutilizam a caveira, mandíbula e costelas do esqueleto aprovado `skeleton_warrior_v1`, incluindo sua pintura original. Há prateleiras de ossos, fêmures, ossos cruzados e uma relíquia sobre o sarcófago.', '',
        '| Civilização | Telhados | Particularidades | Prévia das seis escolas |',
        '|---|---|---|---|',
    ]
    for civ, (plural, label) in CIVS.items():
        color, detail = DETAILS[civ]
        lines.append(f'| {label} | {color} | {detail} | [Abrir](../assets/generated/{plural}/buildings/magic_schools_three_quarter.jpg) |')
    lines += ['', 'Os cristais de treino e núcleos mágicos que levitam por intenção de design continuam assim. A auditoria dos adereços físicos combina uma busca de conexões pelas caixas das peças com revisão visual das prévias; o relatório registra esse método.', '',
              'Verificados os arquivos exportados, UVs, texturas embutidas, bordas do hexágono e importação dos 24 GLBs no Godot. Os arquivos de gameplay acompanhados pelo pipeline permanecem preservados.', '',
              f'Cópias anteriores: `art_source/magic_schools_before_finish_pass/` ({len(manifest)} arquivos, hashes conferidos).', '',
              '[Catálogo e modelos](MAGIC_SCHOOLS_CATALOG.md) · [Auditoria de apoios](magic_school_attachment_audit_after.json) · [Validação dos GLBs](magic_schools_validation.json) · [Importação no Godot](magic_schools_godot_validation.json)', '']
    (ROOT / 'docs/MAGIC_SCHOOLS_FINISH_REVIEW.md').write_text('\n'.join(lines), encoding='utf-8')
    # Early human files were saved before the finish-pass README paragraph was added.
    for civ, (plural, _) in CIVS.items():
        for stem, _, _ in RECIPES.values():
            folder = ('' if civ == 'human' else civ + '_') + stem + '_hex_v1'
            out = ROOT / 'assets/generated' / plural / 'buildings' / folder
            report = json.loads((out / (folder + '_report.json')).read_text(encoding='utf-8'))
            readme = out / 'README.md'
            text = readme.read_text(encoding='utf-8')
            if 'Acabamento ajustado sobre o modelo existente' not in text:
                text += '\nAcabamento ajustado sobre o modelo existente, com volumes principais preservados. '
                text += report['finish_pass']['race_details'] + ' Telhados uniformes por civilização e adereços físicos com apoios revisados.\n'
                if report['magic_school'] == 'necromancy':
                    text += '\nRelíquias usam caveira, mandíbula e costelas do `skeleton_warrior_v1`, com sua pintura original preservada.\n'
                readme.write_text(text, encoding='utf-8')
    print(json.dumps({'documented_assets': 24, 'backup_files_verified': len(manifest)}))

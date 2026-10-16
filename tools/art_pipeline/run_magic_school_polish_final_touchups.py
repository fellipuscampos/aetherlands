"""Apply only localized details identified in the preview and attachment review."""
import json
from run_magic_school_batch import PIPELINE, call

if __name__ == '__main__':
    for filename in ('magic_school_polish_attachment_touchup.py', 'magic_school_orc_rack_touchup.py',
                     'magic_school_dwarf_plate_touchup.py'):
        print('FINAL_TOUCHUP ' + filename, flush=True)
        print(json.dumps(call((PIPELINE / filename).read_text(encoding='utf-8'))), flush=True)
    code = (PIPELINE / 'magic_school_elf_attachment_touchup.py').read_text(encoding='utf-8')
    for stem in ('sacred_temple', 'infernal_sanctum', 'necromancy_ossuary', 'arcane_conclave', 'elemental_observatory'):
        folder = 'elf_' + stem + '_hex_v1'
        print('FINAL_TOUCHUP ' + folder, flush=True)
        print(json.dumps(call(f'TOUCHUP_FOLDER={folder!r}\n' + code)), flush=True)
    print('FINAL_TOUCHUP elf_druidic_circle_hex_v1', flush=True)
    print(json.dumps(call((PIPELINE / 'magic_school_elf_grove_touchup.py').read_text(encoding='utf-8'))), flush=True)

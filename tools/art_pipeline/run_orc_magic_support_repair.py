"""Sequential correction of the five affected first-pass orc assets."""
import json
from run_magic_school_batch import PIPELINE, call

if __name__=='__main__':
    repair = (PIPELINE/'repair_orc_magic_roof_supports.py').read_text(encoding='utf-8')
    for stem in ('sacred_temple','infernal_sanctum','necromancy_ossuary','druidic_circle','arcane_conclave'):
        folder = 'orc_'+stem+'_hex_v1'
        print('REVIEW_AND_SAVE '+folder,flush=True)
        result = call(f'REPAIR_FOLDER={folder!r}\n'+repair)
        print(json.dumps({'DONE':result}),flush=True)
    print('ALL_ORC_SUPPORTS_REPAIRED',flush=True)

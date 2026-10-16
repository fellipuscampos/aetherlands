"""Save the two small corrections found while reviewing the first human previews."""
import json
from run_magic_school_batch import PIPELINE, call

if __name__ == '__main__':
    code = (PIPELINE / 'magic_school_polish_detail_touchup.py').read_text(encoding='utf-8')
    for folder in ('sacred_temple_hex_v1', 'necromancy_ossuary_hex_v1'):
        print('TOUCHUP ' + folder, flush=True)
        print(json.dumps(call(f'TOUCHUP_FOLDER={folder!r}\n' + code)), flush=True)

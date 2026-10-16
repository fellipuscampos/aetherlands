"""Align revised asset metadata with the game's current art catalog."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
completed=json.loads((ROOT/'art_source/building_architecture_review/completed.json').read_text(encoding='utf-8'))
plurals={'human':'humans','elf':'elves','dwarf':'dwarves','orc':'orcs'}
catalog=(ROOT/'scripts/data/BuildingArtCatalog.gd').read_text(encoding='utf-8')
for entry in completed:
    folder=entry['asset']; out=ROOT/'assets/generated'/plurals[entry['civilization']]/'buildings'/folder
    file=out/(folder+'_report.json')
    report=json.loads(file.read_text(encoding='utf-8'))
    report['civilization']=entry['civilization']
    report['integration_source']='scripts/data/BuildingArtCatalog.gd'
    report['integrated_in_game']='"'+folder+'"' in catalog
    file.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    if folder=='war_stable_hex_v1':
        body='# '+report['display_name']+'\n\n'+report['architecture_revision']['design']+'\n\n'
        body+='Revisão de arquitetura de 2026-10-09 pelo **Blender MCP**. Baias, cavalos, pátio e equipamentos preservados; paredes e pilares principais agora usam pedra.\n\n'
        body+=f'- {report["editable_parts"]} peças editáveis, {report["triangles"]} triângulos, atlas {report["texture"]["size"][0]}² com filtro nearest.\n'
        body+='- Fonte .blend com texturas empacotadas e exportação .glb com atlas embutidos.\n- Origem central no solo; frente −Y no Blender / +Z no Godot.\n- Mantém o caminho e o ID usados pelo catálogo do jogo.\n\n'
        body+='Prévias: [três quartos](previews/three_quarter.png), [mapa](previews/game_top.png), [topo](previews/top.png), [traseira](previews/back.png).\n\n'
        body+='Os arquivos anteriores estão em art_source/buildings_before_architecture_revision. O relatório JSON lista as peças alteradas e verificações.\n'
        (out/'README.md').write_text(body,encoding='utf-8')
print(json.dumps({'metadata_normalized':len(completed),'catalog':'scripts/data/BuildingArtCatalog.gd'}))

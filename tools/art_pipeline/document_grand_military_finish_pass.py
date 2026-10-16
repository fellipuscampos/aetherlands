"""Describe the completed repairs using their recorded final validation."""
import hashlib
import json
from pathlib import Path
from grand_military_assets import CIVS, QUEUE, folder_name

ROOT=Path(__file__).resolve().parents[2]
rows=json.loads((ROOT/'docs/grand_military_geometry_after.json').read_text(encoding='utf-8'))
assert len(rows)==24
assert not any(r['coplanar_faces'] or r['mast_roof_intersections'] or
               any(d['blockers'] for d in r['entrances']+r['open_passages']) for r in rows)
backup=ROOT/'art_source/grand_military_before_finish_pass'
manifest=json.loads((backup/'manifest.json').read_text(encoding='utf-8'))
assert len(manifest)==240
assert all(hashlib.sha256((backup/r['backup']).read_bytes()).hexdigest()==r['sha256'] for r in manifest)
godot=json.loads((ROOT/'docs/grand_military_godot_validation.json').read_text(encoding='utf-8'))
assert godot['status']=='PASS' and godot['verified']==24
doc='# Revisão de acabamento das grandes construções militares\n\n'
doc+='Os 24 modelos existentes foram ajustados pelo Blender MCP, uma construção de cada vez, e salvos com novos `.blend`, `.glb`, atlas e quatro prévias. As plantas próprias, os materiais e as cores das quatro civilizações foram preservados.\n\n'
doc+='A revisão corrigiu pilares de esquina à frente de portas hexagonais, um abrigo vizinho invadindo a entrada, brasões baixos sobre aberturas, cercas e mobiliário atravessando aproximações. As entradas receberam fachadas planas e os elementos decorativos mantêm apoios físicos. A escadaria elevada do refúgio élfico termina no patamar da porta.\n\n'
doc+='Mastros e bandeiras foram afastados das coberturas. Poleiros humanos, orcs e anões agora começam em bases sobre o telhado; o ninho élfico aproveita o tronco vivo e não mantém um segundo poste coincidente.\n\n'
doc+='Faces coincidentes de degraus, arquibancadas, cintas, cumeeiras e pequenos detalhes foram recuadas dentro das peças vizinhas, conservando volumes fechados. Peças duplicadas ou substituídas foram arquivadas no grupo de estúdio e excluídas das prévias e da exportação.\n\n'
doc+='## Conferência\n\n'
doc+='| Verificação | Resultado |\n|---|---:|\n'
doc+=f'| Modelos revisados | {len(rows)} |\n'
doc+=f"| Portas verificadas | {sum(len(r['entrances']) for r in rows)} |\n"
doc+=f"| Passagens e aproximações verificadas | {sum(len(r['open_passages']) for r in rows)} |\n"
doc+='| Obstruções nos acessos verificados | 0 |\n| Mastros atravessando telhados | 0 |\n| Pares de faces coplanares expostas detectados | 0 |\n| Importações no Godot | 24 aprovadas |\n| Arquivos originais preservados em backup | 240 |\n\n'
doc+='A sobreposição foi conferida por interseção de triângulos coplanares, com raios para excluir contatos internos. Os mastros foram comparados com a geometria das coberturas. Portas e passagens usam envelopes de aproximação e raios contra as peças reais. Esses testes complementam a revisão visual; não representam navegação de unidades, pois estes assets ainda não estão integrados ao cadastro do jogo.\n\n'
doc+='Também foram conferidos UVs, malhas fechadas, texturas embutidas, nearest, origem no solo, seis limites do tile e 24 geometrias distintas. Os arquivos anteriores de construções e gameplay continuam preservados pela comparação de hashes.\n\n'
doc+='## Modelos e prévias\n\n'
for civ,(directory,label) in CIVS.items():
    doc+='### '+label+'\n\n'
    for c,role in QUEUE:
        if c!=civ:
            continue
        folder=folder_name(c,role)
        asset=Path('assets/generated')/directory/'buildings'/folder
        r=json.loads((ROOT/asset/(folder+'_report.json')).read_text(encoding='utf-8'))
        assert r.get('finish_review')
        doc+='- ['+r['display_name']+'](../'+asset.as_posix()+'/README.md) · [Prévia](../'+asset.as_posix()+'/previews/three_quarter.png).\n'
    doc+='\n'
doc+='[Catálogo](GRAND_MILITARY_CATALOG.md) · [Geometria final](grand_military_geometry_after.json) · [Godot](grand_military_godot_validation.json).\n'
(ROOT/'docs/GRAND_MILITARY_FINISH_REVIEW.md').write_text(doc,encoding='utf-8')
print(json.dumps({'reviewed':24,'original_files_preserved':240,'final_geometry_issues':0}))

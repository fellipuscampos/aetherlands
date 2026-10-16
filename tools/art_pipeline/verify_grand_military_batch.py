"""Validate 24 landmarks, source preservation and distinct structural signatures."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from grand_military_assets import CIVS, RECIPES, ROOFS, reference_folder
from verify_magic_school_batch import validate, sheet

ROOT=Path(__file__).resolve().parents[2]
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--civ',choices=tuple(CIVS))
    args=parser.parse_args()
    baseline=json.loads((ROOT/'docs/grand_military_source_baseline.json').read_text(encoding='utf-8'))
    for row in baseline:
        assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['sha256'],row['path']
    assets,sheets=[],{}
    recipes={role:r[:3] for role,r in RECIPES.items()}
    for civ in ([args.civ] if args.civ else CIVS):
        entries=[]
        for role,(_,_,_,previous) in RECIPES.items():
            entry=validate(civ,role,recipes,'v2_legendary_','military_role')
            out=ROOT/entry['folder']
            r=json.loads((out/(out.name+'_report.json')).read_text(encoding='utf-8'))
            assert r['grand_military'] and r['requires_building']=='v2_building_'+previous
            assert r['roof_rgb']==ROOFS[civ] and not r['physical_attachment_remaining']
            assert r['architecture_key']==civ+'_'+role
            if r.get('finish_review'):
                checks=r['finish_review']['geometry_checks']
                assert not checks['coplanar_faces'] and not checks['mast_roof_intersections']
                assert not any(d['blockers'] for d in checks['entrances'])
                assert not any(d['blockers'] for d in checks.get('open_passages',[]))
            assert r['material_reference']=='assets/generated/'+CIVS[civ][0]+'/buildings/'+reference_folder(civ,role)
            entry.update({'role':role,'design':r['design'],'material_reference':r['material_reference'],
                          'architecture_key':r['architecture_key'],'roof_rgb':r['roof_rgb']})
            entries.append(entry)
        assets+=entries
        sheets[civ]={v:sheet(civ,entries,v,'grand_military','Grandes construções militares') for v in ('three_quarter','game_top')}
    if not args.civ:
        godot=json.loads((ROOT/'docs/grand_military_godot_validation.json').read_text(encoding='utf-8'))
        live=json.loads((ROOT/'docs/grand_military_attachment_audit.json').read_text(encoding='utf-8'))
        assert godot['status']=='PASS' and godot['verified']==24
        assert live['verified']==24 and live['remaining_physical_adornments']==0
        assert len({r['geometry_sha256'] for r in live['scenes']})==24
        doc='# Grandes construções militares — modelos 3D\n\n'
        doc+='24 grandes construções, seis por civilização, criadas pelo Blender MCP. Cada modelo foi concluído e salvo antes de iniciar o seguinte, na ordem humanos, orcs, anões e elfos.\n\n'
        doc+='Plantas e volumes próprios para cada raça, derivados do seu prédio militar básico equivalente. Materiais, cores e telhados preservam a família da civilização. **Assets preparados; integração ao cadastro do jogo pendente.**\n\n'
        if all(json.loads((ROOT/e['folder']/(Path(e['folder']).name+'_report.json')).read_text(encoding='utf-8')).get('finish_review') for e in assets):
            doc+='[Revisão de acabamento](GRAND_MILITARY_FINISH_REVIEW.md): entradas e passagens livres, mastros apoiados fora das coberturas e sobreposição de faces corrigida nos 24 modelos.\n\n'
        doc+='| Doutrina | Humanos | Orcs | Anões | Elfos |\n|---|---|---|---|---|\n'
        descriptions={
            'guardian':['Cidadela hexagonal e três torres','Salão de clã e mirantes desiguais','Fortaleza baixa e bastiões de ombro','Três pavilhões e árvores sentinelas'],
            'warrior':['Anfiteatro em ferradura','Fosso e tribunas de madeira','Arena retangular e arquibancadas de granito','Terraços em pétalas e árvores de sombra'],
            'ranger':['Torre de pedra com mirante de madeira','Andaime aberto de duas plataformas','Torre de granito e galeria com corbelas','Árvore viva de três plataformas'],
            'cavalry':['Comando em U e duas cavalariças','Salão de montarias em L','Cavalariça de abóbada e doca aérea','Pavilhões em meia-lua e ninho na árvore'],
            'rogue':['Casa urbana, torre e varanda','Cabana larga, mirante recuado e alçapão','Refúgio em terraços de rocha','Duas casas suspensas unidas por ponte'],
            'siege':['Oficina dupla e trebuchet','Hangar de aríete e forja','Fundição e máquina com caldeira','Pavilhões botânicos e balista'],
        }
        for role,recipe in RECIPES.items():
            doc+='| '+recipe[1]+' | '+' | '.join(descriptions[role])+' |\n'
        doc+='\n'
        comparison_dir=ROOT/'docs/previews'
        comparison_dir.mkdir(exist_ok=True)
        font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',22)
        for role,recipe in RECIPES.items():
            canvas=Image.new('RGB',(1440,442),(26,33,43))
            draw=ImageDraw.Draw(canvas)
            draw.text((18,8),recipe[1]+' — comparar as quatro civilizações',font=font,fill=(233,224,193))
            for i,(civ,(_,label)) in enumerate(CIVS.items()):
                entry=next(e for e in assets if e['civilization']==civ and e['role']==role)
                with Image.open(ROOT/entry['folder']/'previews/three_quarter.png') as im:
                    canvas.paste(im.convert('RGB').resize((350,350),Image.Resampling.LANCZOS),(i*360+5,42))
                draw.text((i*360+15,402),label,font=font,fill=(231,233,237))
            path=comparison_dir/('grand_military_'+role+'.jpg')
            canvas.save(path,quality=94)
            doc+='['+recipe[1]+' — comparar raças](previews/'+path.name+') · '
        doc=doc.rstrip(' · ')+'\n\n'
        for civ,(_,label) in CIVS.items():
            doc+='## '+label+'\n\n[Visão geral](../'+sheets[civ]['three_quarter']+') · [Visão de mapa](../'+sheets[civ]['game_top']+')\n\n'
            doc+='| Construção | Modelo e quatro prévias | Referência básica | Triângulos |\n|---|---|---|---:|\n'
            for entry in assets:
                if entry['civilization']==civ:
                    doc+='| '+entry['label']+' | [Abrir](../'+entry['folder']+'/README.md) | [Ver referência](../'+entry['material_reference']+'/previews/three_quarter.png) | '+str(entry['triangles'])+' |\n'
            doc+='\n'
        doc+='Cada pasta contém `.blend` isolado/editável, `.glb`, dois atlas PNG, README, relatório e quatro prévias. Montarias usam somente as miniaturas já aprovadas dos estábulos, sem cavaleiros, rig ou animação. As máquinas de cerco são peças de demonstração do prédio.\n\n'
        doc+='Validação: seis bordas do hexágono, origem no solo, malhas fechadas, UVs, texturas embutidas iguais aos PNGs, nearest e importação direta dos 24 GLBs no Godot. Os apoios foram conferidos por conectividade de caixas das peças e revisão visual das prévias. Não há levitação militar intencional.\n\n'
        doc+=f'{len(baseline)} arquivos preexistentes de construções e gameplay preservados por comparação de hashes. As 24 cenas têm geometria distinta, conferida por assinatura de coordenadas e faces, independente das texturas.\n\n'
        doc+='[Validação](grand_military_validation.json) · [Godot](grand_military_godot_validation.json) · [Apoios e geometrias](grand_military_attachment_audit.json).\n'
        (ROOT/'docs/GRAND_MILITARY_CATALOG.md').write_text(doc,encoding='utf-8')
        (ROOT/'docs/grand_military_validation.json').write_text(json.dumps({'verified':24,'preserved_source_files':len(baseline),'assets':assets,'sheets':sheets},ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'verified':len(assets),'preserved_source_files':len(baseline),'sheets':sheets},ensure_ascii=True,indent=2))

"""Connect finished GLBs through the existing human troop helper, without balance changes."""
import json, re, shutil
from human_rogue_siege_assets import ROOT, ASSETS

path=ROOT/'scripts/data/UnitDatabase.gd'
text=path.read_text(encoding='utf-8')
constants='''
## Arte humana Ladino/Cerco: clipes anteriores presentes em todas as evoluções.
## Desmantelar e Munição Demolidora continuam passivas, com clipes disponíveis.
const ROGUE_FIRST_CLIPS := {V2DoctrineTechniqueDatabase.SNEAK_ATTACK: "_SneakAttack"}
const ROGUE_LINE_CLIPS := {V2DoctrineTechniqueDatabase.SNEAK_ATTACK: "_SneakAttack", V2DoctrineTechniqueDatabase.DISMANTLE: "_Dismantle"}
const SIEGE_FIRST_CLIPS := {V2DoctrineTechniqueDatabase.DEMOLITION_AMMO: "_DemolitionAmmo"}
const SIEGE_LINE_CLIPS := {V2DoctrineTechniqueDatabase.DEMOLITION_AMMO: "_DemolitionAmmo", V2DoctrineTechniqueDatabase.PREPARED_BOMBARDMENT: "_PreparedBombardment"}
'''
assert 'const ROGUE_FIRST_CLIPS' not in text, 'Already integrated; preserve later edits.'
backup=ROOT/'art_source/human_rogue_siege_runtime_before'; backup.mkdir(parents=True,exist_ok=True)
(backup/'.gdignore').write_text('',encoding='utf-8'); shutil.copyfile(path,backup/'UnitDatabase.gd')
text=text.replace('\nstatic func create_unit(kind: String) -> UnitData:',constants+'\nstatic func create_unit(kind: String) -> UnitData:')
for a in ASSETS:
    folder=ROOT/'assets/generated/humans'/a['stem']; report=json.loads((folder/(a['stem']+'_report.json')).read_text(encoding='utf-8'))
    assert report['status'].startswith('Finished human') and (folder/(a['stem']+'.glb')).is_file()
    marker='\t\t"'+a['kind']+'":\n'; start=text.index(marker); end=text.find('\n\t\t"',start+len(marker))
    if end<0: end=len(text)
    block=text[start:end]
    block=re.sub(r'\t\t\tdata\.(model_scene_path|animation_scene_path|model_scale_multiplier) = .*\n','',block)
    clipmap=('ROGUE_' if a['family']=='rogue' else 'SIEGE_')+('FIRST_CLIPS' if a['level']==0 else 'LINE_CLIPS')
    line='\t\t\t_apply_human_troop_model(data, "'+a['stem']+'", "'+a['prefix']+'", '+clipmap+')\n'
    insertion=block.index('\t\t\tdata.production_cost ='); insertion=block.index('\n',insertion)+1
    block=block[:insertion]+line+block[insertion:]
    text=text[:start]+block+text[end:]
    # Replace just the obsolete visual-placeholder tail in the preceding comment.
    previous=text.rfind('\n\t\t"',0,start)
    comments=text[previous:start]
    at=comments.rfind('Modelo PROVISÓRIO:')
    if at<0: at=comments.rfind('Modelo\n\t\t# PROVISÓRIO:')
    if at>=0:
        visual=comments[at:]
        desc='Arte humana própria: '+a['label']+', '+str(a['height']).replace('.',',')+' m; rig e clipes nativos.'
        text=text[:previous]+comments[:at]+desc+'\n'+text[start:]
path.write_text(text,encoding='utf-8')
print(json.dumps({'integrated':len(ASSETS),'file':str(path),'backup':str(backup/'UnitDatabase.gd')}))

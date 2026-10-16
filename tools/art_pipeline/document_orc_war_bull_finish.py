"""Update current mount description and assemble native animation previews."""
import re,json,hashlib
from PIL import Image,ImageDraw,ImageFont
from orc_troop_assets import ROOT,WORK,ASSETS

changed={r['stem'] for r in ASSETS if r['family']=='cavalry'}
for file,sha in json.loads((WORK/'war_bull_finish/before_hashes.json').read_text()).items():
    if any('/'+stem+'/' in file.replace('\\','/') for stem in changed):continue
    assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest()==sha,file
for file,sha in json.loads((WORK/'protected_sources.json').read_text()).items():
    assert hashlib.sha256((ROOT/file).read_bytes()).hexdigest()==sha,file

path=ROOT/'docs/ORC_TROOPS_CATALOG.md';text=path.read_text(encoding='utf-8')
text=text.replace('e todas as curvas das **93 animações** continuam iguais à versão aprovada.', 'continuam iguais à versão aprovada. Os **93 clips** foram mantidos; somente as translações das patas das montarias foram ajustadas nesta rodada, conforme descrito abaixo.')
text=text.replace('as presas, as alturas, os esqueletos continuam', 'as presas, as alturas e os esqueletos continuam')
paragraph='''A revisão `war_bull_v3` mantém os touros inspirados na referência, com tronco e peito feitos de blocos retangulares. As placas de osso da montaria, os painéis extras junto à sela e a camada separada da testa foram removidos. Cabeça inclinada, olhos laterais, chifres, pelagem, cauda e cascos continuam como na versão anterior. Cavaleiros, alturas, roupas, armas, sela, estribos e rédeas foram preservados.

As 16 animações montadas foram reaproveitadas. As translações dos oito ossos das patas receberam pequenas correções verticais nas passadas e investidas para impedir que os cascos atravessem o chão, inclusive durante a interpolação entre quadros. Joelhos permanecem conectados; movimentos do cavaleiro, rotações, corpo da montaria, cabeça, rédeas e duração dos clips continuam intactos. Nenhuma animação nova foi criada. Os outros 16 orcs e as fontes das demais raças permanecem iguais.

'''
if 'A revisão `war_bull_v3`' not in text:
    text=re.sub(r'A revisão `war_bull_v2`.*?\n\n',lambda _:paragraph,text,count=1,flags=re.S)
    text=text.replace('- `orc_war_bulls_validation.json`:', '- `orc_war_bull_finish_validation.json`: blocos retangulares, retirada das placas e dos painéis, apoio dos cascos conferido a 48 fps, continuidade dos joelhos e alterações limitadas às translações das patas.\n- `orc_war_bulls_validation.json`: revisão anterior;')
    text=text.replace('tools/art_pipeline/build_orc_war_bulls_mcp.py','tools/art_pipeline/finish_orc_war_bulls_mcp.py').replace('art_source/orc_troops/war_bulls/before_assets/','art_source/orc_troops/war_bull_finish/before_assets/')
    text=text.replace('Para reaplicar a última revisão pelo MCP', 'Para reaplicar a revisão de capacetes pelo MCP')
    text=text.replace('A fonte congelada antes dos touros está em', 'A fonte congelada antes deste ajuste está em')
    text=text.replace('- [Touros de guerra e cavaleiros]', '- [Revisão das animações](previews/orc_troops/bull_motion_contact_sheet.jpg).\n- [Touros de guerra e cavaleiros]')
path.write_text(text,encoding='utf-8')

folder=ROOT/'docs/previews/orc_troops/bull_motion_frames'
if folder.exists():
    groups=[]
    for actor in sorted(folder.iterdir()):
        if not actor.is_dir():continue
        for prefix in sorted({p.stem.rsplit('_',1)[0] for p in actor.glob('*.png')}):
            frames=[Image.open(actor/(prefix+'_'+str(i)+'.png')).convert('RGB') for i in range(8)]
            groups.append((actor.name,prefix,frames))
            frames[0].save(actor/(prefix+'.gif'),save_all=True,append_images=frames[1:],duration=150,loop=0)
    if groups:
        sheet=Image.new('RGB',(1536,len(groups)*216),(31,37,32));draw=ImageDraw.Draw(sheet);font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',17)
        for row,(actor,clip,frames) in enumerate(groups):
            for col,frame in enumerate(frames):sheet.paste(frame.resize((192,192),Image.Resampling.LANCZOS),(col*192,row*216))
            draw.text((8,row*216+194),actor+' · '+clip,font=font,fill=(231,224,202))
        sheet.save(ROOT/'docs/previews/orc_troops/bull_motion_contact_sheet.jpg',quality=93)

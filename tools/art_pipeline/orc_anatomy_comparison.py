"""Show the original and corrected poses without modifying any game asset."""
from PIL import Image,ImageDraw,ImageFont
from orc_troop_assets import ROOT,OUT,WORK,ASSETS

rows=[next(r for r in ASSETS if r['key']==k) for k in ('sentinel','archer','rogue')]
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',22)
heading=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',26)
canvas=Image.new('RGB',(1024,3*560+48),(31,37,33));draw=ImageDraw.Draw(canvas)
draw.text((18,8),'Orcs — correção de posições e articulações',font=heading,fill=(238,230,207))
for index,row in enumerate(rows):
    for side,(folder,label) in enumerate(((WORK/'pose_correction/before_assets'/row['stem'],'Antes'),(OUT/row['stem'],'Corrigido — repouso'))):
        y=48+index*560
        frame=Image.open(folder/'previews/three_quarter.png').convert('RGB').resize((512,512),Image.Resampling.LANCZOS)
        canvas.paste(frame,(side*512,y))
        draw.text((side*512+16,y+516),row['name']+' • '+label,font=font,fill=(232,227,209))
target=ROOT/'docs/previews/orc_troops/anatomy_before_after.jpg'
canvas.save(target,quality=95)
print(target)

"""Package actual Blender action renders as GIF/MP4/contact sheets."""
import shutil
import subprocess
from PIL import Image,ImageDraw,ImageFont
from dwarf_troop_assets import ASSETS
from dwarf_skill_contract import ROOT,OUT,WORK,roles_for

dest=ROOT/'docs/previews/dwarf_skills';dest.mkdir(parents=True,exist_ok=True)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',19)
ffmpeg=shutil.which('ffmpeg');assert ffmpeg
for row in ASSETS:
    for role in roles_for(row):
        folder=WORK/'frames'/row['stem']/role;paths=sorted(folder.glob('*.png'))
        assert paths,(row['stem'],role)
        if row['tier']==2:
            frames=[]
            for path in paths:
                render=Image.open(path).convert('RGB')
                frame=Image.new('RGB',(560,596),(34,38,40));frame.paste(render,(0,36))
                ImageDraw.Draw(frame).text((12,7),row['name']+' — '+role,font=font,fill=(235,232,215))
                frames.append(frame.quantize(colors=192))
            frames[0].save(dest/(row['family']+'_'+role+'.gif'),save_all=True,append_images=frames[1:],
                duration=83,loop=0,optimize=False,disposal=2)
            filelist=folder/'sequence.txt'
            filelist.write_text(''.join("file '"+str(p.resolve()).replace('\\','/')+"'\nduration 0.083333333\n" for p in paths),encoding='utf-8')
            target=OUT/row['stem']/'previews'/(role+'.mp4')
            done=subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-f','concat','-safe','0',
                '-i',str(filelist),'-an','-r','12','-c:v','libx264','-pix_fmt','yuv420p','-crf','19',
                '-movflags','+faststart',str(target)],capture_output=True,text=True,timeout=30)
            assert done.returncode==0,done.stderr

for family in dict.fromkeys(r['family'] for r in ASSETS):
    rows=[r for r in ASSETS if r['family']==family]
    gallery=Image.new('RGB',(4*320,2*370+40),(34,38,40));draw=ImageDraw.Draw(gallery)
    draw.text((14,8),rows[0]['family_name']+' — habilidades por evolução',font=font,fill=(235,232,215))
    for row in rows:
        for index,role in enumerate(roles_for(row)):
            paths=sorted((WORK/'frames'/row['stem']/role).glob('*.png'))
            path=paths[round(len(paths)*.54)] if row['tier']==2 else paths[1]
            img=Image.open(path).convert('RGB').resize((320,320),Image.Resampling.LANCZOS)
            x=row['tier']*320;y=40+index*370
            gallery.paste(img,(x,y));draw.text((x+8,y+321),role,font=font,fill=(235,232,215))
            draw.text((x+8,y+343),row['tier_name'],font=font,fill=(190,205,210))
    gallery.save(dest/(family+'_progression.jpg'),quality=95)
print('DWARF_SKILL_PREVIEWS_PACKAGED: 12 animations and 24-model progression')

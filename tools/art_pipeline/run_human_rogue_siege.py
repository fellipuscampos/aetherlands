"""One finished asset at a time, exclusively through the live Blender MCP."""
import argparse, json, hashlib
from pathlib import Path
import imageio.v2 as imageio
from PIL import Image, ImageDraw, ImageFont
from run_magic_school_batch import call
from human_rogue_siege_assets import ROOT, ASSETS, roles

PIPE=Path(__file__).resolve().parent

def encode(asset, role):
    stem=asset['stem']; clip=asset['prefix']+'_'+role
    files=sorted((ROOT/'art_source'/stem/'animation_frames'/clip).glob('*.png'))
    assert files
    out=ROOT/'assets/generated/humans'/stem/'previews/animations'; out.mkdir(parents=True,exist_ok=True)
    images=[Image.open(f).convert('RGB') for f in files]
    with imageio.get_writer(str(out/(clip+'.mp4')),fps=12,codec='libx264',quality=8,macro_block_size=1,ffmpeg_params=['-movflags','+faststart']) as writer:
        for f in files: writer.append_data(imageio.imread(f))
    # 12 fps review render; game/source animations are baked at 24 fps.
    frames=[im.quantize(colors=128) for im in images]
    frames[0].save(out/(clip+'.gif'),save_all=True,append_images=frames[1:],duration=83,loop=0,disposal=2)
    sheet=Image.new('RGB',(960,708),(28,32,40)); draw=ImageDraw.Draw(sheet)
    draw.text((12,10),asset['label']+' / '+role+' / 24 fps source, 12 fps preview',fill=(235,235,235))
    for i,t in enumerate((0,.2,.4,.6,.8,1)):
        index=round((len(images)-1)*t); x=(i%3)*320; y=36+(i//3)*336
        sheet.paste(images[index].resize((320,320),Image.Resampling.NEAREST),(x,y)); draw.text((x+8,y+321),'frame '+files[index].stem,fill=(235,235,235))
    sheet.save(out/(clip+'_contact.png'))

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--start',type=int,default=0); parser.add_argument('--end',type=int,default=8); parser.add_argument('--indices',type=int,nargs='+'); parser.add_argument('--resume-stage',choices=['build','preview','export'],default='build'); parser.add_argument('--all-resume',action='store_true'); parser.add_argument('--attach-cloth',action='store_true'); parser.add_argument('--mechanical-finish',action='store_true'); args=parser.parse_args()
    baseline=ROOT/'docs/human_rogue_siege_source_baseline.json'
    if not baseline.exists():
        paths=[p for p in (ROOT/'assets/generated').rglob('*') if p.is_file() and not p.name.endswith('.import') and not any(a['stem'] in p.parts for a in ASSETS)]
        paths += [ROOT/'scripts/data/UnitDatabase.gd',ROOT/'scripts/units/Unit.gd']
        data={str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.exists()}
        baseline.write_text(json.dumps(data,indent=2),encoding='utf-8'); print('BASELINE',len(data),flush=True)
    live=(PIPE/'human_rogue_siege_live.py').read_text(encoding='utf-8')
    for i in (args.indices if args.indices is not None else range(args.start,args.end)):
        a=ASSETS[i]; print('BUILD',i+1,a['stem'],flush=True)
        stage=args.resume_stage if i==args.start or args.all_resume else 'build'
        if args.attach_cloth: print(json.dumps(call(f'INDEX={i}\nSTAGE="attach_cloth"\n'+live)),flush=True)
        if args.mechanical_finish: print(json.dumps(call(f'INDEX={i}\nSTAGE="mechanical_finish"\n'+live)),flush=True)
        if stage=='build': print(json.dumps(call(f'INDEX={i}\nSTAGE="build"\n'+live)),flush=True)
        if stage!='export':
            for role in roles(a):
                print('PREVIEW',a['stem'],role,flush=True)
                print(json.dumps(call(f'INDEX={i}\nSTAGE="preview"\nPREVIEW_ROLE={role!r}\n'+live)),flush=True)
                encode(a,role)
        print(json.dumps(call(f'INDEX={i}\nSTAGE="export"\n'+live)),flush=True)
        print('SAVED',i+1,a['stem'],flush=True)

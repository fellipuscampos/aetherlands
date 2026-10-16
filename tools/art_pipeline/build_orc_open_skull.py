"""Solid bone gauntlets, seated horns and a jawless skull over the original face."""
import bpy,sys,importlib,numpy as np
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from orc_troop_assets import OUT,WORK
from build_elf_troops import pixels
from build_orc_squire import rectangle,cuboid_axes
from build_orc_tribal_equipment import frame
from build_orc_refined_clothing import gutter
import orc_closed_bone_armor_paint as paint
import build_orc_horns_hoods as shared
importlib.reload(shared)

FROZEN=WORK/'open_skull/before_assets'
KEYS=('sentinel','guardian_champion','armored_cavalier','griffon_rider')
DESCRIPTION='Jawless painted skull helmet over the original orc lower face, solid bone gauntlets, seated horns clear of the ears. No helmet brows. Approved bodies and animations retained.'

def modify(g,canvas):
    h,w=canvas.shape[:2];painted=[]
    g.remove(['Brow_l','Brow_r'])
    head=g.by['Head'];origin,axes,size=frame(head)
    for name in ('BoneArmor_SkullTempleHorn_-1','BoneArmor_SkullTempleHorn_1'):
        obj=g.by[name]
        # Preserve the successful crescent shape exactly. Seat its root farther
        # inside the upper temple; a slight lift clears the original ear volume.
        delta=axes@np.array([0,.060,.035])
        for v in obj.data.vertices:v.co=np.array(v.co)+delta
        obj.data.update()
    keel=g.by['BoneArmor_SkullNasalKeel']
    for v in keel.data.vertices:v.co=np.array(v.co)+axes[:,2]*size[2]*.14
    keel.data.update()
    original=bpy.data.images.load(str(OUT/'orc_squire_v1/orc_squire_v1_albedo.png'),check_existing=False)
    original.colorspace_settings.name='Non-Color';bare=pixels(original)
    assert bare.shape==canvas.shape or bare.shape[0]==h
    for name in ('Hand_l','Hand_r','Head'):
        obj=g.by[name]
        for poly in obj.data.polygons:
            lo,hi,frac=rectangle(obj,poly,w,h);x0,y0=lo;x1,y1=hi
            x,y,z=(frac[...,i] for i in range(3));vertical=poly.index>=2
            u=x if poly.index in (0,1,2,3) else y;v=z if vertical else y
            if name.startswith('Hand'):
                vertices,local_axes=cuboid_axes(obj);position=frac@local_axes.T+vertices[0]
                tile=paint.color(position,u,v)
                edge=np.minimum.reduce((u,1-u,v,1-v))
                tile[edge<.035]=paint.SHADE+[10,9,6]
                tile[(edge>.035)&(edge<.07)]=paint.RIDGE
                canvas[y0:y1,x0:x1,:3]=np.clip(tile,0,255).astype(np.uint8)
            else:
                tile=canvas[y0:y1,x0:x1,:3].copy();source=bare[y0:y1,x0:x1,:3]
                if poly.index==2:
                    cut=.37+.05*np.maximum(0,.5-abs(x-.5))
                    exposed=z<cut
                    tile[exposed]=source[exposed]
                    rim=(z>=cut)&(z<cut+.022);tile[rim]=paint.BONE-[28,24,16]
                elif poly.index in (3,4,5):
                    exposed=z<.31;tile[exposed]=source[exposed]
                    tile[(z>=.31)&(z<.33)]=paint.BONE-[28,24,16]
                elif poly.index==0:tile=source.copy()
                canvas[y0:y1,x0:x1,:3]=tile
            gutter(canvas,x0,y0,x1,y1)
        painted.append(name)
    return painted,['BoneArmor_SkullTempleHorn_-1','BoneArmor_SkullTempleHorn_1','BoneArmor_SkullNasalKeel']

def update_report(report,changes):
    report['open_skull_revision']='jawless_skull_v1';report['open_skull_refinement']=changes
    report['geometry']['eyebrow_cuboids']=0
    report['texture']['head_style']='painted_jawless_skull_with_original_orc_lower_face'
    changes.update(solid_bone_hands=True,helmet_brows_removed=True,original_lower_orc_face=True,
        horn_translation_head_local=[0,.060,.035],nose_bridge_translation_height_fraction=.14)

def build(row):return shared.build(row,refinement=sys.modules[__name__])

"""Keep the detached mantle as weathered blocks instead of framed shoulder plates."""
import bpy,numpy as np
from pathlib import Path
st=bpy.app.driver_namespace['archdemon_blocky_v2']
scene=st['scene']; bpy.context.window.scene=scene
removed=[o for o in st['parts'] if '_Mantle_' in o.name and (o.name.endswith('_Recess') or o.name.endswith('_Scar'))]
assert len(removed) in (0,8)
st['islands']=[it for it in st['islands'] if it['obj'] not in removed]
st['parts']=[o for o in st['parts'] if o not in removed]
for o in removed: bpy.data.objects.remove(o,do_unlink=True)
image=st['images'][0]; size=st['atlas']; pad=2
pixels=np.array(image.pixels[:],dtype=np.float32).reshape(size,size,4)
for index,it in enumerate(st['islands']):
    if it['obj']['kind']!='fragment': continue
    w,h=it['w'],it['h']; n=it['normal']; base=np.array((74,103,105))/255
    shade=1.07 if n.z>.8 else .78 if n.z<-.8 else 1 if n.y<0 else .88
    tile=np.ones((h,w,4),dtype=np.float32); tile[:,:,:3]=base*shade
    rng=np.random.default_rng(8900+index)
    for patch in range(max(1,round(w*h/70))):
        xx=int(rng.integers(0,w)); yy=int(rng.integers(0,h)); pw=int(rng.integers(2,8)); ph=int(rng.integers(2,5))
        value=float(rng.choice([.72,.85,1.10,1.20]))
        tile[yy:yy+ph,xx:xx+pw,:3]=base*shade*value
    if min(w,h)>8:
        tile[-1:,:,:3]=base*shade*1.20; tile[:1,:,:3]=base*shade*.65
        for yy in range(6,h-2,9):
            tile[yy:yy+1,1:max(2,w-3),:3]=base*shade*.65
            xx=round(w*(.35 if (yy//9)%2 else .65))
            tile[max(1,yy-4):yy,xx:xx+1,:3]=base*shade*.68
    pixels[it['y']-pad:it['y']+h+pad,it['x']-pad:it['x']+w+pad]=np.pad(tile,((pad,pad),(pad,pad),(0,0)),mode='edge')
if image.packed_file: image.unpack(method='REMOVE')
image.pixels.foreach_set(pixels.reshape(-1)); image.update(); image.save(); image.pack()
scene.render.filepath=str(Path(st['out'])/'previews/three_quarter.png'); bpy.ops.render.render(write_still=True)
result={'parts':len(st['parts']),'mantle':'Four simple weathered relic blocks, without inset panels or repeated red seals.'}

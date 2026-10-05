"""Refresh native pixel painting after palette/design edits without rebuilding geometry."""
import bpy
import random
from pathlib import Path
st=bpy.app.driver_namespace['mana_devourer']; NAME=st['name']; OUT=Path(st['out'])
islands=st['islands']; SIZE=st['size']; PAD=2; DENSITY=64
path=Path(r'C:\Users\felipe campos\Documents\jogo\tools\art_pipeline\mana_devourer_model.py')
script=path.read_text(encoding='utf-8')
exec('STONE='+script.split('\nSTONE=',1)[1].split('\nimages=[]',1)[0])
new=[]
for old,suffix,data in zip(st['images'],['albedo','emission'],[pixels,energy]):
    image=bpy.data.images.new(NAME+'_'+suffix+'_Updated',width=SIZE,height=SIZE,alpha=True)
    image.colorspace_settings.name='sRGB'; image.pixels.foreach_set(data)
    image.filepath_raw=str(OUT/f'mana_devourer_v1_{suffix}.png'); image.file_format='PNG'; image.save(); image.pack()
    for node in st['material'].node_tree.nodes:
        if node.type=='TEX_IMAGE' and node.image==old: node.image=image
    name=old.name; bpy.data.images.remove(old); image.name=name; new.append(image)
st['images']=new
result={'images':[i.name for i in new]}

"""Five classes, four orcs each; the approved squire is the anatomical source."""
from pathlib import Path
from elf_troop_assets import FAMILIES

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/generated/orcs'
WORK=ROOT/'art_source/orc_troops'
BASE=OUT/'orc_squire_v1/orc_squire_v1.blend'
ASSETS=[dict(stem='orc_'+key+'_v1',key=key,family=family,family_name=title,tier=tier,
             name=name+' Orc',gameplay_id=kind,character_height_m=2.2 if tier==3 else 2.0,
             source_stem='elf_'+key+'_v1',path='res://assets/generated/orcs/orc_'+key+'_v1/orc_'+key+'_v1.glb')
        for family,(title,units) in FAMILIES.items() for tier,(key,name,kind) in enumerate(units)]

# Practical progression: tanned hides, iron lamellae, heavy tempered plates;
# legendary metal uses dark steel with aged bronze edges instead of elven gold.
PROFILES={
 'guardian': [((90,62,40),'hide'),((103,101,85),'lamellar'),((88,92,88),'plate'),((55,62,62),'plate')],
 'warrior': [((102,61,37),'hide'),((93,92,81),'lamellar'),((80,86,83),'plate'),((53,59,59),'plate')],
 'ranger': [((93,73,44),'hide'),((79,63,40),'hide'),((65,57,41),'reinforced'),((52,60,49),'reinforced')],
 'cavalry': [((87,58,36),'hide'),((95,90,74),'lamellar'),((87,89,80),'plate'),((59,62,57),'plate')],
 'rogue': [((70,58,40),'hide'),((56,49,36),'hide'),((45,44,36),'reinforced'),((36,41,38),'reinforced')],
}

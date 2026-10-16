"""Dwarf skill contract derived from the live doctrine/runtime definitions.

The basic form has the first technique; evolved forms retain that technique
and gain the next. Guardian enter/hold form a single defensive technique.
"""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/generated/dwarves'
WORK = ROOT / 'art_source/dwarf_skills'
FPS = 48
SKILLS = {
    'guardian': {'shield_wall': (1.25, False), 'shield_wall_hold': (1.5, True)},
    'warrior': {'power_strike': (2.0, False), 'arc_attack': (2.0, False)},
    'ranger': {'precise_shot': (2.0, False), 'volley': (2.5, False)},
    'cavalry': {'charge': (2.0, False), 'tactical_retreat': (2.0, False)},
    'rogue': {'sneak_attack': (1.75, False), 'dismantle': (2.25, False)},
    'siege': {'demolition_ammo': (3.0, False), 'prepared_bombardment': (4.0, False)},
}
TECHNIQUES = {
    'guardian': {'v2_technique_shield_wall': 'shield_wall'},
    'warrior': {'v2_technique_power_strike': 'power_strike', 'v2_technique_cleave': 'arc_attack'},
    'ranger': {'v2_technique_precise_shot': 'precise_shot', 'v2_technique_volley': 'volley'},
    'cavalry': {'v2_technique_charge': 'charge', 'v2_technique_tactical_retreat': 'tactical_retreat'},
    'rogue': {'v2_technique_sneak_attack': 'sneak_attack', 'v2_technique_dismantle': 'dismantle'},
    'siege': {'v2_technique_demolition_ammo': 'demolition_ammo', 'v2_technique_prepared_bombardment': 'prepared_bombardment'},
}


def roles_for(row):
    roles = SKILLS[row['family']]
    if row['family'] == 'guardian' or row['tier'] > 0: return roles
    return dict(list(roles.items())[:1])


def techniques_for(row):
    roles = roles_for(row)
    return {technique: role for technique, role in TECHNIQUES[row['family']].items() if role in roles}

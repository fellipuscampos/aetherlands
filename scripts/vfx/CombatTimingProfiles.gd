# Generated from existing art reports by build_combat_timing_profiles.py.
extends RefCounted

const MODELS := {
  "ancient_golem_v2": {
    "Golem_Attack": 0.475
  },
  "archer_v1": {
    "Archer_Attack": 0.54166667,
    "Archer_PreciseShot": 0.60714286
  },
  "armored_cavalier_v1": {
    "ArmoredCavalier_Attack": 0.4375,
    "ArmoredCavalier_Charge": 0.27777778
  },
  "basilisk_blocky_v1": {
    "Basilisk_Attack": 0.40625
  },
  "blade_hero_v1": {
    "BladeHero_ArcAttack": 0.45,
    "BladeHero_Attack": 0.4375,
    "BladeHero_PowerStrike": 0.52083333
  },
  "bombard_v1": {
    "Bombard_Attack": 0.54166667,
    "Bombard_DemolitionAmmo": 0.55555556,
    "Bombard_PreparedBombardment": 0.55208333
  },
  "catapult_v1": {
    "Catapult_Attack": 0.54166667,
    "Catapult_DemolitionAmmo": 0.55555556
  },
  "cavalier_v1": {
    "Cavalier_Attack": 0.4375,
    "Cavalier_Charge": 0.27777778
  },
  "corrupted_hero_v1": {
    "Hero_Attack": 0.525
  },
  "elite_marksman_v1": {
    "EliteMarksman_Attack": 0.54166667,
    "EliteMarksman_PreciseShot": 0.60714286,
    "EliteMarksman_Volley": 0.20289855
  },
  "goblin_raider_v3": {
    "Goblin_Attack": 0.39285714
  },
  "griffon_rider_v1": {
    "GriffonRider_Attack": 0.4375,
    "GriffonRider_Charge": 0.27777778
  },
  "guardian_champion_v1": {
    "Champion_Attack": 0.4
  },
  "guardian_v1": {
    "Guardian_Attack": 0.4
  },
  "hunter_v1": {
    "Hunter_Attack": 0.54166667,
    "Hunter_PreciseShot": 0.60714286,
    "Hunter_Volley": 0.20289855
  },
  "legend_hunter_v1": {
    "LegendHunter_Attack": 0.54166667,
    "LegendHunter_PreciseShot": 0.60714286,
    "LegendHunter_Volley": 0.20289855
  },
  "mana_devourer_v1": {
    "ManaDevourer_Attack": 0.41666667
  },
  "minotaur_blocky_v1": {
    "Minotaur_Attack": 0.5
  },
  "rogue_v1": {
    "Rogue_Attack": 0.46875,
    "Rogue_SneakAttack": 0.48214286
  },
  "saboteur_v1": {
    "Saboteur_Dismantle": 0.48611111
  },
  "sand_worm_v1": {
    "Worm_Attack": 0.41666667
  },
  "sentinel_v1": {
    "Sentinel_Attack": 0.4
  },
  "shock_cavalier_v1": {
    "ShockCavalier_Attack": 0.4375,
    "ShockCavalier_Charge": 0.27777778
  },
  "siege_colossus_v1": {
    "SiegeColossus_Attack": 0.54166667,
    "SiegeColossus_DemolitionAmmo": 0.55555556,
    "SiegeColossus_PreparedBombardment": 0.55208333
  },
  "skeleton_warrior_v1": {
    "Skeleton_Attack": 0.42857143
  },
  "squire_v1": {
    "Squire_Attack": 0.4
  },
  "swordsman_v1": {
    "Swordsman_ArcAttack": 0.45,
    "Swordsman_Attack": 0.4375,
    "Swordsman_PowerStrike": 0.52083333
  },
  "trebuchet_v1": {
    "Trebuchet_Attack": 0.54166667,
    "Trebuchet_DemolitionAmmo": 0.55555556,
    "Trebuchet_PreparedBombardment": 0.55208333
  },
  "troll_blocky_v3": {
    "Troll_Attack": 0.55555556
  },
  "warg_v1": {
    "Warg_Attack": 0.4375
  },
  "warrior_v1": {
    "Warrior_Attack": 0.4375,
    "Warrior_PowerStrike": 0.52083333
  },
  "weapon_master_v1": {
    "WeaponMaster_ArcAttack": 0.45,
    "WeaponMaster_Attack": 0.4375,
    "WeaponMaster_PowerStrike": 0.52083333
  },
  "wyvern_blocky_v1": {
    "Wyvern_Attack": 0.40625
  }
}

# Shared animation libraries reused by other skins keep the same authored timing.
const CLIPS := {
  "Archer_Attack": 0.54166667,
  "Archer_PreciseShot": 0.60714286,
  "ArmoredCavalier_Attack": 0.4375,
  "ArmoredCavalier_Charge": 0.27777778,
  "Basilisk_Attack": 0.40625,
  "BladeHero_ArcAttack": 0.45,
  "BladeHero_Attack": 0.4375,
  "BladeHero_PowerStrike": 0.52083333,
  "Bombard_Attack": 0.54166667,
  "Bombard_DemolitionAmmo": 0.55555556,
  "Bombard_PreparedBombardment": 0.55208333,
  "Catapult_Attack": 0.54166667,
  "Catapult_DemolitionAmmo": 0.55555556,
  "Cavalier_Attack": 0.4375,
  "Cavalier_Charge": 0.27777778,
  "Champion_Attack": 0.4,
  "EliteMarksman_Attack": 0.54166667,
  "EliteMarksman_PreciseShot": 0.60714286,
  "EliteMarksman_Volley": 0.20289855,
  "Goblin_Attack": 0.39285714,
  "Golem_Attack": 0.475,
  "GriffonRider_Attack": 0.4375,
  "GriffonRider_Charge": 0.27777778,
  "Guardian_Attack": 0.4,
  "Hero_Attack": 0.525,
  "Hunter_Attack": 0.54166667,
  "Hunter_PreciseShot": 0.60714286,
  "Hunter_Volley": 0.20289855,
  "LegendHunter_Attack": 0.54166667,
  "LegendHunter_PreciseShot": 0.60714286,
  "LegendHunter_Volley": 0.20289855,
  "ManaDevourer_Attack": 0.41666667,
  "Minotaur_Attack": 0.5,
  "Rogue_Attack": 0.46875,
  "Rogue_SneakAttack": 0.48214286,
  "Saboteur_Dismantle": 0.48611111,
  "Sentinel_Attack": 0.4,
  "ShockCavalier_Attack": 0.4375,
  "ShockCavalier_Charge": 0.27777778,
  "SiegeColossus_Attack": 0.54166667,
  "SiegeColossus_DemolitionAmmo": 0.55555556,
  "SiegeColossus_PreparedBombardment": 0.55208333,
  "Skeleton_Attack": 0.42857143,
  "Squire_Attack": 0.4,
  "Swordsman_ArcAttack": 0.45,
  "Swordsman_Attack": 0.4375,
  "Swordsman_PowerStrike": 0.52083333,
  "Trebuchet_Attack": 0.54166667,
  "Trebuchet_DemolitionAmmo": 0.55555556,
  "Trebuchet_PreparedBombardment": 0.55208333,
  "Troll_Attack": 0.55555556,
  "Warg_Attack": 0.4375,
  "Warrior_Attack": 0.4375,
  "Warrior_PowerStrike": 0.52083333,
  "WeaponMaster_ArcAttack": 0.45,
  "WeaponMaster_Attack": 0.4375,
  "WeaponMaster_PowerStrike": 0.52083333,
  "Worm_Attack": 0.41666667,
  "Wyvern_Attack": 0.40625
}

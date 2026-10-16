"""Modelo de duelo das linhas militares (docs/BALANCE_PASS_2026-10-14.md).

Lê o JSON de `tools/balance/DumpBalanceData.tscn` e aplica a fórmula REAL de CombatResolver.predict sem modificadores
de situação (sem flanco, terreno, técnica, veterania, aura):

    dano    = max(1, ATQ - 0,5 x DEF)
    revide  = max(0, DEF - 0,5 x ATQ) x 0,5      (só se o atacante for corpo a corpo e o defensor sobreviver)

Para cada nível (N3/N5/N7/N9) imprime a matriz "golpes para matar o alvo cheio / revide por golpe" e um duelo 1 contra 1
com as duas iniciativas (quem tem alcance >= 2 contra corpo a corpo ganha um disparo livre, a aproximação). É uma
régua, não uma simulação: técnicas, auras, mobilidade e o papel de cerco/tanque ficam de fora — leia junto com a doc.

Uso:
    godot --headless --path . res://tools/balance/DumpBalanceData.tscn -- --out=C:/tmp/balance_data.json
    python tools/balance/unit_duel_model.py C:/tmp/balance_data.json
"""
import json
import math
import sys

LINES = {
    "guardian": ["v2_unit_shieldbearer", "v2_unit_guardian", "v2_unit_sentinel", "v2_legendary_guardian_champion"],
    "warrior": ["v2_unit_warrior", "v2_unit_swordsman", "v2_unit_weapon_master", "v2_legendary_blade_hero"],
    "ranger": ["v2_unit_archer", "v2_unit_hunter", "v2_unit_elite_marksman", "v2_legendary_legend_hunter"],
    "cavalry": ["v2_unit_cavalier", "v2_unit_shock_cavalier", "v2_unit_armored_cavalier", "v2_legendary_griffon_rider"],
    "rogue": ["v2_unit_rogue", "v2_unit_saboteur", "v2_unit_assassin", "v2_legendary_shadow_master"],
    "siege": ["v2_unit_catapult", "v2_unit_trebuchet", "v2_unit_bombard", "v2_legendary_siege_colossus"],
}
TIERS = ["N3", "N5", "N7", "N9"]


def hit(a, d):
    return max(1.0, a["attack"] - 0.5 * d["defense"])


def counter(a, d):
    if a["attack_range"] > 1:
        return 0.0
    return max(0.0, d["defense"] - 0.5 * a["attack"]) * 0.5


def duel(a, d):
    """a ataca primeiro; turnos alternados até alguém cair. Devolve (vencedor 'A'/'D', turnos, fração de Vida restante)."""
    ha, hd = a["max_hp"], d["max_hp"]
    if a["attack_range"] > 1 and d["attack_range"] <= 1:
        hd -= hit(a, d)
    if d["attack_range"] > 1 and a["attack_range"] <= 1:
        ha -= hit(d, a)
    for turn in range(1, 61):
        hd -= hit(a, d)
        if hd <= 0:
            return "A", turn, ha / a["max_hp"]
        ha -= counter(a, d)
        if ha <= 0:
            return "D", turn, hd / d["max_hp"]
        ha -= hit(d, a)
        if ha <= 0:
            return "D", turn, hd / d["max_hp"]
        hd -= counter(d, a)
        if hd <= 0:
            return "A", turn, ha / a["max_hp"]
    return "-", 60, 0.0


def main(path):
    units = json.load(open(path, encoding="utf-8"))["units"]
    for tier_index, tier in enumerate(TIERS):
        kinds = [LINES[line][tier_index] for line in LINES]
        print(f"\n-- {tier}: golpes para matar o alvo cheio (h) / revide por golpe (c)")
        print("atacante \\ alvo".ljust(22) + "".join(units[k]["unit_name"][:10].rjust(11) for k in kinds))
        for a in kinds:
            row = units[a]["unit_name"][:20].ljust(22)
            for d in kinds:
                row += f"{math.ceil(units[d]['max_hp'] / hit(units[a], units[d])):>5}h {counter(units[a], units[d]):4.1f}c"
            print(row)
        print("   duelos vencidos (2 x 5, as duas iniciativas) | saldo de Vida | ficha")
        for a in kinds:
            wins, score = 0, 0.0
            for d in kinds:
                if d == a:
                    continue
                first = duel(units[a], units[d])
                second = duel(units[d], units[a])
                wins += (first[0] == "A") + (second[0] == "D")
                score += (first[2] if first[0] == "A" else -first[2]) + (second[2] if second[0] == "D" else -second[2])
            u = units[a]
            print(f"   {u['unit_name'][:20]:<22} {wins:>2}/10  {score:+.2f}  {u['production_cost']:.0f} PP, Supr. {u['supply_cost']}, "
                  f"Vida {u['max_hp']:g} ATQ {u['attack']:g} DEF {u['defense']:g} alc. {u['attack_range']} mov. {u['movement_points']:g}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "balance_data.json")

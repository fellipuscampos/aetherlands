extends Node
## Despeja os dados de balanceamento ATUAIS (unidades treináveis + Hostes, monstros, feitiços, técnicas, pesquisa) em
## JSON, para a análise de `tools/balance/unit_duel_model.py` (docs/BALANCE_PASS_2026-10-14.md). Ferramenta de
## desenvolvimento (fora da exportação):
##   godot --headless --path . res://tools/balance/DumpBalanceData.tscn -- --out=C:/caminho/balance_data.json
## Sem --out grava em user://balance_data.json.
func _props(obj: Object) -> Dictionary:
	var d := {}
	for p in obj.get_property_list():
		if (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var v = obj.get(p.name)
		if v is Object:
			continue
		if p.name.ends_with("_path") or p.name.contains("animation") or p.name.contains("model") or p.name.begins_with("glow") or p.name.contains("posture") or p.name.contains("fire_breath"):
			continue
		d[p.name] = v
	return d
func _ready() -> void:
	var out := {"units": {}, "monsters": {}, "spells": [], "techniques": [], "research": []}
	var kinds: Array = UnitDatabase.PLAYER_TRAINABLE_KINDS.duplicate()
	kinds.append_array(["v2_unit_skeleton_host", "v2_unit_macabre_host"])
	for k in kinds:
		var u := UnitDatabase.create_unit(k)
		if u != null:
			out.units[k] = _props(u)
	for k in MonsterDatabase.KIND_DATA.keys():
		var m := MonsterDatabase.create_monster(k)
		if m != null:
			out.monsters[k] = _props(m)
	for s in V2SpellDatabase.all_spells():
		var d := _props(s)
		d["_text"] = V2SpellDatabase.effect_text(s)
		out.spells.append(d)
	for t in V2DoctrineTechniqueDatabase.all_techniques():
		var d := _props(t)
		out.techniques.append(d)
	for n in V2ResearchDatabase.all_nodes():
		out.research.append(_props(n))
	var out_path := "user://balance_data.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.substr(6)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	print("arquivo ", ProjectSettings.globalize_path(out_path), " — units ", out.units.size(), " monsters ", out.monsters.size(), " spells ", out.spells.size(), " techniques ", out.techniques.size(), " research ", out.research.size())
	get_tree().quit()

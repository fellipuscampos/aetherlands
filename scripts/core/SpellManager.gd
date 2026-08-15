class_name SpellManager
extends RefCounted

## Aplica o efeito de um feitico/ritual (ver SpellDatabase) contra um alvo
## escolhido no mapa — chamado por SelectionManager depois que o clique do
## jogador confirma um alvo valido (ver _valid_spell_target la). Estatico
## e sem estado proprio (mesmo padrao de Diplomacy.gd/CombatResolver.gd):
## so le/muta o PlayerData e o Unit passados.
##
## Custo (Ponto 3, "Economia Arcana"): DOIS gates independentes, os dois
## precisam estar satisfeitos pra conjurar —
## - can_cast(): tecnologia pesquisada + cooldown (PlayerData.spell_
##   cooldowns) ja passou.
## - has_enough_mana(): saldo de PlayerData.mana >= SpellData.mana_cost.
## is_castable() e a combinacao dos dois, e o que a HUD usa pra decidir se
## o botao "Conjurar" fica clicavel — mantidos separados (em vez de um
## unico can_cast que ja checasse tudo) pra cada motivo de bloqueio poder
## ser mostrado/testado com uma mensagem propria (recarga vs mana
## insuficiente), sem o chamador ter que redescobrir qual dos dois falhou.

## true se `caster` ja pesquisou a tecnologia que concede este feitico
## (TechDatabase.unlocked_spells_for) E o cooldown dele ja passou. NAO leva
## mana em conta (ver has_enough_mana/is_castable pra isso).
static func can_cast(caster: PlayerData, spell_name: String, current_turn: int) -> bool:
	if not (spell_name in TechDatabase.unlocked_spells_for(caster.researched_techs)):
		return false
	var available_at: int = caster.spell_cooldowns.get(spell_name, 0)
	return current_turn >= available_at

## false pra feitico sem SpellData cadastrado (Ruina Ignea/Metamorfose de
## Gaia, ver SpellDatabase) — nunca "castable" de verdade, mana ou nao.
static func has_enough_mana(caster: PlayerData, spell_name: String) -> bool:
	var spell: SpellData = SpellDatabase.get_spell(spell_name)
	if spell == null:
		return false
	return caster.mana >= spell.mana_cost

## can_cast() (tech+recarga) E has_enough_mana() (saldo) — usado pela HUD
## (Grimorio) pra decidir se "Conjurar" fica clicavel.
static func is_castable(caster: PlayerData, spell_name: String, current_turn: int) -> bool:
	return can_cast(caster, spell_name, current_turn) and has_enough_mana(caster, spell_name)

## Turno em que o feitico volta a ficar disponivel — so informativo pra UI
## (0 ou <= turno atual significa "disponivel agora").
static func cooldown_ends_at(caster: PlayerData, spell_name: String) -> int:
	return caster.spell_cooldowns.get(spell_name, 0)

## Resolve o efeito de verdade contra `target`, poe o feitico em cooldown
## E desconta o mana. O chamador (SelectionManager) ja validou que `target`
## bate com o target_kind do feitico antes de chegar aqui. Sempre devolve
## uma mensagem curta pronta pro toast (EventBus.notify) em vez de lancar
## erro — feitico sem SpellData cadastrado, em recarga, ou sem mana
## suficiente viram um no-op com aviso em vez de travar o jogo. Nenhum dos
## tres casos de bloqueio consome cooldown NEM mana — so uma conjuracao
## que realmente aconteceu cobra o custo.
static func cast(caster: PlayerData, spell_name: String, target: Unit, hex_grid: HexGrid, current_turn: int) -> String:
	var spell: SpellData = SpellDatabase.get_spell(spell_name)
	if spell == null:
		return "%s ainda não tem efeito implementado." % spell_name
	if not can_cast(caster, spell_name, current_turn):
		return "%s ainda está em recarga." % spell_name
	if caster.mana < spell.mana_cost:
		return "Mana insuficiente para conjurar %s (precisa de %d, tem %d)." % [spell_name, spell.mana_cost, int(caster.mana)]

	caster.spell_cooldowns[spell_name] = current_turn + spell.cooldown_turns
	caster.mana -= spell.mana_cost

	if spell.damage > 0.0:
		return _apply_damage(spell, target, hex_grid)
	if spell.heal_fraction > 0.0:
		return _apply_heal(spell, target)
	return "%s conjurado." % spell_name

static func _apply_damage(spell: SpellData, target: Unit, hex_grid: HexGrid) -> String:
	var target_name = target.unit_data.unit_name
	var target_coord = target.coord
	target.hp -= spell.damage
	hex_grid.spawn_damage_popup(target_coord, spell.damage)
	if target.hp <= 0.0:
		hex_grid.remove_unit(target)
		return "%s foi destruído por %s!" % [target_name, spell.name]
	return "%s causou %d de dano em %s." % [spell.name, int(spell.damage), target_name]

static func _apply_heal(spell: SpellData, target: Unit) -> String:
	var healed = target.unit_data.max_hp * spell.heal_fraction
	target.hp = min(target.unit_data.max_hp, target.hp + healed)
	return "%s restaurou %d de HP em %s." % [spell.name, int(healed), target.unit_data.unit_name]

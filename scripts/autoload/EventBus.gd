extends Node

signal tile_selected(coord: Vector2i, data: HexTileData)
signal unit_selected(unit: Unit)
signal game_over(victory: bool)
## Roadmap "Fase F" F1/F2/F3 -- emitido JUNTO com game_over (nunca sozinho,
## ver GameManager._end_game), nunca substituindo-o -- sistemas legados
## (HUD/AudioManager/botao de debug/testes existentes) continuam ouvindo
## so game_over sem precisar mudar nada. victory_type e uma das
## VictoryConditions.VICTORY_TYPE_* (ou VICTORY_TYPE_DEBUG pro botao de
## forcar fim de jogo). Pensado pra a tela de resultado detalhada (F1/F2
## passo 7, ainda nao implementada) consumir sem precisar transportar
## nenhum snapshot pelo proprio sinal -- ela consulta VictoryConditions
## de novo no momento de renderizar.
signal victory_achieved(winner: PlayerData, victory_type: String)
signal restart_requested
## sfx_kind identifica o efeito sonoro a tocar ("combat", "city" ou "" pra
## nenhum) — melhor do que o AudioManager tentar adivinhar pelo texto da
## mensagem, que e fragil se a redacao mudar.
signal notify(text: String, sfx_kind: String)
## Fase 28B: sinais de dominio neutros para a camada de eventos estruturados.
## Nenhum carrega Control/Node de UI e nenhum deles e persistido.
signal ui_research_completed(player: PlayerData, research_id: String, display_name: String)
signal ui_production_completed(player: PlayerData, city_name: String, item_id: String, display_name: String, target_coord: Vector2i)
signal diplomacy_changed(change_type: String, source: PlayerData, target: PlayerData, reason: String)
signal city_founded(player: PlayerData, city_name: String, target_coord: Vector2i)
signal city_captured(old_owner: PlayerData, new_owner: PlayerData, city_name: String, target_coord: Vector2i)
signal city_threatened(player: PlayerData, city_name: String, target_coord: Vector2i, threat_description: String)
## Apresentacao pode recomputar estado derivado sem observar gameplay por frame.
signal ui_state_changed(reason: String)
## Fase 30: SelectionManager entrou/saiu de um modo de mira (Técnica, feitiço,
## posicionamento de prédio, anexação, Ataque da Cidade). O estado continua
## sendo lido do próprio SelectionManager; o sinal só evita polling na UI.
signal targeting_changed
## Fase 30: clique fora dos alvos destacados durante a mira. Nada foi gasto;
## a mensagem é apenas feedback curto para o TargetingBanner.
signal targeting_rejected(message: String)
signal fog_updated
## Aetherlands V2 (Fase 3): um unlock V2 conectado passou a valer pro jogador
## HUMANO (ver V2UnlockSystem/PlayerData._on_v2_unlock_applied). A HUD só usa pra
## atualizar o painel de cidade — a disponibilidade em si é derivada da pesquisa.
signal v2_unlock_applied(player: PlayerData, unlock_type: String, unlock_id: String)
## Fase 23: informação pública do Ritual Final; nenhum destes sinais revela fog.
signal v2_transcendence_started(player: PlayerData, site_coord: Vector2i, remaining_rounds: int)
signal v2_transcendence_progressed(player: PlayerData, site_coord: Vector2i, remaining_rounds: int)
signal v2_transcendence_interrupted(player: PlayerData, site_coord: Vector2i, reason: String)
signal minimap_clicked(world_pos: Vector3)
## World Event System (docs/WORLD_EVENT_CONTRACT.md) -- emitidos so por
## WorldEventManager (ver comentario de topo la), nunca por um WorldEvent
## diretamente (mesma disciplina de victory_achieved: o sinal carrega o
## objeto vivo + um resultado, nunca um snapshot duplicado). result no
## sinal completed e so o resultado FINAL do evento (WorldEvent.result),
## nunca uma copia permanente do estado do evento inteiro.
signal world_event_announced(event: WorldEvent)
signal world_event_phase_changed(event: WorldEvent, old_phase: String, new_phase: String)
signal world_event_completed(event: WorldEvent, result: Dictionary)
## Fase 33D1: a era do mundo avançou (WorldPhaseRules.Phase). `cause` é interno (PROGRESS/FALLBACK) — a
## apresentação é a mesma nos dois casos; telemetria e testes podem ler.
signal world_phase_changed(old_phase: int, new_phase: int, turn: int, cause: String)
## Fase 33B (Release Balance Lab): observabilidade pura. Nenhum sistema do jogo conecta nestes
## sinais; só o observador de telemetria do laboratório (BalanceTelemetry) os escuta, e ele nunca
## escreve estado de gameplay nem alimenta decisões da IA.
## - city_production_processed: uma vez por cidade por turno, logo após City.process_turn;
##   item_id é o item em produção ANTES do processamento ("" = cidade ociosa neste turno).
## - unit_removed: toda remoção de unidade do mapa (morte, fundação, carga final do Construtor...).
## - combat_engagement: um ataque comum resolvido (target_kind "unit" ou "city", no tile target_coord).
signal city_production_processed(player: PlayerData, city: City, item_id: String, result: Dictionary)
signal unit_removed(former_owner: PlayerData, unit: Unit)
signal combat_engagement(attacker_owner: PlayerData, defender_owner: PlayerData, target_kind: String, target_coord: Vector2i)
## Fase 33D1 (observabilidade pura, mesma regra acima): covil destruído por uma civilização e melhoria
## saqueada por monstro (dono do tile). target_kind de combat_engagement ganha "lair" (ataque à estrutura).
signal lair_cleared(player: PlayerData, lair_coord: Vector2i, kind: String)
signal tile_pillaged(owner_player: PlayerData, coord: Vector2i)
## Fase 33D2 — ameaças do mundo (RegionalThreatSystem). `role` = HexGrid.LAIR_ROLE_REGIONAL/GUARDIAN.
## - regional_threat_created: covil regional associado à primeira capital de `owner_player`.
## - regional_threat_awakened: DORMANT → AWAKE (o covil em si pode ainda não ter sido descoberto; a UI
##   só anuncia ao dono que já o conhece).
## - world_threat_discovered: `player` passou a conhecer (tile explorado) um covil regional/guardião.
## - world_threat_resolved: estrutura destruída; `owner_player` = dono conceitual (null para guardião),
##   `resolver` = quem destruiu.
## - guardian_site_spawned: Guardião Troll criado na entrada da Ascensão junto a um recurso existente.
signal regional_threat_created(owner_player: PlayerData, lair_coord: Vector2i, kind: String)
signal regional_threat_awakened(owner_player: PlayerData, lair_coord: Vector2i, kind: String)
signal world_threat_discovered(player: PlayerData, lair_coord: Vector2i, role: String)
signal world_threat_resolved(role: String, owner_player: PlayerData, lair_coord: Vector2i, resolver: PlayerData)
signal guardian_site_spawned(lair_coord: Vector2i, resource_coord: Vector2i, resource: String)
## Fase 33D3 — marco público de vitória atingido (PublicVictoryMilestones): só o FATO, nunca posição/unidades.
signal public_milestone_reached(player: PlayerData, milestone: String)
## V3 / Combat Ecology (observabilidade pura, mesma regra da Fase 33B: só a telemetria do laboratório
## escuta). `action`: move (info.reason = chase/city/improvement/return/roam), attack, city_attack, pillage,
## civ_unit_killed, refill, site_depleted. `info`: species, tier, phase (id da era), ecology (monstro de
## sítio ecológico?) e, quando houver, target (índice da civilização alvo).
signal combat_ecology_event(action: String, info: Dictionary)

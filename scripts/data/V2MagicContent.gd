class_name V2MagicContent
extends RefCounted

## Conteúdo CANÔNICO da árvore de Escolas de Magia V2 (Aetherlands V2, Fase 17) — mesmo espírito de
## V2DoctrineContent (Fase 2) e V2InfrastructureContent (Fase 13): nomes finais, descrições, `unlock_id`
## e função pretendida. V2ResearchDatabase._apply_magic_content aplica isto sobre os nós estruturais
## das Fases 0-1 — os IDs de PESQUISA (v2_magic_<escola>_<n>), `tier`, custos e pré-requisitos não mudam.
##
## Fase 18: Sagrada e Infernal têm conteúdo e gameplay real (18 entradas). Fase 19: + Necromancia (27 entradas).
## Fase 20: + Druidismo (36 entradas). Fase 21: + Arcanismo (45 entradas).
## Fase 22: + Elementalismo (54 entradas). Fase 23: + Transcendência, fechando 55/55.
##
## Magia NÃO é uma segunda árvore militar: o conjurador do N3 não evolui fisicamente; N4-N7 aumentam o
## REPERTÓRIO dele (derivado da pesquisa do dono, ver V2MagicRuntime.spells_for_unit). Os números de
## cada feitiço vivem em V2SpellDatabase; os das unidades/prédios em UnitDatabase/BuildingDatabase.

## Unlock ids com gameplay REAL (Fase 17: os nove da Escola Sagrada). Um unlock mágico passa a existir
## acrescentando o id aqui E criando o objeto (UnitDatabase/BuildingDatabase/V2SpellDatabase).
const CONNECTED_UNLOCK_IDS: Array[String] = [
	"v2_magic_school_sacred",
	"v2_building_sacred_temple",
	"v2_unit_sacred_cleric",
	"v2_spell_restoring_light",
	"v2_spell_sacred_aegis",
	"v2_spell_healing_wave",
	"v2_spell_miracle",
	"v2_building_sacred_ritual",
	"v2_manifestation_seraph",
	"v2_magic_school_infernal",
	"v2_building_infernal_sanctum",
	"v2_unit_infernal_warlock",
	"v2_spell_infernal_flame",
	"v2_spell_devouring_fire",
	"v2_spell_infernal_blast",
	"v2_spell_damnation",
	"v2_building_infernal_ritual",
	"v2_manifestation_archdemon",
	"v2_magic_school_necromancy",
	"v2_building_necromancy_ossuary",
	"v2_unit_necromancer",
	"v2_spell_raise_dead",
	"v2_spell_mend_undead",
	"v2_spell_macabre_command",
	"v2_spell_raise_legion",
	"v2_building_necromancy_ritual",
	"v2_manifestation_lich_sovereign",
	"v2_magic_school_druidism",
	"v2_building_druidic_circle",
	"v2_unit_druid",
	"v2_spell_grow_grove",
	"v2_spell_restore_terrain",
	"v2_spell_raise_ground",
	"v2_spell_awaken_forest",
	"v2_building_druidic_ritual",
	"v2_manifestation_nature_avatar",
	"v2_magic_school_arcanism",
	"v2_building_arcane_conclave",
	"v2_unit_arcanist",
	"v2_spell_arcane_step",
	"v2_spell_silence",
	"v2_spell_dispel",
	"v2_spell_veil_portal",
	"v2_building_arcane_ritual",
	"v2_manifestation_veil_archon",
	"v2_magic_school_elementalism",
	"v2_building_elemental_observatory",
	"v2_unit_elementalist",
	"v2_spell_dense_mist",
	"v2_spell_gale",
	"v2_spell_lightning_storm",
	"v2_spell_elemental_cataclysm",
	"v2_building_elemental_ritual",
	"v2_manifestation_elemental_primordial",
	# Fase 23: o capstone universal entra pelo mesmo pipeline dos 54 nós normais.
	"v2_transcendence_access",
]

const TRANSCENDENCE_UNLOCK_ID := "v2_transcendence_access"
const TRANSCENDENCE_INTENT := "Desbloquear a via de vitória mágica por meio do Ritual Final de Transcendência."
const TRANSCENDENCE_DESCRIPTION := "O domínio completo de duas Escolas permite acessar a via de vitória por Transcendência. O Ritual Final exige duas Grandes Manifestações ativas de Escolas distintas, uma cidade com Estrutura Ritual utilizável, 120 Mana e quatro rodadas de sustentação."

## Regra do slot de Grande Manifestação (V2ManifestationSystem), anexada à descrição de cada N9 conectado.
const MANIFESTATION_RULE := "Cada civilização só pode ter UMA Grande Manifestação por Escola, ativa ou em produção."

## Apresentação das escolas V2 (dado de UI: emblema e cor do conjurador no mapa). A chave é o id da
## linha de pesquisa, que é também o valor de UnitData.v2_magic_school dos conjuradores V2 — nunca os ids
## V1 ("sagrada", "infernal"...), para que os feitiços V1 jamais sejam conjurados por uma unidade V2.
const SCHOOL_PRESENTATION := {
	"sacred": {"emblem": "SA", "color": Color("f4da87")},
	"infernal": {"emblem": "IN", "color": Color("f4774e")},
	"necromancy": {"emblem": "NE", "color": Color("bd86e6"),
		# Fase 19 — rótulos de UI do comando de retinues desta Escola (V2RetinueSystem é genérico; o texto é dado).
		"command_label": "Comando Necromântico", "uncommanded_reason": "Hoste sem comando necromântico."},
	"druidism": {"emblem": "DR", "color": Color("74d894")},
	"arcanism": {"emblem": "AR", "color": Color("86b9fc")},
	"elementalism": {"emblem": "EL", "color": Color("85e8ec")},
}

const BRANCHES := {
	"sacred": [
		{"name": "Escola Sagrada", "unlock_id": "v2_magic_school_sacred",
			"intent": "Abrir a tradição mágica de sustentação: cura e proteção.",
			"description": "Marco da Escola Sagrada: abre a tradição de sustentação do exército. Não concede bônus passivo — libera a pesquisa do Templo Sagrado."},
		{"name": "Templo Sagrado", "unlock_id": "v2_building_sacred_temple",
			"intent": "Estrutura de treinamento dos conjuradores Sagrados.",
			"description": "Prédio da Escola Sagrada. Treina Clérigos depois da pesquisa correspondente. Não produz Mana: a Mana vem da infraestrutura Arcana."},
		{"name": "Clérigo", "unlock_id": "v2_unit_sacred_cleric",
			"intent": "Conjurador de sustentação: não ataca, sustenta a linha com feitiços.",
			"description": "Conjurador da Escola Sagrada. Não possui ataque básico: sua força é o repertório de feitiços que a civilização pesquisa. Treinado no Templo Sagrado."},
		{"name": "Luz Restauradora", "unlock_id": "v2_spell_restoring_light",
			"intent": "Cura de alvo único.",
			"description": "Feitiço básico da Escola Sagrada: restaura a Vida de uma unidade própria ferida."},
		{"name": "Égide Sagrada", "unlock_id": "v2_spell_sacred_aegis",
			"intent": "Proteção temporária de uma unidade própria.",
			"description": "Feitiço intermediário da Escola Sagrada: envolve uma unidade própria em proteção, aumentando sua Defesa até o início do próximo turno do dono."},
		{"name": "Onda de Cura", "unlock_id": "v2_spell_healing_wave",
			"intent": "Cura em área de uma formação própria.",
			"description": "Feitiço avançado da Escola Sagrada: cura o alvo e todas as unidades próprias adjacentes a ele."},
		{"name": "Milagre", "unlock_id": "v2_spell_miracle",
			"intent": "Restauração total de uma unidade própria.",
			"description": "Grande feitiço da Escola Sagrada: restaura uma unidade própria viva ao máximo de Vida. Não ressuscita."},
		{"name": "Catedral Sagrada", "unlock_id": "v2_building_sacred_ritual",
			"intent": "Estrutura ritual: habilita a Grande Manifestação da Escola.",
			"description": "Estrutura ritual da Escola Sagrada. Exige o Templo Sagrado na mesma cidade e permite produzir o Serafim depois da pesquisa correspondente."},
		{"name": "Serafim", "unlock_id": "v2_manifestation_seraph",
			"intent": "Grande Manifestação Sagrada: entidade persistente, voadora e protetora.",
			"description": "Grande Manifestação da Escola Sagrada: uma entidade mágica voadora que conhece o repertório Sagrado da civilização e protege os aliados próximos. Não ataca."},
	],
	"infernal": [
		{"name": "Escola Infernal", "unlock_id": "v2_magic_school_infernal",
			"intent": "Abrir a tradição de dano mágico direto.",
			"description": "Marco da Escola Infernal: abre a tradição de dano mágico e libera a pesquisa do Santuário Infernal. Não concede bônus passivo."},
		{"name": "Santuário Infernal", "unlock_id": "v2_building_infernal_sanctum",
			"intent": "Estrutura de treinamento dos conjuradores Infernais.",
			"description": "Prédio da Escola Infernal. Treina Bruxos Infernais depois da pesquisa correspondente. Não produz Mana: a Mana vem da infraestrutura Arcana."},
		{"name": "Bruxo Infernal", "unlock_id": "v2_unit_infernal_warlock",
			"intent": "Conjurador frágil dedicado a dano mágico.",
			"description": "Conjurador da Escola Infernal. Não possui ataque básico: causa dano pelo repertório pesquisado pela civilização. Treinado no Santuário Infernal."},
		{"name": "Chama Infernal", "unlock_id": "v2_spell_infernal_flame",
			"intent": "Dano mágico direto de alvo único.",
			"description": "Feitiço básico da Escola Infernal: causa dano mágico direto a uma unidade hostil."},
		{"name": "Fogo Voraz", "unlock_id": "v2_spell_devouring_fire",
			"intent": "Pressão contra unidades já feridas.",
			"description": "Feitiço intermediário da Escola Infernal: causa dano adicional quando o alvo está com metade da Vida ou menos."},
		{"name": "Explosão Infernal", "unlock_id": "v2_spell_infernal_blast",
			"intent": "Dano mágico em área contra uma formação hostil.",
			"description": "Feitiço avançado da Escola Infernal: atinge o alvo e todas as unidades hostis adjacentes, sem fogo amigo."},
		{"name": "Condenação", "unlock_id": "v2_spell_damnation",
			"intent": "Grande dano mágico de alvo único.",
			"description": "Grande feitiço da Escola Infernal: concentra dano mágico em uma unidade hostil distante. Não afeta cidades."},
		{"name": "Círculo Profano", "unlock_id": "v2_building_infernal_ritual",
			"intent": "Estrutura ritual: habilita a Grande Manifestação da Escola.",
			"description": "Estrutura ritual da Escola Infernal. Exige o Santuário Infernal na mesma cidade e permite produzir o Arquidemônio depois da pesquisa correspondente."},
		{"name": "Arquidemônio", "unlock_id": "v2_manifestation_archdemon",
			"intent": "Grande Manifestação Infernal: entidade voadora que amplifica dano de feitiços.",
			"description": "Grande Manifestação da Escola Infernal: entidade mágica voadora que conhece o repertório Infernal e causa mais dano com feitiços. Não ataca."},
	],
	"necromancy": [
		{"name": "Escola da Necromancia", "unlock_id": "v2_magic_school_necromancy",
			"intent": "Abrir a tradição de invocação e comando de mortos-vivos.",
			"description": "Marco da Escola de Necromancia: abre a tradição de invocação e comando de mortos-vivos e libera a pesquisa do Ossuário. Não concede bônus passivo."},
		{"name": "Ossuário", "unlock_id": "v2_building_necromancy_ossuary",
			"intent": "Estrutura de treinamento dos conjuradores Necromânticos.",
			"description": "Prédio da Escola de Necromancia. Treina Necromantes depois da pesquisa correspondente. Não produz Mana: a Mana vem da infraestrutura Arcana."},
		{"name": "Necromante", "unlock_id": "v2_unit_necromancer",
			"intent": "Conjurador comandante: ergue e comanda Hostes de mortos-vivos.",
			"description": "Conjurador da Escola de Necromancia. Não possui ataque básico: ergue Hostes mortas-vivas persistentes e concede capacidade de Comando Necromântico. Treinado no Ossuário."},
		{"name": "Erguer Mortos", "unlock_id": "v2_spell_raise_dead",
			"intent": "Invocar uma Hoste Esquelética num tile livre.",
			"description": "Feitiço básico da Escola de Necromancia: ergue uma Hoste Esquelética persistente num tile livre próximo, se houver Comando Necromântico disponível. Não exige cadáveres."},
		{"name": "Recompor Ossos", "unlock_id": "v2_spell_mend_undead",
			"intent": "Cura exclusiva de mortos-vivos.",
			"description": "Feitiço intermediário da Escola de Necromancia: restaura a Vida de uma unidade própria morta-viva ferida."},
		{"name": "Comando Macabro", "unlock_id": "v2_spell_macabre_command",
			"intent": "Fortalecer o ataque de uma Hoste.",
			"description": "Feitiço avançado da Escola de Necromancia: aumenta o Ataque de uma Hoste própria até o início do próximo turno do dono."},
		{"name": "Erguer Legião", "unlock_id": "v2_spell_raise_legion",
			"intent": "Invocar uma Hoste Macabra num tile livre.",
			"description": "Grande feitiço da Escola de Necromancia: ergue uma Hoste Macabra persistente num tile livre próximo, se houver Comando Necromântico disponível."},
		{"name": "Mausoléu Negro", "unlock_id": "v2_building_necromancy_ritual",
			"intent": "Estrutura ritual: habilita a Grande Manifestação da Escola.",
			"description": "Estrutura ritual da Escola de Necromancia. Exige o Ossuário na mesma cidade e permite produzir o Lich Soberano depois da pesquisa correspondente."},
		{"name": "Lich Soberano", "unlock_id": "v2_manifestation_lich_sovereign",
			"intent": "Grande Manifestação Necromântica: soberano morto-vivo que amplia o comando das Hostes.",
			"description": "Grande Manifestação da Escola de Necromancia: um soberano morto-vivo que conhece o repertório Necromântico e amplia a capacidade de Comando Necromântico (Soberania dos Mortos). Não ataca."},
	],
	"druidism": [
		{"name": "Escola Druídica", "unlock_id": "v2_magic_school_druidism",
			"intent": "Abrir a tradição de manipulação física do terreno.",
			"description": "Marco da Escola Druídica: abre a tradição de transformar fisicamente o campo de batalha e libera a pesquisa do Círculo Druídico. Não concede bônus passivo."},
		{"name": "Círculo Druídico", "unlock_id": "v2_building_druidic_circle",
			"intent": "Estrutura de treinamento dos conjuradores Druídicos.",
			"description": "Prédio da Escola Druídica. Treina Druidas depois da pesquisa correspondente. Não produz Mana: a Mana vem da infraestrutura Arcana."},
		{"name": "Druida", "unlock_id": "v2_unit_druid",
			"intent": "Conjurador que remodela o terreno.",
			"description": "Conjurador da Escola Druídica. Não possui ataque básico: cria e restaura modificações físicas persistentes de terreno, que alteram movimento e Defesa física para qualquer um. Treinado no Círculo Druídico."},
		{"name": "Brotar Bosque", "unlock_id": "v2_spell_grow_grove",
			"intent": "Criar Bosque Denso num tile livre.",
			"description": "Feitiço básico da Escola Druídica: faz brotar um Bosque Denso persistente num tile livre, mais custoso de atravessar e melhor de defender."},
		{"name": "Restaurar Terreno", "unlock_id": "v2_spell_restore_terrain",
			"intent": "Remover uma modificação física de terreno.",
			"description": "Feitiço intermediário da Escola Druídica: devolve um tile ao terreno original, removendo a modificação física de terreno que houver — mesmo sob uma unidade. Não remove efeitos mágicos de unidades."},
		{"name": "Erguer Terreno", "unlock_id": "v2_spell_raise_ground",
			"intent": "Criar Terreno Elevado num tile livre.",
			"description": "Feitiço avançado da Escola Druídica: ergue um Terreno Elevado persistente num tile livre — difícil de subir, forte de defender."},
		{"name": "Despertar a Mata", "unlock_id": "v2_spell_awaken_forest",
			"intent": "Remodelar uma pequena área em Bosque Denso.",
			"description": "Grande feitiço da Escola Druídica: desperta Bosque Denso no tile alvo e nos tiles adjacentes elegíveis, inclusive sob unidades. Estruturas, cidades e terrenos já modificados ficam como estão."},
		{"name": "Bosque Ancestral", "unlock_id": "v2_building_druidic_ritual",
			"intent": "Estrutura ritual: habilita a Grande Manifestação da Escola.",
			"description": "Estrutura ritual da Escola Druídica. Exige o Círculo Druídico na mesma cidade e permite produzir o Avatar da Natureza depois da pesquisa correspondente."},
		{"name": "Avatar da Natureza", "unlock_id": "v2_manifestation_nature_avatar",
			"intent": "Grande Manifestação Druídica: entidade natural resistente que remodela o mapa de mais longe.",
			"description": "Grande Manifestação da Escola Druídica: uma entidade natural resistente que conhece o repertório Druídico e alcança mais longe com ele (Domínio Natural). Não ataca."},
	],
	"arcanism": [
		{"name": "Escola do Arcanismo", "unlock_id": "v2_magic_school_arcanism",
			"intent": "Abrir a tradição de mobilidade e utilidade mágicas.",
			"description": "Marco do Arcanismo: abre a tradição de reposicionamento e interferência sobre feitiços. Não concede bônus passivo."},
		{"name": "Conclave Arcano", "unlock_id": "v2_building_arcane_conclave",
			"intent": "Estrutura de treinamento dos Arcanistas.",
			"description": "Prédio da Escola do Arcanismo. Treina Arcanistas depois da pesquisa correspondente. Não produz Mana: a Mana vem da infraestrutura Arcana."},
		{"name": "Arcanista", "unlock_id": "v2_unit_arcanist",
			"intent": "Conjurador de mobilidade e interferência mágica.",
			"description": "Conjurador do Arcanismo. Não possui ataque básico: reposiciona forças e interfere em feitiços pelo repertório pesquisado pela civilização."},
		{"name": "Passo Arcano", "unlock_id": "v2_spell_arcane_step",
			"intent": "Teleportar o próprio conjurador para um tile visível.",
			"description": "Feitiço básico do Arcanismo: reposiciona diretamente o conjurador num destino legal, sem calcular caminho nem capturar cidade."},
		{"name": "Silêncio", "unlock_id": "v2_spell_silence",
			"intent": "Impedir temporariamente a conjuração de um inimigo.",
			"description": "Feitiço intermediário do Arcanismo: silencia um conjurador hostil até o início do próximo turno do dono, sem impedir movimento ou ações não mágicas."},
		{"name": "Dissipar", "unlock_id": "v2_spell_dispel",
			"intent": "Remover efeitos mágicos elegíveis de um tile.",
			"description": "Feitiço avançado do Arcanismo: remove efeitos prejudiciais de unidade própria, efeitos benéficos de unidade hostil e fecha um par de Portais atingido."},
		{"name": "Portal do Véu", "unlock_id": "v2_spell_veil_portal",
			"intent": "Conectar dois pontos por travessia mágica explícita.",
			"description": "Grande feitiço do Arcanismo: cria um par persistente entre a posição do conjurador e um tile visível. Unidades próprias atravessam por ação explícita."},
		{"name": "Torre do Véu", "unlock_id": "v2_building_arcane_ritual",
			"intent": "Estrutura ritual: habilitar a Grande Manifestação da Escola.",
			"description": "Estrutura ritual do Arcanismo. Exige o Conclave Arcano na mesma cidade e permite produzir o Arconte do Véu depois da pesquisa correspondente."},
		{"name": "Arconte do Véu", "unlock_id": "v2_manifestation_veil_archon",
			"intent": "Grande Manifestação do Arcanismo: entidade voadora que acelera seu repertório.",
			"description": "Grande Manifestação do Arcanismo: entidade mágica voadora que conhece o repertório Arcano e reduz em um turno a recarga aplicada por seus feitiços. Não ataca."},
	],
	"elementalism": [
		{"name": "Escola do Elementalismo", "unlock_id": "v2_magic_school_elementalism",
			"intent": "Abrir a tradição de controle ambiental temporário.",
			"description": "Marco do Elementalismo: abre a tradição de zonas ambientais temporárias e libera a pesquisa do Observatório Elemental. Não concede bônus passivo."},
		{"name": "Observatório Elemental", "unlock_id": "v2_building_elemental_observatory",
			"intent": "Estrutura de treinamento dos Elementalistas.",
			"description": "Prédio da Escola do Elementalismo. Treina Elementalistas depois da pesquisa correspondente. Não produz Mana."},
		{"name": "Elementalista", "unlock_id": "v2_unit_elementalist",
			"intent": "Conjurador de controle ambiental temporário.",
			"description": "Conjurador do Elementalismo. Não possui ataque básico: cria zonas temporárias que alteram visão, disparos e risco por rodada."},
		{"name": "Névoa Cerrada", "unlock_id": "v2_spell_dense_mist",
			"intent": "Reduzir temporariamente a visão das unidades numa região.",
			"description": "Feitiço básico do Elementalismo: cria uma zona temporária de Névoa que reduz a visão de qualquer unidade dentro dela."},
		{"name": "Vendaval", "unlock_id": "v2_spell_gale",
			"intent": "Prejudicar ataques físicos à distância numa região.",
			"description": "Feitiço intermediário do Elementalismo: cria um Vendaval temporário que reduz ataques físicos à distância disparados de dentro da zona."},
		{"name": "Tempestade Elétrica", "unlock_id": "v2_spell_lightning_storm",
			"intent": "Criar uma região perigosa com dano mágico por rodada.",
			"description": "Feitiço avançado do Elementalismo: cria uma Tempestade que causa dano mágico ambiental a qualquer unidade dentro dela ao fim de cada rodada global."},
		{"name": "Cataclismo Elemental", "unlock_id": "v2_spell_elemental_cataclysm",
			"intent": "Combinar pressão de visão, disparos e dano numa grande área.",
			"description": "Grande feitiço do Elementalismo: cobre uma grande região com uma zona temporária que reduz visão, prejudica disparos e causa dano por rodada."},
		{"name": "Nexo dos Elementos", "unlock_id": "v2_building_elemental_ritual",
			"intent": "Estrutura ritual: habilitar a Grande Manifestação da Escola.",
			"description": "Estrutura ritual do Elementalismo. Exige o Observatório Elemental na mesma cidade e permite produzir o Primordial dos Elementos."},
		{"name": "Primordial dos Elementos", "unlock_id": "v2_manifestation_elemental_primordial",
			"intent": "Grande Manifestação que prolonga as zonas ambientais que cria.",
			"description": "Grande Manifestação do Elementalismo: entidade voadora que conhece o repertório Elemental e prolonga em uma rodada as zonas que cria (Coração Elemental). Não ataca."},
	],
}

## As 9 entradas (N1..N9) de uma Escola; [] se a Escola ainda não tem conteúdo (placeholder inerte).
static func entries_for(branch: String) -> Array:
	return BRANCHES.get(branch, [])

## `school` (UnitData.v2_magic_school) é uma Escola V2?
static func is_v2_school(school: String) -> bool:
	return SCHOOL_PRESENTATION.has(school)

## "Escola Sagrada" — o título da linha de pesquisa da Escola (fonte: V2ResearchDatabase.MAGIC_BRANCHES).
static func school_title(school: String) -> String:
	return String(V2ResearchDatabase.branch_info(V2ResearchNode.TreeType.MAGIC_SCHOOL, school).get("title", school))

static func school_color(school: String) -> Color:
	return SCHOOL_PRESENTATION.get(school, {}).get("color", Color.WHITE)

static func school_emblem(school: String) -> String:
	return String(SCHOOL_PRESENTATION.get(school, {}).get("emblem", ""))

## Fase 19 — rótulo do comando de retinues da Escola ("Comando Necromântico"); fallback genérico.
static func command_label(school: String) -> String:
	return String(SCHOOL_PRESENTATION.get(school, {}).get("command_label", "Comando — %s" % school_title(school)))

## Fase 19 — motivo mostrado quando uma retinue da Escola está sem comando; fallback genérico.
static func uncommanded_reason(school: String) -> String:
	return String(SCHOOL_PRESENTATION.get(school, {}).get("uncommanded_reason", "Retinue sem comando."))

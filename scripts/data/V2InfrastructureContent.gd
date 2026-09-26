class_name V2InfrastructureContent
extends RefCounted

## Conteúdo CANÔNICO da árvore de Infraestrutura V2: nomes finais, descrições e função pretendida
## das 18 pesquisas (6 linhas × 3 níveis) — mesmo espírito de V2DoctrineContent (Fase 2).
##
## Fase 13: só Urbanização tinha gameplay real (v2_city_level_2/3/4); as outras cinco linhas
## (Economia, Logística, Indústria, Academia, Arcano) ficaram com nomes/descrições reais mas SEM
## unlock_id definitivo (§65 da Fase 13: "não adicionar unlock ids definitivos só pra preencher
## tabela"), porque os prédios reais ainda não existiam.
##
## Fase 14: as cinco linhas econômicas ganham unlock_id real — os quinze ids EXATOS do pedido
## (§65 desta fase), vindos de V2InfrastructureEconomyData (fonte única dos prédios/yields; aqui
## só se referencia o id literal, igual Urbanização já fazia). `gameplay_connected` passa a valer
## para as 18 pesquisas de Infraestrutura — Urbanização continua `unlock_type = "city_level"`
## (nunca alterado, ver V2ResearchDatabase._apply_infrastructure_content); as cinco linhas
## econômicas usam `unlock_type = "building"` no N1 e `"infrastructure_upgrade"` no N2/N3 (§66).

## FASE 14: as 18 pesquisas de Infraestrutura têm gameplay real (3 Urbanização + 15 econômicas).
const CONNECTED_UNLOCK_IDS: Array[String] = [
	"v2_city_level_2",
	"v2_city_level_3",
	"v2_city_level_4",
	"v2_building_market",
	"v2_market_efficiency_2",
	"v2_market_efficiency_3",
	"v2_building_farm",
	"v2_farm_efficiency_2",
	"v2_farm_efficiency_3",
	"v2_building_workshop",
	"v2_workshop_efficiency_2",
	"v2_workshop_efficiency_3",
	"v2_building_academy",
	"v2_academy_efficiency_2",
	"v2_academy_efficiency_3",
	"v2_building_arcane_shrine",
	"v2_arcane_shrine_efficiency_2",
	"v2_arcane_shrine_efficiency_3",
]

const BRANCHES := {
	"economy": [
		{"name": "Mercados Locais", "intent": "Desbloquear a infraestrutura básica de geração de Ouro.", "unlock_id": "v2_building_market",
			"description": "Primeiro passo da linha de Economia: abre a infraestrutura básica de geração de Ouro para as cidades da civilização."},
		{"name": "Contabilidade", "intent": "Aumentar a eficiência dos Mercados.", "unlock_id": "v2_market_efficiency_2",
			"description": "Melhora a eficiência das estruturas de Mercado já construídas, aumentando o Ouro gerado por elas."},
		{"name": "Rede Mercantil", "intent": "Maximizar a geração de Ouro das estruturas econômicas.", "unlock_id": "v2_market_efficiency_3",
			"description": "Topo da linha de Economia: maximiza a geração de Ouro de toda a infraestrutura econômica da civilização."},
	],
	"logistics": [
		{"name": "Abastecimento", "intent": "Desbloquear a infraestrutura básica de Suprimentos.", "unlock_id": "v2_building_farm",
			"description": "Primeiro passo da linha de Logística: abre a infraestrutura básica de Suprimentos para as cidades da civilização."},
		{"name": "Cadeias de Suprimento", "intent": "Aumentar a capacidade logística das cidades.", "unlock_id": "v2_farm_efficiency_2",
			"description": "Melhora a capacidade logística das cidades, aumentando quanto de Suprimentos a infraestrutura consegue sustentar."},
		{"name": "Intendência", "intent": "Maximizar a capacidade de Suprimentos da infraestrutura.", "unlock_id": "v2_farm_efficiency_3",
			"description": "Topo da linha de Logística: maximiza a capacidade de Suprimentos de toda a infraestrutura da civilização."},
	],
	"industry": [
		{"name": "Oficinas", "intent": "Desbloquear Oficina e Construtor básico.", "unlock_id": "v2_building_workshop",
			"description": "Primeiro passo da linha de Indústria: abre a Oficina para as cidades da civilização. Também habilitará a infraestrutura de Construtores na próxima etapa econômica."},
		{"name": "Engenharia", "intent": "Aumentar Produção e melhorar a autonomia do Construtor.", "unlock_id": "v2_workshop_efficiency_2",
			"description": "Aumenta a Produção gerada pelas Oficinas já construídas."},
		{"name": "Manufatura", "intent": "Maximizar Produção e as cargas do Construtor.", "unlock_id": "v2_workshop_efficiency_3",
			"description": "Topo da linha de Indústria: maximiza a Produção local gerada pelas Oficinas da civilização."},
	],
	"academy": [
		{"name": "Academias", "intent": "Desbloquear geração básica de Conhecimento.", "unlock_id": "v2_building_academy",
			"description": "Primeiro passo da linha de Academia: abre a geração básica de Conhecimento para as cidades da civilização."},
		{"name": "Métodos de Estudo", "intent": "Aumentar Conhecimento produzido pelas Academias.", "unlock_id": "v2_academy_efficiency_2",
			"description": "Melhora os métodos de ensino das Academias já construídas, aumentando o Conhecimento produzido por elas."},
		{"name": "Centros de Pesquisa", "intent": "Maximizar geração de Conhecimento.", "unlock_id": "v2_academy_efficiency_3",
			"description": "Topo da linha de Academia: maximiza a geração de Conhecimento de toda a infraestrutura acadêmica da civilização."},
	],
	"arcane": [
		{"name": "Santuários Arcanos", "intent": "Desbloquear infraestrutura básica de Mana.", "unlock_id": "v2_building_arcane_shrine",
			"description": "Primeiro passo da linha Arcana: abre a infraestrutura básica de geração de Mana para as cidades da civilização."},
		{"name": "Condução de Mana", "intent": "Aumentar Mana produzida pela infraestrutura arcana.", "unlock_id": "v2_arcane_shrine_efficiency_2",
			"description": "Melhora a condução de Mana da infraestrutura arcana já construída, aumentando a Mana produzida por ela."},
		{"name": "Nexos Arcanos", "intent": "Maximizar geração de Mana.", "unlock_id": "v2_arcane_shrine_efficiency_3",
			"description": "Topo da linha Arcana: maximiza a geração de Mana de toda a infraestrutura arcana da civilização."},
	],
	"urbanization": [
		{"name": "Planejamento Urbano", "intent": "Permitir Cidade II.", "unlock_id": "v2_city_level_2",
			"description": "Permite que cidades evoluam para Cidade II e ergam Muralhas I. Cada cidade continua precisando produzir seus próprios projetos — pesquisar isto não sobe nem fortifica nenhuma cidade sozinha."},
		{"name": "Cidade Fortificada", "intent": "Permitir Cidade III.", "unlock_id": "v2_city_level_3",
			"description": "Permite que cidades evoluam para Cidade III e reforcem as defesas para Muralhas II."},
		{"name": "Metrópole", "intent": "Permitir Cidade IV.", "unlock_id": "v2_city_level_4",
			"description": "Permite que cidades evoluam para Cidade IV e ergam uma Fortaleza, o ápice do desenvolvimento urbano."},
	],
}

## As 3 entradas (N1..N3) de uma linha de Infraestrutura; [] se a linha não existe.
static func entries_for(branch: String) -> Array:
	return BRANCHES.get(branch, [])

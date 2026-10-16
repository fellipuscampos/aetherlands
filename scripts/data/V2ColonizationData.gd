class_name V2ColonizationData
extends RefCounted

## Linha de Infraestrutura "Colonização" (2026-10-09): o limite de Colonos que uma civilização pode TREINAR na
## partida inteira. Dado puro — quem aplica é V2ColonizationRuntime (City.can_train / GameManager na conclusão).
##
## Regra: sem nenhuma pesquisa da linha, nenhum Colono pode ser treinado (o Colono inicial é grátis e não conta);
## N1 libera 1 no total, N2 libera 2 no total, N3 remove o limite. O limite é do MAIOR nível concluído, nunca
## somado entre níveis. "Treinado" = Colono que nasceu de produção de cidade (PlayerData.settlers_trained).

## Sem limite (N3).
const UNLIMITED := -1

## unlock_id do nó de pesquisa -> Colonos que a civilização pode treinar na partida (UNLIMITED = sem limite).
const SETTLER_LIMIT_BY_UNLOCK := {
	"v2_settler_limit_1": 1,
	"v2_settler_limit_2": 2,
	"v2_settler_limit_unlimited": UNLIMITED,
}

## Texto do limite para tooltip/toast ("até 2 Colonos na partida" / "Colonos sem limite").
static func limit_label(limit: int) -> String:
	if limit == UNLIMITED:
		return "Colonos sem limite"
	return "até %d Colono%s na partida" % [limit, "" if limit == 1 else "s"]

class_name V2OwnerTurnEffect
extends RefCounted

## Regra ÚNICA de "efeito até o início do próximo turno do dono" (Técnicas Militares — Fase 4 — e feitiços
## V2 — Fase 17), extraída pra não copiar o T+2 em vários lugares.
##
## Nesta base de turnos o mundo (IA, monstros) age DENTRO da troca de turno, já com turn_number+1, antes de
## o dono voltar a jogar. Por isso o efeito é gravado em `magic_status[id]` com expiração EXCLUSIVA em
## T + SPAN_TURNS (cobre a fase dos rivais) e o dono o encerra no início do turno seguinte
## (GameManager._finish_turn -> expire). O limite T+2 é só rede de segurança.

const SPAN_TURNS := 2

## O valor a gravar em `magic_status[id]` para um efeito ativado agora.
static func expiry_for_now() -> int:
	return TurnManager.turn_number + SPAN_TURNS

static func is_active(status: Dictionary, id: String) -> bool:
	return int(status.get(id, 0)) > TurnManager.turn_number

## O efeito gravado com `stored` foi ativado num turno ANTERIOR ao atual (= o dono já voltou a jogar)?
static func has_ended(stored: int) -> bool:
	return stored - SPAN_TURNS < TurnManager.turn_number

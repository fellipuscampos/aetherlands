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

## COMO A DURAÇÃO É DITA AO JOGADOR (2026-10-13). Relato do usuário: "eu ativo o efeito no meu turno, o efeito fica
## ativo, eu dou próximo, e o efeito já acabou". A regra sempre cobriu o turno dos inimigos (test_buff_duration.gd
## passa pela troca de turno de verdade), mas a interface dizia "1t" / "até o início do próximo turno do dono" e nada
## mostrava que o efeito tinha valido enquanto o inimigo jogava: o jogador ativava, via o efeito sumir no turno
## seguinte e concluía que ele não tinha servido. Os textos abaixo são a fonte única de todo lugar que fala desta
## duração.
## Para quem USA o efeito (descrição do botão do feitiço ou da técnica).
const DURATION_FOR_CASTER := "até o início do seu próximo turno — vale durante todo o turno dos inimigos"
## Num estado visto em QUALQUER unidade (linhas do inspetor, tooltip do chip).
const DURATION_ON_UNIT := "até o início do próximo turno do dono — cobre o turno dos adversários"
## Rótulo curto do chip no card da unidade, no lugar de "1t" (que parecia "só este turno").
const CHIP_DURATION := "até o próx. turno"

## O valor a gravar em `magic_status[id]` para um efeito ativado agora.
static func expiry_for_now() -> int:
	return TurnManager.turn_number + SPAN_TURNS

static func is_active(status: Dictionary, id: String) -> bool:
	return int(status.get(id, 0)) > TurnManager.turn_number

## O efeito gravado com `stored` foi ativado num turno ANTERIOR ao atual (= o dono já voltou a jogar)?
static func has_ended(stored: int) -> bool:
	return stored - SPAN_TURNS < TurnManager.turn_number

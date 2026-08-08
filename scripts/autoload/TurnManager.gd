extends Node

signal turn_changed(turn_number: int, player_index: int)

var turn_number: int = 1
var current_player_index: int = 0
var player_count: int = 1

func end_turn() -> void:
	current_player_index = (current_player_index + 1) % player_count
	if current_player_index == 0:
		turn_number += 1
	turn_changed.emit(turn_number, current_player_index)

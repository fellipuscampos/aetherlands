class_name LoadingScreen
extends Control

## Pedido do usuario: "ta tendo um certo delay ao dar play, acho que a
## geração do mapa ta demorando um pouco, vamos colocar uma tela de
## loading, igual o civilization tem enquanto carrega o mapa, pra nao
## parecer que travou". HexGrid.generate_map() e sincrono e pesado (mapa
## Grande = 320x84 = 26880 tiles, varias passadas de suavizacao +
## reconstrucao de multimesh/props/overlay) — isto NAO elimina o
## travamento em si (Godot nao deixa mexer em Node/MultiMesh fora da
## thread principal sem cuidado extra, fora de escopo aqui), so garante
## que esta tela CHEGA a ser desenhada (via `await get_tree().
## process_frame` em Main.gd, ver _show_loading_screen) antes do trabalho
## pesado comecar — troca "a tela anterior parada sem explicacao nenhuma"
## por um feedback visual explicito de que o jogo esta ocupado, nao
## travado. Mesmo padrao "tela cheia" de TitleScreen/GameSetupScreen
## (Control root com tema proprio via UITheme.build()).

@onready var title_label: Label = $CenterBox/Box/TitleLabel

func _ready() -> void:
	theme = UITheme.build()

## "Gerando o Mapa..." (jogo novo) ou "Carregando Partida..." (load) — a
## mesma tela serve pros dois casos, ambos passam por HexGrid.
## generate_map() (ver SaveManager.load_game), so o texto muda.
func set_message(text: String) -> void:
	title_label.text = text

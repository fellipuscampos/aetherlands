class_name MenuPager
extends RefCounted

## Navegacao de paginas compartilhada entre TitleScreen e PauseMenu --
## Roadmap "sistema de menu de jogo moderno" (pedido do usuario: "o menu
## ter sistema de paginas... poder navegar indo e voltando entre paginas").
## RefCounted (composicao), nao uma classe base pra TitleScreen/PauseMenu
## herdarem -- os dois scripts ja tem comportamento proprio nao relacionado
## demais (input de ESC, delegacao pra HUD) pra justificar forcar uma base
## comum so por causa disto; cada um so cria um MenuPager.new(...) no
## proprio _ready(), mesmo espirito de UITheme (RefCounted de metodos
## estaticos) sendo composicao em vez de heranca.

var _pages: Array[Control] = []
var _current: Control
var _stack: Array[Control] = []

func _init(pages: Array[Control]) -> void:
	_pages = pages
	for p in _pages:
		p.visible = false

## Mostra `page`, empilhando a pagina atual (se houver) pra back() poder
## voltar pra ela depois.
func go_to(page: Control) -> void:
	if _current != null and _current != page:
		_stack.push_back(_current)
	_show_only(page)

## Volta pra ultima pagina empilhada. No-op se a pilha estiver vazia (ja
## esta na pagina raiz).
func back() -> void:
	if _stack.is_empty():
		return
	_show_only(_stack.pop_back())

## Limpa a pilha inteira e mostra so `page` -- usado por PauseMenu.open()
## toda vez que a pausa REABRE, pra nunca reabrir no meio de Configuracoes/
## Carregar Jogo de uma sessao de pausa anterior.
func reset_to(page: Control) -> void:
	_stack.clear()
	_show_only(page)

func current() -> Control:
	return _current

func _show_only(page: Control) -> void:
	for p in _pages:
		p.visible = (p == page)
	_current = page

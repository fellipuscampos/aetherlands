extends GutTest

## Cobre MenuPager.gd — Roadmap "sistema de menu de jogo moderno" (pedido
## do usuario: "o menu ter sistema de paginas... poder navegar indo e
## voltando entre paginas"). Testado isolado com 3 Controls quaisquer (nao
## precisa de TitleScreen/PauseMenu reais) — TitleScreen/PauseMenu so
## delegam pra este helper, ver test_title_screen.gd/test_pause_menu.gd
## pra cobertura de integracao.

var page_a: Control
var page_b: Control
var page_c: Control

func before_each():
	page_a = Control.new()
	page_b = Control.new()
	page_c = Control.new()
	add_child_autofree(page_a)
	add_child_autofree(page_b)
	add_child_autofree(page_c)

func test_init_hides_every_page():
	MenuPager.new([page_a, page_b, page_c])

	assert_false(page_a.visible)
	assert_false(page_b.visible)
	assert_false(page_c.visible)

func test_go_to_shows_only_the_target_page():
	var pager := MenuPager.new([page_a, page_b, page_c])

	pager.go_to(page_b)

	assert_false(page_a.visible)
	assert_true(page_b.visible)
	assert_false(page_c.visible)
	assert_eq(pager.current(), page_b)

func test_back_returns_to_the_previous_page():
	var pager := MenuPager.new([page_a, page_b, page_c])
	pager.go_to(page_a)
	pager.go_to(page_b)

	pager.back()

	assert_eq(pager.current(), page_a)
	assert_true(page_a.visible)
	assert_false(page_b.visible)

func test_back_with_nothing_on_the_stack_is_a_no_op():
	var pager := MenuPager.new([page_a, page_b, page_c])
	pager.go_to(page_a)

	pager.back()

	assert_eq(pager.current(), page_a)

func test_reset_to_clears_the_whole_stack():
	var pager := MenuPager.new([page_a, page_b, page_c])
	pager.go_to(page_a)
	pager.go_to(page_b)
	pager.go_to(page_c)

	pager.reset_to(page_a)
	pager.back() # nao deveria ter mais nada empilhado

	assert_eq(pager.current(), page_a)

@tool
class_name AetherlandsTheme
extends Theme

## Script do recurso real `aetherlands_theme.tres`. O recurso e carregavel no
## editor e em runtime, enquanto a configuracao continua em uma fonte unica
## testavel (UITheme.configure).
func _init() -> void:
	UITheme.configure(self)

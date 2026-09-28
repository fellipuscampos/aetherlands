class_name UIFormat
extends RefCounted

## Formatação player-facing compartilhada. Mantém o cálculo intacto e elimina
## artefatos de ponto flutuante como "-0" na apresentação estratégica.

static func number(value: float, decimals: int = 0) -> String:
	var scale := pow(10.0, maxi(decimals, 0))
	var rounded := roundf(value * scale) / scale
	var normalized := 0.0 if is_zero_approx(rounded) else rounded
	if decimals <= 0 or is_equal_approx(normalized, roundf(normalized)):
		return str(int(roundf(normalized)))
	return ("%%.%df" % decimals) % normalized

static func delta(value: float, decimals: int = 0) -> String:
	var scale := pow(10.0, maxi(decimals, 0))
	var rounded := roundf(value * scale) / scale
	var normalized := 0.0 if is_zero_approx(rounded) else rounded
	if is_zero_approx(normalized):
		return "0"
	var rendered := number(absf(normalized), decimals)
	return ("+" if normalized > 0.0 else "-") + rendered

class_name PoseCaptureTransition
extends RefCounted

## TRANSIÇÃO POR CAPTURA DE POSE entre os estados de uma unidade (parado -> andar, parado -> conjurar, conjurar ->
## parado...), usada pelas Grandes Manifestações (UnitData.pose_transition_time). Em vez do crossfade linear entre dois
## clipes (UnitData.animation_blend_time), a troca parte da pose em que o esqueleto ESTÁ naquele instante — inclusive no
## meio de outra transição — e chega ao clipe novo com curva seno (acelera e desacelera), enquanto o clipe novo já
## corre. Por isso nunca há salto de pose, mesmo interrompendo um gesto ou conjurando duas vezes seguidas.
##
## Como: as trilhas 3D dos ossos (posição/rotação/escala) viram trilhas de VALOR sobre as mesmas propriedades do
## Skeleton3D, em modo "capture" — é o que `AnimationPlayer.play_with_capture` sabe misturar a partir do valor atual. As
## trilhas de valor que o modelo já traz (emissão do núcleo do Primordial) entram no mesmo modo. Os clipes são COPIADOS:
## a biblioteca importada do GLB fica intacta (outras unidades do mesmo modelo têm a própria cópia).
## Nasceu como ElementalSerpentTransition, só para o Primordial dos Elementos (2026-10-12); generalizada em 2026-10-13.
var _player: AnimationPlayer

func setup(player: AnimationPlayer, skeleton: Skeleton3D) -> void:
	_player = player
	_player.playback_auto_capture = false
	var library := AnimationLibrary.new()
	for name in player.get_animation_library("").get_animation_list():
		var original := player.get_animation(name)
		var animation := original.duplicate() as Animation
		for track in range(original.get_track_count() - 1, -1, -1):
			var kind := original.track_get_type(track)
			if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				if kind == Animation.TYPE_VALUE:
					animation.value_track_set_update_mode(track, Animation.UPDATE_CAPTURE)
				continue
			var path := original.track_get_path(track)
			if path.get_subname_count() == 0:
				continue
			var bone := skeleton.find_bone(path.get_subname(0))
			if bone < 0:
				continue
			var property := "position" if kind == Animation.TYPE_POSITION_3D else ("rotation" if kind == Animation.TYPE_ROTATION_3D else "scale")
			animation.remove_track(track)
			var replacement := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(replacement, NodePath(str(path.get_concatenated_names()) + ":bones/%d/%s" % [bone, property]))
			animation.value_track_set_update_mode(replacement, Animation.UPDATE_CAPTURE)
			for key in original.track_get_key_count(track):
				animation.track_insert_key(replacement, original.track_get_key_time(track, key), original.track_get_key_value(track, key))
		library.add_animation(name, animation)
	player.remove_animation_library("")
	player.add_animation_library("", library)
	player.playback_default_blend_time = 0.0

## Toca `clip` chegando nele em `seconds` a partir da pose atual. `restart` recomeça um clipe que já está tocando
## (dois feitiços seguidos).
func play(clip: String, seconds: float, restart: bool = false) -> void:
	_player.play_with_capture(clip, seconds, 0.0, 1.0, false, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	if restart:
		_player.seek(0.0, false)

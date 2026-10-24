class_name FearSource
extends Node3D
## Aumenta o medo do jogador só por ele estar perto (sem susto nenhum).
## Quanto mais perto, mais rápido o coração dispara.

## Distância em que o medo começa a subir.
@export var radius: float = 4.5
## Medo por segundo quando o jogador está colado.
@export var fear_per_second: float = 0.35
## Se true, o jogador precisa estar olhando pra cá pra contar.
@export var requires_sight: bool = false

var _player: Player


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	if not is_visible_in_tree():
		return
	var dist := _player.global_position.distance_to(global_position)
	if dist > radius:
		return
	if requires_sight and not _player.camera.is_position_in_frustum(global_position + Vector3.UP):
		return
	var closeness := 1.0 - dist / radius
	_player.add_fear(fear_per_second * closeness * closeness * delta)

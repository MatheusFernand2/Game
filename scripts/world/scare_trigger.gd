class_name ScareTrigger
extends Area3D
## Área invisível que dispara um evento quando o jogador entra.

signal triggered(player: Player)

@export var one_shot: bool = true

var _fired := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _fired and one_shot:
		return
	if body is Player:
		_fired = true
		triggered.emit(body as Player)

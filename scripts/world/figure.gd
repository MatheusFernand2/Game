class_name Figure
extends Node3D
## A "Coisa": silhueta alta e magra. Por enquanto só aparece e some
## (sustos roteirizados). Depois vira o monstro com IA que caça o jogador.

@onready var head: Node3D = $Head
@onready var rim_light: OmniLight3D = $RimLight

var _t := 0.0
var _twitch := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	visible = false
	rim_light.visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# Cabeça "estalando" de vez em quando — nada humano.
	if _rng.randf() < delta * 2.5:
		_twitch = _rng.randf_range(-0.6, 0.6)
	head.rotation.z = lerpf(head.rotation.z, _twitch, clampf(delta * 25.0, 0.0, 1.0))
	head.rotation.x = sin(_t * 1.3) * 0.05


## Aparece em 'pos' olhando pra 'look_target'. lit = luz fria embaixo dela.
func appear(pos: Vector3, look_target: Node3D = null, lit: bool = false) -> void:
	global_position = pos
	if look_target:
		var target := look_target.global_position
		target.y = global_position.y
		if target.distance_to(global_position) > 0.01:
			look_at(target, Vector3.UP)
	rim_light.visible = lit
	visible = true


func vanish() -> void:
	visible = false
	rim_light.visible = false

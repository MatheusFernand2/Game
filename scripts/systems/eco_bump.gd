class_name EcoBump
extends Node3D
## A trombada: o jogador vem correndo, vira a câmera pra trás de uma vez e
## um Eco vem correndo e tromba com ele. Atordoa ~3 s e some.
## Acontece no MÁXIMO 2 vezes no jogo inteiro (contado em Game.eco_bumps_done),
## e nunca duas vezes em menos de 10 minutos.

const MAX_BUMPS := 2

@export var impact_sound: AudioStream
@export var ring_sound: AudioStream
## Quanto tempo correndo antes de poder acontecer.
@export var min_sprint_time: float = 5.0
## Quanto o jogador precisa virar (graus) em pouco tempo.
@export var min_turn_degrees: float = 120.0
@export var turn_window: float = 0.35
@export var cooldown: float = 600.0
## Chance de acontecer quando as condições batem (pra não ser previsível).
@export var chance: float = 0.7
@export var stun_time: float = 3.0

## A fase liga/desliga (desligado em cenas roteirizadas e na perseguição).
var enabled := false

var _player: Player
var _yaw_history: Array = []  # [[tempo, yaw], ...]
var _time := 0.0
var _cooldown_left := 0.0
var _busy := false
var _eco: EcoRig


func _ready() -> void:
	_eco = EcoRig.new()
	_eco.pose = EcoRig.Pose.RUN
	_eco.cycle_speed = 2.8
	_eco.visible = false
	add_child(_eco)
	_eco.top_level = true


func _process(delta: float) -> void:
	_time += delta
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var yaw := _player.global_rotation.y
	_yaw_history.append([_time, yaw])
	while not _yaw_history.is_empty() and _time - float(_yaw_history[0][0]) > turn_window:
		_yaw_history.pop_front()

	if not enabled or _busy or _cooldown_left > 0.0 or Game.eco_bumps_done >= MAX_BUMPS:
		return
	if not _player.controls_enabled or _player.is_stunned():
		return
	if _player.sprint_time < min_sprint_time or _yaw_history.is_empty():
		return
	var turned := absf(rad_to_deg(angle_difference(float(_yaw_history[0][1]), yaw)))
	if turned < min_turn_degrees:
		return
	_yaw_history.clear()
	if randf() > chance:
		_cooldown_left = 20.0
		return
	_do_bump()


func _do_bump() -> void:
	_busy = true
	Game.eco_bumps_done += 1
	_cooldown_left = cooldown

	var forward := _player.view_forward()
	forward.y = 0.0
	forward = forward.normalized()
	var start_dist := _free_distance(forward, 4.5)
	var start := _player.global_position + forward * start_dist
	_eco.global_position = start
	_eco.look_at(Vector3(_player.global_position.x, start.y, _player.global_position.z), Vector3.UP)
	_eco.animate = true
	_eco.visible = true

	# Vem MUITO rápido (~0,35 s até bater).
	var hit_point := _player.global_position + forward * 0.5
	var tw := create_tween()
	tw.tween_property(_eco, "global_position", hit_point, start_dist / 12.0)
	await tw.finished

	_eco.visible = false
	_eco.animate = false
	if impact_sound:
		Game.play_sound_2d(impact_sound, 2.0)
	if ring_sound:
		Game.play_sound_2d(ring_sound, -6.0)
	_player.add_fear(0.6)
	var post := _player.get_node_or_null("PostFX")
	if post and post.has_method("glitch"):
		post.call("glitch", 0.5)
	await _player.stun(stun_time)
	_busy = false


func _free_distance(direction: Vector3, wanted: float) -> float:
	var from := _player.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * wanted)
	query.exclude = [_player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return wanted
	return maxf(from.distance_to(hit["position"]) - 0.4, 1.6)

class_name Door
extends Node3D
## Porta que abre pra longe do jogador, range, pode estar trancada
## e pode BATER sozinha (susto).

@export var open_angle: float = 100.0
@export var open_time: float = 1.1
@export var locked: bool = false
@export_multiline var locked_message: String = "Trancada."
@export var creak_sound: AudioStream
@export var slam_sound: AudioStream
@export var locked_sound: AudioStream

@onready var hinge: Node3D = $Hinge
@onready var sfx: AudioStreamPlayer3D = $Sfx

var is_open := false
var _busy := false
var _tween: Tween


func get_interact_text() -> String:
	if locked:
		return "[E] Porta"
	return "[E] Fechar" if is_open else "[E] Abrir"


func interact(player: Node3D) -> void:
	if _busy:
		return
	if locked:
		_play(locked_sound, -4.0, randf_range(0.9, 1.1))
		var hud := player.get_node_or_null("HUD")
		if hud and hud.has_method("show_subtitle"):
			hud.call("show_subtitle", locked_message, 2.5)
		return
	if is_open:
		close()
	else:
		open_away_from(player.global_position)


func open_away_from(from_position: Vector3) -> void:
	# Lado do jogador em relação à porta (eixo Z local).
	var local := to_local(from_position)
	var side := -1.0 if local.z > 0.0 else 1.0
	_rotate_to(open_angle * side, open_time, Tween.EASE_IN_OUT)
	is_open = true
	_play(creak_sound, -6.0, randf_range(0.85, 1.05))


func close() -> void:
	_rotate_to(0.0, open_time * 0.9, Tween.EASE_IN_OUT)
	is_open = false
	_play(creak_sound, -8.0, randf_range(1.0, 1.15))


## Fecha com tudo. Use em sustos.
func slam() -> void:
	_rotate_to(0.0, 0.18, Tween.EASE_IN)
	is_open = false
	_play(slam_sound, 4.0, randf_range(0.95, 1.05))


## Abre devagarinho sozinha... (rangendo). Use em sustos.
func creep_open(angle: float = 35.0, duration: float = 4.0) -> void:
	_rotate_to(angle, duration, Tween.EASE_OUT)
	is_open = true
	_play(creak_sound, -2.0, 0.7)


func _rotate_to(angle_deg: float, duration: float, ease_type: Tween.EaseType) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_busy = true
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	_tween.tween_property(hinge, "rotation_degrees:y", angle_deg, duration)
	_tween.finished.connect(func() -> void: _busy = false)


func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if stream == null:
		return
	sfx.stream = stream
	sfx.volume_db = volume_db
	sfx.pitch_scale = pitch
	sfx.play()

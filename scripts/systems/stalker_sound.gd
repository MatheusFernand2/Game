class_name StalkerSound
extends Node3D
## "Tem alguma coisa andando no mato do meu lado."
## Um barulho de mato que acompanha o jogador pela lateral: anda quando ele
## anda e PARA quando ele para. Depois de uns segundos parado, um galho estala.

@export var rustle_sound: AudioStream
@export var crack_sound: AudioStream
## Distância lateral do jogador, em metros.
@export var side_distance: float = 9.0
## 1 = direita, -1 = esquerda.
@export var side: float = 1.0

var active := false:
	set(value):
		active = value
		if not value and _player_audio:
			_player_audio.stop()

var _player: Player
var _player_audio: AudioStreamPlayer3D
var _still_time := 0.0
var _cracked := false
var _pos := Vector3.ZERO


func _ready() -> void:
	_player_audio = AudioStreamPlayer3D.new()
	_player_audio.unit_size = 6.0
	_player_audio.max_distance = 40.0
	_player_audio.volume_db = -4.0
	add_child(_player_audio)


func _process(delta: float) -> void:
	if not active:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
		_pos = _target_pos()
	var moving := Vector2(_player.velocity.x, _player.velocity.z).length() > 0.6
	_pos = _pos.lerp(_target_pos(), clampf(delta * (1.5 if moving else 0.0), 0.0, 1.0))
	global_position = _pos
	if moving:
		_still_time = 0.0
		_cracked = false
		if not _player_audio.playing and rustle_sound:
			_player_audio.stream = rustle_sound
			_player_audio.pitch_scale = randf_range(0.8, 1.0)
			_player_audio.play()
	else:
		_still_time += delta
		# Para junto com o jogador (com um atraso minúsculo, que é o que assusta).
		if _still_time > 0.25 and _player_audio.playing and _player_audio.stream == rustle_sound:
			_player_audio.stop()
		if _still_time > 3.5 and not _cracked and crack_sound:
			_cracked = true
			_player_audio.stream = crack_sound
			_player_audio.pitch_scale = 0.9
			_player_audio.play()
			_player.add_fear(0.12)


func _target_pos() -> Vector3:
	var right := _player.global_basis.x
	right.y = 0.0
	right = right.normalized()
	return _player.global_position + right * side_distance * side + Vector3.UP * 0.5

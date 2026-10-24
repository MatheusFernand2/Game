class_name FlickerLight
extends OmniLight3D
## Lâmpada que pisca, chia e pode "morrer" (estourar) num susto.

enum Mode { STEADY, OCCASIONAL, HEAVY }

@export var base_energy: float = 1.0
@export var mode: Mode = Mode.OCCASIONAL
@export var buzz_sound: AudioStream
@export var buzz_volume_db: float = -16.0
@export var pop_sound: AudioStream
## MeshInstance3D da lâmpada (o brilho dela acompanha a luz).
@export var bulb: MeshInstance3D

var dead := false
var _flicker_time := 0.0
var _burst_time := 0.0
var _buzz: AudioStreamPlayer3D
var _bulb_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	light_energy = base_energy
	if bulb and bulb.get_surface_override_material(0) is StandardMaterial3D:
		_bulb_mat = (bulb.get_surface_override_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		bulb.set_surface_override_material(0, _bulb_mat)
	if buzz_sound:
		_buzz = AudioStreamPlayer3D.new()
		_buzz.stream = buzz_sound
		_buzz.volume_db = buzz_volume_db
		_buzz.unit_size = 2.0
		_buzz.max_distance = 14.0
		add_child(_buzz)
		_buzz.play()
		_buzz.finished.connect(_buzz.play)


func _process(delta: float) -> void:
	var e := base_energy
	if dead:
		e = 0.0
	else:
		if _flicker_time > 0.0:
			_flicker_time -= delta
			e *= 1.0 if _rng.randf() > 0.5 else _rng.randf_range(0.0, 0.2)
		else:
			match mode:
				Mode.OCCASIONAL:
					if _burst_time <= 0.0 and _rng.randf() < delta * 0.25:
						_burst_time = _rng.randf_range(0.1, 0.6)
				Mode.HEAVY:
					if _burst_time <= 0.0 and _rng.randf() < delta * 1.5:
						_burst_time = _rng.randf_range(0.1, 0.9)
			if _burst_time > 0.0:
				_burst_time -= delta
				e *= 1.0 if _rng.randf() > 0.4 else _rng.randf_range(0.0, 0.25)
	light_energy = e
	var level := e / maxf(base_energy, 0.001)
	if _bulb_mat:
		_bulb_mat.emission_energy_multiplier = level * 3.0
	if _buzz:
		_buzz.volume_db = buzz_volume_db + linear_to_db(clampf(level, 0.02, 1.0)) * 0.5
		if dead and _buzz.playing:
			_buzz.stop()


## Pisca forte por alguns segundos.
func flicker(duration: float) -> void:
	_flicker_time = maxf(_flicker_time, duration)


## Estoura a lâmpada: apaga de vez.
func kill() -> void:
	if dead:
		return
	dead = true
	if pop_sound:
		Game.play_sound_at(pop_sound, global_position, 0.0)


## Volta a acender (mais fraca, se quiser).
func restore(energy_multiplier: float = 1.0, new_mode: Mode = Mode.HEAVY) -> void:
	dead = false
	base_energy *= energy_multiplier
	mode = new_mode
	if _buzz and not _buzz.playing:
		_buzz.play()

class_name CoisaFunda
extends Node3D
## O monstro de verdade. De quatro, grande, quase invisível no escuro.
## - Persegue seguindo o rastro do jogador (assim não atravessa árvore).
## - A luz da lanterna segura ela: fica lenta, chia e recua.
## - Se alcançar, emite `caught` (quem decide o que acontece é a fase —
##   ninguém morre neste jogo).

signal caught(player: Player)
signal lit_by_flashlight

@export var base_speed: float = 2.7
## Velocidade quando o jogador está longe demais (pra pressão não acabar).
@export var catchup_speed: float = 4.4
## Velocidade do bote final.
@export var lunge_speed: float = 3.3
@export var lit_speed: float = 0.4
@export var catch_distance: float = 1.6
@export var step_sounds: Array[AudioStream] = []
@export var hiss_sound: AudioStream
@export_group("Modelo")
## Modelo animado de quatro patas (ex.: Wolf.gltf). Sem ele, usa o corpo procedural.
@export var model_scene: PackedScene
@export var model_scale: float = 0.47
## Estica o modelo: pernas compridas e corpo magro deixam ele "errado".
@export var model_stretch := Vector3(0.75, 1.35, 1.05)
@export var skin_color := Color(0.015, 0.014, 0.016)
## Brilho dos olhos quando a luz bate (reflexo de bicho no escuro).
@export var eye_color := Color(0.9, 0.85, 0.6)

@onready var rig: EcoRig = $Rig
@onready var breath: AudioStreamPlayer3D = $Breath
@onready var steps: AudioStreamPlayer3D = $Steps

var chasing := false
var _player: Player
var _trail: Array[Vector3] = []
var _trail_timer := 0.0
var _speed := 0.0
var _last_step_phase := 0.0
var _hiss_cooldown := 0.0
var _lit_time := 0.0
var _rng := RandomNumberGenerator.new()
var _model: Node3D
var _anim: AnimationPlayer
var _step_timer := 0.0


func _ready() -> void:
	_rng.randomize()
	_setup_model()
	visible = false
	set_physics_process(false)
	breath.stop()


## Começa a caçar o jogador a partir de onde ela está agora.
func start_chase(player: Player) -> void:
	_player = player
	_trail.clear()
	_trail.append(player.global_position)
	chasing = true
	visible = true
	rig.animate = _model == null
	set_physics_process(true)
	breath.play()


func stop_chase() -> void:
	chasing = false
	visible = false
	rig.animate = false
	set_physics_process(false)
	breath.stop()


## Distância até o jogador (INF se não está caçando).
func distance_to_player() -> float:
	if _player == null or not chasing:
		return INF
	return global_position.distance_to(_player.global_position)


func _physics_process(delta: float) -> void:
	if not chasing or _player == null:
		return
	_hiss_cooldown = maxf(_hiss_cooldown - delta, 0.0)

	# Rastro do jogador.
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.25
		var last: Vector3 = _trail.back() if not _trail.is_empty() else global_position
		if last.distance_to(_player.global_position) > 0.8:
			_trail.append(_player.global_position)

	var to_player := _player.global_position - global_position
	var dist := Vector2(to_player.x, to_player.z).length()

	# Alvo: o jogador direto se dá pra ver, senão o próximo ponto do rastro.
	var target := _player.global_position
	var direct := dist <= 6.0 and _clear_line_to(_player.global_position)
	if direct:
		# Caçando direto: o rastro antigo não serve mais.
		_trail.clear()
		_trail.append(_player.global_position)
	else:
		while _trail.size() > 1 and Vector2(_trail[0].x - global_position.x, _trail[0].z - global_position.z).length() < 0.7:
			_trail.pop_front()
		if not _trail.is_empty():
			target = _trail[0]

	# Velocidade.
	var chest := global_position + Vector3.UP * 1.1
	var lit := _player.is_point_lit(chest, 14.0)
	var wanted := base_speed
	if lit:
		_lit_time += delta
		wanted = lit_speed
		if _hiss_cooldown <= 0.0:
			_hiss_cooldown = 3.0
			lit_by_flashlight.emit()
			if hiss_sound:
				Game.play_sound_at(hiss_sound, chest, 4.0, _rng.randf_range(0.9, 1.05))
			_player.add_fear(0.15)
	else:
		_lit_time = 0.0
		if dist > 22.0:
			wanted = catchup_speed
		elif dist < 6.0:
			wanted = lunge_speed
	_speed = lerpf(_speed, wanted, clampf(delta * (6.0 if lit else 2.0), 0.0, 1.0))

	# Andar.
	var to_target := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var target_dist := to_target.length()
	if target_dist > 0.05:
		var move := to_target / target_dist * minf(_speed * delta, target_dist)
		# Na luz ela recua um pouco em vez de só parar.
		if lit and _lit_time > 0.4:
			move = -Vector3(to_player.x, 0.0, to_player.z).normalized() * 0.8 * delta
		global_position += move
		var face_dir := Vector3(to_player.x, 0.0, to_player.z) if dist < 8.0 else to_target
		if face_dir.length_squared() > 0.001:
			var desired := Basis.looking_at(face_dir.normalized(), Vector3.UP)
			global_basis = global_basis.slerp(desired, clampf(delta * 6.0, 0.0, 1.0)).orthonormalized()
	global_position.y = lerpf(global_position.y, _ground_height(global_position), clampf(delta * 10.0, 0.0, 1.0))

	# Animação e passos acompanham a velocidade.
	if _model:
		if lit:
			ModelUtil.play(_anim, "Idle_HitReact1" if _lit_time < 0.6 else "Idle_2_HeadLow", 0.15)
		elif _speed > 3.2:
			ModelUtil.play(_anim, "Gallop", 0.25, clampf(_speed / 4.0, 0.7, 1.3))
		else:
			ModelUtil.play(_anim, "Walk", 0.25, clampf(_speed / 1.8, 0.6, 1.6))
		_step_timer -= delta
		if _step_timer <= 0.0 and _speed > 0.5:
			_step_timer = clampf(1.1 / _speed, 0.18, 0.9)
			_play_step()
	else:
		rig.cycle_speed = 0.35 + _speed * 0.32
		var step_phase := floorf(rig.phase * 2.0)
		if step_phase != _last_step_phase:
			_last_step_phase = step_phase
			_play_step()

	if dist < catch_distance and not _player.is_stunned():
		caught.emit(_player)


func _clear_line_to(point: Vector3) -> bool:
	var from := global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, point + Vector3.UP * 1.0)
	if _player:
		query.exclude = [_player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _ground_height(p: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 8.0)
	if _player:
		query.exclude = [_player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return p.y
	return (hit["position"] as Vector3).y


func _play_step() -> void:
	if step_sounds.is_empty():
		return
	steps.stream = step_sounds[_rng.randi() % step_sounds.size()]
	steps.pitch_scale = _rng.randf_range(0.85, 1.05)
	steps.volume_db = lerpf(-10.0, 2.0, clampf(_speed / catchup_speed, 0.0, 1.0))
	steps.play()


func _setup_model() -> void:
	if model_scene == null:
		return
	rig.visible = false
	rig.animate = false
	_model = model_scene.instantiate() as Node3D
	# O modelo olha pra +Z; o jogo usa -Z como frente.
	_model.rotation.y = PI
	_model.scale = model_stretch * model_scale
	add_child(_model)
	_anim = ModelUtil.find_animation_player(_model)
	ModelUtil.set_loops(_anim, PackedStringArray(["Walk", "Gallop", "Idle", "Idle_2_HeadLow"]))
	ModelUtil.play(_anim, "Idle", 0.0)

	var skin := StandardMaterial3D.new()
	skin.albedo_color = skin_color
	skin.roughness = 0.85
	skin.rim_enabled = true
	skin.rim = 0.25
	skin.rim_tint = 0.8
	var eyes := StandardMaterial3D.new()
	eyes.albedo_color = eye_color
	eyes.emission_enabled = true
	eyes.emission = eye_color
	eyes.emission_energy_multiplier = 0.6
	for mi in ModelUtil.find_meshes(_model):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var mat_name := m.resource_name.to_lower() if m else ""
			mi.set_surface_override_material(i, eyes if mat_name.contains("eye") else skin)

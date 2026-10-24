class_name Player
extends CharacterBody3D
## Jogador em primeira pessoa: anda, corre (com fôlego), agacha, usa lanterna
## e interage. Não luta — só foge e se esconde.

signal fear_changed(value: float)
signal battery_changed(percent: float)
signal interact_prompt_changed(text: String)
signal watch_requested

@export_group("Movimento")
@export var walk_speed: float = 2.0
@export var sprint_speed: float = 3.9
@export var crouch_speed: float = 1.0
@export var acceleration: float = 9.0
@export var friction: float = 12.0
@export var gravity: float = 18.0

@export_group("Fôlego")
## Segundos de corrida com fôlego cheio.
@export var stamina_max: float = 5.0
@export var stamina_regen_per_sec: float = 0.7

@export_group("Altura")
@export var stand_height: float = 1.75
@export var crouch_height: float = 1.0
@export var eye_offset: float = 0.12

@export_group("Lanterna")
@export var flashlight_energy: float = 3.2
## Quanto da bateria (0-100) gasta por segundo ligada.
@export var battery_drain_per_sec: float = 0.25
@export var low_battery_threshold: float = 20.0

@export_group("Sons")
@export var footstep_sounds: Array[AudioStream] = []
@export var flashlight_click: AudioStream
@export var breathing_loop: AudioStream
@export var heartbeat_loop: AudioStream

@onready var collision: CollisionShape3D = $Collision
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var interact_ray: RayCast3D = $Head/Camera/InteractRay
@onready var flashlight_pivot: Node3D = $FlashlightPivot
@onready var flashlight: SpotLight3D = $FlashlightPivot/Flashlight
@onready var footstep_player: AudioStreamPlayer3D = $FootstepPlayer
@onready var breath_player: AudioStreamPlayer = $BreathPlayer
@onready var heart_player: AudioStreamPlayer = $HeartPlayer

var stamina: float
var exhausted := false
var is_crouching := false
var battery: float = 100.0
var flashlight_on := true
## Medo de 0 a 1. Sobe com sustos, desce sozinho com o tempo.
var fear: float = 0.0
## Quando false, o jogador não se mexe nem olha (cutscenes, sustos travados).
var controls_enabled := true:
	set(value):
		controls_enabled = value
		_controls_change_id += 1
## Multiplica todas as velocidades (ex.: 0.6 mancando).
var speed_multiplier := 1.0
## Impede correr (perna machucada, por exemplo).
var sprint_locked := false
## 0..1 — balanço torto de quem está mancando.
var limp_amount := 0.0
## Altura forçada dos olhos (deitado, caído). Negativo = normal.
var forced_eye_height := -1.0
## Inclinação lateral da câmera em graus (caído no chão, tontura).
var camera_roll_target := 0.0
## Segundos seguidos correndo (usado pela trombada do Eco).
var sprint_time := 0.0

var _current_height: float
var _bob_time := 0.0
var _step_distance := 0.0
var _shake_strength := 0.0
var _shake_time := 0.0
var _forced_flicker_time := 0.0
var _base_fov: float
var _current_interactable: Node = null
var _last_prompt := ""
var _pitch := 0.0
var _rng := RandomNumberGenerator.new()
var _eye_y := 1.63
var _step_count := 0
var _stunned := false
var _controls_change_id := 0


func _ready() -> void:
	add_to_group("player")
	_rng.randomize()
	stamina = stamina_max
	_current_height = stand_height
	_eye_y = stand_height - eye_offset
	_base_fov = camera.fov
	flashlight_pivot.top_level = true
	interact_ray.add_exception(self)
	flashlight.light_energy = flashlight_energy
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_loop(breath_player, breathing_loop)
	_setup_loop(heart_player, heartbeat_loop)
	battery_changed.emit(battery)


func _setup_loop(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if stream == null:
		return
	player.stream = stream
	player.volume_db = -60.0
	player.play()
	# Garante loop mesmo se o WAV não tiver ponto de loop.
	player.finished.connect(player.play)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var invert := -1.0 if Game.invert_y else 1.0
		rotate_y(deg_to_rad(-motion.relative.x * Game.mouse_sensitivity))
		_pitch = clampf(_pitch - motion.relative.y * Game.mouse_sensitivity * invert, -85.0, 85.0)
		head.rotation_degrees.x = _pitch
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("interact"):
		if _current_interactable != null:
			_current_interactable.call("interact", self)
	elif event.is_action_pressed("watch"):
		watch_requested.emit()


func _physics_process(delta: float) -> void:
	_update_crouch(delta)
	_update_movement(delta)
	_update_interaction()


func _process(delta: float) -> void:
	_update_camera_effects(delta)
	_update_flashlight(delta)
	_update_fear_audio(delta)


# ---------------------------------------------------------------- movimento

func _update_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Vector2.ZERO
	if controls_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var wants_sprint := controls_enabled and Input.is_action_pressed("sprint") \
		and input_dir.y < 0.0 and not is_crouching and not exhausted and not sprint_locked
	var target_speed := walk_speed
	if is_crouching:
		target_speed = crouch_speed
	elif wants_sprint:
		target_speed = sprint_speed
	target_speed *= speed_multiplier

	# Fôlego
	if wants_sprint and direction != Vector3.ZERO:
		stamina = maxf(stamina - delta, 0.0)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(stamina + stamina_regen_per_sec * delta, stamina_max)
		if exhausted and stamina > stamina_max * 0.45:
			exhausted = false

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if direction != Vector3.ZERO:
		horizontal = horizontal.lerp(direction * target_speed, clampf(acceleration * delta, 0.0, 1.0))
	else:
		horizontal = horizontal.lerp(Vector3.ZERO, clampf(friction * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	# Passos
	var speed := Vector2(velocity.x, velocity.z).length()
	if wants_sprint and speed > walk_speed + 0.5:
		sprint_time += delta
	else:
		sprint_time = 0.0
	if is_on_floor() and speed > 0.3:
		_step_distance += speed * delta
		var stride := 0.75
		if is_crouching:
			stride = 0.6
		elif speed > walk_speed + 0.5:
			stride = 0.95
		if _step_distance >= stride:
			_step_distance = 0.0
			_step_count += 1
			_play_footstep(speed)
		_bob_time += delta * speed * 2.6
	else:
		_step_distance = 0.6


func _play_footstep(speed: float) -> void:
	if footstep_sounds.is_empty():
		return
	footstep_player.stream = footstep_sounds[_rng.randi() % footstep_sounds.size()]
	footstep_player.pitch_scale = _rng.randf_range(0.88, 1.08)
	var vol := -14.0
	if is_crouching:
		vol = -24.0
	elif speed > walk_speed + 0.5:
		vol = -7.0
	footstep_player.volume_db = vol
	footstep_player.play()


func _update_crouch(delta: float) -> void:
	var wants_crouch := controls_enabled and Input.is_action_pressed("crouch")
	if wants_crouch:
		is_crouching = true
	elif is_crouching and _can_stand_up():
		is_crouching = false

	var target := crouch_height if is_crouching else stand_height
	_current_height = lerpf(_current_height, target, clampf(10.0 * delta, 0.0, 1.0))
	var capsule := collision.shape as CapsuleShape3D
	capsule.height = _current_height
	collision.position.y = _current_height * 0.5


func _can_stand_up() -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * (_current_height - 0.05),
		global_position + Vector3.UP * (stand_height + 0.1))
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


# ---------------------------------------------------------------- câmera

func _update_camera_effects(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var bob_amount := clampf(speed / sprint_speed, 0.0, 1.0)
	var bob := Vector3(
		cos(_bob_time * 0.5) * 0.035 * bob_amount,
		sin(_bob_time) * 0.045 * bob_amount,
		0.0)

	# Tremor (sustos) + leve tremor constante quando o medo está alto.
	var shake_offset := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		shake_offset = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0.0) * _shake_strength
	shake_offset += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0.0) * fear * 0.004

	# Mancando: um passo afunda mais que o outro.
	if limp_amount > 0.0 and speed > 0.3:
		var dip := absf(sin(_bob_time * 0.5)) if _step_count % 2 == 0 else 0.0
		bob.y -= dip * 0.09 * limp_amount
		bob.x += sin(_bob_time * 0.5) * 0.02 * limp_amount

	var target_eye := _current_height - eye_offset
	if forced_eye_height >= 0.0:
		target_eye = forced_eye_height
	_eye_y = lerpf(_eye_y, target_eye, clampf(6.0 * delta, 0.0, 1.0))
	head.position = Vector3(0.0, _eye_y, 0.0)
	camera.position = bob + shake_offset
	camera.rotation_degrees.z = lerpf(camera.rotation_degrees.z, camera_roll_target, clampf(5.0 * delta, 0.0, 1.0))

	# FOV fecha um pouco com medo (visão de túnel).
	var target_fov := _base_fov - fear * 8.0
	if speed > walk_speed + 0.5:
		target_fov += 4.0
	camera.fov = lerpf(camera.fov, target_fov, clampf(4.0 * delta, 0.0, 1.0))

	# Lanterna segue a câmera com atraso — dá peso e deixa as bordas no escuro.
	var hand_offset := camera.global_basis * Vector3(0.18, -0.15, 0.0)
	flashlight_pivot.global_position = camera.global_position + hand_offset
	var current := flashlight_pivot.global_basis.get_rotation_quaternion()
	var target_q := camera.global_basis.get_rotation_quaternion()
	flashlight_pivot.global_basis = Basis(current.slerp(target_q, clampf(14.0 * delta, 0.0, 1.0)))


## Coloca a câmera direto numa altura/inclinação (sem suavizar). Para cortes de cena.
func snap_camera(eye_height: float, roll_deg: float) -> void:
	_eye_y = eye_height
	camera.rotation_degrees.z = roll_deg
	head.position = Vector3(0.0, eye_height, 0.0)


## Teleporta o jogador (checkpoints, cortes de cena).
func teleport(target: Transform3D) -> void:
	global_transform = target
	velocity = Vector3.ZERO
	_pitch = 0.0
	head.rotation_degrees.x = 0.0


## Vira o olhar do jogador (graus). Usado em cenas roteirizadas.
func set_look(yaw_deg: float, pitch_deg: float) -> void:
	rotation_degrees.y = yaw_deg
	_pitch = clampf(pitch_deg, -85.0, 85.0)
	head.rotation_degrees.x = _pitch


## Direção pra onde a câmera olha.
func view_forward() -> Vector3:
	return -camera.global_basis.z


func is_sprinting() -> bool:
	return sprint_time > 0.0


func is_stunned() -> bool:
	return _stunned


## Derruba o jogador por alguns segundos (trombada, agarrão).
func stun(duration: float) -> void:
	if _stunned:
		return
	_stunned = true
	var had_controls := controls_enabled
	controls_enabled = false
	var my_change := _controls_change_id
	velocity = Vector3.ZERO
	forced_eye_height = 0.45
	camera_roll_target = 28.0 if _rng.randf() < 0.5 else -28.0
	shake(0.08, 0.5)
	await get_tree().create_timer(duration, false).timeout
	forced_eye_height = -1.0
	camera_roll_target = 0.0
	# Só devolve o controle se ninguém (uma cena) mexeu nele enquanto caído.
	if _controls_change_id == my_change:
		controls_enabled = had_controls
	_stunned = false


## true se o ponto está dentro do facho da lanterna (ligada) e sem nada na frente.
func is_point_lit(point: Vector3, max_distance: float = -1.0) -> bool:
	if not flashlight_on or flashlight.light_energy < flashlight_energy * 0.3:
		return false
	var origin := flashlight.global_position
	var to_point := point - origin
	var dist := to_point.length()
	var reach := flashlight.spot_range if max_distance < 0.0 else max_distance
	if dist > reach or dist < 0.01:
		return false
	var forward := -flashlight.global_basis.z
	if rad_to_deg(forward.angle_to(to_point)) > flashlight.spot_angle:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, point)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or origin.distance_to(hit["position"]) > dist - 0.6


## Treme a câmera. strength ~0.02 leve, ~0.08 forte.
func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength if _shake_time > 0.0 else 0.0, strength)
	_shake_time = maxf(_shake_time, duration)


# ---------------------------------------------------------------- lanterna

func toggle_flashlight() -> void:
	if battery <= 0.0 and not flashlight_on:
		_play_click()
		return
	flashlight_on = not flashlight_on
	_play_click()
	battery_changed.emit(battery)


func _play_click() -> void:
	if flashlight_click:
		Game.play_sound_2d(flashlight_click, -10.0, _rng.randf_range(0.95, 1.05))


## Força a lanterna a piscar (usado em sustos).
func force_flicker(duration: float) -> void:
	_forced_flicker_time = maxf(_forced_flicker_time, duration)


func add_battery(amount: float) -> void:
	battery = clampf(battery + amount, 0.0, 100.0)
	battery_changed.emit(battery)


func _update_flashlight(delta: float) -> void:
	if flashlight_on:
		battery = maxf(battery - battery_drain_per_sec * delta, 0.0)
		if battery <= 0.0:
			flashlight_on = false
			battery_changed.emit(battery)

	var energy := flashlight_energy if flashlight_on else 0.0
	if flashlight_on:
		# Bateria fraca: luz mais fraca e piscando.
		if battery < low_battery_threshold:
			var t := battery / low_battery_threshold
			energy *= lerpf(0.35, 1.0, t)
			if _rng.randf() < (1.0 - t) * 0.08:
				energy *= _rng.randf_range(0.0, 0.4)
		if _forced_flicker_time > 0.0:
			_forced_flicker_time -= delta
			energy *= 1.0 if _rng.randf() > 0.45 else _rng.randf_range(0.0, 0.15)
	flashlight.light_energy = energy


# ---------------------------------------------------------------- medo

## Aumenta o medo (0..1). Sustos grandes ~0.6, pequenos ~0.2.
func add_fear(amount: float) -> void:
	fear = clampf(fear + amount, 0.0, 1.0)
	fear_changed.emit(fear)


func _update_fear_audio(delta: float) -> void:
	if fear > 0.0:
		fear = maxf(fear - delta * 0.05, 0.0)
		fear_changed.emit(fear)
	var heart_target := linear_to_db(clampf(fear * 1.2, 0.0001, 1.0)) - 2.0
	heart_player.volume_db = lerpf(heart_player.volume_db, heart_target, clampf(3.0 * delta, 0.0, 1.0))
	heart_player.pitch_scale = 1.0 + fear * 0.45

	var tired := 1.0 - stamina / stamina_max
	var breath_level := clampf(maxf(tired * 1.1, fear * 0.7), 0.0001, 1.0)
	var breath_target := linear_to_db(breath_level) - 6.0
	breath_player.volume_db = lerpf(breath_player.volume_db, breath_target, clampf(2.0 * delta, 0.0, 1.0))
	breath_player.pitch_scale = 1.0 + tired * 0.25


# ---------------------------------------------------------------- interação

func _update_interaction() -> void:
	var found: Node = null
	if controls_enabled and interact_ray.is_colliding():
		var node := interact_ray.get_collider() as Node
		while node != null and found == null:
			if node.has_method("interact"):
				found = node
			node = node.get_parent()
	_current_interactable = found
	var text := ""
	if found != null and found.has_method("get_interact_text"):
		text = str(found.call("get_interact_text"))
	if text != _last_prompt:
		_last_prompt = text
		interact_prompt_changed.emit(text)

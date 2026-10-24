@tool
class_name Dog
extends Node3D
## Paçoca. Corpo procedural (vira-lata caramelo), anda pelo chão sozinho
## e sabe "guiar": corre até o próximo ponto, espera o jogador chegar perto
## e late chamando. Sem física: ele gruda no chão com um raio pra baixo.

signal reached_point(index: int)
signal lead_finished

@export var coat_color := Color(0.62, 0.4, 0.2):
	set(value):
		coat_color = value
		if is_node_ready():
			_build()
@export var run_speed: float = 5.5
@export var walk_speed: float = 1.6
@export var bark_sounds: Array[AudioStream] = []
@export var whine_sound: AudioStream

var _parts := {}
var _target := Vector3.ZERO
var _moving := false
var _speed := 0.0
var _gait := 0.0
var _wag := 0.0
var _wag_speed := 8.0
var _lead_points: Array[Vector3] = []
var _lead_index := -1
var _lead_wait_distance := 12.0
var _bark_timer := 0.0
var _player: Node3D
var _voice: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build()
	if Engine.is_editor_hint():
		return
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 8.0
	_voice.max_distance = 90.0
	_voice.position = Vector3(0, 0.5, -0.4)
	add_child(_voice)
	_target = global_position


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_update_lead(delta)
	_update_motion(delta)
	_animate(delta)


# ------------------------------------------------------------ comandos

## Corre até um ponto (correndo = true) ou vai andando.
func go_to(point: Vector3, running: bool = true) -> void:
	_target = point
	_moving = true
	_speed = run_speed if running else walk_speed


func stop() -> void:
	_moving = false


## Vira pra olhar um ponto.
func face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if flat.distance_to(global_position) > 0.05:
		look_at(flat, Vector3.UP)


func bark() -> void:
	if bark_sounds.is_empty() or _voice == null:
		return
	_voice.stream = bark_sounds[_rng.randi() % bark_sounds.size()]
	_voice.pitch_scale = _rng.randf_range(0.95, 1.05)
	_voice.volume_db = 2.0
	_voice.play()


func whine() -> void:
	if whine_sound == null or _voice == null:
		return
	_voice.stream = whine_sound
	_voice.pitch_scale = 1.0
	_voice.volume_db = -2.0
	_voice.play()


## Abana o rabo (0 = parado, 1 = muito).
func set_wag(amount: float) -> void:
	_wag_speed = lerpf(0.0, 14.0, clampf(amount, 0.0, 1.0))


## Guia o jogador por uma lista de pontos: vai pro próximo quando o jogador
## chega a wait_distance dele, e late enquanto espera.
func lead(points: Array[Vector3], wait_distance: float = 12.0) -> void:
	_lead_points = points
	_lead_index = 0
	_lead_wait_distance = wait_distance
	_bark_timer = 1.0
	if not points.is_empty():
		go_to(points[0])


func stop_lead() -> void:
	_lead_index = -1


func is_leading() -> bool:
	return _lead_index >= 0


func _update_lead(delta: float) -> void:
	if _lead_index < 0 or _lead_index >= _lead_points.size():
		return
	if _moving:
		return
	# Chegou no ponto: espera o jogador.
	if _player:
		face(_player.global_position)
	_bark_timer -= delta
	if _bark_timer <= 0.0:
		bark()
		_bark_timer = _rng.randf_range(2.5, 4.5)
	if _player and _player.global_position.distance_to(global_position) < _lead_wait_distance:
		reached_point.emit(_lead_index)
		_lead_index += 1
		if _lead_index >= _lead_points.size():
			_lead_index = -1
			lead_finished.emit()
		else:
			bark()
			go_to(_lead_points[_lead_index])


# ------------------------------------------------------------ movimento

func _update_motion(delta: float) -> void:
	var pos := global_position
	if _moving:
		var to := Vector3(_target.x - pos.x, 0.0, _target.z - pos.z)
		var dist := to.length()
		if dist < 0.4:
			_moving = false
		else:
			var step := minf(_speed * delta, dist)
			pos += to / dist * step
			var look := pos + to / dist
			global_position = pos
			face(look)
	# Gruda no chão.
	var ground := _ground_height(global_position)
	global_position.y = lerpf(global_position.y, ground, clampf(delta * 15.0, 0.0, 1.0))


func _ground_height(p: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.5, p + Vector3.DOWN * 6.0)
	var body := _player as CollisionObject3D
	if body:
		query.exclude = [body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return p.y
	return (hit["position"] as Vector3).y


# ------------------------------------------------------------ corpo

func _animate(delta: float) -> void:
	var moving := _moving
	_gait += delta * (14.0 if moving and _speed > 3.0 else 7.0) * (1.0 if moving else 0.0)
	var swing := sin(_gait) * (0.75 if _speed > 3.0 else 0.4) if moving else 0.0
	var legs := ["leg_fl", "leg_br", "leg_fr", "leg_bl"]
	for i in legs.size():
		var leg := _parts.get(legs[i]) as Node3D
		if leg:
			leg.rotation.x = swing * (1.0 if i < 2 else -1.0)
	_wag += delta * (_wag_speed if not moving else 10.0)
	var tail := _parts.get("tail") as Node3D
	if tail:
		tail.rotation.y = sin(_wag) * 0.6
	var body := _parts.get("body") as Node3D
	if body:
		body.position.y = 0.42 + (absf(sin(_gait)) * 0.04 if moving else 0.0)


func _build() -> void:
	for child in get_children():
		if child.has_meta("dog_part"):
			remove_child(child)
			child.queue_free()
	_parts.clear()
	var coat := StandardMaterial3D.new()
	coat.albedo_color = coat_color
	coat.roughness = 1.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = coat_color.darkened(0.55)
	dark.roughness = 1.0
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.05, 0.03, 0.02)
	eye.roughness = 0.2

	var body := _pivot("body", self, Vector3(0, 0.42, 0))
	_mesh_capsule(body, coat, 0.15, 0.7, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	# pescoço + cabeça
	_mesh_capsule(body, coat, 0.08, 0.3, Vector3(0, 0.1, -0.3), Vector3(-0.7, 0, 0))
	var head := _pivot("head", body, Vector3(0, 0.22, -0.42))
	_mesh_box(head, coat, Vector3(0.18, 0.16, 0.2), Vector3.ZERO)
	_mesh_box(head, coat, Vector3(0.1, 0.09, 0.14), Vector3(0, -0.03, -0.15))  # focinho
	_mesh_box(head, dark, Vector3(0.05, 0.04, 0.03), Vector3(0, -0.005, -0.225))  # nariz
	_mesh_box(head, dark, Vector3(0.05, 0.1, 0.03), Vector3(-0.07, 0.1, 0.03), Vector3(0, 0, 0.3))  # orelhas
	_mesh_box(head, dark, Vector3(0.05, 0.1, 0.03), Vector3(0.07, 0.1, 0.03), Vector3(0, 0, -0.3))
	_mesh_box(head, eye, Vector3(0.025, 0.025, 0.02), Vector3(-0.05, 0.03, -0.1))
	_mesh_box(head, eye, Vector3(0.025, 0.025, 0.02), Vector3(0.05, 0.03, -0.1))
	# patas
	var legs := {
		"leg_fl": Vector3(-0.08, -0.02, -0.25), "leg_fr": Vector3(0.08, -0.02, -0.25),
		"leg_bl": Vector3(-0.08, -0.02, 0.25), "leg_br": Vector3(0.08, -0.02, 0.25),
	}
	for leg_name: String in legs:
		var leg := _pivot(leg_name, body, legs[leg_name])
		_mesh_capsule(leg, coat, 0.035, 0.42, Vector3(0, -0.2, 0), Vector3.ZERO)
	# rabo
	var tail := _pivot("tail", body, Vector3(0, 0.08, 0.36))
	_mesh_capsule(tail, coat, 0.03, 0.3, Vector3(0, 0.1, 0.08), Vector3(0.6, 0, 0))


func _pivot(part_name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.set_meta("dog_part", true)
	parent.add_child(n)
	_parts[part_name] = n
	return n


func _mesh_capsule(parent: Node3D, mat: Material, radius: float, height: float, pos: Vector3, rot: Vector3) -> void:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 6
	m.rings = 2
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


func _mesh_box(parent: Node3D, mat: Material, size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)

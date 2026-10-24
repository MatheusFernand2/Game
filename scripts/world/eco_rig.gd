@tool
class_name EcoRig
extends Node3D
## Corpo procedural dos Ecos (e da Coisa Funda): ossos em cápsula entre juntas.
## Cada pose é só uma lista de posições de juntas, então dá pra criar poses
## novas sem Blender. A frente do corpo é -Z (igual ao resto do Godot).
## Depois dá pra trocar por um modelo de verdade sem mudar quem usa isso.

enum Pose { STAND, SIT_FACE, RUN, CRAWL }

@export var pose: Pose = Pose.STAND:
	set(value):
		pose = value
		if is_node_ready():
			_rebuild()
@export var skin_color := Color(0.03, 0.03, 0.03):
	set(value):
		skin_color = value
		if is_node_ready():
			_rebuild()
@export var show_eyes := true:
	set(value):
		show_eyes = value
		if is_node_ready():
			_rebuild()
## Engrossa todos os ossos (a Coisa Funda usa ~1.8).
@export var thickness := 1.0:
	set(value):
		thickness = value
		if is_node_ready():
			_rebuild()
## Anima o ciclo da pose (correr, rastejar) sozinho.
@export var animate := false
## Ciclos por segundo da animação.
@export var cycle_speed := 1.6
## Cabeça dando "estalos" de vez em quando.
@export var head_twitch := false
## Parado, mas vivo: respira e balança de leve (só na pose em pé).
@export var idle_sway := false

## Se definido, a cabeça vira devagar pra acompanhar esse nó (ex.: o jogador).
var look_target: Node3D

# Ossos: [junta A, junta B, raio]
const BONES := [
	["hip", "chest", 0.15],
	["chest", "neck", 0.07],
	["chest", "shoulder_l", 0.055],
	["chest", "shoulder_r", 0.055],
	["shoulder_l", "elbow_l", 0.045],
	["elbow_l", "hand_l", 0.04],
	["shoulder_r", "elbow_r", 0.045],
	["elbow_r", "hand_r", 0.04],
	["hip", "hip_l", 0.07],
	["hip", "hip_r", 0.07],
	["hip_l", "knee_l", 0.06],
	["knee_l", "foot_l", 0.05],
	["hip_r", "knee_r", 0.06],
	["knee_r", "foot_r", 0.05],
]
const FINGER_LENGTH := 0.2
const HEAD_RADIUS := 0.12

const POSE_STAND := {
	"hip": Vector3(0, 1.1, 0), "chest": Vector3(0, 1.65, -0.05),
	"neck": Vector3(0, 1.86, -0.1), "head": Vector3(0, 2.0, -0.13),
	"shoulder_l": Vector3(-0.22, 1.7, -0.06), "elbow_l": Vector3(-0.27, 1.3, -0.03),
	"hand_l": Vector3(-0.28, 0.9, 0.0),
	"shoulder_r": Vector3(0.22, 1.7, -0.06), "elbow_r": Vector3(0.27, 1.3, -0.03),
	"hand_r": Vector3(0.28, 0.9, 0.0),
	"hip_l": Vector3(-0.1, 1.08, 0), "knee_l": Vector3(-0.11, 0.58, -0.03),
	"foot_l": Vector3(-0.11, 0.05, 0.02),
	"hip_r": Vector3(0.1, 1.08, 0), "knee_r": Vector3(0.11, 0.58, -0.03),
	"foot_r": Vector3(0.11, 0.05, 0.02),
}

# Sentado numa cadeira (assento a ~0,48 m), curvado, mão direita cobrindo o rosto,
# cotovelo apoiado no joelho. A esquerda descansa no outro joelho.
const POSE_SIT_FACE := {
	"hip": Vector3(0, 0.56, 0.06), "chest": Vector3(0, 1.06, -0.14),
	"neck": Vector3(0, 1.22, -0.27), "head": Vector3(0, 1.3, -0.36),
	"shoulder_l": Vector3(-0.2, 1.1, -0.17), "elbow_l": Vector3(-0.24, 0.8, -0.32),
	"hand_l": Vector3(-0.15, 0.62, -0.44),
	"shoulder_r": Vector3(0.2, 1.1, -0.17), "elbow_r": Vector3(0.15, 0.7, -0.44),
	"hand_r": Vector3(0.04, 1.2, -0.47),
	"hip_l": Vector3(-0.1, 0.55, 0.06), "knee_l": Vector3(-0.13, 0.56, -0.44),
	"foot_l": Vector3(-0.14, 0.05, -0.48),
	"hip_r": Vector3(0.1, 0.55, 0.06), "knee_r": Vector3(0.13, 0.56, -0.44),
	"foot_r": Vector3(0.14, 0.05, -0.48),
}

# Correndo: perna esquerda e braço direito pra frente (o outro quadro é o espelho).
# O braço da frente vai esticado, como quem quer agarrar.
const POSE_RUN_A := {
	"hip": Vector3(0, 1.05, 0), "chest": Vector3(0, 1.55, -0.25),
	"neck": Vector3(0, 1.73, -0.35), "head": Vector3(0, 1.86, -0.43),
	"shoulder_l": Vector3(-0.22, 1.58, -0.28), "elbow_l": Vector3(-0.26, 1.3, 0.0),
	"hand_l": Vector3(-0.26, 1.12, 0.25),
	"shoulder_r": Vector3(0.22, 1.58, -0.28), "elbow_r": Vector3(0.25, 1.4, -0.6),
	"hand_r": Vector3(0.2, 1.5, -0.95),
	"hip_l": Vector3(-0.1, 1.03, 0), "knee_l": Vector3(-0.1, 0.78, -0.45),
	"foot_l": Vector3(-0.1, 0.22, -0.42),
	"hip_r": Vector3(0.1, 1.03, 0), "knee_r": Vector3(0.1, 0.58, 0.22),
	"foot_r": Vector3(0.1, 0.32, 0.62),
}

# De quatro, baixo e comprido. Cotovelos e joelhos pra cima, como aranha.
const POSE_CRAWL := {
	"hip": Vector3(0, 0.95, 0.65), "chest": Vector3(0, 1.05, -0.45),
	"neck": Vector3(0, 1.0, -0.8), "head": Vector3(0, 0.88, -1.02),
	"shoulder_l": Vector3(-0.3, 1.05, -0.45), "elbow_l": Vector3(-0.62, 1.3, -0.7),
	"hand_l": Vector3(-0.5, 0.04, -1.05),
	"shoulder_r": Vector3(0.3, 1.05, -0.45), "elbow_r": Vector3(0.62, 1.3, -0.7),
	"hand_r": Vector3(0.5, 0.04, -1.05),
	"hip_l": Vector3(-0.22, 0.95, 0.65), "knee_l": Vector3(-0.58, 1.35, 0.75),
	"foot_l": Vector3(-0.45, 0.04, 0.95),
	"hip_r": Vector3(0.22, 0.95, 0.65), "knee_r": Vector3(0.58, 1.35, 0.75),
	"foot_r": Vector3(0.45, 0.04, 0.95),
}

var phase := 0.0

var _bone_meshes: Array[MeshInstance3D] = []
var _bone_lengths: Array[float] = []
var _finger_l: MeshInstance3D
var _finger_r: MeshInstance3D
var _head: Node3D
var _joints: Dictionary = {}
var _twitch := 0.0
var _twitch_now := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_rebuild()


func _process(delta: float) -> void:
	if not animate and not head_twitch and not idle_sway and look_target == null:
		return
	if animate:
		phase += delta * cycle_speed
		_apply_joints(_animated_joints(phase))
	elif idle_sway and pose == Pose.STAND:
		phase += delta
		_apply_joints(_idle_joints(phase))
	if look_target and is_instance_valid(look_target) and _head:
		_look_head(look_target.global_position + Vector3.UP * 1.6, delta)
	if head_twitch and _head:
		if _rng.randf() < delta * 2.5:
			_twitch = _rng.randf_range(-0.6, 0.6)
		_twitch_now = lerpf(_twitch_now, _twitch, clampf(delta * 25.0, 0.0, 1.0))
		# Com alvo de olhar, o estalo já entra em _look_head.
		if look_target == null:
			_head.rotate_object_local(Vector3.BACK, _twitch_now - _head.get_meta("roll", 0.0))
			_head.set_meta("roll", _twitch_now)


## Junta atual (coordenadas locais). Útil pra prender coisas na mão, por exemplo.
func joint(joint_name: String) -> Vector3:
	return _joints.get(joint_name, Vector3.ZERO)


func _base_joints() -> Dictionary:
	match pose:
		Pose.SIT_FACE:
			return POSE_SIT_FACE
		Pose.RUN:
			return POSE_RUN_A
		Pose.CRAWL:
			return POSE_CRAWL
	return POSE_STAND


func _animated_joints(p: float) -> Dictionary:
	var t := p * TAU
	match pose:
		Pose.RUN:
			var w := 0.5 + 0.5 * sin(t)
			var a := POSE_RUN_A
			var b := _mirror(POSE_RUN_A)
			var out := {}
			for k: String in a:
				out[k] = (a[k] as Vector3).lerp(b[k] as Vector3, w)
			var bob := Vector3(0, absf(sin(t)) * 0.08, 0)
			for k: String in out:
				if not k.begins_with("foot"):
					out[k] = (out[k] as Vector3) + bob
			return out
		Pose.CRAWL:
			var out := POSE_CRAWL.duplicate()
			# Diagonais andam juntas: mão esquerda + pé direito, depois o contrário.
			_crawl_limb(out, "hand_l", "elbow_l", t, -0.35)
			_crawl_limb(out, "foot_r", "knee_r", t, -0.3)
			_crawl_limb(out, "hand_r", "elbow_r", t + PI, -0.35)
			_crawl_limb(out, "foot_l", "knee_l", t + PI, -0.3)
			var sway := Vector3(sin(t) * 0.05, sin(t * 2.0) * 0.04, 0)
			for k: String in ["hip", "chest", "neck", "head", "shoulder_l", "shoulder_r", "hip_l", "hip_r"]:
				out[k] = (out[k] as Vector3) + sway
			return out
	return _base_joints()


func _idle_joints(t: float) -> Dictionary:
	var out := POSE_STAND.duplicate()
	var breath := sin(t * 1.3) * 0.012
	var sway := Vector3(sin(t * 0.37) * 0.025, 0.0, sin(t * 0.23) * 0.015)
	for k: String in ["chest", "neck", "head", "shoulder_l", "shoulder_r"]:
		out[k] = (out[k] as Vector3) + sway + Vector3(0, breath, 0)
	# Braços pendurados acompanham com atraso (parecem pesados).
	for k: String in ["elbow_l", "elbow_r", "hand_l", "hand_r"]:
		out[k] = (out[k] as Vector3) + sway * 0.6 + Vector3(0, breath * 0.5, 0)
	return out


## Vira a cabeça (só pros lados e um pouco pra cima/baixo) na direção do alvo.
var _look_yaw := 0.0
var _look_pitch := 0.0


func _look_head(world_point: Vector3, delta: float) -> void:
	var local := to_local(world_point) - _head.position
	var yaw := clampf(atan2(-local.x, -local.z), -1.2, 1.2)
	var pitch := clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.5, 0.5)
	# Lento e "errado": acompanha com atraso.
	_look_yaw = lerpf(_look_yaw, yaw, clampf(delta * 1.2, 0.0, 1.0))
	_look_pitch = lerpf(_look_pitch, pitch, clampf(delta * 1.2, 0.0, 1.0))
	# Sempre parte da pose de descanso (senão a rotação acumula a cada quadro).
	var rest: Basis = _head.get_meta("rest_basis", _head.transform.basis)
	_head.transform.basis = Basis(Vector3.UP, _look_yaw) * Basis(Vector3.RIGHT, _look_pitch) \
		* rest * Basis(Vector3.BACK, _twitch_now)


func _crawl_limb(j: Dictionary, end_name: String, mid_name: String, t: float, reach: float) -> void:
	var swing := sin(t)
	var lift := maxf(0.0, cos(t)) * 0.35
	j[end_name] = (j[end_name] as Vector3) + Vector3(0, lift, swing * reach)
	j[mid_name] = (j[mid_name] as Vector3) + Vector3(0, lift * 0.5, swing * reach * 0.5)


func _mirror(src: Dictionary) -> Dictionary:
	var out := {}
	for k: String in src:
		var v := src[k] as Vector3
		var other := k
		if k.ends_with("_l"):
			other = k.trim_suffix("_l") + "_r"
		elif k.ends_with("_r"):
			other = k.trim_suffix("_r") + "_l"
		out[other] = Vector3(-v.x, v.y, v.z)
	return out


func _rebuild() -> void:
	for child in get_children():
		if child.has_meta("eco_rig_part"):
			remove_child(child)
			child.queue_free()
	_bone_meshes.clear()
	_bone_lengths.clear()

	var skin := StandardMaterial3D.new()
	skin.albedo_color = skin_color
	skin.roughness = 0.9
	# Contorno de luz fraco: a silhueta preta aparece contra o escuro.
	skin.rim_enabled = true
	skin.rim = 0.35
	skin.rim_tint = 0.7
	var joints := _base_joints()

	for bone: Array in BONES:
		var a := joints[bone[0]] as Vector3
		var b := joints[bone[1]] as Vector3
		var radius := float(bone[2]) * thickness
		var length := maxf(a.distance_to(b), 0.01)
		var mesh := CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = length + radius * 2.0
		mesh.radial_segments = 6
		mesh.rings = 2
		mesh.material = skin
		var mi := _part(MeshInstance3D.new()) as MeshInstance3D
		mi.mesh = mesh
		_bone_meshes.append(mi)
		_bone_lengths.append(length)

	_finger_l = _make_finger(skin)
	_finger_r = _make_finger(skin)

	_head = _part(Node3D.new()) as Node3D
	var head_mesh := SphereMesh.new()
	head_mesh.radius = HEAD_RADIUS * lerpf(1.0, thickness, 0.5)
	head_mesh.height = head_mesh.radius * 2.6
	head_mesh.radial_segments = 8
	head_mesh.rings = 6
	head_mesh.material = skin
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = head_mesh
	_head.add_child(head_mi)
	if show_eyes:
		var eye_mat := StandardMaterial3D.new()
		eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		eye_mat.albedo_color = Color(0.95, 0.93, 0.85)
		for x: float in [-0.04, 0.045]:
			var eye_mesh := SphereMesh.new()
			eye_mesh.radius = 0.012
			eye_mesh.height = 0.024
			eye_mesh.radial_segments = 4
			eye_mesh.rings = 2
			eye_mesh.material = eye_mat
			var eye := MeshInstance3D.new()
			eye.mesh = eye_mesh
			eye.position = Vector3(x, 0.02, -head_mesh.radius * 0.92)
			_head.add_child(eye)
	_apply_joints(joints)


func _make_finger(skin: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.022 * thickness
	mesh.height = FINGER_LENGTH + mesh.radius * 2.0
	mesh.radial_segments = 4
	mesh.rings = 1
	mesh.material = skin
	var mi := _part(MeshInstance3D.new()) as MeshInstance3D
	mi.mesh = mesh
	return mi


func _part(node: Node3D) -> Node3D:
	node.set_meta("eco_rig_part", true)
	add_child(node)
	return node


func _apply_joints(joints: Dictionary) -> void:
	_joints = joints
	for i in BONES.size():
		var bone: Array = BONES[i]
		var a := joints[bone[0]] as Vector3
		var b := joints[bone[1]] as Vector3
		_bone_meshes[i].transform = _segment_transform(a, b, _bone_lengths[i])
	_place_finger(_finger_l, joints["elbow_l"] as Vector3, joints["hand_l"] as Vector3)
	_place_finger(_finger_r, joints["elbow_r"] as Vector3, joints["hand_r"] as Vector3)

	var neck := joints["neck"] as Vector3
	var head_pos := joints["head"] as Vector3
	var up := (head_pos - neck).normalized()
	if up.length_squared() < 0.5:
		up = Vector3.UP
	var x := up.cross(Vector3.BACK).normalized()
	if x.length_squared() < 0.5:
		x = Vector3.RIGHT
	var z := x.cross(up).normalized()
	_head.transform = Transform3D(Basis(x, up, z), head_pos)
	_head.set_meta("roll", 0.0)
	_head.set_meta("rest_basis", _head.transform.basis)


func _place_finger(finger: MeshInstance3D, elbow: Vector3, hand: Vector3) -> void:
	var dir := (hand - elbow).normalized()
	finger.transform = _segment_transform(hand, hand + dir * FINGER_LENGTH, FINGER_LENGTH)


## Transform que leva uma cápsula de pé (eixo Y) pra ficar entre a e b.
static func _segment_transform(a: Vector3, b: Vector3, rest_length: float) -> Transform3D:
	var dir := b - a
	var length := dir.length()
	if length < 0.0001:
		return Transform3D(Basis(), a)
	var y := dir / length
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	var stretch := length / maxf(rest_length, 0.0001)
	return Transform3D(Basis(x, y * stretch, z), (a + b) * 0.5)

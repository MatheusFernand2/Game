class_name Owl
extends Node3D
## Coruja que sai voando na cara do jogador (susto pequeno do Ato 1).

@export var screech_sound: AudioStream
@export var flap_sound: AudioStream

var _wing_l: Node3D
var _wing_r: Node3D
var _flapping := false
var _t := 0.0


func _ready() -> void:
	var feathers := StandardMaterial3D.new()
	feathers.albedo_color = Color(0.55, 0.47, 0.36)
	feathers.roughness = 1.0
	var face := StandardMaterial3D.new()
	face.albedo_color = Color(0.85, 0.8, 0.7)
	face.roughness = 1.0
	var eye := StandardMaterial3D.new()
	eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye.albedo_color = Color(0.05, 0.04, 0.03)

	_add_box(self, feathers, Vector3(0.22, 0.3, 0.2), Vector3.ZERO)
	_add_box(self, face, Vector3(0.2, 0.18, 0.04), Vector3(0, 0.08, -0.1))
	_add_box(self, eye, Vector3(0.04, 0.04, 0.02), Vector3(-0.05, 0.1, -0.125))
	_add_box(self, eye, Vector3(0.04, 0.04, 0.02), Vector3(0.05, 0.1, -0.125))
	_wing_l = Node3D.new()
	_wing_l.position = Vector3(-0.11, 0.05, 0)
	add_child(_wing_l)
	_add_box(_wing_l, feathers, Vector3(0.45, 0.03, 0.22), Vector3(-0.22, 0, 0))
	_wing_r = Node3D.new()
	_wing_r.position = Vector3(0.11, 0.05, 0)
	add_child(_wing_r)
	_add_box(_wing_r, feathers, Vector3(0.45, 0.03, 0.22), Vector3(0.22, 0, 0))
	_set_wings_folded()


func _process(delta: float) -> void:
	if not _flapping:
		return
	_t += delta
	var a := sin(_t * 26.0) * 0.9
	_wing_l.rotation.z = -a
	_wing_r.rotation.z = a


## Voa da posição atual, passando colado na câmera, e some.
func fly_at(player: Player) -> void:
	_flapping = true
	var cam := player.camera
	var start := global_position
	var past := cam.global_position + player.view_forward() * -3.0 + Vector3(0.4, 0.8, 0.0)
	var near := cam.global_position + player.view_forward() * 0.35 + Vector3(0.15, 0.05, 0.0)
	if screech_sound:
		Game.play_sound_at(screech_sound, start, 6.0)
	if flap_sound:
		Game.play_sound_at(flap_sound, start, 2.0)
	look_at(near, Vector3.UP)
	var tw := create_tween()
	tw.tween_property(self, "global_position", near, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_on_pass_face.bind(player))
	tw.tween_property(self, "global_position", past, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(queue_free)


func _on_pass_face(player: Player) -> void:
	player.shake(0.05, 0.4)
	player.add_fear(0.35)
	if flap_sound:
		Game.play_sound_2d(flap_sound, 0.0, 1.15)


func _set_wings_folded() -> void:
	_wing_l.rotation.z = 1.3
	_wing_r.rotation.z = -1.3


func _add_box(parent: Node3D, mat: Material, size: Vector3, pos: Vector3) -> void:
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	parent.add_child(mi)

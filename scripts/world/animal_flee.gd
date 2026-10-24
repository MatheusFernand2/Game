class_name AnimalFlee
extends Node3D
## Bicho que fica pastando e foge quando o jogador chega perto.
## Pista do plot twist: os animais fogem dos mortos.

@export var model_scene: PackedScene
@export var model_scale: float = 0.38
@export var flee_distance: float = 15.0
@export var flee_speed: float = 7.5
@export var flee_time: float = 4.0
@export var flee_sound: AudioStream

var _model: Node3D
var _anim: AnimationPlayer
var _player: Node3D
var _fleeing := false
var _flee_dir := Vector3.FORWARD
var _flee_left := 0.0


func _ready() -> void:
	if model_scene == null:
		return
	_model = model_scene.instantiate() as Node3D
	_model.rotation.y = PI
	_model.scale = Vector3.ONE * model_scale
	add_child(_model)
	_anim = ModelUtil.find_animation_player(_model)
	ModelUtil.set_loops(_anim, PackedStringArray(["Eating", "Idle", "Gallop"]))
	ModelUtil.play(_anim, "Eating", 0.0)


func _physics_process(delta: float) -> void:
	if _model == null:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	if not _fleeing:
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() < flee_distance:
			_start_flee(-to_player.normalized())
		return
	_flee_left -= delta
	global_position += _flee_dir * flee_speed * delta
	global_position.y = _ground_height(global_position)
	if _flee_left <= 0.0:
		queue_free()


func _start_flee(direction: Vector3) -> void:
	_fleeing = true
	_flee_left = flee_time
	# Foge meio de lado, não em linha reta (fica mais natural).
	_flee_dir = direction.rotated(Vector3.UP, randf_range(-0.5, 0.5)).normalized()
	look_at(global_position + _flee_dir, Vector3.UP)
	ModelUtil.play(_anim, "Gallop", 0.15, 1.2)
	if flee_sound:
		Game.play_sound_at(flee_sound, global_position + Vector3.UP, 2.0)


func _ground_height(p: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.5, p + Vector3.DOWN * 6.0)
	var body := _player as CollisionObject3D
	if body:
		query.exclude = [body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return p.y
	return (hit["position"] as Vector3).y

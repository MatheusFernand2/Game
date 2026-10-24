class_name ModelUtil
extends RefCounted
## Funções pra usar modelos importados (.gltf) no jogo.


## Lista [mesh, transform relativo à raiz] de todos os MeshInstance3D da cena.
## Serve pra transformar um modelo em MultiMesh (milhares de cópias baratas).
static func extract_parts(scene: PackedScene) -> Array:
	var parts := []
	if scene == null:
		return parts
	var root := scene.instantiate()
	_collect(root, Transform3D.IDENTITY, parts, true)
	root.free()
	return parts


static func _collect(node: Node, xform: Transform3D, parts: Array, is_root: bool) -> void:
	var here := xform
	if node is Node3D and not is_root:
		here = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		parts.append([(node as MeshInstance3D).mesh, here])
	for child in node.get_children():
		_collect(child, here, parts, false)


## Primeiro AnimationPlayer dentro do nó.
static func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := find_animation_player(child)
		if found:
			return found
	return null


## Todos os MeshInstance3D dentro do nó.
static func find_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	_find_meshes(node, out)
	return out


static func _find_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_meshes(child, out)


## Faz as animações darem loop (o importador deixa todas sem loop).
static func set_loops(player: AnimationPlayer, names: PackedStringArray) -> void:
	if player == null:
		return
	for anim_name in names:
		if player.has_animation(anim_name):
			player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR


## Toca a animação se ela existir (com mistura suave).
static func play(player: AnimationPlayer, anim_name: String, blend: float = 0.25, speed: float = 1.0) -> void:
	if player == null or not player.has_animation(anim_name):
		return
	if player.current_animation != anim_name:
		player.play(anim_name, blend)
	player.speed_scale = speed

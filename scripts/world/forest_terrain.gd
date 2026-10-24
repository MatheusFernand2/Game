@tool
class_name ForestTerrain
extends Node3D
## Terreno da mata gerado por código (malha + colisão), com:
## - uma trilha (lista de pontos) mais plana e com textura de terra batida
## - clareiras planas (o sítio, a casa de ferramentas...)
## - o barranco: uma queda que corta o mapa de um lado ao outro
## - morros nas bordas, pra fechar o mapa de um jeito natural
## Aparece no editor também. Mude os parâmetros e ele refaz sozinho.

signal generated

## Lado do mapa em metros (1 vértice por metro).
@export var size: int = 240:
	set(value):
		size = maxi(value, 16)
		_queue_regen()
@export var noise_seed: int = 7:
	set(value):
		noise_seed = value
		_queue_regen()
@export var height_scale: float = 3.5:
	set(value):
		height_scale = value
		_queue_regen()
## Pontos da trilha no chão (x, z).
@export var path_points: PackedVector2Array = PackedVector2Array():
	set(value):
		path_points = value
		_queue_regen()
@export var path_width: float = 2.2:
	set(value):
		path_width = value
		_queue_regen()
## Clareiras planas: cada item é (x, z, raio).
@export var clearings: PackedVector3Array = PackedVector3Array():
	set(value):
		clearings = value
		_queue_regen()
@export_group("Barranco")
## Linha (z) onde fica a beira do barranco. Tudo com z menor fica lá embaixo.
@export var cliff_z: float = -70.0:
	set(value):
		cliff_z = value
		_queue_regen()
@export var cliff_drop: float = 9.0:
	set(value):
		cliff_drop = value
		_queue_regen()
@export var cliff_steepness: float = 2.5:
	set(value):
		cliff_steepness = value
		_queue_regen()
@export_group("Visual")
@export var material: Material:
	set(value):
		material = value
		if _mesh_instance:
			_mesh_instance.material_override = material

var _heights := PackedFloat32Array()
var _n := 0
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _mesh_instance: MeshInstance3D
var _body: StaticBody3D
var _regen_queued := false


func _ready() -> void:
	if _heights.is_empty():
		generate()


func _queue_regen() -> void:
	if not is_node_ready() or _regen_queued:
		return
	_regen_queued = true
	_deferred_regen.call_deferred()


func _deferred_regen() -> void:
	_regen_queued = false
	generate()


func _setup_noise() -> void:
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.018
	_noise.fractal_octaves = 3
	_detail.seed = noise_seed + 101
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.15


## Distância (no plano) até a trilha. Acima de max_dist devolve max_dist
## (bem mais rápido, porque pula os trechos longe).
func distance_to_path(x: float, z: float, max_dist: float = 9999.0) -> float:
	if path_points.size() < 2:
		return max_dist
	var p := Vector2(x, z)
	var best := max_dist * max_dist
	for i in path_points.size() - 1:
		var a := path_points[i]
		var b := path_points[i + 1]
		if x < minf(a.x, b.x) - max_dist or x > maxf(a.x, b.x) + max_dist \
				or z < minf(a.y, b.y) - max_dist or z > maxf(a.y, b.y) + max_dist:
			continue
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_squared_to(a + ab * t))
	return sqrt(best)


## Altura "matemática" do terreno (antes de virar malha).
func _raw_height(x: float, z: float, path_dist: float) -> float:
	var big := _noise.get_noise_2d(x, z) * height_scale
	var small := _detail.get_noise_2d(x, z) * 0.35
	var flat := smoothstep(path_width, path_width + 7.0, path_dist)
	var h := big * lerpf(0.35, 1.0, flat) + small * flat

	for c in clearings:
		var d := Vector2(x, z).distance_to(Vector2(c.x, c.y))
		var w := 1.0 - smoothstep(c.z, c.z + 8.0, d)
		if w > 0.0:
			var center_h := _noise.get_noise_2d(c.x, c.y) * height_scale * 0.35
			h = lerpf(h, center_h, w)

	# O barranco.
	if z < cliff_z:
		h -= cliff_drop * smoothstep(0.0, cliff_steepness, cliff_z - z)

	# Morros nas bordas do mapa.
	var half := size * 0.5
	var edge := maxf(absf(x), absf(z))
	h += smoothstep(half - 25.0, half, edge) * 10.0
	return h


func generate() -> void:
	_setup_noise()
	_n = size + 1
	var half := size * 0.5
	_heights.resize(_n * _n)
	var colors := PackedColorArray()
	colors.resize(_n * _n)
	var verts := PackedVector3Array()
	verts.resize(_n * _n)

	for j in _n:
		var z := j - half
		for i in _n:
			var x := i - half
			var d := distance_to_path(x, z, path_width + 8.0)
			var h := _raw_height(x, z, d)
			var idx := j * _n + i
			_heights[idx] = h
			verts[idx] = Vector3(x, h, z)
			# Vermelho = quanto é trilha (o shader mistura as texturas).
			var path_mask := 1.0 - smoothstep(path_width * 0.45, path_width * 1.1, d)
			colors[idx] = Color(path_mask, 0.0, 0.0, 1.0)

	var normals := PackedVector3Array()
	normals.resize(_n * _n)
	for j in _n:
		for i in _n:
			var hl := _heights[j * _n + maxi(i - 1, 0)]
			var hr := _heights[j * _n + mini(i + 1, _n - 1)]
			var hd := _heights[maxi(j - 1, 0) * _n + i]
			var hu := _heights[mini(j + 1, _n - 1) * _n + i]
			normals[j * _n + i] = Vector3(hl - hr, 2.0, hd - hu).normalized()

	var indices := PackedInt32Array()
	indices.resize(size * size * 6)
	var k := 0
	for j in size:
		for i in size:
			var a := j * _n + i
			var b := a + 1
			var c := a + _n
			var d := c + 1
			# Sentido horário visto de cima = face pra cima (padrão do Godot).
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if _mesh_instance == null:
		_mesh_instance = get_node_or_null("TerrainMesh") as MeshInstance3D
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "TerrainMesh"
		add_child(_mesh_instance)
	# O chão não precisa projetar sombra em si mesmo (evita listras com o vertex snap).
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material

	if _body == null:
		_body = get_node_or_null("TerrainBody") as StaticBody3D
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "TerrainBody"
		add_child(_body)
		var shape_node := CollisionShape3D.new()
		shape_node.shape = HeightMapShape3D.new()
		_body.add_child(shape_node)
	var shape := (_body.get_child(0) as CollisionShape3D).shape as HeightMapShape3D
	shape.map_width = _n
	shape.map_depth = _n
	shape.map_data = _heights
	generated.emit()


## Altura do chão em (x, z) — igual à colisão (interpolada entre os vértices).
func height_at(x: float, z: float) -> float:
	if _heights.is_empty():
		generate()
	var half := size * 0.5
	var fx := clampf(x + half, 0.0, float(size) - 0.001)
	var fz := clampf(z + half, 0.0, float(size) - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var h00 := _heights[j * _n + i]
	var h10 := _heights[j * _n + i + 1]
	var h01 := _heights[(j + 1) * _n + i]
	var h11 := _heights[(j + 1) * _n + i + 1]
	# Mesma divisão em triângulos da malha.
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


## Ponto no chão.
func ground_point(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)

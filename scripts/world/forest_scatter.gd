@tool
class_name ForestScatter
extends Node3D
## Espalha árvores, mato e arbustos em cima de um ForestTerrain.
## Tudo em MultiMesh (rápido mesmo com milhares), dividido em blocos pra
## o Godot só desenhar o que está perto. Troncos ganham colisão (só no jogo,
## não no editor). Mesma "semente" = mesma floresta sempre.
## Se houver modelos (.gltf) nas listas de "Modelos", usa eles; senão usa as
## formas simples geradas por código.

@export var terrain_path: NodePath
@export var scatter_seed: int = 11:
	set(value):
		scatter_seed = value
		_queue_regen()
@export_group("Árvores")
@export var tree_count: int = 1400:
	set(value):
		tree_count = value
		_queue_regen()
## Distância mínima entre árvore e trilha.
@export var tree_path_clearance: float = 3.2
@export var tree_min_spacing: float = 2.6
## Faixas sem árvore nem arbusto (linhas de visão roteirizadas).
## Pares de pontos: (a1, b1, a2, b2, ...).
@export var exclusion_segments: PackedVector2Array = PackedVector2Array()
@export var exclusion_radius: float = 2.5
@export_group("Mato")
@export var grass_count: int = 9000:
	set(value):
		grass_count = value
		_queue_regen()
## Mato só perto da trilha (onde o jogador anda), até essa distância.
@export var grass_max_path_distance: float = 30.0
@export var bush_count: int = 700:
	set(value):
		bush_count = value
		_queue_regen()
## Arbustos extras na beira do barranco, pra esconder a queda.
@export var cliff_bush_count: int = 160
@export_group("Modelos")
## Árvores: cena, peso no sorteio, escala (mín, máx) e raio do tronco (na escala 1).
@export var tree_models: Array[PackedScene] = []:
	set(value):
		tree_models = value
		_queue_regen()
@export var tree_model_weights: PackedFloat32Array = PackedFloat32Array()
@export var tree_model_scales: PackedVector2Array = PackedVector2Array()
@export var tree_model_trunks: PackedFloat32Array = PackedFloat32Array()
## Plantas baixas (arbustos, samambaias, cogumelos).
@export var plant_models: Array[PackedScene] = []
@export var plant_model_weights: PackedFloat32Array = PackedFloat32Array()
@export var plant_model_scales: PackedVector2Array = PackedVector2Array()
@export var plant_count: int = 2600
## Fração das plantas que nasce perto da trilha (onde o jogador vê).
@export var plant_near_path: float = 0.75
## Capim (usa grass_count).
@export var grass_models: Array[PackedScene] = []
@export var grass_model_scales: PackedVector2Array = PackedVector2Array()
@export var rock_models: Array[PackedScene] = []
@export var rock_model_scales: PackedVector2Array = PackedVector2Array()
@export var rock_count: int = 240
## Tamanho do bloco (m) e distância máxima de desenho de cada camada.
@export var chunk_size: float = 32.0
@export var tree_draw_distance: float = 85.0
@export var plant_draw_distance: float = 50.0
@export var grass_draw_distance: float = 32.0
@export_group("Texturas")
@export var bark_texture: Texture2D
@export var foliage_texture: Texture2D
@export var grass_texture: Texture2D
@export var bush_texture: Texture2D

var _regen_queued := false
var _built: Array[Node] = []


func _ready() -> void:
	var terrain := _terrain()
	if terrain:
		if not terrain.generated.is_connected(_queue_regen):
			terrain.generated.connect(_queue_regen)
	generate()


func _terrain() -> ForestTerrain:
	if terrain_path.is_empty():
		return null
	return get_node_or_null(terrain_path) as ForestTerrain


func _queue_regen() -> void:
	if not is_node_ready() or _regen_queued:
		return
	_regen_queued = true
	_deferred_regen.call_deferred()


func _deferred_regen() -> void:
	_regen_queued = false
	generate()


func generate() -> void:
	for node in _built:
		if is_instance_valid(node):
			node.queue_free()
	_built.clear()
	# Depois de recarregar o script no editor a lista se perde: limpa pela marca.
	for child in get_children():
		if child.has_meta("scatter_part"):
			child.queue_free()
	var terrain := _terrain()
	if terrain == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_seed

	if tree_models.is_empty():
		_scatter_trees(terrain, rng)
	else:
		_scatter_model_trees(terrain, rng)
	if grass_models.is_empty():
		_scatter_cards(terrain, rng, grass_count, _grass_mesh(), true)
	else:
		_scatter_models(terrain, rng, "Grass", grass_models, PackedFloat32Array(), grass_model_scales,
			grass_count, 1.0, grass_draw_distance, false)
	if plant_models.is_empty():
		_scatter_cards(terrain, rng, bush_count, _bush_mesh(), false)
		_scatter_cliff_bushes(terrain, rng)
	else:
		_scatter_models(terrain, rng, "Plants", plant_models, plant_model_weights, plant_model_scales,
			plant_count, plant_near_path, plant_draw_distance, false)
		_scatter_model_cliff_bushes(terrain, rng)
	if not rock_models.is_empty():
		_scatter_rocks(terrain, rng)


# ------------------------------------------------------------------ regras

func _in_play_area(terrain: ForestTerrain, x: float, z: float) -> bool:
	var half := terrain.size * 0.5 - 4.0
	return absf(x) < half and absf(z) < half


func _in_clearing(terrain: ForestTerrain, x: float, z: float, extra: float) -> bool:
	for c in terrain.clearings:
		if Vector2(x, z).distance_to(Vector2(c.x, c.y)) < c.z + extra:
			return true
	return false


func _in_exclusion(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for i in range(0, exclusion_segments.size() - 1, 2):
		var a := exclusion_segments[i]
		var b := exclusion_segments[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if p.distance_to(a + ab * t) < exclusion_radius:
			return true
	return false


func _near_cliff_edge(terrain: ForestTerrain, z: float, before: float, after: float) -> bool:
	return z < terrain.cliff_z + before and z > terrain.cliff_z - terrain.cliff_steepness - after


# ------------------------------------------------------------------ árvores

func _scatter_trees(terrain: ForestTerrain, rng: RandomNumberGenerator) -> void:
	var meshes := [_pine_mesh(), _dead_mesh(), _broad_mesh()]
	var weights := [0.55, 0.2, 0.25]
	var transforms: Array = [[], [], []]
	var placed := PackedVector2Array()
	var half := terrain.size * 0.5
	var attempts := tree_count * 6
	var trunks := []  # [pos, radius]

	# Grade simples pra checar espaçamento rápido.
	var cell := tree_min_spacing
	var grid := {}
	while placed.size() < tree_count and attempts > 0:
		attempts -= 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if terrain.distance_to_path(x, z, tree_path_clearance + 1.0) < tree_path_clearance:
			continue
		if _in_clearing(terrain, x, z, 2.0):
			continue
		if _near_cliff_edge(terrain, z, 2.5, 3.0):
			continue
		if _in_exclusion(x, z):
			continue
		var key := Vector2i(floori(x / cell), floori(z / cell))
		var too_close := false
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var k2 := key + Vector2i(dx, dz)
				if grid.has(k2) and (grid[k2] as Vector2).distance_to(Vector2(x, z)) < tree_min_spacing:
					too_close = true
		if too_close:
			continue
		grid[key] = Vector2(x, z)
		placed.append(Vector2(x, z))

		var r := rng.randf()
		var kind := 0
		if r > weights[0]:
			kind = 1 if r < weights[0] + weights[1] else 2
		var sc := rng.randf_range(0.8, 1.35)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.15), sc))
		# Inclinação leve, árvore de mata nunca é reta.
		var tilt_axis := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
		if tilt_axis.length_squared() > 0.01:
			b = Basis(tilt_axis.normalized(), rng.randf_range(0.0, 0.07)) * b
		var pos := Vector3(x, terrain.height_at(x, z) - 0.15, z)
		(transforms[kind] as Array).append(Transform3D(b, pos))
		trunks.append([pos, 0.24 * sc])

	for kind in 3:
		_add_multimesh("Trees%d" % kind, meshes[kind], transforms[kind], true)

	if not Engine.is_editor_hint():
		var body := StaticBody3D.new()
		body.name = "TreeTrunks"
		body.set_meta("scatter_part", true)
		add_child(body)
		_built.append(body)
		for t: Array in trunks:
			var shape := CylinderShape3D.new()
			shape.radius = float(t[1])
			shape.height = 4.0
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = (t[0] as Vector3) + Vector3.UP * 2.0
			body.add_child(cs)


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array, shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.set_meta("scatter_part", true)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_built.append(mmi)


# ------------------------------------------------------------------ mato e arbustos

func _scatter_cards(terrain: ForestTerrain, rng: RandomNumberGenerator, count: int, mesh: Mesh, is_grass: bool) -> void:
	var transforms := []
	var half := terrain.size * 0.5 - 6.0
	var attempts := count * 5
	while transforms.size() < count and attempts > 0:
		attempts -= 1
		var x: float
		var z: float
		if is_grass:
			# Perto da trilha: sorteia um ponto da trilha e espalha em volta.
			var pts := terrain.path_points
			if pts.size() < 2:
				return
			var seg := rng.randi_range(0, pts.size() - 2)
			var base := pts[seg].lerp(pts[seg + 1], rng.randf())
			var ang := rng.randf() * TAU
			var dist := pow(rng.randf(), 0.7) * grass_max_path_distance
			x = base.x + cos(ang) * dist
			z = base.y + sin(ang) * dist
		else:
			x = rng.randf_range(-half, half)
			z = rng.randf_range(-half, half)
		if absf(x) > half or absf(z) > half:
			continue
		var pd := terrain.distance_to_path(x, z, 3.0)
		if pd < (terrain.path_width * 0.55 if is_grass else 2.4):
			continue
		if _in_clearing(terrain, x, z, -3.0 if is_grass else 0.0):
			continue
		if _near_cliff_edge(terrain, z, 0.5, 2.5):
			continue
		if not is_grass and _in_exclusion(x, z):
			continue
		var sc := rng.randf_range(0.7, 1.3) if is_grass else rng.randf_range(0.9, 1.8)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc))
		transforms.append(Transform3D(b, Vector3(x, terrain.height_at(x, z) - 0.05, z)))
	_add_multimesh("Grass" if is_grass else "Bushes", mesh, transforms, not is_grass)


func _scatter_cliff_bushes(terrain: ForestTerrain, rng: RandomNumberGenerator) -> void:
	var transforms := []
	var half := terrain.size * 0.5 - 6.0
	for i in cliff_bush_count:
		var x := rng.randf_range(-half, half)
		var z := terrain.cliff_z + rng.randf_range(0.2, 2.2)
		var sc := rng.randf_range(1.3, 2.2)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.3), sc))
		transforms.append(Transform3D(b, Vector3(x, terrain.height_at(x, z) - 0.1, z)))
	_add_multimesh("CliffBushes", _bush_mesh(), transforms, true)


# ------------------------------------------------------------------ malhas

func _mat(tex: Texture2D, color: Color, alpha_cut: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = color
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if alpha_cut:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	return m


## Cilindro afinando (tronco/galho) de a até b.
func _add_tube(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, v_scale: float) -> void:
	var axis := (b - a).normalized()
	var ref := Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var u := axis.cross(ref).normalized()
	var w := axis.cross(u).normalized()
	var length := a.distance_to(b)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := u * cos(a0) + w * sin(a0)
		var d1 := u * cos(a1) + w * sin(a1)
		var p00 := a + d0 * r0
		var p01 := a + d1 * r0
		var p10 := b + d0 * r1
		var p11 := b + d1 * r1
		var u0 := float(i) / sides * 2.0
		var u1 := float(i + 1) / sides * 2.0
		var vtop := length * v_scale
		# dois triângulos (sentido horário visto de fora)
		_vert(st, p00, d0, Vector2(u0, vtop))
		_vert(st, p10, d0, Vector2(u0, 0.0))
		_vert(st, p11, d1, Vector2(u1, 0.0))
		_vert(st, p00, d0, Vector2(u0, vtop))
		_vert(st, p11, d1, Vector2(u1, 0.0))
		_vert(st, p01, d1, Vector2(u1, vtop))


## Cone (copa de pinheiro) com base em y0 e ponta em y1.
func _add_cone(st: SurfaceTool, center: Vector3, y0: float, y1: float, radius: float, sides: int) -> void:
	var tip := center + Vector3(0, y1, 0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := center + Vector3(cos(a0) * radius, y0, sin(a0) * radius)
		var p1 := center + Vector3(cos(a1) * radius, y0, sin(a1) * radius)
		var n0 := Vector3(cos(a0), 0.6, sin(a0)).normalized()
		var n1 := Vector3(cos(a1), 0.6, sin(a1)).normalized()
		# lado (sentido horário visto de fora)
		_vert(st, p1, n1, Vector2(1.0, 1.0))
		_vert(st, tip, (n0 + n1).normalized(), Vector2(0.5, 0.0))
		_vert(st, p0, n0, Vector2(0.0, 1.0))
		# fundo (virado pra baixo)
		_vert(st, p0, Vector3.DOWN, Vector2(0.0, 1.0))
		_vert(st, center + Vector3(0, y0, 0), Vector3.DOWN, Vector2(0.5, 0.5))
		_vert(st, p1, Vector3.DOWN, Vector2(1.0, 1.0))


## Bolota de folhas (octaedro amassado) pra árvore copada.
func _add_blob(st: SurfaceTool, c: Vector3, r: Vector3) -> void:
	var px := c + Vector3(r.x, 0, 0)
	var nx := c - Vector3(r.x, 0, 0)
	var py := c + Vector3(0, r.y, 0)
	var ny := c - Vector3(0, r.y, 0)
	var pz := c + Vector3(0, 0, r.z)
	var nz := c - Vector3(0, 0, r.z)
	var faces := [
		[py, px, pz], [py, pz, nx], [py, nx, nz], [py, nz, px],
		[ny, pz, px], [ny, nx, pz], [ny, nz, nx], [ny, px, nz],
	]
	for f: Array in faces:
		var a := f[0] as Vector3
		var b := f[1] as Vector3
		var d := f[2] as Vector3
		var n := (b - a).cross(d - a).normalized()
		if n.dot((a + b + d) / 3.0 - c) < 0.0:
			n = -n
			var tmp := b
			b = d
			d = tmp
		_vert(st, a, n, Vector2(0.5, 0.0))
		_vert(st, d, n, Vector2(1.0, 1.0))
		_vert(st, b, n, Vector2(0.0, 1.0))


func _vert(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2) -> void:
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)


func _pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tube(st, Vector3.ZERO, Vector3(0, 8.5, 0), 0.24, 0.06, 6, 0.5)
	var mesh := st.commit()
	mesh.surface_set_material(0, _mat(bark_texture, Color(0.85, 0.85, 0.85), false))
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels := [[2.2, 4.6, 1.7], [3.6, 6.0, 1.4], [5.0, 7.4, 1.05], [6.4, 9.0, 0.7]]
	for l: Array in levels:
		_add_cone(st, Vector3.ZERO, l[0], l[1], l[2], 7)
	st.commit(mesh)
	mesh.surface_set_material(1, _mat(foliage_texture, Color(0.75, 0.85, 0.75), false))
	return mesh


func _dead_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tube(st, Vector3.ZERO, Vector3(0.1, 7.0, 0.05), 0.22, 0.04, 6, 0.5)
	var branches := [
		[Vector3(0.05, 3.2, 0), Vector3(1.4, 4.6, 0.3)],
		[Vector3(0.06, 4.0, 0), Vector3(-1.2, 5.2, -0.6)],
		[Vector3(0.08, 5.0, 0), Vector3(0.6, 6.2, -1.1)],
		[Vector3(0.09, 5.6, 0.02), Vector3(-0.7, 6.6, 0.9)],
		[Vector3(0.04, 2.4, 0), Vector3(-1.0, 2.9, 0.8)],
	]
	for br: Array in branches:
		_add_tube(st, br[0], br[1], 0.07, 0.015, 4, 0.5)
	var mesh := st.commit()
	mesh.surface_set_material(0, _mat(bark_texture, Color(0.7, 0.68, 0.66), false))
	return mesh


func _broad_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tube(st, Vector3.ZERO, Vector3(0, 5.0, 0), 0.26, 0.12, 6, 0.5)
	_add_tube(st, Vector3(0, 3.5, 0), Vector3(1.0, 5.2, 0.4), 0.1, 0.05, 4, 0.5)
	_add_tube(st, Vector3(0, 3.8, 0), Vector3(-0.9, 5.4, -0.5), 0.1, 0.05, 4, 0.5)
	var mesh := st.commit()
	mesh.surface_set_material(0, _mat(bark_texture, Color(0.8, 0.78, 0.75), false))
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_blob(st, Vector3(0, 6.0, 0), Vector3(2.4, 1.6, 2.2))
	_add_blob(st, Vector3(1.1, 5.4, 0.5), Vector3(1.5, 1.1, 1.5))
	_add_blob(st, Vector3(-1.0, 5.6, -0.6), Vector3(1.6, 1.2, 1.4))
	_add_blob(st, Vector3(0.2, 7.0, -0.2), Vector3(1.4, 1.0, 1.4))
	st.commit(mesh)
	mesh.surface_set_material(1, _mat(foliage_texture, Color(0.8, 0.95, 0.8), false))
	return mesh


## Cartões cruzados (3 planos) com textura recortada.
func _cross_cards(width: float, height: float, tex: Texture2D, color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := PI * k / 3.0
		var dx := Vector3(cos(a), 0, sin(a)) * width * 0.5
		var p0 := -dx
		var p1 := dx
		var p2 := dx + Vector3(0, height, 0)
		var p3 := -dx + Vector3(0, height, 0)
		# As duas faces, ambas com normal pra cima: mato iluminado igual dos dois lados.
		var n := Vector3.UP
		_vert(st, p0, n, Vector2(0, 1))
		_vert(st, p3, n, Vector2(0, 0))
		_vert(st, p2, n, Vector2(1, 0))
		_vert(st, p0, n, Vector2(0, 1))
		_vert(st, p2, n, Vector2(1, 0))
		_vert(st, p1, n, Vector2(1, 1))
		_vert(st, p0, n, Vector2(0, 1))
		_vert(st, p2, n, Vector2(1, 0))
		_vert(st, p3, n, Vector2(0, 0))
		_vert(st, p0, n, Vector2(0, 1))
		_vert(st, p1, n, Vector2(1, 1))
		_vert(st, p2, n, Vector2(1, 0))
	var mesh := st.commit()
	mesh.surface_set_material(0, _mat(tex, color, true))
	return mesh


func _grass_mesh() -> ArrayMesh:
	return _cross_cards(0.9, 0.7, grass_texture, Color(0.8, 0.85, 0.75))


func _bush_mesh() -> ArrayMesh:
	return _cross_cards(1.6, 1.3, bush_texture, Color(0.75, 0.85, 0.75))


# ------------------------------------------------------------------ modelos (.gltf)

func _pick(rng: RandomNumberGenerator, count: int, weights: PackedFloat32Array) -> int:
	if weights.size() != count:
		return rng.randi() % count
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in count:
		r -= weights[i]
		if r <= 0.0:
			return i
	return count - 1


func _scale_for(rng: RandomNumberGenerator, scales: PackedVector2Array, idx: int) -> float:
	if idx < scales.size():
		return rng.randf_range(scales[idx].x, scales[idx].y)
	return rng.randf_range(0.8, 1.2)


## Sorteia um ponto válido. near_path_prob = chance de nascer perto da trilha.
## Devolve Vector2(INF, INF) se não achou.
func _find_spot(terrain: ForestTerrain, rng: RandomNumberGenerator, near_path_prob: float,
		min_path: float, near_max: float, clearing_extra: float, check_exclusion: bool) -> Vector2:
	var half := terrain.size * 0.5 - 6.0
	for attempt in 8:
		var x: float
		var z: float
		var pts := terrain.path_points
		if rng.randf() < near_path_prob and pts.size() >= 2:
			var seg := rng.randi_range(0, pts.size() - 2)
			var base := pts[seg].lerp(pts[seg + 1], rng.randf())
			var ang := rng.randf() * TAU
			var dist := min_path + pow(rng.randf(), 0.8) * near_max
			x = base.x + cos(ang) * dist
			z = base.y + sin(ang) * dist
		else:
			x = rng.randf_range(-half, half)
			z = rng.randf_range(-half, half)
		if absf(x) > half or absf(z) > half:
			continue
		if terrain.distance_to_path(x, z, min_path + 0.5) < min_path:
			continue
		if _in_clearing(terrain, x, z, clearing_extra):
			continue
		if _near_cliff_edge(terrain, z, 0.5, 2.5):
			continue
		if check_exclusion and _in_exclusion(x, z):
			continue
		return Vector2(x, z)
	return Vector2(INF, INF)


func _scatter_model_trees(terrain: ForestTerrain, rng: RandomNumberGenerator) -> void:
	var placements := []  # [modelo, Transform3D]
	var trunks := []
	var half := terrain.size * 0.5
	var cell := tree_min_spacing
	var grid := {}
	var attempts := tree_count * 6
	while placements.size() < tree_count and attempts > 0:
		attempts -= 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		if terrain.distance_to_path(x, z, tree_path_clearance + 1.0) < tree_path_clearance:
			continue
		if _in_clearing(terrain, x, z, 2.0):
			continue
		if _near_cliff_edge(terrain, z, 2.5, 3.0):
			continue
		if _in_exclusion(x, z):
			continue
		var key := Vector2i(floori(x / cell), floori(z / cell))
		var too_close := false
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var k2 := key + Vector2i(dx, dz)
				if grid.has(k2) and (grid[k2] as Vector2).distance_to(Vector2(x, z)) < tree_min_spacing:
					too_close = true
		if too_close:
			continue
		grid[key] = Vector2(x, z)
		var idx := _pick(rng, tree_models.size(), tree_model_weights)
		var sc := _scale_for(rng, tree_model_scales, idx)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.1), sc))
		var tilt_axis := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
		if tilt_axis.length_squared() > 0.01:
			b = Basis(tilt_axis.normalized(), rng.randf_range(0.0, 0.05)) * b
		var pos := Vector3(x, terrain.height_at(x, z) - 0.2, z)
		placements.append([idx, Transform3D(b, pos)])
		var trunk := tree_model_trunks[idx] if idx < tree_model_trunks.size() else 0.3
		trunks.append([pos, trunk * sc])
	_build_chunked("Trees", tree_models, placements, true, tree_draw_distance)
	_add_trunk_collisions(trunks)


func _scatter_models(terrain: ForestTerrain, rng: RandomNumberGenerator, layer: String,
		models: Array[PackedScene], weights: PackedFloat32Array, scales: PackedVector2Array,
		count: int, near_prob: float, draw_distance: float, shadows: bool) -> void:
	var placements := []
	var is_grass := layer == "Grass"
	var min_path := terrain.path_width * (0.55 if is_grass else 0.9)
	var near_max := grass_max_path_distance if is_grass else 22.0
	for i in count:
		var spot := _find_spot(terrain, rng, near_prob, min_path, near_max,
			-3.0 if is_grass else -1.0, not is_grass)
		if spot.x == INF:
			continue
		var idx := _pick(rng, models.size(), weights)
		var sc := _scale_for(rng, scales, idx)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.85, 1.15), sc))
		placements.append([idx, Transform3D(b, Vector3(spot.x, terrain.height_at(spot.x, spot.y) - 0.04, spot.y))])
	_build_chunked(layer, models, placements, shadows, draw_distance)


func _scatter_model_cliff_bushes(terrain: ForestTerrain, rng: RandomNumberGenerator) -> void:
	# Arbustos na beira do barranco (escondem a queda). Usa a 1ª planta da lista.
	var placements := []
	var half := terrain.size * 0.5 - 6.0
	var sc_range := plant_model_scales[0] if not plant_model_scales.is_empty() else Vector2(1, 1)
	for i in cliff_bush_count:
		var x := rng.randf_range(-half, half)
		var z := terrain.cliff_z + rng.randf_range(0.2, 2.2)
		var sc := rng.randf_range(sc_range.x, sc_range.y) * 1.4
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.3), sc))
		placements.append([0, Transform3D(b, Vector3(x, terrain.height_at(x, z) - 0.1, z))])
	_build_chunked("CliffBushes", plant_models, placements, false, plant_draw_distance)


func _scatter_rocks(terrain: ForestTerrain, rng: RandomNumberGenerator) -> void:
	var placements := []
	var blockers := []
	for i in rock_count:
		var spot := _find_spot(terrain, rng, 0.4, 2.8, 20.0, 0.0, true)
		if spot.x == INF:
			continue
		var idx := rng.randi() % rock_models.size()
		var sc := _scale_for(rng, rock_model_scales, idx)
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		var tilt_axis := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
		if tilt_axis.length_squared() > 0.01:
			b = Basis(tilt_axis.normalized(), rng.randf_range(0.0, 0.25)) * b
		b = b.scaled(Vector3(sc, sc, sc))
		var pos := Vector3(spot.x, terrain.height_at(spot.x, spot.y) - 0.35 * sc, spot.y)
		placements.append([idx, Transform3D(b, pos)])
		if sc > 0.45:
			blockers.append([pos, 1.1 * sc])
	_build_chunked("Rocks", rock_models, placements, true, plant_draw_distance)
	_add_trunk_collisions(blockers)


## Agrupa por (modelo, bloco) e cria um MultiMeshInstance3D por peça do modelo.
func _build_chunked(layer: String, models: Array[PackedScene], placements: Array, shadows: bool, draw_distance: float) -> void:
	var parts_cache := {}
	var buckets := {}
	for p: Array in placements:
		var idx := int(p[0])
		var t := p[1] as Transform3D
		var key := Vector3i(idx, floori(t.origin.x / chunk_size), floori(t.origin.z / chunk_size))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(t)
	for key: Vector3i in buckets:
		if not parts_cache.has(key.x):
			parts_cache[key.x] = ModelUtil.extract_parts(models[key.x])
		var center := Vector3((key.y + 0.5) * chunk_size, 0.0, (key.z + 0.5) * chunk_size)
		var list := buckets[key] as Array
		for part: Array in parts_cache[key.x]:
			var mesh := part[0] as Mesh
			var local := part[1] as Transform3D
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = list.size()
			for i in list.size():
				var t := list[i] as Transform3D
				t.origin -= center
				mm.set_instance_transform(i, t * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d_%d" % [layer, key.x, key.y, key.z]
			mmi.multimesh = mm
			mmi.position = center
			mmi.visibility_range_end = draw_distance
			mmi.visibility_range_end_margin = 6.0
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.set_meta("scatter_part", true)
			add_child(mmi)
			_built.append(mmi)


func _add_trunk_collisions(trunks: Array) -> void:
	if Engine.is_editor_hint() or trunks.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "Collisions_%d" % _built.size()
	body.set_meta("scatter_part", true)
	add_child(body)
	_built.append(body)
	for t: Array in trunks:
		var shape := CylinderShape3D.new()
		shape.radius = maxf(float(t[1]), 0.12)
		shape.height = 4.0
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = (t[0] as Vector3) + Vector3.UP * 2.0
		body.add_child(cs)

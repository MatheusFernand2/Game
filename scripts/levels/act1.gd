extends Node3D
## ATO 1 — A TRILHA
## 1. Sítio, 22h: o Paçoca late pro mato e foge pelo portão.
## 2. Beira da mata: alguma coisa anda no mato do seu lado e para quando você para.
## 3. Casa de ferramentas: rastro de sangue e a coruja na cara.
## 4. O primeiro Eco, parado entre as árvores. Some quando você apaga a lanterna
##    (ou quando chega perto, ou quando olha pra outro lado).
## 5. A perseguição: a Coisa Funda vem atrás. Você segue o latido.
## 6. A queda no barranco.
## 7. O despertar: lanterna falhando, perna doendo, relógio parado em 03:17.

enum Stage { INTRO, TRAIL, CHASE, FALLEN, END }

const SND_STEPS: Array[AudioStream] = [
	preload("res://assets/audio/footstep_dirt_1.wav"),
	preload("res://assets/audio/footstep_dirt_2.wav"),
	preload("res://assets/audio/footstep_dirt_3.wav"),
	preload("res://assets/audio/footstep_dirt_4.wav"),
]
const SND_BARKS: Array[AudioStream] = [
	preload("res://assets/audio/dog_bark_1.wav"),
	preload("res://assets/audio/dog_bark_2.wav"),
	preload("res://assets/audio/dog_bark_3.wav"),
]
const SND_CRACK := preload("res://assets/audio/branch_crack.wav")
const SND_STINGER := preload("res://assets/audio/stinger_scream.wav")
const SND_TENSION := preload("res://assets/audio/tension_rise.wav")
const SND_FALL := preload("res://assets/audio/body_fall.wav")
const SND_HISS := preload("res://assets/audio/coisa_hiss.wav")

@onready var terrain: ForestTerrain = $Terrain
@onready var player: Player = $Player
@onready var hud: GameHUD = $Player/HUD
@onready var post_fx: PostFX = $Player/PostFX
@onready var ambience: AudioStreamPlayer = $Ambience
@onready var dog: Dog = $Pacoca
@onready var coisa: CoisaFunda = $Coisa
@onready var eco_sight: EcoRig = $EcoSight
@onready var stalker: StalkerSound = $Stalker
@onready var eco_bump: EcoBump = $EcoBump
@onready var owl: Owl = $Shed/Owl
@onready var bark_beyond: AudioStreamPlayer3D = $BarkBeyond

var stage := Stage.INTRO
var _respawn := Transform3D()
var _catching := false
var _bark_beyond_active := false
var _bark_timer := 0.0
var _gate_bark_timer := 1.5
var _ambience_tween: Tween
var _rng := RandomNumberGenerator.new()

# Primeiro Eco
var _eco_active := false
var _eco_time := 0.0
var _eco_seen_time := 0.0
var _eco_unseen_time := 0.0
var _eco_light_was_off := false

# Despertar
var _limp_time := 0.0


func _ready() -> void:
	_rng.randomize()
	_snap_to_ground()
	player.footstep_sounds = SND_STEPS
	_respawn = ($Markers/Start as Node3D).global_transform
	player.teleport(_respawn)
	ambience.finished.connect(ambience.play)
	ambience.play()

	for t: ScareTrigger in [$Triggers/ForestEdge, $Triggers/StalkerOff, $Triggers/Blood,
			$Triggers/ShedInside, $Triggers/EcoSight, $Triggers/Chase, $Triggers/Fall, $Triggers/End]:
		t.triggered.connect(_on_trigger.bind(t.name))

	coisa.caught.connect(_on_caught)
	dog.lead_finished.connect(_on_dog_lead_finished)
	dog.global_position = ($Markers/DogGate as Node3D).global_position
	dog.face(player.global_position)
	eco_sight.visible = false
	eco_bump.enabled = true
	_intro()


func _snap_to_ground() -> void:
	for n in get_tree().get_nodes_in_group("snap_ground"):
		var node := n as Node3D
		if node == null:
			continue
		var p := node.global_position
		p.y = terrain.height_at(p.x, p.z) + float(node.get_meta("ground_offset", 0.0))
		node.global_position = p


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _fade_ambience(target_db: float, duration: float) -> void:
	if _ambience_tween and _ambience_tween.is_valid():
		_ambience_tween.kill()
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(ambience, "volume_db", target_db, duration)


func _process(delta: float) -> void:
	match stage:
		Stage.INTRO:
			_gate_bark_timer -= delta
			if _gate_bark_timer <= 0.0:
				_gate_bark_timer = _rng.randf_range(2.2, 3.8)
				dog.bark()
			if player.global_position.distance_to(dog.global_position) < 11.0:
				_start_trail()
		Stage.FALLEN:
			_update_limp(delta)
	if _eco_active:
		_update_eco_sighting(delta)
	if _bark_beyond_active:
		_bark_timer -= delta
		if _bark_timer <= 0.0:
			_bark_timer = _rng.randf_range(2.8, 4.5)
			bark_beyond.stream = SND_BARKS[_rng.randi() % SND_BARKS.size()]
			bark_beyond.play()
	# Segurança: deu a volta no gatilho da perseguição pelo mato.
	if stage <= Stage.TRAIL and player.global_position.z < -10.0:
		_start_chase()
	# Segurança: passou da beira do barranco sem o gatilho pegar.
	if stage < Stage.FALLEN and player.global_position.z < terrain.cliff_z - 1.2:
		_fall()
	# Segurança: caiu pra fora do mapa.
	if player.global_position.y < -60.0:
		player.teleport(_respawn)


func _on_trigger(_p: Player, trigger_name: String) -> void:
	match trigger_name:
		"ForestEdge":
			if stage <= Stage.TRAIL:
				stalker.active = true
		"StalkerOff":
			stalker.active = false
		"Blood":
			hud.show_subtitle("Sangue... é de bicho. Tem que ser de bicho.", 3.5)
			player.add_fear(0.1)
		"ShedInside":
			if is_instance_valid(owl):
				owl.fly_at(player)
			_stalker_again()
		"EcoSight":
			stalker.active = false
			if stage <= Stage.TRAIL:
				_start_eco_sighting()
		"Chase":
			if stage <= Stage.TRAIL:
				_start_chase()
		"Fall":
			_fall()
		"End":
			if stage == Stage.FALLEN:
				_end_act()


# ------------------------------------------------------------ 1. intro

func _intro() -> void:
	await _wait(1.0)
	hud.show_title_card("ECOS", "Ato 1 — A Trilha", 3.0)
	await _wait(5.5)
	if stage == Stage.INTRO:
		hud.show_subtitle("Paçoca? ...Paçoca! Volta aqui!", 3.0)
	await _wait(4.0)
	hud.show_hint("[F] lanterna    [Shift] correr    [Ctrl] agachar    [T] relógio", 7.0)


## Depois da coruja, o barulho no mato volta — agora do outro lado.
func _stalker_again() -> void:
	await _wait(8.0)
	if stage == Stage.TRAIL and not _eco_active:
		stalker.side = -1.0
		stalker.active = true


func _start_trail() -> void:
	stage = Stage.TRAIL
	var points: Array[Vector3] = []
	for m in $Markers/DogLead.get_children():
		points.append((m as Node3D).global_position)
	dog.lead(points, 13.0)
	hud.show_subtitle("Pro mato não, Paçoca... de novo não.", 3.0)


func _on_dog_lead_finished() -> void:
	# Ele some na frente. Daqui pra frente só o latido guia.
	dog.go_to(($Markers/DogFar as Node3D).global_position)
	await _wait(6.0)
	dog.visible = false
	dog.process_mode = Node.PROCESS_MODE_DISABLED


# ------------------------------------------------------------ 4. o primeiro Eco

func _start_eco_sighting() -> void:
	_eco_active = true
	_eco_time = 0.0
	_eco_seen_time = 0.0
	_eco_unseen_time = 0.0
	_eco_light_was_off = not player.flashlight_on
	eco_sight.visible = true
	eco_sight.head_twitch = true
	eco_sight.idle_sway = true
	eco_sight.look_target = player
	var target := player.global_position
	target.y = eco_sight.global_position.y
	eco_sight.look_at(target, Vector3.UP)


func _update_eco_sighting(delta: float) -> void:
	_eco_time += delta
	var head := eco_sight.global_position + Vector3.UP * 1.7
	var seen := player.camera.is_position_in_frustum(head)
	if seen:
		_eco_seen_time += delta
		_eco_unseen_time = 0.0
	else:
		_eco_unseen_time += delta
	if not player.flashlight_on:
		_eco_light_was_off = true

	var vanish := false
	# Apagou e acendeu a lanterna: ele não está mais lá.
	if _eco_light_was_off and player.flashlight_on:
		vanish = true
	# Chegou perto demais.
	if player.global_position.distance_to(eco_sight.global_position) < 13.0:
		vanish = true
	# Olhou bastante e desviou o olhar.
	if _eco_seen_time > 3.5 and _eco_unseen_time > 0.4:
		vanish = true
	if _eco_time > 40.0 and not seen:
		vanish = true
	if vanish:
		_eco_active = false
		eco_sight.visible = false
		eco_sight.head_twitch = false
		eco_sight.look_target = null
		_after_eco_vanish()


func _after_eco_vanish() -> void:
	player.add_fear(0.25)
	await _wait(1.4)
	if stage <= Stage.TRAIL:
		hud.show_subtitle("...tinha alguém ali. Tinha alguém ali parado.", 3.5)


# ------------------------------------------------------------ 5. perseguição

func _start_chase() -> void:
	stage = Stage.CHASE
	eco_bump.enabled = false
	stalker.active = false
	_eco_active = false
	eco_sight.visible = false
	_respawn = ($Markers/ChaseCheckpoint as Node3D).global_transform
	var spawn := ($Markers/CoisaSpawn as Node3D).global_position
	Game.play_sound_at(SND_CRACK, spawn + Vector3.UP, 8.0)
	player.add_fear(0.2)
	await _wait(0.7)
	hud.show_subtitle("...o que foi isso?", 2.0)
	await _wait(2.2)
	if stage != Stage.CHASE:
		return
	Game.play_sound_at(SND_HISS, spawn + Vector3.UP, 6.0, 0.8)
	Game.play_sound_2d(SND_TENSION, -6.0)
	coisa.global_position = spawn
	coisa.start_chase(player)
	player.add_fear(0.45)
	hud.show_hint("CORRE", 2.5)
	_bark_beyond_active = true
	_bark_timer = 1.0


func _on_caught(_p: Player) -> void:
	if stage != Stage.CHASE or _catching:
		return
	_catching = true
	coisa.stop_chase()
	player.controls_enabled = false
	Game.play_sound_2d(SND_STINGER, 0.0)
	post_fx.glitch(1.0)
	player.shake(0.12, 0.6)
	player.add_fear(0.9)
	hud.fade_to(1.0, 0.08)
	await _wait(2.5)
	if stage != Stage.CHASE:
		_catching = false
		return
	# Ninguém morre: você "acorda" de volta mais atrás, com menos pilha.
	player.teleport(_respawn)
	var lost := minf(25.0, maxf(player.battery - 12.0, 0.0))
	player.add_battery(-lost)
	await _wait(0.8)
	hud.fade_to(0.0, 2.0)
	player.controls_enabled = true
	hud.show_subtitle("...ainda tá aqui. Ainda tá perto.", 3.0)
	await _wait(3.5)
	if stage == Stage.CHASE:
		coisa.global_position = ($Markers/CoisaSpawn as Node3D).global_position
		coisa.start_chase(player)
	_catching = false


# ------------------------------------------------------------ 6. a queda

func _fall() -> void:
	if stage >= Stage.FALLEN:
		return
	stage = Stage.FALLEN
	coisa.stop_chase()
	stalker.active = false
	eco_bump.enabled = false
	_eco_active = false
	eco_sight.visible = false
	_bark_beyond_active = false
	bark_beyond.stop()
	dog.visible = false
	player.controls_enabled = false
	player.set_physics_process(false)

	# O barranco é sempre pro "norte" (-Z), não importa pra onde ele olhava.
	var forward := Vector3.FORWARD
	var start := player.global_position
	Game.play_sound_2d(SND_FALL, 0.0)
	player.camera_roll_target = 65.0
	var tw := create_tween()
	tw.tween_property(player, "global_position", start + forward * 1.2 + Vector3.DOWN * 0.4, 0.25)
	tw.parallel().tween_property(player.head, "rotation_degrees:x", -70.0, 0.5)
	tw.tween_property(player, "global_position", start + forward * 2.6 + Vector3.DOWN * 6.0, 0.35) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished

	# Impacto: preto e silêncio.
	hud.fade_to(1.0, 0.04)
	player.shake(0.15, 0.3)
	ambience.volume_db = -80.0
	Game.watch_stopped = true
	await _wait(6.5)
	_wake_up()


# ------------------------------------------------------------ 7. o despertar

func _wake_up() -> void:
	var wake := $Markers/Wake as Node3D
	_respawn = wake.global_transform
	player.teleport(wake.global_transform)
	player.set_physics_process(true)
	# Deitado de costas, olhando pro céu, entre as folhas.
	player.forced_eye_height = 0.22
	player.camera_roll_target = 8.0
	player.snap_camera(0.22, 8.0)
	player.set_look(wake.global_rotation_degrees.y, 72.0)
	player.flashlight_on = true
	player.force_flicker(4.0)
	hud.fade_to(0.0, 3.5)
	_fade_ambience(-12.0, 8.0)

	# A câmera fica no chão um segundo a mais do que deveria.
	await _wait(5.0)
	var tw := create_tween()
	tw.tween_property(player.head, "rotation_degrees:x", 8.0, 2.2).set_trans(Tween.TRANS_SINE)
	player.forced_eye_height = 0.9
	player.camera_roll_target = 0.0
	await tw.finished
	player.set_look(wake.global_rotation_degrees.y, 8.0)
	player.forced_eye_height = -1.0
	await _wait(1.0)
	hud.show_subtitle("Caralho... achei que eu tinha morrido.", 3.5)
	player.controls_enabled = true
	player.sprint_locked = true
	player.speed_multiplier = 0.6
	player.limp_amount = 1.0
	_limp_time = 0.0
	await _wait(5.0)
	hud.show_watch()
	await _wait(0.6)
	hud.show_subtitle("Três e dezessete? Apaguei esse tempo todo?", 3.5)
	await _wait(4.0)
	# O latido agora vem do fundo do barranco, mais pra frente.
	bark_beyond.global_position = ($Markers/BarkEnd as Node3D).global_position
	_bark_beyond_active = true
	_bark_timer = 0.5
	await _wait(2.0)
	hud.show_subtitle("Paçoca...?", 2.0)


## Mancando por uns 2 minutos. Depois a dor some... rápido demais.
func _update_limp(delta: float) -> void:
	if not player.controls_enabled:
		return
	_limp_time += delta
	if _limp_time > 120.0:
		var t := clampf((_limp_time - 120.0) / 10.0, 0.0, 1.0)
		player.limp_amount = 1.0 - t
		player.speed_multiplier = lerpf(0.6, 1.0, t)
		if t >= 1.0:
			player.sprint_locked = false


func _end_act() -> void:
	stage = Stage.END
	_bark_beyond_active = false
	player.controls_enabled = false
	await hud.show_end_card("Fim do Ato 1", "versão de teste — continua...")
	await _wait(4.0)
	Game.go_to_menu()

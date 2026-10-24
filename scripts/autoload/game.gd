extends Node
## Autoload global do jogo.
## Registra os controles, guarda configurações e cuida da pausa.

signal paused_changed(is_paused: bool)
signal volume_changed(volume: float)

const SETTINGS_PATH := "user://settings.cfg"
const VOLUME_STEP := 0.1

## Volume geral de 0 a 1 (começa baixo; o jogo é alto de propósito).
var master_volume: float = 0.4
## Sensibilidade do mouse (graus por pixel).
var mouse_sensitivity: float = 0.12
var invert_y: bool = false

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const ACT1_SCENE := "res://scenes/levels/act1_trilha.tscn"
const TEST_HOUSE_SCENE := "res://scenes/levels/test_house.tscn"

# ------------------------------------------------------------ estado da partida
## Quantas trombadas de Eco já aconteceram (máximo 2 no jogo inteiro).
var eco_bumps_done := 0
## O relógio do protagonista parou na queda?
var watch_stopped := false
## Segundos de jogo desde o início da partida (pro relógio andar antes da queda).
var play_time := 0.0

# Ação -> lista de teclas (physical keycode) ou botões do mouse.
const KEY_BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"interact": [KEY_E],
	"flashlight": [KEY_F],
	"pause": [KEY_ESCAPE],
	"quit_from_pause": [KEY_Q],
	"toggle_fullscreen": [KEY_F11],
	"volume_down": [KEY_MINUS, KEY_KP_SUBTRACT],
	"volume_up": [KEY_EQUAL, KEY_KP_ADD],
	"watch": [KEY_T],
}

const MOUSE_BINDINGS := {
	"interact": [MOUSE_BUTTON_LEFT],
	"flashlight": [MOUSE_BUTTON_RIGHT],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	load_settings()
	_apply_volume()


func _register_inputs() -> void:
	for action: String in KEY_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in KEY_BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action: String in MOUSE_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for button: int in MOUSE_BINDINGS[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("volume_down"):
		set_master_volume(master_volume - VOLUME_STEP)
		save_settings()
	elif event.is_action_pressed("volume_up"):
		set_master_volume(master_volume + VOLUME_STEP)
		save_settings()
	elif event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
	elif get_tree().paused and event.is_action_pressed("quit_from_pause"):
		quit_game()


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


## Começa uma partida nova do zero.
func new_game() -> void:
	eco_bumps_done = 0
	watch_stopped = false
	play_time = 0.0
	go_to(ACT1_SCENE)


## Troca de cena com a pausa desligada.
func go_to(scene_path: String) -> void:
	get_tree().paused = false
	paused_changed.emit(false)
	get_tree().change_scene_to_file(scene_path)


func go_to_menu() -> void:
	save_settings()
	go_to(MENU_SCENE)


## Hora que aparece no relógio de pulso. Antes da queda anda (rápido);
## depois da queda fica parado em 03:17 pra sempre.
func watch_text() -> String:
	if watch_stopped:
		return "03:17"
	# 22:10 + 12 minutos de relógio por minuto de jogo, travado antes de 03:17.
	var minutes := mini(22 * 60 + 10 + int(play_time / 5.0), 24 * 60 + 3 * 60 + 16)
	return "%02d:%02d" % [floori(minutes / 60.0) % 24, minutes % 60]


func quit_game() -> void:
	save_settings()
	get_tree().quit()


# ------------------------------------------------------------ configurações

## Volume geral, de 0 (mudo) a 1 (máximo).
func set_master_volume(value: float) -> void:
	master_volume = clampf(snappedf(value, 0.01), 0.0, 1.0)
	_apply_volume()
	volume_changed.emit(master_volume)


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.02, 0.5)


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.001)))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	mouse_sensitivity = float(cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(cfg.get_value("controls", "invert_y", invert_y))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.save(SETTINGS_PATH)


func set_paused(value: bool) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.is_in_group("no_pause"):
		return
	get_tree().paused = value
	if value:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		save_settings()
	paused_changed.emit(value)


## Toca um som 3D solto no mundo e apaga o player quando terminar.
func play_sound_at(stream: AudioStream, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var scene := get_tree().current_scene
	if scene == null or stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 6.0
	p.max_distance = 60.0
	p.attenuation_filter_cutoff_hz = 2500.0
	scene.add_child(p)
	p.global_position = position
	p.finished.connect(p.queue_free)
	p.play()


## Toca um som 2D (sem posição) — para stingers e coisas "dentro da cabeça".
func play_sound_2d(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var scene := get_tree().current_scene
	if scene == null or stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

extends Control
## Tela inicial: ECOS. Novo jogo, casa de teste, volume, sair.

const AMBIENCE := preload("res://assets/audio/forest_night_loop.wav")
const CLICK := preload("res://assets/audio/flashlight_click.wav")

var _title: Label
var _volume_label: Label
var _flicker := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("no_pause")
	_rng.randomize()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.012)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	_title = _label("ECOS", 72, Color(0.82, 0.8, 0.74))
	box.add_child(_title)
	box.add_child(_label("ninguém sai da mata", 15, Color(0.45, 0.43, 0.4)))
	var space := Control.new()
	space.custom_minimum_size = Vector2(0, 36)
	box.add_child(space)

	var play := _button("Novo jogo")
	play.pressed.connect(_on_play)
	box.add_child(play)
	var test := _button("Casa de teste")
	test.pressed.connect(_on_test)
	box.add_child(test)

	_volume_label = _label("", 15, Color(0.6, 0.58, 0.54))
	box.add_child(_volume_label)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 100.0
	vol.step = 1.0
	vol.value = Game.master_volume * 100.0
	vol.custom_minimum_size = Vector2(300, 24)
	vol.value_changed.connect(_on_volume)
	box.add_child(vol)
	_on_volume(vol.value)

	var quit := _button("Sair")
	quit.pressed.connect(Game.quit_game)
	box.add_child(quit)
	box.add_child(_label("Use fone de ouvido. Jogue no escuro.", 13, Color(0.4, 0.38, 0.36)))

	play.grab_focus()

	var amb := AudioStreamPlayer.new()
	amb.stream = AMBIENCE
	amb.volume_db = -14.0
	add_child(amb)
	amb.play()
	amb.finished.connect(amb.play)


func _process(delta: float) -> void:
	# Título falhando como lâmpada velha.
	_flicker -= delta
	if _flicker <= 0.0:
		_flicker = _rng.randf_range(0.05, 3.0)
		_title.modulate.a = 1.0 if _rng.randf() > 0.25 else _rng.randf_range(0.1, 0.5)


func _on_play() -> void:
	_click()
	await _show_loading()
	Game.new_game()


func _on_test() -> void:
	_click()
	await _show_loading()
	Game.go_to(Game.TEST_HOUSE_SCENE)


## A mata demora uns segundos pra ser gerada: avisa antes de travar.
func _show_loading() -> void:
	for child in get_children():
		if child is CenterContainer:
			child.visible = false
	var l := _label("carregando...", 16, Color(0.5, 0.48, 0.45))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	await get_tree().process_frame
	await get_tree().process_frame


func _on_volume(value: float) -> void:
	Game.set_master_volume(value / 100.0)
	_volume_label.text = "Volume: %d%%" % int(value)


func _click() -> void:
	Game.save_settings()
	var p := AudioStreamPlayer.new()
	p.stream = CLICK
	p.volume_db = -8.0
	get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _label(text: String, size: int, color: Color) -> Label:
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = 2
	settings.outline_color = Color.BLACK
	var l := Label.new()
	l.text = text
	l.label_settings = settings
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 40)
	return b

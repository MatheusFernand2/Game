extends CanvasLayer
## HUD mínimo: ponto de mira, texto de interação, bateria, pausa e fade.
## Pouca interface = mais imersão = mais medo.

@onready var prompt: Label = $Prompt
@onready var battery_label: Label = $Battery
@onready var crosshair: Control = $Crosshair
@onready var pause_panel: Control = $PausePanel
@onready var fade_rect: ColorRect = $Fade
@onready var subtitle: Label = $Subtitle

var _battery_visible_time := 0.0
var _subtitle_time := 0.0
var _volume_label: Label
var _volume_slider: HSlider
var _volume_toast: Label
var _volume_toast_time := 0.0
var _sens_label: Label
var _continue_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	prompt.text = ""
	subtitle.text = ""
	battery_label.modulate.a = 0.0
	_build_pause_menu()
	_build_volume_toast()
	Game.paused_changed.connect(_on_paused_changed)
	Game.volume_changed.connect(_on_volume_changed)

	var player := get_parent() as Player
	if player:
		player.interact_prompt_changed.connect(_on_prompt_changed)
		player.battery_changed.connect(_on_battery_changed)

	# Começa no preto e clareia devagar.
	fade_rect.color.a = 1.0
	fade_to(0.0, 3.0)


func _process(delta: float) -> void:
	if _battery_visible_time > 0.0:
		_battery_visible_time -= delta
		battery_label.modulate.a = minf(1.0, battery_label.modulate.a + delta * 3.0)
	else:
		battery_label.modulate.a = maxf(0.0, battery_label.modulate.a - delta * 1.5)

	if _volume_toast_time > 0.0:
		_volume_toast_time -= delta
		_volume_toast.modulate.a = 1.0
	else:
		_volume_toast.modulate.a = maxf(0.0, _volume_toast.modulate.a - delta * 2.0)

	if _subtitle_time > 0.0:
		_subtitle_time -= delta
		if _subtitle_time <= 0.0:
			var tw := create_tween()
			tw.tween_property(subtitle, "modulate:a", 0.0, 0.8)


func _on_prompt_changed(text: String) -> void:
	prompt.text = text
	crosshair.modulate.a = 0.9 if text != "" else 0.35


func _on_battery_changed(percent: float) -> void:
	battery_label.text = "BATERIA %d%%" % int(round(percent))
	_battery_visible_time = 2.5


func _on_paused_changed(is_paused: bool) -> void:
	pause_panel.visible = is_paused
	if is_paused:
		_volume_slider.set_value_no_signal(Game.master_volume * 100.0)
		_update_volume_text(Game.master_volume)
		_continue_button.grab_focus()


func _on_volume_changed(volume: float) -> void:
	_update_volume_text(volume)
	if _volume_slider:
		_volume_slider.set_value_no_signal(volume * 100.0)
	# Teclas - e + fora do menu: mostra o volume no canto.
	if not get_tree().paused:
		_volume_toast.text = "VOLUME %d%%" % int(round(volume * 100.0))
		_volume_toast_time = 1.5


func _update_volume_text(volume: float) -> void:
	if _volume_label:
		_volume_label.text = "Volume: %d%%" % int(round(volume * 100.0))


## Escurece/clareia a tela. alpha 1 = preto total.
func fade_to(alpha: float, duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", alpha, duration)
	return tw


## Mostra uma legenda/pensamento do personagem por alguns segundos.
func show_subtitle(text: String, duration: float = 3.5) -> void:
	subtitle.text = text
	subtitle.modulate.a = 1.0
	_subtitle_time = duration


# ------------------------------------------------------------ menu de pausa

func _make_label(text: String, size: int) -> Label:
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = Color(0.8, 0.76, 0.7)
	settings.outline_size = 3
	settings.outline_color = Color.BLACK
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_slider(min_value: float, max_value: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 16)
	return slider


func _build_pause_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)

	box.add_child(_make_label("PAUSADO", 18))
	box.add_child(Control.new())  # espaço

	# Volume
	_volume_label = _make_label("", 11)
	box.add_child(_volume_label)
	_volume_slider = _make_slider(0.0, 100.0, 1.0, Game.master_volume * 100.0)
	_volume_slider.value_changed.connect(func(v: float) -> void: Game.set_master_volume(v / 100.0))
	box.add_child(_volume_slider)
	_update_volume_text(Game.master_volume)

	# Sensibilidade do mouse
	_sens_label = _make_label("", 11)
	box.add_child(_sens_label)
	var sens := _make_slider(0.02, 0.4, 0.01, Game.mouse_sensitivity)
	sens.value_changed.connect(_on_sensitivity_changed)
	box.add_child(sens)
	_on_sensitivity_changed(Game.mouse_sensitivity)

	box.add_child(Control.new())

	_continue_button = Button.new()
	_continue_button.text = "Continuar"
	_continue_button.pressed.connect(func() -> void: Game.set_paused(false))
	box.add_child(_continue_button)

	var quit := Button.new()
	quit.text = "Sair do jogo"
	quit.pressed.connect(Game.quit_game)
	box.add_child(quit)

	box.add_child(_make_label("Atalhos:  - / + volume   F11 tela cheia", 9))


func _on_sensitivity_changed(value: float) -> void:
	Game.set_mouse_sensitivity(value)
	_sens_label.text = "Sensibilidade do mouse: %.2f" % value


func _build_volume_toast() -> void:
	_volume_toast = _make_label("", 11)
	_volume_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_volume_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_volume_toast.offset_left = -150.0
	_volume_toast.offset_right = -12.0
	_volume_toast.offset_top = 10.0
	_volume_toast.offset_bottom = 28.0
	_volume_toast.modulate.a = 0.0
	add_child(_volume_toast)

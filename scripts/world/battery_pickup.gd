extends StaticBody3D
## Pilhas para a lanterna.

@export var amount: float = 45.0
@export var pickup_sound: AudioStream


func get_interact_text() -> String:
	return "[E] Pegar pilhas"


func interact(player: Node3D) -> void:
	if player is Player:
		(player as Player).add_battery(amount)
	if pickup_sound:
		Game.play_sound_2d(pickup_sound, -6.0)
	queue_free()

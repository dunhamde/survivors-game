extends Label

const REFRESH_INTERVAL := 0.25
var _refresh_in := 0.0


func _ready() -> void:
	# Reflect option changes immediately, including while the menu pauses combat.
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.ensure_loaded()
	visible = GameSettings.show_fps


func _process(delta: float) -> void:
	visible = GameSettings.show_fps
	if not visible:
		_refresh_in = 0.0
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		text = "FPS %d" % Engine.get_frames_per_second()
		_refresh_in = REFRESH_INTERVAL

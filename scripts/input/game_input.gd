class_name GameInput
extends RefCounted


static func configure(settings: GameSettings) -> void:
	if not InputMap.has_action("walk"):
		InputMap.add_action("walk")
	InputMap.action_erase_events("walk")
	for key: int in [settings.walk_key, KEY_ENTER, KEY_KP_ENTER]:
		var event := InputEventKey.new()
		event.keycode = key
		InputMap.action_add_event("walk", event)

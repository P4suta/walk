class_name SaveCodec
extends RefCounted

const FORMAT: int = 1


static func encode(state: GameState, settings: GameSettings) -> String:
	var purchases: Array[String] = []
	for count: int in state.purchases:
		purchases.append(str(count))
	var data: Dictionary = {
		"format": FORMAT,
		"state":
		{
			"steps": str(state.steps),
			"total_steps": str(state.total_steps),
			"distance_m": state.distance_m,
			"chapter_distance_m": state.chapter_distance_m,
			"chapter": str(state.chapter),
			"purchases": purchases,
			"reached_count": str(state.reached_count),
			"visited_count": str(state.visited_count),
			"home": state.home,
			"play_time_s": state.play_time_s,
			"auto_fraction": state.auto_fraction,
		},
		"settings":
		{
			"audio_enabled": settings.audio_enabled,
			"hold_to_walk": settings.hold_to_walk,
			"walk_key": str(settings.walk_key),
			"music_volume": settings.music_volume,
			"effects_volume": settings.effects_volume,
		},
	}
	return JSON.stringify(data, "\t", true, true)


static func decode(text: String, route: RouteDef) -> SaveResult:
	var parser := JSON.new()
	if text.length() > 65536 or parser.parse(text) != OK:
		return SaveResult.new(SaveResult.Status.INVALID, "The save is not valid JSON.")
	var root: Variant = parser.data
	if not root is Dictionary:
		return SaveResult.new(SaveResult.Status.INVALID, "The save has no record.")
	if (
		not SaveSchema.format_valid(root.get("format"), FORMAT)
		or not root.get("state") is Dictionary
	):
		return SaveResult.new(SaveResult.Status.INVALID, "The save format is unsupported.")
	var data: Dictionary = root.state
	if (
		not root.get("settings") is Dictionary
		or not SaveSchema.state_shape_valid(data)
		or not SaveSchema.settings_valid(root.settings)
	):
		return SaveResult.new(SaveResult.Status.INVALID, "The save fields are invalid.")
	var state := GameState.new()
	state.steps = String(data.steps).to_int()
	state.total_steps = String(data.total_steps).to_int()
	state.distance_m = float(data.distance_m)
	state.chapter_distance_m = float(data.chapter_distance_m)
	state.chapter = String(data.chapter).to_int()
	state.purchases.clear()
	for value: Variant in data.purchases:
		state.purchases.append(String(value).to_int())
	state.reached_count = String(data.reached_count).to_int()
	state.visited_count = String(data.visited_count).to_int()
	state.home = data.home
	state.play_time_s = float(data.play_time_s)
	state.auto_fraction = float(data.auto_fraction)
	if not SaveSchema.state_valid(state, route):
		return SaveResult.new(SaveResult.Status.INVALID, "The save progression is inconsistent.")
	var settings := GameSettings.new()
	settings.audio_enabled = root.settings.audio_enabled
	settings.hold_to_walk = root.settings.hold_to_walk
	settings.walk_key = String(root.settings.walk_key).to_int()
	settings.music_volume = float(root.settings.music_volume)
	settings.effects_volume = float(root.settings.effects_volume)
	var result := SaveResult.new(SaveResult.Status.LOADED)
	result.state = state
	result.settings = settings
	return result

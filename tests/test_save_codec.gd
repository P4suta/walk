extends GutTest

var route: RouteDef = preload("res://data/route.tres")


func test_round_trip_preserves_large_integer_and_settings() -> void:
	var state: GameState = GameRules.walk(GameState.new(), 9007199254740993, route)
	var settings := GameSettings.new()
	settings.walk_key = KEY_W
	settings.hold_to_walk = true
	settings.music_volume = 0.25
	var encoded: String = SaveCodec.encode(state, settings)
	var result: SaveResult = SaveCodec.decode(encoded, route)
	assert_eq(result.status, SaveResult.Status.LOADED)
	if result.state == null:
		return
	assert_eq(result.state.steps, state.steps)
	assert_eq(result.state.total_steps, state.total_steps)
	assert_eq(result.settings.walk_key, KEY_W)
	assert_true(result.settings.hold_to_walk)
	assert_eq(result.settings.music_volume, 0.25)


func test_corrupt_values_are_rejected() -> void:
	var texts: Array[String] = ["", "null", "[]", "{", '{"format": 999}']
	for text: String in texts:
		assert_eq(SaveCodec.decode(text, route).status, SaveResult.Status.INVALID)


func test_full_signed_integer_range_survives_json() -> void:
	var state: GameState = GameRules.walk(GameState.new(), GameRules.MAX_STEPS, route)
	var resumed: SaveResult = SaveCodec.decode(SaveCodec.encode(state, GameSettings.new()), route)
	assert_eq(resumed.status, SaveResult.Status.LOADED)
	assert_eq(resumed.state.total_steps, GameRules.MAX_STEPS)
	assert_eq(resumed.state.steps, GameRules.MAX_STEPS)


func test_invalid_fields_and_progression_are_rejected() -> void:
	var encoded: String = SaveCodec.encode(GameState.new(), GameSettings.new())
	var fixtures: Array[Array] = [
		["steps", "9223372036854775808"],
		["steps", 0.0],
		["total_steps", "-1"],
		["chapter", "5"],
		["reached_count", "1"],
		["visited_count", "1"],
		["distance_m", -1.0],
		["auto_fraction", 1.0],
		["purchases", ["0", "0", "0", "0", "0"]]
	]
	for fixture: Array in fixtures:
		var data: Dictionary = JSON.parse_string(encoded) as Dictionary
		data.state[fixture[0]] = fixture[1]
		assert_eq(SaveCodec.decode(JSON.stringify(data), route).status, SaveResult.Status.INVALID)
	for version: Variant in ["1", true, [], {}, null]:
		var data: Dictionary = JSON.parse_string(encoded) as Dictionary
		data.format = version
		assert_eq(SaveCodec.decode(JSON.stringify(data), route).status, SaveResult.Status.INVALID)

class_name SaveSchema
extends RefCounted


static func format_valid(value: Variant, expected: int) -> bool:
	if not value is float and not value is int:
		return false
	return is_finite(float(value)) and float(value) == expected


static func decimal(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	if text.is_empty() or text.length() > 19 or text.length() > 1 and text.begins_with("0"):
		return false
	for index: int in range(text.length()):
		if text.unicode_at(index) < 48 or text.unicode_at(index) > 57:
			return false
	return text.length() < 19 or text <= str(GameRules.MAX_STEPS)


static func finite_number(value: Variant, maximum: float = 1.0e300) -> bool:
	if not value is float and not value is int:
		return false
	return is_finite(float(value)) and float(value) >= 0.0 and float(value) <= maximum


static func settings_valid(data: Dictionary) -> bool:
	return (
		data.has_all(
			["audio_enabled", "hold_to_walk", "walk_key", "music_volume", "effects_volume"]
		)
		and data.audio_enabled is bool
		and data.hold_to_walk is bool
		and decimal(data.walk_key)
		and GameSettings.valid_walk_key(String(data.walk_key).to_int())
		and finite_number(data.music_volume, 1.0)
		and finite_number(data.effects_volume, 1.0)
	)


static func state_shape_valid(data: Dictionary) -> bool:
	var integer_fields: Array[String] = [
		"steps", "total_steps", "chapter", "reached_count", "visited_count"
	]
	for field: String in integer_fields:
		if not decimal(data.get(field)):
			return false
	var number_fields: Array[String] = [
		"distance_m", "chapter_distance_m", "play_time_s", "auto_fraction"
	]
	for field: String in number_fields:
		if not finite_number(data.get(field)):
			return false
	if not data.get("home") is bool or not data.get("purchases") is Array:
		return false
	var purchases: Array = data.purchases
	if purchases.size() != 6:
		return false
	for value: Variant in purchases:
		if not decimal(value) or String(value).to_int() > 400:
			return false
	return true


static func state_valid(state: GameState, route: RouteDef) -> bool:
	if state.chapter >= route.chapters.size() or state.steps > state.total_steps:
		return false
	var chapter: ChapterDef = route.chapters[state.chapter]
	if (
		state.chapter_distance_m > chapter.length_m()
		or state.distance_m < state.chapter_distance_m
		or state.auto_fraction >= 1.0
		or state.play_time_s > 1.0e15
	):
		return false
	if (
		state.visited_count < route.chapter_start(state.chapter)
		or state.visited_count > state.reached_count
		or state.reached_count != route.reached_at(state.chapter, state.chapter_distance_m)
		or state.home != (state.visited_count == route.sight_count())
	):
		return false
	var spent: int = 0
	for index: int in range(state.purchases.size()):
		for owned: int in range(state.purchases[index]):
			var cost: int = GameRules.price(index, owned)
			if cost < 0 or spent > GameRules.MAX_STEPS - cost:
				return false
			spent += cost
	for index: int in range(state.chapter):
		var cost: int = route.chapters[index].gate_price
		if spent > GameRules.MAX_STEPS - cost:
			return false
		spent += cost
	return state.total_steps - state.steps == spent

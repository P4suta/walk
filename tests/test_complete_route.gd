extends GutTest

var route: RouteDef = preload("res://data/route.tres")


func test_every_sight_and_gate_through_normal_progression_then_keep_walking() -> void:
	var state: GameState = GameRules.walk(GameState.new(), 10000, route)
	for index: int in range(6):
		var bought: ActionResult = GameRules.purchase(state, index)
		assert_eq(bought.status, ActionResult.Status.OK)
		state = bought.state
	var visited: Array[String] = []
	for chapter_index: int in range(5):
		var chapter: ChapterDef = route.chapters[chapter_index]
		var remaining: float = chapter.length_m() - state.chapter_distance_m
		var count: int = ceili(remaining / GameRules.stride_m(state)) + 1
		state = GameRules.walk(state, count, route)
		while state.visited_count < state.reached_count:
			visited.append(route.sight(state.visited_count).title)
			state = GameRules.finish_sight(state, route)
		assert_true(SaveSchema.state_valid(state, route))
		if chapter_index < 4:
			if state.steps < chapter.gate_price:
				state = GameRules.walk(state, chapter.gate_price - state.steps, route)
			var opened: ActionResult = GameRules.open_gate(state, route)
			assert_eq(opened.status, ActionResult.Status.OK)
			state = opened.state
			assert_eq(state.chapter, chapter_index + 1)
			assert_eq(state.chapter_distance_m, 0.0)
	assert_eq(visited.size(), 248)
	assert_true(state.home)
	assert_eq(visited.front(), "わが家")
	assert_eq(visited.back(), "竜")
	var total: int = state.total_steps
	var distance: float = state.distance_m
	state = GameRules.walk(state, 10, route)
	assert_eq(state.total_steps, total + 10)
	assert_gt(state.distance_m, distance)
	assert_eq(state.visited_count, 248)
	assert_eq(state.purchases, [1, 1, 1, 1, 1, 1])
	assert_true(SaveSchema.state_valid(state, route))
	var resumed: SaveResult = SaveCodec.decode(SaveCodec.encode(state, GameSettings.new()), route)
	assert_eq(resumed.status, SaveResult.Status.LOADED)
	assert_true(resumed.state.home)

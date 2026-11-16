extends GutTest

var game: GameController
var store: SaveStore


func before_each() -> void:
	store = SaveStore.new("user://walk-interface-test.json")
	store.erase()
	var muted := GameSettings.new()
	muted.audio_enabled = false
	assert_true(store.write_save(GameState.new(), muted, GameController.ROUTE))
	game = GameController.new()
	game.save_store = store
	add_child_autofree(game)
	game.set_process(false)
	await get_tree().process_frame


func after_each() -> void:
	store.erase()


func test_native_controls_fit_the_design_height() -> void:
	var button: Button = _button("強化")
	assert_eq(button.size.y, 24.0, str(button.get_theme_font("font").get_height(16)))
	game.panels.open(PanelHost.View.SETTINGS)
	await get_tree().process_frame
	assert_eq(_button("とじる").size.y, 24.0)
	assert_lte(game.notice.position.y + game.notice.size.y, 180.0)


func test_setting_key_capture_can_be_cancelled_without_walking() -> void:
	game.panels.open(PanelHost.View.KEY_CAPTURE)
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	game._input(event)
	assert_eq(game.settings.walk_key, KEY_SPACE)
	assert_eq(game.state.steps, 0)
	assert_eq(game.panels.view, PanelHost.View.SETTINGS)


func test_walk_animation_returns_to_standing_after_four_tenths() -> void:
	game.manual_step()
	game.landscape._process(0.0)
	assert_true(game.landscape.traveler.texture.resource_path.ends_with("7e601.svg"))
	for index: int in range(4):
		game.landscape._process(0.1)
	assert_true(game.landscape.traveler.texture.resource_path.ends_with("3c930.svg"))
	game.manual_step()
	game.landscape._process(1.0)
	assert_true(game.landscape.traveler.texture.resource_path.ends_with("3c930.svg"))


func test_shop_operation_does_not_also_walk() -> void:
	game.state = GameRules.walk(game.state, 10, GameController.ROUTE)
	game.panels.open(PanelHost.View.SHOES)
	game.panels.rows[0].pressed.emit()
	assert_eq(game.state.steps, 0)
	assert_eq(game.state.total_steps, 10)
	assert_eq(game.state.purchases[0], 1)


func test_focused_row_handles_enter_without_an_extra_step() -> void:
	game.state = GameRules.walk(game.state, 10, GameController.ROUTE)
	game.panels.open(PanelHost.View.SHOES)
	game.panels.rows[0].grab_focus()
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame
	assert_eq(game.state.steps, 0)
	assert_eq(game.state.total_steps, 10)
	assert_eq(game.state.purchases[0], 1)


func test_completed_part_keeps_its_landscape_until_the_gate_opens() -> void:
	game.state = GameRules.walk(game.state, 2000000, GameController.ROUTE)
	for index: int in range(40):
		game.state = GameRules.finish_sight(game.state, GameController.ROUTE)
	game._update_display(1.0)
	assert_eq(game.landscape.region.key, "seaside")
	game.open_gate()
	game._update_display(1.0)
	assert_eq(game.landscape.region.key, "east_asia")


func test_open_panels_keep_focus_out_of_covered_navigation() -> void:
	game.panels.open(PanelHost.View.SETTINGS)
	assert_eq(_button("強化").focus_mode, Control.FOCUS_NONE)
	game.panels.open(PanelHost.View.CLOSED)
	assert_eq(_button("強化").focus_mode, Control.FOCUS_ALL)


func test_hold_repeats_four_times_per_second_and_sleep_adds_nothing() -> void:
	game.settings.hold_to_walk = true
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	game._unhandled_input(event)
	game.advance_time(0.5)
	game.advance_time(0.5)
	assert_eq(game.state.total_steps, 5)
	game.advance_time(3600.0)
	assert_eq(game.state.total_steps, 5)
	assert_eq(game.state.play_time_s, 1.0)


func test_erase_requires_confirmation_and_resets_settings() -> void:
	game.manual_step()
	game.settings.walk_key = KEY_W
	game.panels.open(PanelHost.View.ERASE)
	game.panels.cancel()
	assert_eq(game.state.steps, 1)
	game.panels.open(PanelHost.View.ERASE)
	game.panels.erase_requested.emit()
	assert_eq(game.state.steps, 0)
	assert_eq(game.settings.walk_key, KEY_SPACE)
	assert_eq(store.read_save(GameController.ROUTE).state.total_steps, 0)


func test_cancel_erase_preserves_the_corrupt_save_hold() -> void:
	game.panels.load_failed = true
	game.panels.open(PanelHost.View.ERASE)
	game.panels.cancel()
	assert_eq(game.panels.view, PanelHost.View.SAVE_ERROR)
	game.panels.cancel()
	assert_eq(game.panels.view, PanelHost.View.SAVE_ERROR)


func test_shop_price_inverts_when_affordable() -> void:
	game.panels.open(PanelHost.View.SHOES)
	var price: Label = game.panels.rows[0].get_node("Price") as Label
	assert_eq(price.text, "あと10歩")
	assert_false((price.get_theme_stylebox("normal") as StyleBoxFlat).draw_center)
	game.state = GameRules.walk(game.state, 10, GameController.ROUTE)
	game._update_display(0.0)
	assert_eq(price.text, "10歩")
	assert_true((price.get_theme_stylebox("normal") as StyleBoxFlat).draw_center)
	assert_eq(price.get_theme_color("font_color"), Color.WHITE)


func _button(text: String) -> Button:
	for node: Node in game.hud.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == text:
			return button
	return null

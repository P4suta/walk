class_name PackageSmoke
extends VerificationRunner

var _game: GameController
var _failures: PackedStringArray = PackedStringArray()
var _gallery: RenderGallery


func run(game: Node) -> void:
	if not game is GameController:
		push_error("The verification runner requires the game controller.")
		get_tree().quit(1)
		return
	_game = game as GameController
	_game.set_process(false)
	_check(
		ContentCheck.errors(GameController.ROUTE).is_empty(),
		"All packaged artwork and route data must load."
	)
	_game.get_window().size = Vector2i(640, 360)
	await get_tree().process_frame
	_check(
		_game.get_viewport().get_visible_rect().size == Vector2(320, 180),
		"The smallest window must preserve the logical viewport."
	)
	_game.get_window().size = Vector2i(960, 540)
	if "--capture-gallery" in OS.get_cmdline_user_args():
		_gallery = RenderGallery.new()
		await _gallery.run(_game)
	await _exercise_input()
	_exercise_saves()
	await _exercise_route()
	await _exercise_audio()
	_check(_game.persist(), "The completed game must save before exit.")
	if _failures.is_empty():
		print(
			"WALK_SMOKE_PASS ",
			OS.get_name(),
			" / ",
			DisplayServer.get_name(),
			" / ",
			AudioServer.get_driver_name(),
			" / 248 sights"
		)
		_game.request_quit.call_deferred()
	else:
		for failure: String in _failures:
			push_error(failure)
		get_tree().quit.call_deferred(1)


func _exercise_input() -> void:
	await _key(KEY_SPACE)
	_check(_game.state.total_steps == 1, "Space must take exactly one step.")
	for index: int in range(10):
		_game.manual_step()
	_game.panels.open(PanelHost.View.SHOES)
	await get_tree().process_frame
	_game.panels.rows[0].grab_focus()
	await _key(KEY_ENTER)
	_check(
		_game.state.total_steps == 11 and _game.state.steps == 1,
		"A focused shop row must buy without walking."
	)
	await _mouse(Vector2(32, 104))
	_check(
		_game.state.total_steps == 12, "The uncovered landscape must walk while the shop is open."
	)
	await _key(KEY_ESCAPE)
	_game.panels.capture_requested.emit()
	await _key(KEY_ESCAPE)
	_check(_game.settings.walk_key == KEY_SPACE, "Cancelling key capture must preserve Space.")
	_game.panels.capture_requested.emit()
	await _key(KEY_W)
	_check(_game.settings.walk_key == KEY_W, "A captured walk key must be applied.")
	_game.panels.open(PanelHost.View.AUDIO)
	await get_tree().process_frame
	var sliders: Array[Node] = _game.panels.find_children("*", "HSlider", true, false)
	_check(sliders.size() == 2, "Music and effects must have separate controls.")
	if sliders.size() == 2:
		(sliders[0] as HSlider).value = 25
		(sliders[1] as HSlider).value = 75
	_game.panels.open(PanelHost.View.CLOSED)
	await _key(KEY_W)
	_check(_game.state.total_steps == 13, "The chosen key must take one step.")
	_game.settings.hold_to_walk = true
	GameInput.configure(_game.settings)
	var held := InputEventKey.new()
	held.keycode = KEY_W
	held.pressed = true
	_game._unhandled_input(held)
	_game.advance_time(0.5)
	_game.advance_time(0.5)
	held.pressed = false
	_game._input(held)
	_check(_game.state.total_steps == 18, "A held key must repeat four times per second.")
	_game.advance_time(3600.0)
	_check(_game.state.total_steps == 18, "Suspended time must add no steps.")


func _exercise_saves() -> void:
	_check(_game.persist(), "The package must write its save.")
	var loaded: SaveResult = _game.save_store.read_save(GameController.ROUTE)
	_check(loaded.status == SaveResult.Status.LOADED, "The package must resume its own save.")
	_check(
		loaded.settings.walk_key == KEY_W and loaded.settings.music_volume == 0.25,
		"Settings must survive a reload."
	)
	var damaged: FileAccess = FileAccess.open(_game.save_store.path, FileAccess.WRITE)
	if damaged == null:
		_check(false, "The isolated recovery fixture could not be written.")
		return
	damaged.store_string("{")
	damaged.close()
	var recovered: SaveResult = _game.save_store.read_save(GameController.ROUTE)
	_check(recovered.status == SaveResult.Status.RECOVERED, "The package must recover its backup.")
	_check(_game.persist(), "The package must save again after recovery.")


func _exercise_route() -> void:
	for index: int in range(1, 6):
		_game.state = GameRules.walk(_game.state, 10000, GameController.ROUTE)
		_game.buy_upgrade(index)
	for chapter_index: int in range(5):
		var chapter: ChapterDef = GameController.ROUTE.chapters[chapter_index]
		var remaining: float = chapter.length_m() - _game.state.chapter_distance_m
		var count: int = ceili(remaining / GameRules.stride_m(_game.state)) + 1
		_game.state = GameRules.walk(_game.state, count, GameController.ROUTE)
		while _game.state.visited_count < _game.state.reached_count:
			_game.advance_time(0.4)
		await get_tree().process_frame
		_check(
			SaveSchema.state_valid(_game.state, GameController.ROUTE),
			"The route must preserve save invariants."
		)
		if chapter_index < 4:
			_game.state = GameRules.walk(_game.state, chapter.gate_price, GameController.ROUTE)
			_game.open_gate()
			_check(
				_game.state.chapter == chapter_index + 1,
				"Each gate must open its following part once."
			)
	_check(
		_game.state.home and _game.state.visited_count == 248,
		"All sights must return the traveler home."
	)
	if _gallery != null:
		await _gallery.capture("ending", _game.get_viewport())
	await _press_button("つづける")
	var previous: int = _game.state.total_steps
	await _key(KEY_W)
	_check(_game.state.total_steps == previous + 1, "Walking must continue after the ending.")


func _exercise_audio() -> void:
	_check(AudioServer.get_driver_name() != "Dummy", "The package must use an active audio driver.")
	_game.settings.audio_enabled = true
	_game.audio.configure(_game.settings)
	var length: float = _game.audio.music.stream.get_length()
	_game.audio.music.seek(length - 0.1)
	await get_tree().create_timer(0.35).timeout
	_check(
		_game.audio.music.playing and _game.audio.music.get_playback_position() < 1.0,
		"The background music must loop."
	)
	for index: int in range(100):
		_game.audio.play_effect("step", _game.settings)
	_check(_game.audio.effects["step"].max_polyphony == 1, "Repeated effects must remain bounded.")
	_game.settings.audio_enabled = false
	_game.audio.configure(_game.settings)
	_check(_game.audio.music.stream_paused, "Sound off must pause the music.")


func _press_button(text: String) -> void:
	for node: Node in _game.panels.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == text and button.is_visible_in_tree():
			await _mouse(button.get_global_rect().get_center())
			return
	_check(false, "The expected button is missing: " + text)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func _mouse(at: Vector2) -> void:
	var window_position: Vector2 = _game.get_viewport().get_final_transform() * at
	var event := InputEventMouseButton.new()
	event.position = window_position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.position = window_position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(
			(
				failure
				+ (
					" [steps=%d, total=%d, view=%d]"
					% [_game.state.steps, _game.state.total_steps, _game.panels.view]
				)
			)
		)

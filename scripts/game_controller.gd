class_name GameController
extends Node

const ROUTE: RouteDef = preload("res://data/route.tres")
const ARRIVAL_SECONDS: float = 1.2

var state: GameState = GameState.new()
var settings: GameSettings = GameSettings.new()
var save_store: SaveStore = SaveStore.new()
var landscape: Landscape
var audio: GameAudio
var panels: PanelHost
var hud: Control
var step_label: Label
var step_unit: Label
var distance_label: Label
var notice: Label
var save_label: Label
var _upgrade_button: Button
var _hold: bool = false
var _hold_s: float = 0.0
var _autosave_s: float = 0.0
var _arrival_s: float = 0.0
var _auto_visual_s: float = 0.0
var _active_sight: int = -1
var _last_tick_usec: int = 0
var _blocked: bool = false
var _quitting: bool = false
var _display_region: RegionDef
var _palette_wait_s: float = 1.0


func _ready() -> void:
	var findings: PackedStringArray = ContentCheck.errors(ROUTE)
	if not findings.is_empty():
		push_error("Game content is invalid: " + "; ".join(findings))
		OS.alert("ゲームの素材を読み込めません。", "Walk")
		get_tree().quit(1)
		return
	get_tree().auto_accept_quit = false
	get_window().min_size = Vector2i(640, 360)
	if "--smoke-test" in OS.get_cmdline_user_args():
		save_store = SaveStore.new("user://walk-package-smoke.json")
		save_store.erase()
	var loaded: SaveResult = save_store.read_save(ROUTE)
	_blocked = loaded.status == SaveResult.Status.INVALID
	if not _blocked:
		state = loaded.state
		settings = loaded.settings
	GameInput.configure(settings)
	landscape = Landscape.new()
	add_child(landscape)
	audio = GameAudio.new()
	add_child(audio)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = PixelTheme.make()
	add_child(hud)
	_build_hud()
	panels = PanelHost.new()
	panels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panels.state = state
	panels.settings = settings
	panels.route = ROUTE
	panels.load_failed = _blocked
	hud.add_child(panels)
	panels.upgrade_requested.connect(buy_upgrade)
	panels.gate_requested.connect(open_gate)
	panels.settings_changed.connect(_settings_changed)
	panels.capture_requested.connect(_capture_key)
	panels.erase_requested.connect(erase_data)
	panels.quit_requested.connect(request_quit)
	panels.closed.connect(_release_focus)
	panels.panel_changed.connect(_panel_changed)
	audio.configure(settings)
	_last_tick_usec = Time.get_ticks_usec()
	_update_display(1.0)
	if _blocked:
		panels.open(PanelHost.View.SAVE_ERROR)
	elif loaded.status == SaveResult.Status.RECOVERED:
		save_label.text = "保存を復旧しました"
	if "--smoke-test" in OS.get_cmdline_user_args():
		var smoke_script: GDScript = load("res://scripts/verification/package_smoke.gd") as GDScript
		var smoke: VerificationRunner = smoke_script.new() as VerificationRunner
		if smoke == null:
			push_error("The package verification runner is invalid.")
			get_tree().quit(1)
			return
		add_child(smoke)
		smoke.run.call_deferred(self)


func _build_hud() -> void:
	step_label = PixelWidgets.label(hud, "0", Rect2(4, 4, 156, 32), 32)
	step_unit = PixelWidgets.label(hud, "歩", Rect2(22, 20, 16, 16))
	step_label.tooltip_text = "所持歩数"
	distance_label = PixelWidgets.label(hud, "0m", Rect2(4, 38, 156, 16))
	_upgrade_button = PixelWidgets.button(
		hud, "強化", Rect2(188, 4, 40, 24), _open_panel.bind(PanelHost.View.SHOES)
	)
	PixelWidgets.button(hud, "旅", Rect2(248, 4, 24, 24), _open_panel.bind(PanelHost.View.JOURNEY))
	PixelWidgets.button(hud, "設定", Rect2(276, 4, 40, 24), _open_panel.bind(PanelHost.View.SETTINGS))
	notice = PixelWidgets.label(hud, "", Rect2(4, 156, 312, 24))
	notice.add_theme_stylebox_override("normal", PixelTheme.box(Color.WHITE, Color.BLACK))
	save_label = PixelWidgets.label(hud, "", Rect2(4, 58, 300, 16), 12)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var elapsed: float = float(now - _last_tick_usec) / 1000000.0
	_last_tick_usec = now
	advance_time(elapsed)


func advance_time(elapsed: float) -> void:
	if _blocked or elapsed <= 0.0 or elapsed > GameRules.MAX_ACTIVE_DELTA:
		_hold = false
		_hold_s = 0.0
		return
	var before: int = state.total_steps
	state = GameRules.tick(state, elapsed, ROUTE)
	var automatic_steps: int = state.total_steps - before
	if _hold and settings.hold_to_walk:
		_hold_s += elapsed
		while _hold_s >= 0.25:
			_hold_s -= 0.25
			manual_step()
	_auto_visual_s += elapsed
	if automatic_steps > 0 and _auto_visual_s >= 0.25:
		landscape.animate_step()
		audio.play_effect("step", settings)
		_auto_visual_s = 0.0
	_autosave_s += elapsed
	if _autosave_s >= 5.0:
		persist()
		_autosave_s = 0.0
	_process_arrivals(elapsed)
	_update_display(elapsed)


func manual_step() -> void:
	if _blocked:
		return
	state = GameRules.walk(state, 1, ROUTE)
	landscape.animate_step()
	audio.play_effect("step", settings)
	_update_display(0.0)


func buy_upgrade(index: int) -> void:
	var result: ActionResult = GameRules.purchase(state, index)
	if result.status == ActionResult.Status.OK:
		state = result.state
		audio.play_effect("buy", settings)
		persist()
	_update_display(0.0)


func open_gate() -> void:
	var result: ActionResult = GameRules.open_gate(state, ROUTE)
	if result.status == ActionResult.Status.OK:
		state = result.state
		audio.play_effect("gate", settings)
		persist()
		panels.open(PanelHost.View.CLOSED)
	_update_display(0.0)


func persist() -> bool:
	if _blocked:
		return false
	var saved: bool = save_store.write_save(state, settings, ROUTE)
	save_label.text = "" if saved else "保存できません。空き容量を確認してください。"
	return saved


func erase_data() -> void:
	if not save_store.erase():
		save_label.text = "データを消せませんでした"
		return
	state = GameState.new()
	settings = GameSettings.new()
	_blocked = false
	panels.load_failed = false
	_active_sight = -1
	_arrival_s = 0.0
	_hold = false
	_hold_s = 0.0
	_display_region = null
	_palette_wait_s = 1.0
	panels.settings = settings
	audio.configure(settings)
	GameInput.configure(settings)
	panels.open(PanelHost.View.CLOSED)
	_update_display(1.0)
	persist()


func request_quit() -> void:
	if _quitting:
		return
	if _blocked or persist():
		_quitting = true
		set_process(false)
		audio.shutdown()
		await get_tree().create_timer(0.05).timeout
		get_tree().quit()
	else:
		panels.open(PanelHost.View.SETTINGS)


func _process_arrivals(elapsed: float) -> void:
	if state.visited_count >= state.reached_count:
		return
	if _active_sight != state.visited_count:
		_active_sight = state.visited_count
		_arrival_s = 0.0
		landscape.show_sight(ROUTE.sight(_active_sight))
		return
	_arrival_s += elapsed
	if _arrival_s >= ARRIVAL_SECONDS:
		state = GameRules.finish_sight(state, ROUTE)
		if state.home:
			landscape.show_sight(null)
			panels.state = state
			panels.open(PanelHost.View.ENDING)
			audio.play_effect("home", settings)
		persist()


func _update_display(elapsed: float) -> void:
	if hud == null or panels == null:
		return
	_palette_wait_s += elapsed
	var chapter_end: int = (
		ROUTE.chapter_start(state.chapter) + ROUTE.chapters[state.chapter].sight_count() - 1
	)
	var visible_index: int = mini(state.visited_count, chapter_end)
	var target: RegionDef = ROUTE.region_for_sight(visible_index)
	if state.home:
		target = ROUTE.chapters[0].regions[0]
	if _display_region != target and _palette_wait_s >= 1.0:
		_display_region = target
		_palette_wait_s = 0.0
		landscape.show_region(target)
		hud.theme = PixelTheme.make(target.night)
		var paper: Color = Color.BLACK if target.night else Color.WHITE
		var ink: Color = Color.WHITE if target.night else Color.BLACK
		notice.add_theme_stylebox_override("normal", PixelTheme.box(paper, ink))
	landscape.party.assign(state.purchases.slice(3))
	step_label.text = GameFormat.number(float(state.steps))
	step_label.tooltip_text = str(state.steps) + "歩"
	var text_width: float = (
		step_label
		. get_theme_font("font")
		. get_string_size(step_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
		. x
	)
	step_unit.position.x = 6.0 + ceilf(text_width)
	distance_label.text = GameFormat.distance(state.distance_m)
	panels.state = state
	panels.refresh()
	if state.visited_count < state.reached_count:
		notice.text = ROUTE.sight(state.visited_count).title
	elif state.total_steps == 0:
		notice.text = "クリックかスペースキーで一歩"
	elif GameRules.gate_ready(state, ROUTE):
		notice.text = "名所をすべて訪問。旅の門へ"
	elif state.home:
		notice.text = "住宅街"
	else:
		notice.text = _display_region.title if _display_region != null else "住宅街"
	var notice_width: float = (
		(
			notice
			. get_theme_font("font")
			. get_string_size(notice.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			. x
		)
		+ 16.0
	)
	notice.position.x = 40.0 if state.total_steps == 0 else 4.0
	notice.size = Vector2(minf(312.0, notice_width), 24.0)
	_upgrade_button.tooltip_text = "歩幅 " + GameFormat.distance(GameRules.stride_m(state))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			panels.cancel()
			_hold = false
			get_viewport().set_input_as_handled()
		elif panels.view == PanelHost.View.KEY_CAPTURE:
			if GameSettings.valid_walk_key(event.keycode):
				settings.walk_key = event.keycode
				_settings_changed()
				panels.open(PanelHost.View.SETTINGS)
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.is_action_released("walk"):
		_hold = false
	if (
		event is InputEventMouseButton
		and not event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		_hold = false


func _unhandled_input(event: InputEvent) -> void:
	if _blocked or panels.view >= PanelHost.View.SETTINGS:
		return
	var walk_pressed: bool = false
	if event is InputEventKey:
		if get_viewport().gui_get_focus_owner() != null:
			return
		walk_pressed = event.is_action_pressed("walk", false, true)
	elif event is InputEventMouseButton:
		walk_pressed = (
			event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
			and Rect2(0, 0, 320, 180).has_point(event.position)
		)
	if walk_pressed:
		if event is InputEventMouseButton:
			_release_focus()
		_hold = true
		_hold_s = 0.0
		manual_step()
		get_viewport().set_input_as_handled()


func _open_panel(view: PanelHost.View) -> void:
	_hold = false
	panels.open(view)


func _capture_key() -> void:
	_hold = false
	panels.open(PanelHost.View.KEY_CAPTURE)


func _settings_changed() -> void:
	_hold = false
	GameInput.configure(settings)
	audio.configure(settings)
	persist()


func _release_focus() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func _panel_changed(opened: bool) -> void:
	for child: Node in hud.get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_NONE if opened else Control.FOCUS_ALL


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_hold = false

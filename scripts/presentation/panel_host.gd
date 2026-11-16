class_name PanelHost
extends Control

signal upgrade_requested(index: int)
signal gate_requested
signal settings_changed
signal capture_requested
signal erase_requested
signal quit_requested
signal closed
signal panel_changed(opened: bool)

enum View {
	CLOSED, SHOES, COMPANIONS, JOURNEY, SETTINGS, AUDIO, KEY_CAPTURE, ERASE, ENDING, SAVE_ERROR
}

var view: View = View.CLOSED
var state: GameState
var settings: GameSettings
var route: RouteDef
var load_failed: bool = false
var content: Panel
var rows: Array[Button] = []
var _blocker: Control
var _journey_labels: Array[Label] = []


func open(requested: View) -> void:
	view = requested
	panel_changed.emit(view != View.CLOSED)
	for child: Node in get_children():
		if child is Control:
			child.hide()
		child.queue_free()
	rows.clear()
	_journey_labels.clear()
	if view == View.CLOSED:
		closed.emit()
		return
	if view >= View.SETTINGS:
		_blocker = Control.new()
		_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_blocker)
	match view:
		View.SHOES, View.COMPANIONS:
			_shop()
		View.JOURNEY:
			_journey()
		View.SETTINGS:
			_settings()
		View.AUDIO:
			_audio()
		View.KEY_CAPTURE:
			_capture()
		View.ERASE:
			_erase()
		View.ENDING:
			_ending()
		View.SAVE_ERROR:
			_save_error()
	var focusable: Array[Node] = find_children("*", "Button", true, false)
	for node: Node in focusable:
		var button: Button = node as Button
		if button.is_visible_in_tree():
			_focus_button(button)
			break
	refresh()


func cancel() -> void:
	if view == View.ERASE and load_failed:
		open(View.SAVE_ERROR)
	elif view in [View.AUDIO, View.KEY_CAPTURE, View.ERASE]:
		open(View.SETTINGS)
	elif view != View.SAVE_ERROR:
		open(View.CLOSED)


func _focus_button(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()


func refresh() -> void:
	if view in [View.SHOES, View.COMPANIONS]:
		var start: int = 0 if view == View.SHOES else 3
		for row_index: int in range(rows.size()):
			var index: int = start + row_index
			var cost: int = GameRules.price(index, state.purchases[index])
			var price_label: Label = rows[row_index].get_node("Price") as Label
			var count_label: Label = rows[row_index].get_node("Count") as Label
			count_label.text = "×" + str(state.purchases[index])
			price_label.text = (
				"上限"
				if cost < 0
				else (
					GameFormat.number(cost) + "歩"
					if state.steps >= cost
					else "あと" + GameFormat.number(cost - state.steps) + "歩"
				)
			)
			PixelWidgets.fit(price_label, 88.0)
			_style_shop_row(rows[row_index], cost >= 0 and state.steps >= cost)
	elif view == View.JOURNEY and _journey_labels.size() == 4:
		_refresh_journey()


func _style_shop_row(row: Button, affordable: bool) -> void:
	var ink: Color = get_theme_color("font_color", "Label")
	var paper: Color = Color.BLACK if ink == Color.WHITE else Color.WHITE
	var pressed: bool = row.is_pressed()
	for child: Node in row.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", paper if pressed else ink)
		elif child is TextureRect:
			var invert: bool = (ink == Color.WHITE) != pressed
			if invert and child.material == null:
				var material := ShaderMaterial.new()
				material.shader = preload("res://assets/invert.gdshader")
				child.material = material
			elif not invert:
				child.material = null
	var price: Label = row.get_node("Price") as Label
	var fill: Color = paper if pressed else ink
	var tag: StyleBoxFlat = PixelTheme.box(fill, fill)
	tag.draw_center = affordable
	tag.set_border_width_all(0)
	tag.set_content_margin_all(0)
	price.add_theme_stylebox_override("normal", tag)
	if affordable:
		price.add_theme_color_override("font_color", ink if pressed else paper)
		var width: float = (
			ceilf(
				(
					price
					. get_theme_font("font")
					. get_string_size(
						price.text,
						HORIZONTAL_ALIGNMENT_LEFT,
						-1,
						price.get_theme_font_size("font_size")
					)
					. x
				)
			)
			+ 4.0
		)
		price.position.x = 172.0 - width
		price.size.x = width
	else:
		price.position.x = 84.0
		price.size.x = 88.0


func _header(title: String, rect: Rect2) -> void:
	content = PixelWidgets.panel(self, rect)
	PixelWidgets.label(content, title, Rect2(8, 4, 180, 24))
	PixelWidgets.button(content, "とじる", Rect2(rect.size.x - 60, 4, 56, 24), cancel)


func _shop() -> void:
	content = PixelWidgets.panel(self, Rect2(136, 0, 184, 180))
	PixelWidgets.button(content, "くつ", Rect2(4, 4, 40, 24), open.bind(View.SHOES))
	PixelWidgets.button(content, "なかま", Rect2(44, 4, 56, 24), open.bind(View.COMPANIONS))
	PixelWidgets.button(content, "とじる", Rect2(124, 4, 56, 24), cancel)
	PixelWidgets.label(content, "一歩で進む距離" if view == View.SHOES else "自動で歩く", Rect2(4, 30, 176, 16))
	var start: int = 0 if view == View.SHOES else 3
	for row_index: int in range(3):
		var index: int = start + row_index
		var item: UpgradeDef = GameRules.UPGRADES.items[index]
		var row: Button = PixelWidgets.button(
			content, "", Rect2(4, 48 + row_index * 42, 176, 40), upgrade_requested.emit.bind(index)
		)
		PixelWidgets.icon(row, item.icon, Vector2(4, 3))
		PixelWidgets.label(row, item.title, Rect2(24, 1, 100, 18))
		var count: Label = PixelWidgets.label(row, "", Rect2(112, 1, 60, 18))
		count.name = "Count"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var gain: String = (
			"+" + GameFormat.stride_gain(item.stride_m)
			if index < 3
			else "+%d歩/秒" % item.steps_per_second
		)
		PixelWidgets.label(row, gain, Rect2(24, 20, 76, 18))
		var cost: Label = PixelWidgets.label(row, "", Rect2(84, 20, 88, 18))
		cost.name = "Price"
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rows.append(row)


func _journey() -> void:
	_header("旅", Rect2(136, 0, 184, 180))
	for index: int in range(4):
		_journey_labels.append(PixelWidgets.label(content, "", Rect2(8, 32 + index * 20, 168, 20)))
	var button: Button = PixelWidgets.button(
		content, "", Rect2(4, 112, 176, 40), gate_requested.emit
	)
	rows.append(button)
	PixelWidgets.label(content, "強化と仲間は残ります", Rect2(8, 156, 168, 18))


func _refresh_journey() -> void:
	var chapter: ChapterDef = route.chapters[state.chapter]
	var start: int = route.chapter_start(state.chapter)
	_journey_labels[0].text = (
		"いまの場所 名所%d/%d" % [state.visited_count - start, chapter.sight_count()]
	)
	_journey_labels[1].text = (
		chapter.title
		+ "編 "
		+ route.region_for_sight(mini(state.visited_count, start + chapter.sight_count() - 1)).title
	)
	_journey_labels[2].text = "つぎの場所"
	_journey_labels[3].text = (
		route.chapters[state.chapter + 1].title + "編" if state.chapter < 4 else "わが家"
	)
	if state.chapter >= 4:
		rows[0].text = "名所をめぐると帰宅"
	elif not GameRules.gate_ready(state, route):
		rows[0].text = "門は全名所の訪問後"
	else:
		var price: String = GameFormat.number(chapter.gate_price) + "歩"
		if state.steps < chapter.gate_price:
			price = "あと" + GameFormat.number(chapter.gate_price - state.steps) + "歩"
		rows[0].text = "門 歩幅%d倍\n%s" % [int(chapter.gate_multiplier), price]


func _settings() -> void:
	_header("設定", Rect2(38, 12, 244, 156))
	PixelWidgets.label(content, "音", Rect2(8, 34, 124, 24))
	_toggle(164, 34, settings.audio_enabled, _set_audio)
	PixelWidgets.label(content, "長押しで歩く", Rect2(8, 62, 124, 24))
	_toggle(164, 62, settings.hold_to_walk, _set_hold)
	PixelWidgets.label(content, "歩くキー", Rect2(8, 90, 112, 24))
	var key_name: String = (
		"スペース" if settings.walk_key == KEY_SPACE else OS.get_keycode_string(settings.walk_key)
	)
	PixelWidgets.button(content, key_name, Rect2(140, 90, 96, 24), capture_requested.emit)
	PixelWidgets.button(content, "音量", Rect2(112, 34, 48, 24), open.bind(View.AUDIO))
	PixelWidgets.button(content, "データを消す", Rect2(8, 124, 104, 24), open.bind(View.ERASE))
	PixelWidgets.button(content, "ゲームを終わる", Rect2(116, 124, 120, 24), quit_requested.emit)


func _toggle(x: int, y: int, enabled: bool, action: Callable) -> void:
	var on: Button = PixelWidgets.button(content, "入", Rect2(x, y, 24, 24), action.bind(true))
	var off: Button = PixelWidgets.button(
		content, "切", Rect2(x + 24, y, 24, 24), action.bind(false)
	)
	on.toggle_mode = true
	off.toggle_mode = true
	on.button_pressed = enabled
	off.button_pressed = not enabled


func _set_audio(enabled: bool) -> void:
	settings.audio_enabled = enabled
	settings_changed.emit()
	open(View.SETTINGS)


func _set_hold(enabled: bool) -> void:
	settings.hold_to_walk = enabled
	settings_changed.emit()
	open(View.SETTINGS)


func _audio() -> void:
	_header("音量", Rect2(38, 24, 244, 132))
	_volume("BGM", 40, settings.music_volume, _music_volume)
	_volume("効果音", 76, settings.effects_volume, _effects_volume)


func _volume(title: String, y: int, value: float, action: Callable) -> void:
	PixelWidgets.label(content, title, Rect2(8, y, 64, 24))
	var slider := HSlider.new()
	slider.position = Vector2(76, y + 4)
	slider.size = Vector2(152, 20)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = value * 100.0
	slider.value_changed.connect(action)
	content.add_child(slider)


func _music_volume(value: float) -> void:
	settings.music_volume = value / 100.0
	settings_changed.emit()


func _effects_volume(value: float) -> void:
	settings.effects_volume = value / 100.0
	settings_changed.emit()


func _capture() -> void:
	_header("歩くキー", Rect2(38, 36, 244, 108))
	PixelWidgets.label(content, "使うキーを押してください", Rect2(8, 36, 228, 24))
	PixelWidgets.label(content, "Escapeで取消", Rect2(8, 68, 228, 24))


func _erase() -> void:
	_header("データを消す", Rect2(38, 24, 244, 132))
	PixelWidgets.label(content, "歩数と記録を消しますか？", Rect2(8, 36, 228, 24))
	PixelWidgets.button(content, "やめる", Rect2(8, 88, 104, 24), cancel)
	PixelWidgets.button(content, "消す", Rect2(132, 88, 104, 24), erase_requested.emit)


func _ending() -> void:
	content = PixelWidgets.panel(self, Rect2(136, 32, 176, 144))
	PixelWidgets.label(content, "家に着きました", Rect2(8, 4, 160, 24))
	PixelWidgets.label(content, "見た名所          248", Rect2(8, 28, 160, 20))
	PixelWidgets.label(
		content, "歩数 " + GameFormat.number(state.total_steps) + "歩", Rect2(8, 48, 160, 20)
	)
	PixelWidgets.label(
		content, "距離 " + GameFormat.distance(state.distance_m), Rect2(8, 68, 160, 20)
	)
	PixelWidgets.label(content, GameFormat.duration(state.play_time_s), Rect2(8, 88, 160, 20))
	PixelWidgets.button(content, "つづける", Rect2(88, 116, 80, 24), cancel)


func _save_error() -> void:
	content = PixelWidgets.panel(self, Rect2(20, 24, 280, 132))
	PixelWidgets.label(content, "保存を読み込めません", Rect2(8, 4, 264, 24))
	PixelWidgets.label(content, "記録を保護して停止しました", Rect2(8, 36, 264, 20))
	PixelWidgets.button(content, "データを消す", Rect2(8, 88, 112, 24), open.bind(View.ERASE))
	PixelWidgets.button(content, "終了", Rect2(216, 88, 56, 24), quit_requested.emit)

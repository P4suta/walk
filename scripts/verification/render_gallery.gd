class_name RenderGallery
extends RefCounted

var directory: String = ""
var _frames: Array[Image] = []


func run(game: GameController) -> void:
	directory = "res://build/screenshots" if OS.has_feature("editor") else "user://walk-gallery"
	DirAccess.make_dir_recursive_absolute(directory)
	game.landscape.set_process(false)
	var entries: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/gallery.json")
	)
	if not entries is Array:
		push_error("The render gallery has no fixtures.")
		return
	for raw: Dictionary in entries:
		var region := RegionDef.new()
		region.key = String(raw.key)
		region.title = String(raw.title)
		region.landscape = String(raw.landscape)
		region.night = bool(raw.night)
		region.helmet = bool(raw.helmet)
		if not ContentCheck.landscape_errors(region).is_empty():
			push_error("The gallery landscape is invalid: " + region.key)
			return
		game.landscape.show_sight(null)
		game.landscape.show_region(region)
		game.landscape.party.assign(raw.party)
		game.landscape._process(1.0)
		game.hud.theme = PixelTheme.make(region.night)
		game.notice.text = region.title
		game.notice.position = Vector2(4, 156)
		game.notice.size = Vector2(240, 24)
		var paper: Color = Color.BLACK if region.night else Color.WHITE
		var ink: Color = Color.WHITE if region.night else Color.BLACK
		game.notice.add_theme_stylebox_override("normal", PixelTheme.box(paper, ink))
		await game.get_tree().create_timer(1.02).timeout
		await capture(region.key, game.get_viewport())
	game.landscape.show_region(GameController.ROUTE.chapters[0].regions[0])
	game.hud.theme = PixelTheme.make()
	game.notice.add_theme_stylebox_override("normal", PixelTheme.box(Color.WHITE, Color.BLACK))
	game.landscape.party.assign([0, 0, 0])
	game.landscape._process(1.0)
	game._display_region = null
	game._update_display(1.0)
	for view: PanelHost.View in [
		PanelHost.View.SHOES,
		PanelHost.View.COMPANIONS,
		PanelHost.View.JOURNEY,
		PanelHost.View.SETTINGS,
		PanelHost.View.AUDIO,
		PanelHost.View.KEY_CAPTURE,
		PanelHost.View.ERASE,
		PanelHost.View.SAVE_ERROR
	]:
		game.panels.open(view)
		await game.get_tree().create_timer(1.02).timeout
		await capture("panel_" + str(view), game.get_viewport())
	game.panels.open(PanelHost.View.CLOSED)
	game.landscape.set_process(true)
	game._display_region = null
	game._update_display(1.0)


func capture(key: String, viewport: Viewport) -> void:
	if directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("The renderer produced an empty frame: " + key)
		return
	if image.save_png(directory.path_join(key + ".png")) != OK:
		push_error("The renderer could not save the frame: " + key)
	_frames.append(image)
	var sheet_index: int = int((_frames.size() - 1) / 16.0)
	var sheet := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	for index: int in range(sheet_index * 16, _frames.size()):
		var slot: int = index % 16
		sheet.blit_rect(
			_frames[index], Rect2i(0, 0, 320, 180), Vector2i(slot % 4 * 320, int(slot / 4.0) * 180)
		)
	if sheet.save_png(directory.path_join("gallery_%d.png" % sheet_index)) != OK:
		push_error("The renderer could not save the gallery sheet.")

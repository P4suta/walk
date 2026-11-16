class_name Landscape
extends Node2D

const WALK_FRAMES: Array[String] = ["3c930.svg", "7e601.svg", "b34a3.svg", "840c9.svg"]
const SUIT_FRAMES: Array[String] = ["5470b.svg", "18436.svg", "79a0c.svg", "b8dbb.svg"]
const CYCLE_A: Array[int] = [1, 2, 3]
const CYCLE_B: Array[int] = [3, 2, 1]
const COMPANION_FRAMES: Array[Array] = [
	["dc30b.svg", "ad65f.svg"], ["e023f.svg", "194ea.svg"], ["f25c9.svg", "d45b3.svg"]
]

var region: RegionDef
var scroll_steps: int = 0
var step_serial: int = 0
var idle_s: float = 1.0
var party: Array[int] = [0, 0, 0]
var sight: SightDef
var sprites: Array[ScenerySprite] = []
var traveler: Sprite2D
var companions: Array[Sprite2D] = []
var _character_x: float = 64.0
var _textures: Dictionary[String, Texture2D] = {}
var _sight_texture: Texture2D
var _invert: ShaderMaterial


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_invert = ShaderMaterial.new()
	_invert.shader = preload("res://assets/invert.gdshader")
	traveler = Sprite2D.new()
	traveler.centered = false
	add_child(traveler)
	for index: int in range(3):
		var companion := Sprite2D.new()
		companion.centered = false
		add_child(companion)
		companions.append(companion)


func show_region(value: RegionDef) -> void:
	if region == value:
		return
	region = value
	sprites.clear()
	scroll_steps = 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(region.landscape))
	if data is Dictionary and data.get("sprites") is Array:
		for raw: Variant in data.sprites:
			if raw is Dictionary:
				sprites.append(ScenerySprite.new(raw))
	if traveler != null:
		traveler.material = _invert if region.night else null
		for companion: Sprite2D in companions:
			companion.material = _invert if region.night else null
	queue_redraw()


func animate_step() -> void:
	scroll_steps = (scroll_steps + 1) % 320
	step_serial += 1
	idle_s = 0.0
	queue_redraw()


func show_sight(value: SightDef) -> void:
	sight = value
	_sight_texture = load(value.artwork) as Texture2D if value != null else null
	queue_redraw()


func _process(delta: float) -> void:
	if region == null:
		return
	idle_s += delta
	var pose: int = 0
	if idle_s < 0.4:
		var frame: int = mini(int(idle_s / 0.13334), 2)
		var cycle: Array[int] = CYCLE_A if step_serial % 2 == 1 else CYCLE_B
		pose = cycle[frame]
	var count: int = 0
	for owned: int in party:
		if owned > 0:
			count += 1
	_character_x = move_toward(_character_x, 96.0 if count > 0 else 64.0, delta * 96.0)
	var frames: Array[String] = SUIT_FRAMES if region.helmet else WALK_FRAMES
	traveler.texture = _texture(frames[pose])
	traveler.position = Vector2(roundf(_character_x), 123)
	var preceding: int = 0
	for index: int in range(companions.size()):
		var companion: Sprite2D = companions[index]
		companion.visible = party[index] > 0
		if not companion.visible:
			continue
		preceding += 1
		var frame: int = (step_serial + index) % 2 if idle_s < 0.4 else 0
		companion.texture = _texture(COMPANION_FRAMES[index][frame])
		companion.position = Vector2(roundf(_character_x) - preceding * 28 - 2, 138)


func _draw() -> void:
	if region == null:
		return
	draw_rect(Rect2(0, 0, 320, 180), Color.BLACK if region.night else Color.WHITE)
	for sprite: ScenerySprite in sprites:
		var offset: float = fmod(float(scroll_steps * sprite.motion), 320.0)
		for shift: int in [-320, 0, 320]:
			var at: Vector2 = sprite.origin + Vector2(shift - offset, 0)
			if at.x + sprite.texture.get_width() >= 0 and at.x <= 320:
				draw_texture(sprite.texture, at)
	if sight != null:
		var present: bool = false
		for sprite: ScenerySprite in sprites:
			if sprite.texture.resource_path == sight.artwork:
				present = true
		if not present:
			draw_texture(_sight_texture, Vector2(180, 149 - _sight_texture.get_height()))


func _texture(filename: String) -> Texture2D:
	if not _textures.has(filename):
		_textures[filename] = load("res://assets/art/" + filename) as Texture2D
	return _textures[filename]

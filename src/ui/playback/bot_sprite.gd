class_name BotSprite
extends Node2D

const CELL_SIZE := 16

const BOT_TEXTURES: Dictionary = {
	"NanoAI":        preload("res://assets/bots/bot_nanoai.png"),
	"NanoExplorer":  preload("res://assets/bots/bot_nanoexplorer.png"),
	"NanoCollector": preload("res://assets/bots/bot_nanocollector.png"),
	"NanoContainer": preload("res://assets/bots/bot_nanocontainer.png"),
	"NanoNeedle":    preload("res://assets/bots/bot_nanoneedle.png"),
	"NanoIPCreator": preload("res://assets/bots/bot_nanoipcreator.png"),
	"NanoBlocker":   preload("res://assets/bots/bot_nanoblocker.png"),
	"NanoWall":      preload("res://assets/bots/bot_nanowall.png"),
}

const PLAYER_COLORS: Array = [
	Color(0.25, 0.55, 1.00),
	Color(1.00, 0.30, 0.25),
	Color(0.20, 0.85, 0.40),
	Color(1.00, 0.85, 0.15),
]

var bot_id: int
var bot_type: String
var owner_id: int

var _color: Color
var _tween: Tween = null

func setup(p_id: int, p_type: String, p_owner: int) -> void:
	bot_id   = p_id
	bot_type = p_type
	owner_id = p_owner
	_color   = PLAYER_COLORS[p_owner % PLAYER_COLORS.size()]
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func place_at(cell: Vector2i) -> void:
	position = _cell_px(cell)

func animate_to(cell: Vector2i, duration: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", _cell_px(cell), duration) \
		  .set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func mark_dead() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(queue_free)

func _draw() -> void:
	var tex: Texture2D = BOT_TEXTURES.get(bot_type)
	var half := CELL_SIZE * 0.5
	var rect := Rect2(-half, -half, CELL_SIZE, CELL_SIZE)
	if tex == null:
		draw_circle(Vector2.ZERO, half * 0.7, _color)
		return
	draw_texture_rect(tex, rect, false, _color)

static func _cell_px(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5,
				   cell.y * CELL_SIZE + CELL_SIZE * 0.5)

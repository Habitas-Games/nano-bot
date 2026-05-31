class_name FxFlash
extends Sprite2D

const FRAME_SEC := 0.07   # seconds per animation frame

# Animate through `textures` centred at `world_pos`, then self-destruct.
func play(textures: Array, world_pos: Vector2) -> void:
	position       = world_pos
	centered       = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if textures.is_empty():
		queue_free()
		return
	texture = textures[0]
	var t := create_tween()
	t.tween_interval(FRAME_SEC)
	for i in range(1, textures.size()):
		var tex: Texture2D = textures[i]
		t.tween_callback(func(): texture = tex)
		t.tween_interval(FRAME_SEC)
	t.tween_callback(queue_free)

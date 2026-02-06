extends Control

## Draws the selection rectangle in screen space (on the HUD CanvasLayer).
## This ensures the rect is always visible regardless of camera position.

var selection_rect: Rect2 = Rect2()
var rect_visible: bool = false

func update_selection_rect(rect: Rect2, visible: bool) -> void:
	selection_rect = rect
	rect_visible = visible
	queue_redraw()

func _draw() -> void:
	if rect_visible and selection_rect.size != Vector2.ZERO:
		draw_rect(selection_rect, Color(0.2, 0.8, 0.2, 0.3), true)
		draw_rect(selection_rect, Color(0.2, 0.8, 0.2, 0.8), false, 2.0)

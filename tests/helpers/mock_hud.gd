extends CanvasLayer
## Mock HUD - Stub implementation of HUD for testing
##
## This provides all the method signatures that main.gd calls,
## but does nothing. Allows tests to run without the full UI.

class_name MockHUD


func show_info(_entity: Node) -> void:
	pass


func hide_info() -> void:
	pass


func show_tc_panel(_tc: Node) -> void:
	pass


func hide_tc_panel() -> void:
	pass


func show_barracks_panel(_barracks: Node) -> void:
	pass


func hide_barracks_panel() -> void:
	pass


func show_market_panel(_market: Node) -> void:
	pass


func hide_market_panel() -> void:
	pass


func _show_error(_message: String) -> void:
	pass

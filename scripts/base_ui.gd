extends Control


func _on_join_pressed() -> void:
	HighLevelMultiplayerHandler.start_client()
	self.hide()


func _on_host_pressed() -> void:
	HighLevelMultiplayerHandler.start_server()
	self.hide()

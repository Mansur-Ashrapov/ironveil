extends MultiplayerSpawner

@export var network_player: PackedScene
@export var network_player2: PackedScene


func _ready() -> void:
	multiplayer.peer_connected.connect(spawn_player)

func spawn_player(peer_id: int) -> void:
	if !multiplayer.is_server(): return
	var player: Node
	player = network_player.instantiate()
	player.name = str(peer_id)
	get_node(spawn_path).call_deferred("add_child", player)

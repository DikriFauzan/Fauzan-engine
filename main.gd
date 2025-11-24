extends Node

var websocket_server = WebSocketServer.new()
const FEAC_PORT = 9999

func _ready():
    # Setup WebSocket listener untuk FEAC
    websocket_server.peer_connected.connect(_on_feac_connected)
    websocket_server.peer_disconnected.connect(_on_feac_disconnected)
    websocket_server.connect("data_received", _on_feac_data)
    
    if websocket_server.listen(FEAC_PORT) == OK:
        print("✅ NeoEngine FEAC Bridge aktif di port %d" % FEAC_PORT)
    else:
        print("❌ Gagal start FEAC Bridge")

func _on_feac_data(peer_id, data):
    var json_data = JSON.parse_string(data.get_string_from_utf8())
    var response = _process_feac_command(json_data.command)
    websocket_server.send_text(peer_id, JSON.stringify(response))

func _process_feac_command(command: String):
    match command:
        "status":
            return {"status": "ok", "scene": get_tree().current_scene.name, "fps": Engine.get_frames_per_second()}
        
        "fix_code":
            # Trigger AI analysis
            var script_path = "res://scripts/player.gd"  # Contoh
            return {"status": "analysis_started", "file": script_path}
        
        "upgrade_engine":
            # Minta approval admin
            return {"status": "upgrade_pending", "message": "Admin approval required"}
        
        _:
            return {"status": "error", "message": "Command tidak dikenali: %s" % command}

func _on_feac_connected(id):
    print("FEAC Core terhubung: %s" % id)

func _on_feac_disconnected(id):
    print("FEAC Core terputus: %s" % id)

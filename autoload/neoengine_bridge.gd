extends Node
class_name NeoBridge

# NeoEngine Bridge v2.0 for Godot 4.5+
# Connects to FEAC WA Mini for live control, hot-reloading, and metrics.

# --- CONFIGURATION ---
# Ideally, load these from a .env file or export vars if not headless
var SERVER_URL: String = "wss://your-feac-backend.railway.app/neo"
var BRIDGE_TOKEN: String = "YOUR_NEO_TOKEN_HERE" 

# Internal State
var _socket: WebSocketPeer = WebSocketPeer.new()
var _connected: bool = false
var _reconnect_timer: Timer
var _heartbeat_timer: Timer

func _ready() -> void:
	# Setup Timers
	_reconnect_timer = Timer.new()
	_reconnect_timer.wait_time = 3.0
	_reconnect_timer.one_shot = true
	_reconnect_timer.timeout.connect(_connect_to_server)
	add_child(_reconnect_timer)
	
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = 5.0
	_heartbeat_timer.timeout.connect(_send_heartbeat)
	add_child(_heartbeat_timer)
	
	print("[NeoBridge] Initializing...")
	_connect_to_server()

func _process(_delta: float) -> void:
	_socket.poll()
	var state = _socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_on_connected()
		
		while _socket.get_available_packet_count():
			var packet = _socket.get_packet()
			var msg_string = packet.get_string_from_utf8()
			if msg_string.is_empty(): continue
			
			var json = JSON.parse_string(msg_string)
			if json:
				_handle_message(json)
			else:
				printerr("[NeoBridge] Failed to parse JSON: ", msg_string)
				
	elif state == WebSocketPeer.STATE_CLOSED:
		if _connected:
			_on_disconnected()

func _connect_to_server() -> void:
	print("[NeoBridge] Connecting to ", SERVER_URL)
	# Pass token in headers or query param depending on backend support
	# Using Query param here for simplicity with WebSocketPeer
	var url_with_token = SERVER_URL + "?token=" + BRIDGE_TOKEN
	var err = _socket.connect_to_url(url_with_token)
	if err != OK:
		printerr("[NeoBridge] Connection refused. Retrying in 3s...")
		_reconnect_timer.start()

func _on_connected() -> void:
	_connected = true
	print("[NeoBridge] Connected to FEAC Core!")
	_heartbeat_timer.start()
	
	# Send Register Payload
	var payload = {
		"type": "register",
		"token": BRIDGE_TOKEN,
		"engine_version": Engine.get_version_info().string,
		"platform": OS.get_name(),
		"project_name": ProjectSettings.get_setting("application/config/name")
	}
	_send(payload)

func _on_disconnected() -> void:
	_connected = false
	_heartbeat_timer.stop()
	print("[NeoBridge] Disconnected. Reconnecting...")
	_reconnect_timer.start()

func _send(data: Dictionary) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.put_packet(JSON.stringify(data).to_utf8_buffer())

# --- HANDLERS ---

func _handle_message(msg: Dictionary) -> void:
	var cmd = msg.get("cmd", "")
	var args = msg.get("args", [])
	
	print("[NeoBridge] Received CMD: ", cmd)
	
	match cmd:
		"execute_script":
			_execute_snippet(msg.get("code", ""))
		"reload_scene":
			print("[NeoBridge] Reloading current scene...")
			get_tree().reload_current_scene()
			_send_log("Scene reloaded successfully.")
		"apply_patch":
			# Advanced: Could load a PCK or script from disk
			pass
		_:
			print("[NeoBridge] Unknown command.")

func _execute_snippet(code: String) -> void:
	# DANGEROUS: Only enable in debug builds
	if not OS.is_debug_build():
		_send({"type": "error", "msg": "Execution denied in release build."})
		return
		
	var script = GDScript.new()
	script.source_code = "extends Node\nfunc run():\n" + "\t" + code.replace("\n", "\n\t")
	if script.reload() == OK:
		var obj = Node.new()
		obj.set_script(script)
		obj.run()
		obj.free()
		_send_log("Snippet executed.")
	else:
		_send_log("Script compilation failed.")

# --- REPORTING ---

func _send_heartbeat() -> void:
	var stats = {
		"type": "engine_status",
		"fps": Engine.get_frames_per_second(),
		"memory_static": OS.get_static_memory_usage(),
		"uptime": Time.get_ticks_msec() / 1000.0
	}
	_send(stats)

func _send_log(msg: String) -> void:
	_send({"type": "log", "message": msg})

func send_bug_report(error_msg: String, stack_trace: String) -> void:
	_send({
		"type": "bug_report",
		"error": error_msg,
		"stack": stack_trace
	})

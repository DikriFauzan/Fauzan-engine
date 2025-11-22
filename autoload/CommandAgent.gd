extends Node

## CommandAgent - NeoEngine v1
## Bertanggung jawab untuk menerima perintah eksternal (simulasi dari Termux Webhook)
## dan mengarahkan perintah tersebut ke Agent yang relevan.

# --- Dependensi (Autoload) ---
var sws: Node = null 
var orchestrator: Node = null 
var http_request: HTTPRequest = null

# --- Konfigurasi ---
const TERMUX_WEBHOOK_URL := "http://localhost:3000"
const COMMAND_CHECK_INTERVAL := 5.0 

# --- State Internal ---
var is_server_reachable: bool = false
var last_check_time: float = 0.0

func _ready() -> void:
	sws = get_node_or_null("/root/SharedWorldState")
	orchestrator = get_node_or_null("/root/NeoEngineOrchestrator")
	
	if not sws:
		print("CommandAgent: SharedWorldState belum didaftarkan. Menggunakan Node placeholder.")
		sws = Node.new() 
		
	if not orchestrator:
		print("CommandAgent: NeoEngineOrchestrator belum didaftarkan. Menggunakan Node placeholder.")
		orchestrator = Node.new()

	http_request = HTTPRequest.new()
	add_child(http_request)
	# Menggunakan Callable untuk Godot 4
	http_request.request_completed.connect(_on_http_request_completed)
	
	print("CommandAgent: Siap. Server Termux di: %s" % TERMUX_WEBHOOK_URL)
	_check_server_status()

func _process(_delta: float) -> void: # PERBAIKAN: _delta
	if Time.get_unix_time_from_system() - last_check_time > COMMAND_CHECK_INTERVAL:
		_check_server_status()
		last_check_time = Time.get_unix_time_from_system()

# --- Fungsi Komunikasi Eksternal ---

func _check_server_status() -> void:
	print("CommandAgent: Mengecek status server Termux...")
	
	if not is_instance_valid(http_request):
		return
		
	var error = http_request.request(TERMUX_WEBHOOK_URL, ["Content-Type: application/json"], HTTPClient.METHOD_GET)
	if error != OK:
		printerr("CommandAgent: Gagal mengirim permintaan status HTTP (Error: ", error, ").")
		is_server_reachable = false
		if sws.has_method("set_data"):
			sws.set_data("external_server_status", "DOWN")
		
func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void: # PERBAIKAN: _headers
	
	if result == HTTPRequest.RESULT_SUCCESS:
		if response_code == 200:
			if not is_server_reachable:
				print("CommandAgent: Server Termux Webhook AKTIF (Code: %d)." % response_code)
				if sws.has_method("set_data"):
					sws.set_data("external_server_status", "UP")
				is_server_reachable = true
			
			if http_request.get_last_method() == HTTPClient.METHOD_GET:
				return

			var response_text = body.get_string_from_utf8()
			_process_incoming_command(response_text)
			
		else:
			printerr("CommandAgent: Server merespons tapi kode non-200. Status Code: %d" % response_code)
			is_server_reachable = false
	else:
		printerr("CommandAgent: Koneksi ke server Termux GAGAL (Result: %d)." % result)
		is_server_reachable = false

# --- Logika Pemrosesan Perintah ---

func _process_incoming_command(json_string: String) -> void:
	# PERBAIKAN UTAMA: Menggunakan JSON.parse_string() (Godot 4 Static Method)
	var parsed_data = JSON.parse_string(json_string)
	
	# Jika parsing gagal, parsed_data akan bernilai null
	if parsed_data == null:
		printerr("CommandAgent: Gagal parsing JSON. String tidak valid.")
		return

	if typeof(parsed_data) == TYPE_DICTIONARY and parsed_data.has("command_name"):
		var command_name = parsed_data.command_name.to_lower()
		var payload = parsed_data.get("payload", {})

		print("CommandAgent: Menerima perintah: %s" % command_name)

		match command_name:
			"generate_scene":
				var prompt = payload.get("prompt", "Default prompt")
				_execute_story_generation(prompt)
				
			"change_price":
				var item_id = payload.get("item_id", "")
				var new_price = payload.get("new_price", 0.0)
				_execute_price_change(item_id, new_price)
				
			"trigger_event":
				var event_type = payload.get("event_type", "global_storm")
				if orchestrator.has_method("execute_global_event"):
					orchestrator.execute_global_event(event_type, payload)
				
			"evolve_engine":
				if orchestrator.has_method("evolve_engine"):
					orchestrator.evolve_engine()
				
			_:
				printerr("CommandAgent: Perintah tidak dikenal: %s" % command_name)
	else:
		printerr("CommandAgent: Payload valid JSON tapi missing 'command_name'.")

# --- Fungsi Eksekusi Perintah Internal ---

func _execute_story_generation(prompt: String) -> void:
	var story_agent = get_node_or_null("/root/StoryAgent") 
	if story_agent and story_agent.has_method("generate_story_plan"):
		print("CommandAgent: Meneruskan perintah ke StoryAgent: %s" % prompt)
		story_agent.generate_story_plan(prompt)
	else:
		printerr("CommandAgent: StoryAgent tidak ditemukan.")

func _execute_price_change(item_id: String, new_price: float) -> void:
	var economy_agent = get_node_or_null("/root/EconomyAgent")
	if economy_agent and economy_agent.has_method("force_set_item_price"):
		print("CommandAgent: Mengubah harga %s menjadi %f" % [item_id, new_price])
		economy_agent.force_set_item_price(item_id, new_price)
	else:
		printerr("CommandAgent: EconomyAgent tidak ditemukan.")

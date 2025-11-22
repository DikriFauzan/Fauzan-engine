extends Node

## CommandAgent - NeoEngine v1
## Bertanggung jawab untuk menerima perintah eksternal (simulasi dari Termux Webhook)
## dan mengarahkan perintah tersebut ke Agent yang relevan (StoryAgent, EconomyAgent, dll.)

# --- Dependensi (Autoload) ---
var sws: Node = null # SharedWorldState
var orchestrator: Node = null # NeoEngineOrchestrator
var http_request: HTTPRequest = null # Node untuk komunikasi HTTP

# --- Konfigurasi ---
const TERMUX_WEBHOOK_URL := "http://localhost:3000"
const COMMAND_CHECK_INTERVAL := 5.0 # Interval cek status server Termux (dalam detik)

# --- State Internal ---
var is_server_reachable: bool = false
var last_check_time: float = 0.0

func _ready() -> void:
	# Inisialisasi dependensi
	sws = get_node_or_null("/root/SharedWorldState")
	orchestrator = get_node_or_null("/root/NeoEngineOrchestrator")
	
	# PENTING: Perbaiki kesalahan jika Autoload lain belum didaftarkan
	if not sws:
		print("CommandAgent: SharedWorldState belum didaftarkan di Autoload. Menggunakan Node placeholder.")
		# Jika SWS belum dibuat, ini akan mencegah crash. Anda harus membuat SWS nanti.
		sws = Node.new() 
		
	if not orchestrator:
		print("CommandAgent: NeoEngineOrchestrator belum didaftarkan di Autoload. Menggunakan Node placeholder.")
		# Jika Orchestrator belum dibuat, ini akan mencegah crash. Anda harus membuat Orchestrator nanti.
		orchestrator = Node.new()

	# Inisialisasi node HTTPRequest
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(Callable(self, "_on_http_request_completed"))
	
	print("CommandAgent: Siap. Server Termux di: %s" % TERMUX_WEBHOOK_URL)
	
	# Coba cek koneksi pertama kali
	_check_server_status()


func _process(delta: float) -> void:
	# Cek status server secara berkala
	# Menggunakan Time.get_unix_time_from_system() untuk interval yang lebih akurat
	if Time.get_unix_time_from_system() - last_check_time > COMMAND_CHECK_INTERVAL:
		_check_server_status()
		last_check_time = Time.get_unix_time_from_system()

# --- Fungsi Komunikasi Eksternal ---

func _check_server_status() -> void:
	# Mengirim GET request ringan untuk mengecek apakah server Termux Node.js merespons
	print("CommandAgent: Mengecek status server Termux...")
	
	# Guard clause: pastikan http_request ada sebelum menggunakannya
	if not is_instance_valid(http_request):
		printerr("CommandAgent: HTTPRequest node tidak valid.")
		is_server_reachable = false
		sws.set_data("external_server_status", "INVALID_NODE")
		return
		
	var error = http_request.request(TERMUX_WEBHOOK_URL, ["Content-Type: application/json"], HTTPClient.METHOD_GET)
	if error != OK:
		printerr("CommandAgent: Gagal mengirim permintaan status HTTP (Error: ", error, ").")
		is_server_reachable = false
		sws.set_data("external_server_status", "DOWN")
		
func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# Pastikan Godot bisa menjalankan set_data pada node placeholder jika SWS belum ada
	if sws.has_method("set_data"):
		pass # Biarkan SWS menangani data
	elif sws.is_in_group("placeholder"):
		# Ini hanya untuk menghindari error jika SWS belum dibuat, akan dihapus saat SWS dibuat
		pass 
	else:
		printerr("CommandAgent: SharedWorldState tidak memiliki metode set_data().")
		return
		
	if result == HTTPRequest.RESULT_SUCCESS:
		if response_code == 200:
			# Server Node.js merespons dengan 200 OK
			if not is_server_reachable:
				print("CommandAgent: Server Termux Webhook AKTIF (Code: %d)." % response_code)
				sws.set_data("external_server_status", "UP")
				is_server_reachable = true
			
			# Khusus untuk GET request cek status, kita tidak memproses body
			if http_request.get_last_method() == HTTPClient.METHOD_GET:
				return

			# --- Jika ini adalah SIMULASI RESPONSE WEBHOOK (POST request) ---
			# Kita asumsikan body berisi JSON perintah dari admin_core/server.js
			var response_text = body.get_string_from_utf8()
			_process_incoming_command(response_text)
			
		else:
			printerr("CommandAgent: Server merespons tapi kode non-200. Status Code: %d" % response_code)
			is_server_reachable = false
			sws.set_data("external_server_status", "ISSUE")
	else:
		printerr("CommandAgent: Koneksi ke server Termux GAGAL (Result: %d). Pastikan server Termux berjalan." % result)
		is_server_reachable = false
		sws.set_data("external_server_status", "DOWN")

# --- Logika Pemrosesan Perintah (Simulasi) ---

# Fungsi ini akan dipanggil ketika CommandAgent menerima payload yang di-forward dari server Termux
func _process_incoming_command(json_string: String) -> void:
	var parsed_data = JSON.parse(json_string) # Menggunakan Godot 3.x parse
	
	if typeof(parsed_data) == TYPE_DICTIONARY and parsed_data.has("command_name"):
		var command_name = parsed_data.command_name.to_lower()
		var payload = parsed_data.get("payload", {})

		print("CommandAgent: Menerima perintah: %s" % command_name)

		match command_name:
			"generate_scene":
				# Perintah untuk membuat scene baru (diteruskan ke StoryAgent)
				var prompt = payload.get("prompt", "A mystical forest scene with a hidden shrine.")
				_execute_story_generation(prompt)
				
			"change_price":
				# Perintah untuk mengubah harga (diteruskan ke EconomyAgent)
				var item_id = payload.get("item_id", "")
				var new_price = payload.get("new_price", 0.0)
				_execute_price_change(item_id, new_price)
				
			"trigger_event":
				# Perintah untuk memicu event global (diteruskan ke Orchestrator)
				var event_type = payload.get("event_type", "global_storm")
				# Pastikan orchestrator ada sebelum dipanggil
				if orchestrator.has_method("execute_global_event"):
					orchestrator.execute_global_event(event_type, payload)
				
			"evolve_engine":
				# Perintah untuk memulai evolusi engine
				if orchestrator.has_method("evolve_engine"):
					orchestrator.evolve_engine()
				
			_:
				printerr("CommandAgent: Perintah tidak dikenal: %s" % command_name)
	else:
		printerr("CommandAgent: Payload tidak valid atau missing 'command_name'.")

# --- Fungsi Eksekusi Perintah Internal ---

func _execute_story_generation(prompt: String) -> void:
	# Menggunakan get_node_or_null langsung untuk Agen lain
	var story_agent = get_node_or_null("/root/StoryAgent") 
	if story_agent and story_agent.has_method("generate_story_plan"):
		print("CommandAgent: Meneruskan perintah 'generate_scene' ke StoryAgent dengan prompt: %s" % prompt)
		story_agent.generate_story_plan(prompt)
	else:
		printerr("CommandAgent: StoryAgent tidak ditemukan, missing method, atau belum di-Autoload.")

func _execute_price_change(item_id: String, new_price: float) -> void:
	var economy_agent = get_node_or_null("/root/EconomyAgent")
	if economy_agent and economy_agent.has_method("force_set_item_price"):
		print("CommandAgent: Meneruskan perintah 'change_price' ke EconomyAgent: %s = %f" % [item_id, new_price])
		economy_agent.force_set_item_price(item_id, new_price)
	else:
		printerr("CommandAgent: EconomyAgent tidak ditemukan, missing method, atau belum di-Autoload.")

# --- Placeholder untuk Fungsi yang Belum Diimplementasikan ---

# Tambahkan placeholder method di CommandAgent jika agen lain belum dibuat.
func force_set_item_price(item_id: String, new_price: float) -> void:
	# Implementasi asli akan ada di EconomyAgent.gd
	print("CommandAgent: Placeholder method for force_set_item_price called (item: %s, price: %f). Implement in EconomyAgent.gd." % [item_id, new_price])

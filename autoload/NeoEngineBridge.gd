extends Node

## NeoEngineBridge - NeoEngine v1
## Central communication hub for connecting external LLMs, APIs, and data sources.
## Handles request routing, response parsing, and integration with StoryAgent and other systems.
## Designed for high-throughput and modular connectivity.

# --- Internal State ---
var sws: Node = null # Referensi ke SharedWorldState
var active_requests: Dictionary = {} # Menyimpan request_id -> callback_info
var request_counter: int = 0 # Untuk membuat ID request unik

# --- Configuration (Bisa dibaca dari SWS atau file konfigurasi) ---
var llm_endpoint_url: String = ""
var api_key: String = ""
var default_headers: Dictionary = {}

# --- Signals ---
signal llm_response_received(request_id: String, response_json_string: String)
signal llm_request_failed(request_id: String, error_code: int)

func _ready() -> void:
    if not Engine.is_editor_hint():
        sws = get_node_or_null("/root/SharedWorldState")
        if not sws:
            push_error("NeoEngineBridge: SharedWorldState not found in root. Cannot initialize.")
            return

        # Ambil konfigurasi dari SWS (opsional, bisa diisi default dulu)
        _load_configuration_from_sws()
        print("NeoEngineBridge: Ready. Config loaded.")

func _load_configuration_from_sws() -> void:
    # Contoh: Ambil konfigurasi dari SWS
    var config = sws.get_data("engine_bridge_config", {})
    llm_endpoint_url = config.get("llm_endpoint_url", "https://api.openai.com/v1/chat/completions")
    api_key = config.get("api_key", "sk-YOUR-DEFAULT-KEY")
    default_headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + api_key
    }
    
# --- New HTTP Request Function for General API Calls (e.g., LiveOpsAgent) ---

func make_http_request(url: String, body: String, response_callback: Callable, external_request_id: String = "", method: HTTPClient.Method = HTTPClient.METHOD_POST, custom_headers: PackedStringArray = []) -> String:
    """
    Membuat permintaan HTTP dan mengarahkan respons ke callback yang ditentukan.
    """
    var request_id = external_request_id if external_request_id.length() > 0 else "req_" + str(request_counter)
    request_counter += 1

    var http_request = HTTPRequest.new()
    add_child(http_request)
    
    # Simpan info callback
    active_requests[request_id] = {
        "target": response_callback.get_object(),
        "method": response_callback.get_method(),
        "request_node": http_request
    }
    
    http_request.request_completed.connect(Callable(self, "_on_general_http_request_completed").bind(request_id))

    var headers_to_use = custom_headers.duplicate()
    if method == HTTPClient.METHOD_POST:
        # Pastikan Content-Type disetel untuk POST/JSON
        headers_to_use.append("Content-Type: application/json")

    # Perbaikan Line 68: Mengubah PackedByteArray kembali menjadi String untuk argumen ke-4.
    # Godot akan melakukan encoding menjadi PackedByteArray secara internal, yang lebih stabil.
    var error = http_request.request(url, headers_to_use, method, body)
    
    if error != OK:
        printerr("NeoEngineBridge: Failed to start HTTP request (", request_id, "): ", error)
        # Hapus request yang gagal
        active_requests.erase(request_id)
        # Emit signal kegagalan jika perlu
        emit_signal("llm_request_failed", request_id, error)
        http_request.queue_free()
        return ""
        
    return request_id

func _on_general_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request_id: String) -> void:
    """
    Callback umum untuk semua permintaan HTTP yang dilewatkan melalui make_http_request.
    """
    if not active_requests.has(request_id):
        printerr("NeoEngineBridge: Received unknown request_id completion: ", request_id)
        return
        
    var callback_info = active_requests[request_id]
    var request_node = callback_info.request_node

    # Panggil fungsi callback eksternal (LiveOpsAgent)
    if callback_info.target and callback_info.target.has_method(callback_info.method):
        callback_info.target.call(callback_info.method, request_id, result, response_code, headers, body)
    
    # Bersihkan state
    active_requests.erase(request_id)
    request_node.queue_free()


# --- LLM Specific Functions (Contoh Simulasi, tetap dipertahankan) ---

# Perbaikan Line 103: Mengganti user_prompt menjadi _user_prompt
func request_llm_generation(_user_prompt: String, callback_info: Dictionary) -> String:
    # ... (Fungsi LLM tetap sama, hanya bagian _on_llm_http_request_completed yang akan dipanggil) ...
    
    var request_id = "llm_" + str(request_counter)
    request_counter += 1
    
    # Simulasi sukses (untuk development tanpa API key)
    _simulate_llm_response(request_id, callback_info)
    return request_id

func _simulate_llm_response(request_id: String, callback_info: Dictionary) -> void:
    # Simulasi respons JSON dari LLM
    var simulated_response = {
        "id": "chatcmpl-000000000000000000",
        "object": "chat.completion",
        "created": 1677699100,
        "model": "gemini-2.5-flash-preview-09-2025",
        "choices": [
            {
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "{\n  \"script_id\": \"test_scene_001\",\n  \"title\": \"Misi Rahasia di Pasar Malam\",\n  \"description\": \"Kisah dimulai dengan player menerima pesan rahasia di sebuah pasar malam yang ramai, memicu plot utama.\\n\\n\\n\",\n  \"entities\": [\n    {\"id\": \"npc_alina\", \"type\": \"human\", \"role\": \"informant\", \"location\": \"market_stall_3\"},\n    {\"id\": \"item_secret_note\", \"type\": \"item\", \"interaction\": \"pickup\", \"location\": \"player_inventory\"}\n  ],\n  \"cinematics\": [\n    {\"type\": \"fade_in\", \"duration\": 2.0},\n    {\"type\": \"camera_pan\", \"target_entity\": \"market_stall_3\", \"duration\": 3.0}\n  ],\n  \"goals\": [{\"type\": \"talk_to\", \"target\": \"npc_alina\"}],\n  \"triggers\": [],\n  \"classes\": [],\n  \"skills\": [],\n  \"combat\": {},\n  \"economy\": {},\n  \"cinematics\": {},\n  \"physics\": {},\n  \"engine_evolution\": {\n    \"recommended_modules\": [],\n    \"new_agents\": [],\n    \"importer_extensions\": [],\n    \"engine_v2_capabilities\": []\n  }\n}"
                },
                "finish_reason": "stop"
            }
        ]
    }

    var _response_json_string = JSON.stringify(simulated_response)
    var content = JSON.parse_string(simulated_response.choices[0].message.content)

    # Kirim response ke target callback
    if callback_info.target and callback_info.target.has_method(callback_info.response_method):
        callback_info.target.call(callback_info.response_method, JSON.stringify(content))
    emit_signal("llm_response_received", request_id, JSON.stringify(content))

func _get_current_request_id_from_context() -> String:
    # Fungsi helper untuk mengambil request_id dari konteks HTTPRequest
    # Ambil satu key dari active_requests
    if not active_requests.is_empty():
        return active_requests.keys()[0]
    return ""

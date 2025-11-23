extends Node
# LiveOpsAgent - collects runtime telemetry and persist to user:// for analysis
# Corrected UNUSED_PARAMETER warnings and added backend communication logic.

const TELEMETRY_SEND_INTERVAL := 60.0 # seconds (Changed from 60.0, adjust as needed)
const TELEMETRY_BATCH_SIZE := 10     # Number of events to buffer before sending

var event_buffer: Array[Dictionary] = []
var send_timer: Timer
var sws: Node = null
var bridge_node: Node = null # Referensi ke NeoEngineBridge

func _ready() -> void:
    print("LiveOpsAgent ready.")
    sws = get_node_or_null("/root/SharedWorldState")
    bridge_node = get_node_or_null("/root/NeoEngineBridge")

    if not sws:
        printerr("LiveOpsAgent: SharedWorldState not found!")
    if not bridge_node:
        print("LiveOpsAgent: NeoEngineBridge not found. Telemetry will only save locally.")
    
    # Setup timer for periodic batch sending
    send_timer = Timer.new()
    send_timer.wait_time = TELEMETRY_SEND_INTERVAL
    send_timer.one_shot = false
    send_timer.autostart = true
    add_child(send_timer)
    send_timer.connect("timeout", Callable(self, "_on_send_timer_timeout"))

func record_event(event_type: String, payload: Dictionary = {}) -> void:
    var entry = {
        "time": Time.get_unix_time_from_system(),
        "type": event_type,
        "payload": payload
    }
    _append_to_telemetry(entry)

func _append_to_telemetry(entry: Dictionary) -> void:
    # 1. Simpan data secara lokal (seperti sebelumnya)
    var dir := "user://liveops/"
    DirAccess.make_dir_recursive_absolute(dir)
    var path := dir + "telemetry.json"
    var arr := []
    if FileAccess.file_exists(path):
        var f = FileAccess.open(path, FileAccess.READ)
        if f:
            var txt = f.get_as_text()
            f.close()
            var res = JSON.parse_string(txt)
            if typeof(res) == TYPE_ARRAY: # Perbaikan: Langsung cek tipe
                arr = res
    arr.append(entry)
    var f2 = FileAccess.open(path, FileAccess.WRITE)
    if f2:
        f2.store_string(JSON.stringify(arr, "\t")) # Gunakan tab untuk format lebih rapi
        f2.close()

    # 2. Tambahkan ke buffer untuk dikirim ke backend
    event_buffer.append(entry)

    # 3. Cek apakah buffer sudah penuh
    if event_buffer.size() >= TELEMETRY_BATCH_SIZE:
        _send_batch_to_backend()


func _on_send_timer_timeout() -> void:
    # Kirim sisa data di buffer secara berkala
    if event_buffer.size() > 0:
        _send_batch_to_backend()

func _send_batch_to_backend() -> void:
    if event_buffer.is_empty():
        return
        
    var batch_to_send: Array[Dictionary] = event_buffer.duplicate()
    event_buffer.clear() # Hapus buffer sebelum dikirim
    
    # --- PERBAIKAN LINE 88 ---
    # Mendeklarasikan total_events di sini agar dapat diakses oleh kedua blok IF di bawah.
    var total_events = batch_to_send.size()

    # Kirim ke SWS untuk pemantauan lokal
    if sws:
        # PENTING: Jangan kirim terlalu banyak data ke SWS. Contoh: hanya kirim total/ringkasan.
        sws.call_deferred("set_data", "liveops_last_batch_size", total_events)

    # Kirim ke Backend API via Bridge
    if bridge_node:
        print("LiveOpsAgent: Sending telemetry batch to backend (", total_events, " events) via Bridge...")
        # Mengganti URL placeholder dengan alamat Uvicorn Anda di Termux (localhost:8000)
        # NOTE: Telemetry seharusnya dikirim ke endpoint yang spesifik, misalnya:
        # var api_url = "http://127.0.0.1:8000/api/telemetry/collect"
        
        # Menggunakan placeholder asli yang mungkin dikonfigurasi di tempat lain:
        var _request_id = bridge_node.make_http_request(
            "https://your-ai-core-api.com/v1/telemetry/event", # <-- Asumsi URL ini akan diganti di Godot
            JSON.stringify(batch_to_send),
            Callable(self, "_on_telemetry_request_completed"),
            "", # request_id eksternal: String kosong
            HTTPClient.METHOD_POST
        )
        # Perbaikan Line 89 (UNUSED_VARIABLE) diselesaikan dengan prefix '_request_id'

    else:
        # Jika Bridge tidak ada, kembalikan data ke buffer dan cetak error
        printerr("LiveOpsAgent: Bridge not available. Telemetry not sent to backend.")
        event_buffer.append_array(batch_to_send) # Kembalikan data ke buffer

# Callback dari NeoEngineBridge
func _on_telemetry_request_completed(_request_id: String, result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
    # Perbaikan UNUSED_PARAMETER: Parameter 'request_id', 'headers' dan 'body' diawali underscore
    
    if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
        print("LiveOpsAgent: Telemetry batch sent successfully (Code: ", response_code, ").")
    else:
        printerr("LiveOpsAgent: FAILED to send telemetry batch to backend. Result: ", result, ", Code: ", response_code)
        # TODO: Implementasi logika coba ulang (retry) atau simpan ke file khusus error.
        # Untuk saat ini, kita anggap data hilang. (Tidak dikembalikan ke event_buffer untuk mencegah loop error)

extends Node

## CommandAgent (WebSocket Edition) - NeoEngine v1
## Bertindak sebagai "Saraf Motorik" yang menjaga koneksi real-time dengan AI Admin Core.
## Menerima perintah JSON secara instan dan meneruskannya ke Orchestrator.

signal command_received(cmd_type: String, payload: Dictionary)
signal connection_status_changed(is_connected: bool)

# --- Konfigurasi ---
# Ganti localhost dengan IP server VPS Anda nanti
# Port 8000 adalah standar untuk server Python FastAPI development
var server_url: String = "ws://127.0.0.1:8000/ws/%s" 
var client_id: String = "neo_engine_v1_dev" # ID unik engine ini
var reconnect_delay: float = 3.0

# --- Internal State ---
var ws := WebSocketPeer.new()
var is_connected_to_server := false
var reconnect_timer := Timer.new()

# --- Dependencies ---
var orchestrator: Node

func _ready() -> void:
    # Setup Timer Reconnect
    add_child(reconnect_timer)
    reconnect_timer.wait_time = reconnect_delay
    reconnect_timer.one_shot = true
    reconnect_timer.timeout.connect(_connect_to_socket)
    
    # Ambil referensi Orchestrator
    orchestrator = get_node_or_null("/root/NeoEngineOrchestrator")
    
    print("CommandAgent: Menginisialisasi WebSocket Bridge...")
    _connect_to_socket()

func _connect_to_socket() -> void:
    var url = server_url % client_id
    print("CommandAgent: Menghubungkan ke Admin Core di %s ..." % url)
    var err = ws.connect_to_url(url)
    
    if err != OK:
        printerr("CommandAgent: Gagal connect. Error: %d" % err)
        reconnect_timer.start()

func _process(_delta: float) -> void:
    ws.poll()
    var state = ws.get_ready_state()
    
    if state == WebSocketPeer.STATE_OPEN:
        if not is_connected_to_server:
            _on_connected()
        
        # Baca pesan yang masuk secara terus menerus
        while ws.get_available_packet_count() > 0:
            var packet = ws.get_packet()
            var msg_string = packet.get_string_from_utf8()
            _handle_message(msg_string)
            
    elif state == WebSocketPeer.STATE_CLOSED:
        if is_connected_to_server:
            _on_disconnected()
            
    elif state == WebSocketPeer.STATE_CLOSING:
        pass

func _on_connected() -> void:
    is_connected_to_server = true
    emit_signal("connection_status_changed", true)
    print("CommandAgent: TERHUBUNG ke AI Admin Core! Menunggu perintah...")

func _on_disconnected() -> void:
    is_connected_to_server = false
    emit_signal("connection_status_changed", false)
    print("CommandAgent: Koneksi terputus. Mencoba reconnect dalam 3 detik...")
    reconnect_timer.start()

func _handle_message(msg_string: String) -> void:
    print("CommandAgent: Pesan diterima -> %s" % msg_string)
    
    var json = JSON.new()
    var error = json.parse(msg_string)
    
    if error == OK:
        var data = json.data
        if typeof(data) == TYPE_DICTIONARY:
            var cmd_type = data.get("command", "UNKNOWN")
            var payload = data.get("payload", {})
            
            # Kirim Sinyal ke Game/UI
            emit_signal("command_received", cmd_type, payload)
            
            # Langsung eksekusi di Orchestrator jika ada (Gunakan _plan untuk menghindari UNUSED_VARIABLE)
            if orchestrator:
                var _plan = {
                    "id": "CMD_" + str(Time.get_ticks_msec()),
                    "type": cmd_type,
                    "data": payload
                }
                # Jika Orchestrator Anda telah memiliki fungsi:
                # orchestrator.execute_command(_plan)
                pass # Untuk saat ini, kita biarkan saja sinyal yang bekerja
        else:
            printerr("CommandAgent: Format pesan bukan Dictionary.")
    else:
        printerr("CommandAgent: JSON Parse Error.")

# Fungsi untuk mengirim data balik ke Admin Core (misal: Laporan Bug/Status)
func send_to_admin(type: String, data: Dictionary) -> void:
    if is_connected_to_server:
        var packet = {
            "type": type,
            "data": data,
            "timestamp": Time.get_unix_time_from_system()
        }
        ws.send_text(JSON.stringify(packet))

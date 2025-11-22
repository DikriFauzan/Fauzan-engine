# autoload/GameMonitor.gd
extends Node
# GameMonitor - Collects runtime telemetry, tracks player events, sends to backend/SWS.
# Uses a buffer to batch-send data for efficiency.

const TELEMETRY_BATCH_SIZE := 10
const TELEMETRY_SEND_INTERVAL := 60.0 # seconds

var event_buffer: Array[Dictionary] = []
var send_timer: Timer

func _ready() -> void:
    print("GameMonitor ready. PID: ", get_instance_id())
    # Setup timer for periodic batch sending
    send_timer = Timer.new()
    send_timer.wait_time = TELEMETRY_SEND_INTERVAL
    send_timer.one_shot = false
    send_timer.autostart = true
    add_child(send_timer)
    send_timer.connect("timeout", Callable(self, "_on_send_timer_timeout"))

func track_event(event_type: String,  Dictionary = {}) -> void:
    var event_entry = {
        "timestamp": Time.get_ticks_msec(),
        "type": event_type,
        "data": data,
        "session_id": OS.get_unique_id(), # Or use a specific session ID from DataAgent
        "player_id": DataAgent.get_player_value("player_id", "unknown_player"), # Example access
    }
    event_buffer.append(event_entry)
    print("GameMonitor: Tracked event - ", event_type)

    # Check if buffer is full, send immediately
    if event_buffer.size() >= TELEMETRY_BATCH_SIZE:
        _send_telemetry_batch()

func _on_send_timer_timeout() -> void:
    if not event_buffer.is_empty():
        _send_telemetry_batch()

func _send_telemetry_batch() -> void:
    if event_buffer.is_empty():
        return

    var batch_to_send = event_buffer.duplicate(true)
    event_buffer.clear() # Clear the buffer after copying

    # --- Send to SharedWorldState (for local analysis/backup) ---
    var sws_node = get_node_or_null("/root/SharedWorldState")
    if sws_node and sws_node.has_method("get_data"):
        var current_telemetry = sws_node.call("get_data", "telemetry_events", [])
        if typeof(current_telemetry) == TYPE_ARRAY:
            current_telemetry.append_array(batch_to_send)
            # Limit stored events to prevent memory bloat
            if current_telemetry.size() > 1000:
                current_telemetry = current_telemetry.slice(-1000)
            sws_node.call_deferred("set_data", "telemetry_events", current_telemetry)

    # --- Send to Backend API (Placeholder) ---
    # var http_request = HTTPRequest.new()
    # add_child(http_request)
    # http_request.request_completed.connect(_on_http_request_completed)
    # var headers = ["Content-Type: application/json"]
    # var error = http_request.request("https://your-backend/api/telemetry", headers, HTTPClient.METHOD_POST, JSON.stringify(batch_to_send))
    # if error != OK:
    #     printerr("GameMonitor: Failed to send telemetry batch via HTTP: ", error)
    #     # Fallback: add back to buffer or save to file
    #     event_buffer.append_array(batch_to_send)

    print("GameMonitor: Sent telemetry batch (", batch_to_send.size(), " events).")

# func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
#     if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
#         print("GameMonitor: Telemetry batch sent successfully to backend.")
#     else:
#         printerr("GameMonitor: Failed to send telemetry batch to backend. Result: ", result, ", Code: ", response_code)
#         # Fallback: add back to buffer or save to file
#         var failed_batch = JSON.parse_string(body.get_string_from_utf8()) # Assuming server sends back the batch on error
#         if typeof(failed_batch) == TYPE_ARRAY:
#             event_buffer.append_array(failed_batch)

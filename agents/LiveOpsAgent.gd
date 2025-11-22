# agents/LiveOpsAgent.gd
extends Node
# LiveOpsAgent - Analyzes runtime telemetry from GameMonitor and SharedWorldState.
# Generates reports, identifies issues (bugs, retention), and sends alerts/commands (e.g., to WhatsApp).
# This agent runs externally or periodically processes data dumps, distinct from autoload/GameMonitor.

const TELEMETRY_DATA_SOURCE := "user://liveops_telemetry.json" # Or API endpoint
const REPORT_OUTPUT_DIR := "user://liveops_reports/"
const RETENTION_ANALYSIS_WINDOW_DAYS := 7 # Analyze D1, D7 retention
const CRASH_THRESHOLD_PER_1000_SESSIONS := 50.0
const LOW_RETENTION_THRESHOLD := 0.1 # 10%

var analysis_results: Dictionary = {}
var last_analysis_time: int = 0

func _ready() -> void:
    print("LiveOpsAgent ready. PID: ", get_instance_id())
    # This agent might be triggered by a timer, external signal, or command.
    # For now, we'll have a method to run analysis manually or on interval.

# --- Main Analysis Function ---
func analyze_telemetry_and_report() -> Dictionary:
    var current_time = Time.get_unix_time_from_system()
    var time_since_last_analysis = current_time - last_analysis_time

    # Avoid running analysis too frequently
    if time_since_last_analysis < 1800: # Run at most every 30 minutes
        print("LiveOpsAgent: Skipping analysis, last run was ", time_since_last_analysis, " seconds ago.")
        return analysis_results

    print("LiveOpsAgent: Starting telemetry analysis...")

    # --- 1. Fetch Telemetry Data ---
    var telemetry_data = _fetch_telemetry_data()
    if not telemetry_data or typeof(telemetry_data) != TYPE_ARRAY:
        printerr("LiveOpsAgent: Failed to fetch or invalid telemetry data.")
        return {}

    # --- 2. Perform Analysis ---
    var results = _perform_analysis(telemetry_data)

    # --- 3. Generate Report ---
    _generate_report(results)

    # --- 4. Send Alerts (e.g., via CommandAgent to WhatsApp) ---
    _send_alerts(results)

    analysis_results = results
    last_analysis_time = current_time

    print("LiveOpsAgent: Analysis complete.")
    return results

# --- Fetch Data ---
func _fetch_telemetry_data() -> Array:
    # --- Option 1: Read from local file (user://) saved by GameMonitor ---
    var f = FileAccess.open(TELEMETRY_DATA_SOURCE, FileAccess.READ)
    if f:
        var txt = f.get_as_text()
        f.close()
        var parsed = JSON.parse_string(txt)
        if parsed and typeof(parsed) == TYPE_ARRAY:
            print("LiveOpsAgent: Fetched ", parsed.size(), " telemetry events from file.")
            return parsed
        else:
            printerr("LiveOpsAgent: Failed to parse telemetry data from file.")
            return []
    else:
        printerr("LiveOpsAgent: Failed to open telemetry data file: ", TELEMETRY_DATA_SOURCE)
        return []

    # --- Option 2: Fetch from API (Placeholder) ---
    # var http_request = HTTPRequest.new()
    # add_child(http_request)
    # http_request.request_completed.connect(_on_telemetry_api_response)
    # var error = http_request.request("https://your-backend/api/telemetry?since=last_analysis_time")
    # if error != OK:
    #     printerr("LiveOpsAgent: Failed to request telemetry from API.")
    #     return []
    # return [] # Wait for signal

# func _on_telemetry_api_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
#     if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
#         var txt = body.get_string_from_utf8()
#         var parsed = JSON.parse_string(txt)
#         if parsed and typeof(parsed) == TYPE_ARRAY:
#             print("LiveOpsAgent: Fetched ", parsed.size(), " telemetry events from API.")
#             # Process parsed data here
#         else:
#             printerr("LiveOpsAgent: Failed to parse telemetry data from API.")
#     else:
#         printerr("LiveOpsAgent: API request failed. Result: ", result, ", Code: ", response_code)

# --- Analysis Logic ---
func _perform_analysis(telemetry_ Array) -> Dictionary:
    var results = {
        "summary": {
            "total_events": telemetry_.size(),
            "analysis_period_start": 0,
            "analysis_period_end": Time.get_unix_time_from_system()
        },
        "retention": {},
        "crashes": {},
        "bugs": {},
        "engagement": {},
        "economy": {},
        "high_priority_issues": [],
        "recommendations": []
    }

    if telemetry_.is_empty():
        return results

    # --- Example Analysis: Count crashes, sessions, calculate basic retention ---
    var session_starts = 0
    var session_ends = 0
    var crash_count = 0
    var player_sessions: Dictionary = {} # player_id -> [start_time, end_time, ...]

    for event in telemetry_:
        if typeof(event) != TYPE_DICTIONARY:
            continue

        var event_type = event.get("type", "")
        var player_id = event.get("player_id", "unknown")
        var timestamp = event.get("timestamp", 0)

        match event_type:
            "session_start":
                session_starts += 1
                if not player_sessions.has(player_id):
                    player_sessions[player_id] = []
                player_sessions[player_id].append({"start": timestamp, "end": null})
            "session_end":
                session_ends += 1
                if player_sessions.has(player_id):
                    var sessions = player_sessions[player_id]
                    if not sessions.is_empty() and sessions[-1]["end"] == null:
                        sessions[-1]["end"] = timestamp
            "game_crash":
                crash_count += 1
                results["high_priority_issues"].append({
                    "type": "crash",
                    "timestamp": timestamp,
                    "player_id": player_id,
                    "details": event.get("data", {})
                })
            # Add more event types for analysis (e.g., quest completion, IAP, etc.)

    # --- Calculate basic metrics ---
    results["summary"]["session_starts"] = session_starts
    results["summary"]["session_ends"] = session_ends
    results["summary"]["crash_count"] = crash_count
    results["summary"]["unique_players"] = player_sessions.keys().size()

    if session_starts > 0:
        var crash_rate_per_1000 = (float(crash_count) / session_starts) * 1000.0
        results["crashes"]["rate_per_1000_sessions"] = crash_rate_per_1000
        if crash_rate_per_1000 > CRASH_THRESHOLD_PER_1000_SESSIONS:
            results["high_priority_issues"].append({
                "type": "high_crash_rate",
                "metric_value": crash_rate_per_1000,
                "threshold": CRASH_THRESHOLD_PER_1000_SESSIONS,
                "suggestion": "Investigate recent changes or server stability."
            })

    # --- Simple Retention Estimation (Placeholder) ---
    # A real implementation needs more complex logic linking session start times to player IDs over days.
    # This is a very rough estimation.
    var active_players_today = 0
    var active_players_7_days_ago = 0
    var cutoff_today = Time.get_unix_time_from_system() - 86400 # 24 hours ago
    var cutoff_7_days = Time.get_unix_time_from_system() - (86400 * 7) # 7 days ago

    for pid in player_sessions.keys():
        var sessions = player_sessions[pid]
        var last_session_end = 0
        for s in sessions:
            if s.get("end", 0) > last_session_end:
                last_session_end = s["end"]
        if last_session_end > cutoff_today:
            active_players_today += 1
        elif last_session_end > cutoff_7_days:
            active_players_7_days_ago += 1

    if active_players_7_days_ago > 0:
        var d7_retention = float(active_players_today) / active_players_7_days_ago
        results["retention"]["d7_estimated"] = d7_retention
        if d7_retention < LOW_RETENTION_THRESHOLD:
            results["high_priority_issues"].append({
                "type": "low_retention",
                "metric_value": d7_retention,
                "threshold": LOW_RETENTION_THRESHOLD,
                "suggestion": "Review recent gameplay changes, difficulty, or content updates."
            })

    # --- Add more complex analysis here (economy, engagement, etc.) ---

    return results

# --- Report Generation ---
func _generate_report(results: Dictionary) -> void:
    DirAccess.make_dir_recursive_absolute(REPORT_OUTPUT_DIR)
    var report_time = Time.get_datetime_string_from_system().replace(":", "-")
    var file_path = REPORT_OUTPUT_DIR + "liveops_report_" + report_time + ".json"

    var f = FileAccess.open(file_path, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(results, "\t"))
        f.close()
        print("LiveOpsAgent: Report generated at ", file_path)
    else:
        printerr("LiveOpsAgent: Failed to write report to ", file_path)

# --- Alert Sending (via CommandAgent) ---
func _send_alerts(results: Dictionary) -> void:
    var command_agent_node = get_node_or_null("/root/CommandAgent")
    if not (command_agent_node and command_agent_node.has_method("receive_command")):
        printerr("LiveOpsAgent: CommandAgent not found or unavailable for sending alerts.")
        return

    # Send high-priority issues
    for issue in results.get("high_priority_issues", []):
        var alert_message = "🚨 LiveOps Alert: %s\nDetails: %s" % [issue.get("type", "Unknown"), str(issue)]
        var command = {
            "type": "admin.send_message",
            "payload": {
                "target": "whatsapp_dev_group", # Or specific admin
                "message": alert_message
            }
        }
        command_agent_node.call_deferred("receive_command", command)
        print("LiveOpsAgent: Sent alert via CommandAgent: ", alert_message)

    # Send summary if significant issues found
    if not results.get("high_priority_issues", []).is_empty():
        var summary_message = "📊 LiveOps Summary:\nCrashes (last period): %d\nEstimated D7 Retention: %.2f\nUnique Players: %d" % [
            results["summary"].get("crash_count", 0),
            results["retention"].get("d7_estimated", 0.0),
            results["summary"].get("unique_players", 0)
        ]
        var summary_command = {
            "type": "admin.send_message",
            "payload": {
                "target": "whatsapp_dev_group",
                "message": summary_message
            }
        }
        command_agent_node.call_deferred("receive_command", summary_command)
        print("LiveOpsAgent: Sent summary via CommandAgent.")

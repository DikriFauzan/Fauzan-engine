# autoload/DataAgent.gd
extends Node
# DataAgent - Manages persistent player data (status, inventory, quest progress).
# Saves/loads to/from SharedWorldState or local file (user://) as fallback.

const PLAYER_DATA_FILE := "user://player_data.json"

var player_ Dictionary = {}

func _ready() -> void:
    print("DataAgent ready. PID: ", get_instance_id())
    # Attempt to load data on startup
    load_player_data()

func load_player_data(player_id: String = "default_player") -> bool:
    # Try loading from SharedWorldState first
    var sws_node = get_node_or_null("/root/SharedWorldState")
    if sws_node and sws_node.has_method("get_data"):
        var saved_data = sws_node.call("get_data", "player_data_" + player_id, null)
        if saved_data and typeof(saved_data) == TYPE_DICTIONARY:
            player_data = saved_data
            print("DataAgent: Loaded player data from SWS for ", player_id)
            return true

    # Fallback: load from local file
    var file_path = PLAYER_DATA_FILE
    if FileAccess.file_exists(file_path):
        var f = FileAccess.open(file_path, FileAccess.READ)
        if f:
            var txt = f.get_as_text()
            f.close()
            var parsed = JSON.parse_string(txt)
            if parsed and typeof(parsed) == TYPE_DICTIONARY:
                player_data = parsed
                print("DataAgent: Loaded player data from file for ", player_id)
                return true

    # If no data found anywhere, initialize default
    player_data = _get_default_player_data()
    print("DataAgent: Initialized default player data for ", player_id)
    return false

func save_player_data(player_id: String = "default_player") -> bool:
    # Prepare data to save
    var data_to_save = player_data.duplicate(true)
    data_to_save["last_save_time"] = Time.get_unix_time_from_system()

    # Save to SharedWorldState
    var sws_node = get_node_or_null("/root/SharedWorldState")
    if sws_node and sws_node.has_method("set_data"):
        sws_node.call_deferred("set_data", "player_data_" + player_id, data_to_save)
        print("DataAgent: Saved player data to SWS for ", player_id)
    else:
        printerr("DataAgent: SharedWorldState not available for saving player data.")

    # Also save to local file as fallback
    var file_path = PLAYER_DATA_FILE
    var f = FileAccess.open(file_path, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data_to_save, "\t"))
        f.close()
        print("DataAgent: Saved player data to local file.")
        return true
    else:
        printerr("DataAgent: Failed to write player data to local file.")
        return false

func get_player_value(key: String, default: Variant = null) -> Variant:
    return player_data.get(key, default)

func set_player_value(key: String, value: Variant) -> void:
    player_data[key] = value

func _get_default_player_data() -> Dictionary:
    # Define the default structure for a new player
    return {
        "player_id": "default_player",
        "level": 1,
        "xp": 0,
        "xp_to_next_level": 100,
        "status": {
            "health": 100,
            "max_health": 100,
            "mana": 50,
            "max_mana": 50,
        },
        "inventory": {
            "items": [],
            "gold": 0,
            "capacity": 50,
        },
        "quests": {
            "active": [],
            "completed": [],
        },
        "skills": {},
        "location": "start_area",
        "last_save_time": Time.get_unix_time_from_system(),
    }

# Example: Sync data with SWS periodically (call this from GameMonitor or a timer)
func sync_with_sws(player_id: String = "default_player") -> void:
    # This function could be called periodically to ensure SWS is up-to-date
    # even if local changes happen frequently.
    var current_data = player_data.duplicate(true)
    var sws_node = get_node_or_null("/root/SharedWorldState")
    if sws_node and sws_node.has_method("set_data"):
        sws_node.call_deferred("set_data", "player_data_" + player_id, current_data)
        print("DataAgent: Synced player data to SWS.")

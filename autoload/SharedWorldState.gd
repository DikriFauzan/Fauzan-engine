extends Node
# Shared World State - single source of truth for NeoEngine
# Author: Generated for Fauzan-engine
# License: MIT

signal state_changed(key: String, value)
signal batch_updated(changes: Dictionary)

const AUTOSAVE_PATH := "user://sws_current_world_state.json"
const AUTOSAVE_INTERVAL := 10.0 # seconds

var sws : Dictionary = {}
var _autosave_timer : Timer

func _ready() -> void:
    # initialize
    _load_from_file(AUTOSAVE_PATH)
    _autosave_timer = Timer.new()
    _autosave_timer.wait_time = AUTOSAVE_INTERVAL
    _autosave_timer.one_shot = false
    _autosave_timer.autostart = true
    add_child(_autosave_timer)
    _autosave_timer.connect("timeout", Callable(self, "_on_autosave_timeout"))
    print("SharedWorldState: Ready. Data loaded.")

# Basic getters/setters

func get_data(key: String, default: Variant = null) -> Variant:
    if key == "":
        return sws
    if sws.has(key):
        return sws[key]
    return default

func set_data(key: String, value: Variant) -> void:
    sws[key] = value
    emit_signal("state_changed", key, value)

func remove_data(key: String) -> void:
    if sws.has(key):
        sws.erase(key)
        emit_signal("state_changed", key, null)

# Update multiple keys atomically
func update_data_batch(updates: Dictionary) -> void:
    for k in updates.keys():
        sws[k] = updates[k]
    emit_signal("batch_updated", updates)

# Merge (patch) nested dictionaries (shallow merge)
func patch_data(key: String, patch: Dictionary) -> void:
    var current = {}
    if sws.has(key) and sws[key] is Dictionary:
        current = sws[key]
    for p_key in patch.keys():
        current[p_key] = patch[p_key]
    sws[key] = current
    emit_signal("state_changed", key, sws[key])

# Persistence: save/load

func save_to_file(path: String = AUTOSAVE_PATH) -> bool:
    var j = JSON.stringify(sws)
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(j)
        file.close()
        return true
    return false

func _load_from_file(path: String) -> bool:
    if not FileAccess.file_exists(path):
        sws = {}
        return false
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        sws = {}
        return false
    var txt := file.get_as_text()
    file.close()
    var parsed = JSON.parse_string(txt)
    if typeof(parsed) == TYPE_DICTIONARY:
        sws = parsed.duplicate(true)
        return true
    sws = {}
    return false

func load_from_file(path: String) -> bool:
    return _load_from_file(path)

# Autosave handler
func _on_autosave_timeout() -> void:
    save_to_file(AUTOSAVE_PATH)

# Utility helpers
func dump_pretty() -> String:
    # Gunakan JSON.stringify untuk membuat string JSON yang rapi
    var json_string = JSON.stringify(sws, "\t") # <-- Baris 97 sekarang (kemungkinan besar)
    # print(json_string) # <-- Jika Anda ingin mencetak ke terminal, uncomment baris ini
    return json_string

func clear_all() -> void:
    sws.clear()
    emit_signal("batch_updated", {})

# Simple search helper
func find_entities_by_tag(tag: String) -> Array:
    var out := []
    if sws.has("entities") and sws["entities"] is Array:
        for e in sws["entities"]:
            if typeof(e) == TYPE_DICTIONARY and e.has("tags") and tag in e["tags"]:
                out.append(e)
    return out
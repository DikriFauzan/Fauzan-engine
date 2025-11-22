extends Node

## CinemaAgent - NeoEngine v1
## Handles cinematic sequences, cutscenes, camera control, and visual storytelling

var sws
var active_cutscene: String = ""
var is_playing: bool = false
var current_cinematic_data: Dictionary = {}

func _ready() -> void:
    if not Engine.is_editor_hint():
        sws = get_node_or_null("/root/SharedWorldState")
        if not sws:
            push_error("CinemaAgent: SharedWorldState not found! Cannot operate.")
            return
        print("CinemaAgent: Loaded and connected to SWS.")

func trigger_cinematic_by_id(cutscene_id: String) -> void:
    if is_playing:
        print("CinemaAgent: Cutscene '", active_cutscene, "' already playing. Cannot trigger '", cutscene_id, "'.")
        return

    var cinematic_plan = _fetch_cinematic_plan(cutscene_id)
    if cinematic_plan.is_empty():
        printerr("CinemaAgent: No cinematic plan found for ID: ", cutscene_id)
        return

    current_cinematic_data = cinematic_plan
    active_cutscene = cutscene_id
    is_playing = true
    _execute_cinematic()

func _fetch_cinematic_plan(cutscene_id: String) -> Dictionary:
    # Ambil dari blueprint yang disimpan di SWS
    var all_cinematics = sws.get_data("last_scene_plan", {}).get("cinematics", [])
    for cinematic in all_cinematics:
        if cinematic.get("id", "") == cutscene_id:
            return cinematic
    return {}

func _execute_cinematic() -> void:
    print("CinemaAgent: Executing cinematic: ", active_cutscene)
    # Logika untuk memainkan cutscene akan diimplementasikan di sini
    # Ini adalah tempat di mana CinemaConverter akan digunakan secara internal
    # untuk menghasilkan scene/node yang sesuai dari blueprint.

    # Contoh placeholder
    await get_tree().create_timer(2.0).timeout # Simulasi durasi
    _finish_cinematic()

func _finish_cinematic() -> void:
    print("CinemaAgent: Finished cinematic: ", active_cutscene)
    active_cutscene = ""
    is_playing = false
    current_cinematic_data.clear()

# Fungsi untuk menerima event dari sistem luar (misalnya StoryAgent)
func on_story_event(event_data: Dictionary) -> void: # <-- Baris 59: Perbaikan nama parameter dan tipe data
    if event_data.has("cinematic_trigger"):
        trigger_cinematic_by_id(event_data["cinematic_trigger"])

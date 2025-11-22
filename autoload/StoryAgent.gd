extends Node

## StoryAgent - NeoEngine v1
## Generates structured scene_plan JSON for NeoEngineImporter
## Handles both direct generation and LLM bridge integration

var sws # <-- Hapus deklarasi tipe SharedWorldState
var bridge_node: Node = null  # Referensi ke NeoEngineBridge (jika ada)
var generation_in_progress: bool = false

func _ready() -> void:
    # Inisialisasi referensi SWS
    sws = get_node_or_null("/root/SharedWorldState")
    if not sws:
        printerr("StoryAgent: SharedWorldState not found! Some features may not work.")
    
    # Coba temukan bridge (opsional)
    bridge_node = get_node_or_null("/root/NeoEngineBridge")
    if bridge_node:
        print("StoryAgent: NeoEngineBridge found, LLM integration enabled.")
    else:
        print("StoryAgent: NeoEngineBridge not found, using local generation.")
    
    print("StoryAgent ready. PID: ", get_instance_id())

func generate_story_plan(prompt: String) -> Dictionary:
    if generation_in_progress:
        printerr("StoryAgent: Generation already in progress. Ignoring new request.")
        return {}
    
    generation_in_progress = true
    
    # Jika bridge ada, gunakan LLM
    if bridge_node:
        return _request_llm_generation(prompt)
    else:
        # Fallback: generate lokal
        return _generate_local_plan(prompt)

func _request_llm_generation(prompt: String) -> Dictionary:
    var constructed_prompt = _construct_llm_prompt(prompt)
    bridge_node.request_llm_generation(constructed_prompt, self, "_on_llm_response_received", "_on_llm_response_received_error")
    # Karena async, simpan status ke SWS
    if sws:
        sws.call_deferred("set_data", "story_generation_status", "in_progress")
    return {"status": "llm_request_sent", "prompt": prompt}

func _generate_local_plan(prompt: String) -> Dictionary:
    # Generate blueprint lokal jika tidak ada LLM
    var blueprint := {
        "id": "scene_plan_" + str(Time.get_unix_time_from_system()),
        "script_id": "scene_plan_" + str(Time.get_unix_time_from_system()),
        "world": {
            "name": "PrototypeWorld",
            "regions": []
        },
        "characters": [],
        "npc_ai": {},
        "quests": [],
        "classes": [],
        "skills": [],
        "combat": {},
        "economy": {},
        "cinematics": {},
        "physics": {},
        "engine_evolution": {
            "recommended_modules": [],
            "new_agents": [],
            "importer_extensions": [],
            "engine_v2_capabilities": []
        }
    }

    _save_plan_to_sws(blueprint)
    generation_in_progress = false
    return blueprint

func _on_llm_response_received(response_json_string: String) -> void:
    var parsed_response = JSON.parse_string(response_json_string)
    if typeof(parsed_response) == TYPE_DICTIONARY and _is_valid_plan_structure(parsed_response):
        _save_plan_to_sws(parsed_response)
        print("StoryAgent: Valid plan received from LLM and saved to SWS.")
    else:
        printerr("StoryAgent: LLM response invalid. Falling back to local generation.")
        var fallback_plan = _generate_local_plan("fallback")
        _save_plan_to_sws(fallback_plan)
    
    generation_in_progress = false
    if sws:
        sws.call_deferred("set_data", "story_generation_status", "completed")

func _on_llm_response_received_error(response_code: int) -> void:
    printerr("StoryAgent: LLM request failed with code: ", response_code)
    var fallback_plan = _generate_local_plan("error_fallback")
    _save_plan_to_sws(fallback_plan)
    generation_in_progress = false
    if sws:
        sws.call_deferred("set_data", "story_generation_status", "error")

func _is_valid_plan_structure(plan: Dictionary) -> bool:
    return plan.has("world") and plan.has("characters") and plan.has("economy")

func _save_plan_to_sws(plan: Dictionary) -> void:
    if sws and sws.has_method("set_data"):
        sws.call_deferred("set_data", "last_scene_plan", plan)
        print("StoryAgent: Blueprint saved to SharedWorldState (deferred). id=", plan.get("id", "unknown"))
    else:
        printerr("StoryAgent: SharedWorldState not available. Falling back to local save.")
        _fallback_persist_local(plan)

func _fallback_persist_local(blueprint: Dictionary) -> void:
    var dir: String = "user://generated/scene_plans/" # <-- Tipe eksplisit untuk keamanan
    DirAccess.make_dir_recursive_absolute(dir)
    # Perbaikan: Deklarasikan tipe fname secara eksplisit
    var fname: String = dir + (blueprint.get("script_id", blueprint.get("id", "scene_unknown")) + ".json") # <-- Baris 114 (kemungkinan besar)
    var f = FileAccess.open(fname, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(blueprint))
        f.close()
        print("StoryAgent: fallback saved plan to ", fname)
    else:
        printerr("StoryAgent: failed to write fallback plan to ", fname)

func _construct_llm_prompt(user_prompt: String) -> String:
    var base_instruction = "You are NeoEngine v1, a multi-agent generative game engine. Generate a structured JSON blueprint for a game scene based on the following user prompt: "
    return base_instruction + user_prompt

# func _process(_delta: float) -> void:
#    # Update status, logging, atau logic lainnya
#    pass # Nonaktifkan dulu jika tidak diperlukan
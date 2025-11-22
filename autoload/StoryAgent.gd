extends Node

## StoryAgent - NeoEngine v1 (Hybrid Version)
## Generates structured scene_plan JSON (Blueprint) for the Orchestrator.
## Handles both local fallback generation and future LLM bridge integration.

# --- Dependensi ---
var sws: Node = null 
var orchestrator: Node = null
var bridge_node: Node = null 

# --- State Internal ---
var generation_in_progress: bool = false
var last_prompt: String = ""

# --- Konfigurasi File Lokal ---
# Menggunakan path "user://" yang dianggap absolut oleh Godot
const LOCAL_PLAN_DIR: String = "user://generated/scene_plans/"

func _ready() -> void:
    # Inisialisasi referensi Autoload wajib
    sws = get_node_or_null("/root/SharedWorldState")
    orchestrator = get_node_or_null("/root/NeoEngineOrchestrator")
    
    if not sws or not orchestrator:
        push_error("StoryAgent: SharedWorldState atau Orchestrator tidak ditemukan. Inisialisasi gagal.")
        return
        
    # Coba temukan bridge (opsional, untuk masa depan)
    bridge_node = get_node_or_null("/root/NeoEngineBridge")
    if bridge_node:
        print("StoryAgent: NeoEngineBridge ditemukan, integrasi LLM di masa depan diaktifkan.")
    else:
        print("StoryAgent: NeoEngineBridge tidak ditemukan, menggunakan generasi lokal.")
    
    print("StoryAgent: Siap. PID: ", get_instance_id())


# Fungsi utama yang dipanggil oleh CommandAgent
func generate_story_plan(prompt: String) -> void:
    if generation_in_progress:
        printerr("StoryAgent: Generation already in progress. Ignoring new request.")
        return 
    
    last_prompt = prompt
    generation_in_progress = true
    
    print("StoryAgent: Menerima prompt: '%s'. Memulai generasi plan..." % prompt)
    
    # Memanggil plan lokal (fallback)
    var blueprint: Dictionary = _generate_local_plan(prompt)
    
    if orchestrator.has_method("execute_plan"):
        # Setelah StoryAgent membuat plan, ia menyuruh Orchestrator untuk melaksanakannya.
        orchestrator.execute_plan(blueprint)
    
    generation_in_progress = false


# --- LLM Integration (Future Use) ---

func _request_llm_generation(prompt: String) -> void:
    var _constructed_prompt = _construct_llm_prompt(prompt) 
    # bridge_node.request_llm_generation(_constructed_prompt, self, "_on_llm_response_received", "_on_llm_response_received_error")
    
    if sws:
        sws.set_data("story_generation_status", "in_progress")

func _on_llm_response_received(response_json_string: String) -> void:
    var parsed_response = JSON.parse_string(response_json_string)
    
    if typeof(parsed_response) == TYPE_DICTIONARY and _is_valid_plan_structure(parsed_response):
        _save_plan_to_sws(parsed_response)
        print("StoryAgent: Valid plan received from LLM and saved to SWS.")
    else:
        printerr("StoryAgent: LLM response invalid. Falling back to local generation.")
        var fallback_plan = _generate_local_plan("LLM fallback due to invalid JSON")
        _save_plan_to_sws(fallback_plan)
    
    generation_in_progress = false
    if sws:
        sws.set_data("story_generation_status", "completed")

func _on_llm_response_received_error(response_code: int) -> void:
    printerr("StoryAgent: LLM request failed with code: ", response_code)
    var fallback_plan = _generate_local_plan("LLM error fallback: code %d" % response_code)
    _save_plan_to_sws(fallback_plan)
    generation_in_progress = false
    if sws:
        sws.set_data("story_generation_status", "error")

func _construct_llm_prompt(user_prompt: String) -> String:
    var base_instruction = "You are NeoEngine v1, a multi-agent generative game engine. Generate a structured JSON blueprint for a game scene based on the following user prompt: "
    return base_instruction + user_prompt

# --- Local Fallback & Persistance ---

func _generate_local_plan(prompt: String) -> Dictionary:
    # Generate blueprint lokal jika tidak ada LLM / LLM error
    var blueprint: Dictionary = {
        "id": "scene_plan_" + str(Time.get_unix_time_from_system()),
        "script_id": "scene_plan_" + str(Time.get_unix_time_from_system()),
        "world": {
            "name": "GeneratedScene: %s" % prompt,
            "regions": []
        },
        "characters": [{
             "name": "Protagonist",
             "role": "main_player"
        }],
        "npc_ai": {},
        "quests": [],
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
    
    # Menggunakan call_deferred untuk menghindari masalah timing saat Godot sedang startup
    call_deferred("_fallback_persist_local", blueprint) 
    return blueprint

func _is_valid_plan_structure(plan: Dictionary) -> bool:
    # Memeriksa kunci wajib
    return plan.has("world") and plan.has("characters") and plan.has("economy")

func _save_plan_to_sws(plan: Dictionary) -> void:
    if sws and sws.has_method("set_data"):
        # Menyimpan plan terakhir agar Orchestrator bisa mengambilnya
        sws.set_data("last_scene_plan", plan)
        print("StoryAgent: Blueprint saved to SharedWorldState (deferred). id=", plan.get("id", "unknown"))
    else:
        printerr("StoryAgent: SharedWorldState not available.")

func _fallback_persist_local(blueprint: Dictionary) -> void:
    # FIX 5: Menggunakan metode statis Godot 4 yang paling aman untuk membuat folder
    # Karena LOCAL_PLAN_DIR menggunakan "user://", kita bisa menggunakan make_dir_recursive_absolute.
    var error_code = DirAccess.make_dir_recursive_absolute(LOCAL_PLAN_DIR)
    
    if error_code != OK and error_code != ERR_FILE_EXISTS:
        printerr("StoryAgent: Gagal membuat direktori lokal: %s (Error: %d)" % [LOCAL_PLAN_DIR, error_code])
        return

    var fname: String = LOCAL_PLAN_DIR + (blueprint.get("script_id", blueprint.get("id", "scene_unknown")) + ".json")
    
    # Godot 4: Menggunakan FileAccess.open dengan parameter kedua sebagai mode
    var f: FileAccess = FileAccess.open(fname, FileAccess.WRITE) 
    
    if f:
        f.store_string(JSON.stringify(blueprint, "\t")) 
        print("StoryAgent: fallback saved plan to ", fname)
    else:
        # Menambahkan pesan error spesifik jika gagal
        printerr("StoryAgent: failed to write fallback plan to %s (Error: %d)" % [fname, FileAccess.get_open_error()])

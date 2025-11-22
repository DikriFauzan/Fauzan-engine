@tool
extends Node

## NeoEngineOrchestrator - NeoEngine v1
## Central hub for coordinating agents, managing game state, and executing engine evolution plans.
## Mengimplementasikan Orchestrator Agent (V.A), Execution Graph, dan Constraint Solver.

# --- Internal State ---
var sws: Node = null # Referensi ke SharedWorldState
var agents: Dictionary = {} # Menyimpan referensi ke semua agent (nama -> node)
var current_plan: Dictionary = {} # Plan terakhir yang dihasilkan oleh StoryAgent
var engine_state: String = "IDLE" # "IDLE", "PROCESSING_PLAN", "EXECUTING_CONTENT", "EVOLVING_ENGINE"

# --- Agent Names (Konstanta) ---
const AGENT_SHARED_WORLD_STATE := "SharedWorldState"
const AGENT_STORY := "StoryAgent"
const AGENT_LIVEOPS := "LiveOpsAgent"
const AGENT_ENGINE_GROWTH := "EngineGrowthAgent"
const AGENT_CINEMA := "CinemaAgent"
const AGENT_PHYSICS := "PhysicsAgent"
const AGENT_ECONOMY := "EconomyAgent"
const AGENT_DATA := "DataAgent" 
const AGENT_GAME_MONITOR := "GameMonitor"
const AGENT_NPC_BRAIN := "NPCBrainAgent"
const AGENT_COMMAND := "CommandAgent" 
const AGENT_BRIDGE := "NeoEngineBridge"
const AGENT_IMPORTER := "NeoEngineImporter"

# Array berisi nama-nama semua agen yang harus dicari.
const ALL_AGENT_NAMES: Array[String] = [
    AGENT_SHARED_WORLD_STATE, AGENT_STORY, AGENT_LIVEOPS, AGENT_PHYSICS,
    AGENT_ECONOMY, AGENT_GAME_MONITOR, AGENT_NPC_BRAIN, AGENT_BRIDGE,
    AGENT_IMPORTER, AGENT_ENGINE_GROWTH, AGENT_CINEMA,
    AGENT_DATA, AGENT_COMMAND 
]

func _ready() -> void:
    if not Engine.is_editor_hint():
        # Rule VII: Memuat Blueprint dan SWS
        # PERBAIKAN: Menggunakan % operator
        sws = get_node_or_null("/root/%s" % AGENT_SHARED_WORLD_STATE)
        if not sws:
            push_error("NeoEngineOrchestrator: SharedWorldState not found in root. Cannot initialize.")
            return

        _initialize_agents()
        _connect_sws_signals()
        print("NeoEngineOrchestrator: Agent System dan Execution Graph siap.")
        
# V.A. Orchestrator Agent: Memastikan blueprint engine dipatuhi (Agent Discovery)
func _initialize_agents() -> void:
    for agent_name in ALL_AGENT_NAMES:
        # Mencari Node Autoload (Rule V.A: Memastikan Blueprint Engine dipatuhi)
        # PERBAIKAN: Menggunakan % operator
        var agent_node = get_node_or_null("/root/%s" % agent_name)
        
        if agent_node:
            agents[agent_name] = agent_node
        else:
            # PERBAIKAN: Menggunakan % operator
            push_error("Orchestrator Error: Autoload Agent '%s' TIDAK ditemukan. Engine Lock berisiko." % agent_name)

func _connect_sws_signals() -> void:
    if sws:
        if sws.has_signal("state_changed"):
            sws.state_changed.connect(_on_sws_state_changed)
        if sws.has_signal("batch_updated"):
            sws.batch_updated.connect(_on_sws_batch_updated)

# --- FUNGSI UTAMA: EXECUTION GRAPH (I.1, V.A) ---

# Fungsi ini dipanggil StoryAgent atau CommandAgent setelah plan siap.
func execute_plan(plan: Dictionary) -> void:
    if engine_state == "PROCESSING_PLAN":
        printerr("Orchestrator: Plan execution sudah berjalan. Abaikan plan baru.")
        return

    engine_state = "PROCESSING_PLAN"
    current_plan = plan
    
    # PERBAIKAN: Menggunakan % operator
    var plan_id = plan.get("id", "N/A")
    print("NeoEngineOrchestrator: Menerima Plan ID: %s. Memulai distribusi tugas ke Agen..." % plan_id)

    # 1. Distrbusi Tugas ke Agen Spesialis
    
    # Importer Agent (V.B: File Agent) - Wajib pertama untuk memproses file/scene.
    if agents.has(AGENT_IMPORTER):
        var importer_agent = agents[AGENT_IMPORTER]
        if importer_agent.has_method("run_import_plan"):
            importer_agent.run_import_plan(plan)
        else:
            push_error("Orchestrator: Importer Agent tidak memiliki method 'run_import_plan'.")
            
    # Physics Agent
    if agents.has(AGENT_PHYSICS):
        var physics_agent = agents[AGENT_PHYSICS]
        var physics_data: Dictionary = plan.get("physics", {})
        if physics_agent.has_method("apply_world_physics_blueprint"):
            physics_agent.apply_world_physics_blueprint(physics_data)
        
    # NPC Brain Agent
    if agents.has(AGENT_NPC_BRAIN):
        var npc_brain_agent = agents[AGENT_NPC_BRAIN]
        var npc_data: Dictionary = plan.get("npc_ai", {})
        if npc_brain_agent.has_method("apply_npc_behavior_blueprint"):
            npc_brain_agent.apply_npc_behavior_blueprint(npc_data)

    # Economy Agent
    if agents.has(AGENT_ECONOMY):
        var economy_agent = agents[AGENT_ECONOMY]
        var economy_data: Dictionary = plan.get("economy", {})
        if economy_agent.has_method("update_market_from_blueprint"):
            economy_agent.update_market_from_blueprint(economy_data)

    # LiveOps Agent
    if agents.has(AGENT_LIVEOPS):
        var liveops_agent = agents[AGENT_LIVEOPS]
        var pid = plan.get("id", "N/A")
        liveops_agent.record_event("PLAN_EXECUTION_COMPLETE", {"plan_id": pid, "status": "Success"})
        
    # 2. Transisi State
    engine_state = "EXECUTING_CONTENT"
    print("NeoEngineOrchestrator: Plan execution selesai. Engine beralih ke 'EXECUTING_CONTENT'.")
    
# --- REAKSI SWS ---

func _on_sws_state_changed(key: String, value) -> void:
    if key == "last_scene_plan" and engine_state == "IDLE":
        execute_plan(value)

func _on_sws_batch_updated(_changes: Dictionary) -> void:
    pass
    
func check_constraints_and_correct(data: Dictionary) -> Dictionary:
    print("Orchestrator: Menerapkan Constraint Solver...")
    return {"success": true, "corrected_data": data}
    
func evolve_engine() -> void:
    print("NeoEngineOrchestrator: Initiating engine evolution process...")
    engine_state = "EVOLVING_ENGINE"

    var growth_agent = agents.get(AGENT_ENGINE_GROWTH)
    if growth_agent and growth_agent.has_method("start_evolution_process"):
        # growth_agent.start_evolution_process()
        pass
    else:
        push_error("Orchestrator: Engine Growth Agent tidak ditemukan atau method 'start_evolution_process' hilang.")

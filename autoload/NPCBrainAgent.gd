@tool
extends Node

## NPCBrainAgent - NeoEngine v1
## Handles AI decision making, state management, and behavior trees for NPCs
## Integrates with SharedWorldState for world context and event-driven behavior

# --- Internal State ---
var sws: Node = null # Referensi ke SharedWorldState
var npc_states: Dictionary = {} # Menyimpan state per NPC (id -> state_dict)
var behavior_trees: Dictionary = {} # Menyimpan tree per NPC type (type -> tree_resource)
var registered_npcs: Array[String] = [] # Daftar ID NPC yang terdaftar

# --- Core NPC State Structure ---
## State Dictionary Keys:
const STATE_POS := "position" # Vector3
const STATE_ROT := "rotation" # Basis/Quaternion
const STATE_HEALTH := "health" # float
const STATE_CURRENT_STATE := "current_state" # String ("idle", "patrol", "chase", "combat", "flee", "dead")
const STATE_TARGET_NPC := "target_npc_id" # String
const STATE_TARGET_PLAYER := "target_player_id" # String
const STATE_INVENTORY := "inventory" # Dictionary
const STATE_LAST_SEEN_POS := "last_seen_pos" # Vector3
const STATE_ALERT_LEVEL := "alert_level" # float (0.0 - 1.0)
const STATE_CURRENT_ACTION := "current_action" # Dictionary
const STATE_CURRENT_ACTION_TIMER := "current_action_timer" # float

# --- Behavior Tree Nodes (Simplified) ---
const BT_NODE_TYPE := "type" # "sequence", "selector", "action", "condition"
const BT_NODE_CHILDREN := "children" # Array[Dictionary]
const BT_NODE_ACTION := "action" # String ("move_to", "attack", "idle", "say")
const BT_NODE_CONDITION := "condition" # String ("is_player_near", "health_low", "has_target")
const BT_NODE_PARAMS := "params" # Dictionary

func _ready() -> void:
    if not Engine.is_editor_hint():
        sws = get_node_or_null("/root/SharedWorldState")
        if not sws:
            push_error("NPCBrainAgent: SharedWorldState not found in root. Cannot initialize.")
            return
        print("NPCBrainAgent: Loaded and connected to SWS.")

func _process(_delta: float) -> void:
    # Proses update logika AI untuk semua NPC yang terdaftar
    for npc_id in registered_npcs:
        _update_npc_logic(npc_id, _delta)

func _update_npc_logic(npc_id: String, delta: float) -> void:
    if not npc_states.has(npc_id):
        printerr("NPCBrainAgent: NPC ", npc_id, " not found in states during update.")
        return

    var state = npc_states[npc_id]
    var npc_type = state.get("type", "default")
    var behavior_tree = behavior_trees.get(npc_type, _get_default_behavior_tree(npc_type))

    if behavior_tree.is_empty():
        printerr("NPCBrainAgent: No behavior tree for type ", npc_type, " of NPC ", npc_id)
        return

    # Jalankan behavior tree
    var action = _execute_behavior_tree(behavior_tree, state, delta)
    if not action.is_empty():
        _apply_action_to_npc(npc_id, action, state)

    # Simpan state terbaru
    npc_states[npc_id] = state

func register_npc(npc_id: String, npc_type: String, initial_position: Vector3) -> void:
    if npc_states.has(npc_id):
        printerr("NPCBrainAgent: NPC ", npc_id, " is already registered.")
        return

    var initial_state: Dictionary = {
        STATE_POS: initial_position,
        STATE_HEALTH: 100.0,
        STATE_CURRENT_STATE: "idle",
        STATE_ALERT_LEVEL: 0.0,
        STATE_INVENTORY: {},
        STATE_LAST_SEEN_POS: Vector3.ZERO,
        STATE_CURRENT_ACTION: {},
        STATE_CURRENT_ACTION_TIMER: 0.0,
        "type": npc_type # Tambahkan type ke state untuk lookup behavior tree
    }

    npc_states[npc_id] = initial_state
    registered_npcs.append(npc_id)
    print("NPCBrainAgent: Registered NPC ", npc_id, " (type: ", npc_type, ")")

func _execute_behavior_tree(tree_root: Dictionary, npc_state: Dictionary, delta: float) -> Dictionary:
    # Eksekusi root node dari behavior tree
    return _execute_bt_node(tree_root, npc_state, delta)

func _execute_bt_node(node: Dictionary, npc_state: Dictionary, delta: float) -> Dictionary:
    var node_type = node.get(BT_NODE_TYPE, "action")

    # Deklarasikan result di awal fungsi untuk menghindari error scope
    var result: Dictionary = {}

    match node_type:
        "sequence":
            for child_node in node.get(BT_NODE_CHILDREN, []):
                result = _execute_bt_node(child_node, npc_state, delta)
                if result.is_empty():
                    return {} # Gagal, hentikan sequence
            # Jika semua child sukses, kembalikan action terakhir (dari result)
            return result
        "selector":
            for child_node in node.get(BT_NODE_CHILDREN, []):
                result = _execute_bt_node(child_node, npc_state, delta)
                if not result.is_empty():
                    return result # Sukses, kembalikan hasil
            return {} # Semua gagal
        "condition":
            var condition = node.get(BT_NODE_CONDITION, "")
            if _evaluate_condition(condition, npc_state):
                # Jika condition true, eksekusi child pertama
                var children = node.get(BT_NODE_CHILDREN, [])
                if not children.is_empty():
                    return _execute_bt_node(children[0], npc_state, delta)
            return {}
        "action":
            var action_name = node.get(BT_NODE_ACTION, "")
            var params = node.get(BT_NODE_PARAMS, {})
            # Kembalikan action yang siap dijalankan
            return { "name": action_name, "params": params }
        _:
            printerr("NPCBrainAgent: Unknown BT node type: ", node_type)
            return {}

func _evaluate_condition(condition: String, npc_state: Dictionary) -> bool:
    # Evaluasi kondisi berdasarkan state NPC
    match condition:
        "is_player_near":
            # Cek apakah player ada di dekat NPC
            # Implementasi: ambil posisi player dari SWS, hitung jarak ke npc_state[STATE_POS]
            var player_pos = sws.get_data("player_position", Vector3.ZERO)
            var npc_pos = npc_state.get(STATE_POS, Vector3.ZERO)
            var distance = player_pos.distance_to(npc_pos)
            return distance < 10.0 # Threshold hardcoded untuk contoh
        "health_low":
            return npc_state.get(STATE_HEALTH, 100.0) < 30.0
        "has_target":
            return not npc_state.get(STATE_TARGET_PLAYER, "").is_empty() or not npc_state.get(STATE_TARGET_NPC, "").is_empty()
        _:
            printerr("NPCBrainAgent: Unknown condition: ", condition)
            return false

func _apply_action_to_npc(npc_id: String, action: Dictionary, npc_state: Dictionary) -> void:
    var action_name = action.get("name", "")
    var params = action.get("params", {})
    # Terjemahkan action ke perintah game engine
    match action_name:
        "move_to":
            var target_pos = params.get("position", Vector3.ZERO)
            print("NPCBrainAgent: NPC ", npc_id, " moving to ", target_pos)
            # Kirim perintah ke NPC node (misalnya via signal atau RPC)
            # Example: emit_signal("npc_move_request", npc_id, target_pos)
        "attack":
            var target = params.get("target", "")
            print("NPCBrainAgent: NPC ", npc_id, " attacking ", target)
            # Kirim perintah ke NPC node
            # Example: emit_signal("npc_attack_request", npc_id, target)
        "idle":
            print("NPCBrainAgent: NPC ", npc_id, " is idling.")
            # Update state
            npc_state[STATE_CURRENT_STATE] = "idle"
        "say":
            var text = params.get("text", "...")
            print("NPCBrainAgent: NPC ", npc_id, " says: ", text)
        _:
            printerr("NPCBrainAgent: Unknown action: ", action_name)

func _get_default_behavior_tree(npc_type: String) -> Dictionary:
    # Kembalikan behavior tree default berdasarkan type
    # Ini bisa dibaca dari file blueprint di masa depan
    match npc_type:
        "guard":
            return {
                BT_NODE_TYPE: "selector",
                BT_NODE_CHILDREN: [
                    {
                        BT_NODE_TYPE: "condition",
                        BT_NODE_CONDITION: "is_player_near",
                        BT_NODE_CHILDREN: [
                            {
                                BT_NODE_TYPE: "action",
                                BT_NODE_ACTION: "chase_player"
                            }
                        ]
                    },
                    {
                        BT_NODE_TYPE: "action",
                        BT_NODE_ACTION: "patrol"
                    }
                ]
            }
        "merchant":
            return {
                BT_NODE_TYPE: "action",
                BT_NODE_ACTION: "idle",
                BT_NODE_PARAMS: { "text": "Welcome, traveler!" }
            }
        _:
            # Default: idle
            return {
                BT_NODE_TYPE: "action",
                BT_NODE_ACTION: "idle"
            }

# Fungsi untuk menerima event dunia yang mempengaruhi NPC
func on_world_event(event_data: Dictionary) -> void: # <-- Perbaikan: Ganti 'event_ Dictionary' menjadi 'event_data: Dictionary'
    var event_type = event_data.get("type", "")
    var _affected_npcs = event_data.get("npcs_affected", []) # <-- Gunakan underscore untuk variabel tidak digunakan

    match event_type:
        "player_moved":
            var player_pos = event_data.get("position", Vector3.ZERO)
            # Update state semua NPC tentang posisi player (jika dalam jarak tertentu)
            for npc_id in registered_npcs:
                var state = npc_states[npc_id]
                var npc_pos = state.get(STATE_POS, Vector3.ZERO)
                if player_pos.distance_to(npc_pos) < 20.0: # Update jika dekat
                    state[STATE_LAST_SEEN_POS] = player_pos
                    # Trigger logic update jika perlu
        "npc_damaged":
            var target_npc = event_data.get("target_npc_id", "")
            if registered_npcs.has(target_npc):
                var state = npc_states[target_npc]
                state[STATE_HEALTH] = max(0.0, state.get(STATE_HEALTH, 100.0) - event_data.get("damage", 0.0))
                state[STATE_ALERT_LEVEL] = min(1.0, state.get(STATE_ALERT_LEVEL, 0.0) + 0.2)
                # Trigger logic update
        "global_alarm":
            for npc_id in registered_npcs:
                var state = npc_states[npc_id]
                state[STATE_CURRENT_STATE] = "alert"
                state[STATE_ALERT_LEVEL] = 1.0
                # Trigger logic update
        _:
            # Event lain bisa ditangani di sini
            pass

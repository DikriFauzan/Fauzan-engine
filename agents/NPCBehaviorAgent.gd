# agents/NPCBehaviorAgent.gd
extends Node
# NPCBehaviorAgent - Generates complex NPC behaviors like BehaviorTrees, StateMachines, or
# custom logic scripts based on NPC data from SharedWorldState.
# It can output these as Godot resources (.tres) or GDScript files.

const BEHAVIOR_SCRIPT_TEMPLATE = """
# Generated NPC Behavior Script for NPC: {npc_id}
# Based on personality: {personality_type}, mood: {default_mood}

extends Node

var personality: String = "{personality_type}"
var default_mood: String = "{default_mood}"
var current_mood: String = default_mood
var interaction_cooldown: float = 0.0

func _ready() -> void:
    print("NPCBehaviorScript for {npc_id} ready.")

func update_behavior(delta_time: float, context_data: Dictionary) -> void:
    # Example: Mood change based on context
    var player_nearby = context_data.get("player_nearby", false)
    var recent_events = context_data.get("recent_events", [])

    if player_nearby:
        if "player_helped_npc" in recent_events:
            current_mood = "happy"
        elif "player_harmed_npc" in recent_events:
            current_mood = "angry"
        else:
            current_mood = default_mood # Revert to default if no interaction

    # Example: Simple state machine based on mood
    match current_mood:
        "happy":
            # Do happy things, maybe give player a buff or friendly dialogue
            pass
        "angry":
            # Do angry things, maybe attack or give hostile dialogue
            pass
        "sad":
            # Do sad things, maybe avoid player or give sad dialogue
            pass
        _:
            # Default behavior
            pass

    # Example: Interaction cooldown
    if interaction_cooldown > 0:
        interaction_cooldown -= delta_time

func can_interact() -> bool:
    return interaction_cooldown <= 0

func reset_behavior() -> void:
    current_mood = default_mood
    interaction_cooldown = 0.0

"""

func _ready() -> void:
    print("NPCBehaviorAgent ready. PID: ", get_instance_id())

# --- Main Function: Generate Behavior ---
func generate_behavior(npc_id: String, npc_data: Dictionary) -> Resource:
    # Validate input
    if npc_id.is_empty() or typeof(npc_data) != TYPE_DICTIONARY:
        printerr("NPCBehaviorAgent: Invalid input for NPC ", npc_id)
        return null

    # --- 1. Analyze NPC Data ---
    var personality_type = npc_data.get("personality", "neutral")
    var default_mood = npc_data.get("default_mood", "neutral")
    var behavior_type = npc_data.get("behavior_type", "state_machine") # Or "behavior_tree", "custom_script"
    var dialogue_tree_ref = npc_data.get("dialogue_tree", null) # Reference to dialogue data
    var schedule_data = npc_data.get("schedule", {}) # Daily schedule
    var ai_params = npc_data.get("ai_params", {}) # Custom parameters for AI logic

    # --- 2. Choose Generation Method ---
    var behavior_resource: Resource = null
    match behavior_type:
        "custom_script":
            behavior_resource = _generate_custom_script(npc_id, personality_type, default_mood)
        "state_machine":
            behavior_resource = _generate_state_machine(npc_id, personality_type, default_mood)
        "behavior_tree":
            behavior_resource = _generate_behavior_tree(npc_id, personality_type, default_mood)
        _:
            printerr("NPCBehaviorAgent: Unknown behavior_type '", behavior_type, "' for NPC ", npc_id, ". Using default state_machine.")
            behavior_resource = _generate_state_machine(npc_id, personality_type, default_mood)

    # --- 3. Post-Process (Optional: Save to file, attach to NPC instance) ---
    if behavior_resource:
        # Example: Save the generated script as a .gd file (requires Godot Editor context or careful runtime handling)
        # This is complex for runtime. Saving as a custom Resource (like a StateMachine or BehaviorTree resource) is safer.
        # For now, we'll just return the resource.
        # _save_behavior_resource(behavior_resource, npc_id, behavior_type)
        print("NPCBehaviorAgent: Generated behavior for NPC ", npc_id, " (Type: ", behavior_type, ")")
    else:
        printerr("NPCBehaviorAgent: Failed to generate behavior for NPC ", npc_id)

    return behavior_resource

# --- Generation Methods ---

func _generate_custom_script(npc_id: String, personality_type: String, default_mood: String) -> Script:
    # Create a dynamic script content based on NPC data
    var script_content = BEHAVIOR_SCRIPT_TEMPLATE.format({
        "npc_id": npc_id,
        "personality_type": personality_type,
        "default_mood": default_mood
    })

    # Create a new script resource
    var new_script = GDScript.new()
    new_script.source_code = script_content

    # Validate script syntax (optional, requires Editor context in some cases)
    var err = new_script.reload() # Reload compiles it
    if err != OK:
        printerr("NPCBehaviorAgent: Generated script for NPC ", npc_id, " has errors.")
        return null

    return new_script

func _generate_state_machine(npc_id: String, personality_type: String, default_mood: String) -> Resource:
    # Example: Create a custom resource representing a simple state machine
    # In a real implementation, this might be a dedicated StateMachine.gd resource type.
    var state_machine_resource = Resource.new()
    state_machine_resource.set_script(load("res://scripts/NPCStateMachine.gd")) # Assume this script exists

    # Populate the resource with states based on personality/mood
    var states = {}
    for mood in ["happy", "sad", "angry", default_mood]:
        states[mood] = {
            "actions": [], # e.g., ["move_to_location", "say_line"]
            "transitions": {} # e.g., {"happy": {"trigger": "player_helped", "target": "happy"}}
        }
    state_machine_resource.set("states", states)
    state_machine_resource.set("initial_state", default_mood)

    return state_machine_resource

func _generate_behavior_tree(npc_id: String, personality_type: String, default_mood: String) -> Resource:
    # Example: Create a custom resource representing a simple behavior tree structure
    # In a real implementation, this might be a dedicated BehaviorTree.gd resource type.
    var behavior_tree_resource = Resource.new()
    behavior_tree_resource.set_script(load("res://scripts/NPCBehaviorTree.gd")) # Assume this script exists

    # Populate the resource with a basic tree structure based on personality
    var root_selector = {
        "type": "Selector",
        "children": [
            {"type": "Condition", "check": "player_nearby"},
            {"type": "Action", "action": "wander"},
        ]
    }
    if personality_type == "aggressive":
        root_selector["children"].insert(0, {"type": "Action", "action": "attack_player"})

    behavior_tree_resource.set("tree_root", root_selector)

    return behavior_tree_resource

# --- Helper to save generated resource (Advanced, usually Editor-only or pre-runtime) ---
func _save_behavior_resource(resource: Resource, npc_id: String, behavior_type: String) -> void:
    var dir_path = "res://generated/npc_behaviors/"
    DirAccess.make_dir_recursive_absolute(dir_path)
    var file_path = dir_path + npc_id + "_" + behavior_type + ".tres"
    var err = ResourceSaver.save(file_path, resource)
    if err == OK:
        print("NPCBehaviorAgent: Saved behavior resource to ", file_path)
    else:
        printerr("NPCBehaviorAgent: Failed to save behavior resource to ", file_path, " (Error: ", err, ")")

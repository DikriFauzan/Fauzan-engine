# agents/WorldEvolutionAgent.gd
extends Node
# Analyzes the current world state and player behavior data to suggest content changes,
# balance adjustments, or dynamic world events. Interacts with SharedWorldState and GameMonitor telemetry.

# Configuration for analysis thresholds
var analysis_config: Dictionary = {
    "telemetry_window_hours": 24, # Analyze last 24 hours of data
    "low_retention_threshold": 0.1, # If D1 retention < 10%, flag for action
    "high_engagement_threshold": 0.8, # If session time > 80% of average, consider adding content
    "bug_frequency_threshold": 5, # If > 5 crashes per 1000 sessions, flag bug
    "npc_frustration_threshold": 0.3, # If > 30% of players show frustration with an NPC, flag
    "resource_scarcity_threshold": 0.05, # If < 5% of players have resource X, consider buffing spawn
    "quest_completion_threshold": 0.95 # If > 95% of players complete a quest, consider buffing difficulty
}

# Internal state for analysis results
var _last_analysis_time: int = 0
var _analysis_results: Dictionary = {}

func _ready() -> void:
    print("WorldEvolutionAgent ready. PID: ", get_instance_id())
    # Load config from SWS or external source if needed
    _load_analysis_config()

func _load_analysis_config() -> void:
    var sws_node = get_node_or_null("/root/SharedWorldState")
    if sws_node and sws_node.has_method("get_data"):
        var config = sws_node.call("get_data", "world_evolution_config", {})
        if typeof(config) == TYPE_DICTIONARY:
            analysis_config.merge(config, true)
            print("WorldEvolutionAgent: Loaded/updated analysis config from SWS.")
        else:
            print("WorldEvolutionAgent: No world_evolution_config in SWS, using defaults.")

# --- Main Analysis Function ---
func analyze_world_and_player_behavior() -> Dictionary:
    var current_time = Time.get_unix_time_from_system()
    var time_since_last_analysis = current_time - _last_analysis_time

    # Avoid running analysis too frequently
    if time_since_last_analysis < 3600: # Run at most every hour
        print("WorldEvolutionAgent: Skipping analysis, last run was ", time_since_last_analysis, " seconds ago.")
        return _analysis_results # Return cached results or empty dict

    print("WorldEvolutionAgent: Starting world & player behavior analysis...")

    var sws_node = get_node_or_null("/root/SharedWorldState")
    if not (sws_node and sws_node.has_method("get_data")):
        printerr("WorldEvolutionAgent: SharedWorldState not available for analysis.")
        return {}

    var telemetry_data = sws_node.call("get_data", "telemetry_events", [])
    var world_data = sws_node.call("get_data", "world", {})
    var npc_data = sws_node.call("get_data", "npc_states", {})
    var quest_data = sws_node.call("get_data", "quests", {})

    var results = {
        "timestamp": current_time,
        "suggested_events": [],
        "suggested_npc_changes": [],
        "suggested_quest_changes": [],
        "suggested_world_changes": [],
        "suggested_balance_adjustments": [],
        "identified_bugs": [],
        "high_level_insights": {}
    }

    # --- Analyze Telemetry ---
    if typeof(telemetry_data) == TYPE_ARRAY:
        results.merge(_analyze_telemetry(telemetry_data), true)

    # --- Analyze World State ---
    if typeof(world_data) == TYPE_DICTIONARY:
        results.merge(_analyze_world_state(world_data), true)

    # --- Analyze NPC State ---
    if typeof(npc_data) == TYPE_DICTIONARY:
        results.merge(_analyze_npc_state(npc_data), true)

    # --- Analyze Quest State ---
    if typeof(quest_data) == TYPE_DICTIONARY:
        results.merge(_analyze_quest_state(quest_data), true)

    # --- Generate Insights ---
    results["high_level_insights"] = _generate_insights(results)

    _analysis_results = results
    _last_analysis_time = current_time

    print("WorldEvolutionAgent: Analysis complete. Found ", results["suggested_events"].size(), " events, ",
          results["suggested_npc_changes"].size(), " NPC changes, ",
          results["suggested_quest_changes"].size(), " quest changes, ",
          results["suggested_world_changes"].size(), " world changes, ",
          results["suggested_balance_adjustments"].size(), " balance adjustments, ",
          results["identified_bugs"].size(), " bugs.")

    return results

func _analyze_telemetry(telemetry_ Array) -> Dictionary:
    var results = {
        "suggested_events": [],
        "suggested_balance_adjustments": [],
        "identified_bugs": [],
        "high_level_insights": {}
    }

    # Filter telemetry based on analysis window
    var cutoff_time = Time.get_unix_time_from_system() - (analysis_config.get("telemetry_window_hours", 24) * 3600)
    var relevant_telemetry = []
    for event in telemetry_:
        if typeof(event) == TYPE_DICTIONARY and event.get("timestamp", 0) > cutoff_time:
            relevant_telemetry.append(event)

    # Example: Count crashes/bugs
    var crash_count = 0
    var session_count = 0
    var total_session_time = 0.0
    var frustration_npc_count: Dictionary = {} # NPC ID -> count of frustration flags

    for event in relevant_telemetry:
        match event.get("type", ""):
            "game_crash":
                crash_count += 1
            "session_start":
                session_count += 1
                # Assuming session_end has 'duration'
                # We'd need to pair start/end events to get duration
            "npc_frustration_detected":
                var npc_id = event.get("data", {}).get("npc_id", "")
                if npc_id:
                    frustration_npc_count[npc_id] = frustration_npc_count.get(npc_id, 0) + 1
            # Add other relevant event types for analysis

    # --- Suggestion Logic based on telemetry ---
    if session_count > 0 and (float(crash_count) / session_count) > (analysis_config.get("bug_frequency_threshold", 5) / 1000.0):
        results["identified_bugs"].append({
            "type": "high_crash_rate",
            "metric_value": float(crash_count) / session_count,
            "suggestion": "Investigate recent changes or server stability."
        })

    for npc_id in frustration_npc_count.keys():
        if (float(frustration_npc_count[npc_id]) / session_count) > analysis_config.get("npc_frustration_threshold", 0.3):
            results["suggested_npc_changes"].append({
                "npc_id": npc_id,
                "change_type": "behavior_review",
                "reason": "High frustration detected from telemetry.",
                "suggestion": "Review NPC dialogue, quest, or combat behavior."
            })

    return results

func _analyze_world_state(world_ Dictionary) -> Dictionary:
    var results = {
        "suggested_world_changes": [],
        "suggested_balance_adjustments": []
    }

    # Example: Analyze resource scarcity
    var resource_data = world_.get("resources", {})
    for resource_name in resource_data.keys():
        var resource_info = resource_data[resource_name]
        # Assuming resource_info has 'global_amount' or similar metric gathered from player data
        # This is a placeholder logic; actual scarcity would need player inventory data
        var estimated_player_held = _estimate_player_held_resource(resource_name)
        var global_amount = resource_info.get("global_amount", 0)
        var scarcity_ratio = float(global_amount - estimated_player_held) / global_amount if global_amount > 0 else 1.0

        if scarcity_ratio < analysis_config.get("resource_scarcity_threshold", 0.05):
            results["suggested_world_changes"].append({
                "target": "resource_spawn",
                "resource": resource_name,
                "change_type": "increase_spawn_rate",
                "reason": "Resource scarcity detected.",
                "suggestion": "Increase spawn rate or reduce consumption rate."
            })

    return results

func _analyze_npc_state(npc_ Dictionary) -> Dictionary:
    var results = {
        "suggested_npc_changes": []
    }
    # This would involve deeper analysis of NPC schedules, interaction logs (if stored in SWS),
    # or data generated by NPCBrainAgent/NPCBehaviorAgent.
    # For now, placeholder based on NPC state flags.
    for npc_id in npc_.keys():
        var npc_info = npc_[npc_id]
        # Example: Check for an 'underperforming' flag set by other agents or analysis
        if npc_info.get("status", "") == "underperforming":
            results["suggested_npc_changes"].append({
                "npc_id": npc_id,
                "change_type": "review_and_update",
                "reason": "NPC marked as underperforming.",
                "suggestion": "Update dialogue, quest, or behavior logic."
            })

    return results

func _analyze_quest_state(quest_ Dictionary) -> Dictionary:
    var results = {
        "suggested_quest_changes": []
    }
    # Example: Analyze quest completion rates (requires telemetry data linking to quests)
    # This is complex and usually requires joining quest data with player telemetry.
    # Placeholder: Assume quest data in SWS has completion stats.
    for quest_id in quest_.keys():
        var quest_info = quest_[quest_id]
        var completion_rate = quest_info.get("completion_rate", 0.0) # Placeholder metric
        if completion_rate > analysis_config.get("quest_completion_threshold", 0.95):
            results["suggested_quest_changes"].append({
                "quest_id": quest_id,
                "change_type": "increase_difficulty",
                "reason": "High completion rate detected.",
                "suggestion": "Increase enemy health, add more complex objectives, or reduce reward."
            })

    return results

func _generate_insights(analysis_ Dictionary) -> Dictionary:
    var insights = {}
    if analysis_["suggested_events"].size() > 0:
        insights["action_needed"] = true
        insights["focus_area"] = "dynamic_content"
    if analysis_["identified_bugs"].size() > 0:
        insights["action_needed"] = true
        insights["focus_area"] = "stability_and_performance"
    if analysis_["suggested_balance_adjustments"].size() > 0:
        insights["action_needed"] = true
        insights["focus_area"] = "game_balance"

    insights["summary"] = "Found %d events, %d bugs, %d balance adjustments needed." % [
        analysis_["suggested_events"].size(),
        analysis_["identified_bugs"].size(),
        analysis_["suggested_balance_adjustments"].size()
    ]

    return insights

# Helper function (placeholder)
func _estimate_player_held_resource(resource_name: String) -> int:
    # This would require aggregating player inventories from SWS or a backend DB.
    # For simulation, return a dummy value.
    return 500

# --- Example: Apply Suggested Changes (Called by Orchestrator or Admin) ---
func apply_suggested_changes(suggestions: Dictionary) -> void:
    print("WorldEvolutionAgent: Attempting to apply suggested changes...")
    # This function would take the output of analyze_world_and_player_behavior
    # and apply the changes to the game world, SWS, or send commands via CommandAgent.
    # Implementation depends heavily on the specific change type and game structure.
    # Example: Trigger an event
    for event_suggestion in suggestions.get("suggested_events", []):
        print("Applying event: ", event_suggestion)

    # Example: Modify SWS based on suggestion
    var sws_node = get_node_or_null("/root/SharedWorldState")
    if sws_node and sws_node.has_method("patch_data"):
        for balance_suggestion in suggestions.get("suggested_balance_adjustments", []):
            # Example: Adjust a global economy parameter
            if balance_suggestion.get("target") == "global_economy":
                var patch = { balance_suggestion.get("parameter", ""): balance_suggestion.get("new_value", 1.0) }
                sws_node.call_deferred("patch_data", "economy", patch)
                print("Applied economy patch: ", patch)

    # Example: Send command to modify NPC
    var command_agent_node = get_node_or_null("/root/CommandAgent")
    if command_agent_node and command_agent_node.has_method("receive_command"):
        for npc_suggestion in suggestions.get("suggested_npc_changes", []):
            var command = {
                "type": "npc.modify_behavior",
                "payload": {
                    "npc_id": npc_suggestion.get("npc_id", ""),
                    "behavior": npc_suggestion.get("suggestion_data", {})
                }
            }
            command_agent_node.call_deferred("receive_command", command)

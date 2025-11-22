# agents/MonetizationAgent.gd
extends Node
# Manages in-app purchases (IAP), ad mediation, and business analytics.
# Interacts with SharedWorldState for economy data and GameMonitor for event tracking.

# --- Configuration (can be loaded from SWS or external config) ---
var iap_products: Dictionary = {}
var ad_placement_ids: Dictionary = {
    "main_menu_interstitial": "menu_inter",
    "post_level_interstitial": "post_level_inter",
    "rewarded_video_currency": "rewarded_gold",
    "rewarded_video_double_xp": "rewarded_xp"
}
var economy_config: Dictionary = {}
# --- End Configuration ---

# Internal state
var _pending_iap_transactions: Array = []
var _tracked_analytics_events: Array = []

func _ready() -> void:
    print("MonetizationAgent ready. PID: ", get_instance_id())
    # Load initial config from SWS or external source
    _load_economy_config()
    _load_iap_products()
    _load_ad_config()

func _load_economy_config() -> void:
    var sws_node = get_node_or_null("/root/SharedWorldState")
    if sws_node and sws_node.has_method("get_data"):
        var config = sws_node.call("get_data", "economy_config", {})
        if typeof(config) == TYPE_DICTIONARY:
            economy_config = config
            print("MonetizationAgent: Loaded economy config from SWS.")
        else:
            printerr("MonetizationAgent: Failed to load economy_config from SWS, using defaults.")
            economy_config = _get_default_economy_config()

func _load_iap_products() -> void:
    # Example: Load product definitions from SWS or external source
    var sws_node = get_node_or_null("/root/SharedWorldState")
    if sws_node and sws_node.has_method("get_data"):
        var products = sws_node.call("get_data", "iap_products", {})
        if typeof(products) == TYPE_DICTIONARY:
            iap_products = products
            print("MonetizationAgent: Loaded IAP products from SWS.")
        else:
            printerr("MonetizationAgent: Failed to load IAP products from SWS, using defaults.")
            iap_products = _get_default_iap_products()

func _load_ad_config() -> void:
    # Example: Load ad placement IDs from SWS or external source
    var sws_node = get_node_or_null("/root/SharedWorldState")
    if sws_node and sws_node.has_method("get_data"):
        var config = sws_node.call("get_data", "ad_config", {})
        if typeof(config) == TYPE_DICTIONARY:
            ad_placement_ids.merge(config, true) # Merge with existing defaults, overwrite keys
            print("MonetizationAgent: Loaded/updated ad config from SWS.")
        else:
            print("MonetizationAgent: No ad_config found in SWS, using defaults.")

func _get_default_economy_config() -> Dictionary:
    return {
        "iap_currency_exchange_rate": 100, # 1 premium currency = 100 standard currency
        "iap_xp_boost_multiplier": 2.0,
        "ad_currency_reward": 10,
        "ad_xp_reward": 50,
        "premium_user_discount": 0.85, # 15% discount
    }

func _get_default_iap_products() -> Dictionary:
    return {
        "premium_currency_small": {
            "id": "premium_currency_small",
            "name": "Small Premium Currency Pack",
            "price": 0.99,
            "currency_amount": 100,
            "type": "consumable" # or "non_consumable", "subscription"
        },
        "premium_currency_medium": {
            "id": "premium_currency_medium",
            "name": "Medium Premium Currency Pack",
            "price": 4.99,
            "currency_amount": 550,
            "type": "consumable"
        },
        "xp_boost_2h": {
            "id": "xp_boost_2h",
            "name": "2-Hour XP Boost",
            "price": 2.99,
            "boost_multiplier": 2.0,
            "duration_seconds": 7200,
            "type": "consumable"
        },
        "no_ads_lifetime": {
            "id": "no_ads_lifetime",
            "name": "No Ads (Lifetime)",
            "price": 9.99,
            "removes_ads": true,
            "type": "non_consumable"
        }
    }

# --- IAP Logic ---
func initiate_iap_purchase(product_id: String) -> bool:
    var product_info = iap_products.get(product_id)
    if not product_info:
        printerr("MonetizationAgent: Unknown IAP product ID: ", product_id)
        _track_analytics_event("iap_purchase_failed", {"product_id": product_id, "reason": "unknown_product"})
        return false

    # Simulate calling external IAP SDK
    print("MonetizationAgent: Initiating IAP purchase for ", product_id, " (", product_info.get("price", "N/A"), "$)")
    _track_analytics_event("iap_purchase_started", {"product_id": product_id})

    # In a real implementation, this would call the Godot IAP module or a bridge script
    # and wait for a callback (e.g., via signal).
    # For now, simulate a successful purchase.
    var success = _simulate_iap_purchase(product_id)
    if success:
        _apply_iap_purchase(product_id)
        _track_analytics_event("iap_purchase_completed", {"product_id": product_id})
        return true
    else:
        _track_analytics_event("iap_purchase_failed", {"product_id": product_id, "reason": "sdk_error"})
        return false

func _simulate_iap_purchase(product_id: String) -> bool:
    # Simulate network delay or processing
    # OS.delay_msec(500)
    # Simulate success/failure
    import RandomNumberGenerator
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    return rng.randf() > 0.1 # 90% success rate for simulation

func _apply_iap_purchase(product_id: String) -> void:
    var product_info = iap_products[product_id]
    var sws_node = get_node_or_null("/root/SharedWorldState")
    var data_agent_node = get_node_or_null("/root/DataAgent")

    if product_info.get("type") == "consumable" or product_info.get("type") == "non_consumable":
        # Apply currency
        if product_info.has("currency_amount"):
            var current_gold = data_agent_node.get_player_value("inventory/gold", 0) if data_agent_node else 0
            var new_gold = current_gold + product_info["currency_amount"]
            if data_agent_node:
                data_agent_node.set_player_value("inventory/gold", new_gold)
            if sws_node:
                # Update SWS player data if it exists there too
                var player_id = data_agent_node.get_player_value("player_id", "default_player") if data_agent_node else "default_player"
                var player_data_key = "player_data_" + player_id
                var current_sws_data = sws_node.call("get_data", player_data_key, {})
                if typeof(current_sws_data) == TYPE_DICTIONARY:
                    current_sws_data["inventory"]["gold"] = new_gold
                    sws_node.call_deferred("set_data", player_data_key, current_sws_data)

        # Apply other effects (e.g., XP boost, remove ads)
        if product_info.has("boost_multiplier"):
            # Apply temporary boost logic here (e.g., store in DataAgent/SharedWorldState)
            var duration = product_info.get("duration_seconds", 3600) # Default 1 hour
            print("MonetizationAgent: Applied XP boost for ", duration, " seconds.")
            # Example: Store boost in SWS or DataAgent
            if data_agent_node:
                data_agent_node.set_player_value("active_xp_boost_multiplier", product_info["boost_multiplier"])
                data_agent_node.set_player_value("xp_boost_end_time", Time.get_unix_time_from_system() + duration)

        if product_info.get("removes_ads", false):
            # Store user preference in SWS or DataAgent
            if data_agent_node:
                data_agent_node.set_player_value("has_no_ads", true)
            print("MonetizationAgent: Applied No Ads perk for user.")

    elif product_info.get("type") == "subscription":
        # Handle subscription logic
        print("MonetizationAgent: Applied subscription benefits for user.")
        # Example: Set subscription status in DataAgent/SWS

# --- Ad Logic ---
func request_interstitial_ad(placement_id: String) -> void:
    var player_id = "default_player"
    var data_agent_node = get_node_or_null("/root/DataAgent")
    if data_agent_node:
        player_id = data_agent_node.get_player_value("player_id", "default_player")

    # Check if user has no-ads perk
    if data_agent_node and data_agent_node.get_player_value("has_no_ads", false):
        print("MonetizationAgent: Skipping ad request for user with no-ads perk (", player_id, ").")
        return

    print("MonetizationAgent: Requesting interstitial ad for placement ", placement_id, " (Player: ", player_id, ")")
    # Simulate calling ad SDK
    # In a real implementation, this would call the Godot AdMob module or similar.
    # The SDK would call back via a signal when the ad is loaded or fails.
    # For now, simulate a successful load after a delay.
    _simulate_ad_load(placement_id, "interstitial")

func request_rewarded_ad(placement_id: String) -> void:
    var player_id = "default_player"
    var data_agent_node = get_node_or_null("/root/DataAgent")
    if data_agent_node:
        player_id = data_agent_node.get_player_value("player_id", "default_player")

    print("MonetizationAgent: Requesting rewarded ad for placement ", placement_id, " (Player: ", player_id, ")")
    # Simulate calling ad SDK
    _simulate_ad_load(placement_id, "rewarded")

func _simulate_ad_load(placement_id: String, ad_type: String) -> void:
    # Simulate network delay
    # OS.delay_msec(1000)
    # Simulate success/failure
    import RandomNumberGenerator
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    var success = rng.randf() > 0.2 # 80% success rate for simulation

    if success:
        print("MonetizationAgent: Ad loaded successfully for placement ", placement_id, " (Type: ", ad_type, ").")
        # In real impl, this would trigger a signal for the UI to show the ad button
        # Here, we'll just simulate the user watching it after a delay.
        _simulate_ad_completion(placement_id, ad_type)
    else:
        print("MonetizationAgent: Failed to load ad for placement ", placement_id, " (Type: ", ad_type, ").")

func _simulate_ad_completion(placement_id: String, ad_type: String) -> void:
    # Simulate user watching the ad and getting rewarded
    print("MonetizationAgent: Ad completed for placement ", placement_id, " (Type: ", ad_type, ").")
    _track_analytics_event("ad_completed", {"placement_id": placement_id, "type": ad_type})

    if ad_type == "rewarded":
        # Reward player based on placement or config
        var reward_currency = economy_config.get("ad_currency_reward", 5)
        var reward_xp = economy_config.get("ad_xp_reward", 25)

        var data_agent_node = get_node_or_null("/root/DataAgent")
        var sws_node = get_node_or_null("/root/SharedWorldState")

        if data_agent_node:
            var current_gold = data_agent_node.get_player_value("inventory/gold", 0)
            var current_xp = data_agent_node.get_player_value("xp", 0)
            data_agent_node.set_player_value("inventory/gold", current_gold + reward_currency)
            data_agent_node.set_player_value("xp", current_xp + reward_xp)

        if sws_node:
            var player_id = data_agent_node.get_player_value("player_id", "default_player") if data_agent_node else "default_player"
            var player_data_key = "player_data_" + player_id
            var current_sws_data = sws_node.call("get_data", player_data_key, {})
            if typeof(current_sws_data) == TYPE_DICTIONARY:
                current_sws_data["inventory"]["gold"] += reward_currency
                current_sws_data["xp"] += reward_xp
                sws_node.call_deferred("set_data", player_data_key, current_sws_data)

        print("MonetizationAgent: Rewarded player with ", reward_currency, " currency and ", reward_xp, " XP.")

# --- Analytics Logic ---
func _track_analytics_event(event_name: String,  Dictionary = {}) -> void:
    # Use GameMonitor to track the event, or add to a local buffer for batch sending
    var game_monitor_node = get_node_or_null("/root/GameMonitor")
    if game_monitor_node and game_monitor_node.has_method("track_event"):
        game_monitor_node.call_deferred("track_event", event_name, data)
        print("MonetizationAgent: Tracked analytics event - ", event_name)
    else:
        # Fallback: add to internal buffer, send later
        var event_entry = {
            "timestamp": Time.get_ticks_msec(),
            "type": event_name,
            "data": data
        }
        _tracked_analytics_events.append(event_entry)
        printerr("MonetizationAgent: GameMonitor not found, buffered event - ", event_name)

# Example: Sync tracked events periodically (call this from a timer or orchestrator)
func sync_analytics() -> void:
    if _tracked_analytics_events.is_empty():
        return

    var game_monitor_node = get_node_or_null("/root/GameMonitor")
    if game_monitor_node and game_monitor_node.has_method("track_event"):
        for event in _tracked_analytics_events:
            game_monitor_node.call_deferred("track_event", event.type, event.data)
        print("MonetizationAgent: Synced ", _tracked_analytics_events.size(), " buffered analytics events.")
    else:
        printerr("MonetizationAgent: Cannot sync analytics, GameMonitor unavailable.")

    _tracked_analytics_events.clear()

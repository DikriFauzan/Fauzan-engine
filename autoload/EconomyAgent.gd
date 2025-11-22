@tool
extends Node

## EconomyAgent - NeoEngine v1
## Handles currency, trading, inflation, market simulation, and economic events

var sws: SharedWorldState
var currency_pool: Dictionary = {}
var market_data: Dictionary = {}
var global_inflation: float = 0.0

func _ready() -> void:
    if not Engine.is_editor_hint():
        sws = get_node("/root/SharedWorldState")
        initialize_economy()
        print("EconomyAgent loaded")

func initialize_economy() -> void:
    currency_pool["gold"] = 1000000.0
    currency_pool["silver"] = 5000000.0
    currency_pool["copper"] = 10000000.0
    refresh_market_data()

func refresh_market_data() -> void:
    market_data["wheat"] = {"base_price": 10.0, "supply": 1000, "demand": 800}
    market_data["wood"] = {"base_price": 15.0, "supply": 1200, "demand": 950}
    market_data["iron"] = {"base_price": 50.0, "supply": 300, "demand": 400}

func get_item_price(item_id: String) -> float:
    if market_data.has(item_id):
        var data = market_data[item_id]
        var price = data["base_price"]
        var supply = data["supply"]
        var demand = data["demand"]
        # Dynamic pricing based on supply/demand
        var ratio = demand / max(supply, 1.0)
        return price * ratio * (1.0 + global_inflation)
    return 0.0

func add_currency(currency_type: String, amount: float) -> void:
    if currency_pool.has(currency_type):
        currency_pool[currency_type] += amount
    else:
        currency_pool[currency_type] = amount

func subtract_currency(currency_type: String, amount: float) -> bool:
    if currency_pool.has(currency_type) and currency_pool[currency_type] >= amount:
        currency_pool[currency_type] -= amount
        return true
    return false

func _process(_delta: float) -> void:
    # Update inflation, market fluctuations, etc.
    update_economy_simulation()

func update_economy_simulation() -> void:
    # Example: Inflation increases over time
    global_inflation += 0.0001 * _delta
    refresh_market_data()

# Example: Called by NPC, player, or system
func on_trade_event(seller_id: String, buyer_id: String, item_id: String, price: float) -> void:
    print("EconomyAgent: Trade completed - ", item_id, " for ", price, " by ", buyer_id)

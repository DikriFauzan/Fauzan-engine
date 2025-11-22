extends Node

## SharedWorldState (SWS) - NeoEngine v1
## Menyimpan semua data global, state game, dan informasi yang dibagikan antar Agent.
## Bertindak sebagai database In-Memory untuk simulasi.

# --- Data Dunia ---
var world_data: Dictionary = {
	"time_day": 1, 			
	"time_cycle": "morning", 	
	"population": 1000, 		
	"economy_index": 5.0, 		
	"event_history": [], 		
	"external_server_status": "DOWN", 
	"agents_running": [],		
}

# --- Data Entitas (Contoh Placeholder) ---
var entity_data: Dictionary = {
	"player_character": {
		"health": 100,
		"location": "Central Hub",
		"inventory": {},
	},
	"items": {
		"gold_price": 100,
		"food_price": 5,
	}
}

func _ready() -> void:
	print("SharedWorldState: Database global berhasil diinisialisasi.")
	
	# FIX: Menggunakan get_root().get_children() untuk mendapatkan anak-anak dari Scene utama.
	var root_node = get_tree().get_root()
	for node in root_node.get_children():
		# Mendaftarkan Agent yang ada di Scene utama (misalnya TimeAgent)
		if node is Node and node.get_name().ends_with("Agent"):
			world_data.agents_running.append(node.get_name())
	
	# Tambahkan Autoload yang pasti berjalan
	world_data.agents_running.append("CommandAgent")
	world_data.agents_running.append("SharedWorldState")
	
	# FIX: Menggunakan str() untuk konversi Array menjadi String sebelum formatting.
	print("SharedWorldState: Agent Aktif: %s" % str(world_data.agents_running)) 

func get_data(key: String) -> Variant:
	if world_data.has(key):
		return world_data[key]
	else:
		return null

func set_data(key: String, value: Variant) -> void:
	if world_data.has(key):
		world_data[key] = value
		print("SWS Update: %s diubah menjadi %s" % [key, value])
	else:
		printerr("SWS Error: Kunci '%s' tidak ditemukan di database global." % key)

func get_entity_data(entity_key: String, data_key: String) -> Variant:
	if entity_data.has(entity_key) and entity_data[entity_key].has(data_key):
		return entity_data[entity_key][data_key]
	return null

func set_entity_data(entity_key: String, data_key: String, value: Variant) -> void:
	if entity_data.has(entity_key) and entity_data[entity_key].has(data_key):
		entity_data[entity_key][data_key] = value
		print("SWS Entity Update: %s.%s diubah menjadi %s" % [entity_key, data_key, value])
	else:
		printerr("SWS Entity Error: Kunci entitas atau data tidak ditemukan.")

func print_world_status() -> void:
	print("\n--- STATUS DUNIA NEOENGINE V1 ---")
	for key in world_data:
		print(" [GLOBAL] %s: %s" % [key, world_data[key]])
	for entity_key in entity_data:
		print(" [ENTITY] %s: %s" % [entity_key, entity_data[entity_key]])
	print("---------------------------------\n")

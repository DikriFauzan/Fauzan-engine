extends Node

## EconomyAgent - NeoEngine v1 (Hybrid Terbaik)
## Agen Universal yang mengelola simulasi pasar real-time, inflasi,
## dan struktur monetisasi ganda (Coin/Diamond) untuk SEMUA jenis game.

var sws: Node = null
var current_market_data: Dictionary = {}
var global_inflation: float = 0.0

# --- Definisi Sistem Ekonomi Default (Universal) ---
const DEFAULT_GLOBAL_ECONOMY: Dictionary = {
	"primary_currency": {
		"name": "Coin", 
		"symbol": "C"
	},
	"premium_currency": {
		"name": "Diamond", 
		"symbol": "D"
	},
	# Default set data market untuk game universal (dapat ditimpa oleh StoryPlan)
	"market_seeds": {
		# Komoditas Game (Contoh: World Building, Farmville, dsb.)
		"Wheat": {"base_price": 10.0, "supply": 1000, "demand": 800},
		"AyamPedaging": {"base_price": 30000.0, "supply": 500, "demand": 900},
		# Unit/Skor Game (Contoh: Chess, Tower Defense, dsb.)
		"Tower_Base_Cost": {"base_price": 100.0, "supply": 9999, "demand": 50},
		"Chess_Rating_Value": {"base_price": 1.0, "supply": 1000, "demand": 1000}
	},
	"inflation_rate": 0.00001 # Inflasi dasar per frame
}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	sws = get_node_or_null("/root/SharedWorldState")
	if not sws:
		push_error("EconomyAgent: SharedWorldState not found! Cannot operate.")
		return
		
	print("EconomyAgent: Siap (Mode Simulasi Dinamis). Menunggu Plan Ekonomi dari Orchestrator.")
	
# --- Panggilan Orchestrator (Memuat Plan) ---
func execute_plan(plan_data: Dictionary) -> void:
	var economy_data: Dictionary = plan_data.get("economy", {})
	
	if economy_data.is_empty():
		print("EconomyAgent: Plan kosong. Menggunakan konfigurasi Universal Default.")
		_initialize_economy(DEFAULT_GLOBAL_ECONOMY)
		return
	
	print("EconomyAgent: Menerima Plan Ekonomi. Memuat dan memproses simulasi nilai...")
	
	# Gabungkan Plan dengan Default Global
	var final_economy_data = DEFAULT_GLOBAL_ECONOMY.duplicate(true)
	final_economy_data.merge(economy_data, true) 

	_initialize_economy(final_economy_data)

# --- Inisialisasi Sistem Ekonomi ---
func _initialize_economy(data: Dictionary) -> void:
	# 1. Atur Struktur Mata Uang Global
	sws.set_data("currency_primary", data.get("primary_currency"))
	sws.set_data("currency_premium", data.get("premium_currency"))
	
	# 2. Atur Skema Monetisasi Global (dari dokumen Anda)
	sws.set_data("monetization_bundles", data.get("monetization_bundles"))
	sws.set_data("land_schema", data.get("land_investment_schema")) # Khusus FarmVille

	# 3. Set Market Data Awal dan Inflasi
	global_inflation = 0.0
	# Simpan market seed (data awal) ke SWS
	sws.set_data("market_seeds", data.get("market_seeds"))
	sws.set_data("inflation_rate", data.get("inflation_rate"))

	# Inisialisasi market data saat ini dari seed
	refresh_market_data() 
	
	print("EconomyAgent: Sistem ekonomi universal siap. Simulasi pasar dimulai.")

# --- Simulasi Waktu Nyata ---
func _process(delta: float) -> void:
	# Hanya update jika game sedang berjalan, bukan di editor.
	if Engine.is_editor_hint():
		return
		
	update_economy_simulation(delta)

func update_economy_simulation(delta: float) -> void:
	# 1. Update Global Inflation
	var inflation_rate = sws.get_data("inflation_rate", DEFAULT_GLOBAL_ECONOMY.get("inflation_rate"))
	global_inflation += inflation_rate * delta
	
	# 2. Simulasikan Fluktuasi Pasar
	# Dalam game, Supply/Demand akan dipengaruhi oleh aktivitas pemain (TradeAgent)
	# Untuk sementara, hanya me-refresh harga berdasarkan inflasi.
	refresh_market_data()
	
# --- Fungsi Perhitungan Harga Dinamis ---
func refresh_market_data() -> void:
	# Ambil seed (data base price) dari SWS
	var seeds = sws.get_data("market_seeds", DEFAULT_GLOBAL_ECONOMY.get("market_seeds"))
	
	# Reset market data saat ini
	current_market_data.clear()
	
	# Hitung harga dinamis untuk setiap item
	for item_id in seeds:
		var data = seeds[item_id]
		var base_price = data.get("base_price", 0.0)
		var supply = data.get("supply", 1.0)
		var demand = data.get("demand", 1.0)

		# Rumus Harga Dinamis (Qwen): supply/demand ratio
		var ratio = demand / max(supply, 1.0)
		
		# Harga Akhir = Base * (Ratio S/D) * (1 + Inflasi)
		var final_price = base_price * ratio * (1.0 + global_inflation)
		
		# Simpan hasil perhitungan (harga dinamis) ke market data
		current_market_data[item_id] = {
			"price": final_price,
			"supply": supply,
			"demand": demand
		}
	
	# Simpan harga dinamis yang sudah dihitung ke SWS untuk Agen lain
	sws.set_data("current_market_prices", current_market_data)


# Fungsi global untuk mendapatkan harga yang telah disimulasikan
func get_simulated_price(item_id: String) -> float:
	if current_market_data.has(item_id):
		return current_market_data[item_id]["price"]
	
	printerr("EconomyAgent: Harga simulasi untuk item '%s' tidak ditemukan." % item_id)
	return 0.0

# Fungsi Contoh: Menambah saldo (dipanggil oleh agen Player/Trade)
func add_currency(currency_type: String, amount: float) -> void:
	# Implementasi ini membutuhkan PlayerAgent/TradeAgent untuk memegang saldo
	# Namun, Agen Ekonomi Universal ini bertanggung jawab untuk logikanya.
	print("EconomyAgent: Memicu transaksi: +%.2f %s" % [amount, currency_type])
	# Placeholder: Akan memanggil fungsi di PlayerAgent/TradeAgent

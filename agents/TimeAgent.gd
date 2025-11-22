extends Timer

## TimeAgent - NeoEngine v1
## Bertanggung jawab untuk mengatur dan memperbarui waktu simulasi (hari, siklus).
## Memanggil Agent lain pada pergantian waktu.

# --- Dependensi ---
var sws: Node = null

# --- Konfigurasi ---
const CYCLE_DURATION_SECONDS := 30.0 # Berapa lama satu siklus waktu (Pagi/Siang/Sore/Malam) berlangsung

# --- Siklus Waktu ---
const TIME_CYCLES: Array[String] = ["morning", "day", "evening", "night"]

func _ready() -> void:
	# Hubungkan ke SWS (Autoload)
	sws = get_node_or_null("/root/SharedWorldState")
	
	if not sws:
		printerr("TimeAgent Error: SharedWorldState tidak ditemukan.")
		return
		
	# Konfigurasi Timer (ini adalah node Timer)
	self.wait_time = CYCLE_DURATION_SECONDS
	self.one_shot = false
	self.autostart = true
	
	# Hubungkan sinyal timeout ke fungsi update
	timeout.connect(_on_timeout)
	
	print("TimeAgent: Siap. Siklus akan berganti setiap %d detik." % CYCLE_DURATION_SECONDS)
	
	# Memperbarui status koneksi Termux di SWS 
	var command_agent = get_node_or_null("/root/CommandAgent")
	if command_agent and sws.has_method("set_data"):
		sws.set_data("external_server_status", command_agent.is_server_reachable)


func _on_timeout() -> void:
	# 1. Dapatkan status saat ini
	var current_cycle = sws.get_data("time_cycle")
	var current_day = sws.get_data("time_day")
	var current_index = TIME_CYCLES.find(current_cycle)
	
	# 2. Hitung siklus berikutnya
	var next_index = (current_index + 1) % TIME_CYCLES.size()
	var next_cycle = TIME_CYCLES[next_index]
	var next_day = current_day
	
	# 3. Periksa Pergantian Hari
	if next_index == 0: # Jika kembali ke 'morning' (indeks 0), maka hari berganti
		next_day += 1
		print("\n--- NEW DAY: DAY %d ---" % next_day)
		sws.set_data("time_day", next_day)
		
		# --- Pemicu Agent Lain saat Pergantian HARI ---
		_trigger_daily_agents()
	
	# 4. Update SWS
	sws.set_data("time_cycle", next_cycle)
	print("TimeAgent: Waktu berubah ke: Hari %d, Siklus %s" % [next_day, next_cycle])
	
	# --- Pemicu Agent Lain saat Pergantian SIKLUS (misalnya, EconomyAgent) ---
	_trigger_cycle_agents(next_cycle)

# Fungsi untuk memicu Agent yang berjalan setiap hari
func _trigger_daily_agents() -> void:
	print("TimeAgent: Memicu Agent Harian...")

# Fungsi untuk memicu Agent yang berjalan setiap siklus
func _trigger_cycle_agents(cycle: String) -> void:
	print("TimeAgent: Memicu Agent Siklus (%s)..." % cycle)

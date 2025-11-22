extends Node

## CinemaAgent - NeoEngine v1 (Hybrid Version)
## Bertanggung jawab untuk memproses data 'cinematics' dari Plan (Blueprint)
## dan mengorkestrasi cutscene, kamera, dan memicu rendering video (Sora-style).

var sws: Node = null
var active_cutscene: String = ""
var is_playing: bool = false
var current_cinematic_data: Dictionary = {}

func _ready() -> void:
    # Memastikan tidak berjalan di editor (untuk Godot 4.x)
    if Engine.is_editor_hint():
        return
        
    sws = get_node_or_null("/root/SharedWorldState")
    
    if not sws:
        push_error("CinemaAgent: SharedWorldState not found! Cannot operate.")
        return
        
    print("CinemaAgent: Siap dan terhubung ke SWS. Menunggu Plan dari Orchestrator.")

# --- Fungsi Panggilan Orchestrator (Wajib ada) ---
# Orchestrator akan memanggil ini setelah StoryAgent menghasilkan blueprint.
func execute_plan(plan_data: Dictionary) -> void:
    var cinematic_array: Array[Dictionary] = plan_data.get("cinematics", [])
    
    if cinematic_array.is_empty():
        print("CinemaAgent: Plan tidak mengandung urutan sinematik. Melanjutkan.")
        return
        
    # Untuk pengujian, kita anggap cutscene pertama adalah yang harus dimainkan
    var first_cinematic_id: String = cinematic_array[0].get("id", "")
    
    if not first_cinematic_id.is_empty():
        # Karena kita sudah memiliki data cutscene di dalam 'plan_data', 
        # kita tidak perlu memanggil _fetch_cinematic_plan dari SWS (menghemat I/O).
        # Namun, kita tetap menggunakan alur trigger.
        print("CinemaAgent: Menerima Plan. Memicu cutscene ID pertama: %s" % first_cinematic_id)
        # Simulasikan pemicu internal yang sebenarnya akan memanggil trigger_cinematic_by_id
        trigger_cinematic_by_plan_data(first_cinematic_id, cinematic_array[0])
    else:
        print("CinemaAgent: Plan sinematik ada, tetapi ID tidak ditemukan.")

# --- Logika Cutscene ---

# Fungsi yang digunakan jika data sudah di tangan (dipanggil dari execute_plan)
func trigger_cinematic_by_plan_data(cutscene_id: String, cinematic_plan: Dictionary) -> void:
    if is_playing:
        print("CinemaAgent: Cutscene '", active_cutscene, "' sudah dimainkan. Abaikan '", cutscene_id, "'.")
        return

    current_cinematic_data = cinematic_plan
    active_cutscene = cutscene_id
    is_playing = true
    _execute_cinematic()

# Fungsi asli Anda (dipertahankan untuk panggilan eksternal jika plan belum dimuat)
func trigger_cinematic_by_id(cutscene_id: String) -> void:
    if is_playing:
        print("CinemaAgent: Cutscene '", active_cutscene, "' sudah dimainkan. Abaikan '", cutscene_id, "'.")
        return

    var cinematic_plan = _fetch_cinematic_plan(cutscene_id)
    if cinematic_plan.is_empty():
        printerr("CinemaAgent: Tidak ada plan sinematik ditemukan untuk ID: ", cutscene_id)
        return

    trigger_cinematic_by_plan_data(cutscene_id, cinematic_plan)


func _fetch_cinematic_plan(cutscene_id: String) -> Dictionary:
    # Ambil dari blueprint yang disimpan di SWS
    var last_plan = sws.get_data("last_scene_plan", {})
    var all_cinematics = last_plan.get("cinematics", [])
    
    # Asumsi: Cinematics disimpan sebagai Array, cari berdasarkan ID.
    # Jika Anda ingin menyimpan sebagai Dictionary dengan ID sebagai kunci, logika ini perlu diubah.
    for cinematic in all_cinematics:
        if cinematic is Dictionary and cinematic.get("id", "") == cutscene_id:
            return cinematic
    return {}

func _execute_cinematic() -> void:
    print("CinemaAgent: [CUTSCENE START] Executing cinematic: ", active_cutscene)
    print("CinemaAgent: Detail Plan: ", current_cinematic_data)

    # Placeholder: Di sinilah logika Sora/Video akan terintegrasi di masa depan.
    # Misalnya, memicu Video Agent untuk menghasilkan video dari script yang ada di 'current_cinematic_data'
    
    # Simulasi durasi cutscene (Gunakan await di Godot 4)
    await get_tree().create_timer(2.0).timeout 
    
    _finish_cinematic()

func _finish_cinematic() -> void:
    print("CinemaAgent: [CUTSCENE END] Finished cinematic: ", active_cutscene)
    active_cutscene = ""
    is_playing = false
    current_cinematic_data.clear()

# Fungsi untuk menerima event dari sistem luar (misalnya StoryAgent)
func on_story_event(event_data: Dictionary) -> void:
    if event_data.has("cinematic_trigger"):
        print("CinemaAgent: Menerima event pemicu dari StoryAgent: ", event_data["cinematic_trigger"])
        # Asumsi: Event ini berisi ID cutscene
        trigger_cinematic_by_id(event_data["cinematic_trigger"])

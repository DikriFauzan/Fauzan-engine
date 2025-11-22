# agents/DeploymentAgent.gd
extends Node

# --- Konfigurasi ---
var godot_executable_path: String = "" # Misalnya, "godot", atau path lengkap jika tidak di PATH
var export_presets: Array[String] = ["Android Release"] # Nama preset dari project.godot
var export_directory: String = "user://exports/" # Gunakan user:// agar aman untuk Android

func _ready() -> void:
    print("DeploymentAgent: Ready. Ensure Godot executable is accessible.")
    # Coba deteksi path Godot (bisa gagal di lingkungan runtime)
    # godot_executable_path = OS.get_executable_path() # Ini path game, bukan editor
    # Solusi: Konfigurasi path Godot secara manual atau eksternal

func build_and_export() -> void:
    # Pastikan direktori export ada
    DirAccess.make_dir_recursive_absolute(export_directory)

    for preset_name in export_presets:
        print("DeploymentAgent: Attempting to export preset '", preset_name, "'...")
        var export_path = export_directory + _generate_filename(preset_name)
        var command = _construct_export_command(preset_name, export_path)

        if command.is_empty():
            printerr("DeploymentAgent: Failed to construct export command for preset '", preset_name, "'. Check preset name and Godot path.")
            continue

        # Eksekusi perintah
        var exit_code = OS.execute("sh", ["-c", command]) # Gunakan shell untuk perintah kompleks
        if exit_code == 0:
            print("DeploymentAgent: Successfully exported to ", export_path)
        else:
            printerr("DeploymentAgent: Failed to export preset '", preset_name, "'. Exit code: ", exit_code)

func _construct_export_command(preset_name: String, output_path: String) -> String:
    # Format: godot --export-release "Preset Name" "output/path.apk"
    # Ganti "godot" dengan path lengkap jika diperlukan
    if godot_executable_path.is_empty():
        printerr("DeploymentAgent: Godot executable path is not set. Cannot construct command.")
        return ""

    # Escape path untuk shell
    var escaped_preset = preset_name.replace("\"", "\\\"")
    var escaped_output = output_path.replace("\"", "\\\"")

    return "\"" + godot_executable_path + "\" --export-release \"" + escaped_preset + "\" \"" + escaped_output + "\""

func _generate_filename(preset_name: String) -> String:
    # Format: game_nama_preset_timestamp.apk
    var timestamp = Time.get_datetime_string_from_system().replace(" ", "_").replace(":", "-")
    var clean_preset = preset_name.replace(" ", "_").replace("/", "_")
    return "neoengine_game_" + clean_preset + "_" + timestamp + ".apk"

# --- Fungsi untuk mengatur preset dan path Godot (bisa dipanggil dari Orchestrator atau UI eksternal) ---
func set_godot_executable_path(path: String) -> void:
    godot_executable_path = path

func add_export_preset(preset_name: String) -> void:
    if not export_presets.has(preset_name):
        export_presets.append(preset_name)

func remove_export_preset(preset_name: String) -> void:
    export_presets.erase(preset_name)

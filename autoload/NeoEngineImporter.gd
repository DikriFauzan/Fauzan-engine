@tool
extends EditorPlugin

## NeoEngineImporter - Editor Plugin for NeoEngine v1
## Handles automatic import of documents, blueprints, and procedural content
## Integrates with SharedWorldState and NeoEngineOrchestrator

const CONVERTER_PATHS = {
    "world": "res://addons/NeoEngineImporter/converters/world_converter.gd",
    "cinematic": "res://addons/NeoEngineImporter/converters/cinematic_converter.gd",
    "physics": "res://addons/NeoEngineImporter/converters/physics_converter.gd",
    "npc": "res://addons/NeoEngineImporter/converters/npc_converter.gd",
    "economy": "res://addons/NeoEngineImporter/converters/economy_converter.gd",
    "engine": "res://addons/NeoEngineImporter/converters/engine_converter.gd"
}

var _menu_item_name := "Run NeoEngine Importer"
var _importers_active := false

func _enter_tree():
    # Tambahkan menu ke tool
    add_tool_menu_item(_menu_item_name, Callable(self, "_run_import"))
    print("NeoEngineImporter: Plugin loaded. Menu item added.")

func _exit_tree():
    # Hapus menu saat plugin dilepas
    remove_tool_menu_item(_menu_item_name)
    print("NeoEngineImporter: Plugin unloaded. Menu item removed.")

func _run_import():
    if _importers_active:
        print("NeoEngineImporter: Import already in progress. Skipping.")
        return

    print("NeoEngineImporter: Starting import process...")
    _importers_active = true

    # Ambil blueprint dari SharedWorldState
    var orchestrator = get_node_or_null("/root/NeoEngineOrchestrator")
    if not orchestrator:
        push_error("NeoEngineImporter: NeoEngineOrchestrator not found in root. Cannot import.")
        _importers_active = false
        return

    var plan = orchestrator.get_current_plan() # Fungsi ini harus ada di Orchestrator
    if typeof(plan) != TYPE_DICTIONARY:
        push_error("NeoEngineImporter: No valid scene_plan found in orchestrator.")
        _importers_active = false
        return

    # Jalankan pipeline konversi
    var success = _execute_conversion_pipeline(plan)
    if success:
        print("NeoEngineImporter: Import process completed successfully.")
    else:
        printerr("NeoEngineImporter: Import process failed.")

    _importers_active = false

func _execute_conversion_pipeline(plan: Dictionary) -> bool:
    var all_success := true

    for converter_type in CONVERTER_PATHS:
        var converter_path = CONVERTER_PATHS[converter_type]
        if ResourceLoader.exists(converter_path):
            var ConverterScript = load(converter_path)
            if ConverterScript:
                var converter_instance = ConverterScript.new()
                if converter_instance and converter_instance.has_method("convert"):
                    print("NeoEngineImporter: Converting ", converter_type, "...")
                    var result = converter_instance.convert(plan, converter_type)
                    if result != OK:
                        printerr("NeoEngineImporter: Conversion failed for ", converter_type, " with error: ", result)
                        all_success = false
                else:
                    printerr("NeoEngineImporter: Script at ", converter_path, " is not a valid converter.")
                    all_success = false
            else:
                printerr("NeoEngineImporter: Failed to load converter script: ", converter_path)
                all_success = false
        else:
            printerr("NeoEngineImporter: Converter script not found: ", converter_path)
            all_success = false

    return all_success

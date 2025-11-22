# addons/NeoEngineImporter/converters/EngineConverter.gd
extends RefCounted
class_name EngineConverter

func convert(plan: Dictionary) -> Resource:
	var evo := plan.get("engine_evolution", {})
	if typeof(evo) != TYPE_DICTIONARY or evo.empty():
		return null

	var out_path := "res://generated/engine_evolution.json"
	DirAccess.make_dir_recursive_absolute("res://generated/")
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if not f:
		printerr("EngineConverter: cannot open ", out_path)
		return null
	f.store_string(JSON.stringify(evo, "\t"))
	f.close()
	var r := Resource.new()
	r.set_meta("engine_evolution_saved", true)
	return r

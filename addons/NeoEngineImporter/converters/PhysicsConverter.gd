# addons/NeoEngineImporter/converters/PhysicsConverter.gd
extends RefCounted
class_name PhysicsConverter

func convert(plan: Dictionary) -> Resource:
	var data := plan.get("physics", {})
	if typeof(data) != TYPE_DICTIONARY or data.empty():
		return null

	var out_path := "res://generated/physics_settings.json"
	DirAccess.make_dir_recursive_absolute("res://generated/")
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if not f:
		printerr("PhysicsConverter: cannot open ", out_path)
		return null
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var r := Resource.new()
	r.set_meta("physics_saved", true)
	return r

# addons/NeoEngineImporter/converters/EconomyConverter.gd
extends RefCounted
class_name EconomyConverter

func convert(plan: Dictionary) -> Resource:
	var eco := plan.get("economy", {})
	if typeof(eco) != TYPE_DICTIONARY or eco.empty():
		return null

	var out_path := "res://generated/economy.json"
	DirAccess.make_dir_recursive_absolute("res://generated/")
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if not f:
		printerr("EconomyConverter: cannot open ", out_path)
		return null
	f.store_string(JSON.stringify(eco, "\t"))
	f.close()
	var r := Resource.new()
	r.set_meta("economy_saved", true)
	return r

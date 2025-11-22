# addons/NeoEngineImporter/converters/NPCConverter.gd
extends RefCounted
class_name NPCConverter

func convert(plan: Dictionary) -> Node:
	var list := plan.get("characters", [])
	if typeof(list) != TYPE_ARRAY:
		return null

	var container := Node3D.new()
	container.name = "NPCs"

	for i in range(list.size()):
		var n = list[i]
		if typeof(n) != TYPE_DICTIONARY:
			continue
		var npc_node := Node3D.new()
		npc_node.name = n.get("name", "NPC_%d" % i)
		# attach metadata for BehaviorConverter or later processing
		npc_node.set_meta("npc_data", n.duplicate(true))
		container.add_child(npc_node)

	return container

@tool
extends Node

## WorldConverter - NeoEngine v1
## Converts world blueprint into Godot scenes and resources

func convert(plan: Dictionary, section: String) -> int:
    if section != "world":
        return OK # Tidak menangani bagian lain

    var world_data = plan.get("world", {})
    if world_data.is_empty():
        print("WorldConverter: No world data to convert.")
        return OK

    var root_node_name = world_data.get("name", "GeneratedWorld")
    var regions_list = world_data.get("regions", [])

    var root_node = Node3D.new()
    root_node.name = root_node_name

    for region_data in regions_list:
        var region_node = Node3D.new()
        region_node.name = region_data.get("name", "Region")
        # Tambahkan logika untuk mengisi region_node berdasarkan region_data
        root_node.add_child(region_node)

    # Simpan scene
    var output_dir = "res://generated/scenes/"
    DirAccess.make_dir_recursive_absolute(output_dir)
    var scene_path = output_dir + root_node_name + ".tscn"

    var packed_scene = PackedScene.new()
    var pack_result = packed_scene.pack(root_node)
    if pack_result == OK:
        var save_result = ResourceSaver.save(packed_scene, scene_path)
        if save_result == OK:
            print("WorldConverter: Saved world scene to ", scene_path)
        else:
            printerr("WorldConverter: Failed to save scene to ", scene_path)
            return save_result
    else:
        printerr("WorldConverter: Failed to pack scene.")
        return pack_result

    return OK

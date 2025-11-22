@tool
extends Node

## CinematicConverter - NeoEngine v1
## Converts cinematic blueprint into Godot scenes and resources

func convert(plan: Dictionary, section: String) -> int:
    if section != "cinematic":
        return OK # Tidak menangani bagian lain

    var cinematic_list = plan.get("cinematics", [])
    if cinematic_list.is_empty():
        print("CinematicConverter: No cinematic data to convert.")
        return OK

    var output_dir = "res://generated/cinematics/"
    DirAccess.make_dir_recursive_absolute(output_dir)

    for cinematic_data in cinematic_list:
        var id = cinematic_data.get("id", "cinematic_" + str(Time.get_unix_time_from_system()))
        var file_path = output_dir + id + ".json"

        var file = FileAccess.open(file_path, FileAccess.WRITE)
        if file:
            file.store_string(JSON.stringify(cinematic_data, "\t"))
            file.close()
            print("CinematicConverter: Saved cinematic blueprint to ", file_path)
        else:
            printerr("CinematicConverter: Failed to write cinematic data to ", file_path)
            return ERR_FILE_CANT_WRITE

    return OK

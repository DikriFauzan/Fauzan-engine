extends Node

## PhysicsAgent - NeoEngine v1
## Handles physics rules, collision management, gravity, and custom physics behaviors

var sws # <-- Hapus deklarasi tipe SharedWorldState
var world_gravity: float = 9.8
var custom_physics_enabled: bool = true

func _ready() -> void:
    if not Engine.is_editor_hint():
        sws = get_node_or_null("/root/SharedWorldState")
        if not sws:
            printerr("PhysicsAgent: SharedWorldState not found! Some features may not work.")
            return
        configure_physics()
        print("PhysicsAgent loaded")

func configure_physics() -> void:
    PhysicsServer3D.set_active(true)
    PhysicsServer2D.set_active(true)
    # Set custom gravity, collision layers, etc.
    set_world_gravity(world_gravity)

func set_world_gravity(gravity: float) -> void:
    world_gravity = gravity
    # Perbaikan: Gunakan get_viewport().world_3d.space
    var current_viewport = get_viewport()
    if current_viewport and current_viewport.world_3d:
        PhysicsServer3D.area_set_param(current_viewport.world_3d.space, PhysicsServer3D.AREA_PARAM_GRAVITY, gravity)
    else:
        printerr("PhysicsAgent: Could not get world_3d to set gravity.")

func apply_custom_physics_to_body(body: Node3D, custom_params: Dictionary) -> void:
    if custom_params.has("gravity_override"):
        body.gravity_scale = custom_params["gravity_override"]

func _physics_process(_delta: float) -> void: # <-- Perbaikan: Ganti 'delta' menjadi '_delta'
    if custom_physics_enabled:
        # Custom physics simulation
        # Contoh: update forces, constraints, etc. (gunakan _delta jika diperlukan nanti)
        pass

# Example: Trigger from environment changes
func on_environment_change(event_data: Dictionary) -> void: # <-- Perbaikan: Ganti nama parameter
    if event_data.has("gravity_change"): # <-- Perbaikan: Gunakan 'event_data' bukan 'data'
        set_world_gravity(event_data["gravity_change"]) # <-- Perbaikan: Gunakan 'event_data' bukan 'data'

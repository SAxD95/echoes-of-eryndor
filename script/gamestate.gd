extends Node

## Global singleton managing sector states, power telemetry, and emergency sequences
## for "Echoes of Eryndor".

enum Room {
	BRIDGE,          # Far-left command deck with dual pilot consoles
	OPERATIONS,      # Left vertical module with dual blue holo-tables & auxiliary generator
	CROSS_HUB,       # Central-left 4-way junction connecting western modules
	CREW_QUARTERS,   # Top-left bunk, desk terminal, and personal lockers
	MED_BAY,         # Bottom-right medical & diagnostic containment bay
	AIR_TERMINAL,    # Central-right main concourse with red cargo airlock
	CARGO_BAY,       # Top-right storage bay with forklifts and shipping containers
	ARMORY,          # Bottom-left security locker, weapon racks, and lavatory
	REACTOR          # Far-right engineering chamber housing the octagonal reactor core
}

signal room_changed(previous_room: Room, new_room: Room)
signal sector_emergency_triggered(is_active: bool)
signal power_grid_updated(current_load: float, is_critical: bool)
signal reactor_stabilization_sequence_started()
signal inventory_updated(item_id: String)

const MAX_SAFE_POWER_LOAD: float = 85.0
const CRITICAL_POWER_LOAD: float = 100.0

var reactor_meltdown_imminent: bool = false
var power_grid_load: float = 42.5
var current_room: Room = Room.BRIDGE
var player_inventory: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Safely transitions the active room state and notifies listeners.
func change_room(new_room: Room) -> void:
	if current_room == new_room:
		return
	
	var previous_room: Room = current_room
	current_room = new_room
	room_changed.emit(previous_room, current_room)
	print("[GameState] Player transitioned from %s to %s" % [
		Room.keys()[previous_room],
		Room.keys()[current_room]
	])


## Modifies the ship's power grid load and automatically triggers a meltdown state if critical.
func modify_power_grid_load(delta_load: float) -> void:
	power_grid_load = clampf(power_grid_load + delta_load, 0.0, CRITICAL_POWER_LOAD)
	var is_critical: bool = power_grid_load >= MAX_SAFE_POWER_LOAD
	power_grid_updated.emit(power_grid_load, is_critical)
	
	if power_grid_load >= CRITICAL_POWER_LOAD and not reactor_meltdown_imminent:
		trigger_sector_emergency(true)


## Triggers or resolves sector-wide red alert states across all connected chambers.
func trigger_sector_emergency(enable: bool) -> void:
	if reactor_meltdown_imminent == enable:
		return
	
	reactor_meltdown_imminent = enable
	sector_emergency_triggered.emit(reactor_meltdown_imminent)
	
	if reactor_meltdown_imminent:
		push_warning("[GameState] ALERT: Reactor meltdown imminent! Sector-wide emergency active.")
	else:
		print("[GameState] Sector emergency resolved. Returning to nominal operations.")


## Called by the Reactor Core Panel to initiate the endgame stabilization timeline.
func initiate_reactor_stabilization() -> void:
	power_grid_load = 30.0
	trigger_sector_emergency(false)
	reactor_stabilization_sequence_started.emit()
	power_grid_updated.emit(power_grid_load, false)


## Utility for adding tools/keycards obtained from Cargo Bay crates.
func add_inventory_item(item_id: String) -> void:
	if not player_inventory.has(item_id):
		player_inventory.append(item_id)
		inventory_updated.emit(item_id)

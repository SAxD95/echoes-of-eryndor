extends Node

## Global singleton managing sector states, power telemetry, NASA BVAD survival math,
## and emergency sequences for "Echoes of Eryndor".

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
signal status_message_updated(message: String)
signal mission_ended(success: bool, reason: String)

const MAX_SAFE_POWER_LOAD: float = 85.0
const CRITICAL_POWER_LOAD: float = 100.0

# NASA BVAD & LEO Parameters
const BASE_O2_BURN: float = 0.58       # g/min (NASA BVAD 0.84 kg/day)
const SPRINT_MULTIPLIER: float = 1.6   # 1.6x metabolic exertion

var reactor_meltdown_imminent: bool = false
var power_grid_load: float = 40.0      # Starts with ECLSS (40 MW) active
var current_room: Room = Room.BRIDGE
var player_inventory: Array[String] = []

# Survival & Orbital Telemetry
var o2_remaining: float = 100.0        # Percentage
var pp_co2: float = 2.4                # mmHg (NASA safe limit < 3.0)
var orbital_velocity: float = 7.66     # km/s (Decaying LEO)
var time_left: float = 180.0           # 3-minute countdown

# 100 MW Power Grid Trade-off Flags
var eclss_active: bool = true          # 40 MW
var comms_active: bool = false         # 30 MW
var propulsion_active: bool = false    # 30 MW

# Mission Progression Flags
var audio_played: bool = false
var valve_vented: bool = false
var reactor_ignited: bool = false
var is_sprinting: bool = false
var game_over: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if game_over or not audio_played:
		return

	# 1. Orbital Decay Countdown
	time_left -= delta
	orbital_velocity = clampf(7.20 + (time_left / 180.0) * 0.46, 7.20, 7.66)
	if time_left <= 0.0:
		end_mission(false, "ORBITAL DECAY: Atmospheric Re-entry")
		return

	# 2. NASA Metabolic O2 & CO2 Math
	var burn_rate: float = 0.35 if eclss_active else 0.95
	if is_sprinting:
		burn_rate *= SPRINT_MULTIPLIER

	o2_remaining = maxf(0.0, o2_remaining - burn_rate * delta)
	pp_co2 = move_toward(pp_co2, 2.4 if eclss_active else 4.8, delta * 0.15)

	if o2_remaining <= 0.0:
		end_mission(false, "LOSS OF CREW: Oxygen Depleted")


## Toggles 100 MW power trade-off between ECLSS (40 MW) and Comms + Propulsion (60 MW)
func toggle_power_reroute() -> void:
	eclss_active = !eclss_active
	comms_active = !eclss_active
	propulsion_active = !eclss_active
	
	# Syncs with your existing power_grid_load telemetry
	power_grid_load = 40.0 if eclss_active else 60.0
	power_grid_updated.emit(power_grid_load, not eclss_active)
	
	if not eclss_active:
		status_message_updated.emit("GRID REROUTED (60 MW): Comms & Propulsion ONLINE. ECLSS OFF (CO2 Rising!).")
	else:
		status_message_updated.emit("GRID RESTORED (40 MW): ECLSS Nominal. Comms & Propulsion OFFLINE.")


func end_mission(success: bool, reason: String) -> void:
	if game_over:
		return
	game_over = true
	if success:
		initiate_reactor_stabilization()
	mission_ended.emit(success, reason)


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
	orbital_velocity = 7.80
	trigger_sector_emergency(false)
	reactor_stabilization_sequence_started.emit()
	power_grid_updated.emit(power_grid_load, false)


## Utility for adding tools/keycards obtained from Cargo Bay crates.
func add_inventory_item(item_id: String) -> void:
	if not player_inventory.has(item_id):
		player_inventory.append(item_id)
		inventory_updated.emit(item_id)

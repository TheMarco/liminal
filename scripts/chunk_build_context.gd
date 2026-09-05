class_name ChunkBuildContext
extends RefCounted
## Immutable facts for one Chunk construction.
##
## ChunkBuildSpec is the mutable assembly object used by ChunkManager. Chunk
## immediately snapshots it into this context before a theme builder runs, so
## builders cannot accidentally change streaming/game state while constructing
## geometry. Live services (currently only Player for the waiting anomaly) stay
## outside this value object.

var _world_seed: int
var _cell: Vector2i
var _theme: int
var _style: int
var _ceiling_height: float
var _room_root: Vector2i
var _room_size: int
var _room_anchor: bool
var _furniture_variant: int
var _portal_destination: int

var _descent: bool
var _target: bool
var _target_wall: int
var _final: bool
var _floor_idx: int
var _anomaly: int
var _topology: DescentTopology
var _topology_state_override: int
var _blackout: bool
var _arrival: bool
var _arrival_wall: int
var _arrival_used: bool
var _lift_called: bool
var _lift_wait: float
var _lift_open: bool
var _tape_watched: bool
var _base_seed: int
var _bleed: float
var _bleed_theme: int
var _optional_vhs: bool
var _optional_vhs_key: String
var _broken_station: bool
var _broken_station_tried: bool

var world_seed: int:
	get:
		return _world_seed
var cell: Vector2i:
	get:
		return _cell
var theme: int:
	get:
		return _theme
var style: int:
	get:
		return _style
var ceiling_height: float:
	get:
		return _ceiling_height
var room_root: Vector2i:
	get:
		return _room_root
var room_size: int:
	get:
		return _room_size
var is_room_anchor: bool:
	get:
		return _room_anchor
var furniture_variant: int:
	get:
		return _furniture_variant
var portal_destination: int:
	get:
		return _portal_destination

var descent: bool:
	get:
		return _descent
var target: bool:
	get:
		return _target
var target_wall: int:
	get:
		return _target_wall
var final: bool:
	get:
		return _final
var floor_idx: int:
	get:
		return _floor_idx
var anomaly: int:
	get:
		return _anomaly
var topology: DescentTopology:
	get:
		return _topology
var topology_state_override: int:
	get:
		return _topology_state_override
var blackout: bool:
	get:
		return _blackout
var arrival: bool:
	get:
		return _arrival
var arrival_wall: int:
	get:
		return _arrival_wall
var arrival_used: bool:
	get:
		return _arrival_used
var lift_called: bool:
	get:
		return _lift_called
var lift_wait: float:
	get:
		return _lift_wait
var lift_open: bool:
	get:
		return _lift_open
var tape_watched: bool:
	get:
		return _tape_watched
var base_seed: int:
	get:
		return _base_seed
var bleed: float:
	get:
		return _bleed
var bleed_theme: int:
	get:
		return _bleed_theme
var optional_vhs: bool:
	get:
		return _optional_vhs
var optional_vhs_key: String:
	get:
		return _optional_vhs_key
var broken_station: bool:
	get:
		return _broken_station
var broken_station_tried: bool:
	get:
		return _broken_station_tried


func _init(p_world_seed: int, p_cell: Vector2i, p_theme: int,
		p_style: int, p_ceiling_height: float, p_room_root: Vector2i,
		p_room_size: int, p_room_anchor: bool, p_furniture_variant: int,
		spec: ChunkBuildSpec) -> void:
	_world_seed = p_world_seed
	_cell = p_cell
	_theme = p_theme
	_style = p_style
	_ceiling_height = p_ceiling_height
	_room_root = p_room_root
	_room_size = p_room_size
	_room_anchor = p_room_anchor
	_furniture_variant = p_furniture_variant
	_portal_destination = -1

	_descent = spec.descent
	_target = spec.target
	_target_wall = spec.target_wall
	_final = spec.final
	_floor_idx = spec.floor_idx
	_anomaly = spec.anomaly
	_topology = spec.topology
	_topology_state_override = spec.topology_state_override
	_blackout = spec.blackout
	_arrival = spec.arrival
	_arrival_wall = spec.arrival_wall
	_arrival_used = spec.arrival_used
	_lift_called = spec.lift_called
	_lift_wait = spec.lift_wait
	_lift_open = spec.lift_open
	_tape_watched = spec.tape_watched
	_base_seed = spec.base_seed
	_bleed = spec.bleed
	_bleed_theme = spec.bleed_theme
	_optional_vhs = spec.optional_vhs
	_optional_vhs_key = spec.optional_vhs_key
	_broken_station = spec.broken_station
	_broken_station_tried = spec.broken_station_tried


## Pure call-order-independent random value for this cell.
func random01(salt: int) -> float:
	return WorldGen.r01(_world_seed, _cell.x, _cell.y, salt)

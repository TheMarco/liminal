class_name ChunkBuildSpec
extends RefCounted
## Typed boundary between streaming/game state and Chunk construction. New
## production fields must be declared here. Focused tools may still pass a
## Dictionary, which Chunk converts through `from_dictionary()` immediately.

var casino_landmark := ""
var descent := false
var target := false
var target_wall := -1
var final := false
var floor_idx := 0
var anomaly := -1
var topology: DescentTopology
var topology_state_override := -1
var furniture_variant_override := -1
var blackout := false
var arrival := false
var arrival_wall := -1
var arrival_used := false
var lift_called := false
var lift_wait := 0.0
var lift_open := false
var tape_watched := false
var base_seed := 1
var bleed := 0.0
var bleed_theme := -1
var optional_vhs := false
var optional_vhs_key := ""
var broken_station := false
var broken_station_tried := false
var player: Player


static func from_dictionary(config: Dictionary) -> ChunkBuildSpec:
	var out := ChunkBuildSpec.new()
	out.casino_landmark = str(config.get("casino_landmark", ""))
	out.descent = bool(config.get("descent", false))
	out.target = bool(config.get("target", false))
	out.target_wall = int(config.get("target_wall", -1))
	out.final = bool(config.get("final", false))
	out.floor_idx = int(config.get("floor_idx", 0))
	out.anomaly = int(config.get("anomaly", -1))
	out.topology = config.get("topology", null) as DescentTopology
	out.topology_state_override = int(
		config.get("topology_state_override", -1))
	out.furniture_variant_override = int(
		config.get("furniture_variant_override", -1))
	out.blackout = bool(config.get("blackout", false))
	out.arrival = bool(config.get("arrival", false))
	out.arrival_wall = int(config.get("arrival_wall", -1))
	out.arrival_used = bool(config.get("arrival_used", false))
	out.lift_called = bool(config.get("lift_called", false))
	out.lift_wait = float(config.get("lift_wait", 0.0))
	out.lift_open = bool(config.get("lift_open", false))
	out.tape_watched = bool(config.get("tape_watched", false))
	out.base_seed = int(config.get("base_seed", 1))
	out.bleed = float(config.get("bleed", 0.0))
	out.bleed_theme = int(config.get("bleed_theme", -1))
	out.optional_vhs = bool(config.get("optional_vhs", false))
	out.optional_vhs_key = str(config.get("optional_vhs_key", ""))
	out.broken_station = bool(config.get("broken_station", false))
	out.broken_station_tried = bool(
		config.get("broken_station_tried", false))
	out.player = config.get("player", null) as Player
	return out

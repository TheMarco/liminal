class_name LevelTransitionPort
extends RefCounted
## Narrow lifecycle callbacks required by LevelTransitionController.
## This keeps the controller independent of Main's unrelated gameplay state.

var active_level: Callable
var set_active_level: Callable
var descent_mode: Callable
var player: Callable
var world_3d: Callable
var level_seed: Callable
var level_root: Callable
var detach_level: Callable
var reset_floor_presence: Callable
var switch_music: Callable
var prepare_destination: Callable
var build_level: Callable
var post_build: Callable
var sealed_descent_arrival: Callable


func is_valid() -> bool:
	return active_level.is_valid() and set_active_level.is_valid() \
		and descent_mode.is_valid() and player.is_valid() \
		and world_3d.is_valid() and level_seed.is_valid() \
		and level_root.is_valid() and detach_level.is_valid() \
		and reset_floor_presence.is_valid() and switch_music.is_valid() \
		and prepare_destination.is_valid() and build_level.is_valid() \
		and post_build.is_valid() and sealed_descent_arrival.is_valid()

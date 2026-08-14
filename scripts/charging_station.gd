class_name ChargingStation
extends Node3D
## A deterministic safe harbour that is not actually safe: connecting turns
## the flashlight off, keeps the player close, and takes ten exposed seconds
## from empty. Power enters the cell continuously; disconnecting, fleeing, or
## raising the flashlight keeps every bit accumulated so far.
##
## One station per run is `broken`: dead in a way a player who has used the
## honest ones can notice (no emissive glow, the idle hum a shade flat), and
## honest in every other respect until pressed. The press appears to take,
## then the unit collapses, the prompt turns OUT OF ORDER for the rest of the
## run, and something arrives behind the player. It never drains the cell —
## the cost is the charge that did not happen, spent finding another unit
## with an encounter on your heels.

const MODEL := preload(
	"res://models/cc_by/hovercar_charging_station/hovercar_charging_station.glb")
const MODEL_ALBEDO := preload(
	"res://models/cc_by/hovercar_charging_station/charging_station_base_color.png")
const MODEL_EMISSION := preload(
	"res://models/cc_by/hovercar_charging_station/charging_station_emissive.png")
const MODEL_SCALE := 2.5

## Assigned by the chunk before this enters the tree; config-driven so a
## streamed-out trap rebuilds in the same state.
var broken := false
var broken_tried := false

var _hit: Interactable
var _actor: Player
var _hum: AudioStreamPlayer3D
## True during the ~1.2s in which a broken unit pretends the connection took.
var _breaking := false


func _ready() -> void:
	set_meta("charging_station", true)
	var model := MODEL.instantiate() as Node3D
	_apply_authored_textures(model)
	model.scale = Vector3.ONE * MODEL_SCALE
	# Source bounds are centred around the origin. Rebase its 1.64m cabinet to
	# the floor and centre the shallow body around this placement pivot.
	model.position = Vector3(0.0, 0.8186, -0.1951)
	add_child(model)

	var body := StaticBody3D.new()
	var solid := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.62, 1.64, 0.48)
	solid.shape = shape
	solid.position = Vector3(0, 0.82, 0)
	body.add_child(solid)
	add_child(body)

	_hit = Interactable.new()
	_hit.prompt_text = "E — CHARGE FLASHLIGHT"
	_hit.position = Vector3(0, 0.92, -0.02)
	_hit.add_box(Vector3(0.95, 1.85, 0.90))
	_hit.activated.connect(_toggle_charge)
	add_child(_hit)

	_hum = AudioStreamPlayer3D.new()
	_hum.stream = SoundBank.buzz()
	_hum.bus = SoundBank.HALL_BUS
	_hum.position = Vector3(0, 1.0, 0)
	_hum.unit_size = 2.0
	_hum.max_distance = 12.0
	_hum.volume_db = -28.0
	_hum.pitch_scale = 0.72
	_hum.autoplay = true
	add_child(_hum)
	if broken:
		# The tell, for a player who has stood at enough honest units to know
		# their sound: a shade flat, and the panel light dead (the emission
		# skip happens in _apply_authored_textures).
		_hum.pitch_scale = 0.68
		if broken_tried:
			_present_out_of_order()


func _apply_authored_textures(root: Node) -> void:
	var mesh_instance := root as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface_index)
			var material := source.duplicate() as BaseMaterial3D if source != null else null
			if material == null:
				continue
			material.albedo_texture = MODEL_ALBEDO
			# A dead unit's panel does not glow. This is the strongest of its
			# quiet tells, and the only visual one.
			if not broken:
				material.emission_enabled = true
				material.emission_texture = MODEL_EMISSION
			mesh_instance.set_surface_override_material(surface_index, material)
	for child in root.get_children():
		_apply_authored_textures(child)


func _toggle_charge(actor: Node) -> void:
	var player := actor as Player
	if player == null:
		return
	if broken:
		if not broken_tried and not _breaking:
			_break_sequence(player)
		return
	_actor = player
	if player.is_charging_at(self):
		player.stop_charging()
	else:
		player.start_charging(self)


## The press appears to take: click, torch off, hum up — exactly the honest
## connection for about a second. Then the unit dies. Deliberately never
## `start_charging`: the trap must not touch the charge session machinery,
## because the cost of this station is the charge that did not happen, not a
## drained cell.
func _break_sequence(player: Player) -> void:
	_breaking = true
	player.set_flashlight(false)
	_hit.prompt_text = ""
	_hum.volume_db = -14.0
	_hum.pitch_scale = 1.08
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(_collapse)


func _collapse() -> void:
	_breaking = false
	broken_tried = true
	# The connection tone slides flat and dies instead of cutting: a machine
	# failing, not a sound effect stopping.
	var tw := create_tween()
	tw.tween_property(_hum, "pitch_scale", 0.5, 0.9)
	tw.parallel().tween_property(_hum, "volume_db", -60.0, 0.9)
	_present_out_of_order()
	# Main captions the death and sends what the dark owes for it; the run
	# records the spring so a rebuilt chunk stays sprung.
	if is_inside_tree():
		get_tree().call_group("descent_listener", "descent_station_died")


func _present_out_of_order() -> void:
	# Enabled stays true so aiming at it still reads the label; pressing E is
	# swallowed by the broken branch above.
	_hit.prompt_text = "OUT OF ORDER"


func _process(_dt: float) -> void:
	if broken:
		# The pre-press presentation is the honest prompt (the lie), the
		# breaking window is silent, and afterwards the label is the record.
		if broken_tried:
			_hit.prompt_text = "OUT OF ORDER"
		elif _breaking:
			_hit.prompt_text = ""
		return
	var connected := is_instance_valid(_actor) and _actor.is_charging_at(self)
	var full := is_instance_valid(_actor) \
		and _actor.flashlight_charge() >= 0.999
	_hit.prompt_text = "E — STOP CHARGING" if connected else (
		"FLASHLIGHT FULL" if full else "E — CHARGE FLASHLIGHT")
	_hum.volume_db = -14.0 if connected else -28.0
	_hum.pitch_scale = 1.08 if connected else 0.72

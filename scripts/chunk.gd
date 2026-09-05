class_name Chunk
extends Node3D
## One 12x12m cell, fully generated in _init from (seed, cell, theme).
## Theme 0: seedy Vegas hotel-casino. Theme 1: sterile Severance-style office.
## Theme 2: the warm yellow Annex. Theme 4: an airport terminal parked forever
## at 3 a.m. (3 was a derelict theme park, cut — ids are not renumbered).
## Theme 5: an abandoned asylum — the first theme dressed in downloaded CC0
## photo textures and models (ambientCG / Poly Haven) instead of pure math.
## Theme 6: a sealed school. Theme 7: an abandoned shopping mall.
## Theme 8: a decaying island prison.
## Theme 9: the flooded Poolrooms. Theme 10: the concrete Data Center.
## Theme 11: the organic civic nightmare of the Bloom.
## All geometry is local; the ChunkManager places the node at the cell origin.

const CHARGING_STATION_SCRIPT := preload("res://scripts/charging_station.gd")
const VHS_RITUAL_SCRIPT := preload("res://scripts/vhs_ritual.gd")

const VEGAS_LEVEL_BUILDER = preload("res://scripts/levels/vegas_level_builder.gd")
const OFFICE_LEVEL_BUILDER = preload("res://scripts/levels/office_level_builder.gd")
const ANNEX_LEVEL_BUILDER = preload("res://scripts/levels/annex_level_builder.gd")
const AIRPORT_LEVEL_BUILDER = preload("res://scripts/levels/airport_level_builder.gd")
const ASYLUM_LEVEL_BUILDER = preload("res://scripts/levels/asylum_level_builder.gd")
const SCHOOL_LEVEL_BUILDER = preload("res://scripts/levels/school_level_builder.gd")
const MALL_LEVEL_BUILDER = preload("res://scripts/levels/mall_level_builder.gd")
const PRISON_LEVEL_BUILDER = preload("res://scripts/levels/prison_level_builder.gd")
const POOL_LEVEL_BUILDER = preload("res://scripts/levels/pool_level_builder.gd")
const BRUTALIST_LEVEL_BUILDER = preload("res://scripts/levels/brutalist_level_builder.gd")
const BLOOM_LEVEL_BUILDER = preload("res://scripts/levels/bloom_level_builder.gd")
const BASE_LEVEL_BUILDER = preload("res://scripts/levels/chunk_level_builder.gd")

## theme id -> level builder. One place to register a theme's construction,
## instead of a match arm here plus one in each of the four _build_* dispatchers.
## Theme ids are sparse on purpose (3 was the cut theme park); a theme with no
## entry gets the shared kernel and nothing else.
const LEVEL_BUILDERS := {
	0: VEGAS_LEVEL_BUILDER,
	1: OFFICE_LEVEL_BUILDER,
	2: ANNEX_LEVEL_BUILDER,
	4: AIRPORT_LEVEL_BUILDER,
	5: ASYLUM_LEVEL_BUILDER,
	6: SCHOOL_LEVEL_BUILDER,
	7: MALL_LEVEL_BUILDER,
	8: PRISON_LEVEL_BUILDER,
	9: POOL_LEVEL_BUILDER,
	10: BRUTALIST_LEVEL_BUILDER,
	11: BLOOM_LEVEL_BUILDER,
}

const S := WorldGen.CELL_SIZE
const H := 3.2       # vegas wall/ceiling height
const HOFF := 3.0    # office ceiling height
const HANNEX := 2.78 # the Annex's deliberately low drop ceiling
## The source ceiling map is a 2x2 grid. At the material's world-triplanar
## projection each visible square is 1.2m wide (the former 0.6m assumption
## made every troffer occupy only one quarter of a visible tile).
const ANNEX_CEILING_TILE := 1.20
## The Annex uses substantial commercial partitions. The shared 0.15m wall
## constant made its door returns look like paper and exposed a separately-lit
## end cap at every 12m chunk boundary.
const ANNEX_WALL_T := 0.30
## Tall, shallow painted skirting. The first pass projected 4cm and stood only
## 11cm high, which read as a chunky floor rail at close range.
const ANNEX_BASEBOARD_H := 0.16
const ANNEX_BASEBOARD_D := 0.02
## Raised apertures occasionally cut through the Annex's deep wall masses.
## Their carpeted sill sits at waist height and the top crosses the 1.38m eye
## line, so the player can peer through without being able to enter.
const ANNEX_TUNNEL_W := 1.20
const ANNEX_TUNNEL_SILL := 0.72
const ANNEX_TUNNEL_H := 0.72
## A tunnel has to read as a passage through a mass, not a window cut into an
## ordinary partition. Every tunneled mass is therefore over two metres deep.
const ANNEX_TUNNEL_MIN_DEPTH := 2.10
const ANNEX_FIXTURE_CLEARANCE := 0.08
## The authored outlet and switch models measure a real 7-8cm by 11-12cm — the
## size of an actual wall plate. Against the Annex's unbroken 12m walls that is
## close to invisible, so its fixtures are deliberately oversized for
## readability. The office keeps them at measured 1:1: it carries far more
## other detail to place the eye, and audit_wall_utilities asserts that scale.
const ANNEX_UTILITY_SCALE := 1.35
const HASY := 3.0    # asylum corridor height
const HSCH := 3.05   # school corridor height
const HMALL := 4.0   # mall gallery height
const HPRISON := 3.5 # prison gallery height
## Pool channel ceiling. It must clear POOL_DOOR_TOP (3.57): a dry hall's
## floor stands at 1.42, and any lower lid — or a ceiling fascia hanging from
## it — becomes a head-height beam across every doorway into the lane. The
## office default this used to inherit (3.0) did exactly that.
const HPOOL := 4.1
const HBRUTAL := 5.8
const HBLOOM := 3.2
const SCH_BAND := 1.42   # height of the red line that runs the whole school
const T := 0.15
const DOOR_TOP := 2.25
const AIR_DOOR := 3.15   # airport portal head height
const BRUTAL_DOOR_TOP := 3.15 # monumental portal head; casing must match the cut
const BLOOM_DOOR_TOP := 2.55
const DOOR_CLEAR_DEPTH := 3.6
const DOOR_CLEAR_PAD := 0.5

static var BOX := BoxMesh.new()
static var CYL := CylinderMesh.new()
static var SPH := SphereMesh.new()
static var TOR := TorusMesh.new()
static var QUAD := QuadMesh.new()
static var CONE := CylinderMesh.new()
static var _cone_ready := false

const ASY_PROP_NAMES := ["BarberShopChair_01", "Rockingchair_01", "SchoolChair_01",
	"medical_box", "metal_office_desk", "mounted_fluorescent_lights",
	"old_bed_frame", "vintage_crutches_01", "wheelchair_01"]
const CC0_PROP_NAMES := ["ArmChair_01", "Barrel_01", "Chandelier_03", "CoffeeCart_01",
	"CoffeeTable_01", "Lantern_01", "Ottoman_01", "WetFloorSign_01",
	"SchoolDesk_01", "bar_chair_round_01", "barrel_03", "barrel_stove", "clipboard",
	"coffee_table_round_01", "drawer_cabinet", "fancy_picture_frame_01",
	"fancy_picture_frame_02", "hanging_industrial_lamp", "industrial_caged_sconce",
	"old_tyre", "plastic_crate_03", "potted_plant_01", "potted_plant_02",
	"power_box_01", "rusted_wheel_rim_01", "rusted_wheel_rim_02", "sofa_03",
	"steel_frame_shelves_01", "television_02", "trashbag", "vintage_grandfather_clock_01",
	"wall_clock", "wooden_crate_01", "wooden_crate_02",
	"wooden_ladder", "wooden_picnic_table", "book_encyclopedia_set_01",
	"office_notepads",
	"old_military_compressor", "security_camera_01",
	"stationery_supplies", "CashRegister_01", "hand_truck",
	"industrial_storage_cart", "metal_trash_can", "long_life_food",
	"plunger", "drain_cleaner", "can_rusted"]
const OFFICE_CHAIR_PATH := "res://models/cc0/office_chair/Office_Chair.fbx"
const SLOT_MACHINE_PATH := "res://models/cc_by/slot_machine/slot_machine.glb"
const SLOT_MACHINE_SCALE := 1.30
const SLOT_MACHINE_FLOOR_OFFSET := 0.548386
const PRISON_BUNK_PATH := \
	"res://models/cc_by/bunk_bed/bunk_bed.glb"
const PRISON_TOILET_PATH := \
	"res://models/cc_by/prison_toilet/prison_toilet.glb"
const PRISON_DOOR_OLD_PATH := \
	"res://models/cc_by/prison_door_old/prison_door_old.glb"
const SOLITARY_CELL_DOOR_PATH := \
	"res://models/cc_by/solitary_cell_door/solitary_cell_door.glb"

# Asylum: authored institutional furniture. These stand in for the procedural
# versions that came before them; each placement keeps its generated fallback so
# an import failure degrades to a coherent room instead of a floating collider.
const ASY_BED_PATH := "res://models/cc_by/hospital_bed/hospital_bed.glb"
const ASY_BED_SCALE := 0.01
const ASY_BED_CENTRE := Vector3(-0.2564, -2.0842, 0.6923)
const ASY_GURNEY_PATH := "res://models/cc_by/asylum_gurney/asylum_gurney.glb"
const ASY_GURNEY_CENTRE := Vector3(7.9749, -0.0574, 1.6181)
const ASY_TROLLEY_PATH := \
	"res://models/cc_by/hospital_trolley/hospital_trolley.glb"
const ASY_TROLLEY_CENTRE := Vector3(0.0, -0.0006, 0.0230)
# The source tub is oversized in every axis — its rim sits at 0.854m against a
# real clawfoot's 0.60-0.70m. 0.80 brings the rim to 0.68m and the length to
# 1.80m, which reads correctly beside the 1.88m ward bed.
const ASY_BATH_PATH := "res://models/cc_by/abandoned_hospital/hydro_bath.glb"
const ASY_BATH_SCALE := 0.80
const ASY_SCRUB_SINK_PATH := \
	"res://models/cc_by/abandoned_hospital/scrub_sink.glb"
const ASY_NOTICES_PATH := \
	"res://models/cc_by/abandoned_hospital/pinned_notices.glb"
const ASY_TRANSPORT_CLEARANCE := 0.25
# Four leaves from the same hospital. Mounted at authored height as sealed
# façades on solid walls, and at ASY_DOOR_FIT in a generated opening, whose
# head is DOOR_TOP.
const ASY_DOOR_PATHS := [
	"res://models/cc_by/abandoned_hospital/ward_door.glb",
	"res://models/cc_by/abandoned_hospital/cell_door.glb",
	"res://models/cc_by/abandoned_hospital/service_door.glb",
	"res://models/cc_by/abandoned_hospital/vision_door.glb",
]
const ASY_DOOR_H := 2.4447          # tallest authored leaf
# `ward_door` is modelled with its width down X and its face on +Z; the other
# three run down Z with their face on +X and need a quarter turn to match.
const ASY_DOOR_FACE_YAW := [0.0, -PI / 2.0, -PI / 2.0, -PI / 2.0]
# Leaf height inside the generated corridor casing, which is shorter than a
# free-standing opening because the casing carries its own lintel.
const ASY_LEAF_H := 2.12
const ASY_LEAF_FIT := ASY_LEAF_H / ASY_DOOR_H

const OFFICE_TERMINAL_PATH := \
	"res://models/cc_by/ibm_3278_terminal/ibm_3278_terminal.glb"
const OFFICE_TERMINAL_SCALE := 0.0193
const OFFICE_TERMINAL_CENTRE := Vector3(-1.2799, 0.0, 2.3151)
const OFFICE_TERMINAL_SCREEN := preload(
	"res://textures/office/liminalterminal.png")
const OFFICE_WATER_COOLER_PATH := \
	"res://models/sketchfab/water_cooler/water_cooler.glb"
const OFFICE_WATER_COOLER_SCALE := 0.10
const OFFICE_WATER_COOLER_CENTRE := Vector3(0.0, 0.0005, -0.0995)
const OFFICE_AIR_CONDITIONER_PATH := \
	"res://models/cc_by/indoor_air_conditioner/indoor_air_conditioner_unit.glb"
const OFFICE_AIR_CONDITIONER_SCALE := 2.35
# Imported visual bounds: x 0.088965..0.619921, y 0.003381..0.184028,
# z -0.064694..0.066597. Re-origin on the centre of the wall-mounted housing.
const OFFICE_AIR_CONDITIONER_CENTRE := Vector3(0.354443, 0.093705, 0.000952)
const DESK_PHONE_PATH := "res://models/cc_by/corded_phone/corded_phone.glb"
const DESK_PHONE_SCALE := 5.25
# The payphone is re-origined at export so its open back sits on the wall
# contact plane, centred on its own face: placement supplies a wall point and a
# yaw and nothing else. Scaling grows it away from that plane, so the back stays
# flush. The authored 0.30 x 0.62m housing is accurate but reads undersized on a
# 4m gallery wall beside 4.8m storefronts, so it is mounted a fifth over.
const MALL_PAYPHONE_PATH := "res://models/cc_by/payphone/payphone.glb"
const MALL_PAYPHONE_SCALE := 1.2
## How far the housing hangs below its own mounting origin, in authored units.
## The bank uses it to sit the housing clear of the concourse's brass rail.
const MALL_PAYPHONE_DROP := 0.3083
const MALL_DIRECTORY_PATH := \
	"res://models/cc_by/mall_directories/mall_directories.glb"
const MALL_DIRECTORY_SCALE := 0.01
const MALL_DIRECTORY_CENTRE := Vector3(47.5, 0.0, -4.3125)

# Casino table games. The blackjack source shipped 40 chips at 10,500 triangles
# each — 84% of a half-million-triangle model, for props that are cylinders.
# Only the chips were dropped; the table, felt and six matching stools remain.
const CASINO_BLACKJACK_PATH := \
	"res://models/cc_by/blackjack_table/blackjack_table.glb"
const CASINO_BLACKJACK_SCALE := 0.00407
const CASINO_ROULETTE_PATH := \
	"res://models/cc_by/roulette_table/roulette_table.glb"
# Scaled on the baize, not on total height. The wheel bowl, rim and spindle sit
# above the playing surface and account for a fifth of the model's height, so
# fitting the total put the layout at 0.71m — visibly low to stand at.
const CASINO_ROULETTE_SCALE := 0.085
const CASINO_ROULETTE_CENTRE := Vector3(12.0064, -8.2188, -3.7567)

const MALL_HOTDOG_PATH := "res://models/cc_by/hotdog_stand/hotdog_stand.glb"
const MALL_HOTDOG_SCALE := 0.017
const MALL_HOTDOG_CENTRE := Vector3(55.9571, 0.0, -16.2907)
const MALL_SHOPPING_CART_PATH := \
	"res://models/cc_by/shopping_cart/shopping_cart.glb"
# Source bounds are 0.560 x 0.876 x 0.906m. A modest lift brings the handle to
# a natural 1.01m while keeping the cart narrow enough for the generated aisles.
const MALL_SHOPPING_CART_SCALE := 1.15
const MALL_SHOPPING_CART_CENTRE := Vector3(0.0, 0.0, 0.025569)

# Named a medical table; it is an autopsy table — fluted drainage top, castors,
# undershelf — which is why it belongs in treatment rooms and nowhere else.
const ASY_AUTOPSY_PATH := "res://models/cc_by/medical_table/medical_table.glb"
const ASY_AUTOPSY_CENTRE := Vector3(0.2409, 0.0294, -0.1539)

const OFFICE_PRINTER_PATH := \
	"res://models/cc_by/mfp_office_printer/mfp_office_printer.glb"
const OFFICE_PRINTER_SCALE := 0.01
const OFFICE_PRINTER_CENTRE := Vector3(-12.2670, -45.6449, 6.6817)
const OFFICE_BOXES_PATH := \
	"res://models/cc_by/cardboard_boxes/cardboard_boxes.glb"
const OFFICE_BOX_VARIANTS := [
	"430x210x270_1", "290x170x190_1", "290x290x290_1", "290x290x400_1",
]
const LIGHT_SWITCH_PATH := \
	"res://models/cc_by/light_switch/light_switch.glb"
const OUTLET_PATH := "res://models/cc_by/outlet/outlet.glb"
const ALARM_PATH := "res://models/cc_by/alarm_light/alarm_light.glb"
const ALARM_SCALE := 0.34
const ALARM_FITTED_HEIGHT := 1.060429 * ALARM_SCALE
const ALARM_SIGN_CLEARANCE := 0.008
const ALARM_MIN_CEILING_CLEARANCE := 0.008
const ANNEX_SHELVING_PATH := \
	"res://models/cc_by/stainless_steel_shelving/stainless_steel_shelving.glb"
const ANNEX_SHELVING_SCALE := 0.025
const ANNEX_SHELVING_CENTRE := Vector3(1.75, 0.0, 0.75)
# Measured tops of the first three load-bearing decks in the imported rack.
# Boxes are bottom-aligned by `_shelf_box`, so these are contact planes,
# not approximate visual offsets.
const ANNEX_SHELVING_DECK_TOPS := [0.09375, 0.69375, 1.14375]
const ANNEX_CHAIR_PATH := \
	"res://models/cc_by/wood_dining_chair/wood_dining_chair.glb"
const ANNEX_CHAIR_SCALE := 0.45
const ANNEX_CHAIR_CENTRE := Vector3(0.0, -1.0, 0.0)
const ANNEX_EXIT_DOOR_PATH := \
	"res://models/cc_by/backrooms_vr_exit_door/backrooms_exit_door.scn"
const AIRPORT_SEATS_PATH := \
	"res://models/cc_by/airport_seats/airport_seats.glb"
const AIRPORT_SEATS_SCALE := 0.04
const AIRPORT_SEATS_CENTRE := Vector3(28.4745, -1.3114, 23.9693)
const AIRPORT_DEPARTURE_BOARD_PATH := \
	"res://models/cc_by/airport_departure_board/airport_departure_board.glb"
# A departures board reads as signage, not a picture frame: under a 5m terminal
# ceiling the old 1.63m panel disappeared. Panel size is derived from the
# authored bounds below so the housing, hanging rods and fallback can never
# drift out of step with the scale.
const AIRPORT_DEPARTURE_BOARD_BIG_SCALE := 0.25
const AIRPORT_DEPARTURE_BOARD_SMALL_SCALE := 0.14
const AIRPORT_DEPARTURE_BOARD_UNITS := Vector3(18.1539, 12.3137, 1.1244)
# Imported bounds are approximately 18.154 x 12.314 x 1.124 authored units.
# The source origin is at floor level, so centre it vertically before mounting.
const AIRPORT_DEPARTURE_BOARD_CENTRE := Vector3(-0.0715, 6.1565, 0.0)
const AIRPORT_LUGGAGE_PATH := "res://models/cc_by/luggage/luggage.glb"
const AIRPORT_LUGGAGE_SCALE := 0.23
# The source scene is one staged set whose material-merger grouped geometry by
# material rather than by suitcase. These node lists recover its three physical
# pieces without copying meshes or leaving another piece's handles floating.
const AIRPORT_LUGGAGE_NODES := [
	["Object_7", "Object_12", "Object_18", "Object_19", "Object_20", "Object_23"],
	["Object_2", "Object_5", "Object_6", "Object_8", "Object_9", "Object_10",
		"Object_13", "Object_16", "Object_22"],
	["Object_3", "Object_4", "Object_11", "Object_14", "Object_15", "Object_21"],
]
const AIRPORT_LUGGAGE_CENTRES := [
	Vector3(-2.167161, 0.019231, -0.253345),
	Vector3(-0.025769, 0.000902, 0.464206),
	Vector3(2.168187, 0.010157, -0.355802),
]
const AIRPORT_LUGGAGE_COLLIDERS := [
	Vector3(0.40, 0.48, 0.40),
	Vector3(0.48, 0.78, 0.36),
	Vector3(0.52, 0.82, 0.40),
]
const AIRPORT_LUGGAGE_BODY_MATERIALS := [
	"tas_roze_01", "tas_roze_02", "kunststof",
	"koffer_01_blauw", "koffer_01_streep",
]
const AIRPORT_LUGGAGE_PALETTE := [
	Color("#294b65"), Color("#773846"), Color("#8a6a32"),
	Color("#365d4d"), Color("#70533d"), Color("#62566d"),
]

# Desk and chair modelled as one unit. The Sketchfab root carries a baked
# -136.9088° presentation turn; undo it so the chair looks along local +Z
# through the writing surface, matching `_sch_face_yaw`.
const SCH_DESK_PATH := "res://models/cc_by/school_desk/school_desk.glb"
const SCH_DESK_SCALE := 0.007
const SCH_DESK_YAW_FIX := deg_to_rad(136.9088)
const SCH_DESK_CENTRE := Vector3(-25.9953, 0.0512, -26.8323)
const SCH_DESK_COL_PITCH := 1.20
const SCH_DESK_ROW_PITCH := 1.70

# School chemistry lab. The source table is a full 6.21 x 5.37m island; a
# reduction puts its black worktop at 0.86m and leaves useful circulation
# in a 12m classroom instead of recreating the old thicket of overlapping
# benches. The bottle set is authored at presentation scale and is reduced to
# real tabletop glassware. Its sub-assemblies remain named, allowing the asylum
# to use individual vessels while the school keeps the complete arrangement.
const SCH_CHEMISTRY_TABLE_PATH := \
	"res://models/cc_by/chemistry_lab_table/chemistry_lab_table.glb"
const SCH_CHEMISTRY_TABLE_SCALE := 0.72
const SCH_CHEMISTRY_TABLE_CENTRE := \
	Vector3(0.815898, -0.099926, 0.412191)
const CHEMISTRY_GLASSWARE_PATH := \
	"res://models/cc_by/chemistry_bottles/chemistry_bottles.glb"
const CHEMISTRY_GLASSWARE_SCALE := 0.12
const CHEMISTRY_GLASSWARE_FULL_CENTRE := \
	Vector3(0.375171, 0.000001, 0.386920)
const CHEMISTRY_GLASSWARE_VARIANTS := [
	["MatrazErlenmeyer_1"],
	["Vaso de precipitado_6"],
	["Probeta_7"],
	["MatrazFondoPlano_0"],
	["Soporte Tubos_9", "Tubo de ensayo1_2", "Tubo de ensayo2_5",
		"Tubo de ensayo3_4", "Tubo de ensayo4_3"],
]
const CHEMISTRY_GLASSWARE_CENTRES := [
	Vector3(0.805776, 0.004035, 1.100000),
	Vector3(-0.987876, 0.000001, 1.100000),
	Vector3(-2.395622, 0.037215, 1.100000),
	Vector3(2.758199, 0.004035, 1.100000),
	Vector3(1.249908, 0.001937, -0.504714),
]
# Verified against the granite mesh triangles, not merely the table's bounding
# box. The model is L-shaped: its visual centre is open floor, which is why the
# original full set appeared to float. These slots stay well inside the broad
# rear worktop and its narrow return, clear of the authored sink cut-out.
const SCH_CHEMISTRY_COUNTER_POINTS := [
	Vector3(-1.40, 0.864, -1.30),
	Vector3(-0.55, 0.864, -1.30),
	Vector3(0.30, 0.864, -1.30),
	Vector3(1.15, 0.864, -1.30),
	Vector3(-1.35, 0.864, -0.72),
	Vector3(-0.45, 0.864, -0.72),
	Vector3(0.45, 0.864, -0.72),
	Vector3(1.35, 0.864, -0.72),
	Vector3(-1.90, 0.864, 0.38),
	Vector3(-1.90, 0.864, 1.04),
]

## CC BY replacement for the former noncommercial desk phone. The downloaded
## scene is authored in large units; these measured bounds restore a compact
## 0.31 x 0.16 x 0.39m phone on the desk.
const OFFICE_PHONE_PATH := "res://models/cc_by/office_phone/office_phone.glb"
const OFFICE_PHONE_SCALE := 0.025
const OFFICE_PHONE_CENTRE := Vector3(0.02702, -0.0063, -0.88795)

# --- authored replacements for generated furniture ---------------------------
#
# Every model below took over a function that used to assemble the same object
# out of boxes and cylinders. They share one convention: authored front is
# local +Z, which is what `_wall_facing` already assumes, and each records the
# (centre x, lowest y, centre z) of its own bounds so `_attributed_floor_prop`
# can drop it centred and standing on the floor.
#
# Scales are fitted to the *working surface* — the seat, the counter, the
# baize — not to total height. Fitting a total is how the school desk, the
# hydrotherapy bath and the roulette table each ended up short.

## Third casino cabinet. The 1-in-5 machines that used to be assembled out of
## 42 primitives are this instead; the generated cabinet stays as the fallback.
## The source shipped a 5.2m ground plane baked into the scene, since removed.
const SLOT_ALT_PATH := "res://models/cc_by/slot_machine_alt/slot_machine_alt.glb"
const SLOT_ALT_SCALE := 0.81064
const SLOT_ALT_CENTRE := Vector3(0.0, -0.1019, 0.0539)

const CHANGE_MACHINE_PATH := \
	"res://models/cc_by/change_machine/change_machine.glb"
const CHANGE_MACHINE_SCALE := 0.61738
const CHANGE_MACHINE_CENTRE := Vector3(0.0, 0.0, 0.0432)

## Two brass stanchions and the swag between them, as one unit. Posts sit
## 1.891m apart at this scale, which is what the queue lines are laid out on
## rather than the other way round — stretching the unit to a chosen pitch
## would take the post height with it.
const ROPE_BARRIER_PATH := "res://models/sketchfab/rope_barrier/rope_barrier.glb"
const ROPE_BARRIER_SCALE := 0.62184
const ROPE_BARRIER_CENTRE := Vector3(0.0, 0.0, 0.0)
const ROPE_BARRIER_PITCH := 1.891

const CHECKIN_DESK_PATH := "res://models/sketchfab/checkin_desk/checkin_desk.glb"
## Authored in metres and correct at 1:1. The source was a double-sided island
## mirrored about its counter — 6.23m deep, more than the 3.4m between the
## queue lane and the back wall — so it is clipped to one position: counter at
## local -Z facing the queue, masts, scale and belt housing running back to +Z.
const CHECKIN_DESK_SCALE := 1.0
const CHECKIN_DESK_CENTRE := Vector3(0.0, 0.0, 0.0)
## Half-depth and width of the clipped position, which is what sets both the
## desk pitch below and the distance the row stands off the back wall.
const CHECKIN_DESK_W := 4.78

const GARBAGE_BIN_PATH := "res://models/cc_by/garbage_bin/garbage_bin.glb"
const GARBAGE_BIN_SCALE := 1.0
const GARBAGE_BIN_CENTRE := Vector3(0.0, 0.0028, 0.0)

const IV_DRIP_PATH := "res://models/cc_by/iv_drip/iv_drip.glb"
const IV_DRIP_SCALE := 0.00486
const IV_DRIP_CENTRE := Vector3(31.8042, -0.8658, 0.0)

const CITY_BENCH_PATH := "res://models/cc_by/city_bench/city_bench.glb"
const CITY_BENCH_SCALE := 0.01186
const CITY_BENCH_CENTRE := Vector3(0.0, 0.0, -1.1806)

const FOOD_COURT_SET_PATH := \
	"res://models/cc_by/food_court_set/food_court_set.glb"
## Fitted so the tabletop lands at 0.75m. The chairs' spindle backs run 0.4m
## above that and would have made a 1.39m table out of a 0.92m one.
const FOOD_COURT_SET_SCALE := 0.818
const FOOD_COURT_SET_CENTRE := Vector3(0.0, -0.0172, -0.7932)

const LOCKERS_PATH := "res://models/cc_by/lockers/lockers.glb"
const LOCKERS_SCALE := 0.00904
const LOCKERS_CENTRE := Vector3(22.0150, -115.0920, 79.8665)
## Width of one authored run, used to tile a corridor length without stretching.
const LOCKERS_RUN_W := 1.97
const GYM_LOCKER_PATH := "res://models/cc_by/gym_locker/gym_locker.glb"
const GYM_LOCKER_SCALE := 16.68542
const GYM_LOCKER_CENTRE := Vector3(0.0, 0.0074, -0.0012)
const GYM_LOCKER_W := 0.48

const SCH_SINK_PATH := "res://models/cc_by/sink/sink.glb"
const SCH_SINK_SCALE := 1.0
const SCH_SINK_CENTRE := Vector3(0.0075, -0.0076, 0.0336)
const SCH_TOILET_PATH := "res://models/cc_by/toilet/toilet.glb"
const SCH_TOILET_SCALE := 1.0
const SCH_TOILET_CENTRE := Vector3(-0.0279, 0.0, 0.3011)
const SCH_URINAL_PATH := "res://models/cc_by/urinal/urinal.glb"
const SCH_URINAL_SCALE := 1.0
## Authored hanging: the bowl's lowest point is 0.60m up its own mounting
## plane, so this one is placed from the wall rather than from the floor.
const SCH_URINAL_CENTRE := Vector3(-0.1628, 0.5985, -0.0041)
const SCH_FOUNTAIN_PATH := \
	"res://models/cc_by/drinking_fountain/drinking_fountain.glb"
const SCH_FOUNTAIN_SCALE := 0.55948
const SCH_FOUNTAIN_CENTRE := Vector3(-0.0249, -0.9555, -0.0157)

## An authored overhead fixture sheet was measured for `_troffer` and rejected.
## The 4ft pan it contains is 3.9:1, and five of the six ceiling runs need
## between 2.1:1 and 11.8:1 — matching them means non-uniform scaling that
## visibly distorts the housing and its end caps. The lens would have to stay a
## separate emissive quad in every case regardless, because the flicker system
## drives that material and the model's own lens is baked, so the model would
## only ever have contributed a frame around a quad that five boxes already do.

const PRISON_WALL_PHONE_PATH := \
	"res://models/prison/stainless_wall_phone/Stainless_Wall_Phone_GAME.glb"
## Metric asset: centre vertically and align its back with the mounting plane.
const PRISON_WALL_PHONE_SCALE := 1.0
const PRISON_WALL_PHONE_CENTRE := Vector3(0.0, 0.1609867, -0.0318079)

## CC BY replacement for the former noncommercial school cart. Its source is
## 7.75 units high, so a 0.16 scale yields a realistic 1.24m trolley.
##
## Two authored jetways have been measured for `_air_jetway` and neither
## shipped. The apron is a sealed 2.14m diorama strip that the docked aircraft
## already fills — fuselage z 4.00..5.76 across its full 10.5m width. A tunnel
## sized to that depth is either too short to read as a jetway, or tall enough
## to swallow the aircraft rather than dock against it. The generated tube is
## 1m across and tuned to meet a fuselage, which is what this space actually
## needs; a replacement has to be authored as a shallow facade, not a bridge.
const SCH_CLEANING_CART_PATH := \
	"res://models/cc_by/cleaning_cart/cleaning_cart.glb"
const SCH_CLEANING_CART_SCALE := 0.16
const SCH_CLEANING_CART_CENTRE := Vector3(0.0, 0.000065, -0.831794)

## Painted storefront fascias cropped from a CC BY-NC source. Every use of these
## runs through `_mall_unit_sign`, so the noncommercial dependency can be lifted
## out in one edit; the generated MALL_NAMES lettering is the fallback and stays.
const MALL_SIGN_DIR := "res://textures/cc_by_nc/mall_signs/"
# Fit bounds for a painted board inside the 4.4 x 0.50m generated fascia. The
# placement and its audit read the same two numbers, so widening one cannot
# silently invalidate the other.
const MALL_SIGN_MAX_W := 4.25
const MALL_SIGN_MAX_H := 0.46
const MALL_SIGN_FACES := [
	["key_of_beauty", 7.71], ["purple_side", 6.15], ["natural_shop", 3.84],
	["since_1977", 4.75], ["blue_marine", 6.20], ["royal_grill", 6.04],
	["boutique_marguerite", 4.10], ["cafe_paradise_noon", 5.21],
	["sunshine_princess", 5.75],
]

const ART_VEGAS := [
	"res://paintings/runtime/painting1-vegas.webp",
	"res://paintings/runtime/painting2-vegas.webp",
	"res://paintings/runtime/painting3-vegas.webp",
	"res://paintings/runtime/painting4-vegas.webp",
	"res://paintings/runtime/painting5-vegas.webp",
]
const POSTER_OFFICE := [
	"res://paintings/runtime/posters/poster-office-01.webp",
	"res://paintings/runtime/posters/poster-office-02.webp",
	"res://paintings/runtime/posters/poster-office-03.webp",
	"res://paintings/runtime/posters/poster-office-04.webp",
	"res://paintings/runtime/posters/poster-office-05.webp",
	"res://paintings/runtime/posters/poster-office-06.webp",
	"res://paintings/runtime/posters/poster-office-07.webp",
	"res://paintings/runtime/posters/poster-office-08.webp",
	"res://paintings/runtime/posters/poster-office-09.webp",
]
const POSTER_ANNEX := [
	"res://paintings/runtime/posters/poster-annex-01.webp",
	"res://paintings/runtime/posters/poster-annex-02.webp",
	"res://paintings/runtime/posters/poster-annex-03.webp",
	"res://paintings/runtime/posters/poster-annex-04.webp",
	"res://paintings/runtime/posters/poster-annex-05.webp",
	"res://paintings/runtime/posters/poster-annex-06.webp",
	"res://paintings/runtime/posters/poster-annex-07.webp",
	"res://paintings/runtime/posters/poster-annex-08.webp",
	"res://paintings/runtime/posters/poster-annex-09.webp",
]
const POSTER_AIRPORT := [
	"res://paintings/runtime/posters/poster-airport-01.webp",
	"res://paintings/runtime/posters/poster-airport-02.webp",
	"res://paintings/runtime/posters/poster-airport-03.webp",
	"res://paintings/runtime/posters/poster-airport-04.webp",
	"res://paintings/runtime/posters/poster-airport-05.webp",
	"res://paintings/runtime/posters/poster-airport-06.webp",
	"res://paintings/runtime/posters/poster-airport-07.webp",
	"res://paintings/runtime/posters/poster-airport-08.webp",
	"res://paintings/runtime/posters/poster-airport-09.webp",
]
const POSTER_MALL := [
	"res://paintings/runtime/posters/poster-mall-01.webp",
	"res://paintings/runtime/posters/poster-mall-02.webp",
	"res://paintings/runtime/posters/poster-mall-03.webp",
	"res://paintings/runtime/posters/poster-mall-04.webp",
	"res://paintings/runtime/posters/poster-mall-05.webp",
	"res://paintings/runtime/posters/poster-mall-06.webp",
	"res://paintings/runtime/posters/poster-mall-07.webp",
	"res://paintings/runtime/posters/poster-mall-08.webp",
	"res://paintings/runtime/posters/poster-mall-09.webp",
]
const POSTER_SCHOOL := [
	"res://paintings/runtime/posters/poster-school-01.webp",
	"res://paintings/runtime/posters/poster-school-02.webp",
	"res://paintings/runtime/posters/poster-school-03.webp",
	"res://paintings/runtime/posters/poster-school-04.webp",
	"res://paintings/runtime/posters/poster-school-05.webp",
	"res://paintings/runtime/posters/poster-school-06.webp",
	"res://paintings/runtime/posters/poster-school-07.webp",
	"res://paintings/runtime/posters/poster-school-08.webp",
	"res://paintings/runtime/posters/poster-school-09.webp",
]
const POSTER_ASYLUM := [
	"res://paintings/runtime/posters/poster-asylum-01.webp",
	"res://paintings/runtime/posters/poster-asylum-02.webp",
	"res://paintings/runtime/posters/poster-asylum-03.webp",
	"res://paintings/runtime/posters/poster-asylum-04.webp",
	"res://paintings/runtime/posters/poster-asylum-05.webp",
	"res://paintings/runtime/posters/poster-asylum-06.webp",
	"res://paintings/runtime/posters/poster-asylum-07.webp",
	"res://paintings/runtime/posters/poster-asylum-08.webp",
	"res://paintings/runtime/posters/poster-asylum-09.webp",
]
const POSTER_PRISON := [
	"res://paintings/runtime/posters/poster-prison-01.webp",
	"res://paintings/runtime/posters/poster-prison-02.webp",
	"res://paintings/runtime/posters/poster-prison-03.webp",
	"res://paintings/runtime/posters/poster-prison-04.webp",
	"res://paintings/runtime/posters/poster-prison-05.webp",
	"res://paintings/runtime/posters/poster-prison-06.webp",
	"res://paintings/runtime/posters/poster-prison-07.webp",
	"res://paintings/runtime/posters/poster-prison-08.webp",
	"res://paintings/runtime/posters/poster-prison-09.webp",
]
const ART_SEWER := [
	"res://paintings/runtime/painting1-sewer.webp",
	"res://paintings/runtime/painting2-sewer.webp",
]
const ART_RANDOM := [
	"res://paintings/runtime/painting1-random.webp",
	"res://paintings/runtime/painting2-random.webp",
]
# Sewer paintings remain in the supplied source set, but the sewer itself is
# deliberately bare: damp utility tunnels should not read like a gallery.
const WALL_ART_ALL := ART_VEGAS + POSTER_OFFICE + POSTER_ANNEX \
	+ POSTER_AIRPORT + POSTER_ASYLUM + POSTER_SCHOOL + POSTER_MALL \
	+ POSTER_PRISON

# Builder-owned implementations still share a small amount of immutable
# authored data through Chunk. Keeping these values on the stable host also
# preserves the existing public constants used by main.gd and the audit tools.
const CASINO_NEON := [
	["C O C K T A I L S", Color(0.3, 1.0, 0.8)],
	["C A S H I E R", Color(1.0, 0.75, 0.2)],
	["B U F F E T", Color(1.0, 0.5, 0.2)],
	["K E N O", Color(0.55, 0.7, 1.0)],
	["R O O M S", Color(1.0, 0.4, 0.6)],
]
const OFFICE_CORRIDOR_LABELS := ["ACCOUNTS", "ARCHIVES", "CONFERENCE B",
	"FACILITIES", "HUMAN RESOURCES", "PROCESSING", "RECORDS", "SUPPLY"]
const OFFICE_ZONE_DEPTS := [
	["PROCESSING", "ACCOUNTS", "DATA SERVICES"],
	["ARCHIVES", "RECORDS", "DOCUMENT CONTROL"],
	["WELLNESS", "BREAK ROOMS", "HUMAN RESOURCES"],
]
const TERMINAL_PAGES := [
	"EMPLOYEE 0000\nSTATUS: PRESENT\nSHIFT END: --:--",
	"QUEUE 9 / 9\nPLEASE REMAIN\nAT YOUR STATION",
	"FLOOR PLAN\nROOM NOT FOUND\nRETRYING...",
	"MESSAGE (1)\nFROM: YOURSELF\nDO NOT REPLY",
]
const TERMINAL_SCREEN_SIZE := Vector2(0.26, 0.195)
const TERMINAL_TEXT_PIXEL_SIZE := 0.00082
const TERMINAL_TEXT_FONT_SIZE := 44
const TERMINAL_TEXT_LAYOUT_WIDTH := 285.0
const TERMINAL_FONT := preload("res://fonts/VT323-Regular.ttf")
const SCH_ZONE_ROOMS := [
	["101", "103", "112", "204", "ART", "SCIENCE"],
	["MUSIC", "GYM", "CAFETERIA", "LIBRARY", "ART"],
	["FACULTY", "MAIN OFFICE", "COUNSELOR", "RECORDS"],
]
const SCH_CHALK := [
	"TODAY: FRIDAY\nTOMORROW: FRIDAY",
	"HOMEWORK\nfinish the corridor",
	"ATTENDANCE\n0 / 0 PRESENT",
	"DO NOT LOOK AT\nTHE BACK ROW",
	"SUBSTITUTE TEACHER\nAGAIN",
	"PERIOD 9\nPERIOD 9\nPERIOD 9",
	"WHO TURNED OFF\nTHE BELL?",
	"READ CHAPTER\nAGAIN",
	"TEST TOMORROW\n(there is no tomorrow)",
	"PLEASE REMAIN\nSEATED UNTIL",
	"IF YOU CAN READ THIS\nYOU ARE STILL HERE",
	"class of\n19__",
	"THE BELL RANG\nAFTER EVERYONE LEFT",
	"DO NOT ERASE\nTHE LAST LINE",
	"WE COUNTED\nONE TOO MANY",
	"TODAY'S LESSON:\nSTAY WHERE YOU ARE",
]
const MALL_NAMES := ["ORCHARD", "ARCADE", "HOUSE & HOME", "PARADE",
	"LEVEL TWO", "FOOD GALLERY", "CLOSED", "COMING SOON",
	"RADIO HUT", "SHOE PALACE", "GOLDEN WOK", "PHOTO 1 HR",
	"CARD & PARTY", "PRETZEL TIME", "BOOKS & CO", "FASHION CITY",
	"TOY CHEST", "NAILS", "OPTICA", "GIFT GARDEN",
	"PET CORNER", "RECORD BAR", "LUGGAGE WORLD", "SUIT YOURSELF"]
const MALL_FOOD := ["GOLDEN WOK", "PRETZEL TIME", "BURGER BARN", "TACO FIESTA",
	"ORANGE JULIET", "PIZZA MIA", "DONUT DEN", "CHICKEN SHACK"]

# Pool measurements are part of Chunk's public geometry contract. In
# particular main.gd reads POOL_WATER_Y to determine the active water plane.
const POOL_WATER_Y := 1.05
const POOL_DECK_Y := 1.42
const POOL_DRY_Y := 1.42
const POOL_DOOR_TOP := POOL_DRY_Y + 2.15
const POOL_PIER := 1.05
const POOL_WALL_T := 0.30
const POOL_PILLAR_RADIUS := POOL_PIER * 0.62
const POOL_CORNER_SEGMENTS := 10
const POOL_LANE := 2.9
const POOL_LADDER_W := 0.52
const POOL_LADDER_PATH := "res://models/cc_by/pool_ladder/pool_ladder.glb"
const POOL_CHAIR_PATH := "res://models/cc_by/plastic_chair/plastic_chair.glb"
const POOL_CHAIR_MESH := "polySurface15_blinn6_0"
const POOL_CHAIR_CENTRE := Vector3(1.664, 0.0, -0.025)
const POOL_LOUNGE_CHAIR_PATH := \
	"res://models/cc_by/pool_lounge_chair/pool_lounge_chair.glb"
const POOL_LOUNGE_CHAIR_SCALE := 0.75
const POOL_LOUNGE_CHAIR_CENTRE := Vector3(-0.3787, -0.5870, 0.0008)
const POOL_JACUZZI_PATH := \
	"res://models/cc_by/soulmate_jacuzzi/soulmate_jacuzzi.glb"
# The source scene nests 100x FBX transforms under counter-rotated parents.
# These are the combined, transformed bounds—not the raw mesh accessor bounds.
const POOL_JACUZZI_SCALE := 0.0125
const POOL_JACUZZI_CENTRE := Vector3(1.8269, -43.2387, 25.0056)
const POOL_LIGHT_PATH := "res://models/cc_by/pool_light/pool_light.glb"
const POOL_LIGHT_SCALE := 0.045
const BRUTAL_LIGHT_PATH := \
	"res://models/cc_by/fluorescent_light_fixtures/fluorescent_light_fixtures.glb"
const DATA_CENTER_CONSOLE_PATH := \
	"res://models/cc_by/server_v2_console/server_v2_console.glb"
const DATA_CENTER_RACK_BANK_PATH := \
	"res://models/cc_by/server_rack/server_rack.glb"
const DATA_CENTER_RACK_PATH := \
	"res://models/cc_by/data_center_server_rack/data_center_server_rack.glb"
const DATA_CENTER_NETWORK_RACK_PATH := \
	"res://models/cc_by/network_server_rack/network_server_rack.glb"
const DATA_CENTER_DETAILED_RACK_PATH := \
	"res://models/cc_by/server_racking_system/server_racking_system.glb"
const DATA_CENTER_GLASS_SERVER_PATH := \
	"res://models/cc_by/server/server.glb"
const DATA_CENTER_AZURE_SERVER_PATH := \
	"res://models/cc_by/tall_server_of_base_with_azure_lane_island/" + \
	"tall_server_of_base_with_azure_lane_island.glb"
const DATA_CENTER_AC_PATHS := [
	"res://models/cc_by/air_conditioners/air_conditioner_floor_a.scn",
	"res://models/cc_by/air_conditioners/air_conditioner_floor_b.scn",
	"res://models/cc_by/air_conditioners/air_conditioner_floor_c.scn",
]
const BLOOM_ROOT_PATH := "res://models/cc0/pine_roots/pine_roots.gltf"
const BLOOM_VINES_PATH := "res://models/cc_by/modular_vines/modular_vines.glb"
const BLOOM_FLESH_BLOB_PATH := "res://models/cc_by/flesh_blob/flesh_blob.glb"
const POOL_LADDER_SCALE := 1.0
const POOL_BUOY_PATH := "res://models/cc_by/pool_buoy/pool_buoy.glb"
const POOL_BUOY_TINTS := [
	Color(0.62, 0.24, 0.72), Color(0.86, 0.32, 0.30),
	Color(0.28, 0.52, 0.80), Color(0.92, 0.74, 0.26),
	Color(0.30, 0.68, 0.48),
]

static var _prop_preloads_requested := false
static var _slot_scene: PackedScene
static var _attributed_scenes := {}
static var _scrawl_fonts := {}
static var profile_build_stages := false
static var profile_stage_threshold_ms := 4.0
static var _prewarmed_themes := {}

var wseed: int
var cell: Vector2i
var theme: int
var body: StaticBody3D
var style: int
var ceil_h: float
var portal_dest := -1
var room_root: Vector2i        # the room this cell belongs to
var room_n := 1                # how many cells the room spans
var is_room_anchor := false    # only the anchor cell furnishes the room
var doorway_props_removed := 0 # exposed for the generated-doorway audit
var descent := false
var descent_topology: DescentTopology
## Off-tree blackout replacements may be prepared for the next complete state
## while the live resolver still owns the old one. Installed chunks always use
## -1 and follow the resolver normally.
var descent_topology_state_override := -1
var descent_target := false
var descent_target_wall := -1
var descent_final := false
var descent_floor_idx := 0
## The arrival room — the car the player rides in on. A separate authored cell
## from the objective, and never the same one.
var descent_arrival := false
var descent_arrival_wall := -1
var descent_arrival_used := false
## Objective lift call state, mirrored from DescentRun so a target room that
## streams out during the wait resumes it correctly when it streams back in.
var descent_lift_called := false
var descent_lift_wait := 0.0
var descent_lift_open := false
## Whether this floor's tape has already been watched, mirrored from the run
## like the lift state. The lift refuses an unwatched player.
var descent_tape_watched := false
## The run's base seed; the session-wide tape deal is keyed on it.
var descent_base_seed := 1
var optional_vhs := false
var optional_vhs_key := ""
## This cell's lattice station is the run's one dead unit, and whether it has
## already sprung. The objective room's own station is never the dead one.
var descent_broken_station := false
var descent_broken_station_tried := false
## How far the next floor has crept into this one at the moment this chunk was
## built, and which theme is doing the creeping.
var bleed_amount := 0.0
var bleed_theme := -1
var anomaly_kind := -1
## Complete furniture recipe selected by the floor's generated reality graph.
## Zero is the seed-authored layout; later values are deterministic validated
## alternatives and therefore survive streaming/rebuilds exactly.
var mutation_furniture_variant := 0
var mutation_furniture_changed_groups := 0
## Only used by the waiting-figure anomaly, which needs a hunt target.
var anomaly_player: Player
var _descent_lift_rig := {}
var _descent_arrival_rig := {}
var _blackout := false
var _blackout_lights := {}
var _blackout_meshes := {}
var _furnishing_group_serial := 0
## Stable semantic identities for objects whose generated node instances may
## disappear during streaming or a reality rebuild. Kept outside scene metadata
## so adding runtime ownership cannot alter the generated scene fingerprint.
var _runtime_objects: Dictionary = {}
var _runtime_identity_errors := 0
## Theme-owned construction lives in a small composition object. Chunk keeps
## the stable public API and shared geometry kernel while its compatibility
## methods forward to this active builder.
var _level_builder: RefCounted
## Typed, deliberately narrow construction boundary. The compatibility `chunk`
## host remains available while theme builders migrate one at a time.
var _build_context: ChunkBuildContext
var _scene_writer: ChunkSceneWriter
## Local XZ footprints of walls and columns that reach the drop ceiling.
## Annex fixtures are built after its architecture and reject these rectangles.
var _annex_ceiling_obstructions: Array[Rect2] = []
## Every interior architecture slab already standing in this Annex cell, as
## plan_box() dictionaries. The architecture pass had no notion of what it had
## already placed, so a lobby's half wall could be driven straight through its
## column; each piece now tests against these before it is built.
var _annex_architecture_footprints: Array[Dictionary] = []
# props are laid out in cell coords, then shifted onto the room centre


## Start glTF loading on worker threads while the title card is up. The first
## encounter with a new prop previously made streaming pay the full disk,
## decode and scene-import cost in one frame (hundreds of milliseconds for the
## heaviest casino sets). Retrieval still blocks if a player outruns the load,
## but in normal play the work is complete long before another floor is seen.
static func request_prop_preloads() -> void:
	if _prop_preloads_requested:
		return
	_prop_preloads_requested = true
	# These two finishes occur only in uncommon landmark rooms, well after the
	# level-change fade has gone. Prime them before the title appears so the
	# first cinema or shower block cannot introduce a one-frame texture hitch.
	Mats.mall_brick()
	Mats.prison_tile()
	Mats.note_wall_art_preloads_requested()
	for path in _prop_preload_paths():
		ResourceLoader.load_threaded_request(path)


static func _prop_preload_paths() -> Array[String]:
	var paths: Array[String] = []
	for mname in ASY_PROP_NAMES:
		paths.append("res://models/asylum/%s/%s_1k.gltf" % [mname, mname])
	for mname in CC0_PROP_NAMES:
		paths.append("res://models/cc0/%s/%s_1k.gltf" % [mname, mname])
	paths.append(OFFICE_CHAIR_PATH)
	paths.append(SLOT_MACHINE_PATH)
	paths.append(PRISON_BUNK_PATH)
	paths.append(PRISON_TOILET_PATH)
	paths.append(PRISON_DOOR_OLD_PATH)
	paths.append(SOLITARY_CELL_DOOR_PATH)
	paths.append(ASY_BED_PATH)
	paths.append(ASY_GURNEY_PATH)
	paths.append(ASY_TROLLEY_PATH)
	paths.append(ASY_BATH_PATH)
	paths.append(ASY_SCRUB_SINK_PATH)
	paths.append(ASY_NOTICES_PATH)
	for door_path in ASY_DOOR_PATHS:
		paths.append(door_path)
	paths.append(OFFICE_TERMINAL_PATH)
	paths.append(OFFICE_WATER_COOLER_PATH)
	paths.append(OFFICE_AIR_CONDITIONER_PATH)
	paths.append(ALARM_PATH)
	paths.append(POOL_JACUZZI_PATH)
	paths.append(POOL_LOUNGE_CHAIR_PATH)
	paths.append(DESK_PHONE_PATH)
	paths.append(MALL_PAYPHONE_PATH)
	paths.append(MALL_DIRECTORY_PATH)
	paths.append(CASINO_BLACKJACK_PATH)
	paths.append(CASINO_ROULETTE_PATH)
	paths.append(MALL_HOTDOG_PATH)
	paths.append(MALL_SHOPPING_CART_PATH)
	paths.append(ASY_AUTOPSY_PATH)
	paths.append(OFFICE_PRINTER_PATH)
	paths.append(OFFICE_BOXES_PATH)
	paths.append(LIGHT_SWITCH_PATH)
	paths.append(OUTLET_PATH)
	paths.append(ANNEX_SHELVING_PATH)
	paths.append(ANNEX_CHAIR_PATH)
	paths.append(ANNEX_EXIT_DOOR_PATH)
	paths.append(BRUTAL_LIGHT_PATH)
	paths.append(DATA_CENTER_CONSOLE_PATH)
	paths.append(DATA_CENTER_RACK_BANK_PATH)
	paths.append(DATA_CENTER_RACK_PATH)
	paths.append(DATA_CENTER_NETWORK_RACK_PATH)
	paths.append(DATA_CENTER_DETAILED_RACK_PATH)
	paths.append(DATA_CENTER_GLASS_SERVER_PATH)
	paths.append(DATA_CENTER_AZURE_SERVER_PATH)
	for ac_path in DATA_CENTER_AC_PATHS:
		paths.append(ac_path)
	paths.append(BLOOM_ROOT_PATH)
	paths.append(BLOOM_VINES_PATH)
	paths.append(BLOOM_FLESH_BLOB_PATH)
	paths.append(AIRPORT_SEATS_PATH)
	paths.append(AIRPORT_DEPARTURE_BOARD_PATH)
	paths.append(AIRPORT_LUGGAGE_PATH)
	paths.append(SCH_DESK_PATH)
	paths.append(SCH_CHEMISTRY_TABLE_PATH)
	paths.append(CHEMISTRY_GLASSWARE_PATH)
	paths.append(OFFICE_PHONE_PATH)
	paths.append(SLOT_ALT_PATH)
	paths.append(CHANGE_MACHINE_PATH)
	paths.append(ROPE_BARRIER_PATH)
	paths.append(CHECKIN_DESK_PATH)
	paths.append(GARBAGE_BIN_PATH)
	paths.append(IV_DRIP_PATH)
	paths.append(CITY_BENCH_PATH)
	paths.append(FOOD_COURT_SET_PATH)
	paths.append(LOCKERS_PATH)
	paths.append(GYM_LOCKER_PATH)
	paths.append(SCH_SINK_PATH)
	paths.append(SCH_TOILET_PATH)
	paths.append(SCH_URINAL_PATH)
	paths.append(SCH_FOUNTAIN_PATH)
	paths.append(PRISON_WALL_PHONE_PATH)
	paths.append(SCH_CLEANING_CART_PATH)
	for art_path in WALL_ART_ALL:
		paths.append(art_path)
	return paths


## Bounded live prefetch manifests. Required assets still have synchronous
## fallbacks; this only prepares known floor families ahead of their first use.
static func theme_prop_paths(p_theme: int) -> Array[String]:
	var paths: Array[String] = []
	match p_theme:
		0:
			paths.append_array([SLOT_MACHINE_PATH, SLOT_ALT_PATH, CHANGE_MACHINE_PATH])
			paths.append_array([CASINO_BLACKJACK_PATH, CASINO_ROULETTE_PATH, ROPE_BARRIER_PATH])
			paths.append("res://models/cc0/Chandelier_03/Chandelier_03_1k.gltf")
			paths.append("res://models/cc0/bar_chair_round_01/bar_chair_round_01_1k.gltf")
			paths.append("res://models/cc0/coffee_table_round_01/coffee_table_round_01_1k.gltf")
			paths.append("res://models/cc0/vintage_grandfather_clock_01/vintage_grandfather_clock_01_1k.gltf")
			paths.append("res://models/cc0/sofa_03/sofa_03_1k.gltf")
			paths.append("res://models/cc0/CoffeeTable_01/CoffeeTable_01_1k.gltf")
			paths.append("res://models/cc0/ArmChair_01/ArmChair_01_1k.gltf")
			paths.append("res://models/cc0/Ottoman_01/Ottoman_01_1k.gltf")
			paths.append("res://models/cc0/potted_plant_01/potted_plant_01_1k.gltf")
		1:
			paths.append_array([OFFICE_AIR_CONDITIONER_PATH, OFFICE_PHONE_PATH, OFFICE_PRINTER_PATH])
			paths.append_array([OFFICE_WATER_COOLER_PATH, OFFICE_CHAIR_PATH, OFFICE_TERMINAL_PATH])
			paths.append_array([OFFICE_BOXES_PATH, LIGHT_SWITCH_PATH, OUTLET_PATH])
			paths.append("res://models/cc0/WetFloorSign_01/WetFloorSign_01_1k.gltf")
			paths.append("res://models/cc0/clipboard/clipboard_1k.gltf")
			paths.append("res://models/cc0/office_notepads/office_notepads_1k.gltf")
			paths.append("res://models/cc0/stationery_supplies/stationery_supplies_1k.gltf")
			paths.append("res://models/cc0/steel_frame_shelves_01/steel_frame_shelves_01_1k.gltf")
			paths.append("res://models/cc0/drawer_cabinet/drawer_cabinet_1k.gltf")
			paths.append("res://models/cc0/CoffeeCart_01/CoffeeCart_01_1k.gltf")
			paths.append("res://models/cc0/coffee_table_round_01/coffee_table_round_01_1k.gltf")
			paths.append("res://models/cc0/television_02/television_02_1k.gltf")
			paths.append("res://models/cc0/potted_plant_02/potted_plant_02_1k.gltf")
			paths.append("res://models/cc0/security_camera_01/security_camera_01_1k.gltf")
		2:
			paths.append_array([OFFICE_AIR_CONDITIONER_PATH, ANNEX_EXIT_DOOR_PATH, ANNEX_CHAIR_PATH])
			paths.append_array([ANNEX_SHELVING_PATH, LIGHT_SWITCH_PATH, OUTLET_PATH])
			paths.append("res://models/asylum/SchoolChair_01/SchoolChair_01_1k.gltf")
		4:
			paths.append_array([AIRPORT_SEATS_PATH, AIRPORT_DEPARTURE_BOARD_PATH, AIRPORT_LUGGAGE_PATH])
			paths.append_array([CHECKIN_DESK_PATH])
			paths.append("res://models/cc0/WetFloorSign_01/WetFloorSign_01_1k.gltf")
			paths.append("res://models/cc0/wooden_picnic_table/wooden_picnic_table_1k.gltf")
			paths.append("res://models/cc0/CoffeeCart_01/CoffeeCart_01_1k.gltf")
		5:
			paths.append_array([ASY_BED_PATH, ASY_GURNEY_PATH, ASY_TROLLEY_PATH])
			paths.append_array([ASY_BATH_PATH, ASY_SCRUB_SINK_PATH, ASY_NOTICES_PATH])
			paths.append_array([ASY_AUTOPSY_PATH, IV_DRIP_PATH, CHEMISTRY_GLASSWARE_PATH])
			paths.append_array(ASY_DOOR_PATHS)
			paths.append("res://models/asylum/mounted_fluorescent_lights/mounted_fluorescent_lights_1k.gltf")
			paths.append("res://models/asylum/old_bed_frame/old_bed_frame_1k.gltf")
			paths.append("res://models/asylum/wheelchair_01/wheelchair_01_1k.gltf")
			paths.append("res://models/asylum/SchoolChair_01/SchoolChair_01_1k.gltf")
			paths.append("res://models/asylum/medical_box/medical_box_1k.gltf")
			paths.append("res://models/asylum/Rockingchair_01/Rockingchair_01_1k.gltf")
			paths.append("res://models/asylum/BarberShopChair_01/BarberShopChair_01_1k.gltf")
			paths.append("res://models/asylum/metal_office_desk/metal_office_desk_1k.gltf")
		6:
			paths.append_array([LOCKERS_PATH, GYM_LOCKER_PATH, SCH_CLEANING_CART_PATH])
			paths.append_array([SCH_DESK_PATH, SCH_CHEMISTRY_TABLE_PATH, CHEMISTRY_GLASSWARE_PATH])
			paths.append_array([SCH_TOILET_PATH, SCH_SINK_PATH, SCH_URINAL_PATH])
			paths.append_array([SCH_FOUNTAIN_PATH])
			paths.append("res://models/cc0/stationery_supplies/stationery_supplies_1k.gltf")
			paths.append("res://models/asylum/SchoolChair_01/SchoolChair_01_1k.gltf")
			paths.append("res://models/asylum/metal_office_desk/metal_office_desk_1k.gltf")
		7:
			paths.append_array([MALL_PAYPHONE_PATH, MALL_DIRECTORY_PATH, MALL_SHOPPING_CART_PATH])
			paths.append_array([CITY_BENCH_PATH, FOOD_COURT_SET_PATH, MALL_HOTDOG_PATH])
			paths.append_array([ROPE_BARRIER_PATH])
			paths.append("res://models/cc0/WetFloorSign_01/WetFloorSign_01_1k.gltf")
			paths.append("res://models/cc0/potted_plant_02/potted_plant_02_1k.gltf")
			paths.append("res://models/cc0/wooden_crate_01/wooden_crate_01_1k.gltf")
			paths.append("res://models/cc0/sofa_03/sofa_03_1k.gltf")
			paths.append("res://models/cc0/bar_chair_round_01/bar_chair_round_01_1k.gltf")
			paths.append("res://models/cc0/CoffeeCart_01/CoffeeCart_01_1k.gltf")
			paths.append("res://models/cc0/steel_frame_shelves_01/steel_frame_shelves_01_1k.gltf")
			paths.append("res://models/cc0/plastic_crate_03/plastic_crate_03_1k.gltf")
			paths.append("res://models/cc0/trashbag/trashbag_1k.gltf")
		8:
			paths.append_array([PRISON_DOOR_OLD_PATH, PRISON_BUNK_PATH, PRISON_TOILET_PATH])
			paths.append_array([PRISON_WALL_PHONE_PATH, DESK_PHONE_PATH])
			paths.append("res://models/cc0/book_encyclopedia_set_01/book_encyclopedia_set_01_1k.gltf")
			paths.append("res://models/cc0/can_rusted/can_rusted_1k.gltf")
			paths.append("res://models/cc0/wooden_crate_02/wooden_crate_02_1k.gltf")
			paths.append("res://models/cc0/WetFloorSign_01/WetFloorSign_01_1k.gltf")
			paths.append("res://models/cc0/office_notepads/office_notepads_1k.gltf")
			paths.append("res://models/cc0/steel_frame_shelves_01/steel_frame_shelves_01_1k.gltf")
			paths.append("res://models/cc0/hanging_industrial_lamp/hanging_industrial_lamp_1k.gltf")
			paths.append("res://models/cc0/old_tyre/old_tyre_1k.gltf")
			paths.append("res://models/asylum/metal_office_desk/metal_office_desk_1k.gltf")
		9:
			paths.append_array([POOL_BUOY_PATH, POOL_LADDER_PATH, POOL_CHAIR_PATH])
			paths.append_array([POOL_LOUNGE_CHAIR_PATH, POOL_JACUZZI_PATH, POOL_LIGHT_PATH])
		10:
			paths.append_array([DATA_CENTER_CONSOLE_PATH, DATA_CENTER_RACK_BANK_PATH, DATA_CENTER_RACK_PATH])
			paths.append_array([DATA_CENTER_NETWORK_RACK_PATH, DATA_CENTER_DETAILED_RACK_PATH, DATA_CENTER_GLASS_SERVER_PATH])
			paths.append_array([DATA_CENTER_AZURE_SERVER_PATH, BRUTAL_LIGHT_PATH, BLOOM_VINES_PATH])
			paths.append_array([ANNEX_EXIT_DOOR_PATH])
			paths.append_array(DATA_CENTER_AC_PATHS)
		11:
			paths.append_array([BLOOM_ROOT_PATH, BLOOM_VINES_PATH, BLOOM_FLESH_BLOB_PATH])
			paths.append_array([BRUTAL_LIGHT_PATH, ANNEX_EXIT_DOOR_PATH, LOCKERS_PATH])
			paths.append_array([SCH_DESK_PATH, SCH_CHEMISTRY_TABLE_PATH])
	if p_theme != 7:
		paths.append(ALARM_PATH)
	return paths


## Headless tools exit soon after sampling and may not naturally encounter
## every requested prop. Consuming completed requests avoids reporting those
## intentionally preloaded resources as leaked audit objects.
static func finish_prop_preloads() -> void:
	if not _prop_preloads_requested:
		return
	for path in _prop_preload_paths():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
				or status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)


## Compile/instantiate each heavy theme's construction families once while the
## transition is already fully black. Streaming then only duplicates cached
## resources and never discovers a new imported prop or shader in view.
static func prewarm_theme_content(ws: int, p_theme: int) -> void:
	if _prewarmed_themes.has(p_theme) or p_theme not in [2, 11]:
		return
	_prewarmed_themes[p_theme] = true
	var wanted: Array[int] = []
	if p_theme == 2:
		wanted.assign([
			WorldGen.ANNEX_OPEN, WorldGen.ANNEX_MAZE, WorldGen.ANNEX_LONG,
			WorldGen.ANNEX_QUIET, WorldGen.ANNEX_PASSAGE, WorldGen.ANNEX_LOBBY,
		])
	else:
		wanted.assign([
			WorldGen.BLOOM_PASSAGE, WorldGen.BLOOM_COMMONS,
			WorldGen.BLOOM_CLASSROOM, WorldGen.BLOOM_INCUBATOR,
			WorldGen.BLOOM_NEST, WorldGen.BLOOM_ATRIUM, WorldGen.BLOOM_GYM,
		])
	var found := {}
	for ring in range(0, 25):
		if found.size() >= wanted.size():
			break
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if ring > 0 and absi(x) != ring and absi(y) != ring:
					continue
				var at := Vector2i(x, y)
				var candidate_style := WorldGen.cell_style(ws, at, p_theme)
				if not wanted.has(candidate_style) or found.has(candidate_style):
					continue
				var root := WorldGen.annex_room_id(ws, at) if p_theme == 2 \
					else WorldGen.room_id(ws, at)
				if root != at and candidate_style not in [
						WorldGen.ANNEX_PASSAGE, WorldGen.BLOOM_PASSAGE]:
					continue
				var warm := Chunk.new(ws, at, p_theme)
				warm.free()
				found[candidate_style] = true


## Audit/test teardown for process-lifetime scene/prototype caches.
static func clear_runtime_caches() -> void:
	finish_prop_preloads()
	FloorResourcePreloader.finish()
	_prop_preloads_requested = false
	_slot_scene = null
	_attributed_scenes.clear()
	_scrawl_fonts.clear()
	_asy_scenes.clear()
	_cc0_scenes.clear()
	_prewarmed_themes.clear()
	BLOOM_LEVEL_BUILDER.clear_runtime_cache()
	ANNEX_LEVEL_BUILDER.clear_runtime_cache()
	MALL_LEVEL_BUILDER.clear_runtime_cache()
	BRUTALIST_LEVEL_BUILDER.clear_runtime_cache()
	POOL_LEVEL_BUILDER.clear_runtime_cache()


## Named process-lifetime asset cache APIs used by the construction façade.
## Builders never receive the mutable dictionaries or PackedScene slots.
static func cached_slot_machine_scene() -> PackedScene:
	if _slot_scene == null:
		_slot_scene = _prop_scene(SLOT_MACHINE_PATH)
	return _slot_scene


static func cached_asylum_scene(key: String, path: String) -> PackedScene:
	var cached: PackedScene = _asy_scenes.get(key)
	if cached == null:
		cached = _prop_scene(path)
		_asy_scenes[key] = cached
	return cached


static func cached_scrawl_font(which: int) -> FontFile:
	return _scrawl_font(which)


var _build_stage := 0
var _build_blackout := false
var _build_started_usec := 0
var _occluder_walls: Array[MeshInstance3D] = []
var _rendering_prepared := false


func _init(p_seed: int, p_cell: Vector2i, p_theme := 0,
		p_config: Variant = null, deferred_build := false) -> void:
	_build_started_usec = Time.get_ticks_usec()
	var spec: ChunkBuildSpec
	if p_config is ChunkBuildSpec:
		spec = p_config
	else:
		spec = ChunkBuildSpec.from_dictionary(
			p_config as Dictionary if p_config is Dictionary else {})
	if not _cone_ready:
		_cone_ready = true
		CONE.top_radius = 0.0
		CONE.bottom_radius = 0.5
		CONE.height = 1.0
	wseed = p_seed
	cell = p_cell
	theme = p_theme
	descent = spec.descent
	descent_topology = spec.topology
	descent_topology_state_override = spec.topology_state_override
	descent_target = spec.target
	descent_target_wall = spec.target_wall
	descent_final = spec.final
	descent_floor_idx = spec.floor_idx
	descent_arrival = spec.arrival
	descent_arrival_wall = spec.arrival_wall
	descent_arrival_used = spec.arrival_used
	descent_lift_called = spec.lift_called
	descent_lift_wait = spec.lift_wait
	descent_lift_open = spec.lift_open
	descent_tape_watched = spec.tape_watched
	descent_base_seed = spec.base_seed
	optional_vhs = spec.optional_vhs
	optional_vhs_key = spec.optional_vhs_key
	descent_broken_station = spec.broken_station
	descent_broken_station_tried = spec.broken_station_tried
	bleed_amount = spec.bleed
	bleed_theme = spec.bleed_theme
	anomaly_kind = spec.anomaly
	# The waiting-figure anomaly is a live figure, and a live figure is useless
	# without the player it is hunting. It has to arrive with the config: the
	# figure is built during construction, and its own _ready — which sizes the
	# capsule it moves with — runs before anything outside could set this.
	anomaly_player = spec.player
	_build_blackout = spec.blackout
	body = StaticBody3D.new()
	add_child(body)
	style = WorldGen.cell_style(wseed, cell, theme)
	# The Annex has its own room/corridor graph rather than inheriting the
	# Vegas-era graph shared by the older floors.
	room_root = WorldGen.annex_room_id(wseed, cell) if theme == 2 \
		else WorldGen.room_id(wseed, cell)
	room_n = WorldGen.annex_room_size(wseed, room_root) if theme == 2 \
		else WorldGen.room_size(wseed, room_root)
	is_room_anchor = room_root == cell
	# Off-tree blackout replacements may request a future complete state while
	# the installed resolver still owns the current one.
	if spec.furniture_variant_override >= 0:
		mutation_furniture_variant = spec.furniture_variant_override
	elif descent_topology != null:
		mutation_furniture_variant = descent_topology.furniture_variant_for_state(
			room_root, descent_topology_state_override) \
			if descent_topology_state_override >= 0 else \
			descent_topology.furniture_variant(room_root)
	# Props use the ceiling datum for tall-room layouts and mounted-vs-floor
	# decisions.
	ceil_h = cell_ceil_h(wseed, cell, theme)
	_build_context = ChunkBuildContext.new(wseed, cell, theme, style, ceil_h,
		room_root, room_n, is_room_anchor, mutation_furniture_variant, spec)
	_scene_writer = ChunkSceneWriter.new(self, body)
	_level_builder = LEVEL_BUILDERS.get(theme, BASE_LEVEL_BUILDER).new(
		_build_context, _scene_writer)
	if not deferred_build:
		while not build_next_stage():
			pass


## Off-tree streaming can stop between authored stages. Direct constructors
## still finish synchronously, retaining the established tool/build contract.
func build_next_stage() -> bool:
	var started := Time.get_ticks_usec()
	match _build_stage:
		0:
			_build_floor_ceiling()
			_profile_stage("floor_ceiling", started)
		1:
			_build_walls()
			_profile_stage("walls", started)
		2:
			if theme == 2:
				_build_props()
				if not is_room_anchor:
					_level_builder._annex_room_member_architecture()
			else:
				_build_lighting()
			_profile_stage("props" if theme == 2 else "lighting", started)
		3:
			if theme == 2:
				_build_lighting()
			else:
				_build_props()
			_profile_stage("lighting" if theme == 2 else "props", started)
		4:
			_build_optional_vhs_set()
			_build_charging_station()
			_build_bleed_dressing()
			_build_interactions()
			_profile_stage("gameplay", started)
		5:
			if mutation_furniture_variant > 0:
				_apply_furniture_variant(mutation_furniture_variant)
				_profile_stage("furniture_mutation", started)
		6:
			SurfaceWear.apply(self, _build_context)
			_profile_stage("surface_wear", started)
		7:
			if anomaly_kind >= 0:
				activate_anomaly(anomaly_kind)
			if _build_blackout:
				set_blackout(true)
			_maybe_probe()
			_profile_stage("TOTAL", _build_started_usec)
	_build_stage = mini(_build_stage + 1, 8)
	return _build_stage == 8


## The allowlist is intentionally conservative: other enclosed floors are
## measurable with the same diagnostic, but culling can cost more CPU there.
static var occlusion_themes: Array[int] = [10]


## Only explicitly authored opaque walls can occlude. Store references until
## gameplay cutouts have finished; removed car/door geometry must not leave an
## invisible occluder behind. Parenting to the surviving wall keeps lifetime,
## visibility and transforms coupled during streaming and reality changes.
func record_occluder_wall(mesh: MeshInstance3D) -> void:
	if theme in occlusion_themes and mesh.mesh is BoxMesh:
		_occluder_walls.append(mesh)


func prepare_runtime_rendering() -> void:
	if _rendering_prepared:
		return
	_rendering_prepared = true
	for mesh in _occluder_walls:
		if not is_instance_valid(mesh) or mesh.get_parent() == null:
			continue
		var occluder := OccluderInstance3D.new()
		occluder.name = "StructuralOccluder"
		var box := BoxOccluder3D.new()
		box.size = mesh.mesh.get_aabb().size * 0.998
		occluder.occluder = box
		mesh.add_child(occluder)
	_occluder_walls.clear()


func _profile_stage(label: String, started_usec: int) -> void:
	if not profile_build_stages:
		return
	var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	if label != "TOTAL" and elapsed_ms < profile_stage_threshold_ms:
		return
	print("CHUNK_STAGE theme=%d style=%d cell=%s %s=%.3fms" % [
		theme, style, cell, label, elapsed_ms])


## One station per 3x3 macro-cell, on a fixed lattice rather than a random
## roll. A player is therefore normally within roughly 25m as the crow flies
## and no unlucky seed can produce a charger desert.
func _build_charging_station() -> void:
	if descent_arrival:
		return
	if descent_target:
		# The objective room is the ritual room: it always carries its own
		# station, on the media wall, whatever the macro-cell lattice says.
		if not descent_final:
			_build_descent_target_station()
		return
	if not _is_charging_station_cell():
		return
	var candidates: Array[Vector3] = []
	# Try the perimeter and then the interior. Twenty-five deterministic sites
	# keep a dense authored room from silently deleting its macro-cell station.
	for x in [2.0, 4.0, 6.0, 8.0, 10.0]:
		for z in [2.0, 4.0, 6.0, 8.0, 10.0]:
			candidates.append(Vector3(x, _floor_h(), z))
	var start := posmod(WorldGen.h(wseed, cell.x, cell.y, 8801), candidates.size())
	for i in candidates.size():
		var at: Vector3 = candidates[(start + i) % candidates.size()]
		if not _floor_spot_clear(at, 0.52, 1.8):
			continue
		var station := CHARGING_STATION_SCRIPT.new() as Node3D
		station.position = at
		station.rotation.y = float((start + i) % 4) * PI * 0.5
		# Config-driven so the tree-less audits and streamed rebuilds agree:
		# the run's one dead unit is dead from construction, and stays sprung.
		# set() because the station variable is typed as its Node3D base.
		station.set("broken", descent_broken_station)
		station.set("broken_tried", descent_broken_station_tried)
		station.set_meta("charging_station", true)
		station.set_meta("station_cell", cell)
		add_child(station)
		return


## What each theme leaves behind when it starts leaking upward: one signature
## object, placed with the same authored-centre convention as its home floor.
## `size` is the approximate collider footprint; zero means walk-through.
const BLEED_PROPS := {
	0: [SLOT_ALT_PATH, SLOT_ALT_SCALE, SLOT_ALT_CENTRE, Vector3(0.6, 1.8, 0.6)],
	1: [OFFICE_WATER_COOLER_PATH, OFFICE_WATER_COOLER_SCALE,
		OFFICE_WATER_COOLER_CENTRE, Vector3(0.42, 1.3, 0.42)],
	2: [ANNEX_CHAIR_PATH, ANNEX_CHAIR_SCALE, ANNEX_CHAIR_CENTRE,
		Vector3(0.55, 0.9, 0.55)],
	4: [AIRPORT_LUGGAGE_PATH, AIRPORT_LUGGAGE_SCALE, Vector3.ZERO,
		Vector3.ZERO],
	5: [ASY_BED_PATH, ASY_BED_SCALE, ASY_BED_CENTRE, Vector3(1.0, 0.9, 2.0)],
	6: [GYM_LOCKER_PATH, GYM_LOCKER_SCALE, GYM_LOCKER_CENTRE,
		Vector3(0.5, 1.9, 0.5)],
	7: [MALL_SHOPPING_CART_PATH, MALL_SHOPPING_CART_SCALE,
		MALL_SHOPPING_CART_CENTRE, Vector3(0.6, 1.0, 1.0)],
	9: [POOL_LOUNGE_CHAIR_PATH, POOL_LOUNGE_CHAIR_SCALE,
		POOL_LOUNGE_CHAIR_CENTRE, Vector3(0.7, 0.8, 1.7)],
}


## Environmental bleed, at build time. As the run's ratchet rises, freshly
## built or rebuilt cells of this floor carry objects that belong to the next
## one — quietly wrong furniture first, and near the lift an unmistakable
## intrusion. Streaming does the propagation for free: cells behind the player
## rebuild bled, cells ahead were built cleaner.
func _build_bleed_dressing() -> void:
	if not descent or descent_target or descent_arrival:
		return
	if bleed_amount < 0.05 or bleed_theme < 0:
		return
	if WorldGen.r01(wseed, cell.x, cell.y, 6101) > bleed_amount * 0.55:
		return
	# One unmistakable foreign object is enough to sell the transition. Two per
	# streamed cell multiplied geometry and SDFGI invalidation precisely where
	# the objective room, lift and tape set enter the retained neighbourhood.
	var count := 1
	var start := posmod(WorldGen.h(wseed, cell.x, cell.y, 6105), 25)
	var placed := 0
	for i in 25:
		if placed >= count:
			return
		var lattice := (start + i) % 25
		var at := Vector3(2.0 + float(lattice % 5) * 2.0, _floor_h(),
			2.0 + float(lattice / 5) * 2.0)
		if not _floor_spot_clear(at, 0.55, 1.9):
			continue
		var yaw := float(posmod(WorldGen.h(wseed, cell.x, cell.y,
			6107 + placed), 8)) * PI * 0.25
		_place_bleed_prop(at, yaw)
		placed += 1


func _place_bleed_prop(at: Vector3, yaw: float) -> void:
	if BLEED_PROPS.has(bleed_theme):
		var entry: Array = BLEED_PROPS[bleed_theme]
		var centre: Vector3 = entry[2]
		if bleed_theme == 4:
			centre = AIRPORT_LUGGAGE_CENTRES[0]
		var prop := _attributed_floor_prop(entry[0], at, yaw,
			float(entry[1]), centre, "bleed_prop")
		if prop == null:
			return
		prop.set_meta("bleed_prop", true)
		var footprint: Vector3 = entry[3]
		if footprint != Vector3.ZERO:
			_collider_yaw_box(at + Vector3(0, footprint.y * 0.5, 0),
				footprint, yaw)
		_disable_streamed_gi(prop)
		return
	# Themes without a portable authored prop intrude as raw matter instead.
	var intrusion := Node3D.new()
	intrusion.position = at
	intrusion.rotation.y = yaw
	intrusion.set_meta("bleed_prop", true)
	add_child(intrusion)
	if bleed_theme == 10:
		# A concrete pier that belongs to the Data Center, run floor to ceiling.
		var h := ceil_h - _floor_h()
		_mbox(intrusion, Vector3(0, h * 0.5, 0), Vector3(0.82, h, 0.82),
			Mats.brutal_structure())
		_collider_yaw_box(at + Vector3(0, h * 0.5, 0),
			Vector3(0.82, h, 0.82), yaw)
	else:
		# The Upside Down arrives as flesh: a low dark growth, warm to look
		# at and wrong in every theme it appears in.
		var blob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 0.62
		blob.mesh = sphere
		var flesh := StandardMaterial3D.new()
		flesh.albedo_color = Color(0.20, 0.05, 0.06)
		flesh.roughness = 0.55
		blob.material_override = flesh
		blob.position = Vector3(0, 0.18, 0)
		blob.scale = Vector3(1.4, 0.55, 1.15)
		intrusion.add_child(blob)
	_disable_streamed_gi(intrusion)


## Bleed dressing is late, transient set decoration. Excluding it from SDFGI
## prevents every newly streamed prop from invalidating the four-cascade GI
## field near the objective; the floor's authored structure still supplies all
## bounced light and occlusion.
func _disable_streamed_gi(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).gi_mode = \
			GeometryInstance3D.GI_MODE_DISABLED
	for child in node.get_children():
		_disable_streamed_gi(child)


## The car is an authored island built AFTER the theme's own dressing, which
## cannot know about it — so a change machine or a shelf can end up standing
## inside the shell. Sweep the car's footprint clean first: dressing pivots
## and their colliders go, structure (the body's wall/floor slabs, lights,
## the ritual, the station) stays.
func _descent_clear_car_footprint(dir: int) -> void:
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var plane := (S - T / 2.0) if dir == 0 or dir == 2 else (T / 2.0)
	var face := plane + n * (T / 2.0)
	var near_face := face + n * 0.15
	var far_face := face + n * 3.6
	var lo: Vector2
	var hi: Vector2
	if dir < 2:
		lo = Vector2(minf(near_face, far_face), S / 2.0 - 2.4)
		hi = Vector2(maxf(near_face, far_face), S / 2.0 + 2.4)
	else:
		lo = Vector2(S / 2.0 - 2.4, minf(near_face, far_face))
		hi = Vector2(S / 2.0 + 2.4, maxf(near_face, far_face))
	for child in get_children():
		var node := child as Node3D
		if node == null or node == body or node is Light3D \
				or node is GPUParticles3D \
				or node.has_meta("descent_ritual") \
				or node.has_meta("charging_station"):
			continue
		if node.position.x >= lo.x and node.position.x <= hi.x \
				and node.position.z >= lo.y and node.position.z <= hi.y:
			remove_child(node)
			node.free()
	for collider in body.get_children():
		var shape := collider as Node3D
		if shape == null or shape.position.y < 0.05 or shape.position.y > 2.5:
			continue
		if shape.position.x >= lo.x and shape.position.x <= hi.x \
				and shape.position.z >= lo.y and shape.position.z <= hi.y:
			body.remove_child(shape)
			shape.free()


## The ritual wall: the first solid edge that is not the lift's own wall,
## walked clockwise from it. Deterministic, so the station pass and the
## interaction pass agree without talking to each other.
func _descent_ritual_wall() -> int:
	for step in 3:
		var dir := (descent_target_wall + 1 + step) % 4
		if bool(_edge_info(cell, dir)["wall"]):
			return dir
	return (descent_target_wall + 2) % 4


## Where along the ritual wall a piece stands, in local coordinates, with the
## same facing convention as the interactive elevator facade.
func _descent_wall_point(dir: int, along: float, out: float) -> Dictionary:
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var plane := (S - T / 2.0) if dir == 0 or dir == 2 else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	if dir < 2:
		return {
			"pos": Vector3(inner + n * out, _floor_h(), along),
			"yaw": -PI / 2.0 if dir == 0 else PI / 2.0,
		}
	return {
		"pos": Vector3(along, _floor_h(), inner + n * out),
		"yaw": PI if dir == 2 else 0.0,
	}


func _build_descent_target_station() -> void:
	var dir := _descent_ritual_wall()
	var spot := _descent_wall_point(dir, S / 2.0 - 2.4, 0.42)
	var at: Vector3 = spot["pos"]
	if not _floor_spot_clear(at, 0.52, 1.8):
		# The authored room got in the way; fall back to the ordinary lattice
		# scan so the ritual room can never be left without power.
		for x in [2.0, 4.0, 6.0, 8.0, 10.0]:
			for z in [2.0, 4.0, 6.0, 8.0, 10.0]:
				var candidate := Vector3(x, _floor_h(), z)
				if _floor_spot_clear(candidate, 0.52, 1.8):
					at = candidate
					break
	var station := CHARGING_STATION_SCRIPT.new() as Node3D
	station.position = at
	station.rotation.y = float(spot["yaw"])
	station.set_meta("charging_station", true)
	station.set_meta("station_cell", cell)
	add_child(station)


## The media altar itself: table, CRT, VCR, on the ritual wall.
func _descent_ritual_set() -> void:
	var dir := _descent_ritual_wall()
	var spot := _descent_wall_point(dir, S / 2.0 + 1.6, 0.34)
	var ritual := VHS_RITUAL_SCRIPT.new() as Node3D
	ritual.name = "DescentRitual"
	ritual.world_seed = descent_base_seed
	ritual.floor_idx = descent_floor_idx
	ritual.home_cell = cell
	ritual.setup_key = "floor:%d:objective" % descent_floor_idx
	ritual.objective = true
	ritual.already_watched = descent_tape_watched
	ritual.position = spot["pos"]
	ritual.rotation.y = float(spot["yaw"])
	add_child(ritual)


## The mandatory tutorial console: floor 1's arrival room only, standing in
## the exit path a few metres out from the car, screen toward the opening
## doors. It plays the pinned camera-tutorial tape (never the authored
## pools) and VhsRitual's intro mode makes it seize the player on approach.
## Site search walks outward/lateral offsets so authored dressing can shift
## it but never delete it; the doorway veto keeps the collider honest.
const INTRO_TAPE_PATH := "res://videos/intro/photo_tutorial.ogv"


func _descent_intro_tv(dir: int) -> void:
	var spot := {}
	for offsets in [[4.2, 0.0], [4.2, 1.4], [4.2, -1.4], [3.4, 0.0],
			[5.2, 0.0], [4.2, 2.4], [4.2, -2.4], [5.2, 1.6], [5.2, -1.6]]:
		var candidate := _descent_wall_point(dir,
			S / 2.0 + float(offsets[1]), float(offsets[0]))
		var at: Vector3 = candidate["pos"]
		var yaw := float(candidate["yaw"]) + PI
		if not _vhs_site_clear(at, yaw):
			continue
		if _optional_vhs_hits_doorway(at, yaw):
			continue
		spot = {"at": at, "yaw": yaw}
		break
	if spot.is_empty():
		# Authored dressing claimed every stance; stand it dead ahead anyway.
		# A mandatory tutorial that silently fails to build is worse than a
		# prop overlap in one seed's arrival room.
		var fallback := _descent_wall_point(dir, S / 2.0, 4.2)
		spot = {"at": fallback["pos"], "yaw": float(fallback["yaw"]) + PI}
	var tv := VHS_RITUAL_SCRIPT.new() as Node3D
	tv.name = "DescentIntroTv"
	tv.world_seed = descent_base_seed
	tv.floor_idx = descent_floor_idx
	tv.home_cell = cell
	tv.setup_key = "floor:0:intro"
	tv.objective = false
	tv.intro = true
	tv.pinned_tape = INTRO_TAPE_PATH
	tv.position = spot["at"]
	tv.rotation.y = float(spot["yaw"])
	add_child(tv)


## Rare optional playback altar. Route selection happens in DescentRoute and
## endless density in ChunkManager; this chunk only finds a physically honest
## wall site that does not overlap furniture or a doorway approach.
func _build_optional_vhs_set() -> void:
	if not descent or not optional_vhs or optional_vhs_key.is_empty() \
			or descent_target or descent_arrival \
			or not is_room_anchor:
		return
	var site := _pick_vhs_site()
	if site.is_empty():
		return
	var set := VHS_RITUAL_SCRIPT.new() as Node3D
	set.name = "OptionalVhs"
	set.world_seed = descent_base_seed
	set.floor_idx = descent_floor_idx
	set.home_cell = cell
	set.setup_key = optional_vhs_key
	set.objective = false
	set.position = site["at"]
	set.rotation.y = float(site["yaw"])
	set.set_meta("optional_vhs", true)
	set.set_meta("optional_vhs_key", optional_vhs_key)
	add_child(set)


## Deterministic optional-set search: perimeter wall sites first, then a
## freestanding interior lattice, plus the Poolrooms' dry-island sampling.
func _pick_vhs_site() -> Dictionary:
	var sites: Array[Dictionary] = []
	# Dense authored rooms can occupy the old six sample points even while a
	# perfectly sound wall site exists between them. Sample each metre so a
	# route-selected recording cannot silently disappear.
	var alongs := [1.0, 2.0, 3.0, 4.0, 5.0, 6.0,
		7.0, 8.0, 9.0, 10.0, 11.0]
	for dir in 4:
		if not _edge_info(cell, dir)["wall"]:
			continue
		for along in alongs:
			sites.append({
				"at": _wall_pt(dir, float(along), 0.34, _floor_h()),
				"yaw": _wall_facing(dir),
			})
	# Dense authored rooms sometimes occupy every perimeter site. A freestanding
	# set deeper in the room is still legible—the table, screen glow and hiss do
	# the work—and prevents a selected route encounter from silently vanishing.
	for z in [1.25, 2.5, 3.75, 5.0, 6.25, 7.5, 8.75, 10.0, 10.75]:
		for x in [1.25, 2.5, 3.75, 5.0, 6.25, 7.5, 8.75, 10.0, 10.75]:
			var yaw_step := posmod(WorldGen.h(wseed, cell.x + int(x),
				cell.y + int(z), 7393), 4)
			sites.append({
				"at": Vector3(x, _floor_h(), z),
				"yaw": float(yaw_step) * PI * 0.5,
			})
	if theme == 9:
		# Pool architecture is laid out as irregular dry islands rather than a
		# conventional empty rectangle. Sample the same continuous interior its
		# own lounge furniture uses instead of trusting only a square lattice.
		for i in 64:
			sites.append({
				"at": Vector3(
					1.5 + 9.0 * _r(7411 + i * 2), _floor_h(),
					1.5 + 9.0 * _r(7412 + i * 2)),
				"yaw": float(posmod(WorldGen.h(wseed, cell.x, cell.y,
					7421 + i), 4)) * PI * 0.5,
			})
	var start := posmod(WorldGen.h(wseed, cell.x, cell.y, 7391),
		sites.size())
	var footprint_fallback := {}
	for i in sites.size():
		var site: Dictionary = sites[(start + i) % sites.size()]
		var yaw := float(site["yaw"])
		var at: Vector3 = site["at"]
		var footprint_clear := _floor_spot_clear(at, 1.05, 1.2) \
			if theme == 9 else _floor_box_clear(at, yaw, 1.95, 0.82, 1.2)
		if not footprint_clear:
			continue
		if _optional_vhs_hits_doorway(at, yaw):
			continue
		if _vhs_watch_path_clear(at, yaw):
			return site
		if footprint_fallback.is_empty():
			footprint_fallback = site
	# The private watch layer prevents a neighbouring prop from entering the
	# close-up. Retain a furniture-safe set when a dense authored room cannot
	# also provide the ideal camera corridor.
	return footprint_fallback


## The table footprint alone is not enough: playback puts a camera about half
## a metre in front of the glass. Reserve that complete short view corridor so
## dividers, desks and columns cannot occupy the eventual close-up.
func _vhs_site_clear(at: Vector3, yaw: float) -> bool:
	return _floor_box_clear(at, yaw, 1.95, 0.82, 1.2) \
		and _vhs_watch_path_clear(at, yaw)


func _vhs_watch_path_clear(at: Vector3, yaw: float) -> bool:
	var local_centre := Vector3(-0.35, 0.0, 0.80)
	var world_centre := at + local_centre.rotated(Vector3.UP, yaw)
	return _floor_box_clear(world_centre, yaw, 1.10, 1.10, 1.65)


func _optional_vhs_hits_doorway(at: Vector3, yaw: float) -> bool:
	var candidate := plan_box(at, yaw, 1.95, 0.82, 1.2)
	for zone in _doorway_clearance_rects():
		var centre := zone.position + zone.size * 0.5
		var doorway := plan_box(Vector3(centre.x, at.y, centre.y), 0.0,
			zone.size.x, zone.size.y, 1.2)
		if plan_box_overlap(candidate, doorway) > 0.0:
			return true
	return false


func _is_charging_station_cell() -> bool:
	if theme != 9:
		return posmod(cell.x, 3) == 1 and posmod(cell.y, 3) == 1
	# Pool stations must be on a raised dry deck, never at the bottom of a
	# basin. Pick exactly one dry cell in each macro-cell by stable hash.
	var origin := Vector2i(floori(float(cell.x) / 3.0) * 3,
		floori(float(cell.y) / 3.0) * 3)
	var chosen := Vector2i(1 << 20, 1 << 20)
	var best := 0x7fffffff
	for x in 3:
		for y in 3:
			var candidate := origin + Vector2i(x, y)
			if not pool_style_dry(WorldGen.cell_style(wseed, candidate, theme)):
				continue
			var score := WorldGen.h(wseed, candidate.x, candidate.y, 8802) & 0x7fffffff
			if score < best:
				best = score
				chosen = candidate
	return cell == chosen


## Real reflections for the rooms with mirror-like surfaces (marble, gold,
## glass). One static box-projected probe, rendered once at chunk build.
func _maybe_probe() -> void:
	# One probe covers a generated room. Multi-cell rooms used to create one in
	# every member chunk, rendering the same surrounding geometry four times.
	if not is_room_anchor:
		# Annex member-cell architecture is built before its lighting, above,
		# so fixtures can reserve an unobstructed ceiling tile.
		return
	var want := false
	if theme == 0:
		want = style == WorldGen.STYLE_GRAND or style == WorldGen.STYLE_SLOTS \
			or style == WorldGen.STYLE_BALLROOM
	elif theme == 4:
		want = style == WorldGen.AIR_GATE or style == WorldGen.AIR_FOODCOURT
	elif theme == 6:
		# The polished hall floor benefits from local cubemaps, but one in every
		# corridor cell recaptured almost the same scene. Alternate cells keep
		# the long reflection read at half the startup/rendering cost.
		want = style == WorldGen.SCH_CORRIDOR \
			and WorldGen.h(wseed, cell.x, cell.y, 1499) % 2 == 0
	elif theme == 7:
		want = style == WorldGen.MALL_ATRIUM or style == WorldGen.MALL_CORRIDOR
	if not want:
		return
	var probe := ReflectionProbe.new()
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	# Reflections must only know the world the eye knows: with the default
	# mask, polished floors reflected lens-only anomalies and camera-only
	# writing (owner report, 2026-08-20).
	probe.cull_mask &= ~(PhotoAnomaly.PHOTO_LAYER | PhotoAnomaly.PRINT_LAYER)
	var span := _room_span()
	var rc := WorldGen.room_centre(wseed, room_root)
	var local_c := Vector3(rc.x - float(cell.x) * S, ceil_h / 2.0,
		rc.y - float(cell.y) * S)
	probe.size = Vector3(span.x, ceil_h + 0.6, span.y)
	probe.position = local_c
	probe.box_projection = true
	probe.interior = true
	probe.max_distance = 24.0
	add_child(probe)


func _r(salt: int) -> float:
	return WorldGen.r01(wseed, cell.x, cell.y, salt)


## A 72m maintenance district shares one finish palette. This gives long walks
## coherent eras of repainting and refitting instead of recoloring every room.
func _finish_variant() -> int:
	return WorldGen.finish_variant(wseed, cell, theme)


func _wall_h() -> float:
	return ceil_h


## The ceiling height any cell builds with, corridor override included. Static
## because the fascia over a fully open edge must predict the NEIGHBOUR's
## exact height, and the seam audit wants the same answer without building a
## chunk. This is the one place the rule lives.
static func cell_ceil_h(ws: int, c: Vector2i, p_theme: int) -> float:
	if p_theme == 2:
		return HANNEX
	if WorldGen.corridor(ws, c) != 0:
		return 3.5 if p_theme == 4 else (HASY if p_theme == 5 else \
			(HSCH if p_theme == 6 else (HMALL if p_theme == 7 else \
			(HPRISON if p_theme == 8 else (HPOOL if p_theme == 9 else \
			(HBRUTAL if p_theme == 10 else (HBLOOM if p_theme == 11 else HOFF)))))))
	return WorldGen.room_height(ws, WorldGen.room_id(ws, c), p_theme)


## Shapes may kiss; they may not interpenetrate. Shared by the generator, which
## uses it to reject a piece before placing it, and by audit_prop_overlap.gd,
## which uses it to fail the build if one slipped through. One value, so a piece
## the generator accepts cannot be one the audit rejects.
const FURNISHING_OVERLAP_TOL := 0.12


## A yawed box in plan, with its vertical extent, for plan_box_overlap.
static func plan_box(p: Vector3, yaw: float, width: float, depth: float,
		height: float) -> Dictionary:
	return {
		"c": Vector2(p.x, p.z),
		"e": Vector2(width * 0.5, depth * 0.5),
		"yaw": yaw,
		"y0": p.y,
		"y1": p.y + height,
	}


## Separating-axis depth for two yawed boxes in plan, gated on their heights
## actually overlapping. Returns the smallest penetration across all four axes,
## which is 0 the moment any axis separates them.
static func plan_box_overlap(a: Dictionary, b: Dictionary) -> float:
	var dy := minf(float(a["y1"]), float(b["y1"])) \
		- maxf(float(a["y0"]), float(b["y0"]))
	if dy <= 0.0:
		return 0.0
	var axes := [
		Vector2(cos(a["yaw"]), -sin(a["yaw"])),
		Vector2(sin(a["yaw"]), cos(a["yaw"])),
		Vector2(cos(b["yaw"]), -sin(b["yaw"])),
		Vector2(sin(b["yaw"]), cos(b["yaw"])),
	]
	var least := INF
	for axis in axes:
		var d: Vector2 = b["c"] - a["c"]
		var gap: float = absf(d.dot(axis)) - _plan_project(a, axis) \
			- _plan_project(b, axis)
		if gap >= 0.0:
			return 0.0
		least = minf(least, -gap)
	return least


static func _plan_project(box: Dictionary, axis: Vector2) -> float:
	var ax := Vector2(cos(box["yaw"]), -sin(box["yaw"]))
	var az := Vector2(sin(box["yaw"]), cos(box["yaw"]))
	var e: Vector2 = box["e"]
	return absf(ax.dot(axis)) * e.x + absf(az.dot(axis)) * e.y


## The Y a cell's walkable surface sits at. Static for the same reason
## cell_ceil_h is: anything that plants something on "the floor" -- a portal, a
## lift, an arriving player -- needs this answer, and the callers outside
## generation cannot build a chunk to ask.
##
## Every floor is flat at zero except the Poolrooms, whose dry styles are a
## raised tile slab over the water line. Getting this wrong does not fail
## loudly: main.gd assumed zero and asked to place the player 1.27m inside that
## slab on every entry to floor 9, and Godot's depenetration quietly pushed them
## out again.
static func cell_floor_h(ws: int, c: Vector2i, p_theme: int) -> float:
	if p_theme == 9 and pool_style_dry(WorldGen.cell_style(ws, c, p_theme)):
		return POOL_DRY_Y
	return 0.0


# --- primitive helpers -------------------------------------------------------

func _box(pos: Vector3, size: Vector3, mat: Material, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BOX
	mi.material_override = mat
	mi.position = pos
	mi.scale = size
	add_child(mi)
	if collide:
		_collider_box(pos, size)
	return mi


## One native QuadMesh face of an Annex wall prism. QuadMesh keeps this on
## Godot's stable primitive rendering path; unlike the former hand-authored
## ArrayMesh, it has not produced intermittent black faces on Metal.
func _annex_wall_face(pos: Vector3, size: Vector2, basis: Basis,
		mat: Material, role: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = QUAD
	mi.material_override = mat
	mi.transform = Transform3D(basis, pos)
	mi.scale = Vector3(size.x, size.y, 1.0)
	mi.set_meta("annex_wall_face", role)
	add_child(mi)
	return mi


## A substantial Annex wall with native primitive faces and one solid box
## collider. Consecutive BoxMesh walls used to place two opposing end-cap
## faces on every 12m chunk boundary. Those coincident caps produced the dark
## or bright vertical ribs that changed with camera distance. Continuations
## now have no visual caps at all; genuine doorway/corner ends keep one cap.
func _annex_wall_prism(pos: Vector3, size: Vector3, along_x: bool,
		cap_min: bool, cap_max: bool, mat: Material,
		soffit_mat: Material = null,
		cap_mat: Material = null,
		face_mat_positive: Material = null,
		face_mat_negative: Material = null) -> MeshInstance3D:
	var half := size * 0.5
	# A soffit is the horizontal underside of a header or tunnel. Papered, it
	# puts wallpaper on a surface the player reads as ceiling, so callers can
	# hand it a plain material while the wall planes stay papered.
	var smat: Material = soffit_mat if soffit_mat != null else mat
	# An end cap can belong to a different treatment from the run itself,
	# because the wall on the far side of an opening may own the passage.
	var cmat: Material = cap_mat if cap_mat != null else mat
	# A header's two long faces lie IN the walls of the rooms either side, so
	# each can differ: the band above an opening belongs to the wall you are
	# looking at, not to the passage behind it.
	var fpos: Material = face_mat_positive if face_mat_positive != null else mat
	var fneg: Material = face_mat_negative if face_mat_negative != null else mat
	var primary: MeshInstance3D
	if along_x:
		primary = _annex_wall_face(
			pos + Vector3(0, 0, half.z), Vector2(size.x, size.y),
			Basis.IDENTITY, fpos, "side_positive")
		_annex_wall_face(
			pos - Vector3(0, 0, half.z), Vector2(size.x, size.y),
			Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1)),
			fneg, "side_negative")
		if cap_min:
			_annex_wall_face(
				pos - Vector3(half.x, 0, 0), Vector2(size.z, size.y),
				Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)),
				cmat, "cap_min")
		if cap_max:
			_annex_wall_face(
				pos + Vector3(half.x, 0, 0), Vector2(size.z, size.y),
				Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)),
				cmat, "cap_max")
	else:
		primary = _annex_wall_face(
			pos + Vector3(half.x, 0, 0), Vector2(size.z, size.y),
			Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)),
			fpos, "side_positive")
		_annex_wall_face(
			pos - Vector3(half.x, 0, 0), Vector2(size.z, size.y),
			Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)),
			fneg, "side_negative")
		if cap_min:
			_annex_wall_face(
				pos - Vector3(0, 0, half.z), Vector2(size.x, size.y),
				Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1)),
				cmat, "cap_min")
		if cap_max:
			_annex_wall_face(
				pos + Vector3(0, 0, half.z), Vector2(size.x, size.y),
				Basis.IDENTITY, cmat, "cap_max")
	# Header undersides and any intentionally short partitions remain closed.
	var bottom := pos.y - half.y
	if bottom > 0.01:
		var bottom_basis := Basis(
			Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1),
			Vector3(0, 0, 1) if along_x else Vector3(-1, 0, 0),
			Vector3(0, -1, 0))
		_annex_wall_face(
			Vector3(pos.x, bottom, pos.z),
			Vector2(size.x if along_x else size.z, size.z if along_x else size.x),
			bottom_basis, smat, "bottom")
	var top := pos.y + half.y
	if top < ceil_h - 0.01:
		var top_basis := Basis(
			Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1),
			Vector3(0, 0, -1) if along_x else Vector3(1, 0, 0),
			Vector3(0, 1, 0))
		_annex_wall_face(
			Vector3(pos.x, top, pos.z),
			Vector2(size.x if along_x else size.z, size.z if along_x else size.x),
			top_basis, mat, "top")
	_collider_box(pos, size)
	primary.set_meta("annex_uncapped_native_prism", true)
	primary.set_meta("annex_wall_along_x", along_x)
	primary.set_meta("annex_wall_cap_min", cap_min)
	primary.set_meta("annex_wall_cap_max", cap_max)
	# Audits and wall-mounted prop placement need the complete solid volume;
	# the primary render face itself is intentionally only a zero-depth quad.
	primary.set_meta("annex_wall_volume_position", pos)
	primary.set_meta("annex_wall_volume_size", size)
	return primary


## Is there room on the floor at `p` for something `radius` wide and `height`
## tall? Scatter props used to pick a random point in the cell and drop, which
## is how a suitcase ends up sitting inside a row of gate seating.
##
## A chunk builds its colliders before it is ever added to the tree, so there is
## no physics world to query yet. The registered shapes are all boxes and
## cylinders with known transforms, so the test is done directly against them —
## which is deterministic, and free of the frame ordering a physics query would
## depend on.
func _floor_spot_clear(p: Vector3, radius: float, height := 0.9) -> bool:
	var lo := p.y + 0.02
	var hi := p.y + height
	for child in body.get_children():
		var cs := child as CollisionShape3D
		if cs == null:
			continue
		var box := cs.shape as BoxShape3D
		var cyl := cs.shape as CylinderShape3D
		var c := cs.position
		var half_h := 0.0
		if box != null:
			half_h = box.size.y * 0.5
		elif cyl != null:
			half_h = cyl.height * 0.5
		else:
			continue
		# a collider overhead or buried underfoot is not in the way
		if c.y + half_h <= lo or c.y - half_h >= hi:
			continue
		if cyl != null:
			if Vector2(p.x - c.x, p.z - c.z).length() < cyl.radius + radius:
				return false
			continue
		# box, possibly yawed: measure in its own frame
		var d := Vector2(p.x - c.x, p.z - c.z)
		var yaw := cs.rotation.y
		if not is_zero_approx(yaw):
			d = d.rotated(yaw)
		var ex := box.size.x * 0.5
		var ez := box.size.z * 0.5
		var nearest := Vector2(clampf(d.x, -ex, ex), clampf(d.y, -ez, ez))
		if d.distance_to(nearest) < radius:
			return false
	return true


## Full-footprint counterpart to `_floor_spot_clear`. Long furniture cannot be
## represented by a small clearance circle: doing that let the middle of an
## Annex shelf clear a divider while the rack's far end passed through it.
func _floor_box_clear(p: Vector3, yaw: float, width: float, depth: float,
		height := 0.9) -> bool:
	var candidate := plan_box(p, yaw, width, depth, height)
	for child in body.get_children():
		var cs := child as CollisionShape3D
		if cs == null:
			continue
		var box := cs.shape as BoxShape3D
		var cyl := cs.shape as CylinderShape3D
		if box == null and cyl == null:
			continue
		var placed_width := box.size.x if box != null else cyl.radius * 2.0
		var placed_depth := box.size.z if box != null else cyl.radius * 2.0
		var placed_height := box.size.y if box != null else cyl.height
		var placed := plan_box(
			Vector3(cs.position.x, cs.position.y - placed_height * 0.5,
				cs.position.z),
			cs.rotation.y, placed_width, placed_depth, placed_height)
		if plan_box_overlap(candidate, placed) > FURNISHING_OVERLAP_TOL:
			return false
	return true


## Pick a floor point that is actually free. Returns Vector3.INF when the cell
## is too full, which the caller should treat as "no prop here" rather than
## forcing one in.
func _free_floor_spot(salt: int, radius: float, inset := 2.4,
		height := 0.9, tries := 10) -> Vector3:
	var span := S - inset * 2.0
	for i in tries:
		var p := Vector3(inset + span * _r(salt + i * 2),
			0, inset + span * _r(salt + i * 2 + 1))
		if _floor_spot_clear(p, radius, height):
			return p
	return Vector3.INF


func _collider_box(pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)


func _collider_cyl(pos: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)


func _cyl(pos: Vector3, radius: float, height: float, mat: Material, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CYL
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(radius / 0.5, height / 2.0, radius / 0.5)
	add_child(mi)
	if collide:
		_collider_cyl(pos, radius, height)
	return mi


func _sphere(pos: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = SPH
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3.ONE * (r / 0.5)
	add_child(mi)
	return mi


func _quad(pos: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = QUAD
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(size.x, size.y, 1.0)
	add_child(mi)
	return mi


func _mbox(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BOX
	mi.material_override = mat
	mi.position = pos
	mi.scale = size
	parent.add_child(mi)
	return mi


func _mquad(parent: Node3D, pos: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = QUAD
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(size.x, size.y, 1.0)
	parent.add_child(mi)
	return mi


## Move a sibling beneath a new pivot without asking for a global transform.
## Chunks build in _init(), before they enter the tree, so Node.reparent(...,
## true) cannot safely preserve globals during headless generation audits.
func _adopt_local(parent: Node3D, child: Node3D) -> void:
	var local_xf := parent.transform.affine_inverse() * child.transform
	child.reparent(parent, false)
	child.transform = local_xf


## One top-level pivot for every multi-piece furnishing. Doorway clearance
## removes top-level nodes, so keeping a table, its legs, and everything on it
## beneath one pivot prevents orphaned props when an entrance cuts through the
## generated layout. Floor-supported groups are also checked by the procedural
## support audit.
func _furnishing_pivot(pos: Vector3, yaw: float, kind: String,
		floor_supported := true) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = yaw
	_claim_furnishing_group(pivot, kind, floor_supported)
	if not floor_supported:
		# Historical _furnishing_pivot callers expose the explicit false value;
		# specialized wall-mounted pivots registered through _claim omit it.
		pivot.set_meta("floor_supported", false)
	add_child(pivot)
	return pivot


## Register a builder-created pivot with the same deterministic group/identity
## contract as _furnishing_pivot. Specialized imported assemblies can create
## their node first without reaching into the serial counter.
func _claim_furnishing_group(pivot: Node3D, kind: String,
		floor_supported := true) -> int:
	pivot.set_meta("atomic_furnishing", kind)
	if floor_supported:
		pivot.set_meta("floor_supported", true)
	_furnishing_group_serial += 1
	pivot.set_meta("furnishing_group", _furnishing_group_serial)
	_register_runtime_object("furniture",
		"%04d:%s" % [_furnishing_group_serial, kind], pivot)
	return _furnishing_group_serial


## Colliders live under the chunk's StaticBody3D rather than the visible
## furnishing pivot. Give every collider created by an assembly the same id so
## the doorway cull removes its physics and visuals together.
func _bind_furnishing_colliders(pivot: Node3D, first: int) -> void:
	var group_id: int = int(pivot.get_meta("furnishing_group", -1))
	if group_id < 0:
		return
	for i in range(first, body.get_child_count()):
		body.get_child(i).set_meta("furnishing_group", group_id)


func _mcyl(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CYL
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(radius / 0.5, height / 2.0, radius / 0.5)
	parent.add_child(mi)
	return mi


func _mcone(parent: Node3D, base: Vector3, radius: float, height: float,
		mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CONE
	mi.material_override = mat
	mi.position = base + Vector3(0, height / 2.0, 0)
	mi.scale = Vector3(radius / 0.5, height, radius / 0.5)
	parent.add_child(mi)
	return mi


func _mellipsoid(parent: Node3D, pos: Vector3, scale: Vector3,
		mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = SPH
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


## Local-space strut for detailed multi-piece props such as shopping carts
## and institutional plumbing. Unlike `_beam`, this remains beneath the
## furnishing pivot so doorway culling keeps the whole assembly atomic.
func _mbeam(parent: Node3D, a: Vector3, b: Vector3, th: float,
		mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BOX
	mi.material_override = mat
	var d := b - a
	var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(d, up), (a + b) / 2.0)
	mi.scale = Vector3(th, th, d.length())
	parent.add_child(mi)
	return mi


## Chamfered box — real objects catch light on their edges.
func _rbox(pos: Vector3, size: Vector3, mat: Material, r := 0.03, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = RoundedBox.mesh(size, r)
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		_collider_box(pos, size)
	return mi


func _mrbox(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, r := 0.03) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = RoundedBox.mesh(size, r)
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


# --- structure ---------------------------------------------------------------

func _build_floor_ceiling() -> void:
	if theme == 11:
		_level_builder._bloom_floor_ceiling()
		return
	if theme == 10:
		_level_builder._brutalist_floor_ceiling()
		return
	if theme == 2:
		_level_builder._annex_floor_ceiling()
		return
	if theme == 9:
		_level_builder._pool_floor_ceiling()
		return
	if theme == 1:
		_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), Mats.office_carpet())
		_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.office_ceiling())
		return
	if theme == 4:
		_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), Mats.terrazzo_photo())
		_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.airport_ceiling())
		return
	if theme == 5:
		var fmat: Material = Mats.asy_floor()
		if style == WorldGen.ASY_CORRIDOR or style == WorldGen.ASY_DAYROOM \
				or style == WorldGen.ASY_OFFICE or style == WorldGen.ASY_CHAPEL:
			fmat = Mats.asy_checker()
		elif style == WorldGen.ASY_HYDRO:
			fmat = Mats.asy_tile()
		_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), fmat)
		_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.asy_ceiling())
		return
	if theme == 6:
		_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), _level_builder._sch_floor_mat())
		_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.sch_ceiling())
		return
	if theme == 7:
		var mall_floor: Material = Mats.mall_floor()
		if style == WorldGen.MALL_SERVICE:
			mall_floor = Mats.concrete_floor()
		_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), mall_floor)
		_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.mall_ceiling())
		# Old brass terrazzo control joints make the gallery feel built at mall
		# scale, rather than like a large beige room.
		if style != WorldGen.MALL_SERVICE:
			_box(Vector3(S / 2.0, 0.012, 3.0), Vector3(S, 0.018, 0.025), Mats.brass(), false)
			_box(Vector3(S / 2.0, 0.012, 9.0), Vector3(S, 0.018, 0.025), Mats.brass(), false)
		# Tall atria get night-sky skylight wells: a faint blue glow recessed
		# in the dark grid, the only reminder there is an outside.
		if style == WorldGen.MALL_ATRIUM and ceil_h > 5.5:
			for wx in [3.9, 8.1]:
				var sky := _box(Vector3(wx, ceil_h - 0.02, 6.0), Vector3(2.5, 0.02, 1.7),
					Mats.mall_skylight(), false)
				sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				for fz in [-0.88, 0.88]:
					var fr := _box(Vector3(wx, ceil_h - 0.05, 6.0 + fz),
						Vector3(2.62, 0.10, 0.06), Mats.mall_trim(), false)
					fr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				for fx in [-1.28, 1.28]:
					var fr2 := _box(Vector3(wx + fx, ceil_h - 0.05, 6.0),
						Vector3(0.06, 0.10, 1.76), Mats.mall_trim(), false)
					fr2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	if theme == 8:
		var pf: Material = Mats.prison_tile() if style == WorldGen.PRISON_SHOWER \
			else Mats.prison_floor()
		_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), pf)
		_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.prison_ceiling())
		return
	var floor_mat: Material = Mats.marble_photo() if style == WorldGen.STYLE_GRAND \
		or style == WorldGen.STYLE_BALLROOM else Mats.carpet()
	_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), floor_mat)
	_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.ceiling())

	if style == WorldGen.STYLE_GRAND or style == WorldGen.STYLE_BALLROOM:
		# clerestory band between standard wall height and the raised ceiling
		var bh := ceil_h - H
		var by := H + bh / 2.0
		_box(Vector3(S / 2.0, by, T / 2.0), Vector3(S, bh, T), Mats.band_paint(), false)
		_box(Vector3(S / 2.0, by, S - T / 2.0), Vector3(S, bh, T), Mats.band_paint(), false)
		_box(Vector3(T / 2.0, by, S / 2.0), Vector3(T, bh, S), Mats.band_paint(), false)
		_box(Vector3(S - T / 2.0, by, S / 2.0), Vector3(T, bh, S), Mats.band_paint(), false)
		var neon: Material = Mats.neon_pink() if _r(31) < 0.5 else Mats.neon_amber()
		var ny := H + 0.18
		_box(Vector3(S / 2.0, ny, 0.35), Vector3(S - 1.0, 0.06, 0.08), neon, false)
		_box(Vector3(S / 2.0, ny, S - 0.35), Vector3(S - 1.0, 0.06, 0.08), neon, false)
		_box(Vector3(0.35, ny, S / 2.0), Vector3(0.08, 0.06, S - 1.0), neon, false)
		_box(Vector3(S - 0.35, ny, S / 2.0), Vector3(0.08, 0.06, S - 1.0), neon, false)


func _build_walls() -> void:
	var wall_t := ANNEX_WALL_T if theme == 2 else (POOL_WALL_T if theme == 9 else T)
	for dir in 4:
		var edge_visual_start := get_child_count()
		var info := _edge_info(cell, dir)
		# Annex and pool shared boundaries have one canonical east/south owner
		# and sit on the actual boundary plane. Previously both neighbouring
		# chunks built an inward half, producing a compound double wall — in
		# the Poolrooms that doubled every bullnose and jamb pillar and left a
		# stepped seam at every convex corner between two cells' slabs. The
		# non-owner still supplies room-side wall dressing below. Interior
		# faces are unchanged: a 0.30 wall centred ON the boundary shows its
		# face 0.15 into each room, exactly where the old inward slab's face
		# was, so every cove/pillar tangency built against T still holds.
		var owns_annex_wall := (theme != 2 and theme != 9) or dir == 0 or dir == 2
		var plane := (S if (dir == 0 or dir == 2) else 0.0) \
			if (theme == 2 or theme == 9) \
			else ((S - wall_t / 2.0) if (dir == 0 or dir == 2) \
				else (wall_t / 2.0))
		# The one canonical pool wall serves BOTH rooms, whose ceilings can
		# differ. Built only to the owner's ceiling, the taller room saw a
		# black slit above the wall top: the void between the two ceiling
		# planes. Build every shared wall to the taller of the two.
		var wtop := _wall_h()
		if theme == 9:
			wtop = maxf(wtop, cell_ceil_h(
				wseed, cell + WorldGen.DIRV[dir], theme))
		if info["wall"]:
			if owns_annex_wall:
				if theme == 9 \
						and WorldGen.pool_wall_aperture(wseed, cell, dir) \
						and not bool(info.get("runtime_seal", false)):
					_pool_wall_with_circular_aperture(
						dir, plane, wtop)
				else:
					_wall_seg(dir, plane, 0.0, S, 0.0, wtop)
			_wall_decor(dir, plane)
			if (theme == 1 or theme == 2) \
					and (theme != 2 or owns_annex_wall) \
					and not (theme == 2 and style == WorldGen.ANNEX_PASSAGE) \
					and not (theme == 1 and style == WorldGen.OFFICE_CORRIDOR):
				_wall_utilities(dir, plane, info)
		elif not info["full_open"]:
			var a: float = info["t"] - info["w"] / 2.0
			var b: float = info["t"] + info["w"] / 2.0
			if owns_annex_wall:
				if theme == 9:
					_pool_shaped_doorway(
						dir, plane, a, b, wtop)
				else:
					_wall_seg(dir, plane, 0.0, a, 0.0, wtop)
					_wall_seg(dir, plane, b, S, 0.0, wtop)
					var head: float = DOOR_TOP
					if theme == 4 or theme == 7:
						head = AIR_DOOR
					elif theme == 10:
						head = BRUTAL_DOOR_TOP
					elif theme == 11:
						head = BLOOM_DOOR_TOP
					_wall_seg(dir, plane, a, b, head, wtop)
				_door_casing(dir, plane, a, b)
				# Generated realities explicitly decide whether a new opening is an
				# impossible raw cut or a conventional door that was never there.
				if not bool(info.get("runtime_shortcut", false)) \
						or bool(info.get("runtime_door", false)):
					_maybe_swing_door(dir, plane, a, b,
						bool(info.get("runtime_door", false)))
			if (theme == 1 or theme == 2) \
					and (theme != 2 or owns_annex_wall) \
					and not (theme == 2 and style == WorldGen.ANNEX_PASSAGE) \
					and not (theme == 1 and style == WorldGen.OFFICE_CORRIDOR):
				_wall_utilities(dir, plane, info)
			if (dir == 0 or dir == 2) and info["exit_sign"]:
				if theme == 4:
					_level_builder._air_portal_sign(dir, info["t"])
				else:
					_exit_sign(dir, info["t"])
		else:
			_open_edge_fascia(dir, plane)
		# Keep the exact scene roots created by a supernatural edge record
		# discoverable. The blackout reveal can then outline the actual new wall,
		# casing, or door leaf instead of drawing only a marker near it.
		if bool(info.get("runtime_shortcut", false)) \
				or bool(info.get("runtime_seal", false)):
			_tag_mutation_edge_visuals(edge_visual_start, dir)
	if theme == 9:
		# Each grid vertex has one deterministic southwest owner.  This chunk
		# therefore owns its north-east vertex and builds at most one curved
		# L-turn there, after both incident straight runs have been shortened
		# to their tangent points by _pool_boundary_rule.
		_pool_rounded_corner()


func _edge_info(at: Vector2i, dir: int) -> Dictionary:
	if descent_topology != null:
		return descent_topology.edge_info_for_state(
			at, dir, descent_topology_state_override) \
			if descent_topology_state_override >= 0 else \
			descent_topology.edge_info(at, dir)
	return WorldGen.edge_info(wseed, at, dir, theme)


func _tag_mutation_edge_visuals(first_child: int, dir: int) -> void:
	for index in range(first_child, get_child_count()):
		var visual := get_child(index) as Node3D
		if visual != null and visual != body:
			visual.set_meta("mutation_edge_visual", true)
			visual.set_meta("mutation_edge_dir", dir)


## Exact installed geometry produced for one supernatural boundary record.
## Returning top-level roots keeps imported door assemblies atomic while the
## presentation effect recursively outlines every mesh beneath them.
func mutation_edge_visuals(dir: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in get_children():
		var visual := child as Node3D
		if visual != null \
				and bool(visual.get_meta("mutation_edge_visual", false)) \
				and int(visual.get_meta("mutation_edge_dir", -1)) == dir:
			out.append(visual)
	return out


func _pool_shaped_doorway(dir: int, plane: float,
		a: float, b: float, wall_top: float) -> void:
	_wall_seg(dir, plane, 0.0, a, 0.0, wall_top)
	_wall_seg(dir, plane, b, S, 0.0, wall_top)
	var width := b - a
	var kind := WorldGen.pool_doorway_kind(wseed, cell, dir)
	var profile: Array[Vector2]
	var kind_name := "rounded"
	if kind == WorldGen.POOL_OPENING_ARCH:
		var rise := clampf(width * 0.28, 0.95, 1.35)
		profile = PoolOpeningMesh.arched_door_profile(
			width, POOL_DOOR_TOP, rise, 18)
		kind_name = "arch"
	else:
		profile = PoolOpeningMesh.rounded_door_profile(
			width, POOL_DOOR_TOP, 0.52, 9)
	_pool_opening_header_mesh(
		dir, plane, (a + b) * 0.5, profile, wall_top, kind_name)
	_pool_profile_header_colliders(
		dir, plane, (a + b) * 0.5, profile, wall_top, kind_name)
	_level_builder._pool_crown_trims(dir, plane, a, b)


func _pool_opening_header_mesh(dir: int, plane: float, along: float,
		profile: Array[Vector2], wall_top: float, kind: String) -> void:
	var header := MeshInstance3D.new()
	header.mesh = PoolOpeningMesh.doorway_header(
		profile, POOL_WALL_T, wall_top)
	header.material_override = Mats.pool_wall_tile()
	header.position = Vector3(plane, 0.0, along) if dir < 2 \
		else Vector3(along, 0.0, plane)
	if dir < 2:
		header.rotation.y = -PI * 0.5
	header.set_meta("pool_opening", true)
	header.set_meta("pool_opening_kind", kind)
	header.set_meta("pool_opening_dir", dir)
	header.set_meta("pool_opening_profile", profile)
	header.set_meta("pool_opening_wall_top", wall_top)
	add_child(header)


func _pool_profile_header_colliders(dir: int, plane: float, along: float,
		profile: Array[Vector2], wall_top: float, kind: String) -> void:
	for i in range(profile.size() - 1):
		_pool_profile_prism_collider(
			dir, plane,
			along + profile[i].x,
			along + profile[i + 1].x,
			profile[i].y, profile[i + 1].y,
			wall_top, wall_top,
			kind)


func _pool_wall_with_circular_aperture(
		dir: int, plane: float, wall_top: float) -> void:
	var along := WorldGen.pool_wall_aperture_along(wseed, cell, dir)
	var neighbor_height := cell_ceil_h(
		wseed, cell + WorldGen.DIRV[dir], theme)
	var visible_top := minf(ceil_h, neighbor_height) - 0.28
	var bottom := POOL_DRY_Y + 0.44
	var radius := minf(
		1.25, maxf(0.82, (visible_top - bottom) * 0.5))
	radius = minf(radius, minf(along - 0.85, S - along - 0.85))
	var center_y := bottom + radius
	var a := along - radius
	var b := along + radius
	_wall_seg(dir, plane, 0.0, a, 0.0, wall_top)
	_wall_seg(dir, plane, b, S, 0.0, wall_top)

	var panel := MeshInstance3D.new()
	panel.mesh = PoolOpeningMesh.circular_aperture_panel(
		radius, POOL_WALL_T, wall_top, center_y, 28)
	panel.material_override = Mats.pool_wall_tile()
	panel.position = Vector3(plane, 0.0, along) if dir < 2 \
		else Vector3(along, 0.0, plane)
	if dir < 2:
		panel.rotation.y = -PI * 0.5
	panel.set_meta("pool_opening", true)
	panel.set_meta("pool_opening_kind", "circle")
	panel.set_meta("pool_opening_dir", dir)
	panel.set_meta("pool_opening_radius", radius)
	panel.set_meta("pool_opening_center_y", center_y)
	panel.set_meta("pool_opening_wall_top", wall_top)
	add_child(panel)

	var count := 20
	for i in count:
		var angle0 := lerpf(PI, 0.0, float(i) / float(count))
		var angle1 := lerpf(PI, 0.0, float(i + 1) / float(count))
		var u0 := along + cos(angle0) * radius
		var u1 := along + cos(angle1) * radius
		var upper0 := center_y + sin(angle0) * radius
		var upper1 := center_y + sin(angle1) * radius
		var lower0 := center_y - sin(angle0) * radius
		var lower1 := center_y - sin(angle1) * radius
		_pool_profile_prism_collider(
			dir, plane, u0, u1,
			0.0, 0.0, lower0, lower1, "circle_lower")
		_pool_profile_prism_collider(
			dir, plane, u0, u1,
			upper0, upper1, wall_top, wall_top, "circle_upper")
	_level_builder._pool_crown_trims(dir, plane, a, b)


func _pool_profile_prism_collider(
		dir: int, plane: float,
		u0: float, u1: float,
		low0: float, low1: float,
		high0: float, high1: float,
		kind: String) -> void:
	if minf(high0 - low0, high1 - low1) < 0.01:
		return
	var half := POOL_WALL_T * 0.5
	var points := PackedVector3Array()
	for offset in [-half, half]:
		if dir < 2:
			points.append(Vector3(plane + offset, low0, u0))
			points.append(Vector3(plane + offset, low1, u1))
			points.append(Vector3(plane + offset, high1, u1))
			points.append(Vector3(plane + offset, high0, u0))
		else:
			points.append(Vector3(u0, low0, plane + offset))
			points.append(Vector3(u1, low1, plane + offset))
			points.append(Vector3(u1, high1, plane + offset))
			points.append(Vector3(u0, high0, plane + offset))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.set_meta("pool_opening_collider", true)
	cs.set_meta("pool_opening_kind", kind)
	cs.set_meta("pool_opening_dir", dir)
	body.add_child(cs)


## A fully open edge builds no wall at all. That is right at eye level and
## wrong above it when the rooms it joins have different ceiling heights: seen
## from the taller room, the band between the two ceiling planes is raw
## unbuilt void — a huge black slab hanging over the opening, with the cut
## edge of the low room's ceiling slab exposed beneath it. The taller cell
## seals the band with a fascia in its own wall plane, flush from the
## neighbour's ceiling up to its own. The Annex never needs one: its drop
## ceiling is a single height everywhere.
func _open_edge_fascia(dir: int, plane: float) -> void:
	var nb_h := cell_ceil_h(wseed, cell + WorldGen.DIRV[dir], theme)
	if ceil_h - nb_h < 0.1:
		return
	var yc := (nb_h + ceil_h) * 0.5
	var fascia := _box(
		Vector3(plane, yc, S / 2.0) if dir < 2 else Vector3(S / 2.0, yc, plane),
		Vector3(T, ceil_h - nb_h, S) if dir < 2 \
			else Vector3(S, ceil_h - nb_h, T),
		_wall_material())
	fascia.set_meta("open_edge_fascia", dir)
	fascia.set_meta("fascia_low_ceiling", nb_h)


## Some genuine room-to-room openings get a working leaf. Canonical east and
## south ownership prevents the neighbour chunk from building a duplicate.
func _maybe_swing_door(dir: int, plane: float, a: float, b: float,
		force := false) -> void:
	if dir != 0 and dir != 2:
		return
	if not force and (theme == 2 or theme == 4 or theme == 7 or theme == 9 or theme == 10 \
			or theme == 11 \
			or b - a > 2.25):
		return
	if not force and WorldGen.h(
			wseed, cell.x, cell.y, 1760 + dir + theme * 11) % 100 >= 14:
		return
	var width := b - a - 0.12
	if width < 0.82:
		return
	var pivot := Node3D.new()
	if dir == 0:
		pivot.position = Vector3(plane - 0.015, 0, a + 0.06)
	else:
		pivot.position = Vector3(a + 0.06, 0, plane - 0.015)
	pivot.set_meta("door_dir", dir)
	if force:
		pivot.set_meta("runtime_mutation_door", true)
	add_child(pivot)
	_register_runtime_object("swing_door", _door_rebuild_key(pivot), pivot)
	var panel_mat: Material = Mats.wood_door()
	if theme == 5:
		panel_mat = Mats.asy_metal_green()
	elif theme == 6:
		panel_mat = Mats.sch_door()
	elif theme == 8:
		panel_mat = Mats.prison_green()
	# School casings are cut to the full 2.25m opening, while the old generic
	# 2.16m leaf stopped nine centimetres short and exposed the wall/header
	# behind it. Retain a small operating gap, but fit the actual frame.
	var panel_height := DOOR_TOP - 0.02 if theme == 6 else 2.16
	var panel_y := panel_height * 0.5
	var panel_pos := Vector3(0, panel_y, width * 0.5) if dir == 0 \
		else Vector3(width * 0.5, panel_y, 0)
	var panel_size := Vector3(0.075, panel_height, width) if dir == 0 \
		else Vector3(width, panel_height, 0.075)
	if theme == 6:
		pivot.set_meta("school_swing_door", true)
		pivot.set_meta("school_door_leaf_top", panel_height)
		pivot.set_meta("school_door_frame_top", DOOR_TOP)
	var authored_prison_leaf := false
	if theme == 8:
		# The authored solitary-cell leaf is floor-aligned and centred on local
		# X. Stretch only that width axis to the generated opening; retain its
		# real height and thickness. Its left edge is then seated exactly on
		# this gameplay pivot, so the existing away-from-player swing remains
		# geometrically honest from either side.
		var sx := width / 1.1068
		var syz := 2.16 / 2.30
		# The source handle sits at local -X, so hinge its +X edge. Rotating
		# that edge onto this pivot puts the handle at the moving end rather
		# than absurdly beside the hinge.
		var door_pos := Vector3(0, 0, 0.5534 * sx) if dir == 0 \
			else Vector3(0.5534 * sx, 0, 0)
		var door_yaw := PI / 2.0 if dir == 0 else PI
		var authored := _attributed_prop_local(pivot, SOLITARY_CELL_DOOR_PATH,
			door_pos, door_yaw, Vector3(sx, syz, syz))
		authored_prison_leaf = authored != null
		if authored_prison_leaf:
			authored.set_meta("interactive_prison_door", true)
	if not authored_prison_leaf:
		_mrbox(pivot, panel_pos, panel_size, panel_mat, 0.012)
		# Kick plate, closer and proper lever make the selected leaf read
		# differently from the permanently locked facade doors nearby.
		var kick_pos := panel_pos + (Vector3(-0.045, -0.72, 0) if dir == 0 \
			else Vector3(0, -0.72, -0.045))
		var kick_size := Vector3(0.018, 0.34, width - 0.18) if dir == 0 \
			else Vector3(width - 0.18, 0.34, 0.018)
		_mbox(pivot, kick_pos, kick_size, Mats.steel())
		var handle_pos := panel_pos + (Vector3(-0.065, -0.05, width * 0.34) \
			if dir == 0 else Vector3(width * 0.34, -0.05, -0.065))
		_mcyl(pivot, handle_pos, 0.025, 0.18,
			Mats.brass() if theme == 0 else Mats.chrome())
		var closer_pos := panel_pos + Vector3(0, 0.86, 0)
		_mbox(pivot, closer_pos, Vector3(0.10, 0.10, 0.42) if dir == 0 \
			else Vector3(0.42, 0.10, 0.10), Mats.charcoal())
	var sb := StaticBody3D.new()
	pivot.add_child(sb)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = panel_size
	cs.shape = shape
	cs.position = panel_pos
	sb.add_child(cs)
	var hit := Interactable.new()
	hit.prompt_text = "E — open door"
	hit.position = panel_pos
	hit.add_box(panel_size + Vector3(0.28, 0.1, 0.28))
	pivot.add_child(hit)
	hit.activated.connect(_toggle_swing_door.bind(pivot, cs, hit, dir))


func _door_swing_away_from(actor: Node, pivot: Node3D, dir: int) -> float:
	var swing := -1.28 if dir == 0 else 1.28
	if not actor is Node3D:
		return swing
	# At zero rotation, positive yaw moves an east/west door's free edge
	# toward +X and a north/south door's free edge toward -Z. Choose the
	# opposite sign whenever that motion would carry the leaf toward whoever
	# is opening it. This is recalculated for every opening, so the same door
	# behaves correctly when approached from either adjoining room.
	var positive_motion_local := Vector3.RIGHT if dir == 0 else Vector3(0, 0, -1)
	var parent := pivot.get_parent() as Node3D
	var positive_motion_world := parent.global_transform.basis * positive_motion_local
	var toward_actor := (actor as Node3D).global_position - pivot.global_position
	if positive_motion_world.dot(toward_actor) > 0.0:
		swing = -1.28
	else:
		swing = 1.28
	return swing


func _toggle_swing_door(actor: Node, pivot: Node3D, cs: CollisionShape3D,
		hit: Interactable, dir: int) -> void:
	if bool(pivot.get_meta("moving", false)):
		return
	var opening := not bool(pivot.get_meta("open", false))
	var target_angle := 0.0
	if opening:
		target_angle = _door_swing_away_from(actor, pivot, dir)
		pivot.set_meta("last_open_angle", target_angle)
	pivot.set_meta("moving", true)
	if opening:
		cs.disabled = true
	hit.prompt_text = "E — close door" if opening else "E — open door"
	get_tree().call_group("level_manager", "door_activity")
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pivot, "rotation:y", target_angle, 0.58)
	await tw.finished
	if not is_instance_valid(pivot):
		return
	pivot.set_meta("open", opening)
	pivot.set_meta("moving", false)
	if not opening:
		cs.disabled = false


## Allowlisted transient room state that generation must not rewind. The
## semantic key survives node destruction, streaming and topology mutation.
func capture_runtime_state() -> ChunkRuntimeState:
	var out := ChunkRuntimeState.new()
	for key in _runtime_objects:
		var record: Dictionary = _runtime_objects[key]
		var node_value: Variant = record.get("node", null)
		if not is_instance_valid(node_value):
			continue
		var node := node_value as Node3D
		if node == null:
			continue
		match str(record.get("kind", "")):
			"swing_door":
				out.put(str(key), "swing_door", {
					"open": bool(node.get_meta("open", false)),
					"angle": float(node.get_meta(
						"last_open_angle", node.rotation.y)),
				})
	return out


func restore_runtime_state(state: ChunkRuntimeState) -> void:
	if state == null or state.is_empty():
		return
	for key in state.keys():
		if not _runtime_objects.has(key):
			continue
		var record: Dictionary = _runtime_objects[key]
		var node_value: Variant = record.get("node", null)
		if not is_instance_valid(node_value):
			continue
		var node := node_value as Node3D
		if node == null:
			continue
		if str(record.get("kind", "")) == "swing_door" \
				and state.kind_for(key) == "swing_door":
			_apply_swing_door_state(node, state.payload_for(key))


func runtime_object_descriptors() -> Dictionary:
	var out := {}
	for key in _runtime_objects:
		var record: Dictionary = _runtime_objects[key]
		var node_value: Variant = record.get("node", null)
		if not is_instance_valid(node_value):
			continue
		var node := node_value as Node3D
		if node != null and node.get_parent() != null:
			out[str(key)] = str(record.get("kind", ""))
	return out


func runtime_object_transforms(kind_filter := "") -> Dictionary:
	var out := {}
	for key in _runtime_objects:
		var record: Dictionary = _runtime_objects[key]
		var kind := str(record.get("kind", ""))
		if not kind_filter.is_empty() and kind != kind_filter:
			continue
		var node_value: Variant = record.get("node", null)
		if not is_instance_valid(node_value):
			continue
		var node := node_value as Node3D
		if node != null and node.get_parent() != null:
			out[str(key)] = node.transform
	return out


## World-space samples for floor-supported, non-interactive set pieces. The
## blackout selector uses the real resident furniture rather than a room-centre
## guess, so a "visible" mutation has an actual object in the camera frustum.
## Three heights cover low chairs, tables and tall cabinets without requiring
## every imported mesh to expose a custom bounding box contract.
func furniture_witness_points(changed_only := false) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for key in _runtime_objects:
		var record: Dictionary = _runtime_objects[key]
		if str(record.get("kind", "")) != "furniture":
			continue
		var node_value: Variant = record.get("node", null)
		if not is_instance_valid(node_value) or not node_value is Node3D:
			continue
		var pivot := node_value as Node3D
		if pivot.get_parent() == null \
				or not bool(pivot.get_meta("floor_supported", false)):
			continue
		if changed_only \
				and not bool(pivot.get_meta("mutation_furniture_moved", false)) \
				and not bool(pivot.get_meta("descent_reality_furniture", false)):
			continue
		if not pivot.find_children("*", "Interactable", true, false).is_empty() \
				or not pivot.find_children("*", "VhsRitual", true, false).is_empty() \
				or not pivot.find_children(
					"*", "ChargingStation", true, false).is_empty():
			continue
		for height in [0.35, 0.85, 1.35]:
			out.append(_furniture_sample_point(pivot, height))
	return out


## Target-aware witness samples. Sparse supported rooms may have no movable
## base furnishing; their alternate reality introduces one chair at the exact
## prevalidated site returned here, so that appearance can still satisfy the
## same camera/occlusion contract before the replacement chunk is constructed.
func furniture_witness_points_for_variant(target_variant: int,
		changed_only := false) -> Array[Vector3]:
	if changed_only:
		return furniture_witness_points(true)
	var out: Array[Vector3] = []
	if target_variant <= 0:
		# Mutation-back can witness a currently displaced object. If the
		# designated object is absent, this room simply cannot qualify and a
		# visible architectural edge or another changed room must carry the beat.
		return furniture_witness_points(true)
	var witness := _first_mutation_furniture()
	if witness != null:
		for height in [0.35, 0.85, 1.35]:
			out.append(_furniture_sample_point(witness, height))
		return out
	var plan := _reality_chair_plan(target_variant)
	if plan.is_empty():
		return out
	var local: Vector3 = plan["position"]
	for height in [0.35, 0.85, 1.35]:
		var sample := local + Vector3(0.0, height, 0.0)
		out.append(to_global(sample) if is_inside_tree() else sample)
	return out


## Resolve a sampled furniture witness back to the actual atomic furnishing
## pivot. This is presentation-only and never alters the deterministic recipe.
func furniture_witness_node_near(point: Vector3,
		changed_only := false) -> Node3D:
	var best: Node3D
	var best_distance := INF
	for key in _runtime_objects:
		var record: Dictionary = _runtime_objects[key]
		if str(record.get("kind", "")) != "furniture":
			continue
		var value: Variant = record.get("node", null)
		if not is_instance_valid(value) or not value is Node3D:
			continue
		var pivot := value as Node3D
		if pivot.get_parent() == null \
				or not bool(pivot.get_meta("floor_supported", false)):
			continue
		if changed_only \
				and not bool(pivot.get_meta("mutation_furniture_moved", false)) \
				and not bool(pivot.get_meta("descent_reality_furniture", false)):
			continue
		var distance := pivot.global_position.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = pivot
	return best


func _furniture_sample_point(pivot: Node3D, height: float) -> Vector3:
	var offset := Vector3(0.0, height, 0.0)
	return pivot.global_position + offset \
		if pivot.is_inside_tree() else pivot.position + offset


## Stable identity of the designated base-state witness. Empty means the
## alternate reality uses the deterministic appearing-chair fallback instead.
func furniture_witness_key_for_variant(target_variant: int) -> String:
	if target_variant <= 0:
		return ""
	var witness := _first_mutation_furniture()
	if witness == null:
		return ""
	for key in _runtime_objects:
		if (_runtime_objects[key] as Dictionary).get("node", null) == witness:
			return str(key)
	return ""


func _first_mutation_furniture() -> Node3D:
	for child in get_children():
		var pivot := child as Node3D
		if _furniture_mutation_eligible(pivot):
			return pivot
	return null


func _furniture_mutation_eligible(pivot: Node3D) -> bool:
	if pivot == null or not pivot.has_meta("furnishing_group"):
		return false
	if pivot.has_meta("annex_architecture") \
			or pivot.has_meta("wall_utility_dir") \
			or pivot.has_meta("annex_ac_mount") \
			or pivot.has_meta("annex_attached_half_wall"):
		return false
	if pivot.position.x < 0.9 or pivot.position.x > S - 0.9 \
			or pivot.position.z < 0.9 or pivot.position.z > S - 0.9 \
			or not bool(pivot.get_meta("floor_supported", false)):
		return false
	return pivot.find_children("*", "Interactable", true, false).is_empty() \
		and pivot.find_children("*", "VhsRitual", true, false).is_empty() \
		and pivot.find_children(
			"*", "ChargingStation", true, false).is_empty()


func runtime_identity_violations() -> int:
	return _runtime_identity_errors


func _register_runtime_object(kind: String, local_id: String,
		node: Node3D) -> String:
	var key := ChunkRuntimeState.object_key(cell, kind, local_id)
	if _runtime_objects.has(key):
		var existing: Dictionary = _runtime_objects[key]
		var existing_value: Variant = existing.get("node", null)
		if is_instance_valid(existing_value) \
				and existing_value is Node3D:
			_runtime_identity_errors += 1
	_runtime_objects[key] = {"kind": kind, "node": node}
	return key


func _apply_swing_door_state(pivot: Node3D, state: Dictionary) -> void:
	var opened := bool(state.get("open", false))
	var angle := float(state.get("angle", 0.0)) if opened else 0.0
	pivot.rotation.y = angle
	pivot.set_meta("open", opened)
	pivot.set_meta("moving", false)
	pivot.set_meta("last_open_angle", angle)
	for body_node in pivot.find_children("*", "StaticBody3D", true, false):
		for shape_node in body_node.find_children(
				"*", "CollisionShape3D", true, false):
			(shape_node as CollisionShape3D).disabled = opened
	for hit_node in pivot.find_children("*", "Interactable", true, false):
		(hit_node as Interactable).prompt_text = \
			"E — close door" if opened else "E — open door"


func _door_rebuild_key(pivot: Node3D) -> String:
	return "%d:%.3f:%.3f" % [int(pivot.get_meta("door_dir", -1)),
		pivot.position.x, pivot.position.z]


## Resolve one endpoint of an Annex boundary wall.
##
## At an L-corner neither wall is dominant, so retain the stable axis-based
## mitre: Z walls extend and X walls retract. At a T-junction there *is* a
## dominant wall — the perpendicular line continues through the junction while
## this one terminates. The terminating stub must stop at the continuous wall's
## near face and must not draw an end cap. That leaves the continuous wall's
## own surface, finish, and baseboard decision visibly in charge instead of
## laying a differently finished rectangle (and sometimes a trim fragment)
## over it.
func _annex_corner_rule(dir: int, at_max: bool) -> Dictionary:
	var collinear: Array
	var perp_a: Array
	var perp_b: Array
	match dir:
		0:
			collinear = [cell + Vector2i(0, 1 if at_max else -1), 0]
			perp_a = [cell, 2 if at_max else 3]
			perp_b = [cell + Vector2i(1, 0), 2 if at_max else 3]
		1:
			collinear = [cell + Vector2i(0, 1 if at_max else -1), 1]
			perp_a = [cell, 2 if at_max else 3]
			perp_b = [cell + Vector2i(-1, 0), 2 if at_max else 3]
		2:
			collinear = [cell + Vector2i(1 if at_max else -1, 0), 2]
			perp_a = [cell, 0 if at_max else 1]
			perp_b = [cell + Vector2i(0, 1), 0 if at_max else 1]
		_:
			collinear = [cell + Vector2i(1 if at_max else -1, 0), 3]
			perp_a = [cell, 0 if at_max else 1]
			perp_b = [cell + Vector2i(0, -1), 0 if at_max else 1]
	if _edge_solid(collinear[0], collinear[1]):
		return {
			"shift": 0.0,
			"t_stub": false,
			"winner_finish": -1,
			"kind": "continuation",
			"needs_cap": false,
		}
	var has_perp_a := _edge_solid(perp_a[0], perp_a[1])
	var has_perp_b := _edge_solid(perp_b[0], perp_b[1])
	if not has_perp_a and not has_perp_b:
		return {
			"shift": 0.0,
			"t_stub": false,
			"winner_finish": -1,
			"kind": "free",
			"needs_cap": true,
		}
	var h := ANNEX_WALL_T * 0.5
	# Both perpendicular halves being solid makes them one longer continuous
	# wall. Retract this terminating stub to its near face regardless of axis.
	if has_perp_a and has_perp_b:
		var winner_finish := WorldGen.annex_wall_finish(
			wseed, perp_a[0], perp_a[1])
		return {
			"shift": -h if at_max else h,
			"t_stub": true,
			"winner_finish": winner_finish,
			"kind": "t_stub",
			"needs_cap": false,
		}
	# walls along Z (dir 0/1) extend into the turn; walls along X retract
	var outward := h if dir < 2 else -h
	return {
		"shift": outward if at_max else -outward,
		"t_stub": false,
		"winner_finish": -1,
		"kind": "l_corner",
		"needs_cap": true,
	}


## Resolve the visible treatment once for the complete canonical wall edge.
## Door cuts can split that edge into several meshes, but every mesh must still
## receive the same finish and baseboard decision. At a T-junction the
## continuous perpendicular wall owns the terminating edge's treatment.
func _annex_resolved_wall_treatment(dir: int) -> Dictionary:
	var raw_finish := WorldGen.annex_wall_finish(wseed, cell, dir)
	var min_rule := _annex_corner_rule(dir, false)
	var max_rule := _annex_corner_rule(dir, true)
	var min_winner := int(min_rule["winner_finish"]) \
		if bool(min_rule["t_stub"]) else -1
	var max_winner := int(max_rule["winner_finish"]) \
		if bool(max_rule["t_stub"]) else -1
	var resolved_finish := raw_finish
	var owner := "collinear_line"
	# Prefer the minimum endpoint only as a deterministic tie-break when a
	# short edge terminates into through-walls at both ends. The important
	# invariant is that the whole edge receives one treatment.
	if min_winner >= 0:
		resolved_finish = min_winner
		owner = "perpendicular_wall_min"
	elif max_winner >= 0:
		resolved_finish = max_winner
		owner = "perpendicular_wall_max"
	return {
		"raw_finish": raw_finish,
		"finish": resolved_finish,
		"owner": owner,
		"winner_min": min_winner,
		"winner_max": max_winner,
	}


## Whether an edge carries any wall mass at its corners. Openings keep at
## least 0.55m of wall beside each jamb, so any non-full-open edge has solid
## material at both cell corners.
func _edge_solid(at: Vector2i, dir: int) -> bool:
	return not bool(_edge_info(at, dir)["full_open"])


## Resolve one boundary endpoint of a pool wall.  A true L-turn retracts BOTH
## incident straight runs by the shared corner radius; their one deterministic
## corner owner fills that space with a tangent quarter-annulus.  A stub
## terminating at a through wall (T) still retracts only to its near face; a
## straight continuation and a free end remain square on the grid vertex.
func _pool_boundary_rule(dir: int, at_max: bool) -> float:
	var collinear: Array
	var perp_a: Array
	var perp_b: Array
	match dir:
		0:
			collinear = [cell + Vector2i(0, 1 if at_max else -1), 0]
			perp_a = [cell, 2 if at_max else 3]
			perp_b = [cell + Vector2i(1, 0), 2 if at_max else 3]
		1:
			collinear = [cell + Vector2i(0, 1 if at_max else -1), 1]
			perp_a = [cell, 2 if at_max else 3]
			perp_b = [cell + Vector2i(-1, 0), 2 if at_max else 3]
		2:
			collinear = [cell + Vector2i(1 if at_max else -1, 0), 2]
			perp_a = [cell, 0 if at_max else 1]
			perp_b = [cell + Vector2i(0, 1), 0 if at_max else 1]
		_:
			collinear = [cell + Vector2i(1 if at_max else -1, 0), 3]
			perp_a = [cell, 0 if at_max else 1]
			perp_b = [cell + Vector2i(0, -1), 0 if at_max else 1]
	if _edge_solid(collinear[0], collinear[1]):
		return 0.0
	var has_a := _edge_solid(perp_a[0], perp_a[1])
	var has_b := _edge_solid(perp_b[0], perp_b[1])
	if not has_a and not has_b:
		return 0.0
	var h := POOL_WALL_T * 0.5
	if has_a and has_b:
		return -h
	# Negative means retract at either end: `_wall_seg` subtracts this value
	# from a minimum endpoint and adds it to a maximum endpoint.
	return -POOL_PILLAR_RADIUS


## Solid half-edges incident on the north-east grid vertex owned by `owner`.
## Every vertex has exactly one southwest owner, while the four physical wall
## runs retain the east/south canonical ownership used by _build_walls.
static func pool_corner_arms(ws: int, owner: Vector2i) -> Array[Vector2i]:
	var arms: Array[Vector2i] = []
	var specs: Array = [
		[Vector2i(1, 0), owner + Vector2i(1, 0), 2],  # +X
		[Vector2i(-1, 0), owner, 2],                   # -X
		[Vector2i(0, 1), owner + Vector2i(0, 1), 0],  # +Z
		[Vector2i(0, -1), owner, 0],                   # -Z
	]
	for spec: Array in specs:
		if not bool(WorldGen.edge_info(
				ws, spec[1] as Vector2i, int(spec[2]), 9)["full_open"]):
			arms.append(spec[0] as Vector2i)
	return arms


## Build the one continuous rounded bend at this chunk's north-east vertex.
## Exactly two perpendicular solid half-edges constitute an L.  Straight,
## isolated and collinear vertices need no curve.  T and four-way vertices
## keep their through-wall topology, but each room quadrant bounded by two
## arms receives an additive inner cove so it cannot expose a sharp concave
## corner.
func _pool_rounded_corner() -> void:
	var arms := pool_corner_arms(wseed, cell)
	var is_l := arms.size() == 2 \
		and arms[0].x * arms[1].x + arms[0].y * arms[1].y == 0
	if not is_l:
		_pool_inner_coves(arms)
		return
	var a := arms[0]
	var b := arms[1]
	var av := Vector2(float(a.x), float(a.y))
	var bv := Vector2(float(b.x), float(b.y))
	var vertex := Vector2(S, S)
	var center := vertex + (av + bv) * POOL_PILLAR_RADIUS
	# At the tangent point on arm A the radius points opposite arm B (and
	# vice versa).  The sign of their 2-D cross picks the short 90-degree
	# sweep rather than the long way around the circle.
	var radial_start := -bv
	var radial_end := -av
	var sweep := PI * 0.5 if radial_start.cross(radial_end) > 0.0 \
		else -PI * 0.5
	var inner_radius := POOL_PILLAR_RADIUS - POOL_WALL_T * 0.5
	var outer_radius := POOL_PILLAR_RADIUS + POOL_WALL_T * 0.5
	var wall_top := maxf(
		_pool_corner_arm_top(a), _pool_corner_arm_top(b))
	var curved := MeshInstance3D.new()
	curved.mesh = PoolCornerMesh.quarter_annulus(
		center, radial_start, sweep, inner_radius, outer_radius,
		0.0, wall_top, POOL_CORNER_SEGMENTS)
	curved.material_override = Mats.pool_wall_tile()
	curved.set_meta("pool_rounded_corner", true)
	curved.set_meta("pool_corner_radius", POOL_PILLAR_RADIUS)
	curved.set_meta("pool_corner_thickness", POOL_WALL_T)
	curved.set_meta("pool_corner_segments", POOL_CORNER_SEGMENTS)
	curved.set_meta("pool_corner_grid_vertex", cell + Vector2i(1, 1))
	curved.set_meta("pool_corner_center_local", center)
	curved.set_meta("pool_corner_sweep", sweep)
	curved.set_meta("pool_corner_wall_top", wall_top)
	curved.set_meta("pool_corner_arm_a", a)
	curved.set_meta("pool_corner_arm_b", b)
	add_child(curved)

	# Matching convex sectors follow the same radii and angular samples as the
	# render mesh.  A single square collider would block the open side of the
	# bend; these ten small hulls preserve the actual rounded walkable space.
	_pool_corner_colliders(center, radial_start, sweep,
		inner_radius, outer_radius, wall_top)

	# The normal straight crown strips now stop at the tangent points.  Continue
	# each room-side strip around the curve at that room's own ceiling height.
	var quadrant := a + b
	var inner_cell := cell + Vector2i(
		1 if quadrant.x > 0 else 0,
		1 if quadrant.y > 0 else 0)
	_pool_corner_crown(center, radial_start, sweep,
		inner_radius - 0.10, inner_radius,
		cell_ceil_h(wseed, inner_cell, theme), inner_cell, "inner")

	# The two outer straight crowns can belong to different rooms and therefore
	# sit at different ceiling heights.  A single 90-degree curve cannot meet
	# both reliably.  Give each tangent its own 45-degree sector, using the
	# room actually touching that arm rather than the diagonally opposite room.
	var outer_a_quadrant := a - b
	var outer_b_quadrant := b - a
	var outer_a_cell := cell + Vector2i(
		1 if outer_a_quadrant.x > 0 else 0,
		1 if outer_a_quadrant.y > 0 else 0)
	var outer_b_cell := cell + Vector2i(
		1 if outer_b_quadrant.x > 0 else 0,
		1 if outer_b_quadrant.y > 0 else 0)
	var half_sweep := sweep * 0.5
	_pool_corner_crown(center, radial_start, half_sweep,
		outer_radius, outer_radius + 0.10,
		cell_ceil_h(wseed, outer_a_cell, theme), outer_a_cell, "outer_a")
	_pool_corner_crown(center, radial_start.rotated(half_sweep), half_sweep,
		outer_radius, outer_radius + 0.10,
		cell_ceil_h(wseed, outer_b_cell, theme), outer_b_cell, "outer_b")


## Room quadrants at a T/cross whose two bounding wall arms form a visible
## concave corner.  Pure L turns are handled by the continuous annulus above;
## applying an extra cove there would duplicate its inner curved face.
static func pool_inner_cove_quadrants(
		arms: Array[Vector2i]) -> Array[Vector2i]:
	var quadrants: Array[Vector2i] = []
	if arms.size() < 3:
		return quadrants
	for quadrant in [
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(-1, -1),
		Vector2i(1, -1),
	]:
		var arm_x := Vector2i(quadrant.x, 0)
		var arm_z := Vector2i(0, quadrant.y)
		if arms.has(arm_x) and arms.has(arm_z):
			quadrants.append(quadrant)
	return quadrants


func _pool_inner_coves(arms: Array[Vector2i]) -> void:
	for quadrant in pool_inner_cove_quadrants(arms):
		_pool_inner_cove(quadrant)


## Add one solid quarter-round cove on the room side of a T/cross.  The
## original straight walls remain uninterrupted; this wedge simply covers
## their square face intersection and supplies matching collision and crown.
func _pool_inner_cove(quadrant: Vector2i) -> void:
	var arm_x := Vector2i(quadrant.x, 0)
	var arm_z := Vector2i(0, quadrant.y)
	var qv := Vector2(float(quadrant.x), float(quadrant.y))
	var vertex := Vector2(S, S)
	var center := vertex + qv * POOL_PILLAR_RADIUS
	var radial_start := Vector2(0.0, -float(quadrant.y))
	var sweep := PI * 0.5 if radial_start.cross(
		Vector2(-float(quadrant.x), 0.0)) > 0.0 \
		else -PI * 0.5
	var face_offset := POOL_WALL_T * 0.5
	var radius := POOL_PILLAR_RADIUS - face_offset
	var corner := vertex + qv * face_offset
	var wall_top := maxf(
		_pool_corner_arm_top(arm_x), _pool_corner_arm_top(arm_z))
	var room_cell := cell + Vector2i(
		1 if quadrant.x > 0 else 0,
		1 if quadrant.y > 0 else 0)

	var cove := MeshInstance3D.new()
	cove.mesh = PoolCornerMesh.quarter_cove(
		center, radial_start, sweep, radius, corner,
		0.0, wall_top, POOL_CORNER_SEGMENTS)
	cove.material_override = Mats.pool_wall_tile()
	cove.set_meta("pool_inner_cove", true)
	cove.set_meta("pool_corner_radius", POOL_PILLAR_RADIUS)
	cove.set_meta("pool_corner_segments", POOL_CORNER_SEGMENTS)
	cove.set_meta("pool_corner_grid_vertex", cell + Vector2i(1, 1))
	cove.set_meta("pool_inner_cove_quadrant", quadrant)
	cove.set_meta("pool_inner_cove_center_local", center)
	cove.set_meta("pool_inner_cove_wall_top", wall_top)
	add_child(cove)

	_pool_inner_cove_colliders(
		center, radial_start, sweep, radius, corner, wall_top, quadrant)

	var crown := MeshInstance3D.new()
	crown.mesh = PoolCornerMesh.quarter_annulus(
		center, radial_start, sweep, maxf(radius - 0.10, 0.01), radius,
		cell_ceil_h(wseed, room_cell, theme) - 0.10,
		cell_ceil_h(wseed, room_cell, theme), POOL_CORNER_SEGMENTS)
	crown.material_override = Mats.crown()
	crown.set_meta("pool_crown", true)
	crown.set_meta("pool_inner_cove_crown", true)
	crown.set_meta("pool_corner_grid_vertex", cell + Vector2i(1, 1))
	crown.set_meta("pool_inner_cove_quadrant", quadrant)
	crown.set_meta("pool_inner_cove_crown_cell", room_cell)
	add_child(crown)


func _pool_inner_cove_colliders(center: Vector2,
		radial_start: Vector2, sweep: float, radius: float,
		corner: Vector2, wall_top: float, quadrant: Vector2i) -> void:
	var start := radial_start.normalized()
	var corner_bottom := Vector3(corner.x, 0.0, corner.y)
	var corner_top := corner_bottom + Vector3.UP * wall_top
	for i in POOL_CORNER_SEGMENTS:
		var u0 := start.rotated(
			sweep * float(i) / float(POOL_CORNER_SEGMENTS))
		var u1 := start.rotated(
			sweep * float(i + 1) / float(POOL_CORNER_SEGMENTS))
		var arc0 := Vector3(
			center.x + u0.x * radius, 0.0,
			center.y + u0.y * radius)
		var arc1 := Vector3(
			center.x + u1.x * radius, 0.0,
			center.y + u1.y * radius)
		var up := Vector3.UP * wall_top
		var shape := ConvexPolygonShape3D.new()
		shape.points = PackedVector3Array([
			corner_bottom, arc0, arc1,
			corner_top, arc0 + up, arc1 + up,
		])
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.set_meta("pool_inner_cove_collider", true)
		cs.set_meta("pool_inner_cove_sector", i)
		cs.set_meta("pool_corner_grid_vertex", cell + Vector2i(1, 1))
		cs.set_meta("pool_inner_cove_quadrant", quadrant)
		body.add_child(cs)


## Height of the canonical wall run represented by one outgoing corner arm.
func _pool_corner_arm_top(arm: Vector2i) -> float:
	var edge_cell := cell
	var dir := 0
	if arm == Vector2i(1, 0):
		edge_cell = cell + Vector2i(1, 0)
		dir = 2
	elif arm == Vector2i(-1, 0):
		dir = 2
	elif arm == Vector2i(0, 1):
		edge_cell = cell + Vector2i(0, 1)
		dir = 0
	else:
		dir = 0
	return maxf(
		cell_ceil_h(wseed, edge_cell, theme),
		cell_ceil_h(wseed, edge_cell + WorldGen.DIRV[dir], theme))


func _pool_corner_colliders(center: Vector2, radial_start: Vector2,
		sweep: float, inner_radius: float, outer_radius: float,
		wall_top: float) -> void:
	var start := radial_start.normalized()
	for i in POOL_CORNER_SEGMENTS:
		var u0 := start.rotated(
			sweep * float(i) / float(POOL_CORNER_SEGMENTS))
		var u1 := start.rotated(
			sweep * float(i + 1) / float(POOL_CORNER_SEGMENTS))
		var i0 := Vector3(
			center.x + u0.x * inner_radius, 0.0,
			center.y + u0.y * inner_radius)
		var i1 := Vector3(
			center.x + u1.x * inner_radius, 0.0,
			center.y + u1.y * inner_radius)
		var o0 := Vector3(
			center.x + u0.x * outer_radius, 0.0,
			center.y + u0.y * outer_radius)
		var o1 := Vector3(
			center.x + u1.x * outer_radius, 0.0,
			center.y + u1.y * outer_radius)
		var up := Vector3.UP * wall_top
		var shape := ConvexPolygonShape3D.new()
		shape.points = PackedVector3Array([
			i0, i1, o0, o1,
			i0 + up, i1 + up, o0 + up, o1 + up,
		])
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.set_meta("pool_corner_collider", true)
		cs.set_meta("pool_corner_sector", i)
		cs.set_meta("pool_corner_grid_vertex", cell + Vector2i(1, 1))
		body.add_child(cs)


func _pool_corner_crown(center: Vector2, radial_start: Vector2,
		sweep: float, radius0: float, radius1: float, room_ceil: float,
		room_cell: Vector2i, face: String) -> void:
	var crown := MeshInstance3D.new()
	crown.mesh = PoolCornerMesh.quarter_annulus(
		center, radial_start, sweep, radius0, radius1,
		room_ceil - 0.10, room_ceil, POOL_CORNER_SEGMENTS)
	crown.material_override = Mats.crown()
	crown.set_meta("pool_crown", true)
	crown.set_meta("pool_corner_crown", true)
	crown.set_meta("pool_corner_crown_face", face)
	crown.set_meta("pool_corner_crown_cell", room_cell)
	crown.set_meta("pool_corner_grid_vertex", cell + Vector2i(1, 1))
	add_child(crown)


## The finish a wall segment on this floor uses. Shared by _wall_seg and the
## open-edge ceiling fascia so the band can never drift from the walls it
## extends. The Annex picks per-edge finishes and stays inside _wall_seg.
func _wall_material() -> Material:
	if theme == 1:
		return Mats.office_wall_variant(_finish_variant())
	if theme == 4:
		return Mats.airport_wall_variant(_finish_variant())
	if theme == 5:
		return _level_builder._asy_wall_mat()
	if theme == 6:
		return _level_builder._sch_wall_mat()
	if theme == 7:
		return Mats.mall_wall()
	if theme == 8:
		return Mats.prison_tile() if style == WorldGen.PRISON_SHOWER \
			else Mats.prison_wall()
	if theme == 9:
		return Mats.pool_wall_tile()
	if theme == 10:
		return Mats.brutal_wall()
	if theme == 11:
		return Mats.bloom_wall()
	return Mats.wallpaper_variant(_finish_variant())


func _wall_seg(dir: int, plane: float, from: float, to: float, y0: float, y1: float) -> void:
	var wall_t := ANNEX_WALL_T if theme == 2 else (POOL_WALL_T if theme == 9 else T)
	var annex_t_stub_min := false
	var annex_t_stub_max := false
	var annex_t_winner_min := -1
	var annex_t_winner_max := -1
	var annex_boundary_min := false
	var annex_boundary_max := false
	var annex_cap_min := false
	var annex_cap_max := false
	var annex_endpoint_kind_min := ""
	var annex_endpoint_kind_max := ""
	if theme == 2:
		if is_zero_approx(from):
			var min_rule := _annex_corner_rule(dir, false)
			annex_boundary_min = true
			annex_cap_min = bool(min_rule["needs_cap"])
			annex_endpoint_kind_min = str(min_rule["kind"])
			from += float(min_rule["shift"])
			annex_t_stub_min = bool(min_rule["t_stub"])
			annex_t_winner_min = int(min_rule["winner_finish"])
		if is_equal_approx(to, S):
			var max_rule := _annex_corner_rule(dir, true)
			annex_boundary_max = true
			annex_cap_max = bool(max_rule["needs_cap"])
			annex_endpoint_kind_max = str(max_rule["kind"])
			to += float(max_rule["shift"])
			annex_t_stub_max = bool(max_rule["t_stub"])
			annex_t_winner_max = int(max_rule["winner_finish"])
	# Pool boundary ends are resolved once per vertex. True L-turns retract
	# both straight runs to the shared tangent radius, where one quarter-annulus
	# joins them. T stubs stop at the through wall's near face; straight runs
	# and free ends remain flush with the cell boundary.
	if theme == 9:
		if is_zero_approx(from):
			from -= _pool_boundary_rule(dir, false)
		if is_equal_approx(to, S):
			to += _pool_boundary_rule(dir, true)
	# A T-stub is closed by the uninterrupted face of the longer perpendicular
	# wall. Rendering a cap here would put a second coplanar face over that
	# winner and resurrect both the finish rectangle and distance-dependent
	# flashing. Genuine doorway cuts and L-corners still receive their caps.
	var cap_min := (annex_cap_min if annex_boundary_min \
		else not is_zero_approx(from)) and not annex_t_stub_min
	var cap_max := (annex_cap_max if annex_boundary_max \
		else not is_equal_approx(to, S)) and not annex_t_stub_max
	var ln := to - from
	# A few low-ceiling themes can place their nominal door-head height at or
	# above the local ceiling. That means there is no header to build; passing
	# the negative height to BoxShape3D only produces an invalid collider.
	if ln < 0.05 or y1 - y0 < 0.05:
		return
	var c := (from + to) * 0.5
	var yc := (y0 + y1) * 0.5
	var hh := y1 - y0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (wall_t * 0.5)
	var annex_finish := -1
	var annex_raw_finish := -1
	var annex_treatment_owner := "collinear_line"
	var annex_line_winner_min := -1
	var annex_line_winner_max := -1
	var wmat: Material = _wall_material()
	if theme == 2:
		# Resolve the treatment for the complete edge, never for an individual
		# mesh produced by a door cut. A continuous perpendicular wall wins at
		# a T-junction, including both wallpaper and its baseboard.
		var treatment := _annex_resolved_wall_treatment(dir)
		annex_raw_finish = int(treatment["raw_finish"])
		annex_finish = int(treatment["finish"])
		annex_treatment_owner = str(treatment["owner"])
		annex_line_winner_min = int(treatment["winner_min"])
		annex_line_winner_max = int(treatment["winner_max"])
		wmat = Mats.annex_wall_variant(annex_finish)
	var wall_mesh: MeshInstance3D
	if dir < 2:
		if theme == 2:
			wall_mesh = _annex_wall_prism(Vector3(plane, yc, c),
				Vector3(wall_t, hh, ln), false,
				cap_min, cap_max, wmat)
		else:
			wall_mesh = _box(
				Vector3(plane, yc, c), Vector3(wall_t, hh, ln), wmat)
		if theme == 2:
			_level_builder._annex_register_ceiling_obstruction(
				Vector3(plane, 0.0, c), wall_t, ln, 0.0, y1)
	else:
		if theme == 2:
			wall_mesh = _annex_wall_prism(Vector3(c, yc, plane),
				Vector3(ln, hh, wall_t), true,
				cap_min, cap_max, wmat)
		else:
			wall_mesh = _box(
				Vector3(c, yc, plane), Vector3(ln, hh, wall_t), wmat)
		if theme == 2:
			_level_builder._annex_register_ceiling_obstruction(
				Vector3(c, 0.0, plane), ln, wall_t, 0.0, y1)
	record_occluder_wall(wall_mesh)
	if theme == 9:
		# Final extents let the audit verify the topology contract: true L ends
		# stop at their common curved-corner tangent radius, T stubs stop at
		# the through wall's near face, and other ends stay on their grid/cut.
		wall_mesh.set_meta("pool_wall_dir", dir)
		wall_mesh.set_meta("pool_wall_from", from)
		wall_mesh.set_meta("pool_wall_to", to)
		wall_mesh.set_meta("pool_wall_y0", y0)
	if theme == 2:
		wall_mesh.set_meta("annex_wall_thickness", wall_t)
		wall_mesh.set_meta("annex_wall_seam_safe", true)
		wall_mesh.set_meta("annex_wall_cap_min", cap_min)
		wall_mesh.set_meta("annex_wall_cap_max", cap_max)
		if annex_boundary_min:
			wall_mesh.set_meta(
				"annex_boundary_endpoint_kind_min", annex_endpoint_kind_min)
		if annex_boundary_max:
			wall_mesh.set_meta(
				"annex_boundary_endpoint_kind_max", annex_endpoint_kind_max)
		wall_mesh.set_meta("annex_raw_finish", annex_raw_finish)
		wall_mesh.set_meta("annex_finish", annex_finish)
		wall_mesh.set_meta("annex_wallpaper", annex_finish >= 3)
		wall_mesh.set_meta("annex_visual_wall_owner", annex_treatment_owner)
		wall_mesh.set_meta(
			"annex_line_t_winner_finish_min", annex_line_winner_min)
		wall_mesh.set_meta(
			"annex_line_t_winner_finish_max", annex_line_winner_max)
		if annex_t_winner_min >= 0 or annex_t_winner_max >= 0:
			wall_mesh.set_meta(
				"annex_t_junction_face_owner", "perpendicular_wall")
		if annex_t_stub_min:
			wall_mesh.set_meta("annex_t_junction_stub_min", true)
			wall_mesh.set_meta(
				"annex_t_junction_winner_finish_min", annex_t_winner_min)
			wall_mesh.set_meta(
				"annex_t_junction_winner_baseboard_min",
				annex_t_winner_min >= 3)
		if annex_t_stub_max:
			wall_mesh.set_meta("annex_t_junction_stub_max", true)
			wall_mesh.set_meta(
				"annex_t_junction_winner_finish_max", annex_t_winner_max)
			wall_mesh.set_meta(
				"annex_t_junction_winner_baseboard_max",
				annex_t_winner_max >= 3)
		if y0 <= 0.01:
			# EVERY Annex wall is skirted, papered or plain. Tying trim to the
			# wallpaper meant a room's walls could differ from each other and
			# from the wall opposite, and that inconsistency read as broken
			# geometry rather than as decoration.
			var outer := plane - n * wall_t * 0.5
			# A face run overlaps an exposed end by its own projection so that
			# it meets the trim turning the corner. Stopping dead on the face
			# plane left an unfilled notch at every outside corner.
			var ext_min := ANNEX_BASEBOARD_D if cap_min else 0.0
			var ext_max := ANNEX_BASEBOARD_D if cap_max else 0.0
			var trim_len := ln + ext_min + ext_max
			var trim_c := c + (ext_max - ext_min) * 0.5
			if dir < 2:
				_annex_baseboard_box(
					Vector3(inner + n * ANNEX_BASEBOARD_D * 0.5,
						ANNEX_BASEBOARD_H * 0.5, trim_c),
					Vector3(ANNEX_BASEBOARD_D, ANNEX_BASEBOARD_H, trim_len))
				_annex_baseboard_box(
					Vector3(outer - n * ANNEX_BASEBOARD_D * 0.5,
						ANNEX_BASEBOARD_H * 0.5, trim_c),
					Vector3(ANNEX_BASEBOARD_D, ANNEX_BASEBOARD_H, trim_len))
				# The skirting continues around an exposed end, so a papered
				# wall's tip is trimmed like the rest of it.
				if cap_min:
					_annex_baseboard_box(
						Vector3(plane, ANNEX_BASEBOARD_H * 0.5,
							from - ANNEX_BASEBOARD_D * 0.5),
						Vector3(wall_t + ANNEX_BASEBOARD_D * 2.0,
							ANNEX_BASEBOARD_H, ANNEX_BASEBOARD_D))
				if cap_max:
					_annex_baseboard_box(
						Vector3(plane, ANNEX_BASEBOARD_H * 0.5,
							to + ANNEX_BASEBOARD_D * 0.5),
						Vector3(wall_t + ANNEX_BASEBOARD_D * 2.0,
							ANNEX_BASEBOARD_H, ANNEX_BASEBOARD_D))
			else:
				_annex_baseboard_box(
					Vector3(trim_c, ANNEX_BASEBOARD_H * 0.5,
						inner + n * ANNEX_BASEBOARD_D * 0.5),
					Vector3(trim_len, ANNEX_BASEBOARD_H, ANNEX_BASEBOARD_D))
				_annex_baseboard_box(
					Vector3(trim_c, ANNEX_BASEBOARD_H * 0.5,
						outer - n * ANNEX_BASEBOARD_D * 0.5),
					Vector3(trim_len, ANNEX_BASEBOARD_H, ANNEX_BASEBOARD_D))
				if cap_min:
					_annex_baseboard_box(
						Vector3(from - ANNEX_BASEBOARD_D * 0.5,
							ANNEX_BASEBOARD_H * 0.5, plane),
						Vector3(ANNEX_BASEBOARD_D, ANNEX_BASEBOARD_H,
							wall_t + ANNEX_BASEBOARD_D * 2.0))
				if cap_max:
					_annex_baseboard_box(
						Vector3(to + ANNEX_BASEBOARD_D * 0.5,
							ANNEX_BASEBOARD_H * 0.5, plane),
						Vector3(ANNEX_BASEBOARD_D, ANNEX_BASEBOARD_H,
							wall_t + ANNEX_BASEBOARD_D * 2.0))
		return
	if theme == 9:
		# Crown on BOTH faces: the canonical wall's owner builds for its
		# neighbour's room too, each strip at its own room's ceiling. The
		# old fall-through to the vegas trim set also laid darkwood
		# baseboards, all underwater or buried inside the dry slab; dropped.
		if y1 >= ceil_h - 0.01:
			_level_builder._pool_crown_trims(dir, plane, from, to)
		return
	if theme == 5:
		# tiled wainscot to shoulder height — unless the whole room is tiled
		if y0 <= 0.01 and not _level_builder._asy_tiled_room():
			_strip(dir, inner + n * 0.03, 0.7, c, ln, 0.05, 1.4, Mats.asy_tile())
		return
	if theme == 6:
		# the red line, painted at the same height through the whole building,
		# and a rubber cove base under it
		if y0 <= 0.01:
			_strip(dir, inner + n * 0.02, SCH_BAND, c, ln, 0.04, 0.17, Mats.sch_red())
			_strip(dir, inner + n * 0.025, 0.06, c, ln, 0.05, 0.12, Mats.charcoal())
		return
	if theme == 7:
		if y0 <= 0.01:
			_strip(dir, inner + n * 0.025, 0.075, c, ln, 0.05, 0.15, Mats.mall_trim())
			_strip(dir, inner + n * 0.018, 1.18, c, ln, 0.035, 0.045, Mats.brass())
		return
	if theme == 8:
		if y0 <= 0.01:
			# green paint to shoulder height over bare concrete, iron base
			if style != WorldGen.PRISON_SHOWER:
				_strip(dir, inner + n * 0.012, 0.72, c, ln, 0.025, 1.44, Mats.prison_dado())
			_strip(dir, inner + n * 0.025, 0.08, c, ln, 0.055, 0.16, Mats.prison_iron())
		return
	if theme == 4:
		# stainless kick guard where trolleys graze the wall
		if y0 <= 0.01:
			_strip(dir, inner + n * 0.025, 0.09, c, ln, 0.05, 0.18, Mats.steel())
		return
	if theme == 1:
		# Office walls meet the carpet directly. The former dark green
		# baseboard read as detached black bars around every room.
		return
	# vegas trim set: crown, baseboard, chair rail
	if y1 >= ceil_h - 0.01:
		_strip(dir, inner + n * 0.05, ceil_h - 0.05, c, ln, 0.1, 0.1, Mats.crown())
	if y0 <= 0.01:
		_strip(dir, inner + n * 0.028, 0.075, c, ln, 0.055, 0.15, Mats.darkwood())
		_strip(dir, inner + n * 0.02, 1.0, c, ln, 0.04, 0.08, Mats.darkwood())


func _strip(dir: int, off: float, y: float, c: float, ln: float, depth: float, height: float, mat: Material) -> void:
	if dir < 2:
		_box(Vector3(off, y, c), Vector3(depth, height, ln), mat, false)
	else:
		_box(Vector3(c, y, off), Vector3(ln, height, depth), mat, false)


func _configure_annex_non_occluding(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for child in node.get_children():
		_configure_annex_non_occluding(child)


func _configure_annex_baseboard(trim: MeshInstance3D, size: Vector3) -> void:
	# This 2cm decorative projection produced an implausibly broad wedge under
	# the Annex's many overhead lights. The substantial wall still casts the
	# room shadow; the painted skirting should not add a second detached one.
	_configure_annex_non_occluding(trim)
	trim.set_meta("annex_baseboard", true)
	trim.set_meta("annex_baseboard_height", size.y)
	trim.set_meta("annex_baseboard_projection", minf(size.x, size.z))
	trim.set_meta("annex_baseboard_attached", true)


func _annex_baseboard_box(pos: Vector3, size: Vector3) -> MeshInstance3D:
	var trim := _box(pos, size, Mats.annex_baseboard(), false)
	_configure_annex_baseboard(trim, size)
	return trim


func _annex_local_baseboard(parent: Node3D, pos: Vector3,
		size: Vector3) -> void:
	var trim := _mbox(parent, pos, size, Mats.annex_baseboard())
	_configure_annex_baseboard(trim, size)


## Wallpaper on a freestanding partition or deep wall mass is one treatment
## around the whole piece, so its skirting runs along both long faces and, when
## the ends are broad enough to be walls rather than reveals, around those too.
func _annex_wrap_local_baseboards(parent: Node3D, width: float,
		depth: float, omit_min_x := false, omit_max_x := false) -> void:
	var y := ANNEX_BASEBOARD_H * 0.5
	var d := ANNEX_BASEBOARD_D
	# Face runs reach past the piece by one projection at each un-omitted end,
	# so they meet the end returns and the outside corners close.
	var fw := width + (0.0 if omit_max_x else d) + (0.0 if omit_min_x else d)
	var fc := ((0.0 if omit_max_x else d) - (0.0 if omit_min_x else d)) * 0.5
	_annex_local_baseboard(parent,
		Vector3(fc, y, depth * 0.5 + d * 0.5),
		Vector3(fw, ANNEX_BASEBOARD_H, d))
	_annex_local_baseboard(parent,
		Vector3(fc, y, -depth * 0.5 - d * 0.5),
		Vector3(fw, ANNEX_BASEBOARD_H, d))
	if not omit_max_x:
		_annex_local_baseboard(parent,
			Vector3(width * 0.5 + d * 0.5, y, 0.0),
			Vector3(d, ANNEX_BASEBOARD_H, depth + d * 2.0))
	if not omit_min_x:
		_annex_local_baseboard(parent,
			Vector3(-width * 0.5 - d * 0.5, y, 0.0),
			Vector3(d, ANNEX_BASEBOARD_H, depth + d * 2.0))


func _door_casing(dir: int, plane: float, a: float, b: float) -> void:
	# Pool openings are cut straight through tile — no frame, no threshold.
	if theme == 9:
		return
	if theme == 10:
		# The Data Center cuts a 3.15m portal. Its old generic casing stopped at
		# DOOR_TOP (2.25m), leaving a conspicuous 90cm strip of naked opening
		# above the lintel. Build one substantial cast-concrete surround to the
		# exact same datum as the wall cut.
		var cm := Mats.brutal_structure()
		var top := BRUTAL_DOOR_TOP
		var jamb := 0.30
		var depth := T + 0.28
		var pieces: Array[MeshInstance3D] = []
		if dir < 2:
			pieces.append(_box(Vector3(plane, top * 0.5, a),
				Vector3(depth, top, jamb), cm, false))
			pieces.append(_box(Vector3(plane, top * 0.5, b),
				Vector3(depth, top, jamb), cm, false))
			pieces.append(_box(Vector3(plane, top + jamb * 0.5, (a + b) * 0.5),
				Vector3(depth, jamb, b - a + jamb), cm, false))
		else:
			pieces.append(_box(Vector3(a, top * 0.5, plane),
				Vector3(jamb, top, depth), cm, false))
			pieces.append(_box(Vector3(b, top * 0.5, plane),
				Vector3(jamb, top, depth), cm, false))
			pieces.append(_box(Vector3((a + b) * 0.5, top + jamb * 0.5, plane),
				Vector3(b - a + jamb, jamb, depth), cm, false))
		for piece in pieces:
			piece.set_meta("brutal_door_casing", true)
			piece.set_meta("brutal_door_head", top)
		return
	if theme == 11:
		# A clean black-steel frame remains a reliable route cue beneath the
		# overgrowth. The cut and surround share the same 2.55m head datum.
		var cm := Mats.bloom_metal()
		var top := BLOOM_DOOR_TOP
		var jamb := 0.12
		var depth := T + 0.16
		if dir < 2:
			_box(Vector3(plane, top * 0.5, a), Vector3(depth, top, jamb), cm, false)
			_box(Vector3(plane, top * 0.5, b), Vector3(depth, top, jamb), cm, false)
			_box(Vector3(plane, top + jamb * 0.5, (a + b) * 0.5),
				Vector3(depth, jamb, b - a + jamb), cm, false)
		else:
			_box(Vector3(a, top * 0.5, plane), Vector3(jamb, top, depth), cm, false)
			_box(Vector3(b, top * 0.5, plane), Vector3(jamb, top, depth), cm, false)
			_box(Vector3((a + b) * 0.5, top + jamb * 0.5, plane),
				Vector3(b - a + jamb, jamb, depth), cm, false)
		return
	if theme == 7 or theme == 8:
		var cm: Material = Mats.mall_trim() if theme == 7 else Mats.prison_iron()
		var top := 3.15 if theme == 7 else DOOR_TOP
		var depth := 0.22 if theme == 7 else 0.18
		if dir < 2:
			_box(Vector3(plane, top * 0.5, a), Vector3(T + depth, top, depth), cm, false)
			_box(Vector3(plane, top * 0.5, b), Vector3(T + depth, top, depth), cm, false)
			_box(Vector3(plane, top + 0.10, (a + b) * 0.5),
				Vector3(T + depth, 0.20, b - a + depth), cm, false)
		else:
			_box(Vector3(a, top * 0.5, plane), Vector3(depth, top, T + depth), cm, false)
			_box(Vector3(b, top * 0.5, plane), Vector3(depth, top, T + depth), cm, false)
			_box(Vector3((a + b) * 0.5, top + 0.10, plane),
				Vector3(b - a + depth, 0.20, T + depth), cm, false)
		return
	if theme == 4:
		# brushed-steel portal surround, airport-tall
		var sm := Mats.steel()
		if dir < 2:
			_box(Vector3(plane, AIR_DOOR * 0.5, a - 0.02), Vector3(T + 0.2, AIR_DOOR, 0.26), sm)
			_box(Vector3(plane, AIR_DOOR * 0.5, b + 0.02), Vector3(T + 0.2, AIR_DOOR, 0.26), sm)
			_box(Vector3(plane, AIR_DOOR + 0.12, (a + b) * 0.5), Vector3(T + 0.2, 0.26, b - a + 0.3), sm, false)
		else:
			_box(Vector3(a - 0.02, AIR_DOOR * 0.5, plane), Vector3(0.26, AIR_DOOR, T + 0.2), sm)
			_box(Vector3(b + 0.02, AIR_DOOR * 0.5, plane), Vector3(0.26, AIR_DOOR, T + 0.2), sm)
			_box(Vector3((a + b) * 0.5, AIR_DOOR + 0.12, plane), Vector3(b - a + 0.3, 0.26, T + 0.2), sm, false)
		return
	if theme == 2:
		# The 30cm native wall segments already expose substantial returns at
		# the opening. Extra jamb/lintel boxes sat directly on those surfaces,
		# producing a thin distance-dependent ridge that vanished up close.
		return
	if theme == 5:
		# chipped green steel frame, a size heavier than it needs to be
		var gm := Mats.asy_metal_green()
		if dir < 2:
			_box(Vector3(plane, DOOR_TOP * 0.5, a), Vector3(T + 0.16, DOOR_TOP, 0.2), gm, false)
			_box(Vector3(plane, DOOR_TOP * 0.5, b), Vector3(T + 0.16, DOOR_TOP, 0.2), gm, false)
			_box(Vector3(plane, DOOR_TOP + 0.09, (a + b) * 0.5), Vector3(T + 0.16, 0.18, b - a + 0.2), gm, false)
		else:
			_box(Vector3(a, DOOR_TOP * 0.5, plane), Vector3(0.2, DOOR_TOP, T + 0.16), gm, false)
			_box(Vector3(b, DOOR_TOP * 0.5, plane), Vector3(0.2, DOOR_TOP, T + 0.16), gm, false)
			_box(Vector3((a + b) * 0.5, DOOR_TOP + 0.09, plane), Vector3(b - a + 0.2, 0.18, T + 0.16), gm, false)
		return
	if theme == 6:
		# painted steel frame, and the door itself parked open against the wall
		var rm := Mats.sch_red()
		if dir < 2:
			_box(Vector3(plane, DOOR_TOP * 0.5, a), Vector3(T + 0.14, DOOR_TOP, 0.17), rm, false)
			_box(Vector3(plane, DOOR_TOP * 0.5, b), Vector3(T + 0.14, DOOR_TOP, 0.17), rm, false)
			_box(Vector3(plane, DOOR_TOP + 0.08, (a + b) * 0.5), Vector3(T + 0.14, 0.16, b - a + 0.17), rm, false)
		else:
			_box(Vector3(a, DOOR_TOP * 0.5, plane), Vector3(0.17, DOOR_TOP, T + 0.14), rm, false)
			_box(Vector3(b, DOOR_TOP * 0.5, plane), Vector3(0.17, DOOR_TOP, T + 0.14), rm, false)
			_box(Vector3((a + b) * 0.5, DOOR_TOP + 0.08, plane), Vector3(b - a + 0.17, 0.16, T + 0.14), rm, false)
		return
	var head_y := DOOR_TOP + 0.07
	var cmat: Material = Mats.paint_white() if theme == 1 else Mats.darkwood()
	if dir < 2:
		_box(Vector3(plane, DOOR_TOP * 0.5, a), Vector3(T + 0.12, DOOR_TOP, 0.16), cmat, false)
		_box(Vector3(plane, DOOR_TOP * 0.5, b), Vector3(T + 0.12, DOOR_TOP, 0.16), cmat, false)
		_box(Vector3(plane, head_y, (a + b) * 0.5), Vector3(T + 0.12, 0.14, b - a + 0.16), cmat, false)
	else:
		_box(Vector3(a, DOOR_TOP * 0.5, plane), Vector3(0.16, DOOR_TOP, T + 0.12), cmat, false)
		_box(Vector3(b, DOOR_TOP * 0.5, plane), Vector3(0.16, DOOR_TOP, T + 0.12), cmat, false)
		_box(Vector3((a + b) * 0.5, head_y, plane), Vector3(b - a + 0.16, 0.14, T + 0.12), cmat, false)


func _exit_sign(dir: int, t: float) -> void:
	# Only built by the canonical (east/north) owner of the edge.
	# Mall openings are substantially taller than the other themes. Their exit
	# cabinet hangs just below the head on two real ceiling rods; the old sign
	# occupied the same open air with no visible means of support.
	var opening_head := AIR_DOOR if theme == 7 else DOOR_TOP
	# Conventional wall-mounted cabinets sit entirely above the lintel. The
	# former centre at opening_head + 0.16 buried most of the cabinet in the
	# overhead wall and door casing, leaving only its red light visible.
	var sign_height := 0.24
	var lintel_clearance := 0.045
	if theme != 7:
		# Build upward from the lintel. Standard rooms retain a full EXIT
		# cabinet and a generous ceiling gap; exceptionally low rooms slim the
		# cabinet and its lintel gap so the now larger alarm still fits whole.
		var stack_room := ceil_h - ALARM_MIN_CEILING_CLEARANCE \
			- ALARM_FITTED_HEIGHT - ALARM_SIGN_CLEARANCE - opening_head
		lintel_clearance = clampf(stack_room - 0.02, 0.008, 0.045)
		sign_height = clampf(stack_room - lintel_clearance, 0.005, 0.12)
	var y := opening_head - 0.18 if theme == 7 \
		else opening_head + lintel_clearance + sign_height * 0.5
	var normal_depth := 0.09 if theme == 7 else 0.22
	var base: Vector3
	var hsize: Vector3
	if dir == 0:
		base = Vector3(S, y, t)
		hsize = Vector3(normal_depth, sign_height, 0.62)
	else:
		base = Vector3(t, y, S)
		hsize = Vector3(0.62, sign_height, normal_depth)
	var housing := _box(base, hsize, Mats.sign_housing(), false)
	var normal_half_extent := normal_depth * 0.5
	var face_offset := normal_half_extent + 0.008
	housing.set_meta("structural_exit_housing", true)
	housing.set_meta("opening_head", opening_head)
	housing.set_meta("sign_bottom", y - sign_height * 0.5)
	housing.set_meta("sign_top", y + sign_height * 0.5)
	housing.set_meta("normal_half_extent", normal_half_extent)
	housing.set_meta("face_offset", face_offset)
	if theme == 7:
		housing.set_meta("mall_exit_mount", true)
		housing.set_meta("hanger_count", 2)
		var sign_top := y + hsize.y * 0.5
		var hanger_h := maxf(0.08, ceil_h - sign_top)
		for side in [-1.0, 1.0]:
			var hp := base
			if dir == 0:
				hp.z += side * 0.20
			else:
				hp.x += side * 0.20
			hp.y = sign_top + hanger_h * 0.5
			var rod := _cyl(hp, 0.012, hanger_h, Mats.mall_trim(), false)
			rod.set_meta("mall_exit_hanger", true)
			var plate_pos := hp
			plate_pos.y = ceil_h - 0.015
			var plate := _box(plate_pos, Vector3(0.10, 0.03, 0.10),
				Mats.mall_trim(), false)
			plate.set_meta("mall_exit_hanger", true)
	for sside in [-1.0, 1.0]:
		var lb := Label3D.new()
		lb.text = "EXIT"
		lb.font_size = 96
		lb.pixel_size = 0.0016
		lb.outline_size = 0
		lb.modulate = Color(1.0, 0.22, 0.15)
		lb.set_meta("structural_exit_label", true)
		if dir == 0:
			lb.position = base + Vector3(sside * face_offset, 0, 0)
			lb.rotation.y = PI / 2.0 if sside > 0.0 else -PI / 2.0
		else:
			lb.position = base + Vector3(0, 0, sside * face_offset)
			lb.rotation.y = 0.0 if sside > 0.0 else PI
		add_child(lb)
		# Mall EXIT lettering is self-lit. Its old shadowless Omni had no
		# visible bulb and painted a floating red patch on the ceiling; global
		# power sags then made that patch flash independently of the cabinet.
		# Other floors put that spill at a visible alarm lens.
		if theme != 7:
			_exit_alarm(lb.position, lb.rotation.y, y + sign_height * 0.5,
				opening_head)


## Centre and wall-align the supplied alarm by its imported mesh bounds. The
## source hierarchy carries several offset conversion transforms, so placing
## its raw origin made the light effectively invisible even though its red
## Omni still painted the wall and ceiling.
func _exit_alarm(face_pos: Vector3, yaw: float, sign_top: float,
		opening_head: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = face_pos
	pivot.rotation.y = yaw
	pivot.set_meta("structural_exit_alarm", true)
	pivot.set_meta("attributed_asset", ALARM_PATH)
	add_child(pivot)
	var model := _attributed_prop_local(pivot, ALARM_PATH, Vector3.ZERO,
		0.0, Vector3.ONE * ALARM_SCALE)
	if model == null:
		remove_child(pivot)
		pivot.free()
		return null
	# The source's flat mounting plate is normal to local +X, while this
	# placement frame expects local +Z to point out of the wall. Turn the model
	# left so the plate is flush and the lamp projects into the room.
	model.rotation.y = -PI / 2.0
	pivot.set_meta("alarm_mount_yaw", -PI / 2.0)
	var state := [AABB(), false]
	_collect_model_bounds(model, Transform3D.IDENTITY, state)
	if not bool(state[1]):
		remove_child(pivot)
		pivot.free()
		return null
	var bounds: AABB = state[0]
	var height := bounds.size.y
	# Local +Z faces away from the mounting plate and into the room.
	model.position = Vector3(-bounds.get_center().x, -bounds.get_center().y,
		-bounds.position.z + 0.012)
	pivot.position.y = minf(
		opening_head + 0.035 + height * 0.5,
		ceil_h - ALARM_MIN_CEILING_CLEARANCE - height * 0.5)
	pivot.set_meta("alarm_bottom", pivot.position.y - height * 0.5)
	pivot.set_meta("alarm_top", pivot.position.y + height * 0.5)
	pivot.set_meta("alarm_depth", bounds.size.z)
	pivot.set_meta("alarm_height", height)
	pivot.set_meta("alarm_sign_top", sign_top)
	pivot.set_meta("alarm_opening_head", opening_head)
	model.set_meta("authored_model", "alarm_light")

	var light := OmniLight3D.new()
	light.set_meta("structural_exit_light", true)
	light.light_color = Color(1.0, 0.055, 0.035)
	light.light_energy = 0.22
	light.omni_range = 1.45
	# The spill now starts at the physical lens rather than inside the wall.
	light.position = Vector3(0, -height * 0.08, bounds.size.z + 0.065)
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 10.0
	light.distance_fade_length = 5.0
	pivot.add_child(light)
	return pivot


# --- wall decoration ---------------------------------------------------------

## Top of the wall's horizontal banding, or 0 where a theme has none. These
## match the strips laid down in `_build_walls`: the asylum's tiled wainscot,
## the school's red line, the mall's brass rail and the prison's green dado.
##
## Anything mounted on a banded wall clears the boundary by `WALL_BAND_CLEAR`
## rather than straddling it. A picture hung across a wainscot, or a payphone
## housing cut in half by a brass rail, reads as a mistake rather than as
## something someone installed.
const WALL_BAND_CLEAR := 0.11


func _wall_band_top() -> float:
	match theme:
		0:
			# Vegas chair rail: centre 1.00m, 0.08m tall.
			return 1.04
		5:
			return 0.0 if _level_builder._asy_tiled_room() else 1.40
		6:
			return 1.51
		7:
			return 1.21
		8:
			return 0.0 if style == WorldGen.PRISON_SHOWER else 1.44
	return 0.0


func _wall_art_pool() -> Array:
	match theme:
		0: return ART_VEGAS
		1: return POSTER_OFFICE
		2: return POSTER_ANNEX
		4: return POSTER_AIRPORT
		5: return POSTER_ASYLUM
		6: return POSTER_SCHOOL
		7: return POSTER_MALL
		8: return POSTER_PRISON
	return []


func _wall_art_path(salt: int) -> String:
	var pool: Array = _wall_art_pool()
	if pool.is_empty():
		pool = ART_RANDOM
	var pick := posmod(WorldGen.h(wseed, cell.x, cell.y, salt), pool.size())
	return str(pool[pick])


func _wall_art_fit(path: String, max_size: Vector2) -> Vector2:
	var tex := Mats.wall_art_texture(path)
	if tex == null or tex.get_height() <= 0:
		return max_size
	var aspect := float(tex.get_width()) / float(tex.get_height())
	var w := minf(max_size.x, max_size.y * aspect)
	var h := w / aspect
	if h > max_size.y:
		h = max_size.y
		w = h * aspect
	return Vector2(w, h)


## Mount a painting in local picture-plane coordinates. `pos` is the artwork
## face, local +Z points into the room, and aspect ratio is always preserved.
## The supplied paintings already depict their own frames, so the mount adds
## no second procedural surround.
func _wall_art_mount(pos: Vector3, yaw: float, dir: int, path: String,
		max_size: Vector2, tilt: float) -> Node3D:
	var size := _wall_art_fit(path, max_size)
	var v := Node3D.new()
	v.position = pos
	v.rotation.y = yaw
	v.rotation.z = tilt
	v.set_meta("wall_art_mount", true)
	v.set_meta("wall_art_path", path)
	v.set_meta("wall_art_dir", dir)
	v.set_meta("wall_art_aspect", size.x / size.y)
	v.set_meta("wall_art_size", size)
	var tex := Mats.wall_art_texture(path)
	v.set_meta("wall_art_source_aspect",
		float(tex.get_width()) / float(tex.get_height()) if tex != null else 1.0)
	add_child(v)
	var art := _mquad(v, Vector3(0, 0, 0.012), size, Mats.wall_art(path))
	art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return v


func _wall_art_chance() -> float:
	if theme == 9:
		return 0.0
	match theme:
		1:
			return 0.62 if style == WorldGen.OFFICE_STORAGE else 0.72
		2:
			return 0.55 if style == WorldGen.ANNEX_PASSAGE else 0.65
		4:
			return 0.22
		5:
			return 0.52
		6:
			return 0.56
		7:
			# Mall art belongs in the poster-case system below. General mounts
			# can be physically valid yet wind up hidden behind store shelving.
			return 0.0
		8:
			return 0.50
	return 0.0


## Classroom and laboratory front walls are authored later by the School
## builder. Reserve the exact deterministic board wall before general wall
## decoration runs so a poster can never be hidden behind the chalkboard.
func _school_chalkboard_wall() -> int:
	if theme != 6:
		return -1
	if style == WorldGen.SCH_CLASSROOM:
		return _level_builder._sch_front_wall(72)
	if style == WorldGen.SCH_LAB:
		return _level_builder._sch_front_wall(710)
	return -1


## Exact wall-plane rectangle of the Office painting that a member chunk will
## generate, or an empty dictionary when that wall owns no painting. Room-root
## fixtures use this before sibling chunks exist, so AC placement and art share
## one deterministic answer instead of discovering their collision afterward.
func _office_wall_art_layout(member: Vector2i, dir: int) -> Dictionary:
	if theme != 1:
		return {}
	var member_style := WorldGen.cell_style(wseed, member, theme)
	var chance := 0.62 if member_style == WorldGen.OFFICE_STORAGE else 0.72
	if WorldGen.r01(wseed, member.x, member.y, 1040 + dir) >= chance:
		return {}
	var salt := 1060 + dir * 7
	var path := str(POSTER_OFFICE[posmod(
		WorldGen.h(wseed, member.x, member.y, salt), POSTER_OFFICE.size())])
	var size := _wall_art_fit(path, Vector2(1.72, 1.34))
	var along := -1.0
	var split := _resolved_room_split_for(member)
	for candidate_idx in 6:
		var candidate := lerpf(0.42 + size.x * 0.5,
			S - 0.42 - size.x * 0.5,
			WorldGen.r01(wseed, member.x, member.y,
				salt + 2 + candidate_idx * 17))
		var partition_hits_wall := not split.is_empty() \
			and ((bool(split[0]) and dir < 2) \
				or (not bool(split[0]) and dir >= 2))
		if partition_hits_wall \
				and absf(candidate - float(split[1])) < size.x * 0.5 + 0.30:
			continue
		along = candidate
		break
	if along < 0.0:
		return {}
	var member_ceil := cell_ceil_h(wseed, member, theme)
	var y := minf(1.92, member_ceil - size.y * 0.5 - 0.30)
	y = maxf(y, size.y * 0.5 + 0.48)
	return {
		"path": path,
		"size": size,
		"along": along,
		"y": y,
	}


func _wall_art(dir: int, plane: float, salt: int) -> void:
	var office_layout := _office_wall_art_layout(cell, dir) if theme == 1 else {}
	var path := str(office_layout["path"]) if not office_layout.is_empty() \
		else _wall_art_path(salt)
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var wall_t := ANNEX_WALL_T if theme == 2 else T
	var inner := plane + n * (wall_t / 2.0)
	var max_size := Vector2(1.90, 1.38) if theme == 0 \
		else Vector2(1.72, 1.34)
	var size: Vector2 = office_layout["size"] if not office_layout.is_empty() \
		else _wall_art_fit(path, max_size)
	var along := float(office_layout["along"]) \
		if not office_layout.is_empty() else -1.0
	if office_layout.is_empty():
		var split := _resolved_room_split()
		for candidate_idx in 6:
			var candidate := lerpf(0.42 + size.x * 0.5,
				S - 0.42 - size.x * 0.5,
				_r(salt + 2 + candidate_idx * 17))
			var partition_hits_wall := not split.is_empty() \
				and ((bool(split[0]) and dir < 2) \
					or (not bool(split[0]) and dir >= 2))
			if partition_hits_wall \
					and absf(candidate - float(split[1])) < size.x * 0.5 + 0.30:
				continue
			along = candidate
			break
	if along < 0.0:
		return
	# A 1.92m centre keeps framed art in the upper wall field instead of
	# reading like furniture-height signage. Short rooms still clamp it safely
	# beneath the ceiling.
	var y := float(office_layout["y"]) if not office_layout.is_empty() \
		else minf(1.92, ceil_h - size.y * 0.5 - 0.30)
	if office_layout.is_empty():
		y = maxf(y, size.y * 0.5 + 0.48)
	# Lift the frame clear of the wall's horizontal banding. A picture hung
	# across a tiled wainscot or the school's red line reads as a mistake
	# rather than as decor, and the old 1.72m centre let a tall Vegas frame sit
	# directly on its chair rail.
	# it. The ceiling clamp still wins if a room is too short to allow both.
	var band := _wall_band_top()
	if band > 0.0:
		y = maxf(y, band + WALL_BAND_CLEAR + size.y * 0.5)
		y = minf(y, ceil_h - size.y * 0.5 - 0.22)
	var pos := Vector3(inner + n * 0.055, y, along) if dir < 2 \
		else Vector3(along, y, inner + n * 0.055)
	var yaw := (PI / 2.0 if n > 0.0 else -PI / 2.0) if dir < 2 \
		else (0.0 if n > 0.0 else PI)
	var tilt_scale := 0.05 if theme == 0 or theme == 2 or theme == 5 else 0.018
	_wall_art_mount(pos, yaw, dir, path, max_size,
		(_r(salt + 3) - 0.5) * tilt_scale)


func _wall_decor(dir: int, plane: float) -> void:
	# Bare tile is the whole point of this floor; a poster or a clock on it
	# would immediately make it a building with a purpose.
	if theme == 9:
		return
	if theme == 10:
		_level_builder._brutalist_wall_detail(dir, plane)
		return
	if theme == 11:
		_level_builder._bloom_wall_growth(dir, plane)
		return
	if theme == 6 and dir == _school_chalkboard_wall():
		return
	var r := _r(40 + dir)
	var art_chance := _wall_art_chance()
	if art_chance > 0.0 and _r(1040 + dir) < art_chance:
		_wall_art(dir, plane, 1060 + dir * 7)
		return
	# Interior partitions meet two of the exterior walls. Decorations whose
	# own helpers do not expose their footprint (cases, clocks, pipes, etc.)
	# are omitted on those two contact walls, so a later partition can never
	# bisect them. Framed art above has a footprint and is relocated instead.
	var split := _resolved_room_split()
	if not split.is_empty() and ((bool(split[0]) and dir < 2) \
			or (not bool(split[0]) and dir >= 2)):
		return
	if theme == 7:
		# Poster cases only belong on public gallery walls. Store and
		# back-of-house wall furnishings are added later and would otherwise
		# grow through the artwork.
		var retail := style == WorldGen.MALL_CORRIDOR or style == WorldGen.MALL_ATRIUM \
				or style == WorldGen.MALL_KIOSKS
		if retail:
			if r < 0.52:
				_level_builder._mall_storefront(dir, plane)
			elif r < 0.96:
				_level_builder._mall_poster_case(dir, plane)
			return
		if r < 0.18:
			_wall_clock(dir, plane)
		return
	if theme == 8:
		if r < 0.24:
			_level_builder._prison_number_wall(dir, plane)
		elif r < 0.43:
			_security_camera_wall(dir, plane)
		elif r < 0.52:
			_level_builder._prison_locked_door_wall(dir, plane)
		elif r < 0.64:
			_ceiling_pipes(dir, plane)
		return
	if theme == 5:
		if r < 0.13:
			_level_builder._asy_straitjacket(dir, plane)
		elif r < 0.35:
			_level_builder._asy_scrawl(dir, plane)
		elif r < 0.36:
			_level_builder._asy_crutches(dir, plane)
		elif r < 0.45:
			_level_builder._asy_noticeboard(dir, plane)
		elif r < 0.54:
			_level_builder._asy_locked_door_wall(dir, plane)
		elif r < 0.63:
			_level_builder._asy_wall_notices(dir, plane)
		elif r < 0.72:
			_ceiling_pipes(dir, plane)
		elif r < 0.79:
			_wall_clock(dir, plane)
		return
	if theme == 6:
		if r < 0.20:
			_level_builder._sch_noticeboard(dir, plane)
		elif r < 0.32:
			_level_builder._sch_fountain(dir, plane)
		elif r < 0.42:
			_level_builder._sch_case(dir, plane)
		elif r < 0.52:
			_wall_clock(dir, plane)
		elif r < 0.62:
			_level_builder._sch_poster(dir, plane)
		return
	if theme == 4:
		if r < 0.30:
			_level_builder._air_adboxes(dir, plane)
		elif r < 0.42:
			_level_builder._air_wall_fids(dir, plane)
		return
	if theme == 2:
		# The art branch above owns the new hotel/corporate propaganda. Remaining
		# bare walls keep the Annex's rare camera motif, so the signs feel issued
		# by the building rather than laid out as a gallery.
		if style != WorldGen.ANNEX_PASSAGE and r < 0.095:
			_security_camera_wall(dir, plane)
		return
	if theme == 1:
		if r < 0.20:
			_level_builder._office_door_decor(dir, plane)
		elif r < 0.30:
			_wall_clock(dir, plane)
		elif r < 0.46:
			_filing_bank(dir, plane)
		elif r < 0.64:
			_level_builder._office_poster(dir, plane)
		return
	if r < 0.32:
		_art(dir, plane)
	elif r < 0.5:
		_sconces(dir, plane)
	elif r < 0.62:
		_level_builder._casino_neon(dir, plane)
	elif r < 0.70:
		_level_builder._change_machine(dir, plane)


## Building infrastructure shared by the office and Annex. Receptacles stay
## low and near the ends of uninterrupted walls; switches sit beside generated
## openings at a human reach height. An Annex boundary's utilities are emitted
## only by the same streamed chunk that owns its wall, so neither can appear
## without the other at the edge of the loaded neighbourhood.
func _wall_utilities(dir: int, plane: float, info: Dictionary) -> void:
	if theme != 1 and theme != 2:
		return
	var base := 1400 + dir * 37 + theme * 211
	var split := _resolved_room_split()
	var outlet_chance := 0.62 if theme == 1 else 0.55
	var switch_chance := 0.86 if theme == 1 else 0.68
	if bool(info["wall"]):
		# A 12m blank run carries several receptacles in any real building.
		# The Annex owns only its east/south edges, so a single outlet per
		# wall left most of the floor with no electrical evidence at all.
		var slots := [0.78, S * 0.5, S - 0.78] if theme == 2 \
			else [0.78 if _r(base + 1) < 0.5 else S - 0.78]
		for i in slots.size():
			if _r(base + 20 + i) >= outlet_chance:
				continue
			var along: float = slots[i]
			if not _wall_utility_along_clear(dir, along, split):
				continue
			_wall_utility(dir, plane, along, 0.31, false)
		return

	var a := float(info["t"]) - float(info["w"]) * 0.5
	var b := float(info["t"]) + float(info["w"]) * 0.5
	if _r(base + 2) < switch_chance:
		var left_space := a
		var right_space := S - b
		var switch_along := a - 0.24
		if right_space > left_space or (is_equal_approx(right_space, left_space) \
				and _r(base + 3) < 0.5):
			switch_along = b + 0.24
		if switch_along > 0.16 and switch_along < S - 0.16 \
				and _wall_utility_along_clear(dir, switch_along, split):
			_wall_utility(dir, plane, switch_along, 1.12, true)
	if _r(base + 4) < outlet_chance * 0.56:
		var left_len := a
		var right_len := S - b
		var outlet_along := a * 0.5
		if right_len > left_len:
			outlet_along = (b + S) * 0.5
		if (left_len if right_len <= left_len else right_len) > 1.15 \
				and _wall_utility_along_clear(dir, outlet_along, split):
			_wall_utility(dir, plane, outlet_along, 0.31, false)


func _wall_utility_along_clear(dir: int, along: float, split: Array) -> bool:
	if split.is_empty():
		return true
	var partition_hits_wall := (bool(split[0]) and dir < 2) \
		or (not bool(split[0]) and dir >= 2)
	return not partition_hits_wall or absf(along - float(split[1])) > 0.48


func _wall_utility(dir: int, plane: float, along: float, height: float,
		is_switch: bool) -> Node3D:
	var wall_t := ANNEX_WALL_T if theme == 2 else T
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var face := plane + n * wall_t * 0.5
	var p := Vector3(face, height, along) if dir < 2 \
		else Vector3(along, height, face)
	var mount := _wall_utility_mount(p, _wall_facing(dir), height, is_switch)
	if mount != null:
		mount.set_meta("wall_utility_dir", dir)
	return mount


func _wall_utility_mount(p: Vector3, yaw: float, height: float,
		is_switch: bool) -> Node3D:
	var mount := Node3D.new()
	mount.position = p
	mount.rotation.y = yaw
	mount.set_meta("wall_utility_kind",
		"light_switch" if is_switch else "outlet")
	mount.set_meta("wall_utility_theme", theme)
	mount.set_meta("wall_utility_height", height)
	add_child(mount)
	var path := LIGHT_SWITCH_PATH if is_switch else OUTLET_PATH
	# The outlet's authored front — the face carrying the receptacle photo with
	# its slots — points down its own -Z, so mounting it unrotated buried the
	# only detailed face in the wall and presented its blank back to the room.
	# That is why outlets read as featureless plates at any distance or scale.
	var correction := -PI * 0.5 if is_switch else PI
	var depth := 0.015266 if is_switch else 0.005001
	# Both models are centred on their own origin, so scaling leaves the plate
	# centred on the authored mount height; only the standoff has to follow.
	var plate := ANNEX_UTILITY_SCALE if theme == 2 else 1.0
	var inst := _attributed_prop_local(mount, path,
		Vector3(0, 0, depth * plate * 0.5 + 0.001), correction,
		Vector3.ONE * plate)
	if inst == null:
		mount.get_parent().remove_child(mount)
		mount.free()
		return null
	inst.set_meta("wall_mounted_utility", true)
	if theme == 2:
		# These plates sit only millimetres off the wall. Their tiny authored
		# depth used to become a large, unstable contact shadow/SDFGI blotch at
		# distance. The wall provides the room occlusion; the plate should only
		# supply visible surface detail.
		_configure_annex_non_occluding(inst)
		mount.set_meta("wall_utility_non_occluding", true)
	return mount


func _art(dir: int, plane: float) -> void:
	_wall_art(dir, plane, 46 + dir * 11)


func _sconces(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	for along in [S * 0.32, S * 0.68]:
		var wall_pos: Vector3
		var out: Vector3
		if dir < 2:
			wall_pos = Vector3(inner, 0, along)
			out = Vector3(n, 0, 0)
		else:
			wall_pos = Vector3(along, 0, inner)
			out = Vector3(0, 0, n)
		var plate_size := Vector3(0.06, 0.34, 0.13) if dir < 2 else Vector3(0.13, 0.34, 0.06)
		_box(wall_pos + out * 0.03 + Vector3(0, 1.78, 0), plate_size, Mats.brass(), false)
		_cyl(wall_pos + out * 0.12 + Vector3(0, 1.86, 0), 0.10, 0.17, Mats.shade(), false)
		_sphere(wall_pos + out * 0.12 + Vector3(0, 1.97, 0), 0.035, Mats.bulb())
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.5)
		l.light_energy = 0.55
		l.omni_range = 4.5
		l.position = wall_pos + out * 0.3 + Vector3(0, 1.95, 0)
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 14.0
		l.distance_fade_length = 6.0
		add_child(l)


func _wall_clock(dir: int, plane: float) -> void:
	var along := S / 2.0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var y := 2.25
	if dir < 2:
		_cc0_prop("wall_clock", Vector3(inner + n * 0.01, y, along), PI / 2.0 * n)
	else:
		_cc0_prop("wall_clock", Vector3(along, y, inner + n * 0.01), 0.0 if n > 0.0 else PI)


# --- lighting ----------------------------------------------------------------

func _build_lighting() -> void:
	if theme == 11:
		_level_builder._bloom_lighting()
		return
	if theme == 10:
		_level_builder._brutalist_lighting()
		return
	if theme == 9:
		_level_builder._pool_lighting()
		return
	if theme == 7:
		_level_builder._mall_lighting()
		return
	if theme == 8:
		_level_builder._prison_lighting()
		return
	if theme == 1:
		_level_builder._office_lighting()
		return
	if theme == 5:
		_level_builder._asy_lighting()
		return
	if theme == 2:
		_level_builder._annex_lighting()
		return
	if theme == 4:
		_level_builder._air_lighting()
		return
	if theme == 6:
		_level_builder._sch_lighting()
		return
	if style == WorldGen.STYLE_HALLWAY:
		_level_builder._hall_lighting()
		return
	var is_spawn := cell == Vector2i.ZERO
	var dead := (not is_spawn) and _r(8) < 0.07
	var flicker := (not is_spawn) and (not dead) and _r(9) < 0.16
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.panel_on().duplicate()
	else:
		pmat = Mats.panel_on()
	# The casino ceiling wants jewellery, not office hardware. Small opaline
	# flush mounts keep the light warm and low without reading as fluorescent
	# square panels against the coffered plaster.
	# The shader's 2.4m world-space coffers put medallion centres at
	# 1.2 + n*2.4. 3.6/8.4 give this four-light rhythm while keeping every
	# mount inside a rosette instead of stranded on the moulding intersection.
	for p in [Vector2(3.6, 3.6), Vector2(8.4, 3.6),
			Vector2(3.6, 8.4), Vector2(8.4, 8.4)]:
		_level_builder._casino_flush_mount(Vector3(p.x, 0, p.y), pmat)

	var grand := style == WorldGen.STYLE_GRAND or style == WorldGen.STYLE_BALLROOM
	if grand:
		_level_builder._chandelier()
	if dead:
		return

	var energy := 2.4 if grand else 1.35
	var light := _make_main_light(flicker, pmat, energy)
	light.light_color = Color.from_hsv(0.07 + 0.05 * _r(11), 0.25 + 0.35 * _r(12), 1.0)
	light.omni_range = 16.0 if grand else 11.0
	light.position = Vector3(S / 2.0, ceil_h - (1.4 if grand else 0.45), S / 2.0)
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = 18.0
	add_child(light)


func _troffer(at: Vector3, lens: Vector2, pmat: Material, frame: Material) -> void:
	_box(Vector3(at.x, ceil_h - 0.055, at.z), Vector3(lens.x, 0.05, lens.y), pmat, false)
	var fx := lens.x / 2.0 + 0.055
	var fz := lens.y / 2.0 + 0.055
	_box(Vector3(at.x, ceil_h - 0.02, at.z - fz), Vector3(lens.x + 0.18, 0.035, 0.07), frame, false)
	_box(Vector3(at.x, ceil_h - 0.02, at.z + fz), Vector3(lens.x + 0.18, 0.035, 0.07), frame, false)
	_box(Vector3(at.x - fx, ceil_h - 0.02, at.z), Vector3(0.07, 0.035, lens.y + 0.18), frame, false)
	_box(Vector3(at.x + fx, ceil_h - 0.02, at.z), Vector3(0.07, 0.035, lens.y + 0.18), frame, false)


func _make_main_light(flicker: bool, pmat: StandardMaterial3D, energy: float) -> OmniLight3D:
	if not flicker:
		var l := OmniLight3D.new()
		l.light_energy = energy
		return l
	var fl := FlickerLight.new()
	fl.base_energy = energy
	fl.mats = [pmat]
	fl.rng_seed = WorldGen.h(wseed, cell.x, cell.y, 10)
	var bz := AudioStreamPlayer3D.new()
	bz.stream = SoundBank.buzz()
	bz.unit_size = 3.0
	bz.max_distance = 15.0
	bz.volume_db = -26.0
	bz.bus = SoundBank.HALL_BUS
	bz.autoplay = true
	bz.position = Vector3(S / 2.0, _wall_h() - 0.5, S / 2.0)
	add_child(bz)
	fl.buzz = bz
	return fl


func _resolved_room_split() -> Array:
	return _resolved_room_split_for(cell)


func _resolved_room_split_for(member: Vector2i) -> Array:
	var member_root := WorldGen.room_id(wseed, member)
	var split := WorldGen.room_split(wseed, member_root, theme)
	if split.is_empty():
		return []
	var along_x := bool(split[0])
	var off := float(split[1])
	var chosen := WorldGen.partition_offset(wseed, member, theme, along_x, off)
	if chosen < 0.0:
		along_x = not along_x
		chosen = WorldGen.partition_offset(wseed, member, theme, along_x, off)
	if chosen < 0.0:
		return []
	return [along_x, chosen]


func _build_props() -> void:
	portal_dest = -1
	# Cell strips hug their own cell's walls, so every cell of a merged block
	# builds its own — the anchor-only path would leave the rest of the block
	# as bare box rooms.
	if not is_room_anchor and style == WorldGen.PRISON_CELLBLOCK and not descent_target:
		_level_builder._prison_cellblock()
	# Data Center tunnels are cell-local circulation shells. A corridor cell can
	# belong to a merged room whose anchor is elsewhere; skipping it here would
	# widen that one twelve-metre segment back into an empty hall.
	if not is_room_anchor and style == WorldGen.BRUTAL_PASSAGE and not descent_target:
		_level_builder._brutal_passage()
	# The Bloom passage is also a cell-local inserted shell. Every streamed
	# segment builds even when a merged room's furnishing anchor is elsewhere.
	if not is_room_anchor and style == WorldGen.BLOOM_PASSAGE and not descent_target:
		_level_builder._bloom_passage()
	# one room is furnished once, by its anchor cell, around its true centre
	if not is_room_anchor:
		return
	# The objective is a deliberately empty room with one unmistakable set
	# piece. Seeded furniture cannot hide its doors or obstruct the car. The
	# arrival room is cleared for the same reason, plus one more: the player is
	# teleported into that car, so nothing seeded may be standing in it.
	if descent_target or descent_arrival:
		return
	var split := _resolved_room_split()
	if theme == 1 and style != WorldGen.OFFICE_CORRIDOR:
		_level_builder._office_air_conditioners(split)
	if not split.is_empty():
		_partition(split[0], split[1])
		if portal_dest < 0:
			var sn0 := get_child_count()
			var sb0 := body.get_child_count()
			_small_room_props(split[0], split[1])
			_clear_furnishings_from_doorways(sn0, sb0)
		return
	var rc := WorldGen.room_centre(wseed, room_root)
	var off := Vector3(rc.x - (float(cell.x) * S + S / 2.0), 0.0,
		rc.y - (float(cell.y) * S + S / 2.0))
	if theme == 2:
		# Annex set pieces are small architectural interruptions authored in the
		# anchor cell; they never inherit the generic room-centre shift.
		off = Vector3.ZERO
	# these build against a specific wall of THIS cell — moving them to the
	# room centre would tear the glass, mezzanine or desk run off its wall
	# (this is exactly what left the prison's cell bars floating mid-room:
	# cellblock strips hug their own cell's walls and must never be shifted)
	if style == WorldGen.AIR_GATE or style == WorldGen.AIR_CHECKIN \
			or style == WorldGen.AIR_ESCALATOR or style == WorldGen.AIR_TRANSIT \
			or style == WorldGen.MALL_CORRIDOR or style == WorldGen.PRISON_CORRIDOR \
			or style == WorldGen.MALL_STORE or style == WorldGen.MALL_FOODCOURT \
			or style == WorldGen.MALL_ATRIUM or style == WorldGen.MALL_CINEMA \
			or style == WorldGen.PRISON_CELLBLOCK or style == WorldGen.PRISON_CELLS \
			or style == WorldGen.PRISON_SHOWER or style == WorldGen.PRISON_GUARD \
			or style == WorldGen.PRISON_VISITATION or style == WorldGen.PRISON_INDUSTRY \
			or style == WorldGen.BRUTAL_PASSAGE or style == WorldGen.BLOOM_PASSAGE:
		off = Vector3.ZERO
	var n0 := get_child_count()
	var b0 := body.get_child_count()
	# On rare 24x24 Annex rooms the furniture hoard replaces that room's usual
	# architectural dressing. It remains one atomic, clearance-aware set piece.
	if theme == 2 and _level_builder._annex_furniture_pile():
		_shift_props(off, n0, b0)
		_clear_furnishings_from_doorways(n0, b0)
		return
	match style:
		WorldGen.STYLE_PILLARS:
			_level_builder._pillars(ceil_h, Mats.brass())
			# A pillared hall is casino floor. Grand halls are 1.4% of the
			# level, so gating table games on them left a Vegas with almost no
			# tables in it; the common room styles carry them instead.
			if _r(240) < 0.62:
				_level_builder._blackjack(Vector3(6.0, 0, 6.0), 242)
			elif _r(241) < 0.55:
				_level_builder._roulette(Vector3(6.0, 0, 6.0), 243)
		WorldGen.STYLE_SLOTS:
			_level_builder._slots()
			# Table games sit at either end of the machine floor, clear of both
			# banks. This is the room that most reads as a casino and it had
			# nothing but slots in it.
			if _r(250) < 0.72:
				var table_z := 1.95 if _r(251) < 0.5 else 10.05
				if _r(252) < 0.55:
					_level_builder._blackjack(Vector3(6.0, 0, table_z), 253)
				else:
					_level_builder._roulette(Vector3(6.0, 0, table_z), 254)
		WorldGen.STYLE_LOUNGE:
			_level_builder._lounge()
			if _r(240) < 0.58:
				_level_builder._blackjack(Vector3(9.4, 0, 4.6), 242)
			elif _r(244) < 0.5:
				_level_builder._roulette(Vector3(8.4, 0, 4.4), 245)
		WorldGen.STYLE_GRAND:
			_level_builder._pillars(ceil_h, Mats.marble_photo())
			if room_n >= 4:
				_level_builder._blackjack(Vector3(1.6, 0, 1.6), 248)
				_level_builder._blackjack(Vector3(10.4, 0, 10.4), 286)
				# One roulette table anchors the middle of a grand hall, where
				# there is genuinely room for a 3m layout.
				if _r(287) < 0.62:
					_level_builder._roulette(Vector3(S / 2.0, 0, S / 2.0), 288)
			elif _r(289) < 0.62:
				_level_builder._roulette(Vector3(S / 2.0, 0, S / 2.0), 290)
			else:
				_level_builder._blackjack(Vector3(S / 2.0, 0, S / 2.0), 291)
			if _r(246) < 0.5:
				_level_builder._velvet_ropes()
		WorldGen.STYLE_BALLROOM:
			_level_builder._casino_ballroom()
		WorldGen.STYLE_HALLWAY:
			_level_builder._hallway()
		WorldGen.STYLE_EMPTY:
			if portal_dest < 0 and _r(20) < 0.35:
				_planter(Vector3(2.6 + 6.8 * _r(21), 0, 2.6 + 6.8 * _r(22)))
			if portal_dest < 0 and _r(24) < 0.48:
				_level_builder._casino_service_cart(Vector3(2.1 if _r(25) < 0.5 else 9.9, 0,
					2.1 if _r(26) < 0.5 else 9.9), 27)
		WorldGen.OFFICE_CORRIDOR:
			_level_builder._office_corridor()
		WorldGen.OFFICE_CUBICLES:
			_level_builder._office_cubicles()
		WorldGen.OFFICE_STORAGE:
			_level_builder._office_storage()
		WorldGen.OFFICE_BREAK:
			_level_builder._office_break()
		WorldGen.OFFICE_BOARDROOM:
			_level_builder._office_boardroom()
		WorldGen.OFFICE_EMPTY:
			if portal_dest < 0 and _r(20) < 0.15:
				_planter(Vector3(2.6 + 6.8 * _r(21), 0, 2.6 + 6.8 * _r(22)))
			if _r(250) < 0.35:
				_level_builder._copier(Vector3(3.0, 0, 8.8), 252)
			elif portal_dest < 0 and _r(254) < 0.62:
				_level_builder._office_floor_files(Vector3(2.2 if _r(255) < 0.5 else 9.8, 0,
					2.1 if _r(256) < 0.5 else 9.9), 257)
		WorldGen.ANNEX_OPEN:
			_level_builder._annex_open()
		WorldGen.ANNEX_MAZE:
			_level_builder._annex_maze()
		WorldGen.ANNEX_LONG:
			_level_builder._annex_long()
		WorldGen.ANNEX_QUIET:
			_level_builder._annex_quiet()
		WorldGen.ANNEX_PASSAGE:
			_level_builder._annex_passage()
		WorldGen.ANNEX_LOBBY:
			_level_builder._annex_lobby()
		WorldGen.AIR_GATE:
			_level_builder._air_gate()
			_level_builder._air_common()
		WorldGen.AIR_CONCOURSE:
			_level_builder._air_concourse()
			_level_builder._air_common()
		WorldGen.AIR_TRANSIT:
			_level_builder._air_transit()
			_level_builder._air_common()
		WorldGen.AIR_CHECKIN:
			_level_builder._air_checkin()
			_level_builder._air_common()
		WorldGen.AIR_BAGGAGE:
			_level_builder._air_baggage()
			_level_builder._air_common()
		WorldGen.AIR_ESCALATOR:
			_level_builder._air_escalator()
			_level_builder._air_common()
		WorldGen.AIR_HALL:
			_level_builder._air_hall()
			_level_builder._air_common()
		WorldGen.AIR_FOODCOURT:
			_level_builder._air_foodcourt()
			_level_builder._air_common()
		WorldGen.ASY_CELL:
			_level_builder._asy_cell_props()
		WorldGen.ASY_WARD:
			_level_builder._asy_ward()
			_level_builder._asy_sounds()
		WorldGen.ASY_DAYROOM:
			_level_builder._asy_dayroom()
			_level_builder._asy_sounds()
		WorldGen.ASY_TREATMENT:
			_level_builder._asy_treatment()
			_level_builder._asy_sounds()
		WorldGen.ASY_HYDRO:
			_level_builder._asy_hydro()
			_level_builder._asy_sounds()
		WorldGen.ASY_OFFICE:
			_level_builder._asy_office()
		WorldGen.ASY_CORRIDOR:
			_level_builder._asy_corridor()
			if _r(779) < 0.35:
				_level_builder._asy_sounds()
		WorldGen.ASY_CHAPEL:
			_level_builder._asy_chapel()
			_level_builder._asy_sounds()
		WorldGen.SCH_CORRIDOR:
			_level_builder._sch_corridor()
		WorldGen.SCH_CLASSROOM:
			_level_builder._sch_classroom()
		WorldGen.SCH_CAFETERIA:
			_level_builder._sch_cafeteria()
		WorldGen.SCH_BATHROOM:
			_level_builder._sch_bathroom()
		WorldGen.SCH_GYM:
			_level_builder._sch_gym()
		WorldGen.SCH_LIBRARY:
			_level_builder._sch_library()
		WorldGen.SCH_LAB:
			_level_builder._sch_lab()
		WorldGen.SCH_ADMIN:
			_level_builder._sch_admin()
		WorldGen.SCH_AUDITORIUM:
			_level_builder._sch_auditorium()
		WorldGen.MALL_CORRIDOR:
			_level_builder._mall_corridor()
		WorldGen.MALL_STORE:
			_level_builder._mall_store()
		WorldGen.MALL_ANCHOR:
			_level_builder._mall_anchor()
		WorldGen.MALL_FOODCOURT:
			_level_builder._mall_foodcourt()
		WorldGen.MALL_ATRIUM:
			_level_builder._mall_atrium()
		WorldGen.MALL_SERVICE:
			_level_builder._mall_service()
		WorldGen.MALL_KIOSKS:
			_level_builder._mall_kiosks()
		WorldGen.MALL_CINEMA:
			_level_builder._mall_cinema()
		WorldGen.PRISON_CORRIDOR:
			_level_builder._prison_corridor()
		WorldGen.PRISON_CELLBLOCK:
			_level_builder._prison_cellblock()
		WorldGen.PRISON_CELLS:
			_level_builder._prison_cells()
		WorldGen.PRISON_MESS:
			_level_builder._prison_mess()
		WorldGen.PRISON_SHOWER:
			_level_builder._prison_shower()
		WorldGen.PRISON_GUARD:
			_level_builder._prison_guard()
		WorldGen.PRISON_INDUSTRY:
			_level_builder._prison_industry()
		WorldGen.PRISON_VISITATION:
			_level_builder._prison_visitation()
		WorldGen.PRISON_ROTUNDA:
			_level_builder._prison_rotunda()
		WorldGen.POOL_BASIN:
			_level_builder._pool_basin_room()
		WorldGen.POOL_CHANNEL:
			_level_builder._pool_channel_room()
		WorldGen.POOL_DECK:
			_level_builder._pool_deck_room()
		WorldGen.POOL_SOLARIUM:
			_level_builder._pool_solarium_room()
		WorldGen.POOL_ALCOVE:
			_level_builder._pool_alcove_room()
		WorldGen.POOL_STAIRS:
			_level_builder._pool_stairs_room()
		WorldGen.POOL_GALLERY:
			_level_builder._pool_gallery_room()
		WorldGen.POOL_CISTERN:
			_level_builder._pool_cistern_room()
		WorldGen.BRUTAL_PASSAGE:
			_level_builder._brutal_passage()
		WorldGen.BRUTAL_HALL:
			_level_builder._brutal_hall()
		WorldGen.BRUTAL_GALLERY:
			_level_builder._brutal_gallery()
		WorldGen.BRUTAL_ATRIUM:
			_level_builder._brutal_atrium()
		WorldGen.BRUTAL_WATER_COURT:
			_level_builder._brutal_water_court()
		WorldGen.BRUTAL_RAMP:
			_level_builder._brutal_ramp()
		WorldGen.BRUTAL_SERVICE:
			_level_builder._brutal_service()
		WorldGen.BRUTAL_SANCTUM:
			_level_builder._brutal_sanctum()
		WorldGen.BLOOM_PASSAGE:
			_level_builder._bloom_passage()
		WorldGen.BLOOM_COMMONS:
			_level_builder._bloom_commons()
		WorldGen.BLOOM_CLASSROOM:
			_level_builder._bloom_classroom()
		WorldGen.BLOOM_INCUBATOR:
			_level_builder._bloom_incubator()
		WorldGen.BLOOM_NEST:
			_level_builder._bloom_nest()
		WorldGen.BLOOM_ATRIUM:
			_level_builder._bloom_atrium()
		WorldGen.BLOOM_GYM:
			_level_builder._bloom_gym()
		WorldGen.BLOOM_HEART:
			_level_builder._bloom_heart()
		WorldGen.BLOOM_STORM_APERTURE:
			_level_builder._bloom_storm_aperture()
	if theme == 2:
		_level_builder._annex_lived_in_dressing()
	if theme == 9:
		# Pool dressing is cell-local ARCHITECTURE: decks, bridges, stairs,
		# piers and channel flanks hug their own cell's walls. Recentring it
		# on a multi-cell room shears it off those walls — stranding ledge
		# ladders over open water, sometimes outside the cell — and the
		# doorway cull then deletes the very decks a door steps onto.
		return
	_shift_props(off, n0, b0)
	_clear_furnishings_from_doorways(n0, b0)


## Move everything the prop pass just built onto the room centre — meshes,
## lights, sounds and colliders alike, whatever node they were parented to.
func _shift_props(off: Vector3, n0: int, b0: int) -> void:
	if off == Vector3.ZERO:
		return
	for i in range(n0, get_child_count()):
		var ch := get_child(i)
		if ch is Node3D:
			(ch as Node3D).position += off
	for i in range(b0, body.get_child_count()):
		var cs := body.get_child(i)
		if cs is Node3D:
			(cs as Node3D).position += off


## Every cased edge opening is a real connection. Furnishing is allowed to be
## dense and awkward, but it may not occupy the first few metres of the path
## through that opening. Locked facade doors are not edge openings and are
## therefore deliberately unaffected.
func _doorway_clearance_rects() -> Array[Rect2]:
	var zones: Array[Rect2] = []
	for member in _room_members():
		var base := Vector2(float(member.x - cell.x) * S,
			float(member.y - cell.y) * S)
		for dir in 4:
			var info := _edge_info(member, dir)
			if info["wall"] or info["full_open"]:
				continue
			var width := float(info["w"]) + DOOR_CLEAR_PAD * 2.0
			var along := float(info["t"]) - width * 0.5
			match dir:
				0:
					zones.append(Rect2(base.x + S - DOOR_CLEAR_DEPTH,
						base.y + along, DOOR_CLEAR_DEPTH + 0.15, width))
				1:
					zones.append(Rect2(base.x - 0.15, base.y + along,
						DOOR_CLEAR_DEPTH + 0.15, width))
				2:
					zones.append(Rect2(base.x + along,
						base.y + S - DOOR_CLEAR_DEPTH, width, DOOR_CLEAR_DEPTH + 0.15))
				3:
					zones.append(Rect2(base.x + along, base.y - 0.15,
						width, DOOR_CLEAR_DEPTH + 0.15))
	return zones


## Pool basin decks are architecture rather than furniture, so the ordinary
## post-furnishing doorway cull cannot remove them. Expose only supernatural
## opening lanes for the pool builder to carve out of its raised deck strips.
func _runtime_shortcut_clearance_rects() -> Array[Rect2]:
	var zones: Array[Rect2] = []
	for member in _room_members():
		var base := Vector2(float(member.x - cell.x) * S,
			float(member.y - cell.y) * S)
		for dir in 4:
			var info := _edge_info(member, dir)
			if not bool(info.get("runtime_shortcut", false)):
				continue
			var width := float(info["w"]) + DOOR_CLEAR_PAD * 2.0
			var along := float(info["t"]) - width * 0.5
			match dir:
				0:
					zones.append(Rect2(base.x + S - DOOR_CLEAR_DEPTH,
						base.y + along, DOOR_CLEAR_DEPTH + 0.15, width))
				1:
					zones.append(Rect2(base.x - 0.15, base.y + along,
						DOOR_CLEAR_DEPTH + 0.15, width))
				2:
					zones.append(Rect2(base.x + along,
						base.y + S - DOOR_CLEAR_DEPTH, width,
						DOOR_CLEAR_DEPTH + 0.15))
				3:
					zones.append(Rect2(base.x + along, base.y - 0.15,
						width, DOOR_CLEAR_DEPTH + 0.15))
	return zones


func _rect_hits_zones(rect: Rect2, zones: Array[Rect2]) -> bool:
	for zone in zones:
		if rect.intersects(zone):
			return true
	return false


## Collect the floor footprint of every visible mesh below head height. A
## top-level prop pivot is removed as a unit when any of its solid-looking
## geometry occupies an approach lane, so a bookcase cannot be left as loose
## shelves and a table cannot be left as four orphaned legs.
func _collect_low_mesh_rects(node: Node, parent_xf: Transform3D, out: Array[Rect2]) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var a := mi.get_aabb()
			var mn := Vector3(INF, INF, INF)
			var mx := Vector3(-INF, -INF, -INF)
			for ix in 2:
				for iy in 2:
					for iz in 2:
						var p := xf * (a.position + Vector3(a.size.x * ix,
							a.size.y * iy, a.size.z * iz))
						mn = mn.min(p)
						mx = mx.max(p)
			# Floor finishes and ceiling fittings do not obstruct a body.
			if mx.y > 0.22 and mn.y < 2.45:
				out.append(Rect2(mn.x, mn.z, mx.x - mn.x, mx.z - mn.z))
	for ch in node.get_children():
		_collect_low_mesh_rects(ch, xf, out)


func _node_hits_doorway(node: Node, zones: Array[Rect2]) -> bool:
	var rects: Array[Rect2] = []
	_collect_low_mesh_rects(node, Transform3D.IDENTITY, rects)
	for rect in rects:
		if _rect_hits_zones(rect, zones):
			return true
	return false


func _collision_floor_rect(cs: CollisionShape3D) -> Rect2:
	if cs.shape == null:
		return Rect2()
	var size := Vector3.ZERO
	if cs.shape is BoxShape3D:
		size = (cs.shape as BoxShape3D).size
	elif cs.shape is CylinderShape3D:
		var cy := cs.shape as CylinderShape3D
		size = Vector3(cy.radius * 2.0, cy.height, cy.radius * 2.0)
	elif cs.shape is CapsuleShape3D:
		var cap := cs.shape as CapsuleShape3D
		size = Vector3(cap.radius * 2.0, cap.height, cap.radius * 2.0)
	else:
		return Rect2()
	var local := AABB(-size * 0.5, size)
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for ix in 2:
		for iy in 2:
			for iz in 2:
				var p := cs.transform * (local.position + Vector3(local.size.x * ix,
					local.size.y * iy, local.size.z * iz))
				mn = mn.min(p)
				mx = mx.max(p)
	if mx.y <= 0.22 or mn.y >= 2.45:
		return Rect2()
	return Rect2(mn.x, mn.z, mx.x - mn.x, mx.z - mn.z)


func _clear_furnishings_from_doorways(n0: int, b0: int) -> void:
	# Corridor styles build their continuous shell during the prop pass. Their
	# real side bays already own explicit clearance and must not be mistaken for
	# furniture. The neighbouring room still clears its side of the same door.
	var is_corridor := WorldGen.annex_corridor_axis(wseed, cell) != 0 \
		if theme == 2 else WorldGen.corridor(wseed, cell) != 0
	if is_corridor:
		return
	var zones := _doorway_clearance_rects()
	if zones.is_empty():
		return
	var hit_groups := {}
	var remove_nodes: Array[Node] = []
	for i in range(n0, get_child_count()):
		var ch := get_child(i)
		ch.set_meta("doorway_furnishing", true)
		if _node_hits_doorway(ch, zones):
			remove_nodes.append(ch)
			var group_id: int = int(ch.get_meta("furnishing_group", -1))
			if group_id >= 0:
				hit_groups[group_id] = true
	var remove_shapes: Array[CollisionShape3D] = []
	for i in range(b0, body.get_child_count()):
		var cs := body.get_child(i) as CollisionShape3D
		if cs == null:
			continue
		cs.set_meta("doorway_furnishing", true)
		var rect := _collision_floor_rect(cs)
		if rect.size != Vector2.ZERO and _rect_hits_zones(rect, zones):
			remove_shapes.append(cs)
			var group_id: int = int(cs.get_meta("furnishing_group", -1))
			if group_id >= 0:
				hit_groups[group_id] = true
	# A hit on any visible or physical member removes the whole atomic group.
	for i in range(n0, get_child_count()):
		var ch := get_child(i)
		var group_id: int = int(ch.get_meta("furnishing_group", -1))
		if group_id >= 0 and hit_groups.has(group_id) and not remove_nodes.has(ch):
			remove_nodes.append(ch)
	for i in range(b0, body.get_child_count()):
		var cs := body.get_child(i) as CollisionShape3D
		if cs == null:
			continue
		var group_id: int = int(cs.get_meta("furnishing_group", -1))
		if group_id >= 0 and hit_groups.has(group_id) and not remove_shapes.has(cs):
			remove_shapes.append(cs)
	for ch in remove_nodes:
		remove_child(ch)
		ch.free()
		doorway_props_removed += 1
	for cs in remove_shapes:
		body.remove_child(cs)
		cs.free()
		doorway_props_removed += 1


## Audit hook: after the cull, no marked furnishing mesh or collider may still
## overlap a real doorway approach lane.
func doorway_clearance_violations() -> int:
	var zones := _doorway_clearance_rects()
	var bad := 0
	for ch in get_children():
		if ch.has_meta("doorway_furnishing") and _node_hits_doorway(ch, zones):
			bad += 1
	for ch in body.get_children():
		if ch is CollisionShape3D and ch.has_meta("doorway_furnishing"):
			var rect := _collision_floor_rect(ch)
			if rect.size != Vector2.ZERO and _rect_hits_zones(rect, zones):
				bad += 1
	return bad


## Focused contract probe for a blackout-created opening. Returns -1 when the
## edge is not a runtime shortcut; otherwise counts low collision boxes inside
## the central player-width lane. The lintel is above the player's movement
## capsule and deliberately does not count.
func runtime_shortcut_blockers(dir: int) -> int:
	var edge := _edge_info(cell, dir)
	if not bool(edge.get("runtime_shortcut", false)):
		return -1
	var half_lane := maxf(0.25,
		float(edge["w"]) * 0.5 - ShadowFigure.MOVE_RADIUS - 0.08)
	var along := float(edge["t"])
	var zone := Rect2(S - 0.42, along - half_lane, 0.84, half_lane * 2.0) \
		if dir == 0 else Rect2(-0.42, along - half_lane, 0.84, half_lane * 2.0) \
		if dir == 1 else Rect2(along - half_lane, S - 0.42, half_lane * 2.0, 0.84) \
		if dir == 2 else Rect2(along - half_lane, -0.42, half_lane * 2.0, 0.84)
	var bad := 0
	for node in body.get_children():
		var cs := node as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		# Purpose-built stair and travelator ramps carry the player through a
		# threshold. Their thin sloped collider is circulation, not an obstacle.
		if bool(cs.get_meta("walkable_ramp", false)):
			continue
		# Include cylinders and capsules as well as boxes. A bin or column in an
		# impossible doorway is just as solid as the wall that vanished.
		var size := Vector3.ZERO
		if cs.shape is BoxShape3D:
			size = (cs.shape as BoxShape3D).size
		elif cs.shape is CylinderShape3D:
			var cylinder := cs.shape as CylinderShape3D
			size = Vector3(cylinder.radius * 2.0, cylinder.height,
				cylinder.radius * 2.0)
		elif cs.shape is CapsuleShape3D:
			var capsule := cs.shape as CapsuleShape3D
			size = Vector3(capsule.radius * 2.0, capsule.height,
				capsule.radius * 2.0)
		else:
			continue
		var local := AABB(-size * 0.5, size)
		var mn := Vector3(INF, INF, INF)
		var mx := Vector3(-INF, -INF, -INF)
		for ix in 2:
			for iy in 2:
				for iz in 2:
					var p := cs.transform * (local.position + Vector3(
						local.size.x * ix, local.size.y * iy,
						local.size.z * iz))
					mn = mn.min(p)
					mx = mx.max(p)
		# Floor below the feet and the doorway lintel above the movement
		# capsule are legal.
		var floor_y := _floor_h()
		if mx.y <= floor_y + 0.03 \
				or mn.y >= floor_y + ShadowFigure.MOVE_HEIGHT:
			continue
		if Rect2(mn.x, mn.z, mx.x - mn.x, mx.z - mn.z).intersects(zone):
			bad += 1
	return bad


## Focused contract probe for a doorway that a generated reality sealed. A
## positive count proves the visual wall is backed by low solid collision.
func runtime_seal_solids(dir: int) -> int:
	var edge := _edge_info(cell, dir)
	if not bool(edge.get("runtime_seal", false)):
		return -1
	var zone := Rect2(S - 0.45, 0.0, 0.9, S) if dir == 0 else \
		Rect2(-0.45, 0.0, 0.9, S) if dir == 1 else \
		Rect2(0.0, S - 0.45, S, 0.9) if dir == 2 else \
		Rect2(0.0, -0.45, S, 0.9)
	var solids := 0
	for node in body.get_children():
		var cs := node as CollisionShape3D
		if cs == null:
			continue
		var rect := _collision_floor_rect(cs)
		if rect.size != Vector2.ZERO and rect.intersects(zone):
			solids += 1
	return solids


func _mesh_min_y(node: Node, parent_xf: Transform3D) -> float:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	var low := INF
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var a := mi.get_aabb()
			for ix in 2:
				for iy in 2:
					for iz in 2:
						var p := xf * (a.position + Vector3(a.size.x * ix,
							a.size.y * iy, a.size.z * iz))
						low = minf(low, p.y)
	for child in node.get_children():
		low = minf(low, _mesh_min_y(child, xf))
	return low


func _collect_atomic_furnishings(node: Node, groups: Dictionary,
		out: Array[Node3D]) -> void:
	if node is Node3D and node.has_meta("atomic_furnishing"):
		var furnishing := node as Node3D
		out.append(furnishing)
		groups[int(furnishing.get_meta("furnishing_group", -1))] = true
	for child in node.get_children():
		_collect_atomic_furnishings(child, groups, out)


## Regression hook for the new levels: atomic furniture must still have visible
## geometry reaching the floor, and no grouped collider may survive after its
## matching visible assembly was culled from a doorway. This catches both the
## floating-accessory bug and invisible collision left behind by its fix.
func atomic_furnishing_support_violations() -> int:
	var groups := {}
	var furnishings: Array[Node3D] = []
	_collect_atomic_furnishings(self, groups, furnishings)
	var bad := 0
	for furnishing in furnishings:
		if bool(furnishing.get_meta("floor_supported", false)):
			var low := _mesh_min_y(furnishing, Transform3D.IDENTITY)
			if not is_finite(low) or low > 0.14:
				bad += 1
	for child in body.get_children():
		if not child.has_meta("furnishing_group"):
			continue
		var group_id: int = int(child.get_meta("furnishing_group", -1))
		if group_id >= 0 and not groups.has(group_id):
			bad += 1
	return bad


func _airport_apron_audit_walk(node: Node, parent_xf: Transform3D,
		inside_setpiece: bool, report: Dictionary) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	var active := inside_setpiece
	if node.has_meta("airport_apron_setpiece"):
		active = true
		report["setpieces"] = int(report["setpieces"]) + 1
	if active and node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var a := mi.get_aabb()
			var overflow := false
			for ix in 2:
				for iy in 2:
					for iz in 2:
						var p := xf * (a.position + Vector3(
							a.size.x * ix, a.size.y * iy, a.size.z * iz))
						if p.x < -0.01 or p.x > S + 0.01 \
								or p.z < -0.01 or p.z > S + 0.01:
							overflow = true
			if overflow:
				report["violations"] = int(report["violations"]) + 1
	for child in node.get_children():
		_airport_apron_audit_walk(child, xf, active, report)


## Airport exterior scenery is only a window-box illusion. No aircraft mesh
## may cross the chunk boundary into the terminal room next door.
## Airport exterior scenery is only a window-box illusion. No aircraft mesh
## may cross the chunk boundary into the terminal room next door.
func airport_apron_setpiece_audit() -> Dictionary:
	var report := {"setpieces": 0, "violations": 0}
	if theme != 4:
		return report
	for child in get_children():
		_airport_apron_audit_walk(child, Transform3D.IDENTITY, false, report)
	return report


## Audit hook for the two newest levels. Named enrichment markers let the
## multi-seed suite prove that each essential prop family is actually emitted,
## rather than merely existing in the asset folder.
func enrichment_prop_counts() -> Dictionary:
	var counts := {}
	var pending: Array[Node] = [self]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node.has_meta("enrichment_prop"):
			var kind := str(node.get_meta("enrichment_prop"))
			counts[kind] = int(counts.get(kind, 0)) + 1
		for child in node.get_children():
			pending.append(child)
	return counts


# --- interaction set pieces --------------------------------------------------

func _build_interactions() -> void:
	if descent:
		if descent_target and descent_target_wall >= 0:
			if descent_final:
				_descent_exit(descent_target_wall)
			else:
				_descent_elevator(descent_target_wall)
				_descent_ritual_set()
		if descent_arrival and descent_arrival_wall >= 0:
			_descent_arrival_car(descent_arrival_wall)
			if descent_floor_idx == 0:
				_descent_intro_tv(descent_arrival_wall)
		return
	if not WorldGen.elevator_cell(wseed, cell, theme):
		return
	var wall := WorldGen.anchor_wall(wseed, cell, 1701, theme)
	_interactive_elevator(wall)


## A complete lift facade: split brushed-metal leaves, deep black reveal,
## illuminated floor display, call panel and animated opening before travel.
func _interactive_elevator(dir: int) -> void:
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var plane := (S - T / 2.0) if dir == 0 or dir == 2 else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner + n * 0.035, _floor_h(), S / 2.0)
		v.rotation.y = -PI / 2.0 if dir == 0 else PI / 2.0
	else:
		v.position = Vector3(S / 2.0, _floor_h(), inner + n * 0.035)
		v.rotation.y = PI if dir == 2 else 0.0
	v.set_meta("elevator_facade", true)
	v.set_meta("elevator_facade_dir", dir)
	add_child(v)
	_mrbox(v, Vector3(0, 1.27, -0.035), Vector3(2.62, 2.54, 0.10),
		Mats.charcoal(), 0.025)
	_mbox(v, Vector3(0, 1.25, -0.075), Vector3(2.22, 2.42, 0.04), Mats.screen_dark())
	var left := Node3D.new()
	var right := Node3D.new()
	v.add_child(left)
	v.add_child(right)
	left.position = Vector3(-0.545, 1.25, 0.015)
	right.position = Vector3(0.545, 1.25, 0.015)
	for leaf in [left, right]:
		_mrbox(leaf, Vector3.ZERO, Vector3(1.07, 2.40, 0.075), Mats.steel(), 0.012)
		for rib in [-0.36, 0.0, 0.36]:
			_mbox(leaf, Vector3(rib, 0, 0.045), Vector3(0.018, 2.25, 0.018), Mats.chrome())
	# Header display and its stubborn amber direction arrow. The Annex ceiling
	# is only 2.78m high, so the former fixed 2.95m header top disappeared into
	# the ceiling and cropped the number. Fit a compact housing between the
	# door frame and the actual local ceiling instead.
	const INDICATOR_BOTTOM := 2.58
	const INDICATOR_TOP_NORMAL := 2.95
	const INDICATOR_CEILING_GAP := 0.04
	var local_ceiling := ceil_h - _floor_h()
	var indicator_top := minf(
		INDICATOR_TOP_NORMAL, local_ceiling - INDICATOR_CEILING_GAP)
	var indicator_h := maxf(indicator_top - INDICATOR_BOTTOM, 0.12)
	var indicator_y := indicator_top - indicator_h * 0.5
	var indicator := _mrbox(
		v, Vector3(0, indicator_y, 0.035),
		Vector3(0.92, indicator_h, 0.08), Mats.sign_housing(), 0.018)
	indicator.set_meta("elevator_indicator_header", true)
	indicator.set_meta("elevator_indicator_top", indicator_top)
	indicator.set_meta("elevator_indicator_ceiling", local_ceiling)
	var floor_lb := Label3D.new()
	floor_lb.text = "%d  ▼" % (WorldGen.THEMES.find(theme) + 1)
	floor_lb.font_size = 52 if indicator_h < 0.24 else 72
	floor_lb.pixel_size = 0.0021
	floor_lb.modulate = Color(1.0, 0.56, 0.18)
	floor_lb.position = Vector3(0, indicator_y, 0.082)
	floor_lb.set_meta("elevator_indicator_label", true)
	floor_lb.set_meta("elevator_indicator_top", indicator_top)
	floor_lb.set_meta("elevator_indicator_ceiling", local_ceiling)
	v.add_child(floor_lb)
	# Brushed call plate, button, key switch and Braille-like locator studs.
	_mrbox(v, Vector3(1.38, 1.16, 0.06), Vector3(0.34, 0.64, 0.08), Mats.steel(), 0.018)
	var button := _mcyl(v, Vector3(1.38, 1.27, 0.125), 0.075, 0.035, Mats.lamp_amber())
	button.rotation.x = PI / 2.0
	var keyhole := _mcyl(v, Vector3(1.38, 0.99, 0.12), 0.026, 0.025, Mats.charcoal())
	keyhole.rotation.x = PI / 2.0
	for i in 3:
		_msphere(v, Vector3(1.30 + 0.08 * float(i), 0.88, 0.125), 0.012, Mats.chrome())
	var idx := WorldGen.THEMES.find(theme)
	var dest: int = WorldGen.THEMES[(idx + 1) % WorldGen.THEMES.size()]
	var hit := Interactable.new()
	hit.prompt_text = "E — elevator to Floor %d" % (WorldGen.THEMES.find(dest) + 1)
	hit.position = Vector3(1.38, 1.18, 0.22)
	hit.add_box(Vector3(0.52, 0.88, 0.42))
	v.add_child(hit)
	hit.activated.connect(_use_elevator.bind(dest, hit, left, right))


func _use_elevator(_actor: Node, dest: int, hit: Interactable,
		left: Node3D, right: Node3D) -> void:
	if not hit.enabled:
		return
	hit.enabled = false
	hit.prompt_text = "ELEVATOR ARRIVING"
	get_tree().call_group("level_manager", "door_activity")
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(left, "position:x", -1.02, 0.48)
	tw.parallel().tween_property(right, "position:x", 1.02, 0.48)
	await tw.finished
	if is_inside_tree():
		get_tree().call_group("level_manager", "use_elevator", dest)


## Descent objective: the wall is deliberately left intact. This sealed car
## sits wholly inside the target room, so walking around it never reveals an
## ungenerated room on the other side of a decorative door.
##
## Reaching it is not the end of the floor. The call plate summons a car that
## is genuinely somewhere else, and the wait is the most exposed the player
## ever is: rule two forbids standing still, so it has to be walked out.
func _descent_elevator(dir: int) -> void:
	_descent_clear_car_footprint(dir)
	var rig := _descent_car_shell(dir, false)
	_descent_lift_rig = rig
	var hit := Interactable.new()
	hit.name = "DescentLiftCall"
	hit.prompt_text = "E — call lift"
	# The whole car front is the target. A 0.5m plate on the right jamb was
	# findable only if you already knew it was there, which reads in play as
	# "the elevator will not open".
	hit.position = Vector3(0.0, 1.28, 2.42)
	hit.add_box(Vector3(3.0, 2.3, 0.9))
	rig["root"].add_child(hit)
	rig["hit"] = hit
	hit.activated.connect(_descent_call.bind(rig, hit))
	var commit := _local_area(rig["root"], Vector3(0, 1.05, 1.05),
		Vector3(1.72, 2.0, 1.15))
	commit.body_entered.connect(_descent_commit.bind(rig, commit, hit))
	# Rebuilt after streaming out mid-wait: resume exactly where the run says.
	if descent_lift_open:
		hit.enabled = false
		hit.prompt_text = ""
		rig["root"].set_meta("opened", true)
		_set_descent_leaves(rig, 1.02)
		_descent_lit_call(rig, true)
	elif descent_lift_called:
		hit.enabled = false
		hit.prompt_text = "LIFT ARRIVING"
		_descent_lit_call(rig, true)
		_descent_lift_wait(rig, descent_lift_wait)


func has_descent_lift() -> bool:
	return not _descent_lift_rig.is_empty()


## Driven by DescentRun, which owns the authoritative clock. The chunk only
## ever presents the wait; it never decides that the car has arrived.
func open_descent_lift() -> void:
	if _descent_lift_rig.is_empty():
		return
	var root: Node3D = _descent_lift_rig["root"]
	# `_open_descent_doors` owns the "opened" meta; only read it here.
	if not is_instance_valid(root) or root.has_meta("opened"):
		return
	if _descent_lift_rig.has("shaft"):
		var shaft: Node = _descent_lift_rig["shaft"]
		if is_instance_valid(shaft):
			shaft.queue_free()
	var display: Label3D = _descent_lift_rig["display"]
	if is_instance_valid(display):
		display.text = "%02d  ▼" % (descent_floor_idx + 1)
	var hit: Interactable = _descent_lift_rig.get("hit")
	if is_instance_valid(hit):
		hit.enabled = false
		hit.prompt_text = ""
	_descent_sound(root, SoundBank.ding(), -7.0)
	_open_descent_doors(_descent_lift_rig["left"], _descent_lift_rig["right"],
		root, 0.72)


## Final objective: the same impossible room-side shell opens onto a short,
## overexposed service passage. The player must physically enter the light.
func _descent_exit(dir: int) -> void:
	_descent_clear_car_footprint(dir)
	var rig := _descent_car_shell(dir, true)
	var left: AnimatableBody3D = rig["left"]
	var right: AnimatableBody3D = rig["right"]
	var root: Node3D = rig["root"]
	# Bright endpoint and dense warm spill obscure the existing solid wall.
	_mrbox(root, Vector3(0, 1.25, 0.16), Vector3(1.78, 2.28, 0.035),
		Mats.bulb(), 0.008)
	for i in 5:
		var haze := _mquad(root, Vector3(0, 1.25, 0.34 + float(i) * 0.28),
			Vector2(1.72, 2.20), Mats.glass())
		haze.transparency = 0.72 + float(i) * 0.04
	var wind := GPUParticles3D.new()
	wind.amount = 36
	wind.lifetime = 1.4
	wind.position = Vector3(0, 1.0, 0.75)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.08, 1)
	pm.spread = 16.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.08, 0)
	pm.scale_min = 0.008
	pm.scale_max = 0.025
	wind.process_material = pm
	var dust := QuadMesh.new()
	dust.size = Vector2(0.025, 0.025)
	wind.draw_pass_1 = dust
	root.add_child(wind)
	var approach := _local_area(root, Vector3(0, 1.1, 3.05),
		Vector3(3.4, 2.2, 1.55))
	approach.body_entered.connect(_descent_open.bind(left, right, approach))
	var finish := _local_area(root, Vector3(0, 1.05, 0.68),
		Vector3(1.65, 2.0, 0.65))
	finish.body_entered.connect(_descent_finish.bind(finish, approach))


## Local placement of a Descent car against wall `dir` of a cell. Shared with
## `car_interior_point()` so main can teleport the player into the arrival car
## without duplicating the offsets.
static func descent_car_basis(dir: int, floor_y := 0.0) -> Transform3D:
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var plane := (S - T / 2.0) if dir == 0 or dir == 2 else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var at := Vector3.ZERO
	var yaw := 0.0
	if dir < 2:
		at = Vector3(inner + n * 0.035, floor_y, S / 2.0)
		yaw = -PI / 2.0 if dir == 0 else PI / 2.0
	else:
		at = Vector3(S / 2.0, floor_y, inner + n * 0.035)
		yaw = PI if dir == 2 else 0.0
	return Transform3D(Basis(Vector3.UP, yaw), at)


## World-space standing position inside the car built against `dir` of `cell`,
## and the yaw that faces its doors. The interior is a sealed authored box, so
## this point is safe by construction and deliberately bypasses ArrivalSafety —
## whose escape-direction test a 2.2m car can never satisfy.
static func car_interior_point(cell: Vector2i, dir: int, floor_y := 0.0) -> Dictionary:
	var basis_at := descent_car_basis(dir, floor_y)
	var local := Vector3(0.0, 0.15, 1.12)
	var world := basis_at * local + Vector3(float(cell.x) * S, 0.0,
		float(cell.y) * S)
	# The doors sit at +Z in car space; the camera convention is -Z forward.
	return {"position": world, "yaw": basis_at.basis.get_euler().y + PI}


func _descent_car_shell(dir: int, out: bool, arrival := false) -> Dictionary:
	var root := Node3D.new()
	root.name = "DescentArrival" if arrival else (
		"DescentExit" if out else "DescentElevator")
	root.transform = descent_car_basis(dir, _floor_h())
	add_child(root)

	var shell := StaticBody3D.new()
	root.add_child(shell)
	# The generated room floor remains the collider beneath the car. Lift the
	# visible steel skin a few millimetres above it: the old exactly-coplanar
	# surfaces z-fought and let the room flooring shimmer through the panel.
	_mrbox(shell, Vector3(0, 0.009, 1.12),
		Vector3(2.44, 0.018, 2.24), Mats.steel(), 0.006)
	_local_shell_box(shell, Vector3(0, 2.42, 1.12),
		Vector3(2.44, 0.10, 2.24), Mats.charcoal())
	_local_shell_box(shell, Vector3(0, 1.22, 0.06),
		Vector3(2.44, 2.42, 0.12), Mats.charcoal())
	_local_shell_box(shell, Vector3(-1.18, 1.22, 1.12),
		Vector3(0.12, 2.42, 2.24), Mats.steel())
	_local_shell_box(shell, Vector3(1.18, 1.22, 1.12),
		Vector3(0.12, 2.42, 2.24), Mats.steel())
	# The facade sits inward from the generated wall; the centre remains open.
	_local_shell_box(shell, Vector3(0, 2.53, 2.23),
		Vector3(2.82, 0.34, 0.14), Mats.charcoal())
	_local_shell_box(shell, Vector3(-1.27, 1.22, 2.23),
		Vector3(0.28, 2.48, 0.14), Mats.charcoal())
	_local_shell_box(shell, Vector3(1.27, 1.22, 2.23),
		Vector3(0.28, 2.48, 0.14), Mats.charcoal())
	# Handrails make the alcove read as a car rather than a stage-flat door.
	for sx in [-1.0, 1.0]:
		var rail := _mcyl(root, Vector3(sx * 1.02, 0.92, 1.10),
			0.025, 1.55, Mats.chrome())
		rail.rotation.x = PI / 2.0
	# Warm car light is intentionally non-shadowed and survives at range.
	_mrbox(root, Vector3(0, 2.34, 1.10), Vector3(1.35, 0.035, 0.50),
		Mats.bulb(), 0.015)
	var car_light := OmniLight3D.new()
	car_light.light_color = Color(1.0, 0.72, 0.42)
	car_light.light_energy = 1.25
	car_light.omni_range = 6.5
	car_light.shadow_enabled = false
	car_light.position = Vector3(0, 2.18, 1.1)
	root.add_child(car_light)

	var left := _descent_leaf(root, -0.54)
	var right := _descent_leaf(root, 0.54)
	_mrbox(root, Vector3(0, 2.68, 2.31), Vector3(1.24, 0.38, 0.10),
		Mats.sign_housing(), 0.018)
	_mrbox(root, Vector3(0, 2.68, 2.37), Vector3(1.04, 0.24, 0.025),
		Mats.screen_dark(), 0.008)
	var display := Label3D.new()
	if out:
		display.text = "OUT"
	elif arrival:
		# The car you arrived in reads the floor you are on, with no direction:
		# it is not going anywhere and neither are you, back the way you came.
		display.text = "%02d" % (descent_floor_idx + 1)
	else:
		display.text = "%02d  ▼" % (descent_floor_idx + 1)
	display.font_size = 66
	display.pixel_size = 0.0020
	display.modulate = Color(1.0, 0.56, 0.18)
	display.position = Vector3(0, 2.68, 2.392)
	root.add_child(display)
	# The call plate is real in Descent; _descent_elevator places the E-key
	# target over this button. The final OUT passage keeps it as dressing.
	_mrbox(root, Vector3(1.50, 1.20, 2.31), Vector3(0.32, 0.62, 0.08),
		Mats.steel(), 0.018)
	var call := _mcyl(root, Vector3(1.50, 1.28, 2.37), 0.07, 0.035,
		Mats.lamp_amber())
	call.rotation.x = PI / 2.0
	return {
		"root": root, "left": left, "right": right, "call": call,
		"display": display, "light": car_light,
	}


func _descent_leaf(parent: Node3D, x: float) -> AnimatableBody3D:
	var leaf := AnimatableBody3D.new()
	leaf.position = Vector3(x, 1.22, 2.25)
	parent.add_child(leaf)
	_mrbox(leaf, Vector3.ZERO, Vector3(1.06, 2.38, 0.09),
		Mats.steel(), 0.012)
	for rib in [-0.35, 0.0, 0.35]:
		_mbox(leaf, Vector3(rib, 0, 0.052),
			Vector3(0.018, 2.22, 0.018), Mats.chrome())
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.06, 2.38, 0.12)
	cs.shape = shape
	leaf.add_child(cs)
	return leaf


func _local_shell_box(parent: StaticBody3D, pos: Vector3, size: Vector3,
		mat: Material) -> void:
	_mrbox(parent, pos, size, mat, minf(0.025, minf(size.x, size.z) * 0.2))
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)


func _local_area(parent: Node3D, pos: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	area.add_child(cs)
	parent.add_child(area)
	return area


func _descent_open(actor: Node, left: AnimatableBody3D,
		right: AnimatableBody3D, approach: Area3D) -> void:
	if not actor is Player or approach.has_meta("opened"):
		return
	_open_descent_doors(left, right, approach)


## Pressing the plate does not open anything. It tells the run to start the
## car moving, and the run tells this chunk when the car is actually here.
func _descent_call(_actor: Node, rig: Dictionary, hit: Interactable) -> void:
	if not hit.enabled:
		return
	hit.enabled = false
	hit.prompt_text = "LIFT ARRIVING"
	get_tree().call_group("level_manager", "door_activity")
	var call: MeshInstance3D = rig["call"]
	var press := create_tween().set_trans(Tween.TRANS_QUAD)
	press.tween_property(call, "position:z", 2.345, 0.08)
	press.tween_property(call, "position:z", 2.37, 0.14)
	_descent_lit_call(rig, true)
	_descent_sound(rig["root"], SoundBank.key_click(), -6.0)
	var seconds := DescentRun.lift_wait_for(descent_floor_idx)
	get_tree().call_group("descent_listener", "descent_lift_called", seconds)
	_descent_lift_wait(rig, seconds)


## Presentation for the wait only. The shaft works away somewhere above and the
## indicator fills; nothing here can open a door.
func _descent_lift_wait(rig: Dictionary, seconds: float) -> void:
	var root: Node3D = rig["root"]
	if not is_instance_valid(root) or root.has_meta("waiting") \
			or root.has_meta("opened"):
		return
	root.set_meta("waiting", true)
	var total := maxf(0.5, seconds)
	var shaft := AudioStreamPlayer3D.new()
	shaft.bus = SoundBank.HALL_BUS
	shaft.stream = SoundBank.lift_shaft()
	shaft.volume_db = -30.0
	shaft.max_distance = 34.0
	shaft.unit_size = 7.0
	root.add_child(shaft)
	shaft.play()
	rig["shaft"] = shaft
	# It gets louder as the car gets closer — audible from further away than the
	# indicator is readable, which is the point.
	var approach_tw := create_tween()
	approach_tw.tween_property(shaft, "volume_db", -13.0, total)
	var display: Label3D = rig["display"]
	var full := DescentRun.lift_wait_for(descent_floor_idx)
	var elapsed_fraction := clampf(1.0 - total / maxf(0.001, full), 0.0, 1.0)
	var tw := create_tween()
	tw.tween_method(
		func(v: float): _descent_lift_indicator(display, v),
		elapsed_fraction, 1.0, total)
	rig["wait_tweens"] = [approach_tw, tw]


## The run cancelled the call because the player abandoned the room. Put the
## plate back exactly as it was before the press.
func reset_descent_lift() -> void:
	if _descent_lift_rig.is_empty():
		return
	var root: Node3D = _descent_lift_rig["root"]
	if not is_instance_valid(root) or root.has_meta("opened"):
		return
	root.remove_meta("waiting")
	for tween in _descent_lift_rig.get("wait_tweens", []):
		if tween != null and tween.is_valid():
			tween.kill()
	_descent_lift_rig.erase("wait_tweens")
	if _descent_lift_rig.has("shaft"):
		var shaft: Node = _descent_lift_rig["shaft"]
		if is_instance_valid(shaft):
			shaft.queue_free()
		_descent_lift_rig.erase("shaft")
	var hit: Interactable = _descent_lift_rig.get("hit")
	if is_instance_valid(hit):
		hit.enabled = true
		hit.prompt_text = "E — call lift"
	_descent_lit_call(_descent_lift_rig, false)
	var display: Label3D = _descent_lift_rig["display"]
	if is_instance_valid(display):
		display.text = "%02d" % (descent_floor_idx + 1)
		display.modulate = Color(0.55, 0.26, 0.07)


func _descent_lift_indicator(display: Label3D, progress: float) -> void:
	if not is_instance_valid(display):
		return
	var bars := clampi(1 + int(progress * 2.99), 1, 3)
	display.text = "%02d  %s" % [descent_floor_idx + 1, "▼".repeat(bars)]
	# A slow amber pulse while it is on its way; steady once it lands.
	display.modulate = Color(1.0, 0.56, 0.18).lerp(
		Color(0.55, 0.26, 0.07), 0.5 + 0.5 * sin(progress * 44.0))


func _descent_lit_call(rig: Dictionary, on: bool) -> void:
	var call: MeshInstance3D = rig.get("call")
	if not is_instance_valid(call):
		return
	call.material_override = Mats.bulb() if on else null


func _set_descent_leaves(rig: Dictionary, x: float) -> void:
	var left: AnimatableBody3D = rig["left"]
	var right: AnimatableBody3D = rig["right"]
	if is_instance_valid(left):
		left.position.x = -x
	if is_instance_valid(right):
		right.position.x = x


func _descent_sound(parent: Node, stream: AudioStream, volume: float,
		max_distance := 24.0) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.bus = SoundBank.HALL_BUS
	sound.stream = stream
	sound.volume_db = volume
	sound.max_distance = max_distance
	sound.unit_size = 6.0
	parent.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
	return sound


func _open_descent_doors(left: AnimatableBody3D,
		right: AnimatableBody3D, owner: Node, seconds := 0.62) -> void:
	if owner.has_meta("opened"):
		return
	owner.set_meta("opened", true)
	var sound := AudioStreamPlayer3D.new()
	sound.bus = SoundBank.HALL_BUS
	sound.stream = SoundBank.elev()
	sound.volume_db = -8.0
	sound.max_distance = 24.0
	owner.add_child(sound)
	sound.play()
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(left, "position:x", -1.02, seconds)
	tw.parallel().tween_property(right, "position:x", 1.02, seconds)


## The story tape is the objective. Charge affects survival on the way to the
## lift and during its summon, but never turns a completed floor into a battery
## errand at the threshold.
func descent_lift_ready() -> bool:
	return descent_tape_watched


func _descent_commit(actor: Node, rig: Dictionary, commit: Area3D,
		hit: Interactable) -> void:
	if not actor is Player or commit.has_meta("committed"):
		return
	# Watching the floor's tape is the sole exit condition. The charging station
	# remains a useful chance to prepare for the summon and next floor, but it is
	# never mandatory.
	if not descent_lift_ready():
		var now := Time.get_ticks_msec()
		if now - int(commit.get_meta("refused_ms", 0)) < 1500:
			return
		commit.set_meta("refused_ms", now)
		var reason := "THE TAPE HAS NOT BEEN WATCHED"
		get_tree().call_group("descent_listener",
			"descent_commit_refused", reason)
		_descent_sound(rig["root"], SoundBank.thud(), -10.0)
		return
	commit.set_meta("committed", true)
	commit.set_deferred("monitoring", false)
	hit.enabled = false
	hit.prompt_text = ""
	get_tree().call_group("descent_listener", "suspend_descent_rules")
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(rig["left"], "position:x", -0.54, 0.52)
	tw.parallel().tween_property(rig["right"], "position:x", 0.54, 0.52)
	await tw.finished
	if not is_inside_tree():
		return
	await _descent_ride(rig)
	if is_inside_tree():
		get_tree().call_group("descent_listener", "_on_descent_lift")


## The one safe place in a run, and the only part of it that happens to the
## player rather than being done by them. A sealed car gives the eye no
## parallax, so the travel is carried by the motor, the loaded car light and
## the camera rumble; the world swap happens behind the fade at the end and the
## player steps out of an identical car on the next floor.
func _descent_ride(rig: Dictionary) -> void:
	var root: Node3D = rig["root"]
	var light: OmniLight3D = rig["light"]
	var display: Label3D = rig["display"]
	var base_energy := light.light_energy
	# A moving car is sealed from the world: an inward-facing matte shell
	# wraps it so nothing shows through leaf seams or panel cracks while the
	# floor outside is, as far as the fiction cares, somewhere between floors.
	var shell := MeshInstance3D.new()
	var shell_mesh := BoxMesh.new()
	# Hugs the car skin (x ±1.24, z 0..2.36): the front face sits centimetres
	# behind the door leaves so a crack can only ever show black.
	shell_mesh.size = Vector3(2.9, 3.0, 2.64)
	shell.mesh = shell_mesh
	var shell_mat := StandardMaterial3D.new()
	shell_mat.albedo_color = Color.BLACK
	shell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	shell.material_override = shell_mat
	shell.position = Vector3(0.0, 1.35, 1.02)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shell)
	_descent_sound(root, SoundBank.clang(), -14.0)
	display.modulate = Color(1.0, 0.56, 0.18)
	display.text = "%02d" % (descent_floor_idx + 1)
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return

	# Brake release, then the hoist takes the weight.
	_descent_sound(root, SoundBank.thud(), -8.0)
	var motor := AudioStreamPlayer3D.new()
	motor.bus = SoundBank.HALL_BUS
	motor.stream = SoundBank.lift_motor()
	motor.volume_db = -36.0
	motor.max_distance = 20.0
	motor.unit_size = 5.0
	root.add_child(motor)
	motor.play()
	var spin_up := create_tween()
	spin_up.tween_property(motor, "volume_db", -12.0, 1.2)
	var rumble_up := create_tween()
	rumble_up.tween_method(_descent_rumble, 0.0, 1.0, 1.2)
	# The car light sags as the motor draws, then hunts while under way.
	var dim := create_tween()
	dim.tween_property(light, "light_energy", base_energy * 0.58, 0.55)
	var travel := create_tween()
	travel.tween_method(
		func(v: float): _descent_ride_indicator(display, v), 0.0, 1.0, 4.4)

	await get_tree().create_timer(4.4).timeout
	if not is_inside_tree():
		return

	# Deceleration: the number of the floor below appears before the doors do.
	display.text = "%02d  ▼" % (descent_floor_idx + 2)
	display.modulate = Color(1.0, 0.56, 0.18)
	var spin_down := create_tween()
	spin_down.tween_property(motor, "volume_db", -34.0, 1.1)
	var rumble_down := create_tween()
	rumble_down.tween_method(_descent_rumble, 1.0, 0.22, 1.1)
	var lift_light := create_tween()
	lift_light.tween_property(light, "light_energy", base_energy, 1.1)
	await get_tree().create_timer(1.15).timeout
	if not is_inside_tree():
		return
	_descent_sound(root, SoundBank.thud(), -12.0)
	await get_tree().create_timer(0.35).timeout


func _descent_ride_indicator(display: Label3D, progress: float) -> void:
	if not is_instance_valid(display):
		return
	# Passing floors that are not on the route: the shaft is taller than the run.
	var bars := 1 + (int(progress * 9.0) % 3)
	display.text = "%s" % "▼".repeat(bars)
	display.modulate = Color(1.0, 0.56, 0.18).lerp(
		Color(0.42, 0.20, 0.05), 0.5 + 0.5 * sin(progress * 62.0))


func _descent_rumble(amount: float) -> void:
	if is_inside_tree():
		get_tree().call_group("descent_listener", "descent_ride_rumble", amount)


## The car the player rides in on. Built shut, opened by main once the floor is
## live, and dead once they have stepped out of it — rule three, in steel.
func _descent_arrival_car(dir: int) -> void:
	var rig := _descent_car_shell(dir, false, true)
	_descent_arrival_rig = rig
	if descent_arrival_used:
		_descent_kill_arrival(rig)
		return
	var inside := _local_area(rig["root"], Vector3(0, 1.05, 1.15),
		Vector3(2.05, 2.10, 1.95))
	inside.name = "DescentArrivalInterior"
	rig["inside"] = inside
	inside.body_exited.connect(_descent_arrival_left.bind(rig, inside))


func has_descent_arrival() -> bool:
	return not _descent_arrival_rig.is_empty() and not descent_arrival_used


func open_descent_arrival() -> void:
	if _descent_arrival_rig.is_empty() or descent_arrival_used:
		return
	var root: Node3D = _descent_arrival_rig["root"]
	if not is_instance_valid(root):
		return
	# Slower than a call: this is the reveal of a floor, not a door operating.
	_open_descent_doors(_descent_arrival_rig["left"],
		_descent_arrival_rig["right"], root, 1.15)


func _descent_arrival_left(actor: Node, rig: Dictionary, inside: Area3D) -> void:
	if not actor is Player or inside.has_meta("spent"):
		return
	inside.set_meta("spent", true)
	# Area exits also fire while a streamed floor is being dismantled. Defer one
	# frame and require both actors to survive before spending the arrival car.
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(actor) \
			or not actor.is_inside_tree() or not is_instance_valid(inside):
		return
	get_tree().call_group("descent_listener", "descent_arrival_spent")
	var delay := create_tween()
	delay.tween_interval(1.7)
	delay.tween_callback(_finish_descent_arrival_left.bind(rig, inside))


func _finish_descent_arrival_left(rig: Dictionary, inside: Area3D) -> void:
	if not is_inside_tree() or not is_instance_valid(inside):
		return
	# Never seal a player who stepped back in — the car has no inside control,
	# and a shut arrival car with someone in it is an unrecoverable run.
	for body in inside.get_overlapping_bodies():
		if body is Player:
			inside.remove_meta("spent")
			return
	var root: Node3D = rig["root"]
	_descent_sound(root, SoundBank.elev(), -13.0)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(rig["left"], "position:x", -0.54, 0.9)
	tw.parallel().tween_property(rig["right"], "position:x", 0.54, 0.9)
	await tw.finished
	if is_inside_tree():
		_descent_kill_arrival(rig)


func _descent_kill_arrival(rig: Dictionary) -> void:
	_set_descent_leaves(rig, 0.54)
	var light: OmniLight3D = rig.get("light")
	if is_instance_valid(light):
		light.light_energy = 0.0
		light.visible = false
	var display: Label3D = rig.get("display")
	if is_instance_valid(display):
		display.modulate = Color(0.17, 0.12, 0.08)
	_descent_lit_call(rig, false)


func _descent_finish(actor: Node, finish: Area3D, approach: Area3D) -> void:
	if not actor is Player or finish.has_meta("committed"):
		return
	finish.set_meta("committed", true)
	finish.set_deferred("monitoring", false)
	approach.set_deferred("monitoring", false)
	get_tree().call_group("descent_listener", "_on_descent_exit")


## Blackout is a reversible overlay. Snapshot each light's exact visible and
## energy state; restoring never resurrects a fixture that was already dead.
func set_blackout(on: bool) -> void:
	if on:
		if _blackout or not _blackout_lights.is_empty() \
				or not _blackout_meshes.is_empty():
			return
		for node in find_children("*", "Light3D", true, false):
			var light := node as Light3D
			_blackout_lights[light] = [light.visible, light.light_energy]
			light.visible = false
		for node in find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if _mesh_is_emissive(mesh):
				_blackout_meshes[mesh] = mesh.visible
				mesh.visible = false
		_blackout = true
		return
	if _blackout_lights.is_empty() and _blackout_meshes.is_empty():
		_blackout = false
		return
	for light in _blackout_lights:
		if is_instance_valid(light):
			var state: Array = _blackout_lights[light]
			light.visible = bool(state[0])
			light.light_energy = float(state[1])
	for mesh in _blackout_meshes:
		if is_instance_valid(mesh):
			mesh.visible = bool(_blackout_meshes[mesh])
	_blackout_lights.clear()
	_blackout_meshes.clear()
	_blackout = false


## Presentation-only mutations never touch walls, floors or connectivity.
func activate_anomaly(kind: int) -> void:
	anomaly_kind = kind
	if kind == 0:
		for node in find_children("*", "Light3D", true, false):
			var light := node as Light3D
			if _blackout_lights.has(light):
				var state: Array = _blackout_lights[light]
				state[0] = false
				state[1] = 0.0
				_blackout_lights[light] = state
			light.visible = false
			light.light_energy = 0.0
		for node in find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if not _mesh_is_emissive(mesh):
				continue
			if _blackout_meshes.has(mesh):
				_blackout_meshes[mesh] = false
			mesh.visible = false
	elif kind == 1 and (WorldGen.corridor(wseed, cell) != 0 \
			or not WorldGen.room_split(wseed, room_root, theme).is_empty() \
			or anomaly_player == null):
		# A narrow or partitioned cell has no universally safe standing corner,
		# and without a player there is nothing for a figure to hunt. Decline the
		# optional beat; killing the fixtures here made a successful global power
		# restore look broken.
		anomaly_kind = -1
	elif kind == 1 and not has_node("WaitingFigure"):
		var f := ShadowFigure.new()
		f.name = "WaitingFigure"
		# stands in a corner rather than hangs, so it reads as watching
		f.variant = ShadowFigure.GAOLER
		# WAITING, never INERT. As an INERT node this was the one figure in the
		# game that could not be burned, could not touch the player and never
		# faded — the player emptied a torch into it and nothing happened. It
		# holds its corner until the player is in the room, then it hunts.
		f.mode = ShadowFigure.Mode.WAITING
		f.player = anomaly_player
		f.topology = descent_topology
		var corners := [
			Vector3(1.45, 0, 1.45), Vector3(10.55, 0, 1.45),
			Vector3(1.45, 0, 10.55), Vector3(10.55, 0, 10.55),
		]
		f.position = corners[WorldGen.h(wseed, cell.x, cell.y, 2441) % 4]
		add_child(f)


## Apply one of the floor's predeclared room arrangements. Every candidate is
## tried with its real meshes and colliders, then rejected unless it remains
## inside its owning room, clear of every doorway lane and disjoint from other
## furnishing groups. Nothing here moves architecture or an interactable.
func _apply_furniture_variant(variant: int) -> void:
	if variant <= 0 or not is_room_anchor:
		return
	var group_colliders := {}
	for child in body.get_children():
		var gid := int(child.get_meta("furnishing_group", -1))
		if gid < 0:
			continue
		if not group_colliders.has(gid):
			group_colliders[gid] = []
		group_colliders[gid].append(child)
	var occupied := {}
	for child in get_children():
		var original := child as Node3D
		if original == null or not original.has_meta("furnishing_group"):
			continue
		var original_gid := int(original.get_meta("furnishing_group"))
		occupied[original_gid] = _furnishing_group_rect(
			original, group_colliders.get(original_gid, []))
	var remove_pivots: Array[Node3D] = []
	var remove_colliders: Array[Node] = []
	var fallback_pivot: Node3D
	var fallback_colliders: Array[Node] = []
	var witness_changed := false
	var idx := 0
	for child in get_children():
		var pivot := child as Node3D
		# Architecture, wall-mounted assemblies and interactions never qualify.
		if not _furniture_mutation_eligible(pivot):
			continue
		if fallback_pivot == null:
			fallback_pivot = pivot
			for collider in group_colliders.get(
					int(pivot.get_meta("furnishing_group")), []):
				fallback_colliders.append(collider)
		idx += 1
		var gid := int(pivot.get_meta("furnishing_group"))
		var roll := WorldGen.h(wseed, cell.x + idx * 131,
			cell.y - idx * 71, 5501 + variant * 409)
		if posmod(roll, 100) >= 72 and pivot != fallback_pivot:
			continue
		# The third reality can make one in four eligible groups simply cease to
		# exist. Removal cannot obstruct circulation and rebuilding an earlier
		# state restores it exactly.
		if variant == 3 and posmod(roll >> 7, 4) == 0:
			remove_pivots.append(pivot)
			for collider in group_colliders.get(gid, []):
				remove_colliders.append(collider)
			occupied.erase(gid)
			mutation_furniture_changed_groups += 1
			if pivot == fallback_pivot:
				witness_changed = true
			continue
		var origin := pivot.position
		var original_pivot_xf := pivot.transform
		var collider_xfs := {}
		for collider in group_colliders.get(gid, []):
			if collider is Node3D:
				collider_xfs[collider] = (collider as Node3D).transform
		var accepted := false
		for attempt in 7:
			pivot.transform = original_pivot_xf
			for collider in collider_xfs:
				(collider as Node3D).transform = collider_xfs[collider]
			var attempt_roll := WorldGen.h(wseed, roll + attempt * 719,
				variant * 193, 5623 + idx * 37)
			var turn_options := [
				deg_to_rad(-38.0), deg_to_rad(38.0),
				PI * 0.5, -PI * 0.5, PI,
			]
			var turn: float = turn_options[posmod(
				attempt_roll, turn_options.size())]
			if variant == 1:
				turn *= 0.72
			var reach := 0.62 if variant == 1 else (0.82 if variant == 2 else 1.05)
			var nudge := Vector3(
				lerpf(-reach, reach,
					float(posmod(attempt_roll >> 5, 997)) / 996.0),
				0.0,
				lerpf(-reach, reach,
					float(posmod(attempt_roll >> 17, 997)) / 996.0))
			pivot.position = origin + nudge
			pivot.rotation.y = original_pivot_xf.basis.get_euler().y + turn
			var spin := Basis(Vector3.UP, turn)
			for collider in collider_xfs:
				var c := collider as Node3D
				var base: Transform3D = collider_xfs[collider]
				c.position = origin + nudge + spin * (base.origin - origin)
				c.rotation.y = base.basis.get_euler().y + turn
			var candidate := _furnishing_group_rect(
				pivot, group_colliders.get(gid, []))
			if _furnishing_variant_rect_valid(candidate, gid, occupied):
				occupied[gid] = candidate
				pivot.set_meta("mutation_furniture_moved", true)
				mutation_furniture_changed_groups += 1
				if pivot == fallback_pivot:
					witness_changed = true
				accepted = true
				break
		if not accepted:
			pivot.transform = original_pivot_xf
			for collider in collider_xfs:
				(collider as Node3D).transform = collider_xfs[collider]
	# The first eligible group is the room's designated witness. It must change
	# even when another, off-camera group already moved. If all seven safe pose
	# attempts fail, removal is collision-safe and mutation-back restores it.
	if not witness_changed and fallback_pivot != null \
			and is_instance_valid(fallback_pivot):
		remove_pivots.append(fallback_pivot)
		for collider in fallback_colliders:
			remove_colliders.append(collider)
		mutation_furniture_changed_groups += 1
		witness_changed = true
	# Some otherwise valid sparse rooms contain no opted-in furnishing at all.
	# Their generated alternate reality gains one plain chair at a fully tested
	# floor site. Appearance is as legible a mutation as movement, and rebuilding
	# the base state removes it exactly. The same clearance contract below audits
	# this chair like every moved furnishing group.
	if mutation_furniture_changed_groups == 0:
		_add_reality_chair(variant)
	for pivot in remove_pivots:
		if is_instance_valid(pivot) and pivot.get_parent() == self:
			remove_child(pivot)
			pivot.free()
	for collider in remove_colliders:
		if is_instance_valid(collider) and collider.get_parent() == body:
			body.remove_child(collider)
			collider.free()


func _add_reality_chair(variant: int) -> bool:
	var plan := _reality_chair_plan(variant)
	if plan.is_empty():
		return false
	var p: Vector3 = plan["position"]
	var yaw := float(plan["yaw"])
	var first_collider := body.get_child_count()
	var pivot := _furnishing_pivot(p, yaw, "reality_chair")
	pivot.set_meta("descent_reality_furniture", true)
	pivot.set_meta("mutation_furniture_moved", true)
	var parts: Array[Array] = [
		[Vector3(0, 0.48, 0), Vector3(0.66, 0.11, 0.62)],
		[Vector3(0, 0.78, 0.26), Vector3(0.66, 0.64, 0.09)],
		[Vector3(-0.25, 0.23, -0.22), Vector3(0.08, 0.46, 0.08)],
		[Vector3(0.25, 0.23, -0.22), Vector3(0.08, 0.46, 0.08)],
		[Vector3(-0.25, 0.23, 0.22), Vector3(0.08, 0.46, 0.08)],
		[Vector3(0.25, 0.23, 0.22), Vector3(0.08, 0.46, 0.08)],
	]
	for part in parts:
		var local_pos: Vector3 = part[0]
		var size: Vector3 = part[1]
		var world_pos := _wp(p, local_pos, yaw)
		var mesh := _box(world_pos, size, Mats.darkwood(), false)
		mesh.rotation.y = yaw
		_adopt_local(pivot, mesh)
		_collider_yaw_box(world_pos, size, yaw)
	_bind_furnishing_colliders(pivot, first_collider)
	mutation_furniture_changed_groups = 1
	return true


func _reality_chair_plan(variant: int) -> Dictionary:
	var candidates: Array[Vector3] = []
	for x in range(2, 11):
		for z in range(2, 11):
			candidates.append(Vector3(float(x), _floor_h(), float(z)))
	var start := posmod(WorldGen.h(
		wseed, cell.x, cell.y, 5939 + variant * 211), candidates.size())
	var doorway_zones := _doorway_clearance_rects()
	for i in candidates.size():
		var p := candidates[(start + i) % candidates.size()]
		var footprint := Rect2(p.x - 0.42, p.z - 0.42, 0.84, 0.84)
		var blocked := false
		for zone in doorway_zones:
			if footprint.grow(0.12).intersects(zone):
				blocked = true
				break
		if blocked or not _floor_spot_clear(p, 0.46, 1.2):
			continue
		var yaw := float(posmod(start + i + variant, 4)) * PI * 0.5
		return {"position": p, "yaw": yaw}
	return {}


func _furnishing_group_rect(pivot: Node3D, colliders: Array) -> Rect2:
	var rects: Array[Rect2] = []
	_collect_low_mesh_rects(pivot, Transform3D.IDENTITY, rects)
	for value in colliders:
		var collider := value as CollisionShape3D
		if collider == null:
			continue
		var rect := _collision_floor_rect(collider)
		if rect.size != Vector2.ZERO:
			rects.append(rect)
	if rects.is_empty():
		return Rect2(pivot.position.x - 0.1, pivot.position.z - 0.1, 0.2, 0.2)
	var merged := rects[0]
	for i in range(1, rects.size()):
		merged = merged.merge(rects[i])
	return merged


func _furnishing_variant_rect_valid(candidate: Rect2, gid: int,
		occupied: Dictionary) -> bool:
	if candidate.size == Vector2.ZERO:
		return false
	var bounds := _mutation_room_bounds().grow(-0.45)
	if not bounds.encloses(candidate):
		return false
	for zone in _doorway_clearance_rects():
		if candidate.grow(0.12).intersects(zone):
			return false
	for other_gid in occupied:
		if int(other_gid) == gid:
			continue
		var other: Rect2 = occupied[other_gid]
		if candidate.grow(0.12).intersects(other.grow(0.12)):
			return false
	return true


func _mutation_room_bounds() -> Rect2:
	var members := _room_members()
	if members.is_empty():
		return Rect2(0.0, 0.0, S, S)
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for member in members:
		var local := Vector2(float(member.x - cell.x) * S,
			float(member.y - cell.y) * S)
		minp = minp.min(local)
		maxp = maxp.max(local + Vector2.ONE * S)
	return Rect2(minp, maxp - minp)


## Focused audit hook for generated furniture realities.
func mutation_furniture_clearance_violations() -> int:
	if mutation_furniture_variant <= 0:
		return 0
	var group_colliders := {}
	for child in body.get_children():
		var gid := int(child.get_meta("furnishing_group", -1))
		if gid < 0:
			continue
		if not group_colliders.has(gid):
			group_colliders[gid] = []
		group_colliders[gid].append(child)
	var occupied := {}
	var moved: Array[Node3D] = []
	for child in get_children():
		var pivot := child as Node3D
		if pivot == null or not pivot.has_meta("furnishing_group"):
			continue
		var gid := int(pivot.get_meta("furnishing_group"))
		occupied[gid] = _furnishing_group_rect(
			pivot, group_colliders.get(gid, []))
		if bool(pivot.get_meta("mutation_furniture_moved", false)):
			moved.append(pivot)
	var bad := 0
	for pivot in moved:
		var gid := int(pivot.get_meta("furnishing_group"))
		if not _furnishing_variant_rect_valid(
				occupied[gid], gid, occupied):
			bad += 1
	return bad


## Runtime staging gate. A planned furniture reality is accepted only when its
## owning Chunk demonstrably changed a group and the completed replacement is
## clear of both furniture and doorway contracts.
func mutation_rebuild_valid() -> bool:
	if mutation_furniture_variant <= 0 or not is_room_anchor:
		return true
	return mutation_furniture_changed_groups > 0 \
		and mutation_furniture_clearance_violations() == 0 \
		and doorway_clearance_violations() == 0


func _mesh_is_emissive(mesh: MeshInstance3D) -> bool:
	var mat := mesh.material_override
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).emission_enabled
	return false


func _has_slot_rear(node: Node) -> bool:
	if node.has_meta("slot_rear_shell"):
		return true
	for child in node.get_children():
		if _has_slot_rear(child):
			return true
	return false
func _has_slot_front(node: Node) -> bool:
	if node.has_meta("slot_front_shell"):
		return true
	for child in node.get_children():
		if _has_slot_front(child):
			return true
	return false


## Regression hooks for the casino audit. Every surviving machine needs an
## explicit closed front and rear volume; relying on custom-mesh faces or a
## stack of display quads is not enough because every bank is walkable.
## Regression hooks for the casino audit. Every surviving machine needs an
## explicit closed front and rear volume; relying on custom-mesh faces or a
## stack of display quads is not enough because every bank is walkable.
func slot_machine_count() -> int:
	var count := 0
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("slot_machine"):
			count += 1
	return count
func slot_back_violations() -> int:
	var bad := 0
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("slot_machine") and not _has_slot_rear(node):
			bad += 1
	return bad
func slot_front_violations() -> int:
	var bad := 0
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("slot_machine") and not _has_slot_front(node):
			bad += 1
	return bad


func _rope_barrier(p: Vector3, yaw: float, kind: String) -> Node3D:
	var b0 := body.get_child_count()
	var pivot := _attributed_floor_prop(ROPE_BARRIER_PATH, p, yaw,
		ROPE_BARRIER_SCALE, ROPE_BARRIER_CENTRE, kind, null, true)
	if pivot == null:
		return null
	# Posts collide; the swag between them does not, so a player can duck a
	# queue line the way the geometry suggests they should be able to.
	var half := ROPE_BARRIER_PITCH * 0.5
	for side in [-1.0, 1.0]:
		var off := Vector3(side * half, 0, 0).rotated(Vector3.UP, yaw)
		_collider_cyl(p + off + Vector3(0, 0.51, 0), 0.09, 1.02)
	_bind_furnishing_colliders(pivot, b0)
	return pivot


func _planter(p: Vector3) -> void:
	# real potted plants; the office gets the sadder, squatter one
	var mname := "potted_plant_02" if theme == 1 else "potted_plant_01"
	_cc0_prop(mname, p, _r(23) * TAU)
	_collider_cyl(p + Vector3(0, 0.5, 0), 0.32, 1.0)


func _office_ibm_terminal(workstation: Node3D, deskc: Vector3, yaw: float,
		qi: int) -> bool:
	var top := deskc + Vector3(0, 0.7475, 0)
	var pivot := _attributed_floor_prop(OFFICE_TERMINAL_PATH, top,
		yaw - PI / 2.0 + (_r(1240 + qi) - 0.5) * 0.16, OFFICE_TERMINAL_SCALE,
		OFFICE_TERMINAL_CENTRE, "ibm_3278", workstation)
	if pivot == null:
		return false
	var stray := pivot.find_child("Lamp", true, false)
	if stray != null:
		stray.get_parent().remove_child(stray)
		stray.free()
	_set_office_terminal_screen(pivot)
	return true


## Replace the imported prop's original fictional login image while preserving
## its authored curved screen geometry and UV mapping.
## Replace the imported prop's original fictional login image while preserving
## its authored curved screen geometry and UV mapping.
func _set_office_terminal_screen(terminal: Node3D) -> void:
	var screen := terminal.find_child("ibm_3278_1", true, false) as MeshInstance3D
	if screen == null:
		return
	var source := screen.mesh.surface_get_material(0) as BaseMaterial3D
	var display := source.duplicate() as BaseMaterial3D \
		if source != null else StandardMaterial3D.new()
	display.albedo_texture = OFFICE_TERMINAL_SCREEN
	display.emission_enabled = true
	display.emission_texture = OFFICE_TERMINAL_SCREEN
	# The source image is deliberately near-black; a strong CRT emission keeps
	# its fine lettering readable under the office's exposure and post-process.
	display.emission_energy_multiplier = 4.2
	screen.material_override = display
	screen.set_meta("office_terminal_custom_screen", true)


func _filing_bank(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	var along := S / 2.0 + (_r(59 + dir) - 0.5) * 4.0
	var count := 3 + int(_r(60 + dir) * 1.99)
	var open_i := int(_r(61 + dir) * float(count) * 0.99)
	# Keep the open drawer at a usable hand height. A bottom drawer pulled
	# nearly its full depth read as a detached cabinet block on the floor.
	var open_j := 1 + int(_r(62 + dir) * 1.99)
	for i in count:
		var t := along + (float(i) - float(count - 1) / 2.0) * 0.5
		var v := Node3D.new()
		if dir < 2:
			v.position = Vector3(inner + n * 0.31, 0, t)
			v.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
		else:
			v.position = Vector3(t, 0, inner + n * 0.31)
			v.rotation.y = 0.0 if n > 0.0 else PI
		v.set_meta("filing_bank_cabinet", true)
		v.set_meta("filing_bank_dir", dir)
		add_child(v)
		_mrbox(v, Vector3(0, 0.66, 0), Vector3(0.46, 1.32, 0.6), Mats.metal_gray(), 0.015)
		for j in 4:
			# The old 0.18m anchor lifted the complete drawer stack 13cm and
			# pushed the top face beyond the 1.32m cabinet shell.
			var dy := 0.05 + 0.31 * float(j)
			if i == open_i and j == open_j:
				# A short 12cm pull exposes the paper insert without projecting
				# a full filing-box depth into the walkway.
				var drawer := _mbox(v, Vector3(0, dy + 0.13, 0.365),
					Vector3(0.4, 0.24, 0.13), Mats.metal_gray())
				drawer.set_meta("filing_bank_open_drawer", true)
				drawer.set_meta("filing_bank_open_row", j)
				drawer.set_meta("filing_bank_projection", 0.128)
				drawer.set_meta("filing_bank_dir", dir)
				var open_face := _mbox(v, Vector3(0, dy + 0.14, 0.436),
					Vector3(0.4, 0.27, 0.012), Mats.divider_gray())
				open_face.set_meta("filing_bank_drawer_face", true)
				open_face.set_meta("filing_bank_drawer_row", j)
				_mbox(v, Vector3(0, dy + 0.245, 0.449),
					Vector3(0.13, 0.022, 0.014), Mats.chrome())
				_mbox(v, Vector3(0, dy + 0.23, 0.375),
					Vector3(0.34, 0.02, 0.10), Mats.box_white())
			else:
				var closed_face := _mbox(v, Vector3(0, dy + 0.14, 0.302),
					Vector3(0.4, 0.27, 0.012), Mats.divider_gray())
				closed_face.set_meta("filing_bank_drawer_face", true)
				closed_face.set_meta("filing_bank_drawer_row", j)
				_mbox(v, Vector3(0, dy + 0.245, 0.315),
					Vector3(0.13, 0.022, 0.014), Mats.chrome())
	var cc: Vector3
	var csize: Vector3
	if dir < 2:
		cc = Vector3(inner + n * 0.31, 0.66, along)
		csize = Vector3(0.65, 1.32, 0.5 * float(count) + 0.1)
	else:
		cc = Vector3(along, 0.66, inner + n * 0.31)
		csize = Vector3(0.5 * float(count) + 0.1, 1.32, 0.65)
	_collider_box(cc, csize)


const OFFICE_POSTERS := ["SAFETY IS EVERYONE'S JOB", "HAVE YOU FILED YOUR 4-19?",
	"THE BUILDING THANKS YOU", "PLEASE CONSERVE LIGHT", "TIDY DESK, TIDY MIND",
	"YOUR DESK MISSES YOU", "CONSISTENCY IS COMFORT", "STAY UNTIL COMPLETE",
	"EVERYONE IS COUNTING ON YOU", "A QUIET FLOOR IS A PRODUCTIVE FLOOR"]


func _vt100(pos: Vector3, yaw: float) -> Node3D:
	var p := Node3D.new()
	p.set_meta("terminal_body", true)
	p.position = Vector3(pos.x, 0, pos.z)
	p.rotation.y = yaw
	add_child(p)
	var shell := Mats.crt_shell()
	var dark := Mats.crt_dark()
	# inset plinth, then the big beige housing (front face at z=0.10)
	_mrbox(p, Vector3(0, 0.7725, -0.05), Vector3(0.36, 0.05, 0.30), shell, 0.012)
	_mrbox(p, Vector3(0, 0.95, -0.08), Vector3(0.44, 0.30, 0.36), shell, 0.03)
	# broad bezel frame overlapping the housing front, opening 0.30 x 0.225
	_mrbox(p, Vector3(0, 1.0825, 0.125), Vector3(0.44, 0.035, 0.06), shell, 0.008)
	_mrbox(p, Vector3(0, 0.82, 0.125), Vector3(0.44, 0.04, 0.06), shell, 0.008)
	_mrbox(p, Vector3(-0.185, 0.9525, 0.125), Vector3(0.07, 0.225, 0.06), shell, 0.008)
	_mrbox(p, Vector3(0.185, 0.9525, 0.125), Vector3(0.07, 0.225, 0.06), shell, 0.008)
	# dark cavity behind the opening; the phosphor glass sits recessed in it
	_mrbox(p, Vector3(0, 0.9525, 0.095), Vector3(0.34, 0.26, 0.05), dark, 0.012)
	var screen := _mquad(p, Vector3(0, 0.9525, 0.121), TERMINAL_SCREEN_SIZE, Mats.crt())
	screen.set_meta("terminal_screen", true)
	screen.set_instance_shader_parameter("queried", 0.0)
	# dark trim strip across the top front, and a little model badge
	_mrbox(p, Vector3(0, 1.103, 0.03), Vector3(0.36, 0.012, 0.12), dark, 0.004)
	_mrbox(p, Vector3(0.13, 0.826, 0.155), Vector3(0.055, 0.016, 0.008), dark, 0.003)
	var readout := Label3D.new()
	readout.set_meta("terminal_readout", true)
	readout.text = TERMINAL_PAGES[WorldGen.h(wseed, cell.x, cell.y, 1801) % TERMINAL_PAGES.size()]
	readout.visible = false
	# Label3D is not clipped by the screen quad. Size its complete layout inside
	# the phosphor glass and recess it behind the bezel so neither this terminal
	# nor the one in the next cubicle can paint glyphs over the housing.
	readout.font_size = TERMINAL_TEXT_FONT_SIZE
	readout.font = TERMINAL_FONT
	readout.pixel_size = TERMINAL_TEXT_PIXEL_SIZE
	readout.width = TERMINAL_TEXT_LAYOUT_WIDTH
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	readout.autowrap_mode = TextServer.AUTOWRAP_OFF
	readout.modulate = Color(0.45, 0.96, 1.0, 0.94)
	readout.outline_size = 0
	readout.outline_modulate = Color(0.0, 0.045, 0.075, 0.92)
	readout.double_sided = false
	readout.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	readout.position = Vector3(0, 0.952, 0.147)
	p.add_child(readout)
	var hit := Interactable.new()
	hit.prompt_text = "E — query terminal"
	hit.position = Vector3(0, 0.96, 0.29)
	hit.add_box(Vector3(0.58, 0.48, 0.40))
	p.add_child(hit)
	hit.set_meta("page", WorldGen.h(wseed, cell.x, cell.y, 1801) % TERMINAL_PAGES.size())
	hit.set_meta("initial_page", hit.get_meta("page"))
	hit.set_meta("queried", false)
	hit.activated.connect(_use_terminal.bind(hit, readout, screen))
	hit.focus_exited.connect(_reset_terminal.bind(hit, readout, screen))
	return p


## The interaction callbacks belong with _vt100 rather than in the office
## builder: prison guard desks build the same terminal, so reaching these
## through the active builder failed on any theme but office, which aborted
## _vt100 and left the terminal parented to the chunk instead of the desk.
func _use_terminal(_actor: Node, hit: Interactable, readout: Label3D,
		screen: MeshInstance3D) -> void:
	var page := int(hit.get_meta("page", 0))
	if not bool(hit.get_meta("queried", false)):
		hit.set_meta("queried", true)
		readout.visible = true
		screen.set_instance_shader_parameter("queried", 1.0)
	else:
		page = (page + 1) % TERMINAL_PAGES.size()
		hit.set_meta("page", page)
		readout.text = TERMINAL_PAGES[page]
	hit.prompt_text = "E — next record"
	get_tree().call_group("level_manager", "terminal_activity", page)


func _reset_terminal(hit: Interactable, readout: Label3D,
		screen: MeshInstance3D) -> void:
	var page := int(hit.get_meta("initial_page", 0))
	hit.set_meta("page", page)
	hit.set_meta("queried", false)
	hit.prompt_text = "E — query terminal"
	readout.text = TERMINAL_PAGES[page]
	readout.visible = false
	screen.set_instance_shader_parameter("queried", 0.0)


## Every CRT belongs beneath a workstation pivot. Doorway clearance operates
## on that pivot, preventing the desk from disappearing independently of the
## terminal and its loose desktop props.
## Every CRT belongs beneath a workstation pivot. Doorway clearance operates
## on that pivot, preventing the desk from disappearing independently of the
## terminal and its loose desktop props.
func terminal_support_violations() -> int:
	var bad := 0
	for node in find_children("*", "Node3D", true, false):
		if not node.has_meta("terminal_body"):
			continue
		var ancestor := node.get_parent()
		var supported := false
		while ancestor != null and ancestor != self:
			if ancestor.has_meta("office_workstation"):
				supported = true
				break
			ancestor = ancestor.get_parent()
		if not supported:
			bad += 1
	return bad


## Teacher-desk accessories may only exist beneath the complete teacher
## station. This specifically guards against the cup-and-pens orphan that
## doorway clearance exposed in classrooms.
## Teacher-desk accessories may only exist beneath the complete teacher
## station. This specifically guards against the cup-and-pens orphan that
## doorway clearance exposed in classrooms.
func school_stationery_support_violations() -> int:
	var bad := 0
	for node in find_children("*", "Node3D", true, false):
		if not node.has_meta("school_teacher_stationery"):
			continue
		var ancestor := node.get_parent()
		var supported := false
		while ancestor != null and ancestor != self:
			if str(ancestor.get_meta("atomic_furnishing", "")) \
					== "school_teacher_station":
				supported = true
				break
			ancestor = ancestor.get_parent()
		if not supported:
			bad += 1
		var supplies := node as Node3D
		var source_bottom := float(
			node.get_meta("school_stationery_source_bottom", INF))
		var desk_top := float(node.get_meta("school_stationery_desk_top", -INF))
		var contact_y := supplies.position.y + source_bottom
		var quarter_turn_error := absf(wrapf(
			supplies.rotation.y - PI / 2.0, -PI, PI))
		if absf(contact_y - desk_top) > 0.004 \
				or quarter_turn_error > 0.07 \
				or absf(float(node.get_meta(
					"school_stationery_quarter_turn", 0.0)) - PI / 2.0) > 0.001:
			bad += 1
	return bad


func school_fixture_integrity_audit() -> Dictionary:
	var report := {
		"carts": 0,
		"stalls": 0,
		"urinals": 0,
		"doors": 0,
		"library_stacks": 0,
		"encyclopedia_sets": 0,
		"elevators": 0,
		"admin_counters": 0,
		"violations": 0,
	}
	if theme != 6:
		return report
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("school_swing_door"):
			report["doors"] = int(report["doors"]) + 1
			var leaf_top := float(node.get_meta("school_door_leaf_top", 0.0))
			var frame_top := float(node.get_meta("school_door_frame_top", INF))
			var operating_gap := frame_top - leaf_top
			if operating_gap < 0.0 or operating_gap > 0.031:
				report["violations"] = int(report["violations"]) + 1
		if str(node.get_meta("attributed_furnishing", "")) \
				== "school_urinal":
			report["urinals"] = int(report["urinals"]) + 1
			var depth := float(node.get_meta("school_urinal_depth", 0.0))
			var clearance := float(
				node.get_meta("school_urinal_wall_clearance", 0.0))
			var standoff := float(
				node.get_meta("school_urinal_mount_standoff", 0.0))
			var dir := int(node.get_meta("school_urinal_wall_dir", -1))
			if dir < 0 or dir > 3 \
					or depth < 0.30 \
					or clearance < 0.01 \
					or absf(standoff - (depth * 0.5 + clearance)) > 0.002:
				report["violations"] = int(report["violations"]) + 1
		if node.has_meta("school_library_stack"):
			report["library_stacks"] = int(report["library_stacks"]) + 1
			var owned_books := 0
			for child in node.find_children("*", "Node3D", true, false):
				if child.has_meta("school_library_encyclopedia_set"):
					owned_books += 1
			if owned_books != 1:
				report["violations"] = int(report["violations"]) + 1
		if node.has_meta("school_library_encyclopedia_set"):
			report["encyclopedia_sets"] = int(report["encyclopedia_sets"]) + 1
			var support := node.get_parent()
			var has_stack := false
			while support != null and support != self:
				if support.has_meta("school_library_stack"):
					has_stack = true
					break
				support = support.get_parent()
			if not has_stack:
				report["violations"] = int(report["violations"]) + 1
		if node.has_meta("elevator_facade"):
			report["elevators"] = int(report["elevators"]) + 1
		if node.has_meta("school_admin_counter"):
			report["admin_counters"] = int(report["admin_counters"]) + 1
		# The authored cart carries its own opaque materials. The generated one
		# is still the fallback and still has to be checked: its tub was once
		# built from translucent water-jug plastic, and the wheels and the wall
		# behind it showed through.
		if str(node.get_meta("attributed_furnishing", "")) \
				== "school_janitor_trolley":
			report["carts"] = int(report["carts"]) + 1
		if node.has_meta("school_cart_opaque_body"):
			report["carts"] = int(report["carts"]) + 1
			var mesh := node as MeshInstance3D
			var mat := mesh.material_override as BaseMaterial3D
			if mat == null \
					or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				report["violations"] = int(report["violations"]) + 1
		if not node.has_meta("school_stall_complete"):
			continue
		report["stalls"] = int(report["stalls"]) + 1
		var doors := 0
		var toilets := 0
		for child in node.find_children("*", "Node3D", true, false):
			if child.has_meta("school_stall_door"):
				doors += 1
			if child.has_meta("school_stall_toilet"):
				toilets += 1
		if doors != 1 or toilets != 1:
			report["violations"] = int(report["violations"]) + 1
	if WorldGen.elevator_cell(wseed, cell, theme):
		if int(report["elevators"]) != 1 \
				or int(report["admin_counters"]) != 0:
			report["violations"] = int(report["violations"]) + 1
		for node in find_children("*", "Node3D", true, false):
			if node.has_meta("school_projector_screen"):
				report["violations"] = int(report["violations"]) + 1
	return report


## Matching wedge keyboard: beige base, dark key deck, rows of black caps.
func _vt100_keyboard(pos: Vector3, yaw: float) -> Node3D:
	var p := Node3D.new()
	p.position = Vector3(pos.x, 0, pos.z)
	p.rotation.y = yaw
	add_child(p)
	_mrbox(p, Vector3(0, 0.766, 0), Vector3(0.42, 0.035, 0.17), Mats.crt_shell(), 0.01)
	_mrbox(p, Vector3(0, 0.7855, -0.01), Vector3(0.38, 0.014, 0.125), Mats.crt_dark(), 0.004)
	for row in 4:
		var rz := -0.058 + 0.026 * row
		var rx := row * 0.004 - 0.006
		for col in 12:
			_mbox(p, Vector3(rx - 0.154 + 0.028 * col, 0.799, rz), Vector3(0.024, 0.014, 0.02), Mats.charcoal())
	_mbox(p, Vector3(0, 0.799, 0.044), Vector3(0.13, 0.012, 0.018), Mats.charcoal())
	return p


func _shelf_unit(c: Vector3, along_x: bool, salt: int) -> void:
	var body0 := body.get_child_count()
	var rack := _furnishing_pivot(c, 0.0, "shelf_unit")
	var half := Vector3(1.2, 0, 0.3) if along_x else Vector3(0.3, 0, 1.2)
	for px in [-1.0, 1.0]:
		for pz in [-1.0, 1.0]:
			var corner := Vector3(half.x * px, 0, half.z * pz)
			_mbox(rack, corner + Vector3(0, 1.1, 0),
				Vector3(0.05, 2.2, 0.05), Mats.metal_gray())
	var shelf_size := Vector3(2.4, 0.04, 0.6) if along_x else Vector3(0.6, 0.04, 2.4)
	for sy in [0.5, 1.1, 1.7]:
		_mbox(rack, Vector3(0, sy, 0), shelf_size, Mats.metal_gray())
		for bi in 4:
			if WorldGen.r01(wseed, cell.x + bi, cell.y + int(sy * 10.0), salt) < 0.72:
				var t := -0.9 + 0.6 * bi
				var shelf_pos := (Vector3(t, sy + 0.02, 0)
					if along_x else Vector3(0, sy + 0.02, t))
				var box_yaw := (WorldGen.r01(wseed, cell.x + bi,
					cell.y + int(sy * 7.0), salt + 1) - 0.5) * 0.14
				var authored := theme == 1 and _shelf_box(rack,
					shelf_pos, box_yaw, WorldGen.h(wseed, cell.x + bi,
						cell.y + int(sy * 10.0), salt + 91) % OFFICE_BOX_VARIANTS.size())
				if not authored:
					var bpos := shelf_pos + Vector3(0, 0.18, 0)
					var bx := _mrbox(rack, bpos, Vector3(0.5, 0.34, 0.45),
						Mats.box_white(), 0.01)
					bx.rotation.y = box_yaw
	_collider_box(c + Vector3(0, 1.1, 0), Vector3(2.5, 2.2, 0.65) if along_x else Vector3(0.65, 2.2, 2.5))
	_bind_furnishing_colliders(rack, body0)


## Pull one real-world box variant out of the supplied Sketchfab set, discard
## the staged duplicates, then centre and bottom-align it on a generated shelf.
func _shelf_box(parent: Node3D, pos: Vector3, yaw: float,
		variant: int, kind := "office_shelf_box") -> bool:
	var ps: PackedScene = _attributed_scenes.get(OFFICE_BOXES_PATH)
	if ps == null:
		ps = _prop_scene(OFFICE_BOXES_PATH)
		_attributed_scenes[OFFICE_BOXES_PATH] = ps
	if ps == null:
		return false
	var inst := ps.instantiate() as Node3D
	var set_root := inst.find_child("RootNode", true, false)
	var wanted: String = OFFICE_BOX_VARIANTS[variant]
	if set_root == null:
		inst.free()
		return false
	for staged in set_root.get_children():
		if staged.name != wanted:
			set_root.remove_child(staged)
			staged.free()
	if set_root.find_child(wanted, false, false) == null:
		inst.free()
		return false
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	holder.set_meta("attributed_furnishing", kind)
	holder.set_meta("attributed_asset", OFFICE_BOXES_PATH)
	parent.add_child(holder)
	holder.add_child(inst)
	var state := [AABB(), false]
	_collect_model_bounds(inst, Transform3D.IDENTITY, state)
	if not bool(state[1]):
		holder.get_parent().remove_child(holder)
		holder.free()
		return false
	var bounds: AABB = state[0]
	inst.position = Vector3(-bounds.get_center().x, -bounds.position.y,
		-bounds.get_center().z)
	return true


func _collect_model_bounds(node: Node, parent_xf: Transform3D,
		state: Array) -> void:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var bounds := xf * (node as MeshInstance3D).mesh.get_aabb()
		state[0] = (state[0] as AABB).merge(bounds) if bool(state[1]) else bounds
		state[1] = true
	for child in node.get_children():
		_collect_model_bounds(child, xf, state)


func _annex_fixture_clear(at: Vector3) -> bool:
	var half := ANNEX_CEILING_TILE * 0.5 + ANNEX_FIXTURE_CLEARANCE
	var fixture := Rect2(
		Vector2(at.x - half, at.z - half),
		Vector2(half * 2.0, half * 2.0))
	for obstruction in _annex_ceiling_obstructions:
		if fixture.intersects(obstruction):
			return false
	return true


## Runtime regression hook: every visible Annex panel must still own a complete,
## unobstructed ceiling tile after all deterministic architecture is present.
## Runtime regression hook: every visible Annex panel must still own a complete,
## unobstructed ceiling tile after all deterministic architecture is present.
func annex_fixture_obstruction_violations() -> int:
	if theme != 2:
		return 0
	var bad := 0
	for node in find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("annex_ceiling_light_size") \
				and not _annex_fixture_clear((node as MeshInstance3D).position):
			bad += 1
	return bad


func _cut_seg(segs: Array, c0: float, c1: float) -> Array:
	var out := []
	for sg in segs:
		if c1 <= sg[0] or c0 >= sg[1]:
			out.append(sg)
			continue
		if c0 > sg[0]:
			out.append([sg[0], c0])
		if c1 < sg[1]:
			out.append([c1, sg[1]])
	return out


# --- sewer: props ------------------------------------------------------------


## One complete pump train per occupied room cell. Keeping each skid in a dry
## corner preserves the central water graph and turns merged rooms into actual
## pump works instead of one machine marooned in a warehouse.
func _sewer_pump_skid(c: Vector3, sx: float, sz: float, salt: int) -> void:
	_box(c + Vector3(0, 0.07, 0), Vector3(2.6, 0.14, 1.8), Mats.concrete_floor())
	# horizontal tank on saddles
	var tk := _cyl(c + Vector3(0, 1.02, -0.25 * sz), 0.5, 1.9, Mats.pipe_green(), false)
	tk.rotation.z = PI / 2.0
	_collider_box(c + Vector3(0, 1.0, -0.25 * sz), Vector3(1.9, 1.05, 1.0))
	for support_x in [-0.6, 0.6]:
		_box(c + Vector3(support_x, 0.42, -0.25 * sz),
			Vector3(0.16, 0.84, 0.9), Mats.iron_dark(), false)
	for ex in [-0.95, 0.95]:
		_sphere(c + Vector3(ex, 1.02, -0.25 * sz), 0.48, Mats.pipe_green())
	# pump block and motor
	_box(c + Vector3(-0.5 * sx, 0.32, 0.55 * sz), Vector3(0.7, 0.5, 0.55), Mats.iron_dark())
	var mot := _cyl(c + Vector3(0.25 * sx, 0.42, 0.55 * sz), 0.19, 0.6, Mats.pipe_green(), false)
	mot.rotation.z = PI / 2.0
	# riser to the ceiling with a valve wheel
	_cyl(c + Vector3(0.9 * sx, (1.3 + ceil_h) / 2.0, -0.25 * sz),
		0.12, ceil_h - 1.3, Mats.pipe_rust(), false)
	var vw := MeshInstance3D.new()
	vw.mesh = TOR
	vw.material_override = Mats.iron_dark()
	vw.position = c + Vector3((0.9 - 0.17) * sx, 1.85, -0.25 * sz)
	vw.rotation.z = PI / 2.0
	vw.scale = Vector3(0.24, 0.24, 0.24)
	add_child(vw)
	# one stubborn status lamp makes the machinery legible through the mist
	_sphere(c + Vector3(-0.5 * sx, 0.63, 0.55 * sz), 0.045,
		Mats.lamp_green() if _r(salt) < 0.62 else Mats.lamp_red())
	# oily spill under the works
	_box(c + Vector3(0.1 * sx, 0.005, 0.3 * sz),
		Vector3(2.2, 0.01, 1.5), Mats.puddle(), false)


## Wall-hung service pipes: long horizontal runs with brackets, flanges and
## the odd vertical branch.
func _ceiling_pipes(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	var count := 1 + int(_r(42 + dir) * 1.99)
	for i in count:
		var r := 0.075 if i == 0 else 0.05
		var y := 2.14 + 0.28 * float(i)
		var mat: Material = Mats.pipe_rust() if _r(43 + dir + i) < 0.55 else Mats.pipe_green()
		var off := inner + n * (r + 0.06)
		var pipe := _cyl(Vector3(off, y, S / 2.0) if dir < 2 else Vector3(S / 2.0, y, off), r, S, mat, false)
		if dir < 2:
			pipe.rotation.x = PI / 2.0
		else:
			pipe.rotation.z = PI / 2.0
		for t in [2.0, 6.0, 10.0]:
			var bp := Vector3(inner + n * (r + 0.06) / 2.0, y, t) if dir < 2 else Vector3(t, y, inner + n * (r + 0.06) / 2.0)
			_box(bp, Vector3(r + 0.12, 0.05, 0.05) if dir < 2 else Vector3(0.05, 0.05, r + 0.12), Mats.iron_dark(), false)
		if _r(45 + dir + i) < 0.6:
			var ft := 3.0 + 6.0 * _r(46 + dir + i)
			var tor := MeshInstance3D.new()
			tor.mesh = TOR
			tor.material_override = mat
			tor.position = Vector3(off, y, ft) if dir < 2 else Vector3(ft, y, off)
			if dir < 2:
				tor.rotation.x = PI / 2.0
			else:
				tor.rotation.z = PI / 2.0
			tor.scale = Vector3(r * 1.9, r * 1.5, r * 1.9)
			add_child(tor)
	if _r(47 + dir) < 0.35:
		var t2 := 2.2 + 2.0 * _r(48 + dir)
		if _r(49 + dir) < 0.5:
			t2 = S - t2
		var off2 := inner + n * 0.135
		_cyl(Vector3(off2, 1.07, t2) if dir < 2 else Vector3(t2, 1.07, off2), 0.075, 2.14, Mats.pipe_rust(), false)
		_sphere(Vector3(off2, 2.18, t2) if dir < 2 else Vector3(t2, 2.18, off2), 0.1, Mats.pipe_rust())


# --- sewer: lighting & sound -------------------------------------------------


## Wall-mounted control cabinet: gauges, indicator lamps, conduit to nowhere.
## Half of them are a real breaker box instead.
func _sewer_panel(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(69 + dir) - 0.5) * 5.0
	if _r(73 + dir) < 0.5:
		if dir < 2:
			_cc0_prop("power_box_01", Vector3(inner + n * 0.03, 1.45, along), PI / 2.0 * n)
		else:
			_cc0_prop("power_box_01", Vector3(along, 1.45, inner + n * 0.03), 0.0 if n > 0.0 else PI)
		return
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner + n * 0.12, 1.35, along)
		v.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
	else:
		v.position = Vector3(along, 1.35, inner + n * 0.12)
		v.rotation.y = 0.0 if n > 0.0 else PI
	add_child(v)
	_mrbox(v, Vector3.ZERO, Vector3(0.72, 0.95, 0.2), Mats.pipe_green(), 0.02)
	_mbox(v, Vector3(0.1, 0, 0.102), Vector3(0.015, 0.8, 0.006), Mats.iron_dark())
	for gi in 2:
		var gx := -0.2 + 0.28 * float(gi)
		var g := _mcyl(v, Vector3(gx, 0.24, 0.115), 0.07, 0.03, Mats.paint_white())
		g.rotation.x = PI / 2.0
		var nd := _mbox(v, Vector3(gx, 0.26, 0.135), Vector3(0.008, 0.05, 0.005), Mats.charcoal())
		nd.rotation.z = (_r(70 + dir + gi) - 0.5) * 2.0
	var lamps: Array = [Mats.lamp_red(), Mats.lamp_amber(), Mats.lamp_green()]
	var lit := int(_r(71 + dir) * 2.99)
	for li in 3:
		var lmat: Material = lamps[li] if li == lit else Mats.charcoal()
		_mbox(v, Vector3(-0.2 + 0.2 * float(li), -0.12, 0.11), Vector3(0.05, 0.05, 0.02), lmat)
	_mcyl(v, Vector3(0.22, (ceil_h - 1.35) / 2.0 + 0.475, -0.02), 0.028, ceil_h - 1.35 - 0.95, Mats.iron_dark())
	_collider_yaw_box(v.position, Vector3(0.75, 0.95, 0.3), v.rotation.y)


## Chain hanging from a ceiling hook, swaying in air that never moves.
func _chain(p: Vector3) -> void:
	var links := 3 + int(_r(267) * 5.0)
	for i in links:
		var tor := MeshInstance3D.new()
		tor.mesh = TOR
		tor.material_override = Mats.iron_dark()
		tor.position = p + Vector3(0, ceil_h - 0.08 - 0.085 * float(i), 0)
		tor.rotation.x = PI / 2.0
		if i % 2 == 1:
			tor.rotation.y = PI / 2.0
		tor.scale = Vector3(0.055, 0.045, 0.055)
		tor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tor)


# --- shared primitives -------------------------------------------------------

## Box strut from a to b — the workhorse for wheels, wires and legs.
func _beam(a: Vector3, b: Vector3, th: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BOX
	mi.material_override = mat
	var d := b - a
	var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(d, up), (a + b) / 2.0)
	mi.scale = Vector3(th, th, d.length())
	add_child(mi)
	return mi


# --- airport -----------------------------------------------------------------

const AIR_DESTS := ["AMSTERDAM", "SINGAPORE", "DENVER", "REYKJAVIK", "OSAKA",
	"LIMA", "TBILISI", "PERTH", "MONTREAL", "DOHA", "HELSINKI", "ANCHORAGE",
	"MANAUS", "TAIPEI", "LAGOS", "ZURICH"]
const AIR_STATUS := ["DELAYED", "DELAYED", "ON TIME", "BOARDING", "DELAYED",
	"CANCELLED", "GATE WAIT", "DELAYED"]
const AIR_ZONE_SIGNS := [
	["Gates A1 - A22  >", "<  Gates B1 - B14", "Transfers", "Lounges  >"],
	["Departures  >", "<  Check-in", "Security", "Gates  >"],
	["Baggage Claim", "Exit  >", "<  Passport Control", "Trains to City"],
]


func _msphere(parent: Node3D, pos: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = SPH
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3.ONE * (r / 0.5)
	parent.add_child(mi)
	return mi


func _collider_yaw_box(pos: Vector3, size: Vector3, yaw: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation.y = yaw
	body.add_child(cs)


func _collider_rot_box(pos: Vector3, size: Vector3,
		rot: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation = rot
	body.add_child(cs)
	return cs


## Rotate a local offset into chunk space around an anchor's yaw.
func _wp(o: Vector3, local: Vector3, yaw: float) -> Vector3:
	return o + local.rotated(Vector3.UP, yaw)


func _yaw_for(dir: int) -> float:
	match dir:
		0: return PI / 2.0
		1: return -PI / 2.0
		2: return 0.0
	return PI


func _room_members() -> Array[Vector2i]:
	return WorldGen.owning_room_members(wseed, room_root, theme)


func _room_span() -> Vector2:
	if theme == 2:
		var width := 12.0
		var depth := 12.0
		if WorldGen.annex_room_id(wseed, room_root + Vector2i(1, 0)) == room_root:
			width = 24.0
		if WorldGen.annex_room_id(wseed, room_root + Vector2i(0, 1)) == room_root:
			depth = 24.0
		return Vector2(width, depth)
	if room_n >= 4:
		return Vector2(24.0, 24.0)
	var mx := WorldGen.merge_dir(wseed, Vector2i(room_root.x - 1, room_root.y)) == 0
	var mz := WorldGen.merge_dir(wseed, Vector2i(room_root.x, room_root.y - 1)) == 2
	if mx and mz:
		return Vector2(12.0, 12.0)
	if mx:
		return Vector2(24.0, 12.0)
	if mz:
		return Vector2(12.0, 24.0)
	return Vector2(12.0, 12.0)


## Interior partition splitting a single-cell room in two, with a doorway
## through it — this is where the genuinely small rooms come from.
func _partition(along_x: bool, off: float) -> void:
	# `_resolved_room_split` has already slid/rotated this wall around every
	# doorway. Keeping this function literal prevents furnishings and audits
	# from disagreeing with the structure it actually builds.
	var wmat: Material = Mats.wallpaper_variant(_finish_variant())
	if theme == 1:
		wmat = Mats.office_wall_variant(_finish_variant())
	elif theme == 4:
		wmat = Mats.airport_wall_variant(_finish_variant())
	elif theme == 5:
		wmat = _level_builder._asy_wall_mat()
	elif theme == 6:
		wmat = _level_builder._sch_wall_mat()
	elif theme == 7:
		wmat = Mats.mall_wall()
	elif theme == 8:
		# concrete, not casino wallpaper — the fall-through default put
		# damask flock inside a prison
		wmat = Mats.prison_tile() if style == WorldGen.PRISON_SHOWER else Mats.prison_wall()
	var h := ceil_h
	var dt := lerpf(2.6, 9.4, _r(620))     # doorway centre along the partition
	var dw := 1.15
	var segs := [[0.0, dt - dw / 2.0], [dt + dw / 2.0, S]]
	for sg in segs:
		var a: float = sg[0]
		var b: float = sg[1]
		if b - a < 0.05:
			continue
		var c := (a + b) * 0.5
		if along_x:
			_box(Vector3(c, h / 2.0, off), Vector3(b - a, h, 0.14), wmat)
		else:
			_box(Vector3(off, h / 2.0, c), Vector3(0.14, h, b - a), wmat)
		# prison partitions carry the same green dado band as the real walls
		if theme == 8 and style != WorldGen.PRISON_SHOWER:
			for pside in [-1.0, 1.0]:
				if along_x:
					_box(Vector3(c, 0.72, off + pside * 0.085),
						Vector3(b - a, 1.44, 0.025), Mats.prison_dado(), false)
				else:
					_box(Vector3(off + pside * 0.085, 0.72, c),
						Vector3(0.025, 1.44, b - a), Mats.prison_dado(), false)
	# header over the doorway, and a casing around it
	var head_h := h - DOOR_TOP
	if head_h > 0.05:
		if along_x:
			_box(Vector3(dt, DOOR_TOP + head_h / 2.0, off), Vector3(dw, head_h, 0.14), wmat)
		else:
			_box(Vector3(off, DOOR_TOP + head_h / 2.0, dt), Vector3(0.14, head_h, dw), wmat)
	var cmat: Material = Mats.paint_white() if theme == 1 else (Mats.steel() if theme == 4 else (Mats.asy_metal_green() if theme == 5 else \
		(Mats.sch_red() if theme == 6 else (Mats.mall_trim() if theme == 7 else \
		(Mats.prison_iron() if theme == 8 else Mats.darkwood())))))
	for sside in [-1.0, 1.0]:
		if along_x:
			_box(Vector3(dt + sside * dw / 2.0, DOOR_TOP / 2.0, off), Vector3(0.1, DOOR_TOP, 0.2), cmat, false)
		else:
			_box(Vector3(off, DOOR_TOP / 2.0, dt + sside * dw / 2.0), Vector3(0.2, DOOR_TOP, 0.1), cmat, false)
	if along_x:
		_box(Vector3(dt, DOOR_TOP + 0.06, off), Vector3(dw + 0.2, 0.12, 0.2), cmat, false)
	else:
		_box(Vector3(off, DOOR_TOP + 0.06, dt), Vector3(0.2, 0.12, dw + 0.2), cmat, false)


## Furniture scaled to a small room: a couple of pieces against the walls,
## never a set piece that would burst through the partition.
func _small_room_props(along_x: bool, off: float) -> void:
	var halves := [[0.6, off - 0.6], [off + 0.6, S - 0.6]]
	var idx := 0
	# If both partition halves receive airport seating, they belong to the same
	# room and share one architectural facing instead of independent random yaws.
	var airport_seat_yaw := 0.0 if along_x else PI / 2.0
	for hf in halves:
		var a: float = hf[0]
		var b: float = hf[1]
		if b - a < 2.0:
			idx += 1
			continue
		var t := lerpf(a + 0.9, b - 0.9, _r(630 + idx))
		var u := lerpf(2.0, 10.0, _r(634 + idx))
		var p := Vector3(u, 0, t) if along_x else Vector3(t, 0, u)
		var pick := _r(638 + idx)
		match theme:
			1:
				if pick < 0.45:
					_shelf_unit(p, along_x, 640 + idx * 3)
				elif pick < 0.8:
					_small_desk(p, _r(644 + idx) * TAU)
				else:
					_level_builder._copier(p, 646 + idx)
			4:
				if pick < 0.5:
					_level_builder._seat_row(p, airport_seat_yaw, 3, 648 + idx * 3)
				elif pick < 0.8:
					_level_builder._air_bin(p)
				else:
					_level_builder._airport_luggage(p, _r(645 + idx) * TAU, 652 + idx, false)
			6:
				if pick < 0.34:
					_level_builder._sch_desk_row(p, PI / 2.0 if along_x else 0.0, 2, 640 + idx * 3)
				elif pick < 0.58:
					_shelf_unit(p, along_x, 642 + idx * 3)
				elif pick < 0.8:
					_level_builder._sch_stack_chairs(p, _r(644 + idx) * TAU, 646 + idx)
				else:
					_level_builder._sch_trolley(p, _r(645 + idx) * TAU)
			5:
				# bed runs along the partition so it cannot poke through it
				if pick < 0.4:
					_level_builder._asy_bed(p, (PI / 2.0 if along_x else 0.0) + (PI if _r(650 + idx) < 0.5 else 0.0), 652 + idx)
				elif pick < 0.6:
					_level_builder._asy_wheelchair(p, _r(644 + idx) * TAU)
				elif pick < 0.8:
					_level_builder._asy_chair(p, _r(645 + idx) * TAU, _r(646 + idx) < 0.2)
				else:
					_scattered_papers(p, 654 + idx, 5)
					_level_builder._asy_medbox(p + Vector3(0.4, 0, 0.25), _r(656 + idx) * TAU)
			7:
				if pick < 0.32:
					_level_builder._mall_display_table(p, _r(644 + idx) * TAU, 660 + idx)
				elif pick < 0.57:
					_level_builder._mall_bench(p, _r(645 + idx) * TAU)
				elif pick < 0.80:
					_level_builder._mall_shopping_cart(p, _r(645 + idx) * TAU, pick > 0.70)
				else:
					_cc0_prop("potted_plant_02", p, _r(646 + idx) * TAU, 0.85)
			8:
				# Bunks and toilet/sink combos are cell furniture, never
				# generic small-room filler. Neutral storage can plausibly
				# survive in a guard room, workshop, mess or shower anteroom.
				if pick < 0.62:
					_cc0_prop("wooden_crate_02", p,
						_r(646 + idx) * TAU, 0.75)
				else:
					_cc0_floor_prop("metal_trash_can", p,
						_r(646 + idx) * TAU, 0.66,
						"prison_small_room_refuse",
						Vector3(0.62, 0.78, 0.62),
						Vector3(0, 0.39, 0))
			_:
				if pick < 0.4:
					_planter(p)
				elif pick < 0.75:
					_level_builder._chair_at(p, _r(644 + idx) * TAU, Mats.velvet())
				else:
					_level_builder._sofa(p + Vector3(0, 0, 0), 1.0)
		idx += 1


## A single desk with the same authored terminal as the cubicle clusters — for
## rooms too small for a cluster.
func _small_desk(p: Vector3, yaw: float) -> void:
	var v := Node3D.new()
	v.set_meta("office_workstation", true)
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mrbox(v, Vector3(0, 0.73, 0), Vector3(1.4, 0.035, 0.72), Mats.desk_white(), 0.012)
	for sx in [-0.62, 0.62]:
		_mrbox(v, Vector3(sx, 0.355, 0), Vector3(0.04, 0.71, 0.66), Mats.desk_white(), 0.008)
	_collider_yaw_box(p + Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 0.75), yaw)
	_office_ibm_terminal(v, Vector3.ZERO, 0.0, 648)
	var paper_side := Vector3(cos(yaw), 0, -sin(yaw)) * 0.34
	var paper := _cc0_prop("office_notepads", p + paper_side + Vector3(0, 0.752, 0),
		yaw + (_r(648) - 0.5) * 0.14, 0.48)
	_adopt_local(v, paper)
	_task_chair(p + Vector3(sin(yaw) * 0.95, 0, cos(yaw) * 0.95), yaw + PI)


# --- vegas: grand chandelier is above; shared below --------------------------


# --- asylum ------------------------------------------------------------------
# Downloaded CC0 kit: photo textures (ambientCG) on the structure, glTF props
# (Poly Haven) for beds, wheelchairs, chairs and desks; everything the models
# don't cover — restraint tables, ECT carts, tubs, straitjackets — is built
# from primitives dressed in the same textures.

const ASY_SCRAWLS := ["LET ME OUT", "THEY LISTEN AT NIGHT", "NO ONE LEFT",
	"I AM NOT SICK", "IT WATCHES THE DOOR", "ROOM 9 ROOM 9 ROOM 9",
	"DONT SLEEP HERE", "WHERE DID EVERYONE GO", "HE COUNTS US AT NIGHT",
	"THE TREATMENT HELPS", "ALL OF US ARE STILL HERE", "THE WALLS BREATHE",
	"SOMEONE IS USING MY NAME", "THEY TURNED OFF THE SUN", "KEEP THE DOOR SHUT",
	"I HEARD YOU COME IN", "WE NEVER WENT HOME"]
const ASY_ZONE_SIGNS := [
	["WARD 3", "WARD 7", "SOLITARY", "DAY ROOM"],
	["HYDROTHERAPY", "TREATMENT", "NO ADMITTANCE", "SURGERY"],
	["ADMISSIONS", "RECORDS", "ADMINISTRATION", "VISITORS"],
]

static var _asy_scenes := {}
static var _cc0_scenes := {}


static func _prop_scene(path: String) -> PackedScene:
	var prepared := FloorResourcePreloader.cached_scene(path)
	if prepared != null:
		return prepared
	if not _prop_preloads_requested:
		return load(path) as PackedScene
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
			or status == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(path) as PackedScene
	return load(path) as PackedScene


## Instance a downloaded glTF prop. Scenes are load()-cached, so each model's
## meshes and textures exist once no matter how many chunks place it.
func _load_model(mname: String, pos: Vector3, yaw: float) -> Node3D:
	var ps: PackedScene = _asy_scenes.get(mname)
	if ps == null:
		ps = _prop_scene("res://models/asylum/%s/%s_1k.gltf" % [mname, mname])
		_asy_scenes[mname] = ps
	var inst: Node3D = ps.instantiate()
	inst.set_meta("surface_wear_prop", mname)
	inst.position = pos
	inst.rotation.y = yaw
	add_child(inst)
	return inst


## Same, for the shared CC0 prop pool every theme draws from.
func _cc0_prop(mname: String, pos: Vector3, yaw: float, scl := 1.0) -> Node3D:
	var ps: PackedScene = _cc0_scenes.get(mname)
	if ps == null:
		ps = _prop_scene("res://models/cc0/%s/%s_1k.gltf" % [mname, mname])
		_cc0_scenes[mname] = ps
	var inst: Node3D = ps.instantiate()
	inst.set_meta("surface_wear_prop", mname)
	inst.position = pos
	inst.rotation.y = yaw
	if scl != 1.0:
		inst.scale = Vector3.ONE * scl
	add_child(inst)
	return inst


## Local-space variant for assets that belong to a larger atomic furnishing:
## a register on its checkout, stock on a gondola, or janitorial clutter in
## one supported group.
func _cc0_prop_local(parent: Node3D, mname: String, pos: Vector3,
		yaw: float, scl := 1.0) -> Node3D:
	var ps: PackedScene = _cc0_scenes.get(mname)
	if ps == null:
		ps = _prop_scene("res://models/cc0/%s/%s_1k.gltf" % [mname, mname])
		_cc0_scenes[mname] = ps
	var inst: Node3D = ps.instantiate()
	inst.set_meta("surface_wear_prop", mname)
	inst.position = pos
	inst.rotation.y = yaw
	if scl != 1.0:
		inst.scale = Vector3.ONE * scl
	parent.add_child(inst)
	return inst


## Downloaded PBR sets occasionally ship a metallic-roughness map that pins
## roughness to zero on a metal surface. A perfect mirror with nothing around it
## to reflect renders as a black cut-out under this game's practicals, so the
## affected materials get a roughness floor. This runs once per asset, on the
## shared material resource, so every instance is corrected at no per-chunk cost
## and the authored albedo and normal maps are untouched.
const ATTRIBUTED_ROUGHNESS_FLOOR := {
	ASY_GURNEY_PATH: 0.45,
}


static func _tune_attributed_scene(path: String, scene: PackedScene) -> void:
	if not ATTRIBUTED_ROUGHNESS_FLOOR.has(path) \
			and path != SCH_CHEMISTRY_TABLE_PATH \
			and path != CHEMISTRY_GLASSWARE_PATH \
			and path != ALARM_PATH:
		return
	var probe := scene.instantiate()
	for node in probe.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var mat := mesh.surface_get_material(si) as BaseMaterial3D
			if mat == null:
				continue
			if ATTRIBUTED_ROUGHNESS_FLOOR.has(path) \
					and mat.roughness_texture != null:
				# The map's green channel is what forces the mirror; drop it and
				# hold a sane scalar instead. Metallic keeps its own map.
				mat.roughness_texture = null
				mat.roughness = maxf(mat.roughness,
					float(ATTRIBUTED_ROUGHNESS_FLOOR[path]))
			if path == SCH_CHEMISTRY_TABLE_PATH:
				if mat.resource_name == "Procedual_Marble_Granite_Black_Galaxy":
					# Granite is dielectric. The source's mirror-like value made
					# the broad black top disappear under school fluorescents.
					mat.metallic = 0.0
					mat.roughness = 0.32
					mat.albedo_color = Color(0.035, 0.038, 0.036, 1.0)
				elif mat.resource_name == "Nickel_metal-02":
					mat.roughness_texture = null
					mat.roughness = 0.20
			elif path == CHEMISTRY_GLASSWARE_PATH \
					and mat.resource_name == "vidrio":
				# Glass is not metal. Slightly stronger opacity keeps the
				# silhouettes legible without turning them into plastic.
				mat.metallic = 0.0
				mat.roughness = 0.10
				mat.albedo_color = Color(0.72, 0.86, 0.80, 0.34)
			elif path == ALARM_PATH \
					and mat.resource_name.to_lower().contains("lumina"):
				# The glTF declares emissive strength but omits emissiveFactor,
				# whose specified default is black. Make the physical bulb the
				# visible source of the red spill instead of a glowing point
				# with no fixture.
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.018, 0.008)
				mat.emission_energy_multiplier = 7.0
	probe.free()


## Local-space instance for documented CC BY / CC BY-NC models. Keeping this
## cache separate from the CC0 pool makes their provenance visible in code and
## prevents an attributed asset from being mistaken for public-domain work.
func _attributed_prop_local(parent: Node3D, path: String, pos: Vector3,
		yaw: float, scl := Vector3.ONE) -> Node3D:
	var ps: PackedScene = _attributed_scenes.get(path)
	if ps == null:
		ps = _prop_scene(path)
		if ps != null:
			_tune_attributed_scene(path, ps)
		_attributed_scenes[path] = ps
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return null
	inst.position = pos
	inst.rotation.y = yaw
	inst.scale = scl
	inst.set_meta("attributed_asset", path)
	parent.add_child(inst)
	return inst


## Downloaded models are rarely built around their own origin: the hospital bed
## sits 2cm below it, the gurney eight metres to one side. Correcting that at
## every call site is where placement bugs come from, so each asset records its
## authored (centre x, lowest y, centre z) once and this drops the prop with its
## footprint centred on `p`, its lowest point on the floor, facing `yaw`.
## `group` opts the prop into the furnishing-group system: the overlap audit
## only compares colliders carrying a group id, so a free-standing prop dropped
## at a hashed point is invisible to it otherwise. That is precisely how a
## suitcase came to stand inside a row of gate seating undetected. Callers that
## pass it must follow their collider calls with `_bind_furnishing_colliders`.
func _attributed_floor_prop(path: String, p: Vector3, yaw: float, scl: float,
		centre: Vector3, kind: String, parent: Node3D = null,
		group := false) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = p
	pivot.rotation.y = yaw
	if group:
		# Same contract as `_furnishing_pivot`: one pivot, one group, removed
		# as a unit. The support audit requires the tag, or the prop's grouped
		# colliders read as physics left behind by a culled assembly.
		_claim_furnishing_group(pivot, kind, true)
	if parent != null:
		parent.add_child(pivot)
	else:
		add_child(pivot)
	var inst := _attributed_prop_local(pivot, path, -centre * scl, 0.0,
		Vector3.ONE * scl)
	if inst == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return null
	pivot.set_meta("attributed_furnishing", kind)
	inst.set_meta("authored_model", kind)
	return pivot


## The one waste bin the whole building uses. Airport concourses, school
## corridors and mall walkways each used to roll their own out of two cylinders
## in slightly different greys; a public bin is a public bin.
func _waste_bin(p: Vector3, yaw: float, kind: String) -> Node3D:
	var b0 := body.get_child_count()
	var pivot := _attributed_floor_prop(GARBAGE_BIN_PATH, p, yaw,
		GARBAGE_BIN_SCALE, GARBAGE_BIN_CENTRE, kind, null, true)
	if pivot == null:
		# The generated fallback keeps a floor legible if the model is absent.
		_cyl(p + Vector3(0, 0.42, 0), 0.26, 0.84, Mats.steel())
		_cyl(p + Vector3(0, 0.855, 0), 0.22, 0.03, Mats.charcoal(), false)
		return null
	_collider_cyl(p + Vector3(0, 0.43, 0), 0.39, 0.86)
	_bind_furnishing_colliders(pivot, b0)
	return pivot


## A complete authored chemistry display or one isolated vessel from it,
## bottom-aligned on a known work surface. The individual variants are removed
## by top-level authored sub-assembly, so a flask can never leave somebody
## else's stand or test tubes floating beside it.
func _chemistry_glassware(parent: Node3D, pos: Vector3, yaw: float,
		salt: int, full_set: bool, context: String) -> Node3D:
	var variant := -1
	var centre := CHEMISTRY_GLASSWARE_FULL_CENTRE
	if not full_set:
		variant = mini(int(_r(salt) * CHEMISTRY_GLASSWARE_VARIANTS.size()),
			CHEMISTRY_GLASSWARE_VARIANTS.size() - 1)
		centre = CHEMISTRY_GLASSWARE_CENTRES[variant]
	var pivot := Node3D.new()
	pivot.name = "ChemistryGlassware"
	pivot.position = pos
	pivot.rotation.y = yaw
	pivot.set_meta("attributed_furnishing", "chemistry_glassware")
	pivot.set_meta("chemistry_context", context)
	pivot.set_meta("chemistry_variant", variant)
	pivot.set_meta("surface_supported", true)
	parent.add_child(pivot)
	var inst := _attributed_prop_local(pivot, CHEMISTRY_GLASSWARE_PATH,
		-centre * CHEMISTRY_GLASSWARE_SCALE, 0.0,
		Vector3.ONE * CHEMISTRY_GLASSWARE_SCALE)
	if inst == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return null
	inst.set_meta("authored_model", "chemistry_glassware")
	if full_set:
		return pivot
	var source_root := inst.find_child("GLTF_SceneRootNode", true, false)
	if source_root == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return null
	var keep: Array = CHEMISTRY_GLASSWARE_VARIANTS[variant]
	for staged in source_root.get_children():
		if keep.has(String(staged.name)):
			continue
		source_root.remove_child(staged)
		staged.free()
	return pivot


## A downloaded floor prop plus its conservative collision bounds, all under
## one support-audited pivot.
func _cc0_floor_prop(mname: String, pos: Vector3, yaw: float, scl: float,
		kind: String, collider_size: Vector3,
		collider_center := Vector3.ZERO) -> Node3D:
	var b0 := body.get_child_count()
	var pivot := _furnishing_pivot(pos, yaw, kind)
	pivot.set_meta("enrichment_prop", mname)
	_cc0_prop_local(pivot, mname, Vector3.ZERO, 0.0, scl)
	if collider_size != Vector3.ZERO:
		_collider_yaw_box(_wp(pos, collider_center, yaw), collider_size, yaw)
	_bind_furnishing_colliders(pivot, b0)
	return pivot


func _set_model_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_set_model_material(child, mat)


## Real five-star caster chair with restrained upholstered back and arms.
## Its FBX origin is at the model centre, so lift it 0.507m to put the wheels
## on the generated floor. The compact collider follows the caster footprint.
func _task_chair(pos: Vector3, yaw: float) -> Node3D:
	var ps: PackedScene = _cc0_scenes.get("office_chair")
	if ps == null:
		ps = _prop_scene(OFFICE_CHAIR_PATH)
		_cc0_scenes["office_chair"] = ps
	var inst: Node3D = ps.instantiate()
	inst.set_meta("surface_wear_prop", "office_task_chair")
	inst.position = pos + Vector3(0, 0.50676, 0)
	inst.rotation.y = yaw
	_set_model_material(inst, Mats.office_task_chair())
	add_child(inst)
	_collider_yaw_box(pos + Vector3(0, 0.52, 0), Vector3(0.62, 1.04, 0.62), yaw)
	return inst


## A real late-20th-century CCTV housing. `mount` is the wall contact point and
## `lens_yaw` points from that wall into the watched space. The imported mesh's
## glass lens faces local +Z and its mounting plate reaches local -Z=0.303m,
## so moving the origin forward seats the plate while leaving the lens aimed
## into the corridor.
func _security_camera(mount: Vector3, lens_yaw: float) -> void:
	var forward := Vector3(sin(lens_yaw), 0, cos(lens_yaw))
	var cam := _cc0_prop("security_camera_01",
		mount + forward * (0.303 * 0.9), lens_yaw, 0.9)
	cam.rotation.x = 0.18
	cam.set_meta("security_camera_mount", mount)


func _disable_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_disable_shadows(c)


# --- asylum: lighting ---------------------------------------------------------

func _scattered_papers(p: Vector3, salt: int, count: int) -> void:
	for i in count:
		var q := MeshInstance3D.new()
		q.mesh = QUAD
		q.material_override = Mats.box_white()
		var a := _r(salt + i * 3) * TAU
		var rd := _r(salt + i * 3 + 1) * 1.3
		q.position = p + Vector3(cos(a) * rd, 0.012 + 0.003 * float(i), sin(a) * rd)
		q.rotation.x = -PI / 2.0
		q.rotation.z = _r(salt + i * 3 + 2) * TAU
		q.scale = Vector3(0.21, 0.3, 1.0)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)


static func _scrawl_font(which: int) -> FontFile:
	var f: FontFile = _scrawl_fonts.get(which)
	if f == null:
		f = load("res://fonts/RockSalt-Regular.ttf" if which == 0
			else "res://fonts/Caveat-Regular.ttf")
		_scrawl_fonts[which] = f
	return f


func school_chalkboard_violations() -> int:
	if theme != 6:
		return 0
	return _school_chalkboard_violations_at(self, false)
func _school_chalkboard_violations_at(node: Node, board_seen: bool) -> int:
	var seen := board_seen
	var bad := 0
	if node.has_meta("school_chalkboard"):
		seen = true
		var dir := int(node.get_meta("school_chalkboard"))
		if not _edge_info(cell, dir)["wall"]:
			bad += 1
	if node.has_meta("school_chalk") and not seen:
		bad += 1
	for ch in node.get_children():
		bad += _school_chalkboard_violations_at(ch, seen)
	return bad


## School wall-screen audit: every roller must be owned by an atomic fixture
## and attached to a genuinely solid generated edge. Portable projector models
## are deliberately no longer part of classroom generation.
## School wall-screen audit: every roller must be owned by an atomic fixture
## and attached to a genuinely solid generated edge. Portable projector models
## are deliberately no longer part of classroom generation.
func school_projector_screen_audit() -> Dictionary:
	var report := {"screens": 0, "violations": 0}
	if theme != 6:
		return report
	for node in find_children("*", "Node3D", true, false):
		if not node.has_meta("school_projector_screen"):
			continue
		report["screens"] += 1
		var dir := int(node.get_meta("school_projector_screen", -1))
		if dir < 0 or dir > 3 \
				or not node.has_meta("atomic_furnishing") \
				or not bool(node.get_meta(
					"school_projector_screen_compact", false)) \
				or WorldGen.elevator_cell(wseed, cell, theme) \
				or not bool(_edge_info(cell, dir)["wall"]):
			report["violations"] += 1
	return report


## EXIT lettering is legal only as part of `_exit_sign`'s physical housing.
## This catches raw labels placed for atmosphere without a real door.
## EXIT lettering is legal only as part of `_exit_sign`'s physical housing.
## This catches raw labels placed for atmosphere without a real door.
func orphan_exit_label_violations() -> int:
	var bad := 0
	for node in find_children("*", "Label3D", true, false):
		var lab := node as Label3D
		if lab.text.strip_edges().to_upper() == "EXIT" \
				and not lab.has_meta("structural_exit_label"):
			bad += 1
	return bad


## A lit EXIT must be a complete, visible fixture. Non-mall cabinets belong
## above the lintel and must project beyond the wall skin; mall cabinets are
## suspended in open air and are covered by `mall_fixture_audit`'s hangers.
## A lit EXIT must be a complete, visible fixture. Non-mall cabinets belong
## above the lintel and must project beyond the wall skin; mall cabinets are
## suspended in open air and are covered by `mall_fixture_audit`'s hangers.
func exit_sign_fixture_audit() -> Dictionary:
	var report := {
		"housings": 0,
		"labels": 0,
		"alarms": 0,
		"lights": 0,
		"violations": 0,
	}
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("structural_exit_label"):
			report["labels"] += 1
		if node.has_meta("structural_exit_light"):
			report["lights"] += 1
		if node.has_meta("structural_exit_alarm"):
			report["alarms"] += 1
			var alarm_bottom := float(node.get_meta("alarm_bottom", -INF))
			var alarm_top := float(node.get_meta("alarm_top", INF))
			var alarm_sign_top := float(node.get_meta("alarm_sign_top", INF))
			var alarm_opening_head := float(
				node.get_meta("alarm_opening_head", INF))
			var alarm_height := float(node.get_meta("alarm_height", 0.0))
			var alarm_depth := float(node.get_meta("alarm_depth", 0.0))
			if str(node.get_meta("attributed_asset", "")) != ALARM_PATH \
					or absf(float(node.get_meta("alarm_mount_yaw", 0.0))
						+ PI / 2.0) > 0.001 \
					or alarm_bottom < alarm_opening_head + 0.03 \
					or alarm_top > ceil_h \
						- ALARM_MIN_CEILING_CLEARANCE + 0.002 \
					or absf(alarm_height - ALARM_FITTED_HEIGHT) > 0.006 \
					or alarm_depth < 0.07:
				report["violations"] += 1
				report["alarm_issue"] = {
					"bottom": alarm_bottom, "top": alarm_top,
					"sign_top": alarm_sign_top, "height": alarm_height,
					"opening_head": alarm_opening_head,
					"depth": alarm_depth, "ceiling": ceil_h,
				}
		if not node.has_meta("structural_exit_housing"):
			continue
		report["housings"] += 1
		var sign_top := float(node.get_meta("sign_top", INF))
		var face_offset := float(node.get_meta("face_offset", 0.0))
		var normal_half := float(node.get_meta("normal_half_extent", 0.0))
		if sign_top >= ceil_h - 0.01 or face_offset <= normal_half:
			report["violations"] += 1
			report["housing_issue"] = {
				"sign_top": sign_top, "ceiling": ceil_h,
				"face_offset": face_offset, "normal_half": normal_half,
			}
		if theme != 7:
			var sign_bottom := float(node.get_meta("sign_bottom", -INF))
			var opening_head := float(node.get_meta("opening_head", INF))
			if sign_bottom <= opening_head + 0.006 \
					or normal_half <= T * 0.5 + 0.02:
				report["violations"] += 1
				report["mount_issue"] = {
					"sign_bottom": sign_bottom, "opening_head": opening_head,
					"normal_half": normal_half, "wall_half": T * 0.5,
				}
	var expected_lights := 0 if theme == 7 else int(report["housings"]) * 2
	if int(report["labels"]) != int(report["housings"]) * 2 \
			or int(report["alarms"]) != expected_lights \
			or int(report["lights"]) != expected_lights:
		report["violations"] += 1
	return report


func _sfb(dir: int, plane: float, off: float, along: float, y: float,
		w: float, h: float, d: float, mat: Material, collide := false) -> MeshInstance3D:
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var p := plane + n * (T * 0.5 + off)
	if dir < 2:
		return _box(Vector3(p, y, along), Vector3(d, h, w), mat, collide)
	return _box(Vector3(along, y, p), Vector3(w, h, d), mat, collide)


func mall_fixture_audit() -> Dictionary:
	var report := {
		"store_signs": 0,
		"painted_signs": 0,
		"payphones": 0,
		"directories": 0,
		"exit_signs": 0,
		"foodcourt_brands": 0,
		"fountains": 0,
		"fountain_waters": 0,
		"violations": 0,
	}
	if theme != 7:
		return report
	# A downloaded model that fails to import falls back silently and would
	# otherwise just quietly stop appearing; count the real ones.
	for node in find_children("*", "Node3D", true, false):
		if str(node.get_meta("atomic_furnishing", "")) == "mall_fountain":
			report["fountains"] += 1
		match str(node.get_meta("authored_model", "")):
			"payphone":
				report["payphones"] += 1
			"mall_directory":
				report["directories"] += 1
	for node in find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("mall_fountain_water"):
			report["fountain_waters"] += 1
			var fountain_mat := (node as MeshInstance3D).material_override \
				as ShaderMaterial
			if fountain_mat == null or fountain_mat.shader == null \
					or fountain_mat.shader.resource_path != \
						"res://shaders/pool_water.gdshader" \
					or not bool(node.get_meta(
						"mall_fountain_water_visual_only", false)) \
					or absf(float(node.get_meta(
						"mall_fountain_water_radius", 0.0)) - 1.30) > 0.001:
				report["violations"] += 1
		if not node.has_meta("mall_painted_sign"):
			continue
		report["painted_signs"] += 1
		# A cropped fascia must keep the artwork's own aspect and stay inside
		# the 4.4 x 0.50m sign band, or it reads as a stretched decal.
		var fit: Vector2 = node.get_meta("mall_sign_fit", Vector2.ZERO)
		var name := str(node.get_meta("mall_painted_sign"))
		var want := 0.0
		for entry in MALL_SIGN_FACES:
			if entry[0] == name:
				want = entry[1]
				break
		if want <= 0.0 or fit.y <= 0.0 \
				or absf(fit.x / fit.y - want) > 0.02 \
				or fit.x > MALL_SIGN_MAX_W + 0.001 \
				or fit.y > MALL_SIGN_MAX_H + 0.001:
			report["violations"] += 1
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("mall_directory_label") and node is Label3D:
			var directory_label := node as Label3D
			if directory_label.double_sided \
					or absf(absf(directory_label.rotation.y) - PI) > 0.001:
				report["violations"] += 1
		if node.has_meta("mall_directory_listing") and node is Label3D:
			var directory_listing := node as Label3D
			if directory_listing.double_sided \
					or absf(absf(directory_listing.rotation.y) - PI) > 0.001 \
					or directory_listing.text.strip_edges().is_empty():
				report["violations"] += 1
		if node.has_meta("mall_store_sign") and node is Label3D:
			report["store_signs"] += 1
			var lab := node as Label3D
			var sign_font: Font = lab.font if lab.font != null else ThemeDB.fallback_font
			var text_px := sign_font.get_string_size(lab.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, lab.font_size).x
			var max_world := float(lab.get_meta("safe_world_width", 0.0))
			if lab.width + 0.5 < text_px \
					or text_px * lab.pixel_size > max_world + 0.001:
				report["violations"] += 1
		if node.has_meta("mall_foodcourt_brand") and node is Label3D:
			report["foodcourt_brands"] += 1
		if node.has_meta("mall_exit_mount") and node is MeshInstance3D:
			report["exit_signs"] += 1
			var mi := node as MeshInstance3D
			var sign_top := float(mi.get_meta("sign_top", INF))
			if int(mi.get_meta("hanger_count", 0)) != 2 \
					or sign_top >= float(mi.get_meta("opening_head", 0.0)) \
					or sign_top >= ceil_h:
				report["violations"] += 1
	if style == WorldGen.MALL_FOODCOURT:
		# A food-court serving counter owns exactly one vendor identity when a
		# solid wall is available. Storefront signs behind it or multiple brands
		# are context errors even if each individual label fits.
		if int(report["store_signs"]) != 0 \
				or int(report["foodcourt_brands"]) > 1:
			report["violations"] += 1
	if int(report["fountain_waters"]) != int(report["fountains"]) \
			or int(report["fountains"]) > 1:
		report["violations"] += 1
	return report


## Regression hook for mounted art: every image must retain its source aspect,
## remain inside the wall/ceiling bounds, and only exist on a genuinely solid
## edge. The generator never treats these textures as decals or floor props.
## Regression hook for mounted art: every image must retain its source aspect,
## remain inside the wall/ceiling bounds, and only exist on a genuinely solid
## edge. The generator never treats these textures as decals or floor props.
func wall_art_audit() -> Dictionary:
	var report := {"mounts": 0, "violations": 0, "paths": {}}
	var split := _resolved_room_split()
	for node in find_children("*", "Node3D", true, false):
		if not node.has_meta("wall_art_mount"):
			continue
		report["mounts"] += 1
		var path := str(node.get_meta("wall_art_path", ""))
		report["paths"][path] = int(report["paths"].get(path, 0)) + 1
		var shown := float(node.get_meta("wall_art_aspect", 0.0))
		var source := float(node.get_meta("wall_art_source_aspect", -1.0))
		var dir := int(node.get_meta("wall_art_dir", -1))
		var size: Vector2 = node.get_meta("wall_art_size", Vector2.ZERO)
		var p := (node as Node3D).position
		var along := p.z if dir < 2 else p.x
		var partition_overlap := not split.is_empty() \
			and ((bool(split[0]) and dir < 2) \
				or (not bool(split[0]) and dir >= 2)) \
			and absf(along - float(split[1])) < size.x * 0.5 + 0.18
		var school_board_overlap := theme == 6 \
			and dir == _school_chalkboard_wall() \
			and absf(along - S * 0.5) < size.x * 0.5 + 2.10
		if path.is_empty() or absf(shown - source) > 0.002 \
				or dir < 0 or dir > 3 \
				or not bool(_edge_info(cell, dir)["wall"]) \
				or size.x <= 0.0 or size.y <= 0.0 \
				or p.y - size.y * 0.5 < 0.25 \
				or p.y + size.y * 0.5 > ceil_h - 0.12 \
				or along - size.x * 0.5 < 0.20 \
				or along + size.x * 0.5 > S - 0.20 \
				or partition_overlap or school_board_overlap:
			report["violations"] += 1
	return report


## Airport ad cases share the poster texture cache with ordinary wall mounts,
## but are emissive and have their own placement path in the level builder.
func airport_poster_lightbox_audit() -> Dictionary:
	var report := {"lightboxes": 0, "violations": 0, "paths": {}}
	if theme != 4:
		return report
	for node in find_children("*", "MeshInstance3D", true, false):
		if not node.has_meta("airport_poster_lightbox"):
			continue
		report["lightboxes"] += 1
		var path := str(node.get_meta("airport_poster_path", ""))
		report["paths"][path] = int(report["paths"].get(path, 0)) + 1
		var aspect := float(node.get_meta("airport_poster_aspect", 0.0))
		var mat := (node as MeshInstance3D).material_override \
			as StandardMaterial3D
		if not POSTER_AIRPORT.has(path) or absf(aspect - 0.75) > 0.002 \
				or mat == null or mat.albedo_texture == null \
				or mat.albedo_texture.resource_path != path \
				or not mat.emission_enabled or mat.emission_texture == null:
			report["violations"] += 1
	return report


## Office wall fixtures are generated by the room anchor while paintings are
## generated by individual member chunks. Recompute the shared deterministic
## rectangle so an AC can never hide or cut through a painting in another
## member of the same merged room.
func office_wall_mount_audit() -> Dictionary:
	var report := {"air_conditioners": 0, "art_conflicts": 0, "violations": 0}
	if theme != 1:
		return report
	var expected := 0
	for node in find_children("*", "Node3D", true, false):
		if not node.has_meta("office_ac_mount"):
			continue
		report["air_conditioners"] += 1
		expected = maxi(expected, int(node.get_meta("office_ac_expected", 0)))
		var member: Vector2i = node.get_meta("office_ac_member", cell)
		var dir := int(node.get_meta("office_ac_dir", -1))
		var along := float(node.get_meta("office_ac_along", INF))
		if dir < 0 or dir > 3 or not is_finite(along):
			report["violations"] += 1
			continue
		var edge := _edge_info(member, dir)
		if not bool(edge["wall"]) or bool(edge["full_open"]) \
				or bool(node.get_meta("office_ac_suspended", false)):
			report["violations"] += 1
			continue
		var art := _office_wall_art_layout(member, dir)
		if art.is_empty():
			continue
		var art_size: Vector2 = art["size"]
		var horizontal_overlap := absf(along - float(art["along"])) \
			< 0.625 + art_size.x * 0.5 + 0.10
		var vertical_overlap := absf((node as Node3D).position.y - float(art["y"])) \
			< 0.21 + art_size.y * 0.5 + 0.08
		if horizontal_overlap and vertical_overlap:
			report["art_conflicts"] += 1
			report["violations"] += 1
	if expected > 0 and int(report["air_conditioners"]) != expected:
		report["violations"] += 1
	return report


## Filing banks deliberately leave one drawer ajar, but it must remain a short
## reveal at hand height rather than a full-depth box protruding at floor level.
func filing_bank_audit() -> Dictionary:
	var report := {
		"cabinets": 0, "drawer_faces": 0, "open_drawers": 0,
		"violations": 0,
	}
	var cabinets_by_dir := {}
	var opens_by_dir := {}
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("filing_bank_cabinet"):
			report["cabinets"] += 1
			var cabinet_dir := int(node.get_meta("filing_bank_dir", -1))
			cabinets_by_dir[cabinet_dir] = \
				int(cabinets_by_dir.get(cabinet_dir, 0)) + 1
		if node.has_meta("filing_bank_drawer_face"):
			report["drawer_faces"] += 1
			var face_row := int(node.get_meta("filing_bank_drawer_row", -1))
			var expected_y := 0.19 + 0.31 * float(face_row)
			var face_y := (node as Node3D).position.y
			# The 27cm faces must remain wholly within the 1.32m shell and
			# centered on the corrected four-row stack.
			if face_row < 0 or face_row > 3 \
					or absf(face_y - expected_y) > 0.001 \
					or face_y - 0.135 < 0.0 or face_y + 0.135 > 1.32:
				report["violations"] += 1
		if not node.has_meta("filing_bank_open_drawer"):
			continue
		report["open_drawers"] += 1
		var drawer_dir := int(node.get_meta("filing_bank_dir", -1))
		opens_by_dir[drawer_dir] = int(opens_by_dir.get(drawer_dir, 0)) + 1
		var row := int(node.get_meta("filing_bank_open_row", -1))
		var projection := float(node.get_meta("filing_bank_projection", INF))
		var drawer_y := (node as Node3D).position.y
		# Open-drawer body is 0.24m tall and must remain inside the 1.32m
		# cabinet just like every closed face in the four-row stack.
		if row < 1 or row > 2 or projection > 0.15 \
				or drawer_y - 0.12 < 0.0 or drawer_y + 0.12 > 1.32:
			report["violations"] += 1
	for bank_dir in cabinets_by_dir:
		# Doorway cleanup removes whole cabinet pivots. If the authored open
		# cabinet is the one intersecting a portal, the surviving partial bank
		# legitimately contains zero open drawers; it must never contain two.
		if int(opens_by_dir.get(bank_dir, 0)) > 1:
			report["violations"] += 1
	return report
func _solid_wall(dir: int) -> bool:
	return _edge_info(cell, dir)["wall"]
func _security_camera_wall(dir: int, plane: float) -> void:
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var wall_t := ANNEX_WALL_T if theme == 2 else T
	var inner := plane + n * (wall_t * 0.5)
	var along := lerpf(3.5, 8.5, _r(1820 + dir))
	var mount := Vector3(inner, minf(2.75, ceil_h - 0.35), along) if dir < 2 \
		else Vector3(along, minf(2.75, ceil_h - 0.35), inner)
	var yaw := (-PI / 2.0 if dir == 0 else PI / 2.0) if dir < 2 \
		else (PI if dir == 2 else 0.0)
	_security_camera(mount, yaw)


func prison_cell_fixture_audit() -> Dictionary:
	var report := {
		"bunks": 0, "toilets": 0,
		"authored_bunks": 0, "authored_toilets": 0,
		"violations": 0,
	}
	if theme != 8:
		return report
	var valid_style := style == WorldGen.PRISON_CELLBLOCK \
		or style == WorldGen.PRISON_CELLS
	for node in find_children("*", "Node3D", true, false):
		if not node.has_meta("enrichment_prop"):
			continue
		var prop := str(node.get_meta("enrichment_prop"))
		if prop != "double_bunk" and prop != "detention_toilet_sink":
			continue
		if prop == "double_bunk":
			report["bunks"] += 1
		else:
			report["toilets"] += 1
		if not bool(node.get_meta("prison_cell_context", false)) \
				or not valid_style:
			report["violations"] += 1
		var expected_path := PRISON_BUNK_PATH if prop == "double_bunk" \
			else PRISON_TOILET_PATH
		var has_authored_model := false
		for child in node.find_children("*", "Node3D", true, false):
			if str(child.get_meta("attributed_asset", "")) == expected_path:
				has_authored_model = true
				break
		if has_authored_model:
			if prop == "double_bunk":
				report["authored_bunks"] += 1
			else:
				report["authored_toilets"] += 1
		else:
			report["violations"] += 1
	return report


## Every authored furnishing this chunk placed, by kind. `_attributed_floor_prop`
## tags each pivot as it builds it, so a downloaded model that stops reaching
## its rooms — a renamed file, a failed import, a placement gate that drifted
## shut — shows up here as a zero instead of quietly disappearing.
func authored_furnishing_counts() -> Dictionary:
	var counts := {}
	for node in find_children("*", "Node3D", true, false):
		if not node.has_meta("attributed_furnishing"):
			continue
		var kind := str(node.get_meta("attributed_furnishing"))
		counts[kind] = int(counts.get(kind, 0)) + 1
	return counts


## Asylum regression hook. The authored hospital furniture has to actually
## reach the rooms it was chosen for, and its doors have to stay on the two
## legal mounts: a sealed leaf against a solid wall, or a leaf inside a
## generated corridor casing. A leaf loose in a room would be a floating slab.
func asylum_authored_audit() -> Dictionary:
	var report := {
		"beds": 0, "gurneys": 0, "trolleys": 0, "baths": 0, "sinks": 0,
		"notices": 0, "facade_doors": 0, "casing_leaves": 0, "violations": 0,
	}
	if theme != 5:
		return report
	var kinds := {
		"ward_bed": "beds", "gurney": "gurneys",
		"instrument_trolley": "trolleys", "hydro_bath": "baths",
		"scrub_sink": "sinks",
	}
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("attributed_furnishing"):
			var kind := str(node.get_meta("attributed_furnishing"))
			if kinds.has(kind):
				report[kinds[kind]] += 1
		if node.has_meta("asylum_wall_notices"):
			report["notices"] += 1
		if bool(node.get_meta("wall_mounted_asylum_door", false)):
			report["facade_doors"] += 1
			if not bool(node.get_meta("locked_facade", false)):
				report["violations"] += 1
		if not node.has_meta("asylum_authored_leaf"):
			continue
		report["casing_leaves"] += 1
		var pick := int(node.get_meta("asylum_authored_leaf"))
		if pick < 0 or pick >= ASY_DOOR_PATHS.size() \
				or str(node.get_meta("attributed_asset", "")) \
				!= ASY_DOOR_PATHS[pick]:
			report["violations"] += 1
	return report
func prison_visitation_phone_audit() -> Dictionary:
	var report := {"booths": 0, "phones": 0, "violations": 0}
	if theme != 8:
		return report
	for node in find_children("*", "Node3D", true, false):
		if not node.has_meta("atomic_furnishing") \
				or str(node.get_meta("atomic_furnishing")) != \
				"prison_visitation_booth":
			continue
		report["booths"] = int(report["booths"]) + 1
		var booth_phones := 0
		for child in node.find_children("*", "Node3D", true, false):
			if child.has_meta("prison_visitation_phone"):
				booth_phones += 1
				var authored_phones := 0
				for model in child.find_children("*", "Node3D", true, false):
					if str(model.get_meta("authored_model", "")) == "visitation_phone" \
							and str(model.get_meta("attributed_asset", "")) == PRISON_WALL_PHONE_PATH:
						authored_phones += 1
				if authored_phones != 1:
					report["violations"] = int(report["violations"]) + 1
		report["phones"] = int(report["phones"]) + booth_phones
		if booth_phones != 2:
			report["violations"] = int(report["violations"]) + 1
	return report
func prison_authored_door_audit() -> Dictionary:
	var report := {"locked_facades": 0, "interactive_leaves": 0, "violations": 0}
	for node in find_children("*", "Node3D", true, false):
		if bool(node.get_meta("wall_mounted_prison_door", false)):
			report["locked_facades"] += 1
			if theme != 8 \
					or str(node.get_meta("attributed_asset", "")) != \
					PRISON_DOOR_OLD_PATH \
					or node.find_child("Null_1", true, false) != null:
				report["violations"] += 1
		if bool(node.get_meta("interactive_prison_door", false)):
			report["interactive_leaves"] += 1
			if theme != 8 \
					or str(node.get_meta("attributed_asset", "")) != \
					SOLITARY_CELL_DOOR_PATH:
				report["violations"] += 1
	return report
func _wall_facing(dir: int) -> float:
	match dir:
		0: return -PI / 2.0
		1: return PI / 2.0
		2: return PI
	return 0.0
func _wall_pt(dir: int, along: float, off: float, y := 0.0) -> Vector3:
	match dir:
		0: return Vector3(S - T - off, y, along)
		1: return Vector3(T + off, y, along)
		2: return Vector3(along, y, S - T - off)
	return Vector3(along, y, T + off)
static func pool_style_dry(st: int) -> bool:
	# Over half the floor is dry tile. An endless sheet of water gives the
	# player nowhere to stand, nothing to read the water against, and no sense
	# of having arrived anywhere — the pools should be rooms in a building.
	return st == WorldGen.POOL_DECK or st == WorldGen.POOL_ALCOVE \
		or st == WorldGen.POOL_GALLERY or st == WorldGen.POOL_SOLARIUM


func _floor_h() -> float:
	return cell_floor_h(wseed, cell, theme)

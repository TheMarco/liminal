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
## All geometry is local; the ChunkManager places the node at the cell origin.

const S := 12.0
const H := 3.2       # vegas wall/ceiling height
const H2 := 6.4      # vegas grand hall ceiling
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
const ANNEX_FIXTURE_CLEARANCE := 0.08
const HAIR := 5.0    # airport hall height
const HASY := 3.0    # asylum corridor height
const HSCH := 3.05   # school corridor height
const HMALL := 4.0   # mall gallery height
const HPRISON := 3.5 # prison gallery height
const SCH_BAND := 1.42   # height of the red line that runs the whole school
const T := 0.15
const DOOR_TOP := 2.25
const AIR_DOOR := 3.15   # airport portal head height
const DOOR_CLEAR_DEPTH := 3.6
const DOOR_CLEAR_PAD := 0.5

# sewer waterway cross-section
const WATER_Y := -0.22   # water surface below the walkways
const CH_HW := 0.85      # half width of the channel invert
const CH_D := 0.48       # channel floor depth below the walkways
const BANK := 0.62       # horizontal run of each sloped bank (walkable angle)
const CH_CUT := CH_HW + BANK
const BAS0 := 3.0        # basin inner square
const BAS1 := 9.0
const BAS_D := 0.95      # basin floor depth

static var BOX := BoxMesh.new()
static var CYL := CylinderMesh.new()
static var SPH := SphereMesh.new()
static var TOR := TorusMesh.new()
static var QUAD := QuadMesh.new()
static var CONE := CylinderMesh.new()
static var _cone_ready := false
## Four unit-prism variants per run axis: neither, either, or both genuine end
## caps. Annex continuation joins use no cap, so two adjacent chunks can meet
## without a perpendicular face or coplanar overlap catching the light.

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
	"res://models/cc_by_nc/prison_bunk_bed/prison_bunk_bed.glb"
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
const ASY_DOOR_FIT := DOOR_TOP / ASY_DOOR_H
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
const ANNEX_SHELVING_PATH := \
	"res://models/cc_by/stainless_steel_shelving/stainless_steel_shelving.glb"
const ANNEX_SHELVING_SCALE := 0.025
const ANNEX_SHELVING_CENTRE := Vector3(1.75, 0.0, 0.75)
# Measured tops of the first three load-bearing decks in the imported rack.
# Boxes are bottom-aligned by `_office_shelf_box`, so these are contact planes,
# not approximate visual offsets.
const ANNEX_SHELVING_DECK_TOPS := [0.09375, 0.69375, 1.14375]
const ANNEX_CHAIR_PATH := \
	"res://models/cc_by/wood_dining_chair/wood_dining_chair.glb"
const ANNEX_CHAIR_SCALE := 0.45
const ANNEX_CHAIR_CENTRE := Vector3(0.0, -1.0, 0.0)
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

## Noncommercial, like the mall fascias. Every use runs through
## `_office_desk_phone`, so this dependency lifts out in one edit too.
const OFFICE_PHONE_PATH := "res://models/cc_by_nc/office_phone/office_phone.glb"
const OFFICE_PHONE_CENTRE := Vector3(-0.0703, 0.0039, 0.0840)

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
const CHECKIN_DESK_HALF_D := 1.60
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
	"res://models/cc_by/wall_telephone/wall_telephone.glb"
const PRISON_WALL_PHONE_SCALE := 0.01025
const PRISON_WALL_PHONE_CENTRE := Vector3(13.5224, -18.2725, 0.0)

## Noncommercial, like the mall fascias and the office phone. Reached through
## exactly one function — `_sch_trolley` — so the dependency lifts out in a
## single edit.
##
## Two authored jetways have been measured for `_air_jetway` and neither
## shipped. The apron is a sealed 2.14m diorama strip that the docked aircraft
## already fills — fuselage z 4.00..5.76 across its full 10.5m width. A tunnel
## sized to that depth is either too short to read as a jetway, or tall enough
## to swallow the aircraft rather than dock against it. The generated tube is
## 1m across and tuned to meet a fuselage, which is what this space actually
## needs; a replacement has to be authored as a shallow facade, not a bridge.
const SCH_CLEANING_CART_PATH := \
	"res://models/cc_by_nc/cleaning_cart/cleaning_cart.glb"
const SCH_CLEANING_CART_SCALE := 1.0
const SCH_CLEANING_CART_CENTRE := Vector3(0.0502, -0.0002, -0.0109)

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
const ART_OFFICE := [
	"res://paintings/runtime/painting1-office.webp",
	"res://paintings/runtime/painting2-office.webp",
]
const ART_SEWER := [
	"res://paintings/runtime/painting1-sewer.webp",
	"res://paintings/runtime/painting2-sewer.webp",
]
const ART_AIRPORT := [
	"res://paintings/runtime/painting1-airport.webp",
	"res://paintings/runtime/painting2-airport.webp",
]
const ART_SCHOOL := ["res://paintings/runtime/painting1-school.webp"]
const ART_MALL := [
	"res://paintings/runtime/painting2-mall.webp",
	"res://paintings/runtime/painting3-mall.webp",
	"res://paintings/runtime/painting4-mall.webp",
	"res://paintings/runtime/painting5-mall.webp",
]
const ART_PRISON := ["res://paintings/runtime/painting1-prison.webp"]
const ART_RANDOM := [
	"res://paintings/runtime/painting1-random.webp",
	"res://paintings/runtime/painting2-random.webp",
]
# Sewer paintings remain in the supplied source set, but the sewer itself is
# deliberately bare: damp utility tunnels should not read like a gallery.
const WALL_ART_ALL := ART_VEGAS + ART_OFFICE + ART_AIRPORT \
	+ ART_SCHOOL + ART_MALL + ART_PRISON + ART_RANDOM

static var _prop_preloads_requested := false
static var _slot_scene: PackedScene
static var _attributed_scenes := {}

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
var anomaly_kind := -1
var _descent_lift_rig := {}
var _descent_arrival_rig := {}
var _blackout := false
var _blackout_lights := {}
var _blackout_meshes := {}
var _furnishing_group_serial := 0
## Local XZ footprints of walls and columns that reach the drop ceiling.
## Annex fixtures are built after its architecture and reject these rectangles.
var _annex_ceiling_obstructions: Array[Rect2] = []
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


func _init(p_seed: int, p_cell: Vector2i, p_theme := 0,
		p_config: Dictionary = {}) -> void:
	if not _cone_ready:
		_cone_ready = true
		CONE.top_radius = 0.0
		CONE.bottom_radius = 0.5
		CONE.height = 1.0
	wseed = p_seed
	cell = p_cell
	theme = p_theme
	descent = bool(p_config.get("descent", false))
	descent_target = bool(p_config.get("target", false))
	descent_target_wall = int(p_config.get("target_wall", -1))
	descent_final = bool(p_config.get("final", false))
	descent_floor_idx = int(p_config.get("floor_idx", 0))
	descent_arrival = bool(p_config.get("arrival", false))
	descent_arrival_wall = int(p_config.get("arrival_wall", -1))
	descent_arrival_used = bool(p_config.get("arrival_used", false))
	descent_lift_called = bool(p_config.get("lift_called", false))
	descent_lift_wait = float(p_config.get("lift_wait", 0.0))
	descent_lift_open = bool(p_config.get("lift_open", false))
	anomaly_kind = int(p_config.get("anomaly", -1))
	var requested_blackout := bool(p_config.get("blackout", false))
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
	# ceiling follows the room, so a small room feels small and a hall soars
	ceil_h = HANNEX if theme == 2 else WorldGen.room_height(wseed, room_root, theme)
	if WorldGen.corridor(wseed, cell) != 0:
		ceil_h = HANNEX if theme == 2 else (3.5 if theme == 4 else \
			(HASY if theme == 5 else (HSCH if theme == 6 else \
			(HMALL if theme == 7 else (HPRISON if theme == 8 else HOFF)))))
	_build_floor_ceiling()
	_build_walls()
	if theme == 2:
		# Annex columns and internal partitions must exist before its ceiling
		# grid is populated, otherwise a valid tile-centred fixture can still
		# be cut in half by later architecture.
		_build_props()
		if not is_room_anchor:
			_annex_room_member_architecture()
		_build_lighting()
	else:
		_build_lighting()
		_build_props()
	_build_interactions()
	if anomaly_kind >= 0:
		activate_anomaly(anomaly_kind)
	if requested_blackout:
		set_blackout(true)
	_maybe_probe()


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


## A substantial Annex wall. Keep this on Godot's native BoxMesh rendering
## path: the former hand-built ArrayMesh developed intermittent black faces on
## Metal when several streamed chunks met. Shared boundaries still have one
## canonical owner and cross-corridor corners are single solids, which removes
## the actual coplanar overlaps without replacing the stable wall primitive.
func _annex_wall_prism(pos: Vector3, size: Vector3, along_x: bool,
		cap_min: bool, cap_max: bool, mat: Material) -> MeshInstance3D:
	var mi := _box(pos, size, mat)
	mi.set_meta("annex_native_box", true)
	# Retain the intended continuation metadata for audits and future batching;
	# the geometry itself must remain the engine-native primitive.
	mi.set_meta("annex_wall_along_x", along_x)
	mi.set_meta("annex_wall_cap_min", cap_min)
	mi.set_meta("annex_wall_cap_max", cap_max)
	return mi


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
	pivot.set_meta("atomic_furnishing", kind)
	pivot.set_meta("floor_supported", floor_supported)
	_furnishing_group_serial += 1
	pivot.set_meta("furnishing_group", _furnishing_group_serial)
	add_child(pivot)
	return pivot


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
	if theme == 2:
		_annex_floor_ceiling()
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
		_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), _sch_floor_mat())
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
	var wall_t := ANNEX_WALL_T if theme == 2 else T
	for dir in 4:
		var info := WorldGen.edge_info(wseed, cell, dir, theme)
		# Annex shared boundaries have one canonical east/south owner and sit
		# on the actual boundary plane. Previously both neighbouring chunks
		# built an inward 30cm half, producing a 60cm compound wall. The
		# non-owner still supplies room-side wall dressing below.
		var owns_annex_wall := theme != 2 or dir == 0 or dir == 2
		var plane := (S if (dir == 0 or dir == 2) else 0.0) if theme == 2 \
			else ((S - wall_t / 2.0) if (dir == 0 or dir == 2) \
				else (wall_t / 2.0))
		if info["wall"]:
			if owns_annex_wall:
				_wall_seg(dir, plane, 0.0, S, 0.0, _wall_h())
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
				_wall_seg(dir, plane, 0.0, a, 0.0, _wall_h())
				_wall_seg(dir, plane, b, S, 0.0, _wall_h())
				_wall_seg(dir, plane, a, b,
					AIR_DOOR if theme == 4 or theme == 7 else DOOR_TOP,
					_wall_h())
				_door_casing(dir, plane, a, b)
				_maybe_swing_door(dir, plane, a, b)
			if (theme == 1 or theme == 2) \
					and (theme != 2 or owns_annex_wall) \
					and not (theme == 2 and style == WorldGen.ANNEX_PASSAGE) \
					and not (theme == 1 and style == WorldGen.OFFICE_CORRIDOR):
				_wall_utilities(dir, plane, info)
			if (dir == 0 or dir == 2) and info["exit_sign"]:
				if theme == 4:
					_air_portal_sign(dir, info["t"])
				else:
					_exit_sign(dir, info["t"])


## Some genuine room-to-room openings get a working leaf. Canonical east and
## south ownership prevents the neighbour chunk from building a duplicate.
func _maybe_swing_door(dir: int, plane: float, a: float, b: float) -> void:
	if dir != 0 and dir != 2:
		return
	if theme == 2 or theme == 4 or theme == 7 or b - a > 2.25:
		return
	if WorldGen.h(wseed, cell.x, cell.y, 1760 + dir + theme * 11) % 100 >= 14:
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
	add_child(pivot)
	var panel_mat: Material = Mats.wood_door()
	if theme == 5:
		panel_mat = Mats.asy_metal_green()
	elif theme == 6:
		panel_mat = Mats.sch_door()
	elif theme == 8:
		panel_mat = Mats.prison_green()
	var panel_pos := Vector3(0, 1.08, width * 0.5) if dir == 0 \
		else Vector3(width * 0.5, 1.08, 0)
	var panel_size := Vector3(0.075, 2.16, width) if dir == 0 \
		else Vector3(width, 2.16, 0.075)
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


## Annex boundary walls are centred ON their grid lines, so where the wall
## line turns a corner each wall ran half a thickness past the other's face
## and stopped at its centreline — a stepped notch read as a vertical groove
## down every convex corner. Mitre the turn instead: walls along Z extend half
## a thickness into it, walls along X retract by the same, which closes the
## corner into one edge with abutting (never coplanar same-facing) surfaces.
## Straight continuations and bare ends are left exactly as before.
func _annex_corner_shift(dir: int, at_max: bool) -> float:
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
	if _annex_edge_solid(collinear[0], collinear[1]):
		return 0.0
	if not _annex_edge_solid(perp_a[0], perp_a[1]) \
			and not _annex_edge_solid(perp_b[0], perp_b[1]):
		return 0.0
	var h := ANNEX_WALL_T * 0.5
	# walls along Z (dir 0/1) extend into the turn; walls along X retract
	var outward := h if dir < 2 else -h
	return outward if at_max else -outward


## Whether an edge carries any wall mass at its corners. Openings keep at
## least 0.55m of wall beside each jamb, so any non-full-open edge has solid
## material at both cell corners.
func _annex_edge_solid(at: Vector2i, dir: int) -> bool:
	return not bool(WorldGen.edge_info(wseed, at, dir, theme)["full_open"])


func _wall_seg(dir: int, plane: float, from: float, to: float, y0: float, y1: float) -> void:
	var wall_t := ANNEX_WALL_T if theme == 2 else T
	if theme == 2:
		if is_zero_approx(from):
			from += _annex_corner_shift(dir, false)
		if is_equal_approx(to, S):
			to += _annex_corner_shift(dir, true)
	var ln := to - from
	if ln < 0.05:
		return
	var c := (from + to) * 0.5
	var yc := (y0 + y1) * 0.5
	var hh := y1 - y0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (wall_t * 0.5)
	var wmat: Material = Mats.wallpaper_variant(_finish_variant())
	if theme == 1:
		wmat = Mats.office_wall_variant(_finish_variant())
	elif theme == 2:
		wmat = Mats.annex_wall_variant(
			WorldGen.annex_wall_finish(wseed, cell, dir))
	elif theme == 4:
		wmat = Mats.airport_wall_variant(_finish_variant())
	elif theme == 5:
		wmat = _asy_wall_mat()
	elif theme == 6:
		wmat = _sch_wall_mat()
	elif theme == 7:
		wmat = Mats.mall_wall()
	elif theme == 8:
		wmat = Mats.prison_tile() if style == WorldGen.PRISON_SHOWER else Mats.prison_wall()
	var wall_mesh: MeshInstance3D
	if dir < 2:
		if theme == 2:
			wall_mesh = _annex_wall_prism(Vector3(plane, yc, c),
				Vector3(wall_t, hh, ln), false,
				not is_zero_approx(from), not is_equal_approx(to, S), wmat)
		else:
			wall_mesh = _box(
				Vector3(plane, yc, c), Vector3(wall_t, hh, ln), wmat)
		if theme == 2:
			_annex_register_ceiling_obstruction(
				Vector3(plane, 0.0, c), wall_t, ln, 0.0, y1)
	else:
		if theme == 2:
			wall_mesh = _annex_wall_prism(Vector3(c, yc, plane),
				Vector3(ln, hh, wall_t), true,
				not is_zero_approx(from), not is_equal_approx(to, S), wmat)
		else:
			wall_mesh = _box(
				Vector3(c, yc, plane), Vector3(ln, hh, wall_t), wmat)
		if theme == 2:
			_annex_register_ceiling_obstruction(
				Vector3(c, 0.0, plane), ln, wall_t, 0.0, y1)
	if theme == 2:
		wall_mesh.set_meta("annex_wall_thickness", wall_t)
		wall_mesh.set_meta("annex_wall_seam_safe", true)
		wall_mesh.set_meta("annex_wall_cap_min", not is_zero_approx(from))
		wall_mesh.set_meta("annex_wall_cap_max", not is_equal_approx(to, S))
		# The Annex references meet carpet directly. A contrasting baseboard
		# reads as a freestanding bar whenever generated openings line up.
		return
	if theme == 5:
		# tiled wainscot to shoulder height — unless the whole room is tiled
		if y0 <= 0.01 and not _asy_tiled_room():
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
		# offices: just a dark green baseboard
		if y0 <= 0.01:
			_strip(dir, inner + n * 0.02, 0.055, c, ln, 0.04, 0.11, Mats.base_green())
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


func _door_casing(dir: int, plane: float, a: float, b: float) -> void:
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
	var y := opening_head - 0.18 if theme == 7 \
		else minf(opening_head + 0.46, ceil_h - 0.34)
	var sign_height := 0.24 if theme == 7 else 0.28
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
		# Each face gets a restrained local spill in front of the physical
		# cabinet. A single shadowless light embedded in the wall used to leak
		# red onto the ceiling even when the sign itself was occluded.
		var l := OmniLight3D.new()
		l.set_meta("structural_exit_light", true)
		l.light_color = Color(1.0, 0.2, 0.15)
		l.light_energy = 0.18
		l.omni_range = 1.45
		l.position = lb.position + (Vector3(sside * 0.08, 0, 0) if dir == 0 \
			else Vector3(0, 0, sside * 0.08))
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 10.0
		l.distance_fade_length = 5.0
		add_child(l)


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
			return 0.0 if _asy_tiled_room() else 1.40
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
		1: return ART_OFFICE
		# Airport concourses also carry the mall's commercial advertisements.
		4: return ART_AIRPORT + ART_MALL
		6: return ART_SCHOOL
		7: return ART_MALL
		# Institutional/official airport portraits make sense in the prison too.
		8: return ART_PRISON + ART_AIRPORT
	return []


func _wall_art_path(salt: int) -> String:
	var pool: Array = _wall_art_pool()
	# "Random" is genuinely cross-theme except where the art direction is
	# explicit: offices use only their monochrome portraits, while sewers never
	# call this function at all. The asylum has no named set, so its formal
	# rooms draw exclusively from the two random pieces.
	if pool.is_empty() or (theme != 1 and _r(salt + 1) < 0.16):
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
	match theme:
		1:
			return 0.12 if style == WorldGen.OFFICE_STORAGE else 0.22
		2:
			return 0.0
		4:
			return 0.22
		5:
			return 0.30 if style == WorldGen.ASY_DAYROOM \
				or style == WorldGen.ASY_OFFICE or style == WorldGen.ASY_CHAPEL \
				else 0.0
		6:
			return 0.24 if style == WorldGen.SCH_CORRIDOR \
				or style == WorldGen.SCH_LIBRARY or style == WorldGen.SCH_ADMIN \
				or style == WorldGen.SCH_AUDITORIUM else 0.0
		7:
			# Mall art belongs in the poster-case system below. General mounts
			# can be physically valid yet wind up hidden behind store shelving.
			return 0.0
		8:
			return 0.26 if style == WorldGen.PRISON_MESS \
				or style == WorldGen.PRISON_GUARD \
				or style == WorldGen.PRISON_VISITATION \
				or style == WorldGen.PRISON_ROTUNDA else 0.0
	return 0.0


func _wall_art(dir: int, plane: float, salt: int) -> void:
	var path := _wall_art_path(salt)
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var max_size := Vector2(1.90, 1.38) if theme == 0 \
		else Vector2(1.72, 1.34)
	var size := _wall_art_fit(path, max_size)
	var along := -1.0
	var split := _resolved_room_split()
	for candidate_idx in 6:
		var candidate := lerpf(0.42 + size.x * 0.5,
			S - 0.42 - size.x * 0.5, _r(salt + 2 + candidate_idx * 17))
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
	var y := minf(1.92, ceil_h - size.y * 0.5 - 0.30)
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
			if r < 0.78:
				_mall_storefront(dir, plane)
			elif r < 0.96:
				_mall_poster_case(dir, plane)
			return
		if r < 0.18:
			_office_clock(dir, plane)
		return
	if theme == 8:
		if r < 0.24:
			_prison_number_wall(dir, plane)
		elif r < 0.43:
			_security_camera_wall(dir, plane)
		elif r < 0.52:
			_prison_locked_door_wall(dir, plane)
		elif r < 0.64:
			_sewer_pipes(dir, plane)
		return
	if theme == 5:
		if r < 0.13:
			_asy_straitjacket(dir, plane)
		elif r < 0.27:
			_asy_scrawl(dir, plane)
		elif r < 0.36:
			_asy_crutches(dir, plane)
		elif r < 0.45:
			_asy_noticeboard(dir, plane)
		elif r < 0.54:
			_asy_locked_door_wall(dir, plane)
		elif r < 0.63:
			_asy_wall_notices(dir, plane)
		elif r < 0.72:
			_sewer_pipes(dir, plane)
		elif r < 0.79:
			_office_clock(dir, plane)
		return
	if theme == 6:
		if r < 0.20:
			_sch_noticeboard(dir, plane)
		elif r < 0.32:
			_sch_fountain(dir, plane)
		elif r < 0.42:
			_sch_case(dir, plane)
		elif r < 0.52:
			_office_clock(dir, plane)
		elif r < 0.62:
			_sch_poster(dir, plane)
		return
	if theme == 4:
		if r < 0.30:
			_air_adboxes(dir, plane)
		elif r < 0.42:
			_air_wall_fids(dir, plane)
		return
	if theme == 2:
		# Cameras are the Annex's one intentional furnishing. Keeping them rare
		# makes the otherwise blank walls feel watched rather than decorated.
		# Corridor cameras mount on the visible inner shell instead of the outer
		# backing wall hidden beyond its reserved side strip.
		if style != WorldGen.ANNEX_PASSAGE and r < 0.095:
			_security_camera_wall(dir, plane)
		return
	if theme == 1:
		if r < 0.20:
			_office_door_decor(dir, plane)
		elif r < 0.30:
			_office_clock(dir, plane)
		elif r < 0.46:
			_filing_bank(dir, plane)
		elif r < 0.58:
			_office_poster(dir, plane)
		return
	if r < 0.32:
		_art(dir, plane)
	elif r < 0.5:
		_sconces(dir, plane)
	elif r < 0.62:
		_casino_neon(dir, plane)
	elif r < 0.70:
		_change_machine(dir, plane)


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
	var correction := -PI * 0.5 if is_switch else 0.0
	var depth := 0.015266 if is_switch else 0.005001
	var inst := _attributed_prop_local(mount, path,
		Vector3(0, 0, depth * 0.5 + 0.001), correction)
	if inst == null:
		mount.get_parent().remove_child(mount)
		mount.free()
		return null
	inst.set_meta("wall_mounted_utility", true)
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


## Decorative wood veneer door with chrome handle on an office wall.
func _office_door_decor(dir: int, plane: float) -> void:
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 5.0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var fc := inner + n * 0.02
	if dir < 2:
		_box(Vector3(fc, 1.06, along), Vector3(0.05, 2.1, 1.0), Mats.wood_door(), false)
		_cyl(Vector3(fc + n * 0.03, 1.05, along + 0.36), 0.02, 0.12, Mats.chrome(), false)
	else:
		_box(Vector3(along, 1.06, fc), Vector3(1.0, 2.1, 0.05), Mats.wood_door(), false)
		_cyl(Vector3(along + 0.36, 1.05, fc + n * 0.03), 0.02, 0.12, Mats.chrome(), false)


## Plain wall clock — the kind that makes time feel slower.
func _office_clock(dir: int, plane: float) -> void:
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
	if theme == 7:
		_mall_lighting()
		return
	if theme == 8:
		_prison_lighting()
		return
	if theme == 1:
		_office_lighting()
		return
	if theme == 5:
		_asy_lighting()
		return
	if theme == 2:
		_annex_lighting()
		return
	if theme == 4:
		_air_lighting()
		return
	if theme == 6:
		_sch_lighting()
		return
	if style == WorldGen.STYLE_HALLWAY:
		_hall_lighting()
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
		_casino_flush_mount(Vector3(p.x, 0, p.y), pmat)

	var grand := style == WorldGen.STYLE_GRAND or style == WorldGen.STYLE_BALLROOM
	if grand:
		_chandelier()
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


## A shallow 1930s-style opaline dome in concentric brass rings. The material
## is passed through to FlickerLight, so the visible glass dies with the room.
func _casino_flush_mount(at: Vector3, lens_mat: Material) -> void:
	var y := ceil_h - 0.045
	var plate := _cyl(Vector3(at.x, y, at.z), 0.34, 0.055, Mats.darkwood(), false)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := _cyl(Vector3(at.x, y - 0.035, at.z), 0.285, 0.075, Mats.brass(), false)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glass := _cyl(Vector3(at.x, y - 0.085, at.z), 0.205, 0.065, lens_mat, false)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A small central finial makes the silhouette read as a fixture rather than
	# another luminous disc pasted onto the ceiling.
	var finial := _sphere(Vector3(at.x, y - 0.14, at.z), 0.055, Mats.brass())
	finial.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Hotel circulation is lit by a chain of warm flush mounts, not the four
## fluorescent panels used in gaming rooms.  Each fixture owns its light so
## highlights and falloff follow the visible architecture down the corridor.
func _hall_lighting() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x := cdir != 2
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var dead_i := -1
	var flick_i := -1
	if cell != Vector2i.ZERO and _r(8) < 0.10:
		dead_i = int(_r(18) * 2.99)
	elif cell != Vector2i.ZERO and _r(9) < 0.18:
		flick_i = int(_r(19) * 2.99)
	# A 12m chunk contains five complete 2.4m coffers. Use the first, middle and
	# last medallion centres (local 1.2, 6.0, 10.8); the old 2/6/10 rhythm only
	# aligned its middle fixture and visibly walked off the rosettes down a hall.
	for i in 3:
		var t := -4.8 + 4.8 * float(i)
		var at := _wp(o, Vector3(t, ceil_h - 0.08, 0), yw)
		_cyl(at + Vector3(0, 0.025, 0), 0.27, 0.08, Mats.brass(), false)
		var lens_mat: StandardMaterial3D = Mats.panel_dead() if i == dead_i else Mats.panel_on()
		if i == flick_i:
			lens_mat = Mats.panel_on().duplicate()
		_cyl(at - Vector3(0, 0.035, 0), 0.20, 0.035, lens_mat, false)
		if i == dead_i:
			continue
		var light: OmniLight3D
		if i == flick_i:
			light = _make_main_light(true, lens_mat, 0.58)
		else:
			light = OmniLight3D.new()
			light.light_energy = 0.58
		light.light_color = Color(1.0, 0.72, 0.46)
		light.omni_range = 5.6
		light.position = at - Vector3(0, 0.30, 0)
		light.shadow_enabled = i == 1
		light.distance_fade_enabled = true
		light.distance_fade_begin = 20.0
		light.distance_fade_length = 7.0
		light.distance_fade_shadow = 15.0
		add_child(light)


func _office_lighting() -> void:
	if style == WorldGen.OFFICE_CORRIDOR:
		_office_corridor_lighting()
		return
	var is_spawn := cell == Vector2i.ZERO
	var dead := (not is_spawn) and _r(8) < 0.02
	var flicker := (not is_spawn) and (not dead) and _r(9) < 0.05
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.office_panel().duplicate()
	else:
		pmat = Mats.office_panel()
	# dense, even grid of fluorescent troffers — shadowless corporate daylight
	for gx in [3.0, 9.0]:
		for gz in [2.1, 4.7, 7.3, 9.9]:
			_troffer(Vector3(gx, 0, gz), Vector2(1.15, 0.55), pmat, Mats.metal_gray())
	# AC diffuser grilles between the light rows
	for vp in [Vector2(6.0, 3.4), Vector2(6.0, 8.6)]:
		_box(Vector3(vp.x, ceil_h - 0.015, vp.y), Vector3(0.62, 0.03, 0.62), Mats.metal_gray(), false)
		for si in 4:
			_box(Vector3(vp.x, ceil_h - 0.035, vp.y - 0.21 + 0.14 * float(si)),
				Vector3(0.54, 0.012, 0.05), Mats.charcoal(), false)
	if dead:
		return
	var light := _make_main_light(flicker, pmat, 1.0)
	light.light_color = Color(0.93, 1.0, 0.95)
	light.omni_range = 12.5
	light.position = Vector3(S / 2.0, ceil_h - 0.5, S / 2.0)
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	add_child(light)


## Corridor fixtures follow the actual lane instead of filling the entire
## 12m cell.  Besides reading as intentional architecture, this prevents
## light from leaking out of the reserved office volumes behind locked doors.
func _office_corridor_lighting() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x := cdir != 2
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var dead := _r(8) < 0.025
	var flicker := not dead and _r(9) < 0.07
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.office_panel().duplicate()
	else:
		pmat = Mats.office_panel()
	for t in [-4.5, -1.5, 1.5, 4.5]:
		var at := _wp(o, Vector3(t, 0, 0), yw)
		_troffer(at, Vector2(1.15, 0.5) if along_x else Vector2(0.5, 1.15),
			pmat, Mats.metal_gray())
	# One supply and one return grille, both kept over the corridor rather than
	# in the inaccessible office strips.
	for t in [-3.0, 3.0]:
		var vp := _wp(o, Vector3(t, ceil_h - 0.018, 0.88 if t < 0.0 else -0.88), yw)
		var grille := _mbox(self, vp, Vector3(0.58, 0.032, 0.58), Mats.metal_gray())
		grille.rotation.y = yw
	if dead:
		return
	var light := _make_main_light(flicker, pmat, 0.82)
	light.light_color = Color(0.91, 1.0, 0.94)
	light.omni_range = 10.5
	light.position = Vector3(S / 2.0, ceil_h - 0.48, S / 2.0)
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 8.0
	add_child(light)


## Ceiling light fixture: recessed glowing lens inside a trim frame, instead
## of a bare emissive slab stuck to the tiles.
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
	bz.bus = "Hall"
	bz.autoplay = true
	bz.position = Vector3(S / 2.0, _wall_h() - 0.5, S / 2.0)
	add_child(bz)
	fl.buzz = bz
	return fl


func _chandelier() -> void:
	# a real ornate chandelier (CC0 model, hangs 1.04m below its origin) with
	# a warm bulb glowing in its heart
	var ch := _cc0_prop("Chandelier_03", Vector3(S / 2.0, ceil_h - 0.05, S / 2.0), _r(30) * TAU, 1.35)
	_asy_no_shadows(ch)
	_sphere(Vector3(S / 2.0, ceil_h - 0.95, S / 2.0), 0.13, Mats.bulb())


# --- furnishing --------------------------------------------------------------

## Resolve a proposed single-room split once and share the result between the
## partition, its furnishings, and wall decoration. Previously `_partition`
## could silently slide or rotate the wall while every later system continued
## using the stale proposal, which produced bisected art and furniture on the
## wrong side of the actual room.
func _resolved_room_split() -> Array:
	var split := WorldGen.room_split(wseed, room_root, theme)
	if split.is_empty():
		return []
	var along_x := bool(split[0])
	var off := float(split[1])
	var chosen := WorldGen.partition_offset(wseed, cell, theme, along_x, off)
	if chosen < 0.0:
		along_x = not along_x
		chosen = WorldGen.partition_offset(wseed, cell, theme, along_x, off)
	if chosen < 0.0:
		return []
	return [along_x, chosen]


func _build_props() -> void:
	portal_dest = -1 if descent else WorldGen.portal(wseed, cell, theme)
	if portal_dest >= 0:
		_build_portal(portal_dest)
	# Cell strips hug their own cell's walls, so every cell of a merged block
	# builds its own — the anchor-only path would leave the rest of the block
	# as bare box rooms.
	if not is_room_anchor and style == WorldGen.PRISON_CELLBLOCK and not descent_target:
		_prison_cellblock()
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
		_office_air_conditioners(split)
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
			or style == WorldGen.PRISON_VISITATION or style == WorldGen.PRISON_INDUSTRY:
		off = Vector3.ZERO
	var n0 := get_child_count()
	var b0 := body.get_child_count()
	# On rare 24x24 Annex rooms the furniture hoard replaces that room's usual
	# architectural dressing. It remains one atomic, clearance-aware set piece.
	if theme == 2 and _annex_furniture_pile():
		_shift_props(off, n0, b0)
		_clear_furnishings_from_doorways(n0, b0)
		return
	match style:
		WorldGen.STYLE_PILLARS:
			_pillars(ceil_h, Mats.brass())
			# A pillared hall is casino floor. Grand halls are 1.4% of the
			# level, so gating table games on them left a Vegas with almost no
			# tables in it; the common room styles carry them instead.
			if _r(240) < 0.62:
				_blackjack(Vector3(6.0, 0, 6.0), 242)
			elif _r(241) < 0.55:
				_roulette(Vector3(6.0, 0, 6.0), 243)
		WorldGen.STYLE_SLOTS:
			_slots()
			# Table games sit at either end of the machine floor, clear of both
			# banks. This is the room that most reads as a casino and it had
			# nothing but slots in it.
			if _r(250) < 0.72:
				var table_z := 1.95 if _r(251) < 0.5 else 10.05
				if _r(252) < 0.55:
					_blackjack(Vector3(6.0, 0, table_z), 253)
				else:
					_roulette(Vector3(6.0, 0, table_z), 254)
		WorldGen.STYLE_LOUNGE:
			_lounge()
			if _r(240) < 0.58:
				_blackjack(Vector3(9.4, 0, 4.6), 242)
			elif _r(244) < 0.5:
				_roulette(Vector3(8.4, 0, 4.4), 245)
		WorldGen.STYLE_GRAND:
			_pillars(ceil_h, Mats.marble_photo())
			if room_n >= 4:
				_blackjack(Vector3(1.6, 0, 1.6), 248)
				_blackjack(Vector3(10.4, 0, 10.4), 286)
				# One roulette table anchors the middle of a grand hall, where
				# there is genuinely room for a 3m layout.
				if _r(287) < 0.62:
					_roulette(Vector3(S / 2.0, 0, S / 2.0), 288)
			elif _r(289) < 0.62:
				_roulette(Vector3(S / 2.0, 0, S / 2.0), 290)
			else:
				_blackjack(Vector3(S / 2.0, 0, S / 2.0), 291)
			if _r(246) < 0.5:
				_velvet_ropes()
		WorldGen.STYLE_BALLROOM:
			_casino_ballroom()
		WorldGen.STYLE_HALLWAY:
			_hallway()
		WorldGen.STYLE_EMPTY:
			if portal_dest < 0 and _r(20) < 0.35:
				_planter(Vector3(2.6 + 6.8 * _r(21), 0, 2.6 + 6.8 * _r(22)))
			if portal_dest < 0 and _r(24) < 0.48:
				_casino_service_cart(Vector3(2.1 if _r(25) < 0.5 else 9.9, 0,
					2.1 if _r(26) < 0.5 else 9.9), 27)
		WorldGen.OFFICE_CORRIDOR:
			_office_corridor()
		WorldGen.OFFICE_CUBICLES:
			_office_cubicles()
		WorldGen.OFFICE_STORAGE:
			_office_storage()
		WorldGen.OFFICE_BREAK:
			_office_break()
		WorldGen.OFFICE_BOARDROOM:
			_office_boardroom()
		WorldGen.OFFICE_EMPTY:
			if portal_dest < 0 and _r(20) < 0.15:
				_planter(Vector3(2.6 + 6.8 * _r(21), 0, 2.6 + 6.8 * _r(22)))
			if _r(250) < 0.35:
				_copier(Vector3(3.0, 0, 8.8), 252)
			elif portal_dest < 0 and _r(254) < 0.62:
				_office_floor_files(Vector3(2.2 if _r(255) < 0.5 else 9.8, 0,
					2.1 if _r(256) < 0.5 else 9.9), 257)
		WorldGen.ANNEX_OPEN:
			_annex_open()
		WorldGen.ANNEX_MAZE:
			_annex_maze()
		WorldGen.ANNEX_LONG:
			_annex_long()
		WorldGen.ANNEX_QUIET:
			_annex_quiet()
		WorldGen.ANNEX_PASSAGE:
			_annex_passage()
		WorldGen.ANNEX_LOBBY:
			_annex_lobby()
		WorldGen.AIR_GATE:
			_air_gate()
			_air_common()
		WorldGen.AIR_CONCOURSE:
			_air_concourse()
			_air_common()
		WorldGen.AIR_TRANSIT:
			_air_transit()
			_air_common()
		WorldGen.AIR_CHECKIN:
			_air_checkin()
			_air_common()
		WorldGen.AIR_BAGGAGE:
			_air_baggage()
			_air_common()
		WorldGen.AIR_ESCALATOR:
			_air_escalator()
			_air_common()
		WorldGen.AIR_HALL:
			_air_hall()
			_air_common()
		WorldGen.AIR_FOODCOURT:
			_air_foodcourt()
			_air_common()
		WorldGen.ASY_CELL:
			_asy_cell_props()
		WorldGen.ASY_WARD:
			_asy_ward()
			_asy_sounds()
		WorldGen.ASY_DAYROOM:
			_asy_dayroom()
			_asy_sounds()
		WorldGen.ASY_TREATMENT:
			_asy_treatment()
			_asy_sounds()
		WorldGen.ASY_HYDRO:
			_asy_hydro()
			_asy_sounds()
		WorldGen.ASY_OFFICE:
			_asy_office()
		WorldGen.ASY_CORRIDOR:
			_asy_corridor()
			if _r(779) < 0.35:
				_asy_sounds()
		WorldGen.ASY_CHAPEL:
			_asy_chapel()
			_asy_sounds()
		WorldGen.SCH_CORRIDOR:
			_sch_corridor()
		WorldGen.SCH_CLASSROOM:
			_sch_classroom()
		WorldGen.SCH_CAFETERIA:
			_sch_cafeteria()
		WorldGen.SCH_BATHROOM:
			_sch_bathroom()
		WorldGen.SCH_GYM:
			_sch_gym()
		WorldGen.SCH_LIBRARY:
			_sch_library()
		WorldGen.SCH_LAB:
			_sch_lab()
		WorldGen.SCH_ADMIN:
			_sch_admin()
		WorldGen.SCH_AUDITORIUM:
			_sch_auditorium()
		WorldGen.MALL_CORRIDOR:
			_mall_corridor()
		WorldGen.MALL_STORE:
			_mall_store()
		WorldGen.MALL_ANCHOR:
			_mall_anchor()
		WorldGen.MALL_FOODCOURT:
			_mall_foodcourt()
		WorldGen.MALL_ATRIUM:
			_mall_atrium()
		WorldGen.MALL_SERVICE:
			_mall_service()
		WorldGen.MALL_KIOSKS:
			_mall_kiosks()
		WorldGen.MALL_CINEMA:
			_mall_cinema()
		WorldGen.PRISON_CORRIDOR:
			_prison_corridor()
		WorldGen.PRISON_CELLBLOCK:
			_prison_cellblock()
		WorldGen.PRISON_CELLS:
			_prison_cells()
		WorldGen.PRISON_MESS:
			_prison_mess()
		WorldGen.PRISON_SHOWER:
			_prison_shower()
		WorldGen.PRISON_GUARD:
			_prison_guard()
		WorldGen.PRISON_INDUSTRY:
			_prison_industry()
		WorldGen.PRISON_VISITATION:
			_prison_visitation()
		WorldGen.PRISON_ROTUNDA:
			_prison_rotunda()
	if theme == 2:
		_annex_lived_in_dressing()
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
			var info := WorldGen.edge_info(wseed, member, dir, theme)
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
		if descent_arrival and descent_arrival_wall >= 0:
			_descent_arrival_car(descent_arrival_wall)
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
		v.position = Vector3(inner + n * 0.035, 0, S / 2.0)
		v.rotation.y = -PI / 2.0 if dir == 0 else PI / 2.0
	else:
		v.position = Vector3(S / 2.0, 0, inner + n * 0.035)
		v.rotation.y = PI if dir == 2 else 0.0
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
	# Header display and its stubborn amber direction arrow.
	_mrbox(v, Vector3(0, 2.78, 0.035), Vector3(0.92, 0.34, 0.08), Mats.sign_housing(), 0.018)
	var floor_lb := Label3D.new()
	floor_lb.text = "%d  ▼" % (WorldGen.THEMES.find(theme) + 1)
	floor_lb.font_size = 72
	floor_lb.pixel_size = 0.0021
	floor_lb.modulate = Color(1.0, 0.56, 0.18)
	floor_lb.position = Vector3(0, 2.78, 0.082)
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
	var rig := _descent_car_shell(dir, false)
	_descent_lift_rig = rig
	var hit := Interactable.new()
	hit.name = "DescentLiftCall"
	hit.prompt_text = "E — call lift"
	hit.position = Vector3(1.50, 1.28, 2.48)
	hit.add_box(Vector3(0.52, 0.82, 0.36))
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
static func descent_car_basis(dir: int) -> Transform3D:
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var plane := (S - T / 2.0) if dir == 0 or dir == 2 else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var at := Vector3.ZERO
	var yaw := 0.0
	if dir < 2:
		at = Vector3(inner + n * 0.035, 0, S / 2.0)
		yaw = -PI / 2.0 if dir == 0 else PI / 2.0
	else:
		at = Vector3(S / 2.0, 0, inner + n * 0.035)
		yaw = PI if dir == 2 else 0.0
	return Transform3D(Basis(Vector3.UP, yaw), at)


## World-space standing position inside the car built against `dir` of `cell`,
## and the yaw that faces its doors. The interior is a sealed authored box, so
## this point is safe by construction and deliberately bypasses ArrivalSafety —
## whose escape-direction test a 2.2m car can never satisfy.
static func car_interior_point(cell: Vector2i, dir: int) -> Dictionary:
	var basis_at := descent_car_basis(dir)
	var local := Vector3(0.0, 0.15, 1.12)
	var world := basis_at * local + Vector3(float(cell.x) * S, 0.0,
		float(cell.y) * S)
	# The doors sit at +Z in car space; the camera convention is -Z forward.
	return {"position": world, "yaw": basis_at.basis.get_euler().y + PI}


func _descent_car_shell(dir: int, out: bool, arrival := false) -> Dictionary:
	var root := Node3D.new()
	root.name = "DescentArrival" if arrival else (
		"DescentExit" if out else "DescentElevator")
	root.transform = descent_car_basis(dir)
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
	sound.stream = SoundBank.elev()
	sound.volume_db = -8.0
	sound.max_distance = 24.0
	owner.add_child(sound)
	sound.play()
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(left, "position:x", -1.02, seconds)
	tw.parallel().tween_property(right, "position:x", 1.02, seconds)


func _descent_commit(actor: Node, rig: Dictionary, commit: Area3D,
		hit: Interactable) -> void:
	if not actor is Player or commit.has_meta("committed"):
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
	_descent_sound(root, SoundBank.clang(), -14.0)
	display.modulate = Color(1.0, 0.56, 0.18)
	display.text = "%02d" % (descent_floor_idx + 1)
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return

	# Brake release, then the hoist takes the weight.
	_descent_sound(root, SoundBank.thud(), -8.0)
	var motor := AudioStreamPlayer3D.new()
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
	get_tree().call_group("descent_listener", "descent_arrival_spent")
	await get_tree().create_timer(1.7).timeout
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
			or not WorldGen.room_split(wseed, room_root, theme).is_empty()):
		# A narrow or partitioned cell has no universally safe standing corner.
		# Fall back to the collider-free dead-light mutation.
		activate_anomaly(0)
	elif kind == 1 and not has_node("WaitingFigure"):
		var f := ShadowFigure.new()
		f.name = "WaitingFigure"
		# stands in a corner rather than hangs, so it reads as watching
		f.variant = ShadowFigure.GAOLER
		f.mode = ShadowFigure.Mode.INERT
		var corners := [
			Vector3(1.45, 0, 1.45), Vector3(10.55, 0, 1.45),
			Vector3(1.45, 0, 10.55), Vector3(10.55, 0, 10.55),
		]
		f.position = corners[WorldGen.h(wseed, cell.x, cell.y, 2441) % 4]
		add_child(f)


func _mesh_is_emissive(mesh: MeshInstance3D) -> bool:
	var mat := mesh.material_override
	if mat is StandardMaterial3D:
		return (mat as StandardMaterial3D).emission_enabled
	return false


func _pillars(h: float, mat: Material) -> void:
	var points := [Vector2(2.2, 2.2), Vector2(9.8, 2.2),
		Vector2(2.2, 9.8), Vector2(9.8, 9.8)]
	if style == WorldGen.STYLE_GRAND and room_n >= 4:
		# Local (6,6) is shifted to the 24x24 room centre after furnishing.
		# An eight-column perimeter grid leaves a generous central axis while
		# making the whole hall, not just its middle cell, feel supported.
		points = []
		for px in [-8.0, 0.0, 8.0]:
			for pz in [-8.0, 0.0, 8.0]:
				if px == 0.0 and pz == 0.0:
					continue
				points.append(Vector2(6.0 + px, 6.0 + pz))
	for p in points:
		_box(Vector3(p.x, 0.06, p.y), Vector3(0.95, 0.12, 0.95), Mats.darkwood())
		_cyl(Vector3(p.x, h / 2.0, p.y), 0.34, h, mat)
		for ring_y in [0.28, h - 0.28]:
			var tor := MeshInstance3D.new()
			tor.mesh = TOR
			tor.material_override = Mats.brass()
			tor.position = Vector3(p.x, ring_y, p.y)
			tor.scale = Vector3(0.5, 0.22, 0.5)
			add_child(tor)


# --- vegas: slots ------------------------------------------------------------

func _slots() -> void:
	var idx := 0
	for row in [[4.35, -1.0], [7.65, 1.0]]:
		var z: float = row[0]
		var fx: float = row[1]
		for i in 5:
			_slot_machine(3.4 + 1.3 * i, z, fx, idx)
			idx += 1
	# colored glow washing over each bank's player side
	var glow_cols := [Color(1.0, 0.35, 0.6), Color(0.45, 0.8, 1.0)]
	var glow_z := [3.0, 9.0]
	for gi in 2:
		var gl := OmniLight3D.new()
		gl.light_color = glow_cols[gi]
		gl.light_energy = 0.7
		gl.omni_range = 5.5
		gl.position = Vector3(S / 2.0, 2.3, glow_z[gi])
		gl.shadow_enabled = false
		gl.distance_fade_enabled = true
		gl.distance_fade_begin = 16.0
		gl.distance_fade_length = 8.0
		add_child(gl)
	# magenta ceiling cove around the slot floor
	var cy := ceil_h - 0.22
	_box(Vector3(S / 2.0, cy, 0.5), Vector3(S - 1.6, 0.05, 0.06), Mats.neon_pink(), false)
	_box(Vector3(S / 2.0, cy, S - 0.5), Vector3(S - 1.6, 0.05, 0.06), Mats.neon_pink(), false)
	_box(Vector3(0.5, cy, S / 2.0), Vector3(0.06, 0.05, S - 1.6), Mats.neon_pink(), false)
	_box(Vector3(S - 0.5, cy, S / 2.0), Vector3(0.06, 0.05, S - 1.6), Mats.neon_pink(), false)
	_slots_sign()
	var snd := SlotSounds.new()
	snd.position = Vector3(S / 2.0, 1.6, S / 2.0)
	add_child(snd)


## Most of the casino floor uses morrrtu1o's properly attributed, textured
## vintage cabinet, while a small minority remains newer procedural hardware
## so the bank does not read as ten copies of one machine. The downloaded
## source can disappear without breaking the generated fallback.
func _slot_machine(x: float, z: float, f: float, idx: int) -> void:
	if posmod(idx, 5) == 4:
		_slot_machine_alt(x, z, f, idx)
		return
	if _slot_scene == null:
		_slot_scene = _prop_scene(SLOT_MACHINE_PATH)
	if _slot_scene == null:
		_procedural_slot_machine(x, z, f, idx)
		return

	var m := Node3D.new()
	m.name = "VintageSlotMachine"
	m.set_meta("slot_machine", true)
	m.set_meta("slot_asset", "morrrtu1o_slot_machine")
	m.position = Vector3(x, 0, z)
	if f < 0.0:
		m.rotation.y = PI
	add_child(m)

	var inst := _slot_scene.instantiate() as Node3D
	inst.name = "AttributedCabinet"
	inst.scale = Vector3.ONE * SLOT_MACHINE_SCALE
	inst.position.y = SLOT_MACHINE_FLOOR_OFFSET * SLOT_MACHINE_SCALE
	# The model is a closed, double-sided cabinet with an explicit front and
	# service back. These tags let the generated-world audit distinguish that
	# deliberate volume from the old stacks of unsupported display quads.
	inst.set_meta("slot_front_shell", true)
	inst.set_meta("slot_rear_shell", true)
	m.add_child(inst)

	# The downloaded prop supplies the cabinet and PBR wear. A tiny live status
	# lamp ties it into the surrounding bank lighting without bleaching its
	# baked artwork or turning the vintage machine into another neon pillar.
	var status := _mcyl(m, Vector3(0.22, 0.91, 0.31),
		0.015, 0.012, Mats.slot_status_blue())
	status.rotation.x = PI / 2.0

	if _r(60 + idx) < 0.85:
		var cyaw := (0.0 if f > 0.0 else PI) + (_r(66 + idx) - 0.5) * 0.6
		var cpos := Vector3(x + (_r(96 + idx) - 0.5) * 0.16, 0, z + f * 0.95)
		_cc0_prop("bar_chair_round_01", cpos, cyaw)
		_collider_cyl(cpos + Vector3(0, 0.4, 0), 0.25, 0.8)
	_collider_box(Vector3(x, 0.85, z), Vector3(0.88, 1.70, 0.76))


## The minority cabinet, so a bank never reads as ten copies of the vintage
## one. This used to be forty-two primitives with live shader screens; it is
## now a second authored machine, and the generated cabinet below stays as the
## fallback if the model is missing.
func _slot_machine_alt(x: float, z: float, f: float, idx: int) -> void:
	var yaw := 0.0 if f > 0.0 else PI
	var b0 := body.get_child_count()
	var pivot := _attributed_floor_prop(SLOT_ALT_PATH, Vector3(x, 0, z), yaw,
		SLOT_ALT_SCALE, SLOT_ALT_CENTRE, "slot_machine_alt", null, true)
	if pivot == null:
		_procedural_slot_machine(x, z, f, idx)
		return
	pivot.set_meta("slot_machine", true)
	pivot.set_meta("slot_asset", "slot_machine_alt")
	# The generated-world audit checks that no cabinet is an unsupported stack
	# of display quads. This one is a closed authored volume, front and back.
	pivot.set_meta("slot_front_shell", true)
	pivot.set_meta("slot_rear_shell", true)
	if _r(60 + idx) < 0.85:
		var cyaw := yaw + (_r(66 + idx) - 0.5) * 0.6
		var cpos := Vector3(x + (_r(96 + idx) - 0.5) * 0.16, 0, z + f * 0.95)
		_cc0_prop("bar_chair_round_01", cpos, cyaw)
		_collider_cyl(cpos + Vector3(0, 0.4, 0), 0.25, 0.8)
	_collider_box(Vector3(x, 0.88, z), Vector3(0.62, 1.76, 1.10))
	_bind_furnishing_colliders(pivot, b0)


## Newer alternate machine: sculpted cabinet shell (shared ArrayMesh) with the
## full panel stack riding its sloped front, and a bonus wheel or marquee.
func _procedural_slot_machine(x: float, z: float, f: float, idx: int) -> void:
	var m := Node3D.new()
	m.name = "SlotMachine"
	m.set_meta("slot_machine", true)
	m.position = Vector3(x, 0, z)
	if f < 0.0:
		m.rotation.y = PI
	add_child(m)
	var cabinet_type := idx % 4
	# Bonus wheels are visual punctuation, not half the casino floor. The other
	# cabinets split between classic mechanical, slant-top and portrait video
	# silhouettes so a bank no longer reads as ten clones.
	var has_wheel := cabinet_type == 0
	var accent: Material = Mats.slot_accent_amber() \
		if posmod(idx, 3) == 0 else Mats.slot_accent_cyan()
	var bodymat: Material = Mats.slot_cabinet_variant(idx)
	var plastic := Mats.slot_molded_plastic()
	var trim := Mats.slot_brushed_metal()

	var shell := MeshInstance3D.new()
	shell.mesh = Cabinet.mesh()
	shell.material_override = bodymat
	m.add_child(shell)
	# The sculpted shell's rear used to be a single custom-mesh face. It could
	# disappear from the back because of face winding/material culling, leaving
	# a bank of convincing fronts that looked hollow from the central aisle.
	# Build the rear as real volume, with the service hardware a casino cabinet
	# would actually expose.
	var rear := _mrbox(m, Vector3(0, 1.06, -0.225),
		Vector3(0.58, 2.08, 0.12), bodymat, 0.025)
	rear.name = "RearShell"
	rear.set_meta("slot_rear_shell", true)
	var service := _mrbox(m, Vector3(0, 1.08, -0.294),
		Vector3(0.45, 1.42, 0.025), plastic, 0.018)
	service.name = "RearServiceDoor"
	# Recessed ventilation slots, a lock and a low power-entry cover keep the
	# back readable without turning the normally hidden side into another sign.
	for vi in 7:
		_mbox(m, Vector3(0, 1.66 + float(vi) * 0.055, -0.310),
			Vector3(0.27, 0.014, 0.012), Mats.rubber_black())
	var rear_lock := _mcyl(m, Vector3(0.155, 1.29, -0.316),
		0.025, 0.018, trim)
	rear_lock.rotation.x = PI / 2.0
	_mrbox(m, Vector3(0, 0.34, -0.312),
		Vector3(0.26, 0.20, 0.035), plastic, 0.01)
	# Manufacturer/service label, hinge knuckles and power inlet.
	_mbox(m, Vector3(-0.105, 0.82, -0.323),
		Vector3(0.14, 0.09, 0.008), Mats.slot_service_label())
	for hy in [0.58, 1.05, 1.50]:
		var hinge := _mcyl(m, Vector3(-0.236, hy, -0.312),
			0.018, 0.07, trim)
		hinge.rotation.x = PI / 2.0
	_mbox(m, Vector3(0.07, 0.33, -0.334),
		Vector3(0.075, 0.085, 0.012), Mats.rubber_black())
	_mbox(m, Vector3(0, 0.135, -0.286),
		Vector3(0.60, 0.22, 0.16), plastic)
	# The screen stack used to be a collection of front-facing quads over an
	# open custom mesh. A continuous recessed substrate now closes every gap
	# around and between the ticker, reels and paytable, so the casino cannot
	# be seen through the face of the machine from oblique angles.
	var front := _mrbox(m, Vector3(0, 1.18, 0.205),
		Vector3(0.58, 1.92, 0.13), bodymat, 0.024)
	front.name = "FrontShell"
	front.set_meta("slot_front_shell", true)
	_mrbox(m, Vector3(0, 1.42, 0.252),
		Vector3(0.50, 1.23, 0.018), plastic, 0.009)
	# Restrained edge illumination: most real cabinets illuminate the display
	# frame, not two floor-to-top neon poles. One machine per bank keeps the
	# louder full-height treatment; the rest have short inset light guides.
	var accent_h := 1.55 if posmod(idx, 5) == 0 else 0.68
	var accent_y := 1.08 if accent_h > 1.0 else 1.43
	for sx in [-1.0, 1.0]:
		_mbox(m, Vector3(sx * 0.284, accent_y, 0.275),
			Vector3(0.014, accent_h, 0.018), accent)
		_mbox(m, Vector3(sx * 0.264, 1.42, 0.292),
			Vector3(0.018, 1.10, 0.022), trim)
	_mrbox(m, Vector3(0, 0.24, 0.235), Vector3(0.36, 0.13, 0.06), plastic, 0.015)
	_mquad(m, Vector3(0, 0.42, 0.278), Vector2(0.44, 0.26), Mats.ticker())
	# Ticket bin and lockable lower cash door.
	_mrbox(m, Vector3(0, 0.125, 0.322),
		Vector3(0.24, 0.055, 0.055), trim, 0.008)
	_mbox(m, Vector3(-0.18, 0.23, 0.304),
		Vector3(0.09, 0.055, 0.008), Mats.slot_service_label())
	var cash_lock := _mcyl(m, Vector3(0.20, 0.32, 0.310),
		0.017, 0.014, trim)
	cash_lock.rotation.x = PI / 2.0
	for sx in [-1.0, 1.0]:
		_mbox(m, Vector3(sx * 0.19, 0.64, 0.272),
			Vector3(0.09, 0.14, 0.015), plastic)
	var deck := _mrbox(m, Vector3(0, 0.84, 0.30),
		Vector3(0.54, 0.045, 0.26), plastic, 0.012)
	deck.rotation.x = 0.45
	var bmats: Array = [Mats.lamp_amber(), Mats.red_knob(), Mats.chrome(), Mats.lamp_red(), Mats.lamp_amber()]
	for bi in 5:
		var btn := _mcyl(m, Vector3(-0.17 + 0.077 * bi, 0.875, 0.345), 0.024, 0.02, bmats[bi])
		btn.rotation.x = 0.45
	# Bill validator, player card reader and ticket-printer mouth.
	_mbox(m, Vector3(0.19, 0.80, 0.315), Vector3(0.12, 0.09, 0.07), plastic)
	_mbox(m, Vector3(0.19, 0.815, 0.352), Vector3(0.07, 0.012, 0.01), Mats.lamp_green())
	_mrbox(m, Vector3(-0.18, 0.785, 0.356),
		Vector3(0.10, 0.052, 0.018), Mats.slot_status_blue(), 0.006)
	_mbox(m, Vector3(0.02, 0.755, 0.361),
		Vector3(0.105, 0.012, 0.008), Mats.rubber_black())
	var reels := _mquad(m, Vector3(0, 1.18, 0.335), Vector2(0.46, 0.40), Mats.slot_reels())
	reels.rotation.x = -0.107
	var pay := _mquad(m, Vector3(0, 1.66, 0.275), Vector2(0.46, 0.34),
		Mats.slot_artwork(idx))
	pay.rotation.x = -0.095
	var glass := _mquad(m, Vector3(0, 1.45, 0.315), Vector2(0.5, 1.0), Mats.glass())
	glass.rotation.x = -0.1
	# Speaker grille and the seam of the hinged screen/service door.
	for si in 7:
		_mbox(m, Vector3(-0.15 + si * 0.05, 1.925, 0.302),
			Vector3(0.028, 0.012, 0.008), Mats.rubber_black())
	_mbox(m, Vector3(0, 0.715, 0.300),
		Vector3(0.46, 0.008, 0.008), trim)
	_mrbox(m, Vector3(0, 2.19, -0.02),
		Vector3(0.54, 0.18, 0.40), plastic, 0.02)
	_mquad(m, Vector3(0, 2.19, 0.185), Vector2(0.5, 0.16), Mats.ticker())
	_mcyl(m, Vector3(0, 2.33, -0.16), 0.035, 0.1, Mats.lamp_amber())
	_mcyl(m, Vector3(0, 2.42, -0.16), 0.03, 0.08, Mats.lamp_red())
	if has_wheel:
		_mbox(m, Vector3(0, 2.38, 0.0), Vector3(0.16, 0.35, 0.1), Mats.gold_mirror())
		# The bonus wheel was another front-only quad. A shallow metal drum
		# closes the topper and gives its silhouette proper depth from behind.
		var wheel_back := _mcyl(m, Vector3(0, 2.72, -0.035),
			0.35, 0.11, Mats.sign_housing())
		wheel_back.rotation.x = PI / 2.0
		wheel_back.set_meta("slot_topper_back", true)
		var wheel_hub := _mcyl(m, Vector3(0, 2.72, -0.096),
			0.075, 0.025, Mats.chrome())
		wheel_hub.rotation.x = PI / 2.0
		_mquad(m, Vector3(0, 2.72, 0.06), Vector2(0.66, 0.66), Mats.slot_wheel())
		var ring := MeshInstance3D.new()
		ring.mesh = TOR
		ring.material_override = Mats.ring_pink() if _r(84 + idx) < 0.5 else Mats.ring_cyan()
		ring.position = Vector3(0, 2.72, 0.03)
		ring.scale = Vector3(0.36, 0.16, 0.36)
		ring.rotation.x = PI / 2.0
		m.add_child(ring)
		for sx in [-1.0, 1.0]:
			var wing := _mbox(m, Vector3(sx * 0.30, 2.62, -0.02), Vector3(0.1, 0.5, 0.08), Mats.gold_mirror())
			wing.rotation.z = -sx * 0.3
	else:
		var top_h := 0.52 if cabinet_type == 1 else 0.38
		var top_y := 2.53 if cabinet_type == 1 else 2.47
		_mrbox(m, Vector3(0, top_y, 0.0),
			Vector3(0.54, top_h, 0.14), plastic, 0.02)
		_mquad(m, Vector3(0, top_y, 0.075),
			Vector2(0.5, min(top_h - 0.04, 0.34)), Mats.slot_artwork(idx + 1))
		# Only the deliberately old mechanical variant retains a pull arm.
		if cabinet_type == 2:
			var arm := _mcyl(m, Vector3(0.33, 1.35, -0.02),
				0.018, 0.34, trim)
			arm.rotation.x = -0.4
			var knob := MeshInstance3D.new()
			knob.mesh = SPH
			knob.material_override = Mats.red_knob()
			knob.position = Vector3(0.33, 1.5, -0.09)
			knob.scale = Vector3.ONE * 0.09
			m.add_child(knob)
	if _r(60 + idx) < 0.85:
		var cyaw := (0.0 if f > 0.0 else PI) + (_r(66 + idx) - 0.5) * 0.6
		var cpos := Vector3(x + (_r(96 + idx) - 0.5) * 0.16, 0, z + f * 0.95)
		# a real worn bar stool pulled up to the machine
		_cc0_prop("bar_chair_round_01", cpos, cyaw)
		_collider_cyl(cpos + Vector3(0, 0.4, 0), 0.25, 0.8)
	_collider_box(Vector3(x, 1.42, z), Vector3(0.68, 2.85, 0.72))


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


## Upholstered swivel chair built in a yawed sub-node; the backrest sits on
## the local +z side.
## A casino stool. This was three cylinders and a leaning box, which read as a
## primitive the moment it stood anywhere near the authored tables — so it is
## the real CC0 bar stool now. The material argument is kept because callers
## pass one, but the model brings its own.
func _chair_at(p: Vector3, yaw: float, _mat: Material) -> Node3D:
	var ch := _cc0_prop("bar_chair_round_01", p, yaw)
	_collider_cyl(p + Vector3(0, 0.38, 0), 0.25, 0.76)
	return ch


## Backlit SLOTS sign on the first solid wall of the room.
func _slots_sign() -> void:
	if _r(88) > 0.7:
		return
	for dir in 4:
		var info := WorldGen.edge_info(wseed, cell, dir, theme)
		if not info["wall"]:
			continue
		var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
		var n := -1.0 if (dir == 0 or dir == 2) else 1.0
		var inner := plane + n * (T * 0.5)
		var off := inner + n * 0.05
		var lb := Label3D.new()
		lb.text = "S L O T S"
		lb.font_size = 140
		lb.pixel_size = 0.0028
		lb.outline_size = 20
		lb.outline_modulate = Color(0.4, 0.05, 0.1)
		lb.modulate = Color(1.0, 0.78, 0.25)
		if dir < 2:
			lb.position = Vector3(off, 2.45, S / 2.0)
			lb.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
			_box(Vector3(off, 2.13, S / 2.0), Vector3(0.04, 0.05, 2.2), Mats.neon_amber(), false)
		else:
			lb.position = Vector3(S / 2.0, 2.45, off)
			lb.rotation.y = 0.0 if n > 0.0 else PI
			_box(Vector3(S / 2.0, 2.13, off), Vector3(2.2, 0.05, 0.04), Mats.neon_amber(), false)
		add_child(lb)
		return


const CASINO_NEON := [
	["C O C K T A I L S", Color(0.3, 1.0, 0.8)],
	["C A S H I E R", Color(1.0, 0.75, 0.2)],
	["B U F F E T", Color(1.0, 0.5, 0.2)],
	["K E N O", Color(0.55, 0.7, 1.0)],
	["R O O M S", Color(1.0, 0.4, 0.6)],
]


## Backlit neon lettering pointing at amenities that are never found.
func _casino_neon(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	var off := inner + n * 0.05
	var pick := int(_r(56 + dir) * (float(CASINO_NEON.size()) - 0.01))
	var txt: String = CASINO_NEON[pick][0]
	var colr: Color = CASINO_NEON[pick][1]
	var lb := Label3D.new()
	lb.text = txt
	lb.font_size = 120
	lb.pixel_size = 0.0026
	lb.outline_size = 18
	lb.outline_modulate = Color(colr.r * 0.22, colr.g * 0.22, colr.b * 0.22)
	lb.modulate = colr
	var tube := Mats.neon_col("c%d" % pick, colr)
	if dir < 2:
		lb.position = Vector3(off, 2.42, S / 2.0)
		lb.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
		_box(Vector3(off, 2.12, S / 2.0), Vector3(0.04, 0.045, 1.9), tube, false)
	else:
		lb.position = Vector3(S / 2.0, 2.42, off)
		lb.rotation.y = 0.0 if n > 0.0 else PI
		_box(Vector3(S / 2.0, 2.12, off), Vector3(1.9, 0.045, 0.04), tube, false)
	add_child(lb)
	var l := OmniLight3D.new()
	l.light_color = colr
	l.light_energy = 0.45
	l.omni_range = 4.0
	l.position = lb.position + Vector3(n * 0.35, -0.1, 0) if dir < 2 else lb.position + Vector3(0, -0.1, n * 0.35)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 14.0
	l.distance_fade_length = 6.0
	add_child(l)


## Bill-change machine humming against the wall, screen still lit.
func _change_machine(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	var along := 2.4 + 7.2 * _r(58 + dir)
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner + n * 0.30, 0, along)
		v.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
	else:
		v.position = Vector3(along, 0, inner + n * 0.30)
		v.rotation.y = 0.0 if n > 0.0 else PI
	add_child(v)
	# The authored cabinet carries its own CHANGE branding, coin tray and bill
	# slot, so the generated panel stack and Label3D marquee are gone with it.
	var unit := _attributed_prop_local(v, CHANGE_MACHINE_PATH,
		-CHANGE_MACHINE_CENTRE * CHANGE_MACHINE_SCALE, 0.0,
		Vector3.ONE * CHANGE_MACHINE_SCALE)
	if unit == null:
		_mrbox(v, Vector3(0, 0.95, 0), Vector3(0.75, 1.9, 0.5),
			Mats.slot_body(), 0.03)
		_mquad(v, Vector3(-0.12, 1.42, 0.253), Vector2(0.34, 0.24), Mats.ticker())
		_mbox(v, Vector3(0, 0.98, 0.26), Vector3(0.5, 0.05, 0.03), Mats.chrome())
		var lb := Label3D.new()
		lb.text = "CHANGE"
		lb.font_size = 72
		lb.pixel_size = 0.0022
		lb.modulate = Color(1.0, 0.72, 0.2)
		lb.position = Vector3(0, 1.75, 0.26)
		v.add_child(lb)
	else:
		v.set_meta("attributed_furnishing", "casino_change_machine")
	_collider_yaw_box(v.position + Vector3(0, 0.88, 0),
		Vector3(1.0, 1.76, 0.52), v.rotation.y)


## Blackjack table nobody deals anymore: baize, shoe, chips, three stools.
## The authored blackjack setpiece: semicircular table, felt, and six matching
## stools already arranged around the player arc. It replaces the generated
## table outright rather than standing beside it, so a floor never shows both
## versions of the same furniture.
func _blackjack_authored(p: Vector3, salt: int) -> bool:
	var yaw := _r(salt + 41) * TAU
	var pivot := _attributed_floor_prop(CASINO_BLACKJACK_PATH, p, yaw,
		CASINO_BLACKJACK_SCALE, Vector3.ZERO, "blackjack_table")
	if pivot == null:
		return false
	# Collide the table body only. The stools sit outside it and are thin
	# enough that walking between them reads as intended rather than blocked.
	_collider_yaw_box(p + Vector3(0, 0.45, 0), Vector3(2.45, 0.90, 1.15), yaw)
	return true


## Roulette: wheel head at one end, betting layout at the other, one piece.
func _roulette(p: Vector3, salt: int) -> void:
	var yaw := _r(salt) * TAU
	if _attributed_floor_prop(CASINO_ROULETTE_PATH, p, yaw,
			CASINO_ROULETTE_SCALE, CASINO_ROULETTE_CENTRE, "roulette_table") == null:
		return
	_collider_yaw_box(p + Vector3(0, 0.48, 0), Vector3(3.5, 0.96, 2.12), yaw)


## Every table is the authored one now. The generated felt-and-torus table below
## survives only as an import-failure fallback: two versions of the same
## furniture on one casino floor read as a bug, not as variety.
func _blackjack(p: Vector3, salt: int) -> void:
	if _blackjack_authored(p, salt):
		return
	_cyl(p + Vector3(0, 0.76, 0), 0.92, 0.06, Mats.felt_green(), false)
	var rim := MeshInstance3D.new()
	rim.mesh = TOR
	rim.material_override = Mats.darkwood()
	rim.position = p + Vector3(0, 0.775, 0)
	rim.scale = Vector3(1.24, 0.22, 1.24)
	add_child(rim)
	_cyl(p + Vector3(0, 0.38, 0), 0.15, 0.76, Mats.darkwood(), false)
	_cyl(p + Vector3(0, 0.05, 0), 0.48, 0.1, Mats.darkwood(), false)
	_collider_cyl(p + Vector3(0, 0.45, 0), 0.95, 0.9)
	# dealer side: chip rack and shoe
	_rbox(p + Vector3(0, 0.815, -0.45), Vector3(0.42, 0.035, 0.18), Mats.sign_housing(), 0.008, false)
	_rbox(p + Vector3(0.45, 0.83, -0.28), Vector3(0.16, 0.1, 0.24), Mats.body_black(), 0.02, false)
	# cards where the last hand stopped
	for i in 5:
		var ca := _box(p + Vector3((_r(salt + i) - 0.5) * 1.1, 0.795, (_r(salt + 9 + i) - 0.5) * 0.9),
			Vector3(0.063, 0.004, 0.088), Mats.paint_white(), false)
		ca.rotation.y = _r(salt + 17 + i) * TAU
	# chip stacks
	var chip_mats: Array = [Mats.red_knob(), Mats.body_black(), Mats.body_blue()]
	for i in 3:
		_cyl(p + Vector3(0.2 - 0.2 * float(i), 0.82, 0.32), 0.036,
			0.05 + 0.05 * _r(salt + 22 + i), chip_mats[i], false)
	# stools around the player arc
	for i in 3:
		var ang := PI * (0.3 + 0.2 * float(i)) + (_r(salt + 27 + i) - 0.5) * 0.2
		var cp := p + Vector3(cos(ang) * 1.4, 0, sin(ang) * 1.4)
		_chair_at(cp, atan2(cos(ang), sin(ang)) + (_r(salt + 31 + i) - 0.5) * 0.5, Mats.velvet())


## Brass posts and sagging red rope framing the grand hall's centre aisle.
## Two queue lines flanking the casino's main axis, laid out on the authored
## barrier's own 1.891m post pitch rather than a chosen one.
func _velvet_ropes() -> void:
	for xr in [3.0, 9.0]:
		for i in 4:
			_rope_barrier(Vector3(xr, 0,
				2.4 + ROPE_BARRIER_PITCH * (float(i) + 0.5)), PI / 2.0,
				"casino_queue_rope")


## One pair of brass stanchions and the swag between them. `yaw` turns the
## run: the authored unit lies along its local X.
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


## Landmark: the casino's forgotten ballroom. A clear marble dance floor,
## bandstand and perimeter supper tables make the whole 24m hall legible at a
## glance without filling its main circulation axis.
func _casino_ballroom() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# Inlaid dance floor and brass border.
	_box(c + Vector3(0, 0.012, 0.6), Vector3(10.2, 0.024, 8.2), Mats.marble_photo(), false)
	for sx in [-5.18, 5.18]:
		_box(c + Vector3(sx, 0.027, 0.6), Vector3(0.08, 0.03, 8.35), Mats.brass(), false)
	for sz in [-3.52, 4.72]:
		_box(c + Vector3(0, 0.027, sz), Vector3(10.35, 0.03, 0.08), Mats.brass(), false)
	# Low stage across the far side, curtain folds and an abandoned microphone.
	var stage := c + Vector3(0, 0, -8.0)
	_rbox(stage + Vector3(0, 0.22, 0), Vector3(9.2, 0.44, 2.7), Mats.darkwood(), 0.025)
	for i in 9:
		var x := -4.2 + 1.05 * float(i)
		_box(stage + Vector3(x, 2.45, -1.22), Vector3(0.58, 4.4, 0.10),
			Mats.velvet() if i % 2 == 0 else Mats.velvet2(), false)
	var mic := stage + Vector3(0.8, 0.44, 0.35)
	_cyl(mic + Vector3(0, 0.72, 0), 0.025, 1.44, Mats.chrome(), false)
	_sphere(mic + Vector3(0, 1.48, 0), 0.065, Mats.charcoal())
	_collider_box(stage + Vector3(0, 0.24, 0), Vector3(9.3, 0.48, 2.8))
	# Supper tables form a loose ring, leaving the dance floor empty.
	for i in 6:
		var ang := TAU * float(i) / 6.0 + PI / 6.0
		var tp := c + Vector3(cos(ang) * 8.1, 0, 0.9 + sin(ang) * 7.2)
		_cc0_prop("coffee_table_round_01", tp, ang)
		_collider_cyl(tp + Vector3(0, 0.26, 0), 0.67, 0.52)
		for j in 3:
			var ca := ang + TAU * float(j) / 3.0 + 0.35
			var cp := tp + Vector3(cos(ca) * 1.0, 0, sin(ca) * 1.0)
			_cc0_prop("bar_chair_round_01", cp, ca + PI)
			_collider_cyl(cp + Vector3(0, 0.38, 0), 0.25, 0.76)
	var title := Label3D.new()
	title.text = "THE SILVER ROOM"
	title.font_size = 140
	title.pixel_size = 0.003
	title.modulate = Color(1.0, 0.72, 0.22)
	title.position = stage + Vector3(0, 3.8, -1.30)
	add_child(title)


## Hotel corridor: a 3m lane of numbered, permanently locked rooms.  The
## guest-room strips behind the two walls are real reserved floor-plan volume:
## they may continue invisibly through several corridor cells, but no navigable
## opening can expose a door's back.  Actual room connections get a cased bay
## with return walls all the way to the canonical cell-edge doorway.
func _hallway() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x := cdir != 2
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	# A fitted runner, inset from the walls so a dark carpet border remains.
	var run := _mbox(self, _wp(o, Vector3(0, 0.013, 0), yw),
		Vector3(12.0, 0.026, 2.18), Mats.carpet_red())
	run.rotation.y = yw

	var side_data := []
	for si in 2:
		var side := -1.5 if si == 0 else 1.5
		var sdir := (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
		var info := WorldGen.edge_info(wseed, cell, sdir, theme)
		var bay := []
		if not info["wall"]:
			# Edge t runs in +x or +z.  Local corridor x runs toward -z after
			# the 90-degree rotation, hence the sign flip in a z-axis corridor.
			var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
			var bw := clampf(float(info["w"]) + 0.42, 2.05, 4.2)
			bay = [bt, bw]
		var doors := _hall_locked_doors(si, bay)
		_hall_wall_side(o, yw, side, doors, bay)
		side_data.append({"side": side, "doors": doors, "bay": bay})

	# A grandfather clock that no longer agrees with anything.  It is allowed
	# only on uninterrupted wall, never in an actual room bay or over a door.
	if _r(288) < 0.14:
		var csi := 0 if _r(290) < 0.5 else 1
		var ct := -3.9 + 7.8 * _r(289)
		if _hall_clear_at(ct, side_data[csi]["doors"], side_data[csi]["bay"], 0.62):
			var cside: float = side_data[csi]["side"] - signf(side_data[csi]["side"]) * 0.28
			var ckp := _wp(o, Vector3(ct, 0, cside), yw)
			var cky := yw + (0.0 if cside < 0.0 else PI)
			_cc0_prop("vintage_grandfather_clock_01", ckp, cky)
			_collider_yaw_box(ckp + Vector3(0, 1.1, 0), Vector3(0.66, 2.2, 0.46), cky)

	# Staggered sconces, moved to the nearest clean stretch when a generated bay
	# happens to claim their usual position.
	for si in 2:
		var sd: Dictionary = side_data[si]
		var t := _hall_sconce_t(si, sd["doors"], sd["bay"])
		if t > 90.0:
			continue
		var side: float = sd["side"] - signf(sd["side"]) * 0.14
		var wpp := _wp(o, Vector3(t, 0, side), yw)
		var outn := Vector3(0, 0, -signf(side)).rotated(Vector3.UP, yw)
		_box(wpp + Vector3(0, 1.78, 0), Vector3(0.1, 0.34, 0.1), Mats.brass(), false)
		_cyl(wpp + outn * 0.1 + Vector3(0, 1.86, 0), 0.10, 0.17, Mats.shade(), false)
		_sphere(wpp + outn * 0.1 + Vector3(0, 1.97, 0), 0.035, Mats.bulb())
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.70, 0.43)
		l.light_energy = 0.34
		l.omni_range = 3.8
		l.position = wpp + outn * 0.28 + Vector3(0, 1.95, 0)
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 14.0
		l.distance_fade_length = 6.0
		add_child(l)


## Candidate locked rooms on one side of the hotel corridor.  A real bay owns
## its stretch of wall and suppresses any decorative door that would overlap.
func _hall_locked_doors(si: int, bay: Array) -> Array:
	var doors := []
	for di in 3:
		var t := -3.2 + 3.2 * float(di)
		if _r(270 + si * 4 + di) >= 0.78:
			continue
		if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + 1.0:
			continue
		doors.append(t)
	return doors


func _hall_clear_at(t: float, doors: Array, bay: Array, clearance: float) -> bool:
	if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + clearance:
		return false
	for dt in doors:
		if absf(t - float(dt)) < 0.62 + clearance:
			return false
	return true


func _hall_sconce_t(si: int, doors: Array, bay: Array) -> float:
	var candidates := [-1.6, 1.6, -4.55, 4.55]
	if si == 1:
		candidates = [1.6, -1.6, 4.55, -4.55]
	for t in candidates:
		if _hall_clear_at(float(t), doors, bay, 0.48):
			return float(t)
	return 99.0


## One complete side of the corridor shell.  Walls run the full 12m and are
## cut only for a filled locked door or for a return-walled real room bay.
func _hall_wall_side(o: Vector3, yw: float, side: float, doors: Array, bay: Array) -> void:
	var segs := [[-6.0, 6.0]]
	for dt in doors:
		segs = _cut_seg(segs, float(dt) - 0.61, float(dt) + 0.61)
	if not bay.is_empty():
		segs = _cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_hall_wall_run(o, yw, side, float(sg[0]), float(sg[1]))
	for dt in doors:
		_hall_header(o, yw, side, float(dt), 1.22)
		_hall_door(o, yw, float(dt), side,
			275 + (0 if side < 0.0 else 8) + int(round((float(dt) + 3.2) / 3.2)))
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_hall_header(o, yw, side, bt, bw)
		_hall_open_casing(o, yw, side, bt, bw)
		_hall_bay_returns(o, yw, side, bt, bw)


func _hall_wall_run(o: Vector3, yw: float, side: float, a: float, b: float) -> void:
	var ln := b - a
	if ln < 0.04:
		return
	var c := (a + b) * 0.5
	var wc := _wp(o, Vector3(c, ceil_h / 2.0, side), yw)
	var wl := _mbox(self, wc, Vector3(ln, ceil_h, 0.16),
		Mats.hall_wallpaper_variant(_finish_variant()))
	wl.rotation.y = yw
	_collider_yaw_box(wc, Vector3(ln, ceil_h, 0.16), yw)
	var inn := side - signf(side) * 0.11
	for spec in [[0.075, 0.15, 0.055, Mats.darkwood()],
		[1.0, 0.08, 0.04, Mats.darkwood()],
		[ceil_h - 0.05, 0.1, 0.05, Mats.crown()]]:
		var tr := _mbox(self, _wp(o, Vector3(c, spec[0], inn), yw),
			Vector3(ln, spec[1], spec[2]), spec[3])
		tr.rotation.y = yw


func _hall_header(o: Vector3, yw: float, side: float, t: float, width: float) -> void:
	var hh := ceil_h - DOOR_TOP
	if hh <= 0.02:
		return
	var hp := _wp(o, Vector3(t, DOOR_TOP + hh * 0.5, side), yw)
	var hmesh := _mbox(self, hp, Vector3(width, hh, 0.16),
		Mats.hall_wallpaper_variant(_finish_variant()))
	hmesh.rotation.y = yw
	_collider_yaw_box(hp, Vector3(width, hh, 0.16), yw)


## The recess connecting the narrow lane to a real canonical edge doorway.
## Its returns also compartmentalize the inaccessible guest-room strip.
func _hall_bay_returns(o: Vector3, yw: float, side: float, t: float, width: float) -> void:
	var outer := signf(side) * (S * 0.5 - T)
	var depth := absf(outer - side)
	var dc := (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp := _wp(o, Vector3(edge, ceil_h * 0.5, dc), yw)
		var ret := _mbox(self, wp, Vector3(0.16, ceil_h, depth),
			Mats.hall_wallpaper_variant(_finish_variant()))
		ret.rotation.y = yw
		_collider_yaw_box(wp, Vector3(0.16, ceil_h, depth), yw)
	# Continue the runner into the doorway recess so it reads as intentional
	# circulation rather than a hole punched into the side of the corridor.
	var carpet := _mbox(self, _wp(o, Vector3(t, 0.014, dc), yw),
		Vector3(width, 0.028, depth), Mats.carpet_red())
	carpet.rotation.y = yw


func _hall_open_casing(o: Vector3, yw: float, side: float, t: float, width: float) -> void:
	var inn := side - signf(side) * 0.11
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb := _mbox(self, _wp(o, Vector3(edge, DOOR_TOP * 0.5, inn), yw),
			Vector3(0.11, DOOR_TOP, 0.25), Mats.darkwood())
		jamb.rotation.y = yw
	var head := _mbox(self, _wp(o, Vector3(t, DOOR_TOP + 0.06, inn), yw),
		Vector3(width + 0.16, 0.12, 0.25), Mats.darkwood())
	head.rotation.y = yw


func _hall_door(o: Vector3, yw: float, t: float, side: float, salt: int) -> void:
	var inn := side - signf(side) * 0.11
	var v := Node3D.new()
	v.position = _wp(o, Vector3(t, 0, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	add_child(v)
	# A real slab in a real opening: rounded edges, deep jambs, panel moulding,
	# hinges and hardware.  Its collider seals the reserved room volume behind.
	_mrbox(v, Vector3(0, 1.10, 0.0), Vector3(1.04, 2.2, 0.075), Mats.wood_door(), 0.018)
	for py in [0.58, 1.35]:
		_mrbox(v, Vector3(0, py, 0.043), Vector3(0.72, 0.46, 0.018), Mats.darkwood(), 0.008)
		_mrbox(v, Vector3(0, py, 0.054), Vector3(0.58, 0.33, 0.012), Mats.wood_door(), 0.006)
	_mbox(v, Vector3(-0.575, 1.11, 0.0), Vector3(0.11, 2.24, 0.28), Mats.darkwood())
	_mbox(v, Vector3(0.575, 1.11, 0.0), Vector3(0.11, 2.24, 0.28), Mats.darkwood())
	_mbox(v, Vector3(0, 2.25, 0.0), Vector3(1.26, 0.12, 0.28), Mats.darkwood())
	for hy in [0.45, 1.7]:
		_mbox(v, Vector3(-0.515, hy, 0.055), Vector3(0.035, 0.12, 0.025), Mats.brass())
	_mbox(v, Vector3(0.36, 1.02, 0.058), Vector3(0.12, 0.22, 0.025), Mats.brass())
	_msphere(v, Vector3(0.36, 1.02, 0.095), 0.045, Mats.brass())
	_msphere(v, Vector3(0, 1.66, 0.09), 0.025, Mats.brass())
	_collider_yaw_box(_wp(o, Vector3(t, 1.1, inn), yw), Vector3(1.06, 2.2, 0.11), yw)
	var num := Label3D.new()
	num.text = "%d%02d" % [10 + WorldGen.h(wseed, cell.x + int(t * 3.0), cell.y, salt) % 20,
		WorldGen.h(wseed, cell.x, cell.y + int(t * 5.0), salt + 1) % 100]
	num.font_size = 44
	num.pixel_size = 0.0018
	num.modulate = Color(0.85, 0.7, 0.4)
	num.position = Vector3(0, 1.98, 0.09)
	v.add_child(num)
	if _r(salt + 2) < 0.22:
		_mcyl(v, Vector3(0.72, 0.025, 0.35), 0.16, 0.03, Mats.chrome())
		_msphere(v, Vector3(0.72, 0.075, 0.35), 0.09, Mats.chrome())


# --- vegas: lounge -----------------------------------------------------------

func _lounge() -> void:
	# a pair of real Victorian sofas facing off over a real coffee table
	_cc0_prop("sofa_03", Vector3(6, 0, 4.6), 0.0)
	_collider_box(Vector3(6, 0.55, 4.6), Vector3(2.75, 1.1, 0.95))
	_cc0_prop("sofa_03", Vector3(6, 0, 7.4), PI)
	_collider_box(Vector3(6, 0.55, 7.4), Vector3(2.75, 1.1, 0.95))
	_cc0_prop("CoffeeTable_01", Vector3(6, 0, 6), 0.0)
	_collider_box(Vector3(6, 0.27, 6), Vector3(1.55, 0.54, 1.0))
	if _r(26) < 0.55:
		var ay := -PI * 0.75 + (_r(27) - 0.5) * 0.4
		_cc0_prop("ArmChair_01", Vector3(8.9, 0, 8.7), ay)
		_collider_yaw_box(Vector3(8.9, 0.55, 8.7), Vector3(0.9, 1.1, 0.8), ay)
		if _r(28) < 0.5:
			_cc0_prop("Ottoman_01", Vector3(8.1, 0, 7.8), ay + (_r(29) - 0.5) * 0.8)
			_collider_box(Vector3(8.1, 0.3, 7.8), Vector3(0.9, 0.62, 0.65))
	var lp := Vector3(3.4, 0, 6.0)
	_cyl(lp + Vector3(0, 0.8, 0), 0.035, 1.6, Mats.brass(), false)
	_cyl(lp + Vector3(0, 1.68, 0), 0.21, 0.28, Mats.shade(), false)
	_sphere(lp + Vector3(0, 1.55, 0), 0.07, Mats.bulb())
	_collider_cyl(lp + Vector3(0, 0.9, 0), 0.24, 1.8)
	if _r(25) < 0.5:
		_planter(Vector3(9.2, 0, 9.2))
	# muffled PA muzak drifting from the lounge ceiling
	var mz := AudioStreamPlayer3D.new()
	mz.stream = SoundBank.muzak()
	mz.unit_size = 4.0
	mz.max_distance = 24.0
	mz.volume_db = -14.0
	mz.bus = "Hall"
	mz.position = Vector3(S / 2.0, ceil_h - 0.3, S / 2.0)
	add_child(mz)
	mz.ready.connect(func(): mz.play(randf() * 11.0))


## Was seven rounded boxes and two tilted cushions, which read as upholstered
## geometry rather than as a sofa. `sofa_03` was already in the project and
## already used elsewhere, so this was only ever a missing call.
func _sofa(center: Vector3, face: float) -> void:
	var yaw := 0.0 if face > 0.0 else PI
	_cc0_prop("sofa_03", center, yaw)
	_collider_box(center + Vector3(0, 0.55, 0), Vector3(2.74, 1.10, 0.95))


func _planter(p: Vector3) -> void:
	# real potted plants; the office gets the sadder, squatter one
	var mname := "potted_plant_02" if theme == 1 else "potted_plant_01"
	_cc0_prop(mname, p, _r(23) * TAU)
	_collider_cyl(p + Vector3(0, 0.5, 0), 0.32, 1.0)


## A room-service cart abandoned after the glasses were poured. Its low,
## asymmetric silhouette gives otherwise empty casino rooms a lived-in past.
func _casino_service_cart(p: Vector3, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = _r(salt) * TAU
	add_child(v)
	_mrbox(v, Vector3(0, 0.76, 0), Vector3(1.05, 0.07, 0.56), Mats.darkwood(), 0.025)
	_mrbox(v, Vector3(0, 0.28, 0), Vector3(0.92, 0.045, 0.46), Mats.darkwood(), 0.018)
	for sx in [-0.44, 0.44]:
		for sz in [-0.20, 0.20]:
			_mcyl(v, Vector3(sx, 0.40, sz), 0.018, 0.72, Mats.brass())
			_mcyl(v, Vector3(sx, 0.055, sz), 0.055, 0.05, Mats.charcoal())
	# Two glasses, one bottle, and a plate left slightly off square.
	for gx in [-0.22, 0.10]:
		_mcyl(v, Vector3(gx, 0.84, -0.06), 0.045, 0.13, Mats.glass_tint())
		_mcyl(v, Vector3(gx, 0.92, -0.06), 0.065, 0.018, Mats.glass_tint())
	_mcyl(v, Vector3(0.32, 0.91, 0.08), 0.045, 0.28, Mats.glass_tint())
	_mcyl(v, Vector3(-0.08, 0.805, 0.12), 0.18, 0.025, Mats.crown())
	_collider_yaw_box(p + Vector3(0, 0.42, 0), Vector3(1.08, 0.84, 0.6), v.rotation.y)


## Archive boxes and loose forms occupy a corner of some otherwise empty
## offices. The pile is broad enough to read, low enough not to become a wall.
func _office_floor_files(p: Vector3, salt: int) -> void:
	for i in 3:
		var v := Node3D.new()
		var ox := -0.30 if i != 1 else 0.30
		v.position = p + Vector3(ox, 0, -0.14)
		v.rotation.y = (_r(salt + i) - 0.5) * 0.34
		add_child(v)
		var y := 0.70 if i == 2 else 0.24
		_mrbox(v, Vector3(0, y, 0), Vector3(0.58, 0.46, 0.48), Mats.box_white(), 0.015)
		_mbox(v, Vector3(0, y + 0.235, 0), Vector3(0.5, 0.018, 0.4), Mats.paint_white())
	_asy_papers(p + Vector3(0.6, 0, 0.35), salt + 8, 6)
	_collider_box(p + Vector3(0, 0.42, 0), Vector3(1.25, 0.84, 1.0))


# --- office props ------------------------------------------------------------

const OFFICE_CORRIDOR_LABELS := ["ACCOUNTS", "ARCHIVES", "CONFERENCE B",
	"FACILITIES", "HUMAN RESOURCES", "PROCESSING", "RECORDS", "SUPPLY"]


## One or two real split-system indoor units per generated office room. The
## room anchor owns the whole set, including merged multi-cell rooms, so the
## same room never receives a duplicate from each member chunk.
func _office_air_conditioners(split: Array) -> void:
	var candidates := []
	var wall_off := 0.165
	var mount_y := ceil_h - 0.34
	var directions := [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
	]
	for member in _room_members():
		var base := Vector3(float(member.x - cell.x) * S, 0.0,
			float(member.y - cell.y) * S)
		for dir in 4:
			var neighbour: Vector2i = member + directions[dir]
			if WorldGen.room_id(wseed, neighbour) == room_root:
				continue
			var info := WorldGen.edge_info(wseed, member, dir, theme)
			var suspended := bool(info["full_open"])
			# Two edge-biased bays leave the centre available for pictures,
			# clocks and door signage while still allowing a pair in a large room.
			for slot in 2:
				var along := (4.0 if slot == 0 else 8.0) if suspended \
					else (3.0 if slot == 0 else 9.0)
				var partition_hits_wall := not split.is_empty() \
					and ((bool(split[0]) and dir < 2) \
						or (not bool(split[0]) and dir >= 2))
				if partition_hits_wall \
						and absf(along - float(split[1])) < 0.82:
					continue
				var p: Vector3
				match dir:
					0:
						p = base + Vector3(S - T - wall_off, mount_y, along)
					1:
						p = base + Vector3(T + wall_off, mount_y, along)
					2:
						p = base + Vector3(along, mount_y, S - T - wall_off)
					_:
						p = base + Vector3(along, mount_y, T + wall_off)
				if suspended:
					# A room with four fully-open edges has no wall at all. Pull
					# the mount into that open-plan bay and give it a ceiling-
					# supported backplate below instead of leaving it floating.
					match dir:
						0:
							p.x = base.x + S - 2.2
						1:
							p.x = base.x + 2.2
						2:
							p.z = base.z + S - 2.2
						_:
							p.z = base.z + 2.2
				var decor_busy := WorldGen.r01(wseed, member.x, member.y,
					1040 + dir) < _wall_art_chance() \
					or WorldGen.r01(wseed, member.x, member.y, 40 + dir) < 0.58
				var score := posmod(WorldGen.h(wseed, member.x * 5 + slot,
					member.y * 7 - dir, 1880), 100000)
				if decor_busy:
					score += 100000
				# A solid wall is preferred. A cased doorway wall is a safe
				# fallback because the unit sits above the 2.25m header.
				if not bool(info["wall"]):
					score += 400000
				if suspended:
					score += 400000
				candidates.append({
					"member": member, "dir": dir, "slot": slot,
					"position": p, "score": score, "suspended": suspended,
				})
	if candidates.is_empty():
		return
	var desired := 2 if room_n >= 2 \
		or WorldGen.r01(wseed, room_root.x, room_root.y, 1881) < 0.28 else 1
	var selected := []
	while selected.size() < desired and not candidates.is_empty():
		var best_idx := 0
		var best_score := 1 << 30
		for i in candidates.size():
			var candidate: Dictionary = candidates[i]
			var score: int = int(candidate["score"])
			if not selected.is_empty():
				var first: Dictionary = selected[0]
				if candidate["member"] == first["member"] \
						and int(candidate["dir"]) == int(first["dir"]):
					score += 220000
			if score < best_score:
				best_score = score
				best_idx = i
		selected.append(candidates.pop_at(best_idx))
	for candidate in selected:
		var p: Vector3 = candidate["position"]
		var dir: int = int(candidate["dir"])
		var pivot := _furnishing_pivot(p, _wall_facing(dir),
			"office_air_conditioner", false)
		var unit := _attributed_prop_local(pivot,
			OFFICE_AIR_CONDITIONER_PATH,
			-OFFICE_AIR_CONDITIONER_CENTRE * OFFICE_AIR_CONDITIONER_SCALE,
			0.0, Vector3.ONE * OFFICE_AIR_CONDITIONER_SCALE)
		if unit == null:
			pivot.get_parent().remove_child(pivot)
			pivot.free()
			continue
		pivot.set_meta("attributed_furnishing", "office_air_conditioner")
		pivot.set_meta("office_ac_mount", true)
		pivot.set_meta("office_ac_member", candidate["member"])
		pivot.set_meta("office_ac_dir", dir)
		pivot.set_meta("office_ac_slot", int(candidate["slot"]))
		pivot.set_meta("office_ac_expected", desired)
		pivot.set_meta("office_ac_suspended", bool(candidate["suspended"]))
		unit.set_meta("authored_model", "office_air_conditioner")
		if bool(candidate["suspended"]):
			_mrbox(pivot, Vector3(0, 0, -0.205),
				Vector3(1.46, 0.52, 0.10), Mats.metal_gray(), 0.025)
			var bracket_h := 0.08
			for bx in [-0.56, 0.56]:
				_mcyl(pivot, Vector3(bx, 0.26 + bracket_h * 0.5, -0.205),
					0.014, bracket_h, Mats.metal_gray())


## A continuous corporate corridor with real plan depth.  Locked doors seal
## inaccessible office/service volumes behind the side walls; genuine graph
## connections open into return-walled vestibules that reach the canonical
## cell-edge doorway.  Nothing ends short of a boundary or shifts between
## adjacent corridor cells, so the player can never walk around a facade.
func _office_corridor() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x := cdir != 2
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var lane_half := 1.85
	# A quieter carpet-tile lane makes the circulation spine readable and masks
	# the floor seam where vestibules branch toward actual rooms.
	var lane := _mbox(self, _wp(o, Vector3(0, 0.012, 0), yw),
		Vector3(S, 0.024, lane_half * 2.0 - 0.18), Mats.office_lane_carpet())
	lane.rotation.y = yw

	var side_data := []
	for si in 2:
		var side := -lane_half if si == 0 else lane_half
		var sdir := (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
		var info := WorldGen.edge_info(wseed, cell, sdir, theme)
		var bay := []
		if not info["wall"]:
			# Edge t runs in world +x/+z. Local corridor x points toward -z after
			# the quarter-turn used by a z-axis corridor.
			var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
			var bw := clampf(float(info["w"]) + 0.38, 1.95, 3.15)
			bay = [bt, bw]
		var doors := _office_corridor_doors(si, bay)
		_office_corridor_wall_side(o, yw, side, doors, bay)
		_office_corridor_utilities(o, yw, side, si, doors, bay)
		side_data.append({"side": side, "doors": doors, "bay": bay})

	if _r(254) < 0.5:
		_office_dept_sign(along_x)
	# A wall directory or clock gives the lane a destination and is placed only
	# on structure that is not claimed by a locked door or a real vestibule.
	if _r(260) < 0.62:
		var dsi := 0 if _r(261) < 0.5 else 1
		var dt := _office_corridor_clear_t(dsi, side_data[dsi]["doors"],
			side_data[dsi]["bay"])
		if dt < 90.0:
			_office_corridor_directory(o, yw, float(side_data[dsi]["side"]), dt)
	# Period CCTV hardware makes the sealed office frontage feel monitored and
	# inhabited. It is wall-mounted above head height, so it cannot compromise
	# the corridor or a vestibule arrival.
	if _r(262) < 0.42:
		var csi := 0 if _r(263) < 0.5 else 1
		var cside := float(side_data[csi]["side"])
		var ct := -4.55 if _r(264) < 0.5 else 4.55
		var cp := _wp(o, Vector3(ct, 2.45, cside), yw)
		_security_camera(cp, yw + PI if cside > 0.0 else yw)
	# a wet floor sign guarding nothing, halfway down the lane
	if _r(256) < 0.16:
		var t2 := 2.5 + 7.0 * _r(258)
		var sp2 := _wp(o, Vector3(t2 - 6.0, 0, (_r(257) - 0.5) * 0.7), yw)
		_cc0_prop("WetFloorSign_01", sp2, _r(259) * TAU)
		_collider_box(sp2 + Vector3(0, 0.3, 0), Vector3(0.35, 0.6, 0.35))


## Locked private offices on one side of a corridor. A real vestibule owns
## its whole wall interval and suppresses any facade that would overlap it.
func _office_corridor_doors(si: int, bay: Array) -> Array:
	var doors := []
	for di in 3:
		var t := -3.55 + 3.55 * float(di)
		if _r(270 + si * 5 + di) >= 0.68:
			continue
		if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + 0.92:
			continue
		doors.append(t)
	# Long stretches with no real connection still need at least one piece of
	# evidence that the inaccessible strip is occupied office volume.
	if doors.is_empty() and bay.is_empty():
		doors.append([-3.55, 0.0, 3.55][int(_r(279 + si) * 2.99)])
	return doors


func _office_corridor_clear(t: float, doors: Array, bay: Array, clearance: float) -> bool:
	if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + clearance:
		return false
	for dt in doors:
		if absf(t - float(dt)) < 0.66 + clearance:
			return false
	return true


func _office_corridor_clear_t(si: int, doors: Array, bay: Array) -> float:
	var candidates := [-1.75, 1.75, -4.65, 4.65]
	if si == 1:
		candidates = [1.75, -1.75, 4.65, -4.65]
	for t in candidates:
		if _office_corridor_clear(float(t), doors, bay, 0.62):
			return float(t)
	return 99.0


## Services belong on the corridor shell the player can actually see, not on
## the canonical cell boundary hidden behind the inaccessible office strip.
## A receptacle occupies a clear wall run; a switch sits beside a sealed door
## or real vestibule, just as it would in a maintained office building.
func _office_corridor_utilities(o: Vector3, yw: float, side: float, si: int,
		doors: Array, bay: Array) -> void:
	var face := side - signf(side) * 0.078
	var facing := yw + (PI if side > 0.0 else 0.0)
	var base := 1480 + si * 23
	if _r(base) < 0.82:
		var outlet_t := _office_corridor_clear_t(si, doors, bay)
		if outlet_t < 90.0:
			_wall_utility_mount(
				_wp(o, Vector3(outlet_t, 0.31, face), yw),
				facing, 0.31, false)
	if _r(base + 1) >= 0.88:
		return
	var opening_t := 99.0
	var opening_half := 0.0
	if not doors.is_empty():
		opening_t = float(doors[0])
		opening_half = 0.63
	elif not bay.is_empty():
		opening_t = float(bay[0])
		opening_half = float(bay[1]) * 0.5
	if opening_t > 90.0:
		return
	var switch_t := opening_t + opening_half + 0.25
	if switch_t > 5.72:
		switch_t = opening_t - opening_half - 0.25
	if switch_t < -5.72 \
			or not _office_corridor_clear(switch_t, doors, bay, 0.08):
		return
	_wall_utility_mount(
		_wp(o, Vector3(switch_t, 1.12, face), yw),
		facing, 1.12, true)


## One complete side wall, cut only by a sealed door or by a real vestibule.
func _office_corridor_wall_side(o: Vector3, yw: float, side: float,
		doors: Array, bay: Array) -> void:
	var segs := [[-6.0, 6.0]]
	for dt in doors:
		segs = _cut_seg(segs, float(dt) - 0.63, float(dt) + 0.63)
	if not bay.is_empty():
		segs = _cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_office_corridor_wall_run(o, yw, side, float(sg[0]), float(sg[1]))
	for di in doors.size():
		var dt := float(doors[di])
		_office_corridor_header(o, yw, side, dt, 1.26)
		_office_corridor_door(o, yw, dt, side,
			285 + (0 if side < 0.0 else 12) + di)
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_office_corridor_header(o, yw, side, bt, bw)
		_office_corridor_open_casing(o, yw, side, bt, bw)
		_office_corridor_bay_returns(o, yw, side, bt, bw)


func _office_corridor_wall_run(o: Vector3, yw: float, side: float,
		a: float, b: float) -> void:
	var ln := b - a
	if ln < 0.04:
		return
	var c := (a + b) * 0.5
	var wc := _wp(o, Vector3(c, ceil_h * 0.5, side), yw)
	var wall := _mbox(self, wc, Vector3(ln, ceil_h, 0.15),
		Mats.office_wall_variant(_finish_variant()))
	wall.rotation.y = yw
	_collider_yaw_box(wc, Vector3(ln, ceil_h, 0.15), yw)
	var inn := side - signf(side) * 0.105
	var base := _mbox(self, _wp(o, Vector3(c, 0.055, inn), yw),
		Vector3(ln, 0.11, 0.045), Mats.base_green())
	base.rotation.y = yw


func _office_corridor_header(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var hh := ceil_h - DOOR_TOP
	if hh <= 0.02:
		return
	var hp := _wp(o, Vector3(t, DOOR_TOP + hh * 0.5, side), yw)
	var head := _mbox(self, hp, Vector3(width, hh, 0.15),
		Mats.office_wall_variant(_finish_variant()))
	head.rotation.y = yw
	_collider_yaw_box(hp, Vector3(width, hh, 0.15), yw)


## Return walls connect the corridor shell to the actual cell-edge doorway and
## close the inaccessible strips on both sides of the vestibule.
func _office_corridor_bay_returns(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var outer := signf(side) * (S * 0.5 - T)
	var depth := absf(outer - side)
	var dc := (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp := _wp(o, Vector3(edge, ceil_h * 0.5, dc), yw)
		var ret := _mbox(self, wp, Vector3(0.15, ceil_h, depth),
			Mats.office_wall_variant(_finish_variant()))
		ret.rotation.y = yw
		_collider_yaw_box(wp, Vector3(0.15, ceil_h, depth), yw)
		# Baseboard on the vestibule face of each return.
		var inward := 0.105 if edge < t else -0.105
		var bp := _wp(o, Vector3(edge + inward, 0.055, dc), yw)
		var base := _mbox(self, bp, Vector3(0.045, 0.11, depth), Mats.base_green())
		base.rotation.y = yw
	var carpet := _mbox(self, _wp(o, Vector3(t, 0.013, dc), yw),
		Vector3(width, 0.026, depth), Mats.office_lane_carpet())
	carpet.rotation.y = yw


func _office_corridor_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn := side - signf(side) * 0.105
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb := _mbox(self, _wp(o, Vector3(edge, DOOR_TOP * 0.5, inn), yw),
			Vector3(0.11, DOOR_TOP, 0.24), Mats.paint_white())
		jamb.rotation.y = yw
	var head := _mbox(self, _wp(o, Vector3(t, DOOR_TOP + 0.06, inn), yw),
		Vector3(width + 0.16, 0.12, 0.24), Mats.paint_white())
	head.rotation.y = yw


## A sealed office door installed in a real wall opening. The collider and
## opaque privacy glass make the facade honest even though the room is not
## generated; deep jambs make the wall thickness visible at grazing angles.
func _office_corridor_door(o: Vector3, yw: float, t: float,
		side: float, salt: int) -> void:
	var inn := side - signf(side) * 0.105
	var v := Node3D.new()
	v.position = _wp(o, Vector3(t, 0, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	add_child(v)
	var service := _r(salt) < 0.24
	var door_mat: Material = Mats.metal_gray() if service else Mats.wood_door()
	_mrbox(v, Vector3(0, 1.09, 0), Vector3(1.04, 2.18, 0.07), door_mat, 0.012)
	_mbox(v, Vector3(-0.575, 1.11, 0), Vector3(0.11, 2.23, 0.25), Mats.paint_white())
	_mbox(v, Vector3(0.575, 1.11, 0), Vector3(0.11, 2.23, 0.25), Mats.paint_white())
	_mbox(v, Vector3(0, 2.25, 0), Vector3(1.26, 0.12, 0.25), Mats.paint_white())
	if not service and _r(salt + 1) < 0.62:
		# Milky vision panel with a slim aluminium bead.
		_mrbox(v, Vector3(0, 1.58, 0.041), Vector3(0.43, 0.5, 0.014),
			Mats.office_privacy_glass(), 0.01)
		for sx in [-0.235, 0.235]:
			_mbox(v, Vector3(sx, 1.58, 0.052), Vector3(0.025, 0.55, 0.018), Mats.chrome())
		for sy in [1.295, 1.865]:
			_mbox(v, Vector3(0, sy, 0.052), Vector3(0.495, 0.025, 0.018), Mats.chrome())
	# Lever, latch plate, and a dead access-control reader.
	_mrbox(v, Vector3(0.36, 1.02, 0.06), Vector3(0.13, 0.2, 0.025), Mats.chrome(), 0.008)
	_msphere(v, Vector3(0.36, 1.02, 0.092), 0.035, Mats.chrome())
	_mrbox(v, Vector3(0.24, 1.02, 0.1), Vector3(0.25, 0.035, 0.035), Mats.chrome(), 0.012)
	_mrbox(v, Vector3(0.72, 1.28, 0.07), Vector3(0.12, 0.2, 0.035), Mats.charcoal(), 0.008)
	_mbox(v, Vector3(0.72, 1.34, 0.091), Vector3(0.055, 0.025, 0.008), Mats.lamp_red())
	_collider_yaw_box(_wp(o, Vector3(t, 1.09, inn), yw),
		Vector3(1.06, 2.18, 0.11), yw)
	var plate := _mrbox(v, Vector3(-0.78, 1.58, 0.075),
		Vector3(0.34, 0.24, 0.025), Mats.paint_white(), 0.006)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lb := Label3D.new()
	lb.text = "ELECTRICAL" if service else OFFICE_CORRIDOR_LABELS[
		WorldGen.h(wseed, cell.x + int(t * 5.0), cell.y, salt + 2) % OFFICE_CORRIDOR_LABELS.size()]
	lb.font_size = 34
	lb.pixel_size = 0.00125
	lb.width = 245.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.modulate = Color(0.06, 0.18, 0.12)
	lb.position = Vector3(-0.78, 1.58, 0.09)
	v.add_child(lb)


func _office_corridor_directory(o: Vector3, yw: float, side: float, t: float) -> void:
	var inn := side - signf(side) * 0.095
	var v := Node3D.new()
	v.position = _wp(o, Vector3(t, 1.55, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	add_child(v)
	_mrbox(v, Vector3(0, 0, 0), Vector3(0.76, 0.88, 0.045), Mats.charcoal(), 0.008)
	_mquad(v, Vector3(0, 0, 0.026), Vector2(0.69, 0.81), Mats.paint_white())
	var title := Label3D.new()
	title.text = "DIRECTORY"
	title.font_size = 50
	title.pixel_size = 0.0016
	title.modulate = Color(0.055, 0.19, 0.12)
	title.position = Vector3(0, 0.25, 0.035)
	v.add_child(title)
	var body_label := Label3D.new()
	body_label.text = "PROCESSING  4E\nARCHIVES      4F\nWELLNESS      4G\nSTAIRS        <--"
	body_label.font_size = 30
	body_label.pixel_size = 0.00145
	body_label.modulate = Color(0.12, 0.2, 0.16)
	body_label.position = Vector3(0, -0.09, 0.035)
	v.add_child(body_label)


## MDR-style desk cluster: cross divider, four desks facing outward, each
## with a CRT terminal, keyboard and chair. The room's reason to exist.
func _office_cubicles() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var span := _room_span()
	var centres := [c]
	if span.x > 12.1 and span.y > 12.1:
		centres = [c + Vector3(-5.4, 0, -5.4), c + Vector3(5.4, 0, -5.4),
			c + Vector3(-5.4, 0, 5.4), c + Vector3(5.4, 0, 5.4)]
	elif span.x > 12.1:
		centres = [c + Vector3(-5.6, 0, 0), c + Vector3(5.6, 0, 0)]
	elif span.y > 12.1:
		centres = [c + Vector3(0, 0, -5.6), c + Vector3(0, 0, 5.6)]
	for ci in centres.size():
		_office_cubicle_cluster(centres[ci], ci * 12)
	var snd := OfficeSounds.new()
	snd.position = c + Vector3(0, 1.2, 0)
	add_child(snd)


## One four-person work island. Large merged rooms arrange several of these
## from their true span rather than leaving three quarters of the floor empty.
func _office_cubicle_cluster(c: Vector3, qi_base: int) -> void:
	# cross divider
	_box(c + Vector3(0, 0.675, 0), Vector3(3.6, 1.35, 0.08), Mats.divider_gray())
	_box(c + Vector3(0, 0.675, 0), Vector3(0.08, 1.35, 3.6), Mats.divider_gray())
	# white cap rails
	_box(c + Vector3(0, 1.36, 0), Vector3(3.7, 0.04, 0.12), Mats.paint_white(), false)
	_box(c + Vector3(0, 1.36, 0), Vector3(0.12, 0.04, 3.7), Mats.paint_white(), false)
	var qi := 0
	for q in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		_office_desk(c + Vector3(q.x * 1.5, 0, 0), Vector2(0, q.y), qi_base + qi)
		qi += 1
	# waste bin
	var bin_side := -1.0 if int(qi_base / 12) % 2 == 1 else 1.0
	_cyl(c + Vector3(1.7 * bin_side, 0.18, 1.7), 0.14, 0.36, Mats.charcoal())


func _office_desk(c: Vector3, d: Vector2, qi := 0) -> void:
	# One top-level pivot makes doorway clearance atomic: the desk, terminal,
	# keyboard and loose items are culled together or survive together.
	var workstation := Node3D.new()
	workstation.set_meta("office_workstation", true)
	add_child(workstation)
	var dv := Vector3(d.x, 0, d.y)
	var deskc := c + dv * 1.05
	var top_size := Vector3(0.8, 0.035, 1.5) if d.x != 0.0 else Vector3(1.5, 0.035, 0.8)
	_mrbox(workstation, deskc + Vector3(0, 0.73, 0), top_size, Mats.desk_white(), 0.012)
	# side panel legs
	var leg_off := Vector3(0, 0, 0.68) if d.x != 0.0 else Vector3(0.68, 0, 0)
	var leg_size := Vector3(0.74, 0.71, 0.04) if d.x != 0.0 else Vector3(0.04, 0.71, 0.74)
	_mrbox(workstation, deskc + leg_off + Vector3(0, 0.355, 0), leg_size, Mats.desk_white(), 0.008)
	_mrbox(workstation, deskc - leg_off + Vector3(0, 0.355, 0), leg_size, Mats.desk_white(), 0.008)
	_collider_box(deskc + Vector3(0, 0.4, 0), top_size * Vector3(1.0, 1.0, 1.0) + Vector3(0, 0.77, 0))
	# Terminal at the inner edge, screen facing the worker (outward). Every
	# office desk uses the authored IBM 3278/VT100-style unit. It arrives as one
	# complete, non-interactive display-and-keyboard assembly, replacing the old
	# generated E-query terminal and its separate keyboard.
	var yaw := atan2(dv.x, dv.z)
	_office_ibm_terminal(workstation, deskc, yaw, qi)
	# Real paper and stationery silhouettes replace the old anonymous white
	# slabs on selected desks, while leaving room for the terminal and keyboard.
	var clutter := _r(59 + qi)
	# The authored terminal is much wider than the old generated CRT. Keep
	# loose stationery beyond its housing instead of letting pencils emerge
	# through the side, while retaining enough desk-edge clearance.
	var side_dir := Vector3(cos(yaw), 0, -sin(yaw))
	var desk_item: Node3D
	if clutter < 0.22:
		desk_item = _cc0_prop("clipboard",
			deskc + side_dir * 0.54 + Vector3(0, 0.75, 0),
			_r(62 + qi) * TAU, 0.82)
	elif clutter < 0.48:
		desk_item = _cc0_prop("office_notepads",
			deskc + side_dir * 0.55 + Vector3(0, 0.752, 0),
			yaw + (_r(63 + qi) - 0.5) * 0.14, 0.42)
	elif clutter < 0.62:
		desk_item = _cc0_prop("stationery_supplies",
			deskc + side_dir * 0.52 + Vector3(0, 0.78, 0),
			yaw + PI / 2.0 + (_r(64 + qi) - 0.5) * 0.08, 0.28)
	if desk_item != null:
		_adopt_local(workstation, desk_item)
	# The phone sits on the opposite side of the terminal from the stationery,
	# so the two never share the same corner of the desk.
	_office_desk_phone(workstation, deskc, yaw, qi)
	# chair facing the desk, never perfectly parked
	_office_task_chair(c + dv * 1.95 + Vector3((_r(97 + qi) - 0.5) * 0.2, 0, 0),
		yaw + (_r(87 + qi) - 0.5) * 0.5)


## A desk phone at the worker's elbow.
##
## This is the only place the CC BY-NC office phone enters the game. Delete this
## function and its one call site in `_office_desk` and the noncommercial
## obligation goes with it; nothing else references the model.
func _office_desk_phone(workstation: Node3D, deskc: Vector3, yaw: float,
		qi: int) -> void:
	if _r(1260 + qi) >= 0.38:
		return
	var side := Vector3(cos(yaw), 0, -sin(yaw)) * -0.52
	# The model's keypad faces its own -Z, so it needs the desk's yaw directly:
	# adding PI turned the dial away from whoever sat there.
	_attributed_floor_prop(OFFICE_PHONE_PATH,
		deskc + side + Vector3(0, 0.7475, 0),
		yaw + (_r(1270 + qi) - 0.5) * 0.5, 1.0, OFFICE_PHONE_CENTRE,
		"office_phone", workstation)


## The authored IBM 3278 set down on a desk top. Its screen faces model +X, so
## a quarter turn off the desk's own yaw points it at whoever sat there. The
## source scene left a `Lamp` node behind; it is dropped on the way in.
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


## A row of payphones on a concourse wall, each on its own dark backboard.
## The authored handset is re-origined on its own mounting plane, so it takes a
## wall point and a facing and nothing else.
func _mall_payphone_bank(dir: int, count: int) -> void:
	var facing := _wall_facing(dir)
	# Wall art mounts on the centre of a run, so a bank placed there ends up
	# shoulder to shoulder with a poster. Sit it well off to one side.
	var along := 3.3 if _r(1641 + dir) < 0.5 else 8.7
	var origin := _wall_pt(dir, along, 0.0)
	var pv := Node3D.new()
	pv.position = origin
	pv.rotation.y = facing
	add_child(pv)
	# The authored housing is 0.74m tall about its own mounting plane, so a
	# 1.38m mount cut it in half on the mall's 1.21m brass rail — the same
	# fault the wall art was moved for. Lift it so the bottom of the housing
	# clears the rail by the shared margin instead of straddling it.
	var mount := 1.38
	var band := _wall_band_top()
	if band > 0.0:
		mount = maxf(mount,
			band + WALL_BAND_CLEAR + MALL_PAYPHONE_DROP * MALL_PAYPHONE_SCALE)
	var span := 1.0
	for ph in count:
		var px := (float(ph) - float(count - 1) * 0.5) * span
		var authored := _attributed_prop_local(pv, MALL_PAYPHONE_PATH,
			Vector3(px, mount, 0.0), 0.0,
			Vector3.ONE * MALL_PAYPHONE_SCALE)
		if authored != null:
			# The authored housing is its own backboard; the charcoal panel the
			# generated bank needed would only read as a slab behind it.
			authored.set_meta("authored_model", "payphone")
		else:
			_mbox(pv, Vector3(px, 1.45, -0.25), Vector3(0.72, 0.85, 0.5),
				Mats.charcoal())
			_mbox(pv, Vector3(px, 1.38, 0.08), Vector3(0.30, 0.44, 0.14),
				Mats.metal_gray())
			_mbox(pv, Vector3(px - 0.11, 1.38, 0.15),
				Vector3(0.05, 0.24, 0.05), Mats.charcoal())
	# The authored housing stands 0.16m off the wall, not the half metre the
	# generated boxes needed; a deeper collider would stop the player short of
	# a wall they can see is flat.
	var forward := Vector3(sin(facing), 0, cos(facing))
	_collider_yaw_box(origin + forward * 0.09 + Vector3(0, mount, 0),
		Vector3(span * float(count) - 0.1, 0.78, 0.20), facing)


## Freestanding concourse directory. The authored board is a readable front face
## with no base and blank sides, so the plinth and edge frame around it are
## generated — they carry the collision and hide the edges the source never
## modelled. The board's own five floors of listings do the rest.
func _mall_directory_pylon(p: Vector3, yaw: float) -> void:
	var b0 := body.get_child_count()
	var pylon := _furnishing_pivot(p, yaw, "mall_directory")
	var board := _attributed_prop_local(pylon, MALL_DIRECTORY_PATH,
		Vector3(-MALL_DIRECTORY_CENTRE.x * MALL_DIRECTORY_SCALE, 0.42,
			-MALL_DIRECTORY_CENTRE.z * MALL_DIRECTORY_SCALE - 0.055),
		0.0, Vector3.ONE * MALL_DIRECTORY_SCALE)
	if board == null:
		# generated lightbox, as before the authored board existed
		_mrbox(pylon, Vector3(0, 1.15, 0), Vector3(1.35, 2.3, 0.22),
			Mats.mall_trim(), 0.04)
		_mbox(pylon, Vector3(0, 1.32, -0.115), Vector3(1.1, 1.55, 0.02),
			Mats.mall_sign_face())
	else:
		board.set_meta("authored_model", "mall_directory")
		# plinth, then a steel edge frame closing the blank sides and back
		_mrbox(pylon, Vector3(0, 0.21, 0), Vector3(1.12, 0.42, 0.30),
			Mats.mall_trim(), 0.03)
		_mrbox(pylon, Vector3(0, 1.30, 0.085), Vector3(1.06, 1.83, 0.09),
			Mats.mall_trim(), 0.02)
		for fx in [-0.515, 0.515]:
			_mbox(pylon, Vector3(fx, 1.30, 0.02), Vector3(0.05, 1.83, 0.16),
				Mats.mall_trim())
		_mbox(pylon, Vector3(0, 2.20, 0.02), Vector3(1.11, 0.06, 0.16),
			Mats.mall_trim())
		var dl := Label3D.new()
		dl.text = "DIRECTORY"
		dl.font_size = 52
		dl.pixel_size = 0.0019
		dl.modulate = Color(0.32, 0.28, 0.24)
		dl.position = Vector3(0, 2.31, -0.07)
		pylon.add_child(dl)
	_collider_yaw_box(p + Vector3(0, 1.15, 0), Vector3(1.2, 2.3, 0.34), yaw)
	_bind_furnishing_colliders(pylon, b0)


## Bank of steel filing cabinets, one drawer always left open.
func _filing_bank(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	var along := S / 2.0 + (_r(59 + dir) - 0.5) * 4.0
	var count := 3 + int(_r(60 + dir) * 1.99)
	var open_i := int(_r(61 + dir) * float(count) * 0.99)
	var open_j := int(_r(62 + dir) * 3.99)
	for i in count:
		var t := along + (float(i) - float(count - 1) / 2.0) * 0.5
		var v := Node3D.new()
		if dir < 2:
			v.position = Vector3(inner + n * 0.31, 0, t)
			v.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
		else:
			v.position = Vector3(t, 0, inner + n * 0.31)
			v.rotation.y = 0.0 if n > 0.0 else PI
		add_child(v)
		_mrbox(v, Vector3(0, 0.66, 0), Vector3(0.46, 1.32, 0.6), Mats.metal_gray(), 0.015)
		for j in 4:
			var dy := 0.18 + 0.31 * float(j)
			_mbox(v, Vector3(0, dy + 0.14, 0.302), Vector3(0.4, 0.27, 0.012), Mats.divider_gray())
			_mbox(v, Vector3(0, dy + 0.245, 0.315), Vector3(0.13, 0.022, 0.014), Mats.chrome())
			if i == open_i and j == open_j:
				_mbox(v, Vector3(0, dy + 0.13, 0.46), Vector3(0.4, 0.24, 0.32), Mats.metal_gray())
				_mbox(v, Vector3(0, dy + 0.23, 0.46), Vector3(0.34, 0.02, 0.26), Mats.box_white())
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
	"THE BUILDING THANKS YOU", "PLEASE CONSERVE LIGHT", "TIDY DESK, TIDY MIND"]


## Framed motivational poster; the motivation has long since left.
func _office_poster(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(63 + dir) - 0.5) * 5.0
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner + n * 0.03, 1.7, along)
		v.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
	else:
		v.position = Vector3(along, 1.7, inner + n * 0.03)
		v.rotation.y = 0.0 if n > 0.0 else PI
	v.rotation.z = (_r(64 + dir) - 0.5) * 0.04
	add_child(v)
	_mbox(v, Vector3(0, 0, -0.008), Vector3(0.68, 0.94, 0.016), Mats.charcoal())
	_mquad(v, Vector3(0, 0, 0.004), Vector2(0.62, 0.88), Mats.paint_white())
	var hd := Label3D.new()
	hd.text = OFFICE_POSTERS[int(_r(65 + dir) * (float(OFFICE_POSTERS.size()) - 0.01))]
	hd.font_size = 30
	hd.pixel_size = 0.0016
	hd.width = 380.0
	hd.autowrap_mode = TextServer.AUTOWRAP_WORD
	hd.modulate = Color(0.1, 0.25, 0.16)
	hd.position = Vector3(0, 0.22, 0.01)
	v.add_child(hd)
	var bd := Label3D.new()
	bd.text = "a reminder from Facilities"
	bd.font_size = 16
	bd.pixel_size = 0.0014
	bd.modulate = Color(0.45, 0.48, 0.45)
	bd.position = Vector3(0, -0.3, 0.01)
	v.add_child(bd)


const OFFICE_ZONE_DEPTS := [
	["PROCESSING", "ACCOUNTS", "DATA SERVICES"],
	["ARCHIVES", "RECORDS", "DOCUMENT CONTROL"],
	["WELLNESS", "BREAK ROOMS", "HUMAN RESOURCES"],
]


## White acrylic department sign hung over the corridor.
func _office_dept_sign(along_x: bool) -> void:
	var v := Node3D.new()
	v.position = Vector3(S / 2.0, 2.55, S / 2.0)
	v.rotation.y = PI / 2.0 if along_x else 0.0
	add_child(v)
	var rod_h := ceil_h - 2.55 - 0.19
	for sx in [-0.55, 0.55]:
		_mcyl(v, Vector3(sx, 0.19 + rod_h / 2.0, 0), 0.012, rod_h, Mats.metal_gray())
	_mrbox(v, Vector3.ZERO, Vector3(1.6, 0.38, 0.05), Mats.paint_white(), 0.01)
	var zone := WorldGen.macro_zone(wseed, cell, theme)
	var labels: Array = OFFICE_ZONE_DEPTS[zone]
	for sside in [-1.0, 1.0]:
		var lb := Label3D.new()
		lb.text = labels[int(_r(255) * (float(labels.size()) - 0.01))]
		lb.font_size = 60
		lb.pixel_size = 0.0022
		lb.modulate = Color(0.08, 0.22, 0.14)
		lb.position = Vector3(0, 0, sside * 0.035)
		lb.rotation.y = 0.0 if sside > 0.0 else PI
		v.add_child(lb)


## Authored multifunction office printer, shared by open and small offices.
func _copier(p: Vector3, salt: int) -> void:
	var yaw := (_r(salt) - 0.5) * 0.3
	var body0 := body.get_child_count()
	var printer := _attributed_floor_prop(OFFICE_PRINTER_PATH, p, yaw,
		OFFICE_PRINTER_SCALE, OFFICE_PRINTER_CENTRE, "office_printer")
	if printer == null:
		return
	_collider_yaw_box(p + Vector3(0, 0.676, 0),
		Vector3(1.21, 1.352, 0.70), yaw)
	_bind_furnishing_colliders(printer, body0)


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


## DEC VT100 lookalike, built in local space facing +Z under one pivot so the
## random desk-jitter yaw can never shear the screen out of its housing.
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
	readout.outline_size = 1
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


## Audit hook: Label3D has no scissor rectangle, so protect the physical CRT
## with the selected font's real metrics whenever terminal copy changes.
func terminal_readout_violations() -> int:
	var bad := 0
	for node in find_children("*", "Label3D", true, false):
		var readout := node as Label3D
		if not readout.has_meta("terminal_readout"):
			continue
		var lines := readout.text.split("\n")
		var text_width_px := 0.0
		for line in lines:
			text_width_px = maxf(text_width_px, readout.font.get_string_size(
				line, HORIZONTAL_ALIGNMENT_LEFT, -1, readout.font_size).x)
		var text_height_px := readout.font.get_height(readout.font_size) * float(lines.size())
		if text_width_px * readout.pixel_size > TERMINAL_SCREEN_SIZE.x * 0.92 \
				or text_height_px * readout.pixel_size > TERMINAL_SCREEN_SIZE.y * 0.90 \
				or readout.width * readout.pixel_size > TERMINAL_SCREEN_SIZE.x * 0.94 \
				or readout.double_sided:
			bad += 1
	return bad


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
	return bad


func school_fixture_integrity_audit() -> Dictionary:
	var report := {"carts": 0, "stalls": 0, "violations": 0}
	if theme != 6:
		return report
	for node in find_children("*", "Node3D", true, false):
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


func _office_storage() -> void:
	# The floor-standing copier, parked against a wall with its finisher trays
	# out. It is the one machine everyone walked to, so the storage room is
	# where it ends up when the floor is stripped.
	if _r(1250) < 0.62:
		for d in 4:
			if not _solid_wall(d):
				continue
			var pp := _wall_pt(d, 9.1, 0.45)
			var pyaw := _wall_facing(d)
			if _attributed_floor_prop(OFFICE_PRINTER_PATH, pp, pyaw,
					OFFICE_PRINTER_SCALE, OFFICE_PRINTER_CENTRE,
					"office_printer") != null:
				_collider_yaw_box(pp + Vector3(0, 0.68, 0),
					Vector3(1.22, 1.36, 0.72), pyaw)
			break
	_shelf_unit(Vector3(3.5, 0, 6.0), false, 30)
	if _r(33) < 0.55:
		# a real steel rack (model ships 10x life size — scaled to 2.1m)
		_cc0_prop("steel_frame_shelves_01", Vector3(8.5, 0, 6.0), PI / 2.0, 0.1)
		_collider_box(Vector3(8.5, 1.1, 6.0), Vector3(0.6, 2.2, 1.15))
	else:
		_shelf_unit(Vector3(8.5, 0, 6.0), false, 34)
	if _r(36) < 0.45:
		var dy := (_r(37) - 0.5) * 0.2
		_cc0_prop("drawer_cabinet", Vector3(2.2, 0, 1.1), dy)
		_collider_yaw_box(Vector3(2.2, 0.95, 1.1), Vector3(1.2, 1.9, 0.55), dy)
	if _r(38) < 0.4:
		_shelf_unit(Vector3(6.0, 0, 2.0), true, 39)


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
				var authored := theme == 1 and _office_shelf_box(rack,
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
func _office_shelf_box(parent: Node3D, pos: Vector3, yaw: float,
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


func _office_break() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# round table with four chairs
	_cyl(c + Vector3(0, 0.72, 0), 0.55, 0.05, Mats.desk_white(), false)
	_cyl(c + Vector3(0, 0.36, 0), 0.06, 0.72, Mats.metal_gray(), false)
	_cyl(c + Vector3(0, 0.02, 0), 0.3, 0.04, Mats.metal_gray(), false)
	_collider_cyl(c + Vector3(0, 0.4, 0), 0.6, 0.8)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + 0.4
		var cp := c + Vector3(cos(ang) * 1.15, 0, sin(ang) * 1.15)
		_office_task_chair(cp, ang + PI / 2.0 + (_r(98 + i) - 0.5) * 0.7)
	# counter along the south wall with a coffee maker
	_rbox(Vector3(4.5, 0.45, 0.75), Vector3(3.0, 0.9, 0.6), Mats.desk_white(), 0.015)
	_rbox(Vector3(3.6, 1.08, 0.75), Vector3(0.3, 0.36, 0.3), Mats.charcoal(), 0.02, false)
	_box(Vector3(3.6, 1.02, 0.92), Vector3(0.05, 0.02, 0.04), Mats.lamp_red(), false)
	# water cooler in the corner
	var wc := Vector3(10.5, 0, 1.0)
	var wc_body0 := body.get_child_count()
	var cooler := _attributed_floor_prop(OFFICE_WATER_COOLER_PATH, wc, PI,
		OFFICE_WATER_COOLER_SCALE, OFFICE_WATER_COOLER_CENTRE,
		"office_water_cooler")
	if cooler != null:
		_collider_box(wc + Vector3(0, 0.69, 0), Vector3(0.34, 1.38, 0.36))
		_bind_furnishing_colliders(cooler, wc_body0)
	# the catering cart that never gets restocked
	if _r(103) < 0.5:
		var cy2 := PI / 2.0 + (_r(104) - 0.5) * 0.3
		_cc0_prop("CoffeeCart_01", Vector3(10.4, 0, 8.6), cy2)
		_collider_yaw_box(Vector3(10.4, 0.85, 8.6), Vector3(2.2, 1.7, 1.1), cy2)
	# a dead CRT television on a low table, facing the chairs
	if _r(106) < 0.4:
		var tvp := Vector3(1.6, 0, 9.8)
		_cc0_prop("coffee_table_round_01", tvp, 0.0)
		_collider_cyl(tvp + Vector3(0, 0.25, 0), 0.66, 0.5)
		_cc0_prop("television_02", tvp + Vector3(0, 0.49, 0), PI * 0.78 + (_r(107) - 0.5) * 0.3)


## Landmark: a boardroom far larger than the company could have needed. The
## single long table and repeated empty chairs create a strong navigational
## silhouette; the live wall display makes it visible through several doors.
func _office_boardroom() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var ln := 11.5
	_rbox(c + Vector3(0, 0.75, 0), Vector3(ln, 0.10, 2.15), Mats.desk_white(), 0.045)
	for x in [-4.7, -1.6, 1.6, 4.7]:
		_rbox(c + Vector3(x, 0.38, 0), Vector3(0.18, 0.72, 1.65), Mats.metal_gray(), 0.025)
	_collider_box(c + Vector3(0, 0.48, 0), Vector3(ln, 0.96, 2.2))
	for side in [-1.0, 1.0]:
		for i in 8:
			var x := -4.9 + 1.4 * float(i)
			var cp := c + Vector3(x, 0, side * 1.75)
			_office_task_chair(cp, 0.0 if side < 0.0 else PI)
	# One chair sits conspicuously far from the head of the table.
	_office_task_chair(c + Vector3(7.0, 0, 0), -PI / 2.0 + 0.18)
	# Dark wall-sized presentation display with a stubborn status line.
	_box(c + Vector3(-8.9, 1.75, 0), Vector3(0.10, 2.3, 5.8), Mats.charcoal(), false)
	var screen := Label3D.new()
	screen.text = "QUARTER  48\nATTENDANCE  0"
	screen.font_size = 92
	screen.pixel_size = 0.0028
	screen.modulate = Color(0.42, 1.0, 0.66)
	screen.position = c + Vector3(-8.82, 1.78, 0)
	screen.rotation.y = PI / 2.0
	add_child(screen)
	# Real models break up the procedural table geometry at the room edges.
	_cc0_prop("drawer_cabinet", c + Vector3(8.8, 0, -7.7), -PI / 2.0)
	_collider_yaw_box(c + Vector3(8.8, 0.95, -7.7), Vector3(1.15, 1.9, 0.52), -PI / 2.0)
	for p in [c + Vector3(-8.5, 0, -8.0), c + Vector3(8.5, 0, 8.0)]:
		_cc0_prop("potted_plant_02", p, _r(118 + int(p.x)) * TAU)
		_collider_cyl(p + Vector3(0, 0.42, 0), 0.34, 0.84)
	var snd := OfficeSounds.new()
	snd.position = c + Vector3(0, 1.2, 0)
	add_child(snd)


# --- the Annex ---------------------------------------------------------------

## Theme 2 is almost prop-free. Its identity comes from continuous carpet, a
## low drop ceiling and wall-like interruptions, plus one rare furniture hoard
## reserved for the largest rooms.
func _annex_floor_ceiling() -> void:
	_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S),
		Mats.annex_carpet())
	_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S),
		Mats.annex_ceiling())


func _annex_lighting() -> void:
	var is_spawn := cell == Vector2i.ZERO
	var axis := WorldGen.annex_corridor_axis(wseed, cell)
	var dim_zone := WorldGen.annex_dim_zone(wseed, cell)
	var light_gap := WorldGen.annex_light_gap(wseed, cell)
	# The Annex no longer draws switched-off fixtures. Every troffer that exists
	# is steadily illuminated; darkness comes from sparse placement and weaker
	# local throw instead.
	var pmat := Mats.annex_panel()
	set_meta("annex_dim_zone", dim_zone)
	set_meta("annex_light_gap", light_gap)
	# Corridor fixtures form an unmistakable line into the distance. Rooms use
	# a four-panel grid. Dim zones reduce that to one or two fixtures; some
	# macro-blocks omit fixtures entirely for a genuine low-light stretch.
	var fixtures: Array[Vector2] = []
	if light_gap:
		fixtures = []
	elif dim_zone:
		if axis == 1 or axis == 2:
			fixtures = [Vector2(6.0, 6.0)]
		elif axis == 3:
			fixtures = [Vector2(3.0, 6.0), Vector2(9.0, 6.0)]
		else:
			fixtures = [Vector2(6.0, 6.0)]
	elif axis == 1:
		fixtures = [Vector2(2.0, 6.0), Vector2(6.0, 6.0), Vector2(10.0, 6.0)]
	elif axis == 2:
		fixtures = [Vector2(6.0, 2.0), Vector2(6.0, 6.0), Vector2(6.0, 10.0)]
	elif axis == 3:
		fixtures = [Vector2(3.0, 6.0), Vector2(9.0, 6.0),
			Vector2(6.0, 3.0), Vector2(6.0, 9.0)]
	else:
		fixtures = [Vector2(3.0, 3.0), Vector2(9.0, 3.0),
			Vector2(3.0, 9.0), Vector2(9.0, 9.0)]
	var built_fixtures := 0
	for pt in fixtures:
		var at := Vector3(
			_annex_tile_center(pt.x, cell.x),
			0.0,
			_annex_tile_center(pt.y, cell.y))
		if not _annex_fixture_clear(at):
			continue
		_annex_troffer(at, pmat)
		built_fixtures += 1
	var effective_gap := light_gap or built_fixtures == 0
	set_meta("annex_light_gap", effective_gap)
	set_meta("annex_ceiling_fixture_count", built_fixtures)
	if effective_gap:
		return
	var light := _make_main_light(false, pmat, 0.24 if dim_zone else 1.42)
	light.light_color = Color(1.0, 0.91, 0.64)
	light.omni_range = 7.4 if dim_zone else 12.8
	light.position = Vector3(S / 2.0, ceil_h - 0.46, S / 2.0)
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 25.0
	light.distance_fade_length = 9.0
	add_child(light)


## Snap a local fixture coordinate to the centre of the world-space drop-
## ceiling grid. Empirical in-game projection of the 2x2 source makes each
## visible tile exactly ANNEX_CEILING_TILE square.
func _annex_tile_center(local_v: float, cell_axis: int) -> float:
	var world_v := float(cell_axis) * S + local_v
	# The imported ceiling map's visible grid intersections land at the former
	# half-tile phase. Whole multiples are the centres of the rendered squares.
	var snapped := roundf(world_v / ANNEX_CEILING_TILE) * ANNEX_CEILING_TILE
	return snapped - float(cell_axis) * S


## One recessed fixture replaces one complete 1.2m ceiling tile. The outer
## frame is the exact tile footprint; the glowing lens is inset within it.
func _annex_troffer(at: Vector3, pmat: Material) -> void:
	var frame := Mats.annex_trim()
	var border := 0.035
	var lens_size := ANNEX_CEILING_TILE - border * 2.0
	var lens := _box(
		Vector3(at.x, ceil_h - 0.055, at.z),
		Vector3(lens_size, 0.05, lens_size), pmat, false)
	lens.set_meta("annex_ceiling_light_size", ANNEX_CEILING_TILE)
	lens.set_meta("annex_ceiling_light_on", true)
	var world_x := float(cell.x) * S + at.x
	var world_z := float(cell.y) * S + at.z
	var grid_error := maxf(
		absf(world_x - roundf(world_x / ANNEX_CEILING_TILE) * ANNEX_CEILING_TILE),
		absf(world_z - roundf(world_z / ANNEX_CEILING_TILE) * ANNEX_CEILING_TILE))
	lens.set_meta("annex_ceiling_light_grid_error", grid_error)
	var edge := ANNEX_CEILING_TILE * 0.5 - border * 0.5
	_box(Vector3(at.x, ceil_h - 0.02, at.z - edge),
		Vector3(ANNEX_CEILING_TILE, 0.035, border), frame, false)
	_box(Vector3(at.x, ceil_h - 0.02, at.z + edge),
		Vector3(ANNEX_CEILING_TILE, 0.035, border), frame, false)
	_box(Vector3(at.x - edge, ceil_h - 0.02, at.z),
		Vector3(border, 0.035, lens_size), frame, false)
	_box(Vector3(at.x + edge, ceil_h - 0.02, at.z),
		Vector3(border, 0.035, lens_size), frame, false)


## Reserve a small margin around each complete ceiling tile. The rectangles are
## populated by perimeter walls, corridor shells and full-height prop-pass
## architecture before lighting is generated.
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
func annex_fixture_obstruction_violations() -> int:
	if theme != 2:
		return 0
	var bad := 0
	for node in find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("annex_ceiling_light_size") \
				and not _annex_fixture_clear((node as MeshInstance3D).position):
			bad += 1
	return bad


func _annex_register_ceiling_obstruction(p: Vector3, width: float,
		depth: float, yaw: float, top: float) -> void:
	if theme != 2 or top < ceil_h - 0.03:
		return
	var cs := absf(cos(yaw))
	var sn := absf(sin(yaw))
	var half_x := (cs * width + sn * depth) * 0.5
	var half_z := (sn * width + cs * depth) * 0.5
	_annex_ceiling_obstructions.append(Rect2(
		Vector2(p.x - half_x, p.z - half_z),
		Vector2(half_x * 2.0, half_z * 2.0)))


## A wall-like slab standing inside the approach zone of a generated doorway
## reads, from the other side of the opening, as a second offset doorframe with
## a light-leak gap beside the jamb — an "indented doorway". The route
## clearance system only protects the walk path, not the sightline, so test
## the slab's footprint against a zone projected into the room from every
## opening on this cell's edges and refuse to stand there. Columns are exempt:
## a small pier near a doorway reads as architecture, not as a broken frame.
func _annex_blocks_doorway(p: Vector3, yaw: float,
		width: float, depth: float) -> bool:
	const ZONE_DEPTH := 3.2
	const ZONE_MARGIN := 0.5
	var cs := absf(cos(yaw))
	var sn := absf(sin(yaw))
	var hx := (cs * width + sn * depth) * 0.5
	var hz := (sn * width + cs * depth) * 0.5
	var lo := Vector2(p.x - hx, p.z - hz)
	var hi := Vector2(p.x + hx, p.z + hz)
	for dir in 4:
		var info := WorldGen.edge_info(wseed, cell, dir, theme)
		if bool(info["wall"]):
			continue
		var a := float(info["t"]) - float(info["w"]) * 0.5 - ZONE_MARGIN
		var b := float(info["t"]) + float(info["w"]) * 0.5 + ZONE_MARGIN
		var zone_lo: Vector2
		var zone_hi: Vector2
		match dir:
			0:
				zone_lo = Vector2(S - ZONE_DEPTH, a)
				zone_hi = Vector2(S, b)
			1:
				zone_lo = Vector2(0.0, a)
				zone_hi = Vector2(ZONE_DEPTH, b)
			2:
				zone_lo = Vector2(a, S - ZONE_DEPTH)
				zone_hi = Vector2(b, S)
			3:
				zone_lo = Vector2(a, 0.0)
				zone_hi = Vector2(b, ZONE_DEPTH)
		if lo.x < zone_hi.x and hi.x > zone_lo.x \
				and lo.y < zone_hi.y and hi.y > zone_lo.y:
			return true
	return false


## Add one architectural slab as an atomic assembly. It is generated in the
## prop pass so the established doorway-clearance system can remove the whole
## slab, including its collider, if a seed places it across a route.
func _annex_block(p: Vector3, yaw: float, width: float, depth: float,
		height: float, kind: String) -> void:
	if kind == "annex_wall" or kind == "annex_half_wall":
		depth = maxf(depth, ANNEX_WALL_T)
	if kind != "annex_column" and _annex_blocks_doorway(p, yaw, width, depth):
		return
	var first := body.get_child_count()
	var pivot := _furnishing_pivot(p, yaw, kind, false)
	pivot.set_meta("annex_architecture", kind)
	if kind == "annex_wall" or kind == "annex_half_wall":
		pivot.set_meta("annex_partition_thickness", depth)
	_mbox(pivot, Vector3(0, height * 0.5, 0),
		Vector3(width, height, depth), Mats.annex_wall_variant(_finish_variant()))
	_annex_register_ceiling_obstruction(p, width, depth, yaw, height)
	if height < ceil_h - 0.2:
		_mbox(pivot, Vector3(0, height + 0.025, 0),
			Vector3(width + 0.08, 0.05, depth + 0.08), Mats.annex_trim())
	_collider_yaw_box(p + Vector3(0, height * 0.5, 0),
		Vector3(width, height, depth), yaw)
	_bind_furnishing_colliders(pivot, first)


func _annex_room_member_architecture() -> void:
	if room_n < 2 or portal_dest >= 0:
		return
	var c := Vector3(S / 2.0, 0, S / 2.0)
	if style == WorldGen.ANNEX_LOBBY and _r(523) < 0.72:
		var side_x := 3.2 if _r(524) < 0.5 else 8.8
		var side_z := 3.2 if _r(525) < 0.5 else 8.8
		_annex_block(Vector3(side_x, 0, side_z), 0.0,
			1.12, 1.12, ceil_h, "annex_column")
	elif style == WorldGen.ANNEX_OPEN and _r(526) < 0.24:
		_annex_block(c + Vector3((_r(527) - 0.5) * 4.4, 0,
			(_r(528) - 0.5) * 4.4), 0.0,
			0.94, 0.94, ceil_h, "annex_column")


func _annex_open() -> void:
	if cell == Vector2i.ZERO or portal_dest >= 0:
		return
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var roll := _r(520)
	# Open rooms stay empty often enough to preserve the level's restraint.
	# The other branches use the references' broad central wall masses, short
	# half-height dividers and occasional offset supports. A large pier leaves
	# multiple routes around it and reads as architecture, not a generic prop.
	if roll < 0.32:
		return
	if roll < 0.58:
		var mass_yaw := PI * 0.5 if _r(521) < 0.5 else 0.0
		var mass_width := lerpf(2.25, 3.15, _r(522))
		var mass_depth := lerpf(1.10, 1.75, _r(523))
		_annex_block(c + Vector3((_r(524) - 0.5) * 2.8, 0,
			(_r(525) - 0.5) * 2.8), mass_yaw,
			mass_width, mass_depth, ceil_h, "annex_wall_mass")
	elif roll < 0.84:
		var yaw := PI / 2.0 if _r(529) < 0.5 else 0.0
		var side := -1.0 if _r(530) < 0.5 else 1.0
		_annex_block(_wp(c, Vector3(0, 0, side * 2.2), yaw), yaw,
			4.8, 0.24, 1.05, "annex_half_wall")
	elif roll < 0.96 and room_n >= 2:
		var along_x := _r(531) < 0.5
		for side in [-1.0, 1.0]:
			var p := c + (Vector3(side * 2.4, 0, 0) if along_x \
				else Vector3(0, 0, side * 2.4))
			_annex_block(p, 0.0, 1.04, 1.04, ceil_h, "annex_column")
	else:
		_annex_block(c + Vector3((_r(532) - 0.5) * 2.0, 0,
			(_r(533) - 0.5) * 2.0), 0.0,
			1.08, 1.08, ceil_h, "annex_column")


func _annex_maze() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var turn := PI / 2.0 if _r(530) < 0.5 else 0.0
	var side := -1.0 if _r(531) < 0.5 else 1.0
	_annex_block(_wp(c, Vector3(-1.45, 0, side * 1.25), turn), turn,
		4.6, 0.22, ceil_h, "annex_wall")
	if room_n >= 2:
		_annex_block(_wp(c, Vector3(2.0, 0, -side * 1.55), turn + PI / 2.0),
			turn + PI / 2.0, 3.4, 0.22, ceil_h, "annex_wall")


func _annex_long() -> void:
	var span := _room_span()
	var along_x := span.x >= span.y
	var yaw := 0.0 if along_x else PI / 2.0
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var side := -1.0 if _r(540) < 0.5 else 1.0
	# A shallow offset slab hides one side of the next opening while preserving
	# the long axis, producing the distant, ambiguous views in the reference.
	_annex_block(_wp(c, Vector3(0, 0, side * 2.15), yaw), yaw,
		5.4, 0.22, ceil_h, "annex_wall")


func _annex_quiet() -> void:
	# The room is the prop. Keeping this branch explicit protects its emptiness.
	pass


## Sparse evidence that the Annex once had an ordinary use. Most rooms remain
## empty; the selected rooms get one readable idea rather than a grab-bag of
## unrelated props. Large chair heaps are limited to genuinely broad spaces.
func _annex_lived_in_dressing() -> void:
	if portal_dest >= 0 or style == WorldGen.ANNEX_PASSAGE:
		return
	if _r(1620) < 0.12:
		_annex_air_conditioner(1621)
	if cell == Vector2i.ZERO:
		return
	var roll := _r(1630)
	# Quiet rooms stay the sparsest branch even after the lived-in pass.
	if style == WorldGen.ANNEX_QUIET:
		if roll < 0.12:
			_annex_chair_cluster(1, 1631, false)
		elif roll < 0.20:
			_annex_loose_boxes(1, 1632)
		elif roll < 0.30:
			_annex_school_chair_scatter(1, 1641)
		return
	if roll < 0.16:
		_annex_shelving(1633)
	elif roll < 0.32:
		_annex_loose_boxes(1 + int(_r(1634) * 2.99), 1635)
	elif roll < 0.48:
		_annex_chair_cluster(1, 1636, false)
	elif roll < 0.60:
		_annex_chair_cluster(2 + int(_r(1637) * 2.99), 1638, false)
	elif roll < 0.72:
		_annex_school_chair_scatter(
			1 + int(_r(1642) * 2.99), 1643)
	elif roll < 0.78 and room_n >= 2:
		_annex_chair_cluster(8 + int(_r(1639) * 2.99), 1640, true)
	# The Annex's broad openings mean its doorway clearance zones cover most
	# of a cell, so roughly half of everything rolled above is culled before
	# the player sees it. A second independent group lets a room read as used
	# rather than as one object in an empty box; the placement helpers still
	# refuse occupied spots and the cull still protects every route.
	var second := _r(1650)
	if second < 0.14:
		_annex_shelving(1651)
	elif second < 0.28:
		_annex_loose_boxes(1 + int(_r(1652) * 1.99), 1653)
	elif second < 0.40:
		_annex_chair_cluster(1, 1654, false)
	elif second < 0.46:
		_annex_school_chair_scatter(1 + int(_r(1655) * 1.99), 1656)


func _annex_wall_floor_point(dir: int, along: float, off: float,
		y := 0.0) -> Vector3:
	var plane := S if dir == 0 or dir == 2 else 0.0
	var inward := -1.0 if dir == 0 or dir == 2 else 1.0
	var face := plane + inward * (ANNEX_WALL_T * 0.5 + off)
	return Vector3(face, y, along) if dir < 2 \
		else Vector3(along, y, face)


func _annex_wall_has_utility(dir: int) -> bool:
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("wall_utility_dir") \
				and int(node.get_meta("wall_utility_dir")) == dir:
			return true
	return false


func _annex_pick_solid_wall(salt: int, avoid_utilities := false) -> int:
	var start := posmod(WorldGen.h(wseed, cell.x, cell.y, salt), 4)
	for step in 4:
		var dir := (start + step) % 4
		if not bool(WorldGen.edge_info(wseed, cell, dir, theme)["wall"]):
			continue
		if avoid_utilities and _annex_wall_has_utility(dir):
			continue
		return dir
	return -1


func _annex_air_conditioner(salt: int) -> void:
	var dir := _annex_pick_solid_wall(salt, false)
	if dir < 0:
		return
	var along := lerpf(3.0, 9.0, _r(salt + 1))
	var p := _annex_wall_floor_point(dir, along, 0.035, ceil_h - 0.32)
	var pivot := Node3D.new()
	pivot.position = p
	pivot.rotation.y = _wall_facing(dir)
	pivot.set_meta("attributed_furnishing", "annex_air_conditioner")
	pivot.set_meta("annex_ac_mount", true)
	pivot.set_meta("annex_ac_dir", dir)
	add_child(pivot)
	var unit := _attributed_prop_local(
		pivot, OFFICE_AIR_CONDITIONER_PATH,
		-OFFICE_AIR_CONDITIONER_CENTRE * OFFICE_AIR_CONDITIONER_SCALE,
		0.0, Vector3.ONE * OFFICE_AIR_CONDITIONER_SCALE)
	if unit == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return
	unit.set_meta("authored_model", "annex_air_conditioner")


func _annex_chair_cluster(count: int, salt: int, piled: bool) -> void:
	var radius := 1.30 if piled else (0.52 if count == 1 else 1.08)
	var p := _free_floor_spot(salt, radius, 1.45 if piled else 1.25,
		1.85 if piled else 0.92, 18)
	if p == Vector3.INF:
		return
	var base_yaw := _r(salt + 41) * TAU
	var first := body.get_child_count()
	var kind := "annex_chair_pile" if piled \
		else ("annex_single_chair" if count == 1 else "annex_chair_group")
	var group := _furnishing_pivot(p, base_yaw, kind)
	group.set_meta("attributed_furnishing", kind)
	group.set_meta("annex_chair_count", count)
	var added := 0
	if piled:
		var pile_specs := [
			# Four tight floor chairs make the physical base.
			[Vector3(-0.40, 0.56, -0.30), Vector3(0.02, -0.52, 0.08)],
			[Vector3(0.40, 0.56, -0.28), Vector3(-0.03, 0.68, -0.10)],
			[Vector3(-0.38, 0.56, 0.32), Vector3(0.05, 2.26, 0.12)],
			[Vector3(0.38, 0.56, 0.31), Vector3(-0.04, 3.72, -0.12)],
			# Every upper chair penetrates the layer below slightly. At this
			# density their legs visibly land on seats/rails instead of hanging
			# in open air around a loose circle.
			[Vector3(-0.16, 0.80, -0.12), Vector3(0.24, 1.26, 0.28)],
			[Vector3(0.17, 0.83, 0.13), Vector3(-0.22, 2.72, -0.30)],
			[Vector3(-0.13, 0.94, 0.10), Vector3(0.26, 4.10, 0.24)],
			[Vector3(0.12, 1.02, -0.10), Vector3(-0.28, 5.24, -0.22)],
			[Vector3(0.02, 1.13, 0.05), Vector3(0.30, 1.90, -0.28)],
			[Vector3(-0.03, 1.25, -0.02), Vector3(-0.30, 4.76, 0.26)],
		]
		for i in mini(count, pile_specs.size()):
			var spec: Array = pile_specs[i]
			var before := group.get_child_count()
			_annex_pile_chair(group, spec[0], spec[1])
			if group.get_child_count() > before:
				added += 1
		if added > 0:
			_collider_yaw_box(p + Vector3(0, 0.91, 0),
				Vector3(1.72, 1.82, 1.66), base_yaw)
	else:
		var offsets := [
			Vector3.ZERO,
			Vector3(-0.48, 0, 0.12),
			Vector3(0.48, 0, -0.10),
			Vector3(0.02, 0, 0.60),
		]
		for i in mini(count, offsets.size()):
			var local_yaw := (_r(salt + 50 + i) - 0.5) * 0.52
			var inst := _attributed_prop_local(
				group, ANNEX_CHAIR_PATH,
				offsets[i] - ANNEX_CHAIR_CENTRE * ANNEX_CHAIR_SCALE,
				local_yaw, Vector3.ONE * ANNEX_CHAIR_SCALE)
			if inst == null:
				continue
			inst.set_meta("authored_model", "annex_dining_chair")
			var cp := _wp(p, offsets[i] + Vector3(0, 0.45, 0), base_yaw)
			_collider_yaw_box(cp, Vector3(0.40, 0.90, 0.49),
				base_yaw + local_yaw)
			added += 1
	if added == 0:
		group.get_parent().remove_child(group)
		group.free()
		return
	_bind_furnishing_colliders(group, first)


## Reuse the school's blue welded-frame chair as occasional Annex residue.
## Upright and side-laid chairs share one supported group; the tipped pose uses
## the imported chair's measured half-width (0.283m) as its floor lift.
func _annex_school_chair_scatter(count: int, salt: int) -> void:
	var radius := 0.46 if count == 1 else (0.78 if count == 2 else 1.02)
	var p := _free_floor_spot(salt, radius, 1.35, 1.05, 18)
	if p == Vector3.INF:
		return
	var base_yaw := _r(salt + 30) * TAU
	var first := body.get_child_count()
	var kind := "annex_school_chair_single" if count == 1 \
		else "annex_school_chair_scatter"
	var group := _furnishing_pivot(p, base_yaw, kind)
	group.set_meta("attributed_furnishing", kind)
	group.set_meta("annex_school_chair_count", count)
	var offsets := [
		Vector3.ZERO,
		Vector3(-0.54, 0, 0.16),
		Vector3(0.54, 0, -0.14),
	]
	var added := 0
	var tipped_count := 0
	for i in mini(count, offsets.size()):
		var chair := _asy_model("SchoolChair_01", Vector3.ZERO, 0.0)
		if chair == null:
			continue
		_adopt_local(group, chair)
		var local_yaw := (_r(salt + 40 + i) - 0.5) * 0.70
		chair.position = offsets[i] + Vector3(0, 0.002, 0)
		chair.rotation = Vector3(0, local_yaw, 0)
		var tipped := _r(salt + 50 + i) < 0.36
		if tipped:
			chair.position.y = 0.286
			chair.rotation.z = (PI / 2.0 - 0.06) \
				* (-1.0 if _r(salt + 60 + i) < 0.5 else 1.0)
			chair.set_meta("annex_school_chair_tipped", true)
			var tipped_pos := _wp(p,
				offsets[i] + Vector3(0, 0.29, 0), base_yaw)
			_collider_yaw_box(tipped_pos, Vector3(1.03, 0.58, 0.70),
				base_yaw + local_yaw)
			tipped_count += 1
		else:
			var upright_pos := _wp(p,
				offsets[i] + Vector3(0, 0.505, 0), base_yaw)
			_collider_yaw_box(upright_pos, Vector3(0.58, 1.01, 0.69),
				base_yaw + local_yaw)
		chair.set_meta("authored_model", "annex_school_chair")
		added += 1
	if added == 0:
		group.get_parent().remove_child(group)
		group.free()
		return
	group.set_meta("annex_school_chair_tipped_count", tipped_count)
	_bind_furnishing_colliders(group, first)


func _annex_loose_boxes(count: int, salt: int) -> void:
	var p := _free_floor_spot(salt, 0.52 if count == 1 else 0.78,
		1.20, 0.85, 16)
	if p == Vector3.INF:
		return
	var yaw := _r(salt + 20) * TAU
	var first := body.get_child_count()
	var group := _furnishing_pivot(p, yaw, "annex_loose_boxes")
	group.set_meta("attributed_furnishing", "annex_loose_boxes")
	group.set_meta("annex_box_count", count)
	var offsets := [
		Vector3.ZERO,
		Vector3(0.38, 0, 0.09),
		Vector3(0.12, 0.30, -0.04),
	]
	var added := 0
	for i in mini(count, offsets.size()):
		var variant := posmod(
			WorldGen.h(wseed, cell.x + i, cell.y - i, salt + 30),
			OFFICE_BOX_VARIANTS.size())
		if _office_shelf_box(group, offsets[i],
				(_r(salt + 35 + i) - 0.5) * 0.26, variant,
				"annex_loose_box"):
			added += 1
	if added == 0:
		group.get_parent().remove_child(group)
		group.free()
		return
	_collider_yaw_box(p + Vector3(0.12, 0.36, 0),
		Vector3(1.04, 0.72, 0.76), yaw)
	_bind_furnishing_colliders(group, first)


func _annex_shelving(salt: int) -> void:
	var dir := _annex_pick_solid_wall(salt, true)
	if dir < 0:
		dir = _annex_pick_solid_wall(salt, false)
	if dir < 0:
		return
	var along := 3.15 if _r(salt + 1) < 0.5 else 8.85
	var p := _annex_wall_floor_point(dir, along, 0.49)
	if not _floor_spot_clear(p, 0.42, 2.12):
		along = S - along
		p = _annex_wall_floor_point(dir, along, 0.49)
	if not _floor_spot_clear(p, 0.42, 2.12):
		return
	var yaw := _wall_facing(dir)
	var first := body.get_child_count()
	var shelf := _attributed_floor_prop(
		ANNEX_SHELVING_PATH, p, yaw, ANNEX_SHELVING_SCALE,
		ANNEX_SHELVING_CENTRE, "annex_shelving", null, true)
	if shelf == null:
		return
	shelf.set_meta("annex_shelf_wall_dir", dir)
	var box_count := 0
	var box_slots := [
		Vector3(-0.52, ANNEX_SHELVING_DECK_TOPS[0], 0.0),
		Vector3(0.02, ANNEX_SHELVING_DECK_TOPS[0], 0.0),
		Vector3(0.48, ANNEX_SHELVING_DECK_TOPS[1], 0.0),
		Vector3(-0.30, ANNEX_SHELVING_DECK_TOPS[2], 0.0),
		Vector3(0.36, ANNEX_SHELVING_DECK_TOPS[2], 0.0),
	]
	for i in box_slots.size():
		if _r(salt + 10 + i) >= 0.66:
			continue
		var variant := posmod(
			WorldGen.h(wseed, cell.x + i, cell.y, salt + 50),
			OFFICE_BOX_VARIANTS.size())
		if _office_shelf_box(shelf, box_slots[i],
				(_r(salt + 60 + i) - 0.5) * 0.12, variant,
				"annex_shelf_box"):
			box_count += 1
	shelf.set_meta("annex_shelf_box_count", box_count)
	_collider_yaw_box(p + Vector3(0, 1.05, 0),
		Vector3(1.90, 2.10, 0.68), yaw)
	_bind_furnishing_colliders(shelf, first)


func _annex_passage() -> void:
	var axis := WorldGen.annex_corridor_axis(wseed, cell)
	if axis == 0:
		return
	var horizontal_width := WorldGen.annex_horizontal_width(wseed, cell.y)
	var vertical_width := WorldGen.annex_vertical_width(wseed, cell.x)
	var marker := Node3D.new()
	marker.set_meta("annex_corridor_shell", axis)
	marker.set_meta("annex_horizontal_width", horizontal_width)
	marker.set_meta("annex_vertical_width", vertical_width)
	add_child(marker)
	# Each corridor run owns one of three stable widths. At an intersection the
	# four corner masses are sized independently, so a narrow hall can suddenly
	# release into a broad cross-axis without gaps or backing voids.
	if axis == 3:
		var block_width := (S - vertical_width) * 0.5
		var block_depth := (S - horizontal_width) * 0.5
		for xi in 2:
			var x := block_width * 0.5 if xi == 0 \
				else S - block_width * 0.5
			var x_dir := 1 if xi == 0 else 0
			var x_mat := Mats.annex_wall_variant(
				WorldGen.annex_wall_finish(wseed, cell, x_dir))
			for zi in 2:
				var z := block_depth * 0.5 if zi == 0 \
					else S - block_depth * 0.5
				# Each cross-corridor corner commits to one finish and one solid.
				# The former perpendicular "skins" were coplanar with this block,
				# causing the recurring bright vertical ridges seen in motion.
				var corner := _box(Vector3(x, ceil_h * 0.5, z),
					Vector3(block_width, ceil_h, block_depth), x_mat)
				corner.set_meta("annex_cross_corner", true)
				corner.set_meta("annex_single_finish", true)
				_annex_register_ceiling_obstruction(
					Vector3(x, 0.0, z), block_width, block_depth, 0.0, ceil_h)
		return
	# near/far_plane are the walkable corridor faces. The shell boxes are
	# centred half a wall thickness outside them, so their corridor faces land
	# exactly on the plane and stay flush with the intersection corner masses
	# (which own [0, block_width]). Centring the box ON the plane put every
	# shell face 15cm inside the corners' line, stepping the wall at each
	# passage-to-intersection junction.
	if axis == 1:
		var near_shell := S * 0.5 - horizontal_width * 0.5 - ANNEX_WALL_T * 0.5
		var far_shell := S * 0.5 + horizontal_width * 0.5 + ANNEX_WALL_T * 0.5
		_annex_corridor_side(true, near_shell, 3,
			Mats.annex_wall_variant(
				WorldGen.annex_wall_finish(wseed, cell, 3)))
		_annex_corridor_side(true, far_shell, 2,
			Mats.annex_wall_variant(
				WorldGen.annex_wall_finish(wseed, cell, 2)))
		if _r(560) < 0.11:
			var camera_dir := 3 if _r(561) < 0.5 else 2
			if WorldGen.edge_info(wseed, cell, camera_dir, theme)["wall"]:
				_security_camera_wall(camera_dir,
					near_shell if camera_dir == 3 else far_shell)
	else:
		var near_shell := S * 0.5 - vertical_width * 0.5 - ANNEX_WALL_T * 0.5
		var far_shell := S * 0.5 + vertical_width * 0.5 + ANNEX_WALL_T * 0.5
		_annex_corridor_side(false, near_shell, 1,
			Mats.annex_wall_variant(
				WorldGen.annex_wall_finish(wseed, cell, 1)))
		_annex_corridor_side(false, far_shell, 0,
			Mats.annex_wall_variant(
				WorldGen.annex_wall_finish(wseed, cell, 0)))
		if _r(560) < 0.11:
			var camera_dir := 1 if _r(561) < 0.5 else 0
			if WorldGen.edge_info(wseed, cell, camera_dir, theme)["wall"]:
				_security_camera_wall(camera_dir,
					near_shell if camera_dir == 1 else far_shell)


## Build one visible inner corridor wall. When its outer cell boundary opens
## into a room, the same opening is repeated here and connected with two return
## walls, creating a real short passage instead of exposing a fake backing bay.
func _annex_corridor_side(along_x: bool, plane: float, outer_dir: int,
		mat: Material) -> void:
	var info := WorldGen.edge_info(wseed, cell, outer_dir, theme)
	if info["wall"]:
		_annex_corridor_segment(along_x, plane, 0.0, S, 0.0, ceil_h, mat)
		_wall_utilities(outer_dir, plane, info)
		return
	# The shell repeats the outer boundary opening EXACTLY. The former clamps
	# let the two frames disagree by up to 70cm, which read from the wider side
	# as a second doorway floating inside the first.
	var a := float(info["t"]) - float(info["w"]) * 0.5
	var b := float(info["t"]) + float(info["w"]) * 0.5
	_annex_corridor_segment(along_x, plane, 0.0, a, 0.0, ceil_h, mat)
	_annex_corridor_segment(along_x, plane, b, S, 0.0, ceil_h, mat)
	_wall_utilities(outer_dir, plane, info)
	var outer_plane := ANNEX_WALL_T * 0.5 \
		if outer_dir == 1 or outer_dir == 3 \
		else S - ANNEX_WALL_T * 0.5
	# One solid mass above door height from the boundary wall to the corridor
	# face of the shell, replacing the shell's own floating header. Together
	# with the flanking returns this turns the doorway into a single straight
	# rectangular tunnel through one visually thick wall — no second frame, no
	# beam hanging behind the first, no ceiling slot over the passage.
	var boundary := 0.0 if outer_dir == 1 or outer_dir == 3 else S
	var reach := boundary if bool(info["full_open"]) else outer_plane
	var toward := 1.0 if plane < S * 0.5 else -1.0
	var shell_face := plane + toward * ANNEX_WALL_T * 0.5
	var head_mid := (reach + shell_face) * 0.5
	var head_depth := absf(shell_face - reach)
	var head_y := (DOOR_TOP + ceil_h) * 0.5
	var head_h := ceil_h - DOOR_TOP
	if along_x:
		_box(Vector3((a + b) * 0.5, head_y, head_mid),
			Vector3(b - a, head_h, head_depth), mat)
		_annex_register_ceiling_obstruction(
			Vector3((a + b) * 0.5, 0.0, head_mid),
			b - a, head_depth, 0.0, ceil_h)
	else:
		_box(Vector3(head_mid, head_y, (a + b) * 0.5),
			Vector3(head_depth, head_h, b - a), mat)
		_annex_register_ceiling_obstruction(
			Vector3(head_mid, 0.0, (a + b) * 0.5),
			head_depth, b - a, 0.0, ceil_h)
	# Returns sit fully OUTSIDE the opening span, so their faces are flush with
	# the jamb cuts at `a` and `b` — centring them ON the opening edge poked a
	# 15cm sliver past each jamb into the passage. They run from the boundary
	# side to the shell's strip face, abutting (never overlapping) the wall
	# segments' own cut faces, so the tunnel side reads as one flush plane.
	var shell_back := plane - toward * ANNEX_WALL_T * 0.5
	var ret_depth := absf(reach - shell_back)
	var ret_mid := (reach + shell_back) * 0.5
	if along_x:
		for x in [a - ANNEX_WALL_T * 0.5, b + ANNEX_WALL_T * 0.5]:
			_box(Vector3(x, ceil_h * 0.5, ret_mid),
				Vector3(ANNEX_WALL_T, ceil_h, ret_depth), mat)
			_annex_register_ceiling_obstruction(
				Vector3(x, 0.0, ret_mid),
				ANNEX_WALL_T, ret_depth, 0.0, ceil_h)
	else:
		for z in [a - ANNEX_WALL_T * 0.5, b + ANNEX_WALL_T * 0.5]:
			_box(Vector3(ret_mid, ceil_h * 0.5, z),
				Vector3(ret_depth, ceil_h, ANNEX_WALL_T), mat)
			_annex_register_ceiling_obstruction(
				Vector3(ret_mid, 0.0, z),
				ret_depth, ANNEX_WALL_T, 0.0, ceil_h)


func _annex_corridor_segment(along_x: bool, plane: float, a: float, b: float,
		y0: float, y1: float, mat: Material) -> void:
	if b - a <= 0.02 or y1 - y0 <= 0.02:
		return
	var wall_mesh: MeshInstance3D
	if along_x:
		wall_mesh = _annex_wall_prism(
			Vector3((a + b) * 0.5, (y0 + y1) * 0.5, plane),
			Vector3(b - a, y1 - y0, ANNEX_WALL_T), true,
			not is_zero_approx(a), not is_equal_approx(b, S), mat)
		_annex_register_ceiling_obstruction(
			Vector3((a + b) * 0.5, 0.0, plane),
			b - a, ANNEX_WALL_T, 0.0, y1)
	else:
		wall_mesh = _annex_wall_prism(
			Vector3(plane, (y0 + y1) * 0.5, (a + b) * 0.5),
			Vector3(ANNEX_WALL_T, y1 - y0, b - a), false,
			not is_zero_approx(a), not is_equal_approx(b, S), mat)
		_annex_register_ceiling_obstruction(
			Vector3(plane, 0.0, (a + b) * 0.5),
			ANNEX_WALL_T, b - a, 0.0, y1)
	wall_mesh.set_meta("annex_wall_thickness", ANNEX_WALL_T)
	wall_mesh.set_meta("annex_wall_seam_safe", true)
	wall_mesh.set_meta("annex_wall_cap_min", not is_zero_approx(a))
	wall_mesh.set_meta("annex_wall_cap_max", not is_equal_approx(b, S))


func _annex_lobby() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var yaw := PI / 2.0 if _r(550) < 0.5 else 0.0
	# An asymmetrical deep mass plus one smaller support creates the framed,
	# layered sightlines in the references without turning the lobby into a
	# regular procedural column grid.
	_annex_block(_wp(c, Vector3(-2.0, 0, -0.18), yaw), yaw,
		2.35, 1.35, ceil_h, "annex_wall_mass")
	_annex_block(_wp(c, Vector3(2.65, 0, 0.32), yaw), 0.0,
		1.10, 1.10, ceil_h, "annex_column")
	if _r(551) < 0.92:
		_annex_block(_wp(c, Vector3(0, 0, 1.9), yaw), yaw,
			5.1, 0.26, 1.08, "annex_half_wall")


## Rare Backrooms furniture hoard. The pile is procedurally composed from a
## few existing CC0 furnishings and seeded wooden chairs, then treated as one
## atomic obstacle. Its centre sits at the middle of a 24x24 room, leaving a
## broad navigable perimeter and every doorway approach clear.
func _annex_furniture_pile() -> bool:
	if portal_dest >= 0 or room_n < 4 \
			or not WorldGen.annex_furniture_pile(wseed, room_root):
		return false
	var span := _room_span()
	if span.x < 23.9 or span.y < 23.9:
		return false
	var centre := Vector3(span.x * 0.5, 0.0, span.y * 0.5)
	var yaw := floorf(_r(568) * 4.0) * PI * 0.5 \
		+ (_r(569) - 0.5) * 0.18
	var body0 := body.get_child_count()
	var pile := _furnishing_pivot(centre, yaw, "annex_furniture_pile")
	pile.set_meta("annex_furniture_pile", true)
	pile.set_meta("annex_room_cells", room_n)

	# Heavy floor-supported core: a sofa, chair and cabinets give the loose
	# upper pieces a believable mass rather than a gravity-free sculpture.
	_cc0_prop_local(pile, "sofa_03", Vector3(-0.55, 0.0, 0.82),
		PI + (_r(570) - 0.5) * 0.16, 0.90)
	_cc0_prop_local(pile, "drawer_cabinet", Vector3(1.40, 0.0, -0.52),
		-PI * 0.5 + (_r(571) - 0.5) * 0.12, 0.92)
	_cc0_prop_local(pile, "ArmChair_01", Vector3(-1.58, 0.0, -0.74),
		0.42 + (_r(572) - 0.5) * 0.22, 0.94)
	_cc0_prop_local(pile, "Ottoman_01", Vector3(1.62, 0.0, 1.18),
		_r(573) * TAU, 0.92)

	# A shoved-in plywood cabinet and a tilted coffee table make the centre read
	# as accumulated office furniture rather than a lounge arrangement.
	_mrbox(pile, Vector3(0.02, 0.76, -0.52),
		Vector3(1.52, 1.52, 0.72), Mats.wood_door(), 0.018)
	for sy in [-0.33, 0.10, 0.53]:
		_mbox(pile, Vector3(0.02, 0.76 + sy, -0.895),
			Vector3(1.30, 0.035, 0.025), Mats.darkwood())
	# Open bookcase on one flank.
	_mbox(pile, Vector3(1.34, 0.88, 0.27),
		Vector3(1.04, 1.76, 0.055), Mats.darkwood())
	for sx in [-0.50, 0.50]:
		_mrbox(pile, Vector3(1.34 + sx, 0.88, 0.02),
			Vector3(0.065, 1.76, 0.56), Mats.wood_door(), 0.012)
	for shelf_y in [0.08, 0.55, 1.02, 1.49, 1.74]:
		_mrbox(pile, Vector3(1.34, shelf_y, 0.02),
			Vector3(1.04, 0.055, 0.56), Mats.wood_door(), 0.012)
	# A full-height panel leans against the opposite side, making the heap read
	# wide even before the chairs and upholstery fill its silhouette.
	var leaning_panel := Node3D.new()
	leaning_panel.position = Vector3(-1.42, 1.03, 0.08)
	leaning_panel.rotation = Vector3(0.04, -0.32, -0.22)
	pile.add_child(leaning_panel)
	_mrbox(leaning_panel, Vector3.ZERO,
		Vector3(1.22, 1.94, 0.085), Mats.wood_door(), 0.015)
	# Misaligned upholstery stacked through the middle.
	_mrbox(pile, Vector3(-0.55, 1.18, 0.56),
		Vector3(1.34, 0.36, 0.84), Mats.velvet2(), 0.10)
	_mrbox(pile, Vector3(-0.43, 1.51, 0.45),
		Vector3(1.10, 0.31, 0.76), Mats.velvet(), 0.09)
	var table := _cc0_prop_local(pile, "CoffeeTable_01",
		Vector3(0.25, 1.20, 0.0), _r(574) * TAU, 0.82)
	table.rotation.x = 0.10 + _r(575) * 0.13
	table.rotation.z = (_r(576) - 0.5) * 0.22
	var upper_table := _cc0_prop_local(pile, "coffee_table_round_01",
		Vector3(-0.22, 1.72, 0.18), _r(578) * TAU, 0.82)
	upper_table.rotation.x = -0.12
	upper_table.rotation.z = 0.16
	var television := _cc0_prop_local(pile, "television_02",
		Vector3(0.72, 1.45, -0.20), -0.55, 0.74)
	television.rotation.z = -0.10

	# Seeded dining chairs ring and crown the pile. They deliberately overlap
	# the core and one another, but never escape the aggregate collider.
	var chair_specs := [
		[Vector3(-1.92, 0.56, -1.32), Vector3(0.02, -0.55, 0.10)],
		[Vector3(1.84, 0.56, 1.38), Vector3(-0.02, 2.15, -0.12)],
		[Vector3(0.32, 0.56, -1.82), Vector3(0.04, 1.55, 0.14)],
		[Vector3(-1.05, 1.23, -0.20), Vector3(0.16, 0.48, 0.08)],
		[Vector3(0.90, 1.32, 0.18), Vector3(-0.13, 2.75, 0.13)],
		[Vector3(-1.36, 1.48, 0.78), Vector3(0.12, 0.18, 0.24)],
		[Vector3(1.38, 1.53, 0.72), Vector3(-0.10, 3.70, -0.26)],
		[Vector3(0.02, 1.84, -0.38), Vector3(0.18, 1.38, 0.20)],
		[Vector3(2.08, 0.56, -0.76), Vector3(0.03, 2.88, -0.14)],
		[Vector3(-2.10, 0.56, 0.72), Vector3(-0.02, -0.16, 0.12)],
		[Vector3(0.76, 1.78, 0.46), Vector3(-0.16, 4.36, -0.18)],
	]
	var chair_count := 9 + int(_r(577) * 2.99)
	for i in chair_count:
		var spec: Array = chair_specs[i]
		var pos: Vector3 = spec[0]
		pos += Vector3((_r(580 + i * 3) - 0.5) * 0.14,
			0.0, (_r(581 + i * 3) - 0.5) * 0.14)
		var rot: Vector3 = spec[1]
		rot.y += (_r(582 + i * 3) - 0.5) * 0.24
		_annex_pile_chair(pile, pos, rot)

	# One absurd floor lamp poking out of the top echoes the reference without
	# turning every hoard into the exact same silhouette.
	if _r(610) < 0.76:
		_mcyl(pile, Vector3(-0.22, 1.91, 0.12), 0.018, 1.14,
			Mats.metal_gray())
		_mcyl(pile, Vector3(-0.22, 1.35, 0.12), 0.17, 0.035,
			Mats.metal_gray())
		var shade := _mcyl(pile, Vector3(-0.22, 2.46, 0.12), 0.18, 0.16,
			Mats.shade())
		shade.rotation.z = 0.18

	# A single conservative collision volume is intentional: the hoard is a
	# pile, not a platforming course, and one group can be culled atomically.
	_collider_yaw_box(
		_wp(centre, Vector3(0.0, 1.31, 0.0), yaw),
		Vector3(5.45, 2.62, 5.15), yaw)
	_bind_furnishing_colliders(pile, body0)
	return true


func _annex_pile_chair(parent: Node3D, pos: Vector3,
		rot: Vector3) -> void:
	var chair := Node3D.new()
	# Existing pile coordinates describe the old generated chair's seat plane
	# at y=.56. Rebase them to the floor and keep the supplied model's authored
	# centre correction inside the rotating chair pivot.
	chair.position = pos - Vector3(0, 0.56, 0)
	chair.rotation = rot
	parent.add_child(chair)
	var inst := _attributed_prop_local(
		chair, ANNEX_CHAIR_PATH,
		-ANNEX_CHAIR_CENTRE * ANNEX_CHAIR_SCALE,
		0.0, Vector3.ONE * ANNEX_CHAIR_SCALE)
	if inst == null:
		chair.get_parent().remove_child(chair)
		chair.free()
		return
	inst.set_meta("authored_model", "annex_dining_chair")


# --- legacy sewer (retired from generation) ---------------------------------

func _sewer_ch() -> Array:
	return [
		WorldGen.sewer_channel(wseed, cell, 0),
		WorldGen.sewer_channel(wseed, cell, 1),
		WorldGen.sewer_channel(wseed, cell, 2),
		WorldGen.sewer_channel(wseed, cell, 3),
	]


func _sewer_floor_ceiling() -> void:
	var ch := _sewer_ch()
	# cast concrete lid with cross beams
	_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.concrete())
	for t in [2.0, 6.0, 10.0]:
		_box(Vector3(S / 2.0, ceil_h - 0.11, t), Vector3(S, 0.24, 0.34), Mats.concrete(), false)
	if style == WorldGen.SEWER_BASIN or style == WorldGen.SEWER_CISTERN:
		_sewer_basin_structure(ch)
		return
	var a := 6.0 - CH_CUT
	var b := 6.0 + CH_CUT
	# corner slabs are always dry ground
	for xr in [[0.0, a], [b, S]]:
		for zr in [[0.0, a], [b, S]]:
			_floor_slab(xr[0], xr[1], zr[0], zr[1])
	# side tiles: water trough if that edge carries the channel
	var regions := [[b, S], [0.0, a], [b, S], [0.0, a]]
	for dir in 4:
		var t0: float = regions[dir][0]
		var t1: float = regions[dir][1]
		if ch[dir]:
			_channel_stub(dir, t0, t1)
		elif dir < 2:
			_floor_slab(t0, t1, a, b)
		else:
			_floor_slab(a, b, t0, t1)
	if ch[0] or ch[1] or ch[2] or ch[3]:
		_channel_junction(ch)
	else:
		_floor_slab(a, b, a, b)


func _floor_slab(x0: float, x1: float, z0: float, z1: float) -> void:
	if x1 - x0 < 0.05 or z1 - z0 < 0.05:
		return
	_box(Vector3((x0 + x1) / 2.0, -0.15, (z0 + z1) / 2.0),
		Vector3(x1 - x0, 0.3, z1 - z0), Mats.concrete_floor())


## Sloped concrete slab with matching collider. `lip` is the centre of the top
## edge; the surface descends `drop` over signed horizontal `run` along z
## (slope_dz) or x, extended `ext` past the toe to bury the seam.
func _slope_slab(lip: Vector3, slope_dz: bool, run: float, drop: float, ln: float, th: float, ext: float) -> void:
	var ang := atan2(drop, absf(run))
	var sn := signf(run)
	var base_len := sqrt(run * run + drop * drop)
	var mid := (base_len + ext) / 2.0
	var dc := cos(ang) * sn * mid - sin(ang) * sn * th / 2.0
	var dy := -sin(ang) * mid - cos(ang) * th / 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = BOX
	mi.material_override = Mats.concrete_floor()
	if slope_dz:
		mi.position = lip + Vector3(0, dy, dc)
		mi.rotation.x = ang * sn
		mi.scale = Vector3(ln, th, base_len + ext)
	else:
		mi.position = lip + Vector3(dc, dy, 0)
		mi.rotation.z = -ang * sn
		mi.scale = Vector3(base_len + ext, th, ln)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = mi.scale
	cs.shape = sh
	cs.position = mi.position
	cs.rotation = mi.rotation
	body.add_child(cs)


## One straight trough stretch: sunken invert, two walkable banks, water.
func _trough(along_x: bool, t0: float, t1: float, flow: Vector2) -> void:
	var ln := t1 - t0
	var c := (t0 + t1) * 0.5
	var wm: MeshInstance3D
	if along_x:
		_box(Vector3(c, -CH_D - 0.075, 6.0), Vector3(ln, 0.15, CH_HW * 2.0 + 0.2), Mats.concrete_floor())
		_slope_slab(Vector3(c, 0, 6.0 - CH_CUT), true, BANK, CH_D, ln, 0.14, 0.1)
		_slope_slab(Vector3(c, 0, 6.0 + CH_CUT), true, -BANK, CH_D, ln, 0.14, 0.1)
		wm = _box(Vector3(c, WATER_Y - 0.02, 6.0), Vector3(ln, 0.04, 2.5), Mats.sewer_water(), false)
	else:
		_box(Vector3(6.0, -CH_D - 0.075, c), Vector3(CH_HW * 2.0 + 0.2, 0.15, ln), Mats.concrete_floor())
		_slope_slab(Vector3(6.0 - CH_CUT, 0, c), false, BANK, CH_D, ln, 0.14, 0.1)
		_slope_slab(Vector3(6.0 + CH_CUT, 0, c), false, -BANK, CH_D, ln, 0.14, 0.1)
		wm = _box(Vector3(6.0, WATER_Y - 0.02, c), Vector3(2.5, 0.04, ln), Mats.sewer_water(), false)
	wm.set_instance_shader_parameter("flow", flow)


func _channel_stub(dir: int, t0: float, t1: float) -> void:
	var along_x := dir < 2
	var sgn := WorldGen.sewer_flow(wseed, cell, dir)
	var flow := Vector2(sgn * 0.32, 0.0) if along_x else Vector2(0.0, sgn * 0.32)
	_trough(along_x, t0, t1, flow)
	if WorldGen.edge_info(wseed, cell, dir, theme)["wall"]:
		_culvert(dir)


## Where all channel stubs meet: shared pool tile, closed sides get banks.
func _channel_junction(ch: Array) -> void:
	var a := 6.0 - CH_CUT
	var b := 6.0 + CH_CUT
	_box(Vector3(6.0, -CH_D - 0.085, 6.0), Vector3(b - a, 0.17, b - a), Mats.concrete_floor())
	if not ch[0]:
		_slope_slab(Vector3(b, 0, 6.0), false, -BANK, CH_D, b - a, 0.14, 0.1)
	if not ch[1]:
		_slope_slab(Vector3(a, 0, 6.0), false, BANK, CH_D, b - a, 0.14, 0.1)
	if not ch[2]:
		_slope_slab(Vector3(6.0, 0, b), true, -BANK, CH_D, b - a, 0.14, 0.1)
	if not ch[3]:
		_slope_slab(Vector3(6.0, 0, a), true, BANK, CH_D, b - a, 0.14, 0.1)
	var fv := Vector2.ZERO
	for dir in 4:
		if ch[dir]:
			var sgn := WorldGen.sewer_flow(wseed, cell, dir)
			fv += Vector2(sgn, 0.0) if dir < 2 else Vector2(0.0, sgn)
	fv = fv.normalized() * 0.3 if fv.length() > 0.01 else Vector2(0.17, 0.13)
	var wm := _box(Vector3(6.0, WATER_Y - 0.02, 6.0), Vector3(b - a, 0.04, b - a), Mats.sewer_water(), false)
	wm.set_instance_shader_parameter("flow", fv)


## Barred opening where the channel slips under a wall.
func _culvert(dir: int) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var bar_p := plane + n * (T / 2.0 + 0.05)
	if dir < 2:
		_box(Vector3(plane, -0.04, 6.0), Vector3(T + 0.1, 0.16, CH_HW * 2.0 + 0.4), Mats.concrete(), false)
		for i in 5:
			_cyl(Vector3(bar_p, -0.26, 6.0 - 0.56 + 0.28 * float(i)), 0.024, 0.52, Mats.iron_dark(), false)
	else:
		_box(Vector3(6.0, -0.04, plane), Vector3(CH_HW * 2.0 + 0.4, 0.16, T + 0.1), Mats.concrete(), false)
		for i in 5:
			_cyl(Vector3(6.0 - 0.56 + 0.28 * float(i), -0.26, bar_p), 0.024, 0.52, Mats.iron_dark(), false)


## Basin room: sunken pool spanning the middle, walkways around it, channel
## stubs pouring in through gaps in the retaining walls.
func _sewer_basin_structure(ch: Array) -> void:
	var a := 6.0 - CH_CUT
	var b := 6.0 + CH_CUT
	if ch[1]:
		_floor_slab(0.0, BAS0, 0.0, a)
		_floor_slab(0.0, BAS0, b, S)
	else:
		_floor_slab(0.0, BAS0, 0.0, S)
	if ch[0]:
		_floor_slab(BAS1, S, 0.0, a)
		_floor_slab(BAS1, S, b, S)
	else:
		_floor_slab(BAS1, S, 0.0, S)
	if ch[3]:
		_floor_slab(BAS0, a, 0.0, BAS0)
		_floor_slab(b, BAS1, 0.0, BAS0)
	else:
		_floor_slab(BAS0, BAS1, 0.0, BAS0)
	if ch[2]:
		_floor_slab(BAS0, a, BAS1, S)
		_floor_slab(b, BAS1, BAS1, S)
	else:
		_floor_slab(BAS0, BAS1, BAS1, S)
	if ch[0]:
		_channel_stub(0, BAS1, S)
	if ch[1]:
		_channel_stub(1, 0.0, BAS0)
	if ch[2]:
		_channel_stub(2, BAS1, S)
	if ch[3]:
		_channel_stub(3, 0.0, BAS0)
	_box(Vector3(6.0, -BAS_D - 0.075, 6.0),
		Vector3(BAS1 - BAS0 + 0.3, 0.15, BAS1 - BAS0 + 0.3), Mats.concrete_floor())
	_basin_walls(ch)
	var wm := _box(Vector3(6.0, WATER_Y - 0.02, 6.0),
		Vector3(BAS1 - BAS0 + 0.1, 0.04, BAS1 - BAS0 + 0.1), Mats.sewer_water(), false)
	wm.set_instance_shader_parameter("flow", Vector2(0.1, 0.08))
	var rs := _basin_ramp_spot(ch)
	_basin_ramp(rs[0], rs[1])


func _basin_walls(ch: Array) -> void:
	var a := 6.0 - CH_CUT
	var b := 6.0 + CH_CUT
	for dir in 4:
		var w := (BAS1 + 0.075) if (dir == 0 or dir == 2) else (BAS0 - 0.075)
		if ch[dir]:
			_bwall(dir, w, BAS0, a)
			_bwall(dir, w, b, BAS1)
			# submerged step below the inlet trough
			if dir < 2:
				_box(Vector3(w, -(BAS_D + CH_D) / 2.0, 6.0), Vector3(0.15, BAS_D - CH_D, b - a), Mats.concrete(), true)
			else:
				_box(Vector3(6.0, -(BAS_D + CH_D) / 2.0, w), Vector3(b - a, BAS_D - CH_D, 0.15), Mats.concrete(), true)
		else:
			_bwall(dir, w, BAS0, BAS1)


func _bwall(dir: int, w: float, t0: float, t1: float) -> void:
	if t1 - t0 < 0.05:
		return
	var c := (t0 + t1) / 2.0
	if dir < 2:
		_box(Vector3(w, -BAS_D / 2.0, c), Vector3(0.15, BAS_D, t1 - t0), Mats.concrete())
	else:
		_box(Vector3(c, -BAS_D / 2.0, w), Vector3(t1 - t0, BAS_D, 0.15), Mats.concrete())


func _basin_ramp_spot(ch: Array) -> Array:
	var start := int(_r(70) * 3.99)
	var rdir := start
	for i in 4:
		var d := (start + i) % 4
		if not ch[d]:
			rdir = d
			break
	var lat := 3.9 if _r(71) < 0.5 else 8.1
	return [rdir, lat]


## Concrete ramp descending into the basin — the way back out of the water.
func _basin_ramp(rdir: int, lat: float) -> void:
	var run := BAS_D / tan(0.6)
	match rdir:
		0: _slope_slab(Vector3(BAS1, 0, lat), false, -run, BAS_D, 1.3, 0.16, 0.2)
		1: _slope_slab(Vector3(BAS0, 0, lat), false, run, BAS_D, 1.3, 0.16, 0.2)
		2: _slope_slab(Vector3(lat, 0, BAS1), true, -run, BAS_D, 1.3, 0.16, 0.2)
		3: _slope_slab(Vector3(lat, 0, BAS0), true, run, BAS_D, 1.3, 0.16, 0.2)


func _sewer_basin_props() -> void:
	var ch := _sewer_ch()
	var rs := _basin_ramp_spot(ch)
	# Prefer an inspection bridge between two closed sides. It crosses the
	# pool rather than pretending a walkway can end in an incoming waterway.
	var bridge_axis := -1  # 0 = along x, 1 = along z
	if not ch[0] and not ch[1]:
		bridge_axis = 0
	elif not ch[2] and not ch[3]:
		bridge_axis = 1
	for dir in 4:
		var segs := [[BAS0 + 0.05, BAS1 - 0.05]]
		if ch[dir]:
			segs = _cut_seg(segs, 6.0 - CH_CUT - 0.15, 6.0 + CH_CUT + 0.15)
		if rs[0] == dir:
			segs = _cut_seg(segs, rs[1] - 0.85, rs[1] + 0.85)
		if (bridge_axis == 0 and dir <= 1) or (bridge_axis == 1 and dir >= 2):
			segs = _cut_seg(segs, 5.28, 6.72)
		for sg in segs:
			_rail_run(dir, sg[0], sg[1])
	if bridge_axis >= 0:
		_sewer_basin_bridge(bridge_axis == 0)
	# ceiling drop pipes discharging into the pool
	var made := 0
	for dir in 4:
		if made >= 2 or ch[dir]:
			continue
		if not WorldGen.edge_info(wseed, cell, dir, theme)["wall"]:
			continue
		if _r(96 + dir) < 0.55:
			_outfall(dir, 4.6 if _r(97 + dir) < 0.5 else 7.4)
			made += 1


## Narrow grated inspection bridge over one treatment pool. The solid deck
## collider keeps it dependable while individual slats sell the open grating.
func _sewer_basin_bridge(along_x: bool) -> void:
	var length := BAS1 - BAS0
	var centre := (BAS0 + BAS1) * 0.5
	for i in 23:
		var t := lerpf(BAS0 + 0.16, BAS1 - 0.16, float(i) / 22.0)
		var p := Vector3(t, 0.055, centre) if along_x else Vector3(centre, 0.055, t)
		var sz := Vector3(0.12, 0.07, 1.08) if along_x else Vector3(1.08, 0.07, 0.12)
		_box(p, sz, Mats.iron_dark(), false)
	# rusted longitudinals visible beneath the grate
	for side in [-0.48, 0.48]:
		var bp := Vector3(centre, 0.015, centre + side) if along_x \
			else Vector3(centre + side, 0.015, centre)
		var bs := Vector3(length, 0.10, 0.08) if along_x \
			else Vector3(0.08, 0.10, length)
		_box(bp, bs, Mats.pipe_rust(), false)
	# handrails and posts along both exposed sides
	for side in [-0.58, 0.58]:
		for t in [BAS0 + 0.12, centre, BAS1 - 0.12]:
			var pp := Vector3(t, 0.48, centre + side) if along_x \
				else Vector3(centre + side, 0.48, t)
			_cyl(pp, 0.022, 0.88, Mats.iron_dark(), false)
		for ry in [0.52, 0.91]:
			var rp := Vector3(centre, ry, centre + side) if along_x \
				else Vector3(centre + side, ry, centre)
			var rz := Vector3(length, 0.05, 0.05) if along_x \
				else Vector3(0.05, 0.05, length)
			_box(rp, rz, Mats.iron_dark(), false)
	var deck_size := Vector3(length, 0.10, 1.12) if along_x \
		else Vector3(1.12, 0.10, length)
	_collider_box(Vector3(centre, 0.05, centre), deck_size)
	for side in [-0.58, 0.58]:
		var cp := Vector3(centre, 0.5, centre + side) if along_x \
			else Vector3(centre + side, 0.5, centre)
		var cs := Vector3(length, 1.0, 0.06) if along_x \
			else Vector3(0.06, 1.0, length)
		_collider_box(cp, cs)


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


func _rail_run(dir: int, t0: float, t1: float) -> void:
	if t1 - t0 < 0.5:
		return
	var w := (BAS1 + 0.16) if (dir == 0 or dir == 2) else (BAS0 - 0.16)
	var c := (t0 + t1) / 2.0
	var n := int(ceilf((t1 - t0) / 1.6))
	for i in n + 1:
		var t := lerpf(t0 + 0.05, t1 - 0.05, float(i) / float(n))
		var pp := Vector3(w, 0.475, t) if dir < 2 else Vector3(t, 0.475, w)
		_cyl(pp, 0.022, 0.95, Mats.iron_dark(), false)
	for ry in [0.93, 0.52]:
		if dir < 2:
			_box(Vector3(w, ry, c), Vector3(0.05, 0.05, t1 - t0), Mats.iron_dark(), false)
		else:
			_box(Vector3(c, ry, w), Vector3(t1 - t0, 0.05, 0.05), Mats.iron_dark(), false)
	if dir < 2:
		_collider_box(Vector3(w, 0.5, c), Vector3(0.06, 1.0, t1 - t0))
	else:
		_collider_box(Vector3(c, 0.5, w), Vector3(t1 - t0, 1.0, 0.06))


func _outfall(dir: int, along: float) -> void:
	var p: Vector3
	match dir:
		0: p = Vector3(BAS1 - 0.5, 0, along)
		1: p = Vector3(BAS0 + 0.5, 0, along)
		2: p = Vector3(along, 0, BAS1 - 0.5)
		3: p = Vector3(along, 0, BAS0 + 0.5)
	_cyl(Vector3(p.x, (1.55 + ceil_h) / 2.0, p.z), 0.15, ceil_h - 1.55, Mats.pipe_rust(), false)
	var tor := MeshInstance3D.new()
	tor.mesh = TOR
	tor.material_override = Mats.pipe_rust()
	tor.position = Vector3(p.x, 1.58, p.z)
	tor.scale = Vector3(0.24, 0.12, 0.24)
	add_child(tor)
	_box(Vector3(p.x, (1.55 + WATER_Y) / 2.0, p.z),
		Vector3(0.24, 1.55 - WATER_Y, 0.24), Mats.water_stream(), false)


# --- sewer: props ------------------------------------------------------------

func _sewer_tunnel_props() -> void:
	var members := _room_members()
	for mi in members.size():
		var member: Vector2i = members[mi]
		var mc := _room_member_local(member)
		var salt := 330 + mi * 24
		# Wet patches and abandoned debris live in dry corners, never on the
		# centre-line water graph that has to remain readable and walkable.
		for pi in 2:
			if WorldGen.r01(wseed, member.x, member.y, salt + pi) >= 0.62:
				continue
			var sx := -1.0 if WorldGen.r01(wseed, member.x, member.y, salt + 3 + pi) < 0.5 else 1.0
			var sz := -1.0 if WorldGen.r01(wseed, member.x, member.y, salt + 5 + pi) < 0.5 else 1.0
			var pp := mc + Vector3(sx * (3.4 + WorldGen.r01(wseed, member.x, member.y, salt + 7 + pi)),
				0.006, sz * (3.2 + 1.2 * WorldGen.r01(wseed, member.x, member.y, salt + 9 + pi)))
			_box(pp, Vector3(0.8 + WorldGen.r01(wseed, member.x, member.y, salt + 11 + pi),
				0.012, 0.65 + 0.7 * WorldGen.r01(wseed, member.x, member.y, salt + 13 + pi)),
				Mats.puddle(), false)
		if WorldGen.r01(wseed, member.x, member.y, salt + 15) < 0.28:
			_barrel(mc + Vector3(-4.25, 0, -4.15))
		if WorldGen.r01(wseed, member.x, member.y, salt + 16) < 0.24:
			_cc0_prop("trashbag", mc + Vector3(4.2, 0, -3.8),
				WorldGen.r01(wseed, member.x, member.y, salt + 17) * TAU)
		if WorldGen.r01(wseed, member.x, member.y, salt + 18) < 0.24:
			_chain(mc + Vector3(-3.8, 0, 3.2))
	# Wall-bound ladders cannot be shifted with a merged room's centre.
	if room_n == 1 and _r(84) < 0.16:
		_wall_ladder()


func _sewer_pump_props() -> void:
	var members := _room_members()
	for i in members.size():
		var member: Vector2i = members[i]
		var mc := _room_member_local(member)
		var sx := -1.0 if WorldGen.r01(wseed, member.x, member.y, 300) < 0.5 else 1.0
		var sz := -1.0 if WorldGen.r01(wseed, member.x, member.y, 301) < 0.5 else 1.0
		var machine_pos := mc + Vector3(3.7 * sx, 0, 3.7 * sz)
		if WorldGen.r01(wseed, member.x, member.y, 302) < 0.48:
			_sewer_compressor(machine_pos, atan2(-sx, -sz))
		else:
			_sewer_pump_skid(machine_pos, sx, sz, 310 + i * 8)


## Scanned/modelled compressor used to break up the repeated pump skids. The
## source scene's origin sits 4.22m behind the actual machine; compensating
## here keeps placement and collision centred on what the player sees.
func _sewer_compressor(p: Vector3, yaw: float) -> void:
	var mesh_centre := Vector3(-0.421985, 0, -4.218817)
	_cc0_prop("old_military_compressor",
		p - mesh_centre.rotated(Vector3.UP, yaw), yaw)
	_collider_yaw_box(p + Vector3(0, 0.59, 0), Vector3(0.68, 1.18, 1.75), yaw)
	var spill := _box(p + Vector3(0.18, 0.005, 0.08),
		Vector3(1.0, 0.01, 1.5), Mats.puddle(), false)
	spill.rotation.y = yaw


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


func _sewer_dry_props() -> void:
	var bx := 2.0 + 1.5 * _r(88)
	var bz := 2.0 + 1.5 * _r(89)
	if _r(90) < 0.5:
		bx = S - bx
	if _r(91) < 0.5:
		bz = S - bz
	_barrel(Vector3(bx, 0, bz))
	if _r(92) < 0.7:
		_barrel(Vector3(bx + 0.72, 0, bz + 0.25))
	if _r(93) < 0.5:
		_barrel(Vector3(bx - 0.3, 0, bz + 0.78))
	# workmen's junk that never got hauled out
	if _r(94) < 0.5:
		var cyaw := _r(95) * TAU
		var crate_name := "wooden_crate_01" if _r(189) < 0.45 else "wooden_crate_02"
		_cc0_prop(crate_name, Vector3(bx + 0.6, 0, bz - 1.3), cyaw)
		var crate_size := Vector3(0.86, 0.38, 0.44) if crate_name == "wooden_crate_01" \
			else Vector3(0.55, 0.47, 1.17)
		_collider_yaw_box(Vector3(bx + 0.6, crate_size.y * 0.5, bz - 1.3), crate_size, cyaw)
	if _r(180) < 0.4:
		var tp := Vector3(S - bx, 0.085, bz + (_r(181) - 0.5) * 3.0)
		var tyre := _cc0_prop("old_tyre", tp, _r(182) * TAU)
		tyre.rotation.x = PI / 2.0
		_collider_cyl(tp, 0.32, 0.18)
	if _r(183) < 0.35:
		_cc0_prop("trashbag", Vector3(bx - 1.1, 0, bz - 0.5), _r(184) * TAU)
	if _r(185) < 0.3:
		var lyaw := _r(186) * TAU
		_cc0_prop("wooden_ladder", Vector3(S - bx, 0, S - bz), lyaw)
		_collider_yaw_box(Vector3(S - bx, 0.65, S - bz), Vector3(1.0, 1.35, 0.55), lyaw)
	if _r(187) < 0.3:
		_cc0_prop("plastic_crate_03", Vector3(bx + 1.4, 0, bz + 1.1), _r(188) * TAU)
		_collider_box(Vector3(bx + 1.4, 0.13, bz + 1.1), Vector3(0.5, 0.27, 0.28))
	# More than one generation of maintenance debris: a stove, loose wheel rim
	# or hand lantern appears in the driest rooms, never in the water channel.
	if _r(190) < 0.24:
		var sp := Vector3(S - bx, 0, 2.0 if bz > 6.0 else 10.0)
		_cc0_prop("barrel_stove", sp, _r(191) * TAU)
		_collider_cyl(sp + Vector3(0, 0.43, 0), 0.32, 0.86)
	if _r(192) < 0.34:
		var rim_name := "rusted_wheel_rim_01" if _r(193) < 0.5 else "rusted_wheel_rim_02"
		var rp := Vector3(2.0 if bx > 6.0 else 10.0, 0.18, S - bz)
		var rim := _cc0_prop(rim_name, rp, _r(194) * TAU)
		rim.rotation.x = PI / 2.0
	if _r(195) < 0.28:
		var lp := Vector3(bx + 0.4, 0.48, bz - 0.2)
		_cc0_prop("Lantern_01", lp, _r(196) * TAU, 1.25)
		var ll := OmniLight3D.new()
		ll.position = lp + Vector3(0, 0.15, 0)
		ll.light_color = Color(1.0, 0.54, 0.22)
		ll.light_energy = 0.28
		ll.omni_range = 3.0
		ll.shadow_enabled = false
		ll.distance_fade_enabled = true
		ll.distance_fade_begin = 12.0
		ll.distance_fade_length = 5.0
		add_child(ll)


## Landmark: four treatment pools meet beneath a huge overhead manifold. The
## existing per-cell bridges keep every basin traversable; the shared pipe
## crown and control island make the 24m reservoir read as one place.
func _sewer_cistern() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# A compact central operator island, offset so the joins between pool decks
	# remain passable on both axes.
	var console := c + Vector3(2.2, 0, 2.2)
	_rbox(console + Vector3(0, 0.62, 0), Vector3(2.4, 1.24, 1.0), Mats.iron_dark(), 0.04)
	var face := _rbox(console + Vector3(0, 1.02, -0.51), Vector3(2.2, 0.48, 0.06), Mats.pipe_green(), 0.02, false)
	face.rotation.x = -0.18
	for i in 7:
		_sphere(console + Vector3(-0.85 + 0.28 * float(i), 1.06, -0.57), 0.035,
			Mats.lamp_green() if i == 2 else Mats.lamp_red())
	_collider_box(console + Vector3(0, 0.65, 0), Vector3(2.45, 1.3, 1.05))
	# Four enormous risers feed a square manifold just below the ceiling.
	for ox in [-5.2, 5.2]:
		for oz in [-5.2, 5.2]:
			var p := c + Vector3(ox, 0, oz)
			_cyl(p + Vector3(0, ceil_h * 0.5, 0), 0.24, ceil_h, Mats.pipe_rust(), false)
			var wheel := _cc0_prop("rusted_wheel_rim_01", p + Vector3(0.28, 1.35, 0), PI / 2.0, 1.7)
			wheel.rotation.z = PI / 2.0
	for oz in [-5.2, 5.2]:
		var px := _cyl(c + Vector3(0, ceil_h - 0.42, oz), 0.22, 10.4, Mats.pipe_green(), false)
		px.rotation.z = PI / 2.0
	for ox in [-5.2, 5.2]:
		var pz := _cyl(c + Vector3(ox, ceil_h - 0.42, 0), 0.22, 10.4, Mats.pipe_green(), false)
		pz.rotation.x = PI / 2.0
	# A pair of real industrial fixtures hangs over the control island.
	for dx in [-1.1, 1.1]:
		var lamp := _cc0_prop("industrial_caged_sconce",
			console + Vector3(dx, 1.85, -0.58), 0.0, 0.58)
		lamp.rotation.x = -PI / 2.0


func _barrel(p: Vector3) -> void:
	# real drums: battered red or faded blue, picked per spot
	var mname := "Barrel_01" if WorldGen.r01(wseed, int(p.x * 7.0), int(p.z * 7.0), 96) < 0.6 else "barrel_03"
	_cc0_prop(mname, p, WorldGen.r01(wseed, int(p.x * 5.0), int(p.z * 5.0), 97) * TAU)
	_collider_cyl(p + Vector3(0, 0.46, 0), 0.32, 0.92)


func _wall_ladder() -> void:
	for dir in 4:
		if not WorldGen.edge_info(wseed, cell, dir, theme)["wall"]:
			continue
		var n := -1.0 if (dir == 0 or dir == 2) else 1.0
		var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
		var inner := plane + n * (T / 2.0)
		var along := 2.0 + 2.0 * _r(85)
		if _r(86) < 0.5:
			along = S - along
		var off := inner + n * 0.13
		for sr in [-0.22, 0.22]:
			var rp := Vector3(off, ceil_h / 2.0, along + sr) if dir < 2 else Vector3(along + sr, ceil_h / 2.0, off)
			_cyl(rp, 0.025, ceil_h - 0.1, Mats.iron_dark(), false)
		var ry := 0.35
		while ry < ceil_h - 0.2:
			var rung := _cyl(Vector3(off, ry, along) if dir < 2 else Vector3(along, ry, off), 0.02, 0.5, Mats.iron_dark(), false)
			if dir < 2:
				rung.rotation.x = PI / 2.0
			else:
				rung.rotation.z = PI / 2.0
			ry += 0.32
		var hp := Vector3(inner + n * 0.45, ceil_h - 0.02, along) if dir < 2 else Vector3(along, ceil_h - 0.02, inner + n * 0.45)
		_box(hp, Vector3(0.8, 0.06, 0.8), Mats.iron_dark(), false)
		return


## Wall-hung service pipes: long horizontal runs with brackets, flanges and
## the odd vertical branch.
func _sewer_pipes(dir: int, plane: float) -> void:
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


## Service gallery: the channel runs down a concrete slot barely two arms
## wide, pipes and cable trays on both walls, cage lamps overhead. Where a
## cross-channel passes, the walls open into rough archways.
func _sewer_gallery() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x := cdir != 2
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var perp := false
	if along_x:
		perp = WorldGen.sewer_channel(wseed, cell, 2) or WorldGen.sewer_channel(wseed, cell, 3)
	else:
		perp = WorldGen.sewer_channel(wseed, cell, 0) or WorldGen.sewer_channel(wseed, cell, 1)
	for si in 2:
		var side := -2.2 if si == 0 else 2.2
		var segs := [[-5.0, 5.0]]
		if perp:
			segs = _cut_seg(segs, -CH_CUT - 0.35, CH_CUT + 0.35)
		for sg in segs:
			var c0: float = sg[0]
			var c1: float = sg[1]
			var wc := _wp(o, Vector3((c0 + c1) / 2.0, ceil_h / 2.0, side), yw)
			var wl := _mbox(self, wc, Vector3(c1 - c0, ceil_h, 0.18), Mats.concrete())
			wl.rotation.y = yw
			_collider_yaw_box(wc, Vector3(c1 - c0, ceil_h, 0.18), yw)
		if perp:
			var lt := _mbox(self, _wp(o, Vector3(0, ceil_h - 0.4, side), yw),
				Vector3(CH_CUT * 2.0 + 0.75, 0.8, 0.18), Mats.concrete())
			lt.rotation.y = yw
			_collider_yaw_box(_wp(o, Vector3(0, ceil_h - 0.4, side), yw),
				Vector3(CH_CUT * 2.0 + 0.75, 0.8, 0.18), yw)
		# pipe runs and a cable tray on the lane face
		var inn := side - signf(side) * 0.24
		for pj in 2:
			var y := 1.9 + 0.3 * float(pj)
			var pmat: Material = Mats.pipe_rust() if _r(280 + si * 3 + pj) < 0.5 else Mats.pipe_green()
			var pp := _mcyl(self, _wp(o, Vector3(0, y, inn), yw), 0.05 + 0.03 * float(pj % 2), 9.6, pmat)
			pp.rotation = Vector3(0, yw, PI / 2.0)
		var tr := _mbox(self, _wp(o, Vector3(0, 1.45, inn), yw), Vector3(9.6, 0.05, 0.16), Mats.iron_dark())
		tr.rotation.y = yw
	# A flush service grate reconnects the two narrow banks without obstructing
	# travel along them. Keep it away from the central cross-channel opening.
	var bridge_t := -3.0 if _r(289) < 0.5 else 3.0
	_sewer_gallery_grate(o, yw, bridge_t)
	# lamps strung down the slot
	for t in [-3.0, 0.0, 3.0]:
		var lp := _wp(o, Vector3(t, 0, 0), yw)
		_cage_lamp(Vector2(lp.x, lp.z), false, t == 0.0 and _r(288) < 0.3, false)


func _sewer_gallery_grate(o: Vector3, yw: float, along: float) -> void:
	for i in 7:
		var x := along + lerpf(-0.48, 0.48, float(i) / 6.0)
		var bar := _mbox(self, _wp(o, Vector3(x, 0.045, 0), yw),
			Vector3(0.055, 0.07, 3.45), Mats.iron_dark())
		bar.rotation.y = yw
	for z in [-1.45, -0.5, 0.5, 1.45]:
		var brace := _mbox(self, _wp(o, Vector3(along, 0.025, z), yw),
			Vector3(1.08, 0.06, 0.055), Mats.pipe_rust())
		brace.rotation.y = yw
	# worn hazard paint just outside the load-bearing grate
	for ex in [-0.58, 0.58]:
		var edge := _mbox(self, _wp(o, Vector3(along + ex, 0.052, 0), yw),
			Vector3(0.055, 0.025, 3.45), Mats.lamp_amber())
		edge.rotation.y = yw
	_collider_yaw_box(_wp(o, Vector3(along, 0.04, 0), yw),
		Vector3(1.12, 0.09, 3.5), yw)


# --- sewer: lighting & sound -------------------------------------------------

func _sewer_lighting() -> void:
	var is_spawn := cell == Vector2i.ZERO
	var dead := (not is_spawn) and _r(8) < 0.06
	var flicker := (not is_spawn) and (not dead) and _r(9) < 0.22
	var spots := [Vector2(3.0, 3.2), Vector2(9.0, 3.2), Vector2(3.0, 8.8), Vector2(9.0, 8.8)]
	var i0 := int(_r(13) * 3.99)
	_cage_lamp(spots[i0], dead, flicker, true)
	_cage_lamp(spots[(i0 + 2) % 4], dead, false, false)
	if style == WorldGen.SEWER_PUMP:
		# the works always keep their own lamp burning
		_cage_lamp(Vector2(2.4, 2.4), false, false, false)
	if style == WorldGen.SEWER_BASIN:
		# a real industrial pendant over the water (visual — light is below)
		var pend := _cc0_prop("hanging_industrial_lamp", Vector3(6.0, ceil_h + 0.62, 6.0), _r(14) * TAU)
		_asy_no_shadows(pend)
	if dead:
		return
	# faint green fill so the water never crushes to black
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.5, 0.75, 0.6)
	fill.light_energy = 0.16
	fill.omni_range = 10.0
	fill.position = Vector3(6.0, 2.0, 6.0)
	fill.shadow_enabled = false
	fill.distance_fade_enabled = true
	fill.distance_fade_begin = 18.0
	fill.distance_fade_length = 8.0
	add_child(fill)


## Bare bulb in a wire cage on a conduit stem. The fixture itself never casts
## shadows — its umbra would paint giant discs on the ceiling.
func _cage_lamp(at: Vector2, dead: bool, flicker: bool, shadows: bool) -> void:
	var y := ceil_h - 0.38
	var stem := _cyl(Vector3(at.x, ceil_h - 0.17, at.y), 0.02, 0.34, Mats.iron_dark(), false)
	var cap := _cyl(Vector3(at.x, y + 0.05, at.y), 0.10, 0.09, Mats.iron_dark(), false)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bmat: StandardMaterial3D = Mats.charcoal() if dead else Mats.bulb()
	if flicker:
		bmat = Mats.bulb().duplicate()
	var bulb := _sphere(Vector3(at.x, y - 0.03, at.y), 0.055, bmat)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ty in [0.02, 0.11]:
		var tor := MeshInstance3D.new()
		tor.mesh = TOR
		tor.material_override = Mats.iron_dark()
		tor.position = Vector3(at.x, y - ty, at.y)
		tor.scale = Vector3(0.11, 0.05, 0.11)
		tor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tor)
	if dead:
		return
	var l: OmniLight3D
	if flicker:
		var fl := FlickerLight.new()
		fl.base_energy = 1.35
		fl.mats = [bmat]
		fl.rng_seed = WorldGen.h(wseed, cell.x, cell.y, 10)
		l = fl
	else:
		l = OmniLight3D.new()
		l.light_energy = 1.35
	l.light_color = Color(1.0, 0.76, 0.48)
	l.omni_range = 8.5
	# well below the cap, or its shadow umbra paints a huge disc on the ceiling
	l.position = Vector3(at.x, y - 0.34, at.y)
	l.shadow_enabled = shadows
	l.distance_fade_enabled = true
	l.distance_fade_begin = 20.0
	l.distance_fade_length = 8.0
	l.distance_fade_shadow = 14.0
	add_child(l)


func _sewer_sounds() -> void:
	var ch := _sewer_ch()
	if not (ch[0] or ch[1] or ch[2] or ch[3] or style == WorldGen.SEWER_BASIN):
		return
	var snd := SewerSounds.new()
	snd.rush_db = -10.0 if style == WorldGen.SEWER_BASIN else -16.0
	snd.position = Vector3(6.0, 0.4, 6.0)
	add_child(snd)


func _sewer_mist() -> void:
	var ch := _sewer_ch()
	if not (ch[0] or ch[1] or ch[2] or ch[3] or style == WorldGen.SEWER_BASIN):
		return
	# cold mist pooling knee-deep over the water
	if _r(266) < 0.65:
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		fv.size = Vector3(11.0, 1.5, 11.0)
		fv.position = Vector3(6.0, 0.45, 6.0)
		var fm := FogMaterial.new()
		fm.density = 0.22
		fm.albedo = Color(0.6, 0.8, 0.66)
		fv.material = fm
		add_child(fv)


const SEWER_STENCILS := ["OUTFALL 3", "SEC C-12", "PUMP 7", "LEVEL -2",
	"NO ENTRY", "DRAIN 44", "FLOW >"]


## Faded paint stencilled straight onto the concrete, decades ago.
func _sewer_stencil(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(66 + dir) - 0.5) * 6.0
	var lb := Label3D.new()
	lb.text = SEWER_STENCILS[int(_r(67 + dir) * (float(SEWER_STENCILS.size()) - 0.01))]
	lb.font_size = 150
	lb.pixel_size = 0.004
	lb.modulate = Color(0.72, 0.62, 0.28, 0.72)
	if dir < 2:
		lb.position = Vector3(inner + n * 0.02, 1.55, along)
		lb.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
	else:
		lb.position = Vector3(along, 1.55, inner + n * 0.02)
		lb.rotation.y = 0.0 if n > 0.0 else PI
	lb.rotation.z = (_r(68 + dir) - 0.5) * 0.05
	add_child(lb)


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


func _cone(base: Vector3, r: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CONE
	mi.material_override = mat
	mi.position = base + Vector3(0, h / 2.0, 0)
	mi.scale = Vector3(r / 0.5, h, r / 0.5)
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


func _air_zone_sign(salt: int) -> String:
	var zone := WorldGen.macro_zone(wseed, cell, theme)
	var labels: Array = AIR_ZONE_SIGNS[zone]
	return labels[int(_r(salt) * (float(labels.size()) - 0.01))]


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


func _collider_rot_box(pos: Vector3, size: Vector3, rot: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation = rot
	body.add_child(cs)


## Rotate a local offset into chunk space around an anchor's yaw.
func _wp(o: Vector3, local: Vector3, yaw: float) -> Vector3:
	return o + local.rotated(Vector3.UP, yaw)


## First solid edge, scanning from a hashed start — the anchor wall for gate
## glass, check-in backs and escalator mezzanines. -1 if the cell has none.
func _air_pick_wall(salt: int) -> int:
	return WorldGen.anchor_wall(wseed, cell, salt)


## Yaw that points a node's local +z at the given edge.
func _air_yaw_for(dir: int) -> float:
	match dir:
		0: return PI / 2.0
		1: return -PI / 2.0
		2: return 0.0
	return PI


func _gate_code() -> String:
	var letters := ["A", "B", "C", "D", "E"]
	return "%s%d" % [letters[int(_r(300) * 4.99)], 1 + int(_r(301) * 27.99)]


func _air_lighting() -> void:
	if style == WorldGen.AIR_TRANSIT:
		return  # transit corridors light themselves under the dropped bulkhead
	var is_spawn := cell == Vector2i.ZERO
	var dead := (not is_spawn) and _r(8) < 0.04
	var flicker := (not is_spawn) and (not dead) and _r(9) < 0.11
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.air_panel().duplicate()
	else:
		pmat = Mats.air_panel()
	# long recessed light lines running the hall
	for gx in [3.0, 9.0]:
		for gz in [2.5, 6.0, 9.5]:
			_troffer(Vector3(gx, 0, gz), Vector2(2.6, 0.22), pmat, Mats.metal_gray())
	if dead:
		return
	var light := _make_main_light(flicker, pmat, 1.7)
	light.light_color = Color(0.85, 0.91, 1.0)
	light.omni_range = 14.5
	light.position = Vector3(S / 2.0, ceil_h - 0.6, S / 2.0)
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = 18.0
	add_child(light)


## Overhead wayfinding hung from the deck above: navy backlit box, yellow
## text both sides, twin drop rods.
func _hang_sign(pos: Vector3, yaw: float, text: String, top := 0.0) -> void:
	var v := Node3D.new()
	v.position = pos
	v.rotation.y = yaw
	add_child(v)
	var w := maxf(1.6, 0.115 * float(text.length()) + 0.55)
	var rod_h := maxf(0.1, (top if top > 0.0 else ceil_h) - pos.y - 0.275)
	for sx in [-w * 0.36, w * 0.36]:
		_mcyl(v, Vector3(sx, 0.275 + rod_h / 2.0, 0), 0.016, rod_h, Mats.charcoal())
	_mrbox(v, Vector3.ZERO, Vector3(w, 0.55, 0.09), Mats.sign_navy(), 0.015)
	for sside in [-1.0, 1.0]:
		var lb := Label3D.new()
		lb.text = text
		lb.font_size = 96
		lb.pixel_size = 0.0024
		lb.modulate = Color(0.96, 0.92, 0.5)
		lb.position = Vector3(0, 0, sside * 0.055)
		lb.rotation.y = 0.0 if sside > 0.0 else PI
		v.add_child(lb)


## Built by the canonical edge owner: a wayfinding sign hung just inside the
## portal, pointing deeper into a terminal that never ends.
func _air_portal_sign(dir: int, t: float) -> void:
	if style == WorldGen.AIR_TRANSIT:
		return  # would poke through the transit bulkhead
	var txt := _air_zone_sign(345 + dir)
	if dir == 0:
		_hang_sign(Vector3(S - 0.8, AIR_DOOR + 0.6, t), PI / 2.0, txt)
	else:
		_hang_sign(Vector3(t, AIR_DOOR + 0.6, S - 0.8), 0.0, txt)


## Authored three-panel departures board. Its black display panels are left
## intact and carry the same deterministic live flight rows as the old
## generated FIDS, so the housing can change without losing world-specific data.
func _fids(parent: Node3D, lpos: Vector3, lyaw: float, big: bool, hang: bool) -> void:
	var v := Node3D.new()
	v.position = lpos
	v.rotation.y = lyaw
	v.set_meta("attributed_furnishing", "airport_departure_board")
	parent.add_child(v)
	var model_scale := AIRPORT_DEPARTURE_BOARD_BIG_SCALE if big \
		else AIRPORT_DEPARTURE_BOARD_SMALL_SCALE
	var w := AIRPORT_DEPARTURE_BOARD_UNITS.x * model_scale
	var h := AIRPORT_DEPARTURE_BOARD_UNITS.y * model_scale
	if hang:
		var rod_h := maxf(0.1, ceil_h - lpos.y - h / 2.0)
		for sx in [-w * 0.36, w * 0.36]:
			_mcyl(v, Vector3(sx, h / 2.0 + rod_h / 2.0, -0.04),
				0.016, rod_h, Mats.charcoal())
	var board := _attributed_prop_local(v, AIRPORT_DEPARTURE_BOARD_PATH,
		-AIRPORT_DEPARTURE_BOARD_CENTRE * model_scale, 0.0,
		Vector3.ONE * model_scale)
	var front_z := AIRPORT_DEPARTURE_BOARD_UNITS.z * model_scale * 0.52
	if board != null:
		board.set_meta("authored_model", "airport_departure_board")
	else:
		# A generated fallback keeps airport construction robust if the imported
		# scene is unavailable in an editor-only or stripped export.
		_mrbox(v, Vector3(0, 0, -0.045), Vector3(w, h, 0.13),
			Mats.charcoal(), 0.02)
		_mquad(v, Vector3(0, 0, 0.022), Vector2(w - 0.12, h - 0.12),
			Mats.screen_glow())
		var hd := Label3D.new()
		hd.text = "DEPARTURES"
		hd.font_size = 54 if big else 36
		hd.pixel_size = 0.0022 if big else 0.0018
		hd.modulate = Color(0.93, 0.96, 1.0)
		hd.position = Vector3(0, h / 2.0 - 0.17, 0.03)
		v.add_child(hd)
		front_z = 0.03
	var rows := 8 if big else 4
	var dest := ""
	var tim := ""
	var gate := ""
	var stat := ""
	for i in rows:
		var hsh := WorldGen.h(wseed, cell.x * 3 + i, cell.y - i, 350)
		dest += AIR_DESTS[hsh % AIR_DESTS.size()] + "\n"
		tim += "%02d:%02d\n" % [(hsh >> 3) % 24, ((hsh >> 8) % 12) * 5]
		gate += "%s%d\n" % [["A", "B", "C", "D"][(hsh >> 13) % 4], 1 + ((hsh >> 15) % 28)]
		stat += AIR_STATUS[(hsh >> 19) % AIR_STATUS.size()] + "\n"
	# Destination occupies the left panel; time and gate share the centre;
	# status sits on the right. Positions scale with both board variants.
	var xs := [-0.444, -0.031, 0.153, 0.291]
	var texts := [dest, tim, gate, stat]
	for ci in 4:
		var lb := Label3D.new()
		lb.text = texts[ci]
		lb.font_size = 40 if big else 24
		lb.pixel_size = 0.0018 if big else 0.0016
		lb.modulate = Color(1.0, 0.72, 0.18)
		lb.outline_modulate = Color(0.16, 0.08, 0.0, 0.8)
		lb.outline_size = 2
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lb.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		# Clear the model's own "All other airlines" subheader before the first
		# data row; keeping this relative preserves the spacing on both sizes.
		lb.position = Vector3(xs[ci] * w, h / 2.0 - h * 0.26, front_z)
		v.add_child(lb)


func _air_wall_fids(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 4.0
	var yaw := 0.0
	var pos: Vector3
	if dir < 2:
		yaw = PI / 2.0 if n > 0.0 else -PI / 2.0
		pos = Vector3(inner + n * 0.10, 2.5, along)
	else:
		yaw = 0.0 if n > 0.0 else PI
		pos = Vector3(along, 2.5, inner + n * 0.10)
	_fids(self, pos, yaw, false, false)


## Pair of backlit advertising lightboxes.
func _air_adboxes(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var idx := int(_r(50 + dir) * 3.99)
	for k in 2:
		var along := S / 2.0 + (float(k) - 0.5) * 3.4
		var fc := inner + n * 0.05
		if dir < 2:
			_box(Vector3(fc, 1.9, along), Vector3(0.08, 1.92, 1.32), Mats.charcoal(), false)
			var q := _quad(Vector3(fc + n * 0.045, 1.9, along), Vector2(1.2, 1.8), Mats.adbox(idx + k))
			q.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
		else:
			_box(Vector3(along, 1.9, fc), Vector3(1.32, 1.92, 0.08), Mats.charcoal(), false)
			var q := _quad(Vector3(along, 1.9, fc + n * 0.045), Vector2(1.2, 1.8), Mats.adbox(idx + k))
			q.rotation.y = 0.0 if n > 0.0 else PI


## Authored four-seat airport bank. Existing layouts asked for three to five
## generated seats; the real model keeps its designed proportions in all of
## those placements instead of being stretched to an arbitrary count.
func _seat_row(p: Vector3, yaw: float, _n: int, _salt: int) -> void:
	var body0 := body.get_child_count()
	var row := _furnishing_pivot(p, yaw, "airport_seat_row")
	row.set_meta("airport_seat_facing_yaw", yaw)
	var seats := _attributed_floor_prop(AIRPORT_SEATS_PATH, Vector3.ZERO,
		PI / 2.0, AIRPORT_SEATS_SCALE, AIRPORT_SEATS_CENTRE,
		"airport_seats", row)
	if seats == null:
		row.get_parent().remove_child(row)
		row.free()
		return
	var staged_root := seats.find_child("RootNode", true, false)
	if staged_root != null:
		for staged_name in ["Light", "Camera", "Light_001", "Light_002"]:
			var staged := staged_root.find_child(staged_name, false, false)
			if staged != null:
				staged_root.remove_child(staged)
				staged.free()
	_collider_yaw_box(p + Vector3(0, 0.414, 0),
		Vector3(2.10, 0.83, 0.62), yaw)
	_bind_furnishing_colliders(row, body0)


## One piece from the authored luggage set. The GLB was material-merged, so
## pieces are recovered by their mesh-node membership instead of by subtree.
## `backpack_only` replaces the old "lying suitcase" use with the source set's
## naturally low backpack instead of tipping a rigid case onto an arbitrary side.
func _airport_luggage_model(parent: Node3D, p: Vector3, yaw: float,
		salt: int, backpack_only := false) -> Node3D:
	var piece := 0 if backpack_only else mini(int(_r(salt) * 3.0), 2)
	var pivot := Node3D.new()
	pivot.name = "AirportLuggage"
	pivot.position = p
	pivot.rotation.y = yaw
	pivot.set_meta("attributed_furnishing", "airport_luggage")
	pivot.set_meta("airport_luggage_piece", piece)
	parent.add_child(pivot)
	var inst := _attributed_prop_local(pivot, AIRPORT_LUGGAGE_PATH,
		-AIRPORT_LUGGAGE_CENTRES[piece] * AIRPORT_LUGGAGE_SCALE, 0.0,
		Vector3.ONE * AIRPORT_LUGGAGE_SCALE)
	if inst == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return null
	inst.set_meta("authored_model", "airport_luggage")
	var keep: Array = AIRPORT_LUGGAGE_NODES[piece]
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	for found in meshes:
		var mesh_node := found as MeshInstance3D
		if not keep.has(String(mesh_node.name)):
			mesh_node.get_parent().remove_child(mesh_node)
			mesh_node.free()
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var source := mesh_node.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or not AIRPORT_LUGGAGE_BODY_MATERIALS.has(source.resource_name):
				continue
			var tinted := source.duplicate() as BaseMaterial3D
			var tint: Color = AIRPORT_LUGGAGE_PALETTE[
				mini(int(_r(salt + 19) * AIRPORT_LUGGAGE_PALETTE.size()),
					AIRPORT_LUGGAGE_PALETTE.size() - 1)]
			if source.resource_name.ends_with("_02") \
					or source.resource_name.ends_with("_streep"):
				tint = tint.lightened(0.16)
			tinted.albedo_color = tint
			mesh_node.set_surface_override_material(surface, tinted)
	return pivot


## Loose airport luggage gets a conservative physical footprint and remains an
## atomic furnishing for doorway/prop-overlap culling.
## A bag standing on the floor on its own. It is registered as a furnishing —
## not just a model with a collider — so doorway clearance can remove it and the
## prop-overlap audit can see it. Without a `furnishing_group` its colliders
## stay untagged, and untagged colliders are invisible to both.
func _airport_luggage(p: Vector3, yaw: float, salt: int,
		backpack_only := false) -> void:
	var body0 := body.get_child_count()
	var group := _furnishing_pivot(p, yaw, "airport_luggage")
	var pivot := _airport_luggage_model(group, Vector3.ZERO, 0.0, salt,
		backpack_only)
	if pivot == null:
		group.get_parent().remove_child(group)
		group.free()
		return
	var piece: int = pivot.get_meta("airport_luggage_piece")
	var collider: Vector3 = AIRPORT_LUGGAGE_COLLIDERS[piece]
	_collider_yaw_box(p + Vector3(0, collider.y * 0.5, 0), collider, yaw)
	_bind_furnishing_colliders(group, body0)


func _air_column(p: Vector2) -> void:
	# The shaft, floor shoe and ceiling cap are one structural assembly. Keeping
	# them as top-level siblings let doorway clearance remove the shaft while
	# leaving its low steel shoe behind as a mysterious "hockey puck".
	var pivot := _furnishing_pivot(Vector3(p.x, 0, p.y), 0.0, "airport_column")
	var b0 := body.get_child_count()
	_mcyl(pivot, Vector3(0, ceil_h / 2.0, 0), 0.34, ceil_h, Mats.paint_white())
	_mcyl(pivot, Vector3(0, 0.09, 0), 0.40, 0.18, Mats.steel())
	_mcyl(pivot, Vector3(0, ceil_h - 0.15, 0), 0.40, 0.3, Mats.charcoal())
	_collider_cyl(pivot.position + Vector3(0, ceil_h / 2.0, 0), 0.34, ceil_h)
	_bind_furnishing_colliders(pivot, b0)


func _air_bin(p: Vector3) -> void:
	_waste_bin(p, _r(int(p.x * 7.0 + p.z * 13.0) + 431) * TAU, "airport_bin")


## Nested baggage trolley (optionally a rank of them).
func _air_trolley(p: Vector3, yaw: float, salt: int, count := 1) -> void:
	for k in count:
		var v := Node3D.new()
		v.position = p + Vector3(0, 0, 0).rotated(Vector3.UP, yaw) + Vector3(sin(yaw), 0, cos(yaw)) * (0.55 * float(k))
		v.rotation.y = yaw
		add_child(v)
		var bs := _mbox(v, Vector3(0, 0.26, 0.05), Vector3(0.6, 0.045, 0.86), Mats.steel())
		bs.rotation.x = 0.07
		_mbox(v, Vector3(0, 0.47, 0.46), Vector3(0.58, 0.42, 0.035), Mats.steel())
		for sx in [-0.27, 0.27]:
			_mcyl(v, Vector3(sx, 0.66, -0.38), 0.02, 0.8, Mats.steel())
		var hb := _mcyl(v, Vector3(0, 1.05, -0.38), 0.022, 0.58, Mats.rubber_black())
		hb.rotation.z = PI / 2.0
		for sx in [-0.24, 0.24]:
			var wh := _mcyl(v, Vector3(sx, 0.075, 0.34), 0.075, 0.05, Mats.rubber_black())
			wh.rotation.z = PI / 2.0
		var wb := _mcyl(v, Vector3(0, 0.075, -0.34), 0.075, 0.05, Mats.rubber_black())
		wb.rotation.z = PI / 2.0
		if k == 0 and _r(salt + 7) < 0.4:
			_airport_luggage_model(v, Vector3(0, 0.285, 0.05), 0.0,
				salt + 8, true)
	var dv := Vector3(sin(yaw), 0, cos(yaw))
	var cc := p + dv * (0.275 * float(count - 1))
	_collider_yaw_box(cc + Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 1.1 + 0.55 * float(count - 1)), yaw)


## Chrome queue posts with retractable belts strung between them.
func _stanchion_line(a: Vector3, b: Vector3, n: int) -> void:
	for i in n:
		var t := float(i) / float(n - 1)
		var pp := a.lerp(b, t)
		_cyl(pp + Vector3(0, 0.49, 0), 0.028, 0.98, Mats.chrome())
		_cyl(pp + Vector3(0, 0.015, 0), 0.16, 0.03, Mats.chrome(), false)
		_cyl(pp + Vector3(0, 0.95, 0), 0.045, 0.06, Mats.charcoal(), false)
	for i in n - 1:
		var p0 := a.lerp(b, float(i) / float(n - 1)) + Vector3(0, 0.88, 0)
		var p1 := a.lerp(b, float(i + 1) / float(n - 1)) + Vector3(0, 0.88, 0)
		var bl := _beam(p0 + (p1 - p0) * 0.06, p1 - (p1 - p0) * 0.06, 0.045, Mats.rubber_black())
		bl.scale.y = 0.022
		bl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- airport: gate ------------------------------------------------------------

func _air_gate() -> void:
	var wdir := _air_pick_wall(310)
	var yw := _air_yaw_for(wdir) if wdir >= 0 else float(int(_r(311) * 3.99)) * PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var code := _gate_code()
	if wdir >= 0:
		_air_window_wall(o, yw)
	# carpet island under the lounge
	var cp := _wp(o, Vector3(0, 0.008, -1.2), yw)
	var cm := _mbox(self, cp, Vector3(10.6, 0.016, 6.6), Mats.airport_carpet())
	cm.rotation.y = yw
	# gate desk off to one side, facing the seats
	_air_gate_desk(o, yw, code)
	# Every lounge row faces the glass. A single deliberately flipped bank used
	# to make the whole gate read as randomly rotated furniture.
	var ri := 0
	for rz in [0.7, -1.1, -2.9]:
		for rx in [-1.9, 1.9]:
			_seat_row(_wp(o, Vector3(rx, 0, rz), yw), yw, 4, 313 + ri)
			ri += 1
	# a bag that never boarded
	if _r(318) < 0.55:
		_airport_luggage(_wp(o, Vector3(-2.6 + 5.2 * _r(319), 0, 1.6), yw),
			_r(320) * TAU, 321)
	if _r(330) < 0.72:
		_security_camera(_wp(o, Vector3(4.7, 3.55, 3.8), yw), yw + PI)


## Full-height glass curtain wall 2.2m inside the anchor wall; the strip
## behind it is the night: black apron, taxiway lights, a docked jetway.
func _air_window_wall(o: Vector3, yw: float) -> void:
	var W := Node3D.new()
	W.position = o
	W.rotation.y = yw
	add_child(W)
	var gz := 3.8   # glass plane, local z
	# mullions and transoms
	for mx in [-5.95, -4.0, -2.0, 0.0, 2.0, 4.0, 5.95]:
		_mbox(W, Vector3(mx, ceil_h / 2.0, gz), Vector3(0.09, ceil_h, 0.14), Mats.charcoal())
	_mbox(W, Vector3(0, 0.06, gz), Vector3(S, 0.12, 0.14), Mats.charcoal())
	_mbox(W, Vector3(0, ceil_h - 0.07, gz), Vector3(S, 0.14, 0.14), Mats.charcoal())
	for ty in [1.35, 2.9]:
		_mbox(W, Vector3(0, ty, gz), Vector3(S, 0.07, 0.10), Mats.charcoal())
	# The glass itself — one thin sheet, one collider. Airport glazing uses a
	# stronger blue-grey tint than generic decorative glass so the collision
	# plane never reads as empty air.
	var barrier_glass := _mbox(W, Vector3(0, ceil_h / 2.0, gz),
		Vector3(S - 0.1, ceil_h - 0.2, 0.024), Mats.airport_glass())
	barrier_glass.set_meta("airport_barrier_glass", true)
	barrier_glass.set_meta("barrier_alpha", 0.24)
	_collider_yaw_box(_wp(o, Vector3(0, ceil_h / 2.0, gz), yw), Vector3(S, ceil_h, 0.1), yw)
	# Two rows of ceramic manifestation dots make the full-height pane legible
	# head-on without turning the apron view into an opaque wall.
	for row_y in [1.28, 1.58]:
		for i in 16:
			var mx := -5.55 + 0.74 * float(i)
			_mrbox(W, Vector3(mx, row_y, gz - 0.018),
				Vector3(0.12, 0.045, 0.012), Mats.airport_glass_marker(), 0.012)
	# dark soffit over the strip so no interior ceiling reads as "outside"
	_mbox(W, Vector3(0, ceil_h - 0.10, 4.85), Vector3(S, 0.06, 2.15), Mats.charcoal())
	# side caps close the strip ends
	for sx in [-5.9, 5.9]:
		_mbox(W, Vector3(sx, ceil_h / 2.0, 4.85), Vector3(0.1, ceil_h, 2.1), Mats.charcoal())
		_collider_yaw_box(_wp(o, Vector3(sx, ceil_h / 2.0, 4.85), yw), Vector3(0.12, ceil_h, 2.1), yw)
	# apron floor and the night beyond
	var ap := _mbox(W, Vector3(0, 0.012, 4.9), Vector3(S, 0.022, 2.15), Mats.asphalt())
	ap.rotation.y = 0.0
	var night := _mquad(W, Vector3(0, ceil_h / 2.0, 5.82), Vector2(S, ceil_h), Mats.apron_night())
	night.rotation.y = PI
	# taxiway edge lights receding along the strip
	for i in 5:
		var lx := -5.0 + 2.5 * float(i)
		_msphere(W, Vector3(lx, 0.06, 5.3), 0.045, Mats.lamp_blue())
	for li in 2:
		var l := OmniLight3D.new()
		l.light_color = Color(0.3, 0.55, 1.0)
		l.light_energy = 0.35
		l.omni_range = 3.5
		l.position = Vector3(-2.5 + 5.0 * float(li), 0.4, 5.2)
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 16.0
		l.distance_fade_length = 8.0
		W.add_child(l)
	_air_jetway(W)
	# most gates have their aircraft still on stand
	if _r(322) < 0.6:
		_air_docked_plane(W)
	# boarding door set into the glass, sealed
	var dx := -2.6
	for jx in [dx - 0.7, dx + 0.7]:
		_mbox(W, Vector3(jx, 1.15, gz), Vector3(0.12, 2.3, 0.18), Mats.steel())
	_mbox(W, Vector3(dx, 2.36, gz), Vector3(1.52, 0.12, 0.18), Mats.steel())
	_mbox(W, Vector3(dx, 1.15, gz + 0.02), Vector3(1.3, 2.3, 0.05), Mats.charcoal())
	_mbox(W, Vector3(dx, 1.02, gz - 0.05), Vector3(0.8, 0.06, 0.05), Mats.steel())
	_mbox(W, Vector3(dx - 0.25, 1.7, gz + 0.05),
		Vector3(0.3, 0.4, 0.02), Mats.airport_glass())


## A widebody parked at the stand, seen side-on through the glass. This is a
## deliberately shallow forced-perspective diorama: the aircraft stays inside
## the sealed apron strip while the dark rear plane supplies the missing depth.
func _air_docked_plane(W: Node3D) -> void:
	# This is a shallow gate-window diorama, not real exterior space. The old
	# 2.3 m fuselage was centred on the terminal boundary and deliberately ran
	# past the side returns. In adjoining rooms its end cap and body therefore
	# appeared through solid walls as giant grey discs and tubes. Keep every
	# visible aircraft mesh wholly inside the sealed apron strip instead.
	var P := Node3D.new()
	P.set_meta("airport_apron_setpiece", "docked_plane")
	W.add_child(P)
	var fus_y := 2.3
	var fus_z := 4.88
	var fus_r := 0.88
	var fus := _mcyl(P, Vector3(0, fus_y, fus_z), fus_r, 10.5, Mats.jetway_body())
	fus.rotation.z = PI / 2.0
	fus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# cabin windows above the centreline — a scatter of them still warm
	for i in 15:
		var wx := -5.6 + 0.8 * float(i)
		if absf(wx) > 5.05:
			continue
		if _r(560 + i) < 0.25:
			continue
		var lit := _r(580 + i) < 0.4
		var wmat: Material = Mats.cabin_warm() if lit else Mats.screen_dark()
		var wnd := _mbox(P, Vector3(wx, fus_y + 0.24, fus_z - fus_r - 0.015),
			Vector3(0.10, 0.13, 0.03), wmat)
		wnd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# one engine pod slung ahead of the glassline, its wing lost in the dark
	var wing := _mbox(P, Vector3(2.6, 2.0, 5.18), Vector3(2.4, 0.1, 0.86), Mats.jetway_body())
	wing.rotation.y = 0.28
	wing.rotation.z = 0.05
	wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nac := _mcyl(P, Vector3(2.1, 1.28, 4.82), 0.44, 1.35, Mats.jetway_body())
	nac.rotation.z = PI / 2.0
	nac.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var intake := _mcyl(P, Vector3(1.40, 1.28, 4.82), 0.37, 0.05, Mats.screen_dark())
	intake.rotation.z = PI / 2.0
	intake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# anti-collision beacon flashing on the shoulder of the hull
	var bmat: StandardMaterial3D = Mats.lamp_red().duplicate()
	var bulb := _msphere(P, Vector3(0.8, fus_y + 0.76, 4.38), 0.055, bmat)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bc := Beacon.new()
	bc.mat = bmat
	bc.phase = _r(590) * 1.4
	bc.light_color = Color(1.0, 0.12, 0.08)
	bc.omni_range = 4.0
	bc.position = Vector3(0.8, fus_y + 0.72, 4.32)
	bc.shadow_enabled = false
	bc.distance_fade_enabled = true
	bc.distance_fade_begin = 20.0
	bc.distance_fade_length = 8.0
	P.add_child(bc)
	# faint spill of cabin light onto the apron below the windows
	var spill := OmniLight3D.new()
	spill.light_color = Color(1.0, 0.8, 0.55)
	spill.light_energy = 0.2
	spill.omni_range = 3.2
	spill.position = Vector3(-1.5, fus_y, 4.15)
	spill.shadow_enabled = false
	spill.distance_fade_enabled = true
	spill.distance_fade_begin = 16.0
	spill.distance_fade_length = 6.0
	P.add_child(spill)


## The jetway out on the apron: ribbed telescoping tunnel on its wheel bogie,
## rotunda at the far end, red beacon still breathing.
func _air_jetway(W: Node3D) -> void:
	var J := Node3D.new()
	J.position = Vector3(-0.8, 1.95, 5.15)
	J.rotation.y = 0.06
	J.rotation.z = 0.08
	W.add_child(J)
	var tube := _mcyl(J, Vector3.ZERO, 0.5, 5.6, Mats.jetway_body())
	tube.rotation.z = PI / 2.0
	# accordion ribs over the telescoping midsection
	for i in 7:
		var rx := -1.9 + 0.5 * float(i)
		var tor := MeshInstance3D.new()
		tor.mesh = TOR
		tor.material_override = Mats.charcoal()
		tor.position = Vector3(rx, 0, 0)
		tor.rotation.z = PI / 2.0
		tor.scale = Vector3(0.72, 0.5, 0.72)
		J.add_child(tor)
	# dark window band along the tunnel
	_mbox(J, Vector3(0.6, 0.18, 0.55), Vector3(2.6, 0.34, 0.04), Mats.screen_dark())
	# rotunda cab at the far end
	_mrbox(J, Vector3(-3.1, -0.1, 0), Vector3(1.35, 1.6, 1.5), Mats.jetway_body(), 0.08)
	_mbox(J, Vector3(-3.1, 0.25, 0), Vector3(1.4, 0.4, 1.4), Mats.screen_dark())
	# service door end nearest the glass
	_mrbox(J, Vector3(2.85, -0.05, 0), Vector3(0.95, 1.9, 1.05), Mats.jetway_body(), 0.05)
	# wheel bogie
	_mbox(J, Vector3(-1.0, -1.25, 0), Vector3(0.16, 1.7, 0.16), Mats.charcoal())
	var axle := _mcyl(J, Vector3(-1.0, -2.05, 0), 0.04, 0.6, Mats.charcoal())
	axle.rotation.x = PI / 2.0
	for sz in [-0.26, 0.26]:
		var wh := _mcyl(J, Vector3(-1.0, -2.05, sz), 0.3, 0.18, Mats.rubber_black())
		wh.rotation.x = PI / 2.0
	# anti-collision beacon
	_msphere(J, Vector3(0.4, 0.6, 0), 0.05, Mats.lamp_red())
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.15, 0.1)
	l.light_energy = 0.22
	l.omni_range = 2.6
	l.position = Vector3(0.4, 0.85, 0)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 18.0
	l.distance_fade_length = 8.0
	J.add_child(l)


func _air_gate_desk(o: Vector3, yw: float, code: String) -> void:
	var v := Node3D.new()
	v.position = _wp(o, Vector3(1.7, 0, 2.4), yw)
	v.rotation.y = yw
	add_child(v)
	_mbox(v, Vector3(0, 0.06, 0), Vector3(2.3, 0.12, 0.6), Mats.charcoal())
	_mrbox(v, Vector3(0, 0.56, 0), Vector3(2.3, 1.0, 0.58), Mats.desk_white(), 0.02)
	_mbox(v, Vector3(0, 1.08, 0), Vector3(2.36, 0.04, 0.66), Mats.steel())
	# two dead monitors on poles
	for mx in [-0.5, 0.5]:
		_mcyl(v, Vector3(mx, 1.2, 0.05), 0.02, 0.2, Mats.charcoal())
		_mrbox(v, Vector3(mx, 1.44, 0.05), Vector3(0.44, 0.3, 0.035), Mats.screen_dark(), 0.008)
	_collider_yaw_box(v.position + Vector3(0, 0.6, 0), Vector3(2.3, 1.2, 0.7), yw)
	# the lit gate sign overhead
	var sv := Node3D.new()
	sv.position = _wp(o, Vector3(1.7, 3.4, 1.7), yw)
	sv.rotation.y = yw
	add_child(sv)
	var rod_h := ceil_h - 3.4 - 0.34
	for sx in [-0.5, 0.5]:
		_mcyl(sv, Vector3(sx, 0.34 + rod_h / 2.0, 0), 0.016, rod_h, Mats.charcoal())
	_mrbox(sv, Vector3.ZERO, Vector3(1.5, 0.68, 0.1), Mats.sign_navy(), 0.015)
	for sside in [-1.0, 1.0]:
		var lb := Label3D.new()
		lb.text = "Gate %s" % code
		lb.font_size = 110
		lb.pixel_size = 0.0028
		lb.modulate = Color(0.96, 0.92, 0.5)
		lb.position = Vector3(0, 0.1, sside * 0.06)
		lb.rotation.y = 0.0 if sside > 0.0 else PI
		sv.add_child(lb)
		var st := Label3D.new()
		st.text = "FLIGHT CLOSED"
		st.font_size = 56
		st.pixel_size = 0.0024
		st.modulate = Color(1.0, 0.45, 0.25)
		st.position = Vector3(0, -0.2, sside * 0.06)
		st.rotation.y = 0.0 if sside > 0.0 else PI
		sv.add_child(st)


# --- airport: concourse -------------------------------------------------------

func _air_concourse() -> void:
	# belts run along the room's LONG axis and are cut to fit between its
	# walls, so a walkway never drives into masonry
	var span := _room_span()
	var along_x := span.x >= span.y
	var yw := 0.0 if along_x else PI / 2.0
	var run := (span.x if along_x else span.y) - 2.6
	var lat := span.y if along_x else span.x
	if run < 6.0:
		_air_hall()   # too short for a walkway; furnish it as a plain hall
		return
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var pair := _r(321) < 0.55 and lat >= 10.0
	var offs := [-1.35, 1.35] if pair else [0.0]
	var flow0 := 1.0 if _r(322) < 0.5 else -1.0
	for i in offs.size():
		_travelator(_wp(o, Vector3(0, 0, offs[i]), yw), yw,
			flow0 * (1.0 if i == 0 else -1.0), 323 + i, minf(10.4, run))
		_hang_sign(o + Vector3(0, 3.55, 0), yw + PI / 2.0,
			_air_zone_sign(326))
	# a seat row parked against the quiet side, only if there is room beside
	# the belts for it
	var side := lat / 2.0 - 1.6
	if _r(327) < 0.55 and side >= (3.4 if pair else 2.8):
		var sp := _wp(o, Vector3(0.8, 0, side * (1.0 if _r(329) < 0.5 else -1.0)), yw)
		_seat_row(sp, yw + PI / 2.0, 5, 328)
	# Clutter keeps to the margins, well clear of the belts — but the seat row
	# above is parked on that same margin, and `clut` collapses onto `side`
	# whenever the room is narrow enough, putting both on one line. Each has to
	# check the spot is free or the bag ends up standing inside the seating.
	var clut := minf(side, 4.5 if pair else 3.9)
	if clut >= 2.6:
		if _r(540) < 0.5:
			var bp := _wp(o, Vector3(-3.5 + 7.0 * _r(541), 0,
				clut * (1.0 if _r(542) < 0.5 else -1.0)), yw)
			if _floor_spot_clear(bp, 0.42, 1.0):
				_air_bin(bp)
		if _r(543) < 0.2:
			var cp := _wp(o, Vector3(-3.0 + 6.0 * _r(544), 0,
				clut * (1.0 if _r(545) < 0.5 else -1.0)), yw)
			if _floor_spot_clear(cp, 0.40, 1.0):
				_airport_luggage(cp, _r(546) * TAU, 547)


## One moving walkway: deck, animated belt, glass balustrades, and an Area3D
## that actually carries whoever stands on it.
func _travelator(p: Vector3, yaw: float, flow: float, salt: int, L := 8.4) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var BW := 1.15
	_mbox(v, Vector3(0, 0.055, 0), Vector3(L, 0.11, BW + 0.7), Mats.steel())
	var belt := _mbox(v, Vector3(0, 0.117, 0), Vector3(L - 1.0, 0.014, BW), Mats.belt())
	belt.set_instance_shader_parameter("speed", flow * 0.75)
	for e in [-1.0, 1.0]:
		var ramp := _mbox(v, Vector3(e * (L / 2.0 + 0.26), 0.048, 0), Vector3(0.64, 0.02, BW + 0.7), Mats.steel())
		ramp.rotation.z = -e * 0.16
		_mbox(v, Vector3(e * (L / 2.0 - 0.30), 0.115, 0), Vector3(0.5, 0.014, BW), Mats.caution_yellow())
	for szn in [-1.0, 1.0]:
		var z: float = szn * (BW / 2.0 + 0.16)
		_mbox(v, Vector3(0, 0.32, z), Vector3(L, 0.42, 0.06), Mats.steel())
		var bg := _mbox(v, Vector3(0, 0.78, z),
			Vector3(L - 0.3, 0.55, 0.024), Mats.airport_glass())
		bg.set_meta("airport_barrier_glass", true)
		bg.set_meta("barrier_alpha", 0.24)
		bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bh := _mrbox(v, Vector3(0, 1.08, z), Vector3(L, 0.075, 0.09), Mats.rubber_black(), 0.03)
		bh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for e in [-1.0, 1.0]:
			_mrbox(v, Vector3(e * (L / 2.0 - 0.06), 0.6, z), Vector3(0.1, 0.98, 0.09), Mats.rubber_black(), 0.04)
		_collider_yaw_box(_wp(p, Vector3(0, 0.6, z), yaw), Vector3(L, 1.25, 0.1), yaw)
	# deck + end ramps the player can actually walk up
	_collider_yaw_box(p + Vector3(0, 0.065, 0), Vector3(L - 0.9, 0.13, BW + 0.5), yaw)
	for e in [-1.0, 1.0]:
		_collider_rot_box(_wp(p, Vector3(e * (L / 2.0 + 0.22), 0.05, 0), yaw),
			Vector3(0.95, 0.035, BW + 0.5), Vector3(0, yaw, -e * 0.16))
	var tv := Travelator.new()
	tv.dirv = Vector3(flow, 0, 0).rotated(Vector3.UP, yaw)
	tv.speed = 0.75
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(L - 1.6, 1.6, BW)
	cs.shape = sh
	tv.add_child(cs)
	tv.position = p + Vector3(0, 0.95, 0)
	tv.rotation.y = yaw
	add_child(tv)


## Transit corridor: three chained walkways in a complete low tube. Side room
## connections get finished portals into a narrow walking margin; every other
## stretch is continuous wall, so there is no cell-end route behind a facade.
func _air_transit() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x: bool
	if cdir != 0:
		along_x = cdir == 1
	else:
		along_x = WorldGen.r01(wseed, 0, cell.y, 511) < 0.5
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var wall_half := 5.2
	var wh := 3.5
	for k in 3:
		var off := (float(k) - 1.0) * 3.4
		var flow := 1.0 if k % 2 == 0 else -1.0
		_travelator(_wp(o, Vector3(0, 0, off), yw), yw, flow, 512 + k, 10.4)

	# A single architectural contract drives wall cuts, returns and dressing.
	for si in 2:
		var data := _air_transit_side_data(si, along_x, wall_half)
		_air_transit_wall_side(o, yw, float(data["side"]), wh, data["bay"])
		if _r(530 + si) < 0.62:
			var at := _air_transit_ad_t(si, data["bay"])
			if at < 90.0:
				var side: float = data["side"] - signf(float(data["side"])) * 0.1
				var q := _mquad(self, _wp(o, Vector3(at, 1.9, side), yw),
					Vector2(1.2, 1.8), Mats.adbox(int(_r(534 + si) * 3.99)))
				q.rotation.y = yw + (PI if side > 0.0 else 0.0)

	# The dropped lid now reaches the continuous walls. Side portal helpers add
	# their own small ceiling patches over the remaining boundary recess.
	var sof := _mbox(self, _wp(o, Vector3(0, wh + 0.06, 0), yw),
		Vector3(S, 0.12, wall_half * 2.0 + T), Mats.airport_ceiling())
	sof.rotation.y = yw
	# Low light lines under the bulkhead — the tall terminal above stays dark.
	var pmat := Mats.air_panel()
	for li in 2:
		var lane := -1.7 if li == 0 else 1.7
		for t in [-3.0, 0.0, 3.0]:
			var st := _mbox(self, _wp(o, Vector3(t, wh - 0.03, lane), yw),
				Vector3(2.2, 0.05, 0.16), pmat)
			st.rotation.y = yw
	var l := OmniLight3D.new()
	l.light_color = Color(0.85, 0.91, 1.0)
	l.light_energy = 1.2
	l.omni_range = 11.0
	l.position = o + Vector3(0, wh - 0.5, 0)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 22.0
	l.distance_fade_length = 8.0
	add_child(l)
	# Wayfinding over the two genuine walking lanes, tucked under the lid.
	for ki in 2:
		var sl := -1.7 if ki == 0 else 1.7
		if _r(516 + ki) < 0.55:
			_hang_sign(_wp(o, Vector3(0, 2.8, sl), yw), yw + PI / 2.0,
					_air_zone_sign(518 + ki), wh)


func _air_transit_side_data(si: int, along_x: bool, wall_half: float) -> Dictionary:
	var side := -wall_half if si == 0 else wall_half
	var sdir := (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
	var info := WorldGen.edge_info(wseed, cell, sdir, theme)
	var bay := []
	if not info["wall"]:
		var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
		var bw := clampf(float(info["w"]) + 0.3, 4.1, 6.5)
		bay = [bt, bw]
	return {"side": side, "bay": bay}


func _air_transit_wall_side(o: Vector3, yw: float, side: float,
		wh: float, bay: Array) -> void:
	var segs := [[-6.0, 6.0]]
	if not bay.is_empty():
		segs = _cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_air_transit_wall_run(o, yw, side, wh, float(sg[0]), float(sg[1]))
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_air_transit_header(o, yw, side, wh, bt, bw)
		_air_transit_open_casing(o, yw, side, bt, bw)
		_air_transit_bay_returns(o, yw, side, wh, bt, bw)


## Full-length wall run with modular aluminium reveals, a stainless kick plate
## and a baggage-cart bumper rail. Segmentation matches its collider exactly.
func _air_transit_wall_run(o: Vector3, yw: float, side: float,
		wh: float, a: float, b: float) -> void:
	var ln := b - a
	if ln < 0.04:
		return
	var c := (a + b) * 0.5
	var wc := _wp(o, Vector3(c, wh * 0.5, side), yw)
	var wall := _mbox(self, wc, Vector3(ln, wh, T),
		Mats.airport_wall_variant(_finish_variant()))
	wall.rotation.y = yw
	_collider_yaw_box(wc, Vector3(ln, wh, T), yw)
	var inn := side - signf(side) * (T * 0.5 + 0.022)
	var kick := _mbox(self, _wp(o, Vector3(c, 0.11, inn), yw),
		Vector3(ln, 0.22, 0.045), Mats.steel())
	kick.rotation.y = yw
	var bumper := _mbox(self, _wp(o, Vector3(c, 0.78, inn - signf(side) * 0.02), yw),
		Vector3(ln, 0.055, 0.075), Mats.rubber_black())
	bumper.rotation.y = yw
	for seam in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		if seam <= a + 0.05 or seam >= b - 0.05:
			continue
		var reveal := _mbox(self, _wp(o, Vector3(seam, wh * 0.5, inn), yw),
			Vector3(0.028, wh, 0.035), Mats.metal_gray())
		reveal.rotation.y = yw


func _air_transit_header(o: Vector3, yw: float, side: float,
		wh: float, t: float, width: float) -> void:
	var hh := wh - AIR_DOOR
	if hh <= 0.02:
		return
	var hp := _wp(o, Vector3(t, AIR_DOOR + hh * 0.5, side), yw)
	var head := _mbox(self, hp, Vector3(width, hh, T),
		Mats.airport_wall_variant(_finish_variant()))
	head.rotation.y = yw
	_collider_yaw_box(hp, Vector3(width, hh, T), yw)


func _air_transit_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn := side - signf(side) * (T * 0.5 + 0.025)
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb := _mbox(self, _wp(o, Vector3(edge, AIR_DOOR * 0.5, inn), yw),
			Vector3(0.2, AIR_DOOR, T + 0.2), Mats.steel())
		jamb.rotation.y = yw
	var lintel := _mbox(self, _wp(o, Vector3(t, AIR_DOOR + 0.1, inn), yw),
		Vector3(width + 0.22, 0.2, T + 0.2), Mats.steel())
	lintel.rotation.y = yw
	# Small backlit identifier fixed to the portal head, facing the transit lane.
	var v := Node3D.new()
	v.position = _wp(o, Vector3(t, AIR_DOOR - 0.16, inn - signf(side) * 0.04), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	add_child(v)
	_mrbox(v, Vector3.ZERO, Vector3(minf(width - 0.35, 2.35), 0.23, 0.05),
		Mats.sign_navy(), 0.008)
	var lb := Label3D.new()
	lb.text = "CONCOURSE ACCESS"
	lb.font_size = 42
	lb.pixel_size = 0.00165
	lb.modulate = Color(0.96, 0.92, 0.5)
	lb.position = Vector3(0, 0, 0.031)
	v.add_child(lb)


## Short returns link the low transit shell to the actual cell-edge portal.
## They close the sliver behind adjacent panels and roof the recess at 3.5m.
func _air_transit_bay_returns(o: Vector3, yw: float, side: float,
		wh: float, t: float, width: float) -> void:
	var outer := signf(side) * (S * 0.5 - T)
	var depth := absf(outer - side)
	var dc := (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp := _wp(o, Vector3(edge, wh * 0.5, dc), yw)
		var ret := _mbox(self, wp, Vector3(T, wh, depth),
			Mats.airport_wall_variant(_finish_variant()))
		ret.rotation.y = yw
		_collider_yaw_box(wp, Vector3(T, wh, depth), yw)
		var inward := T * 0.5 + 0.022 if edge < t else -(T * 0.5 + 0.022)
		var kick := _mbox(self, _wp(o, Vector3(edge + inward, 0.11, dc), yw),
			Vector3(0.045, 0.22, depth), Mats.steel())
		kick.rotation.y = yw
	var roof := _mbox(self, _wp(o, Vector3(t, wh + 0.06, dc), yw),
		Vector3(width, 0.12, depth), Mats.airport_ceiling())
	roof.rotation.y = yw
	var bl := OmniLight3D.new()
	bl.light_color = Color(0.85, 0.91, 1.0)
	bl.light_energy = 0.48
	bl.omni_range = 4.6
	bl.position = _wp(o, Vector3(t, wh - 0.38, dc), yw)
	bl.shadow_enabled = false
	bl.distance_fade_enabled = true
	bl.distance_fade_begin = 18.0
	bl.distance_fade_length = 6.0
	add_child(bl)


func _air_transit_ad_t(si: int, bay: Array) -> float:
	var raw := -3.0 + 6.0 * _r(532 + si)
	var candidates := [raw, -3.9, 3.9, 0.0]
	if si == 1:
		candidates = [raw, 3.9, -3.9, 0.0]
	for t in candidates:
		if bay.is_empty() or absf(float(t) - float(bay[0])) >= float(bay[1]) * 0.5 + 0.9:
			return float(t)
	return 99.0


# --- airport: check-in --------------------------------------------------------

func _air_checkin() -> void:
	var wdir := _air_pick_wall(360)
	var yw := _air_yaw_for(wdir) if wdir >= 0 else ((PI / 2.0) if _r(361) < 0.5 else 0.0)
	var o := Vector3(S / 2.0, 0, S / 2.0)
	# The authored position is 4.78m wide, so a row of two fills the same span
	# three narrow generated desks used to. Falling back to the generated desk
	# restores the tighter three-desk row.
	if _prop_scene(CHECKIN_DESK_PATH) != null:
		for di in 2:
			_checkin_desk(o, yw, -2.6 + 5.2 * float(di), 365 + di * 4)
	else:
		for di in 3:
			_checkin_desk(o, yw, -3.6 + 3.6 * float(di), 365 + di * 4)
	# the big board hanging over the queue
	_fids(self, _wp(o, Vector3(0, 3.15, 1.1), yw), yw + PI, true, true)
	# serpentine of queue barriers holding a line for no one
	_stanchion_line(_wp(o, Vector3(-4.2, 0, 1.6), yw), _wp(o, Vector3(4.2, 0, 1.6), yw), 6)
	_stanchion_line(_wp(o, Vector3(4.2, 0, 0.4), yw), _wp(o, Vector3(-4.2, 0, 0.4), yw), 6)
	if _r(374) < 0.5:
		_stanchion_line(_wp(o, Vector3(-4.2, 0, -0.8), yw), _wp(o, Vector3(4.2, 0, -0.8), yw), 6)
	if _r(375) < 0.55:
		_air_trolley(_wp(o, Vector3(-4.6 + 9.2 * _r(376), 0, -2.6), yw), _r(377) * TAU, 378, 1)
	if _r(379) < 0.68:
		_security_camera(_wp(o, Vector3(4.55, 3.45, S * 0.5 - T * 0.5), yw), yw + PI)


func _checkin_desk(o: Vector3, yw: float, dx: float, salt: int) -> void:
	var authored := _prop_scene(CHECKIN_DESK_PATH) != null
	# The generated desk is a shallow counter that sat 3.55m off centre. The
	# authored position is 3.2m deep, so it stands back far enough for its belt
	# housing to reach the wall without the counter crowding the queue lane.
	var dz := 4.20 if authored else 3.55
	var b0 := body.get_child_count()
	var v := Node3D.new()
	v.position = _wp(o, Vector3(dx, 0, dz), yw)
	v.rotation.y = yw
	v.set_meta("atomic_furnishing", "airport_checkin_desk")
	v.set_meta("floor_supported", true)
	_furnishing_group_serial += 1
	v.set_meta("furnishing_group", _furnishing_group_serial)
	add_child(v)
	# The authored position supplies the counter, the agent monitor mast, the
	# baggage scale and the belt housing — the twelve primitives that used to
	# fake them are the fallback below. Its counter faces local -Z, which is
	# the queue side, matching the generated desk it replaces.
	var desk: Node3D = null
	if authored:
		desk = _attributed_prop_local(v, CHECKIN_DESK_PATH,
			-CHECKIN_DESK_CENTRE * CHECKIN_DESK_SCALE, 0.0,
			Vector3.ONE * CHECKIN_DESK_SCALE)
	if desk != null:
		v.set_meta("attributed_furnishing", "airport_checkin_desk")
		# Counter run and the belt housing behind it, as two boxes rather than
		# one: the queue side in front of the counter must stay walkable.
		_collider_yaw_box(_wp(v.position, Vector3(0, 0.58, -1.05), yw),
			Vector3(CHECKIN_DESK_W, 1.16, 1.10), yw)
		_collider_yaw_box(_wp(v.position, Vector3(0, 0.72, 0.60), yw),
			Vector3(CHECKIN_DESK_W, 1.44, 2.00), yw)
	else:
		# counter facing the queue (local -z)
		_mbox(v, Vector3(0.35, 0.06, 0), Vector3(1.9, 0.12, 0.68), Mats.charcoal())
		_mrbox(v, Vector3(0.35, 0.57, 0), Vector3(1.9, 1.02, 0.66), Mats.desk_white(), 0.02)
		_mbox(v, Vector3(0.35, 1.1, 0), Vector3(1.96, 0.04, 0.74), Mats.steel())
		_collider_yaw_box(_wp(v.position, Vector3(0.35, 0.6, 0), yw), Vector3(1.9, 1.2, 0.75), yw)
		# monitor on a pole, screen to the agent side
		_mcyl(v, Vector3(0.85, 1.55, 0.1), 0.025, 0.9, Mats.metal_gray())
		var lit := _r(salt) < 0.4
		_mrbox(v, Vector3(0.85, 2.1, 0.1), Vector3(0.5, 0.34, 0.04), Mats.screen_glow() if lit else Mats.screen_dark(), 0.008)
		if lit:
			var lb := Label3D.new()
			lb.text = "CLOSED"
			lb.font_size = 40
			lb.pixel_size = 0.002
			lb.modulate = Color(1.0, 0.5, 0.25)
			lb.position = Vector3(0.85, 2.1, 0.13)
			v.add_child(lb)
		# baggage scale and the belt that climbs into the wall housing
		_mbox(v, Vector3(-0.75, 0.17, 0.35), Vector3(0.8, 0.34, 0.95), Mats.steel())
		_mbox(v, Vector3(-0.75, 0.355, 0.35), Vector3(0.68, 0.02, 0.85), Mats.rubber_black())
		var stub := _mbox(v, Vector3(-0.75, 0.62, 1.25), Vector3(0.68, 0.05, 1.0), Mats.rubber_black())
		stub.rotation.x = -0.45
		_mbox(v, Vector3(-0.75, 1.0, 1.95), Vector3(0.92, 1.9, 0.5), Mats.steel())
		for fi in 4:
			_mbox(v, Vector3(-0.99 + 0.16 * float(fi), 1.25, 1.68), Vector3(0.14, 0.5, 0.02), Mats.rubber_black())
		_collider_yaw_box(_wp(v.position, Vector3(-0.75, 0.5, 0.8), yw), Vector3(0.9, 1.0, 2.0), yw)
	_bind_furnishing_colliders(v, b0)
	# Position number hanging above. Over the authored desk it moves a metre
	# forward, to hang over the counter rather than the belt run behind it —
	# far enough back to leave the big departures board its own airspace, and
	# 2.5m clear of the 3.55m monitor mast at the desk's other end.
	var pn := Node3D.new()
	pn.position = _wp(o, Vector3(dx + 0.35, 3.0,
		dz - (1.00 if authored else 0.0)), yw)
	pn.rotation.y = yw
	add_child(pn)
	var rod_h := ceil_h - 3.0 - 0.26
	_mcyl(pn, Vector3(0, 0.26 + rod_h / 2.0, 0), 0.014, rod_h, Mats.charcoal())
	_mrbox(pn, Vector3.ZERO, Vector3(0.5, 0.5, 0.08), Mats.sign_navy(), 0.012)
	for sside in [-1.0, 1.0]:
		var nl := Label3D.new()
		nl.text = "%02d" % (1 + (WorldGen.h(wseed, cell.x, cell.y, salt + 2) % 24))
		nl.font_size = 90
		nl.pixel_size = 0.0026
		nl.modulate = Color(0.96, 0.92, 0.5)
		nl.position = Vector3(0, 0, sside * 0.05)
		nl.rotation.y = 0.0 if sside > 0.0 else PI
		pn.add_child(nl)


# --- airport: baggage claim ---------------------------------------------------

func _air_baggage() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# This marker stays on the chunk even if doorway cleanup removes a
	# furnishing. Audits can therefore distinguish a room that never requested
	# a carousel from a requested carousel that was partially/fully culled.
	set_meta("airport_baggage_carousel_expected", true)
	# The rim, belt and centre island are one bounded furnishing. They used to
	# be unrelated top-level nodes, so doorway cleanup could remove whichever
	# outer panels crossed an approach while leaving the inner belt behind.
	# Pulling the radius inside the 3.6m protected lanes and binding the whole
	# assembly guarantees a carousel is either complete or absent.
	var body0 := body.get_child_count()
	var carousel := _furnishing_pivot(c, 0.0,
		"airport_baggage_carousel")
	carousel.set_meta("airport_carousel_complete", true)
	# RoundedBox bevel geometry extends about 0.21m beyond its nominal radial
	# half-depth, so a 2.22m centre line still grazed a lane beginning 2.40m
	# from the room centre. Keep the complete visible shell comfortably inside.
	var rim_radius := 2.05
	# static stainless rim
	var seg := 18
	for i in seg:
		var ang := TAU * float(i) / float(seg)
		var rp := Vector3(cos(ang) * rim_radius, 0.22,
			sin(ang) * rim_radius)
		var b := _mrbox(carousel, rp, Vector3(0.80, 0.44, 0.18),
			Mats.steel(), 0.015)
		b.rotation.y = -(ang + PI / 2.0)
		b.set_meta("airport_carousel_siding", true)
		var lip := _mrbox(carousel,
			rp + Vector3(cos(ang) * 0.07, 0.235,
				sin(ang) * 0.07),
			Vector3(0.82, 0.055, 0.22), Mats.steel(), 0.012)
		lip.rotation.y = -(ang + PI / 2.0)
		lip.set_meta("airport_carousel_lip", true)
	for i in 8:
		var ang := TAU * float(i) / 8.0
		_collider_yaw_box(c + Vector3(cos(ang) * rim_radius, 0.35,
			sin(ang) * rim_radius), Vector3(1.76, 0.70, 0.20),
			-(ang + PI / 2.0))
	# the bed of slats, turning forever
	var sp := Spinner.new()
	sp.speed = 0.16 if _r(379) < 0.8 else 0.0
	sp.position = Vector3(0, 0.47, 0)
	sp.set_meta("airport_carousel_belt", true)
	carousel.add_child(sp)
	var belt_radius := 1.54
	var slats := 28
	for i in slats:
		var ang := TAU * float(i) / float(slats)
		var sl := _mbox(sp, Vector3(cos(ang) * belt_radius, 0,
			sin(ang) * belt_radius), Vector3(1.20, 0.035, 0.32),
			Mats.rubber_black())
		sl.rotation.y = -ang
		sl.set_meta("airport_carousel_slat", true)
	for i in 1 + int(_r(380) * 2.0):
		var ang := _r(381 + i) * TAU
		# Luggage rides inside the outer lip and follows the belt tangent. A
		# randomly yawed case at the slat radius could overhang the protected
		# doorway lane by a few centimetres and cause cleanup to reject the
		# otherwise valid complete carousel.
		var luggage_radius := 1.25
		_airport_luggage_model(sp,
			Vector3(cos(ang) * luggage_radius, 0.019,
				sin(ang) * luggage_radius),
			-(ang + PI / 2.0) + (_r(385 + i) - 0.5) * 0.28,
			383 + i, _r(387 + i) < 0.34)
	# centre island
	_mcyl(carousel, Vector3(0, 0.5, 0), 0.90, 1.0,
		Mats.metal_gray())
	_mcone(carousel, Vector3(0, 1.0, 0), 1.0, 0.55,
		Mats.metal_gray())
	_collider_cyl(c + Vector3(0, 0.5, 0), 0.90, 1.0)
	_bind_furnishing_colliders(carousel, body0)
	# feed chute descending from the ceiling void, mouth over the belt
	var duct := _box(c + Vector3(0, 1.86, -3.43), Vector3(1.15, 0.55, 3.6), Mats.steel(), false)
	duct.rotation.x = 0.5
	_collider_rot_box(c + Vector3(0, 1.86, -3.43), Vector3(1.15, 0.55, 3.6), Vector3(0.5, 0, 0))
	_box(c + Vector3(0, 3.7, -5.0), Vector3(1.25, 2.6, 0.85), Mats.steel())
	for fi in 5:
		var fl := _box(c + Vector3(-0.44 + 0.22 * float(fi), 0.85,
			-1.54), Vector3(0.2, 0.5, 0.02),
			Mats.rubber_black(), false)
		fl.rotation.x = 0.4
	# belt number totem, still lit
	var tot := Vector3(c.x - 3.4, 0, c.z - 2.4)
	_box(tot + Vector3(0, 1.35, 0), Vector3(0.55, 2.7, 0.2), Mats.charcoal())
	_quad(tot + Vector3(0, 1.9, 0.104), Vector2(0.42, 0.6), Mats.screen_glow())
	var num := Label3D.new()
	num.text = "%d" % (1 + (WorldGen.h(wseed, cell.x, cell.y, 386) % 8))
	num.font_size = 220
	num.pixel_size = 0.0022
	num.modulate = Color(0.96, 0.92, 0.5)
	num.position = tot + Vector3(0, 1.9, 0.12)
	add_child(num)
	_hang_sign(c + Vector3(0.5, 3.6, 0.5), float(int(_r(387) * 3.99)) * PI / 2.0, "Baggage Claim")
	# trolley rank and strays
	if _r(388) < 0.7:
		_air_trolley(Vector3(1.6 + 1.2 * _r(389), 0, 1.5), (_r(390) - 0.5) * 0.4, 391, 2 + int(_r(392) * 2.0))
	if _r(393) < 0.6:
		var stray := Vector3(2.2 + 7.6 * _r(394), 0, 8.6 + 1.6 * _r(395))
		if _floor_spot_clear(stray, 0.40, 1.0):
			_airport_luggage(stray, _r(396) * TAU, 397, _r(398) < 0.5)
	if room_n >= 2:
		_air_baggage_large_dressing(c)


## Seating and trolley ranks scale with a merged baggage hall while the main
## carousel remains the visual anchor. The added islands sit outside its sweep.
func _air_baggage_large_dressing(c: Vector3) -> void:
	var span := _room_span()
	var spots := []
	if span.x > 12.1:
		spots.append(c + Vector3(-7.2, 0, 0))
		spots.append(c + Vector3(7.2, 0, 0))
	if span.y > 12.1:
		spots.append(c + Vector3(0, 0, -7.2))
		spots.append(c + Vector3(0, 0, 7.2))
	# Baggage halls have no apron window. Pick one cardinal room direction and
	# keep every island aligned to it instead of turning each toward the belt.
	var seat_yaw := float(int(_r(431) * 3.99)) * PI / 2.0
	for i in spots.size():
		var sp: Vector3 = spots[i]
		_seat_row(sp, seat_yaw, 4, 430 + i * 4)
	var tp := c + Vector3(span.x * 0.5 - 2.0, 0, -span.y * 0.5 + 2.0)
	_air_trolley(tp, PI * 0.25 + (_r(448) - 0.5) * 0.3, 449,
		2 + int(_r(450) * 1.99))
	if _r(451) < 0.75:
		_airport_luggage(tp + Vector3(-1.2, 0, 0.7), _r(452) * TAU,
			453, _r(454) < 0.4)


# --- airport: escalators ------------------------------------------------------

func _air_escalator() -> void:
	var wdir := _air_pick_wall(390)
	if wdir < 0:
		_air_hall()
		return
	var yw := _air_yaw_for(wdir)
	var o := Vector3(S / 2.0, 0, S / 2.0)
	for cx in [-1.15, 1.15]:
		_escalator_flight(o, yw, cx)
	# mezzanine landing hugging the wall
	var lp := _wp(o, Vector3(0, 2.16, 4.48), yw)
	var lm := _mbox(self, lp, Vector3(5.6, 0.18, 2.75), Mats.steel())
	lm.rotation.y = yw
	_collider_yaw_box(lp, Vector3(5.6, 0.18, 2.75), yw)
	# glass rail along the landing front, gaps at the flight mouths
	for seg in [[-2.8, -1.77], [-0.53, 0.53], [1.77, 2.8]]:
		var sc: float = (seg[0] + seg[1]) / 2.0
		var sl: float = seg[1] - seg[0]
		_air_rail(_wp(o, Vector3(sc, 0, 3.14), yw), yw + PI / 2.0, sl)
	for sxn in [-2.77, 2.77]:
		_air_rail(_wp(o, Vector3(sxn, 0, 4.48), yw), yw, 2.7)
	# roller shutter sealing whatever the mezzanine led to; a solid backing
	# panel sits behind the ribs so no light stripes the wall through the gaps
	var bk := _mbox(self, _wp(o, Vector3(0, 3.55, 5.79), yw), Vector3(4.9, 2.6, 0.05), Mats.charcoal())
	bk.rotation.y = yw
	for i in 14:
		var rb := _mbox(self, _wp(o, Vector3(0, 2.42 + 0.17 * float(i), 5.72), yw), Vector3(4.9, 0.155, 0.06), Mats.metal_gray())
		rb.rotation.y = yw
		rb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for gxn in [-2.5, 2.5]:
		var gd := _mbox(self, _wp(o, Vector3(gxn, 3.55, 5.72), yw), Vector3(0.14, 2.6, 0.12), Mats.charcoal())
		gd.rotation.y = yw
		gd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_collider_yaw_box(_wp(o, Vector3(0, 3.55, 5.72), yw), Vector3(5.2, 2.7, 0.15), yw)
	var cl := Label3D.new()
	cl.text = "CLOSED FOR MAINTENANCE"
	cl.font_size = 40
	cl.pixel_size = 0.002
	cl.modulate = Color(0.85, 0.85, 0.85, 0.8)
	cl.position = _wp(o, Vector3(0, 3.3, 5.62), yw)
	cl.rotation.y = yw + PI
	add_child(cl)
	# support columns under the landing lip
	for sxn in [-2.5, 2.5]:
		var scp := _wp(o, Vector3(sxn, 1.05, 3.3), yw)
		_cyl(scp, 0.11, 2.1, Mats.steel())
	# out-of-service barrier across one flight
	var bx := -1.15 if _r(399) < 0.5 else 1.15
	_stanchion_line(_wp(o, Vector3(bx - 0.6, 0, -2.3), yw), _wp(o, Vector3(bx + 0.6, 0, -2.3), yw), 2)


## Landing-edge glass rail segment, centred at p, running along local x.
func _air_rail(p: Vector3, yaw: float, ln: float) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var gl := _mbox(v, Vector3(0, 2.72, 0), Vector3(ln, 0.9, 0.028), Mats.glass_tint())
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hr := _mrbox(v, Vector3(0, 3.2, 0), Vector3(ln + 0.05, 0.07, 0.08), Mats.rubber_black(), 0.03)
	hr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_collider_yaw_box(p + Vector3(0, 2.85, 0), Vector3(ln, 1.3, 0.1), yaw)


## One frozen escalator flight rising toward local +z from z -1.1 to the
## landing at z 3.1, y 2.25. Steps are dressing; a hidden slope does the work.
func _escalator_flight(o: Vector3, yw: float, cx: float) -> void:
	var v := Node3D.new()
	v.position = _wp(o, Vector3(cx, 0, 0), yw)
	v.rotation.y = yw
	add_child(v)
	var ang := 0.475   # atan2(2.25, 4.38)
	# steps
	for i in 12:
		var sy := 0.1875 * float(i + 1)
		var sz := -1.1 + 0.36 * float(i) + 0.18
		_mbox(v, Vector3(0, sy - 0.11, sz), Vector3(1.0, 0.22, 0.38), Mats.charcoal())
		_mbox(v, Vector3(0, sy - 0.008, sz + 0.155), Vector3(0.96, 0.014, 0.05), Mats.caution_yellow())
	# landing plates
	_mbox(v, Vector3(0, 0.03, -1.62), Vector3(1.24, 0.06, 0.75), Mats.steel())
	_mbox(v, Vector3(0, 2.22, 3.03), Vector3(1.24, 0.07, 0.5), Mats.steel())
	# balustrades: skirt, tinted glass, black handrail. The thin pieces never
	# cast shadows — the room light would smear them into long streaks across
	# the walls.
	for sxn in [-0.62, 0.62]:
		var sk := _mbox(v, Vector3(sxn, 1.23, 0.95), Vector3(0.07, 0.5, 5.1), Mats.steel())
		sk.rotation.x = -ang
		var gl := _mbox(v, Vector3(sxn, 1.78, 0.95), Vector3(0.026, 0.75, 4.85), Mats.glass_tint())
		gl.rotation.x = -ang
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hr := _mrbox(v, Vector3(sxn, 2.2, 0.95), Vector3(0.085, 0.075, 5.15), Mats.rubber_black(), 0.03)
		hr.rotation.x = -ang
		hr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# horizontal handrail stubs at both ends
		var s1 := _mrbox(v, Vector3(sxn, 0.98, -1.75), Vector3(0.085, 0.075, 0.6), Mats.rubber_black(), 0.03)
		s1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var s2 := _mrbox(v, Vector3(sxn, 3.2, 3.35), Vector3(0.085, 0.075, 0.5), Mats.rubber_black(), 0.03)
		s2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# newel posts
		_mbox(v, Vector3(sxn, 0.5, -1.95), Vector3(0.06, 0.96, 0.06), Mats.steel())
		_mbox(v, Vector3(sxn, 2.25 + 0.47, 3.45), Vector3(0.06, 0.96, 0.06), Mats.steel())
		_collider_rot_box(_wp(v.position, Vector3(sxn, 1.75, 0.95), yw),
			Vector3(0.1, 1.6, 5.1), Vector3(-ang, yw, 0))
	# truss cladding underneath
	var tr := _mbox(v, Vector3(0, 0.52, 0.95), Vector3(1.36, 0.4, 5.15), Mats.jetway_body())
	tr.rotation.x = -ang
	# the walkable slope
	_collider_rot_box(_wp(v.position, Vector3(0, 1.03, 0.95), yw),
		Vector3(1.15, 0.2, 4.95), Vector3(-ang, yw, 0))
	_collider_yaw_box(_wp(v.position, Vector3(0, 0.015, -1.62), yw), Vector3(1.24, 0.03, 0.8), yw)


# --- airport: hall & common ---------------------------------------------------

func _air_hall() -> void:
	# the overflow hall: seating for a delay that outlived its passengers
	# (a portal claims the middle of the room when one is open here)
	var span := _room_span()
	var mx := span.x / 2.0 - 2.4
	var mz := span.y / 2.0 - 2.4
	if portal_dest < 0 and _r(400) < 0.6 and mx > 0.5 and mz > 0.5:
		# rows sit square to the room and clear of its walls
		_seat_row(Vector3(S / 2.0 + (_r(401) - 0.5) * 2.0 * mx, 0,
			S / 2.0 + (_r(402) - 0.5) * 2.0 * mz),
			float(int(_r(403) * 3.99)) * PI / 2.0, 5, 404)
	if _r(405) < 0.4:
		_planter(Vector3(2.6 + 6.8 * _r(406), 0, 2.6 + 6.8 * _r(407)))
	if portal_dest < 0 and _r(408) < 0.3:
		# wet floor sign guarding a dry floor
		var p := Vector3(3.0 + 6.0 * _r(409), 0, 3.0 + 6.0 * _r(410))
		_cc0_prop("WetFloorSign_01", p, _r(411) * TAU)
		_collider_box(p + Vector3(0, 0.3, 0), Vector3(0.32, 0.62, 0.36))
	if portal_dest < 0 and _r(411) < 0.35:
		_fids(self, Vector3(2.5 + 7.0 * _r(412), 2.6, 2.5 + 7.0 * _r(413)),
			float(int(_r(414) * 3.99)) * PI / 2.0, true, true)


## Landmark: a shuttered food court. Three distinct concession fronts frame
## a sparse field of real tables; the central aisle stays clear enough to see
## the dead menu boards from the adjoining concourse.
func _air_foodcourt() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var names := ["SKYLINE GRILL", "COFFEE / TEA", "FRESH EXPRESS"]
	for i in 3:
		var x := -6.6 + 6.6 * float(i)
		var kp := c + Vector3(x, 0, -8.5)
		_rbox(kp + Vector3(0, 0.65, 0), Vector3(5.4, 1.3, 1.35), Mats.jetway_body(), 0.03)
		# Corrugated shutter, counter and a black menu strip.
		for sl in 8:
			_box(kp + Vector3(0, 1.22 + 0.22 * float(sl), 0.69),
				Vector3(5.0, 0.12, 0.04), Mats.metal_gray(), false)
		_rbox(kp + Vector3(0, 1.0, 1.0), Vector3(5.2, 0.12, 0.78), Mats.steel(), 0.025)
		_box(kp + Vector3(0, 3.45, 0.72), Vector3(4.7, 0.65, 0.08), Mats.charcoal(), false)
		var sign := Label3D.new()
		sign.text = names[i]
		sign.font_size = 96
		sign.pixel_size = 0.0025
		sign.modulate = Color(0.72, 0.88, 1.0) if i != 1 else Color(1.0, 0.72, 0.34)
		sign.position = kp + Vector3(0, 3.46, 0.78)
		add_child(sign)
		_collider_box(kp + Vector3(0, 1.3, 0), Vector3(5.5, 2.6, 1.5))
	# Four battered public tables, deliberately asymmetrical around the aisle.
	var table_offsets: Array[Vector3] = [Vector3(-5.4, 0, -1.8), Vector3(4.8, 0, -2.0),
		Vector3(-4.5, 0, 4.4), Vector3(5.6, 0, 4.0)]
	for i in 4:
		var tp: Vector3 = c + table_offsets[i]
		var yaw := (0.0 if i % 2 == 0 else PI / 2.0) + (_r(430 + i) - 0.5) * 0.15
		_cc0_prop("wooden_picnic_table", tp, yaw)
		_collider_yaw_box(tp + Vector3(0, 0.4, 0), Vector3(2.3, 0.8, 3.1), yaw)
	# Cleaning and service equipment gives the set piece a second read.
	var cartp := c + Vector3(8.0, 0, 7.6)
	_cc0_prop("CoffeeCart_01", cartp, -PI / 2.0)
	_collider_yaw_box(cartp + Vector3(0, 0.85, 0), Vector3(2.2, 1.7, 1.1), -PI / 2.0)
	var wetp := c + Vector3(0.8, 0, 5.2)
	_cc0_prop("WetFloorSign_01", wetp, _r(438) * TAU)
	_collider_box(wetp + Vector3(0, 0.3, 0), Vector3(0.32, 0.62, 0.36))
	_hang_sign(c + Vector3(0, 3.7, 6.4), 0.0, "FOOD COURT")


func _air_common() -> void:
	# structural columns in the open styles
	if style == WorldGen.AIR_CONCOURSE or style == WorldGen.AIR_HALL \
			or style == WorldGen.AIR_BAGGAGE or style == WorldGen.AIR_FOODCOURT:
		for p in [Vector2(1.7, 1.7), Vector2(10.3, 1.7), Vector2(1.7, 10.3), Vector2(10.3, 10.3)]:
			if WorldGen.r01(wseed, cell.x + int(p.x), cell.y + int(p.y), 330) < 0.5:
				_air_column(p)
	# random scatter never lands in cells with belts — a suitcase parked on a
	# moving walkway pins whoever it carries into it
	var has_belts := style == WorldGen.AIR_TRANSIT or style == WorldGen.AIR_CONCOURSE
	# Scattered floor props take a free spot rather than any spot. Dropping one
	# on a random point in the cell is how a suitcase ends up standing inside a
	# row of gate seating, which is furniture the gate placed long before this.
	if not has_belts and _r(334) < 0.5:
		var bin_p := _free_floor_spot(335, 0.42, 2.6, 1.0)
		if bin_p != Vector3.INF:
			_air_bin(bin_p)
	# a suitcase standing perfectly upright, no owner in any direction
	if not has_belts and style != WorldGen.AIR_ESCALATOR and _r(337) < 0.18:
		var case_p := _free_floor_spot(338, 0.40, 2.6, 1.0)
		if case_p != Vector3.INF:
			_airport_luggage(case_p, _r(340) * TAU, 341)
	# A low backpack from the authored set replaces the old oversized open trunk.
	if style == WorldGen.AIR_BAGGAGE and _r(345) < 0.4:
		var vsp := _free_floor_spot(346, 0.42, 2.4, 0.6)
		if vsp != Vector3.INF:
			var vsy := _r(348) * TAU
			_airport_luggage(vsp, vsy, 349, true)
	# PA speakers live in the busy styles
	var wants_pa := style == WorldGen.AIR_GATE or style == WorldGen.AIR_CHECKIN \
		or style == WorldGen.AIR_BAGGAGE or style == WorldGen.AIR_FOODCOURT
	if wants_pa and _r(342) < 0.5:
		var snd := AirportSounds.new()
		snd.position = Vector3(S / 2.0, 0, S / 2.0)
		add_child(snd)


## Usable rectangle of this room, in metres, centred on room_centre. An
## L-shaped room reports only its root cell, since that is the largest part
## guaranteed to be free of walls.
func _room_members() -> Array:
	var out := []
	# Merges only reach one cell toward -x/-z, while a 2x2 hall reaches one
	# toward +x/+z. This small scan covers every legal generated room shape.
	for mx in range(room_root.x - 1, room_root.x + 2):
		for mz in range(room_root.y - 1, room_root.y + 2):
			var candidate := Vector2i(mx, mz)
			if WorldGen.room_id(wseed, candidate) == room_root:
				out.append(candidate)
	return out


## Local furnishing-space centre of one member cell. The later room-centre
## shift maps this point back onto that cell in world space, including L rooms.
func _room_member_local(member: Vector2i) -> Vector3:
	var rc := WorldGen.room_centre(wseed, room_root)
	return Vector3(6.0 + float(member.x) * S + S / 2.0 - rc.x, 0,
		6.0 + float(member.y) * S + S / 2.0 - rc.y)


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
		wmat = _asy_wall_mat()
	elif theme == 6:
		wmat = _sch_wall_mat()
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
					_office_desk_small(p, _r(644 + idx) * TAU)
				else:
					_copier(p, 646 + idx)
			4:
				if pick < 0.5:
					_seat_row(p, airport_seat_yaw, 3, 648 + idx * 3)
				elif pick < 0.8:
					_air_bin(p)
				else:
					_airport_luggage(p, _r(645 + idx) * TAU, 652 + idx, false)
			6:
				if pick < 0.34:
					_sch_desk_row(p, PI / 2.0 if along_x else 0.0, 2, 640 + idx * 3)
				elif pick < 0.58:
					_shelf_unit(p, along_x, 642 + idx * 3)
				elif pick < 0.8:
					_sch_stack_chairs(p, _r(644 + idx) * TAU, 646 + idx)
				else:
					_sch_trolley(p, _r(645 + idx) * TAU)
			5:
				# bed runs along the partition so it cannot poke through it
				if pick < 0.4:
					_asy_bed(p, (PI / 2.0 if along_x else 0.0) + (PI if _r(650 + idx) < 0.5 else 0.0), 652 + idx)
				elif pick < 0.6:
					_asy_wheelchair(p, _r(644 + idx) * TAU)
				elif pick < 0.8:
					_asy_chair(p, _r(645 + idx) * TAU, _r(646 + idx) < 0.2)
				else:
					_asy_papers(p, 654 + idx, 5)
					_asy_medbox(p + Vector3(0.4, 0, 0.25), _r(656 + idx) * TAU)
			7:
				if pick < 0.32:
					_mall_display_table(p, _r(644 + idx) * TAU, 660 + idx)
				elif pick < 0.57:
					_mall_bench(p, _r(645 + idx) * TAU)
				elif pick < 0.80:
					_mall_shopping_cart(p, _r(645 + idx) * TAU, pick > 0.70)
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
					_chair_at(p, _r(644 + idx) * TAU, Mats.velvet())
				else:
					_sofa(p + Vector3(0, 0, 0), 1.0)
		idx += 1


## A single desk with the same authored terminal as the cubicle clusters — for
## rooms too small for a cluster.
func _office_desk_small(p: Vector3, yaw: float) -> void:
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
	_office_task_chair(p + Vector3(sin(yaw) * 0.95, 0, cos(yaw) * 0.95), yaw + PI)


# --- portals ------------------------------------------------------------------

## A swirling tear in the middle of the room, tinted for wherever it goes.
## The Area3D hands the player to main when they step in.
func _build_portal(dest: int) -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var pt := Portal.new()
	pt.dest = dest
	pt.cellv = cell
	pt.position = c
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.0, 2.3, 1.0)
	cs.shape = sh
	cs.position = Vector3(0, 1.2, 0)
	pt.add_child(cs)
	add_child(pt)
	# the swirl itself — billboard quad, scaled in-shader
	var disc := MeshInstance3D.new()
	disc.mesh = QUAD
	disc.material_override = Mats.portal(dest)
	disc.position = Vector3(0, 1.35, 0)
	disc.scale = Vector3(2.3, 2.3, 1.0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pt.add_child(disc)
	# glow pooled on the floor
	var fl := MeshInstance3D.new()
	fl.mesh = QUAD
	fl.material_override = Mats.portal_floor(dest)
	fl.position = Vector3(0, 0.03, 0)
	fl.rotation.x = -PI / 2.0
	fl.scale = Vector3(3.2, 3.2, 1.0)
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pt.add_child(fl)
	# three sparks in orbit
	var orb := Node3D.new()
	orb.position = Vector3(0, 1.35, 0)
	pt.add_child(orb)
	pt.sparks = orb
	for i in 3:
		var ang := TAU * float(i) / 3.0
		var sp := MeshInstance3D.new()
		sp.mesh = SPH
		sp.material_override = Mats.portal_spark(dest)
		sp.position = Vector3(cos(ang) * 1.15, sin(ang * 2.0) * 0.45, sin(ang) * 1.15)
		sp.scale = Vector3.ONE * 0.08
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.add_child(sp)
	# light of the other place leaking through
	var l := OmniLight3D.new()
	l.light_color = Mats.PORTAL_COLS[dest][0]
	l.light_energy = 1.1
	l.omni_range = 6.5
	l.position = Vector3(0, 1.5, 0)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 22.0
	l.distance_fade_length = 8.0
	pt.add_child(l)
	var hum := AudioStreamPlayer3D.new()
	hum.stream = SoundBank.portal_hum()
	hum.unit_size = 3.0
	hum.max_distance = 18.0
	hum.volume_db = -9.0
	hum.bus = "Hall"
	hum.autoplay = true
	hum.position = Vector3(0, 1.35, 0)
	pt.add_child(hum)


# --- vegas: grand chandelier is above; shared below --------------------------


# --- asylum ------------------------------------------------------------------
# Downloaded CC0 kit: photo textures (ambientCG) on the structure, glTF props
# (Poly Haven) for beds, wheelchairs, chairs and desks; everything the models
# don't cover — restraint tables, ECT carts, tubs, straitjackets — is built
# from primitives dressed in the same textures.

const ASY_SCRAWLS := ["LET ME OUT", "THEY LISTEN AT NIGHT", "NO ONE LEFT",
	"I AM NOT SICK", "IT WATCHES THE DOOR", "ROOM 9 ROOM 9 ROOM 9",
	"DONT SLEEP HERE", "WHERE DID EVERYONE GO", "HE COUNTS US AT NIGHT",
	"THE TREATMENT HELPS", "ALL OF US ARE STILL HERE"]
const ASY_ZONE_SIGNS := [
	["WARD 3", "WARD 7", "SOLITARY", "DAY ROOM"],
	["HYDROTHERAPY", "TREATMENT", "NO ADMITTANCE", "SURGERY"],
	["ADMISSIONS", "RECORDS", "ADMINISTRATION", "VISITORS"],
]

static var _asy_scenes := {}
static var _cc0_scenes := {}


static func _prop_scene(path: String) -> PackedScene:
	if not _prop_preloads_requested:
		return load(path) as PackedScene
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
			or status == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(path) as PackedScene
	return load(path) as PackedScene


## Instance a downloaded glTF prop. Scenes are load()-cached, so each model's
## meshes and textures exist once no matter how many chunks place it.
func _asy_model(mname: String, pos: Vector3, yaw: float) -> Node3D:
	var ps: PackedScene = _asy_scenes.get(mname)
	if ps == null:
		ps = _prop_scene("res://models/asylum/%s/%s_1k.gltf" % [mname, mname])
		_asy_scenes[mname] = ps
	var inst: Node3D = ps.instantiate()
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
			and path != CHEMISTRY_GLASSWARE_PATH:
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
		pivot.set_meta("atomic_furnishing", kind)
		pivot.set_meta("floor_supported", true)
		_furnishing_group_serial += 1
		pivot.set_meta("furnishing_group", _furnishing_group_serial)
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
func _office_task_chair(pos: Vector3, yaw: float) -> Node3D:
	var ps: PackedScene = _cc0_scenes.get("office_chair")
	if ps == null:
		ps = _prop_scene(OFFICE_CHAIR_PATH)
		_cc0_scenes["office_chair"] = ps
	var inst: Node3D = ps.instantiate()
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


func _asy_tiled_room() -> bool:
	return style == WorldGen.ASY_TREATMENT or style == WorldGen.ASY_HYDRO


func _asy_wall_mat() -> Material:
	if _asy_tiled_room():
		return Mats.asy_tile()
	return Mats.asy_wall() if _r(47) < 0.72 else Mats.asy_wall_sick()


## Slide a wall-hugging prop along wall `dir` so it cannot block the doorway —
## a bed in front of a room's only door would seal it for good.
func _asy_wall_clear(dir: int, want: float, span: float) -> float:
	var info := WorldGen.edge_info(wseed, cell, dir, theme)
	if info["wall"] or info["full_open"]:
		return want
	var t: float = info["t"]
	var hw: float = float(info["w"]) * 0.5 + 0.6 + span * 0.5
	if absf(want - t) >= hw:
		return want
	var cand := t + hw if want >= t else t - hw
	if cand < 1.2 or cand > S - 1.2:
		cand = t + hw if cand < 1.2 else t - hw
	return clampf(cand, 1.2, S - 1.2)


func _asy_sounds() -> void:
	var snd := AsylumSounds.new()
	snd.position = Vector3(S / 2.0, 1.4, S / 2.0)
	add_child(snd)


func _asy_no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_asy_no_shadows(c)


# --- asylum: lighting ---------------------------------------------------------

func _asy_lighting() -> void:
	var is_spawn := cell == Vector2i.ZERO
	var dead := (not is_spawn) and _r(8) < 0.13
	var flicker := (not is_spawn) and (not dead) and _r(9) < 0.30
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.asy_panel().duplicate()
	else:
		pmat = Mats.asy_panel()
	var pts := [Vector2(3.6, 6.0), Vector2(8.4, 6.0)]
	if style == WorldGen.ASY_CORRIDOR:
		var cdir := WorldGen.corridor(wseed, cell)
		if cdir == 1:
			pts = [Vector2(2.4, 6.0), Vector2(6.0, 6.0), Vector2(9.6, 6.0)]
		else:
			pts = [Vector2(6.0, 2.4), Vector2(6.0, 6.0), Vector2(6.0, 9.6)]
	for pt in pts:
		_asy_fixture(Vector3(pt.x, 0, pt.y), pmat)
	if dead:
		return
	var tall := ceil_h > 4.0
	var light := _make_main_light(flicker, pmat, 1.8 if tall else 1.35)
	light.light_color = Color(0.8, 0.94, 0.72)
	light.omni_range = 13.5 if tall else 11.5
	light.position = Vector3(S / 2.0, ceil_h - 0.55, S / 2.0)
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = 16.0
	add_child(light)


## Real twin-tube fixture on rusted drop rods, lens panel underneath. Thin
## fixture parts must not cast — the room omni would smear them into streaks.
func _asy_fixture(at: Vector3, pmat: Material) -> void:
	var drop := 0.22
	var y := ceil_h - drop
	var fixture := _asy_model("mounted_fluorescent_lights", Vector3(at.x, y, at.z), 0.0)
	_asy_no_shadows(fixture)
	for dz in [-0.26, 0.26]:
		var rod := _cyl(Vector3(at.x, y + drop / 2.0, at.z + dz), 0.012, drop, Mats.asy_metal(), false)
		rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lens := _box(Vector3(at.x, y - 0.045, at.z), Vector3(0.8, 0.02, 0.55), pmat, false)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- asylum: props ------------------------------------------------------------

## Rusty hospital bed frame (model) + a stained mattress most of the time.
## Ward bed. The authored frame arrives already made up — mattress, pillow and a
## sheet thrown back — so it needs none of the generated bedding below. The bare
## CC0 frame stays in the mix as a minority so a long ward does not read as one
## bed stamped twenty times.
func _asy_bed(p: Vector3, yaw: float, salt: int) -> void:
	if _r(salt + 7) < 0.76:
		# Its long axis is X; turn that onto the row's local Z.
		var authored := _attributed_floor_prop(ASY_BED_PATH, p,
			yaw + PI / 2.0, ASY_BED_SCALE, ASY_BED_CENTRE, "ward_bed")
		if authored != null:
			_collider_yaw_box(p + Vector3(0, 0.6, 0),
				Vector3(1.05, 1.2, 1.95), yaw)
			return
	_asy_model("old_bed_frame", p, yaw)
	_collider_yaw_box(p + Vector3(0, 0.6, 0), Vector3(0.95, 1.2, 2.05), yaw)
	if _r(salt) >= 0.8:
		return
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var mt := _mrbox(v, Vector3(0, 0.52, 0.03), Vector3(0.8, 0.15, 1.78), Mats.asy_cloth(), 0.05)
	mt.rotation.y = (_r(salt + 1) - 0.5) * 0.08
	if _r(salt + 2) < 0.5:
		_mrbox(v, Vector3(0, 0.63, -0.68), Vector3(0.52, 0.09, 0.34), Mats.asy_canvas(), 0.04)


## Wheeled stretcher, straps still across the mattress. The authored gurney is
## tilted half upright with a syringe left on its tray; the generated one below
## covers the rest and any import failure.
func _asy_gurney(p: Vector3, yaw: float, salt: int) -> void:
	var transport_radius := 1.05
	if not _asy_transport_clear(p, transport_radius):
		return
	if _r(salt + 11) < 0.70:
		var authored := _attributed_floor_prop(ASY_GURNEY_PATH, p,
			yaw + PI / 2.0, 1.0, ASY_GURNEY_CENTRE, "gurney")
		if authored != null:
			authored.set_meta("asylum_transport_kind", "gurney")
			authored.set_meta("asylum_transport_radius", transport_radius)
			_collider_yaw_box(p + Vector3(0, 0.55, 0),
				Vector3(0.80, 1.10, 1.90), yaw)
			return
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	v.set_meta("asylum_transport_kind", "gurney")
	v.set_meta("asylum_transport_radius", transport_radius)
	add_child(v)
	_mrbox(v, Vector3(0, 0.8, 0), Vector3(0.64, 0.05, 1.9), Mats.asy_metal(), 0.02)
	_mrbox(v, Vector3(0, 0.9, 0), Vector3(0.58, 0.13, 1.8), Mats.asy_cloth(), 0.05)
	for sz in [-0.38, 0.3]:
		_mbox(v, Vector3(0, 0.97, sz), Vector3(0.62, 0.02, 0.09), Mats.charcoal())
	for lx in [-0.26, 0.26]:
		for lz in [-0.78, 0.78]:
			_mcyl(v, Vector3(lx, 0.45, lz), 0.022, 0.72, Mats.asy_metal())
			_msphere(v, Vector3(lx, 0.07, lz), 0.07, Mats.charcoal())
	if _r(salt) < 0.4:
		# sheet hanging half off — someone left in a hurry
		var sh := _mrbox(v, Vector3(0.18, 0.78, 0.5), Vector3(0.5, 0.35, 0.03), Mats.asy_canvas(), 0.02)
		sh.rotation.z = 0.35
	_collider_yaw_box(p + Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 1.95), yaw)


## The centrepiece: a fixed restraint table, leather straps buckled shut.
func _asy_restraint_table(p: Vector3, yaw: float) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mbox(v, Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.9), Mats.asy_metal())
	_mrbox(v, Vector3(0, 0.72, 0), Vector3(0.85, 0.09, 2.0), Mats.asy_metal(), 0.02)
	_mrbox(v, Vector3(0, 0.8, 0.04), Vector3(0.74, 0.08, 1.82), Mats.asy_canvas(), 0.04)
	_mrbox(v, Vector3(0, 0.86, -0.78), Vector3(0.4, 0.07, 0.26), Mats.asy_canvas(), 0.03)
	for sz in [-0.42, 0.08, 0.56]:
		_mbox(v, Vector3(0, 0.85, sz), Vector3(0.92, 0.02, 0.1), Mats.charcoal())
		_mbox(v, Vector3(0.42, 0.85, sz), Vector3(0.06, 0.03, 0.05), Mats.steel())
	for sx in [-0.44, 0.44]:
		var strap := _mbox(v, Vector3(sx, 0.6, 0.28), Vector3(0.025, 0.34, 0.09), Mats.charcoal())
		strap.rotation.x = (0.2 if sx > 0.0 else -0.15)
	_collider_yaw_box(p + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 2.0), yaw)


## Electroshock station: instrument cart, dial box, two paddles on a wire.
func _asy_ect(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	for sy in [0.34, 0.72]:
		_mrbox(v, Vector3(0, sy, 0), Vector3(0.56, 0.03, 0.42), Mats.steel(), 0.01)
	for lx in [-0.25, 0.25]:
		for lz in [-0.17, 0.17]:
			_mcyl(v, Vector3(lx, 0.37, lz), 0.015, 0.7, Mats.chrome())
			_msphere(v, Vector3(lx, 0.05, lz), 0.05, Mats.charcoal())
	# the machine itself: a grey box, a white gauge, red pilot, bakelite dials
	_mrbox(v, Vector3(0, 0.87, 0), Vector3(0.5, 0.26, 0.34), Mats.metal_gray(), 0.02)
	var gauge := _mcyl(v, Vector3(-0.12, 0.9, 0.176), 0.06, 0.015, Mats.paint_white())
	gauge.rotation.x = PI / 2.0
	for di in 3:
		var knob := _mcyl(v, Vector3(0.06 + 0.11 * float(di), 0.84, 0.176), 0.025, 0.03, Mats.red_knob())
		knob.rotation.x = PI / 2.0
	_msphere(v, Vector3(0.18, 0.95, 0.17), 0.014, Mats.lamp_red())
	# paddles resting on the lower shelf, leads drooping back up to the box
	for px in [-0.12, 0.1]:
		_mcyl(v, Vector3(px, 0.39, 0.05), 0.05, 0.035, Mats.charcoal())
		_mcyl(v, Vector3(px, 0.42, 0.05), 0.012, 0.09, Mats.charcoal())
	# leads sagging from the paddles back up into the box
	_asy_wire(v, Vector3(-0.12, 0.46, 0.05), Vector3(-0.2, 0.87, -0.1))
	_asy_wire(v, Vector3(0.1, 0.46, 0.05), Vector3(0.2, 0.87, -0.1))
	_collider_yaw_box(p + Vector3(0, 0.5, 0), Vector3(0.62, 1.0, 0.5), yaw)


## Sagging two-segment cable between two local points.
func _asy_wire(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5 + Vector3(0, -0.14, 0.1)
	for seg in [[a, mid], [mid, b]]:
		var mi := MeshInstance3D.new()
		mi.mesh = BOX
		mi.material_override = Mats.rubber_black()
		var d: Vector3 = seg[1] - seg[0]
		var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
		mi.transform = Transform3D(Basis.looking_at(d, up), (seg[0] + seg[1]) / 2.0)
		mi.scale = Vector3(0.014, 0.014, d.length())
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## Transport props share conservative floor radii. If a later furnishing rolls
## the same spot, omit it instead of interpenetrating an earlier one.
func _asy_transport_clear(p: Vector3, radius: float) -> bool:
	for node in find_children("*", "Node3D", true, false):
		if not node.has_meta("asylum_transport_radius"):
			continue
		var other := node as Node3D
		if p.distance_to(other.position) < radius \
				+ float(other.get_meta("asylum_transport_radius")) \
				+ ASY_TRANSPORT_CLEARANCE:
			return false
	return true


func _asy_wheelchair(p: Vector3, yaw: float) -> void:
	var transport_radius := 0.70
	if not _asy_transport_clear(p, transport_radius):
		return
	var b0 := body.get_child_count()
	var pivot := _furnishing_pivot(p, yaw, "asylum_wheelchair")
	pivot.set_meta("asylum_transport_kind", "wheelchair")
	pivot.set_meta("asylum_transport_radius", transport_radius)
	var model := _asy_model("wheelchair_01", p, yaw)
	_adopt_local(pivot, model)
	_collider_yaw_box(p + Vector3(0, 0.55, 0), Vector3(0.85, 1.1, 1.1), yaw)
	_bind_furnishing_colliders(pivot, b0)


func _asy_chair(p: Vector3, yaw: float, tipped: bool) -> void:
	var ch := _asy_model("SchoolChair_01", p, yaw)
	if tipped:
		ch.position.y = 0.28
		ch.rotation.z = PI / 2.0 - 0.06
		return
	_collider_yaw_box(p + Vector3(0, 0.5, 0), Vector3(0.58, 1.0, 0.68), yaw)


func _asy_medbox(p: Vector3, yaw: float) -> void:
	_asy_model("medical_box", p, yaw)


func _asy_iv(p: Vector3) -> void:
	var yaw := _r(int(p.x * 17.0 + p.z * 3.0) + 812) * TAU
	var b0 := body.get_child_count()
	var pivot := _attributed_floor_prop(IV_DRIP_PATH, p, yaw, IV_DRIP_SCALE,
		IV_DRIP_CENTRE, "asylum_iv_stand", null, true)
	if pivot == null:
		var v := Node3D.new()
		v.position = p
		add_child(v)
		_mcyl(v, Vector3(0, 0.95, 0), 0.017, 1.9, Mats.chrome())
		_mcyl(v, Vector3(0, 0.025, 0), 0.2, 0.05, Mats.asy_metal())
		_mbox(v, Vector3(0, 1.88, 0), Vector3(0.4, 0.02, 0.02), Mats.chrome())
		_mrbox(v, Vector3(0.16, 1.68, 0), Vector3(0.13, 0.24, 0.05),
			Mats.glass_tint(), 0.02)
		_asy_wire(v, Vector3(0.16, 1.56, 0), Vector3(0.05, 0.9, 0.06))
		_collider_cyl(p + Vector3(0, 0.95, 0), 0.2, 1.9)
		return
	# The five-castor base is 0.84m across but nothing above 0.2m is wider than
	# the pole, so the collider follows the pole and lets a player's feet pass
	# between the legs rather than bouncing off a metre-wide invisible drum.
	_collider_cyl(p + Vector3(0, 1.0, 0), 0.17, 1.95)
	_bind_furnishing_colliders(pivot, b0)


## Claw-foot hydrotherapy tub; half of them still hold black water. The authored
## tub already runs down Z at 0.80 scale, so it drops straight into the row.
func _asy_tub(p: Vector3, yaw: float, salt: int) -> void:
	if _r(salt + 13) < 0.72:
		var authored := _attributed_floor_prop(ASY_BATH_PATH, p, yaw,
			ASY_BATH_SCALE, Vector3.ZERO, "hydro_bath")
		if authored != null:
			_collider_yaw_box(p + Vector3(0, 0.34, 0),
				Vector3(0.80, 0.68, 1.85), yaw)
			if _r(salt) < 0.55:
				var water := _mquad(authored, Vector3(0, 0.55, 0),
					Vector2(0.52, 1.55), Mats.puddle())
				water.rotation.x = -PI / 2.0
			return
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mrbox(v, Vector3(0, 0.36, 0), Vector3(0.8, 0.6, 1.7), Mats.paint_white(), 0.09)
	_mrbox(v, Vector3(0, 0.6, 0), Vector3(0.62, 0.18, 1.5), Mats.charcoal(), 0.05)
	# rust bleeding from the drain end
	_mbox(v, Vector3(0, 0.2, 0.83), Vector3(0.3, 0.4, 0.03), Mats.asy_metal())
	for fx in [-0.34, 0.34]:
		for fz in [-0.72, 0.72]:
			_msphere(v, Vector3(fx, 0.07, fz), 0.07, Mats.iron_dark())
	if _r(salt) < 0.55:
		var wq := _mquad(v, Vector3(0, 0.63, 0), Vector2(0.6, 1.46), Mats.puddle())
		wq.rotation.x = -PI / 2.0
	# taps
	_mcyl(v, Vector3(0.14, 0.75, -0.8), 0.025, 0.16, Mats.brass())
	_mcyl(v, Vector3(-0.14, 0.75, -0.8), 0.025, 0.16, Mats.brass())
	_collider_yaw_box(p + Vector3(0, 0.35, 0), Vector3(0.85, 0.7, 1.75), yaw)


func _asy_papers(p: Vector3, salt: int, count: int) -> void:
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


## Two-shelf castored instrument trolley. Every treatment room had one beside
## the table; this is the one nobody wheeled back.
func _asy_trolley(p: Vector3, yaw: float) -> void:
	var transport_radius := 0.62
	if not _asy_transport_clear(p, transport_radius):
		return
	var trolley := _attributed_floor_prop(ASY_TROLLEY_PATH, p, yaw, 1.0,
		ASY_TROLLEY_CENTRE, "instrument_trolley")
	if trolley == null:
		return
	trolley.set_meta("asylum_transport_kind", "trolley")
	trolley.set_meta("asylum_transport_radius", transport_radius)
	_collider_yaw_box(p + Vector3(0, 0.45, 0), Vector3(1.06, 0.92, 0.62), yaw)


## Steel scrub trough on tubular legs under three gooseneck taps. It is modelled
## down its local Z, so `yaw` runs it along a wall with the taps at the back.
func _asy_scrub_sink(p: Vector3, yaw: float) -> void:
	if _attributed_floor_prop(ASY_SCRUB_SINK_PATH, p, yaw, 1.0,
			Vector3.ZERO, "scrub_sink") == null:
		return
	_collider_yaw_box(p + Vector3(0, 0.45, 0), Vector3(0.88, 0.90, 2.22), yaw)


# --- asylum: wall decor -------------------------------------------------------

## Paper still pinned where somebody left it: forms, duty notices, one pink
## slip. The authored sheet spans 2.13m, so it wants a solid wall run.
func _asy_wall_notices(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(1180 + dir) - 0.5) * 2.6
	var y := 1.46 + (_r(1184 + dir) - 0.5) * 0.22
	var yaw := (-PI / 2.0 if dir == 0 else PI / 2.0) if dir < 2 \
		else (PI if dir == 2 else 0.0)
	var pos := Vector3(inner + n * 0.015, y, along) if dir < 2 \
		else Vector3(along, y, inner + n * 0.015)
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = yaw
	add_child(pivot)
	# The sheet is floored at export; lift its own centre onto the mount height.
	var inst := _attributed_prop_local(pivot, ASY_NOTICES_PATH,
		Vector3(0, -0.496, 0), 0.0)
	if inst == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return
	pivot.set_meta("asylum_wall_notices", true)
	_asy_no_shadows(pivot)


## A sealed hospital leaf on a genuinely solid wall. The wall stays the
## collider, so the door reads as locked for good without adding an invisible
## barrier — the same treatment the prison's authored doors get. Mounted at
## authored height, which the 3.0m asylum ceiling clears.
func _asy_locked_door_wall(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	var along := lerpf(3.2, 8.8, _r(1190 + dir))
	var yaw := (PI if dir == 0 else 0.0) if dir < 2 \
		else (PI / 2.0 if dir == 2 else -PI / 2.0)
	var pos := Vector3(inner + n * 0.03, 0, along) if dir < 2 \
		else Vector3(along, 0, inner + n * 0.03)
	var pick := WorldGen.h(wseed, cell.x, cell.y, 1194 + dir) % ASY_DOOR_PATHS.size()
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = yaw
	add_child(pivot)
	var inst := _attributed_prop_local(pivot, ASY_DOOR_PATHS[pick],
		Vector3.ZERO, ASY_DOOR_FACE_YAW[pick])
	if inst == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return
	pivot.set_meta("wall_mounted_asylum_door", true)
	pivot.set_meta("locked_facade", true)
	inst.set_meta("asylum_authored_leaf", pick)


## A straitjacket on a wall hook, straps hanging loose.
func _asy_straitjacket(dir: int, plane: float) -> void:
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 5.0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner, 0, along)
		v.rotation.y = PI / 2.0 * n
	else:
		v.position = Vector3(along, 0, inner)
		v.rotation.y = 0.0 if n > 0.0 else PI
	add_child(v)
	_mcyl(v, Vector3(0, 2.06, 0.045), 0.015, 0.09, Mats.iron_dark())
	var torso := _mrbox(v, Vector3(0, 1.6, 0.1), Vector3(0.52, 0.78, 0.15), Mats.asy_canvas(), 0.07)
	torso.rotation.z = (_r(48 + dir) - 0.5) * 0.1
	# arms wrapped across the front
	var arm := _mrbox(v, Vector3(0, 1.52, 0.185), Vector3(0.46, 0.13, 0.06), Mats.asy_canvas(), 0.04)
	arm.rotation.z = 0.28
	var arm2 := _mrbox(v, Vector3(0, 1.42, 0.2), Vector3(0.46, 0.13, 0.05), Mats.asy_canvas(), 0.04)
	arm2.rotation.z = -0.24
	for si in 3:
		var sx := -0.14 + 0.14 * float(si)
		var strap := _mbox(v, Vector3(sx, 1.02, 0.12), Vector3(0.045, 0.42, 0.015), Mats.asy_canvas())
		strap.rotation.x = (_r(50 + dir + si) - 0.5) * 0.25
		strap.rotation.z = (_r(53 + dir + si) - 0.5) * 0.2
		_mbox(v, Vector3(sx, 0.82, 0.12), Vector3(0.05, 0.03, 0.02), Mats.steel())


## Written by hand, by someone who was not well. Two hands share the walls:
## Rock Salt is the shaky block-capital marker, Caveat the fast desperate
## cursive — picked per wall so a corridor reads as years of different people.
static var _scrawl_fonts := {}


static func _scrawl_font(which: int) -> FontFile:
	var f: FontFile = _scrawl_fonts.get(which)
	if f == null:
		f = load("res://fonts/RockSalt-Regular.ttf" if which == 0
			else "res://fonts/Caveat-Regular.ttf")
		_scrawl_fonts[which] = f
	return f


func _asy_scrawl(dir: int, plane: float) -> void:
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 6.0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var lb := Label3D.new()
	lb.text = ASY_SCRAWLS[WorldGen.h(wseed, cell.x, cell.y, 55 + dir) % ASY_SCRAWLS.size()]
	# cursive runs smaller and tighter than the block marker, so it needs the
	# larger point size to end up the same height on the wall
	var hand := 0 if _r(60 + dir) < 0.55 else 1
	lb.font = _scrawl_font(hand)
	lb.font_size = 46 if hand == 0 else 86
	lb.pixel_size = 0.0035 * (1.0 + (_r(61 + dir) - 0.5) * 0.5)
	lb.width = 900.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD
	# this floor is near-black, and dark-on-dark writing may as well not exist —
	# a third of it is scratched THROUGH the paint, pale against the plaster
	var ink := _r(56 + dir)
	if ink < 0.42:
		lb.modulate = Color(0.34, 0.06, 0.05, 0.85)   # dried rust-red marker
	elif ink < 0.66:
		lb.modulate = Color(0.16, 0.15, 0.13, 0.9)    # charcoal, almost gone
	else:
		lb.modulate = Color(0.66, 0.64, 0.56, 0.92)   # scratched into the paint
	var y := 1.25 + _r(57 + dir) * 0.6
	if dir < 2:
		lb.position = Vector3(inner + n * 0.02, y, along)
		lb.rotation.y = PI / 2.0 * n
	else:
		lb.position = Vector3(along, y, inner + n * 0.02)
		lb.rotation.y = 0.0 if n > 0.0 else PI
	# a hand steadied against a wall still wanders off true
	lb.rotation.z = (_r(59 + dir) - 0.5) * 0.22
	add_child(lb)


## Cork noticeboard, duty rosters still pinned, one sheet hanging by a corner.
func _asy_noticeboard(dir: int, plane: float) -> void:
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 4.0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner, 0, along)
		v.rotation.y = PI / 2.0 * n
	else:
		v.position = Vector3(along, 0, inner)
		v.rotation.y = 0.0 if n > 0.0 else PI
	add_child(v)
	_mbox(v, Vector3(0, 1.62, 0.025), Vector3(1.2, 0.85, 0.05), Mats.darkwood())
	_mbox(v, Vector3(0, 1.62, 0.045), Vector3(1.08, 0.73, 0.02), Mats.asy_cloth())
	for i in 4:
		var px := -0.35 + 0.24 * float(i)
		if _r(60 + dir + i) < 0.75:
			var sheet := _mbox(v, Vector3(px, 1.6 + (_r(63 + i) - 0.5) * 0.3, 0.062),
				Vector3(0.16, 0.22, 0.004), Mats.box_white())
			sheet.rotation.z = (_r(66 + dir + i) - 0.5) * (0.9 if i == 2 else 0.14)


func _asy_crutches(dir: int, plane: float) -> void:
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 5.5
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner + n * 0.22, 0, along)
		v.rotation.y = PI / 2.0 * n
	else:
		v.position = Vector3(along, 0, inner + n * 0.22)
		v.rotation.y = 0.0 if n > 0.0 else PI
	add_child(v)
	# instanced under the lean node directly — reparent() needs a live tree
	var ps: PackedScene = _asy_scenes.get("vintage_crutches_01")
	if ps == null:
		ps = load("res://models/asylum/vintage_crutches_01/vintage_crutches_01_1k.gltf")
		_asy_scenes["vintage_crutches_01"] = ps
	var m: Node3D = ps.instantiate()
	m.rotation = Vector3(0.17, 0.0, 0.0)
	v.add_child(m)


# --- asylum: rooms ------------------------------------------------------------

func _asy_cell_props() -> void:
	var bx := _asy_wall_clear(3, 2.6 + 6.8 * _r(760), 1.1)
	_asy_bed(Vector3(bx, 0, 1.35), PI if _r(761) < 0.5 else 0.0, 762)
	if _r(763) < 0.45:
		var bx2 := _asy_wall_clear(2, 2.6 + 6.8 * _r(764), 1.1)
		_asy_bed(Vector3(bx2, 0, S - 1.35), PI if _r(765) < 0.5 else 0.0, 766)
	if _r(767) < 0.4:
		_asy_wheelchair(Vector3(3.0 + 6.0 * _r(768), 0, 3.5 + 5.0 * _r(769)), _r(770) * TAU)
	if _r(771) < 0.5:
		_asy_chair(Vector3(2.5 + 7.0 * _r(772), 0, 3.5 + 5.0 * _r(773)), _r(774) * TAU, _r(775) < 0.25)
	if _r(776) < 0.55:
		_asy_papers(Vector3(4.0 + 4.0 * _r(777), 0, 4.0 + 4.0 * _r(778)), 780, 6)
	if _r(781) < 0.35:
		_asy_iv(Vector3(bx + 1.3, 0, 1.6))
	if _r(782) < 0.3:
		_asy_medbox(Vector3(3.0 + 6.0 * _r(783), 0, 4.0 + 4.0 * _r(784)), _r(785) * TAU)


## Two facing rows of beds down the room's long axis — a ward nobody closed.
func _asy_ward() -> void:
	var span := _room_span()
	var long_x := span.x >= span.y
	var L := maxf(span.x, span.y)
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var nbeds := int((L - 3.0) / 2.6)
	var salt := 790
	for si in 2:
		var lat := -4.15 if si == 0 else 4.15
		for bi in nbeds:
			var along := -(L / 2.0 - 2.2) + 2.6 * float(bi) + (_r(salt) - 0.5) * 0.5
			salt += 1
			if _r(salt) < 0.18:
				salt += 3
				continue
			salt += 1
			var p := c + (Vector3(along, 0, lat) if long_x else Vector3(lat, 0, along))
			var yaw: float
			if long_x:
				yaw = 0.0 if lat > 0.0 else PI
			else:
				yaw = PI / 2.0 if lat > 0.0 else -PI / 2.0
			_asy_bed(p, yaw + (_r(salt) - 0.5) * 0.07, salt + 40)
			salt += 1
			if _r(salt) < 0.25:
				var ivoff := Vector3(1.35, 0, 0) if long_x else Vector3(0, 0, 1.35)
				_asy_iv(p + ivoff)
			salt += 1
	# Reserve distinct stations down the central aisle. These three props used
	# to roll independent positions around `c`, allowing a wheelchair to spawn
	# inside the gurney (or either transport to swallow the trolley).
	var aisle := Vector3.RIGHT if long_x else Vector3.FORWARD
	var cross := Vector3.FORWARD if long_x else Vector3.RIGHT
	var transport_yaw := PI / 2.0 if long_x else 0.0
	if _r(860) < 0.55:
		_asy_wheelchair(c - aisle * 2.4 - cross * 0.65,
			transport_yaw + (_r(863) - 0.5) * 0.16)
	if _r(864) < 0.6:
		_asy_papers(c + Vector3((_r(865) - 0.5) * 4.0, 0, (_r(866) - 0.5) * 4.0), 867, 7)
	if _r(868) < 0.35:
		_asy_gurney(c + aisle * 2.0 + cross * 0.55,
			transport_yaw + (_r(871) - 0.5) * 0.12, 872)
	# One trolley abandoned mid-round between the bed rows.
	if _r(873) < 0.42:
		_asy_trolley(c - aisle * 0.15 + cross * 1.25,
			transport_yaw + PI / 2.0 + (_r(876) - 0.5) * 0.18)


## The big common room: a therapy circle nobody dismissed, a rocking chair
## facing the wall, papers everywhere.
func _asy_dayroom() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var span := _room_span()
	var large := span.x > 12.1 or span.y > 12.1
	var base := _r(880) * TAU
	var chair_count := 11 if large else 7
	var circle_r := 4.1 if large else 2.3
	for i in chair_count:
		if _r(881 + i) < 0.2:
			continue
		var ang := base + TAU * float(i) / float(chair_count)
		var cp := c + Vector3(cos(ang) * circle_r, 0, sin(ang) * circle_r)
		var face := atan2(c.x - cp.x, c.z - cp.z)
		_asy_chair(cp, face + (_r(900 + i) - 0.5) * 0.5, _r(920 + i) < 0.15)
	if large:
		# Secondary activity islands stop the 24m dayroom reading as one chair
		# circle marooned in a warehouse-sized shell.
		_asy_dayroom_table(c + Vector3(-6.2, 0, 5.0), 940)
		_asy_dayroom_table(c + Vector3(6.2, 0, -5.0), 950)
	var rp := c + Vector3(7.6, 0, 7.9)
	var rock := _asy_model("Rockingchair_01", rp, PI * 0.83)
	rock.position.y = -0.1
	_collider_yaw_box(rp + Vector3(0, 0.5, 0), Vector3(0.72, 1.0, 0.85), PI * 0.83)
	if _r(902) < 0.6:
		_asy_wheelchair(c + Vector3(-6.2 * _r(903), 0, 5.0 * (_r(904) - 0.5)), _r(905) * TAU)
	_asy_papers(c + Vector3((_r(906) - 0.5) * 5.0, 0, (_r(907) - 0.5) * 5.0), 908, 9)
	if _r(909) < 0.5:
		_asy_gurney(c + Vector3(-5.5, 0, -5.0 * (_r(910) - 0.5)), _r(911) * TAU, 912)
	# a long-dead television would be too kind; a fallen noticeboard instead
	if _r(913) < 0.4:
		var fb := _box(c + Vector3(3.5 * (_r(914) - 0.5), 0.04, -4.5), Vector3(1.2, 0.06, 0.85), Mats.darkwood(), false)
		fb.rotation.y = _r(915) * TAU


## A scarred institutional table and three mismatched chairs, laid out as a
## smaller therapy or card-game group around the edge of a large dayroom.
func _asy_dayroom_table(c: Vector3, salt: int) -> void:
	var body0 := body.get_child_count()
	var table := _furnishing_pivot(c, 0.0, "asylum_dayroom_table")
	table.set_meta("chemistry_surface_y", 0.755)
	_mrbox(table, Vector3(0, 0.72, 0), Vector3(1.55, 0.07, 1.0),
		Mats.asy_concrete(), 0.025)
	for sx in [-0.62, 0.62]:
		for sz in [-0.36, 0.36]:
			_mcyl(table, Vector3(sx, 0.35, sz), 0.025, 0.7,
				Mats.asy_metal())
	# A minority of common-room tables retain one or two abandoned vessels.
	# Both are children of the supported table assembly, so doorway culling can
	# never leave them suspended after removing the furniture underneath.
	if _r(salt + 20) < 0.68:
		_chemistry_glassware(table, Vector3(-0.28, 0.758, 0.08),
			(_r(salt + 21) - 0.5) * 0.8, salt + 22, false,
			"asylum_dayroom")
		if _r(salt + 23) < 0.42:
			_chemistry_glassware(table, Vector3(0.32, 0.758, -0.12),
				(_r(salt + 24) - 0.5) * 0.9, salt + 25, false,
				"asylum_dayroom")
	_collider_box(c + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.05))
	_bind_furnishing_colliders(table, body0)
	for i in 3:
		var ang := TAU * float(i) / 3.0 + 0.35 + (_r(salt + i) - 0.5) * 0.2
		var cp := c + Vector3(cos(ang) * 1.25, 0, sin(ang) * 1.05)
		_asy_chair(cp, atan2(c.x - cp.x, c.z - cp.z), _r(salt + 5 + i) < 0.25)


## A compact institutional utility counter gives the treatment-room glassware
## an explicit support surface instead of balancing it on the restraint table
## or a trolley whose authored shelf height varies by model.
func _asy_chemistry_counter(p: Vector3, yaw: float, salt: int) -> void:
	var body0 := body.get_child_count()
	var counter := _furnishing_pivot(p, yaw, "asylum_chemistry_counter")
	counter.set_meta("chemistry_surface_y", 0.785)
	_mrbox(counter, Vector3(0, 0.36, 0), Vector3(1.42, 0.72, 0.52),
		Mats.asy_metal(), 0.025)
	_mrbox(counter, Vector3(0, 0.75, 0), Vector3(1.52, 0.07, 0.60),
		Mats.asy_concrete(), 0.02)
	_mbox(counter, Vector3(0, 0.92, -0.27), Vector3(1.48, 0.30, 0.035),
		Mats.asy_metal())
	_chemistry_glassware(counter, Vector3(-0.34, 0.788, 0.04),
		(_r(salt) - 0.5) * 0.65, salt + 1, false, "asylum_treatment")
	_chemistry_glassware(counter, Vector3(0.32, 0.788, -0.03),
		(_r(salt + 2) - 0.5) * 0.65, salt + 19, false,
		"asylum_treatment")
	_collider_yaw_box(p + Vector3(0, 0.39, 0),
		Vector3(1.52, 0.78, 0.60), yaw)
	_bind_furnishing_colliders(counter, body0)


func _asy_treatment() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var yaw := (PI / 2.0 if _r(920) < 0.5 else 0.0) + (_r(921) - 0.5) * 0.12
	_asy_restraint_table(c, yaw)
	var side := Vector3(cos(yaw), 0, -sin(yaw))
	_asy_ect(c + side * 1.5, yaw + PI / 2.0, 922)
	# surgical lamp aimed at the table
	_cyl(Vector3(c.x, ceil_h - 0.3, c.z), 0.02, 0.6, Mats.asy_metal(), false)
	var dish := _cyl(Vector3(c.x, ceil_h - 0.62, c.z), 0.3, 0.14, Mats.steel(), false)
	dish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sphere(Vector3(c.x, ceil_h - 0.68, c.z), 0.07, Mats.bulb())
	var sp := SpotLight3D.new()
	sp.position = Vector3(c.x, ceil_h - 0.7, c.z)
	sp.rotation.x = -PI / 2.0
	sp.spot_angle = 38.0
	sp.spot_range = ceil_h
	sp.light_energy = 4.2
	sp.light_color = Color(0.95, 1.0, 0.88)
	sp.shadow_enabled = true
	sp.distance_fade_enabled = true
	sp.distance_fade_begin = 20.0
	sp.distance_fade_length = 8.0
	add_child(sp)
	# the barber chair in the corner is somehow worse than the table
	if _r(923) < 0.6:
		var bp := Vector3(2.2, 0, 2.4)
		var byaw := _r(924) * TAU
		_asy_model("BarberShopChair_01", bp, byaw)
		_collider_yaw_box(bp + Vector3(0, 0.7, 0), Vector3(0.8, 1.5, 1.35), byaw)
	if _r(925) < 0.6:
		_asy_medbox(c + side * -1.6 + Vector3(0, 0, 0.6), _r(926) * TAU)
	# The steel autopsy table stands off to one side of the restraint table,
	# where a second table would actually have been wheeled.
	if _r(1226) < 0.48:
		var ap := c + side * -2.6 + Vector3(0, 0, -1.1)
		if _attributed_floor_prop(ASY_AUTOPSY_PATH, ap, yaw + PI / 2.0, 1.0,
				ASY_AUTOPSY_CENTRE, "autopsy_table") != null:
			_collider_yaw_box(ap + Vector3(0, 0.42, 0),
				Vector3(1.20, 0.84, 2.30), yaw + PI / 2.0)
	# The instrument trolley belongs at the table's side, within reach of it.
	if _r(1210) < 0.72:
		_asy_trolley(c + side * (1.15 if _r(1211) < 0.5 else -1.15)
			+ Vector3(0, 0, 0.85), yaw + (_r(1212) - 0.5) * 0.4)
	var chemistry_counter_pos := c + Vector3(3.65, 0, -3.65)
	_asy_chemistry_counter(chemistry_counter_pos,
		atan2(c.x - chemistry_counter_pos.x, c.z - chemistry_counter_pos.z),
		1230)
	# A scrub trough against the first solid wall, taps to the tiles. Its length
	# runs down local Z, so turn it a quarter from the facing to lie along.
	if _r(1213) < 0.55:
		for dir in 4:
			if not WorldGen.edge_info(wseed, cell, dir, theme)["wall"]:
				continue
			_asy_scrub_sink(
				_wall_pt(dir, S / 2.0 + (_r(1214) - 0.5) * 2.2, 0.62),
				_wall_facing(dir) + PI / 2.0)
			break
	_asy_papers(c + Vector3(1.8, 0, 1.6), 927, 5)
	# floor drain
	var dr := _cyl(c + Vector3(0.9 * cos(yaw), 0.006, 0.7), 0.14, 0.012, Mats.iron_dark(), false)
	dr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _asy_hydro() -> void:
	var span := _room_span()
	var long_x := span.x >= span.y
	var L := maxf(span.x, span.y)
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var ntubs := int((L - 3.0) / 2.5)
	var salt := 930
	# one row of tubs per 12m of width, offset to leave a walk lane
	var lats: Array = [-2.9, 2.9] if minf(span.x, span.y) > 12.1 else [2.6]
	for lat in lats:
		for ti in ntubs:
			var along := -(L / 2.0 - 2.4) + 2.5 * float(ti) + (_r(salt) - 0.5) * 0.3
			salt += 1
			if _r(salt) < 0.15:
				salt += 2
				continue
			salt += 1
			var p := c + (Vector3(along, 0, lat) if long_x else Vector3(lat, 0, along))
			_asy_tub(p, 0.0 if long_x else PI / 2.0, salt + 30)
			salt += 1
	for ci in 3:
		if _r(950 + ci) < 0.6:
			_chain(c + Vector3((_r(953 + ci) - 0.5) * 6.0, 0, (_r(956 + ci) - 0.5) * 6.0))
	if _r(960) < 0.5:
		_asy_wheelchair(c + Vector3(-3.5 * _r(961), 0, -3.0 * _r(962)), _r(963) * TAU)
	if _r(964) < 0.4:
		_asy_iv(c + Vector3(3.0 * (_r(965) - 0.5), 0, -2.5))
	# The trough the tubs were filled and emptied from, against a solid wall.
	if _r(1220) < 0.62:
		for dir in 4:
			if not WorldGen.edge_info(wseed, cell, dir, theme)["wall"]:
				continue
			_asy_scrub_sink(
				_wall_pt(dir, S / 2.0 + (_r(1221) - 0.5) * 3.0, 0.60),
				_wall_facing(dir) + PI / 2.0)
			break
	if _r(1222) < 0.4:
		_asy_trolley(c + Vector3((_r(1223) - 0.5) * 4.0, 0,
			(_r(1224) - 0.5) * 3.0), _r(1225) * TAU)


func _asy_office() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var yaw := [0.0, PI / 2.0, PI, -PI / 2.0][int(_r(970) * 3.99)] as float
	var dp := c + Vector3((_r(971) - 0.5) * 2.0, 0, (_r(972) - 0.5) * 2.0)
	_asy_model("metal_office_desk", dp, yaw)
	_collider_yaw_box(dp + Vector3(0, 0.4, 0), Vector3(2.0, 0.8, 0.95), yaw)
	var back := Vector3(sin(yaw), 0, cos(yaw))
	_asy_chair(dp + back * 0.95, yaw + PI + (_r(973) - 0.5) * 0.6, _r(974) < 0.3)
	_asy_medbox(dp + Vector3(0, 0.79, 0) + back * -0.1 + Vector3(cos(yaw) * 0.55, 0, -sin(yaw) * 0.55), yaw + 0.3)
	# papers drifted off the desk years ago
	_asy_papers(dp + back * 1.2, 975, 8)
	_asy_papers(c + Vector3(2.5 * (_r(976) - 0.5), 0, 2.5 * (_r(977) - 0.5)), 978, 6)
	# filing cabinets against the first solid wall
	for dir in 4:
		if WorldGen.edge_info(wseed, cell, dir, theme)["wall"]:
			_filing_bank(dir, (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0))
			break
	if _r(979) < 0.4:
		_asy_iv(c + Vector3(4.0, 0, -3.5 * (_r(980) - 0.5)))


## Landmark: an institutional chapel/assembly room. Long scarred pews point
## toward a tiny dais, while one wheelchair has been left in the centre aisle.
## The aisle itself remains a clean sightline and traversal route.
func _asy_chapel() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# Shallow dais and plain altar at the north end.
	var front := c + Vector3(0, 0, -8.0)
	_rbox(front + Vector3(0, 0.16, 0), Vector3(8.0, 0.32, 2.8), Mats.darkwood(), 0.025)
	_rbox(front + Vector3(0, 0.88, 0.1), Vector3(2.2, 1.45, 0.75), Mats.asy_concrete(), 0.035)
	_collider_box(front + Vector3(0, 0.48, 0), Vector3(8.1, 0.96, 2.9))
	# A stark wall cross; it is architecture, not a glowing quest marker.
	_box(front + Vector3(0, 3.45, -1.43), Vector3(0.30, 2.2, 0.09), Mats.darkwood(), false)
	_box(front + Vector3(0, 3.70, -1.43), Vector3(1.45, 0.28, 0.09), Mats.darkwood(), false)
	# Two banks of pews leave a generous central aisle.
	for row in 6:
		var z := -4.5 + 2.05 * float(row)
		for side in [-1.0, 1.0]:
			var p := c + Vector3(side * 3.65, 0, z)
			_rbox(p + Vector3(0, 0.54, 0), Vector3(5.6, 0.15, 0.66), Mats.darkwood(), 0.035, false)
			_rbox(p + Vector3(0, 0.92, -0.28), Vector3(5.6, 0.72, 0.12), Mats.darkwood(), 0.035, false)
			for sx in [-2.5, 0.0, 2.5]:
				_box(p + Vector3(sx, 0.30, 0), Vector3(0.10, 0.60, 0.58), Mats.iron_dark(), false)
			_collider_box(p + Vector3(0, 0.65, 0), Vector3(5.7, 1.3, 0.75))
	# Human-scale detail makes the symmetry feel abandoned rather than staged.
	_asy_wheelchair(c + Vector3(0.7, 0, 4.2), PI + 0.22)
	_asy_papers(c + Vector3(-0.8, 0, 6.5), 1101, 11)
	var rockp := front + Vector3(4.8, 0, 0.2)
	_asy_model("Rockingchair_01", rockp, -PI / 2.0)
	_collider_yaw_box(rockp + Vector3(0, 0.5, 0), Vector3(0.72, 1.0, 0.85), -PI / 2.0)


## A narrow but structurally complete ward corridor. Locked patient rooms are
## sealed volumes behind continuous masonry; actual graph connections become
## return-walled cross-passages to the canonical cell-edge doorway. The spacing
## stays irregular so this never acquires the office floor's modular rhythm.
func _asy_corridor() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x := cdir != 2
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var lane_half := 2.05
	var side_data := []
	for si in 2:
		var side := -lane_half if si == 0 else lane_half
		var sdir := (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
		var info := WorldGen.edge_info(wseed, cell, sdir, theme)
		var bay := []
		if not info["wall"]:
			var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
			var bw := clampf(float(info["w"]) + 0.34, 1.9, 2.9)
			bay = [bt, bw]
		var doors := _asy_corridor_doors(si, bay)
		_asy_corridor_wall_side(o, yw, side, doors, bay)
		side_data.append({"side": side, "doors": doors, "bay": bay})

	# Abandoned transport is parked only against uninterrupted wall. It adds
	# history without blocking a real connection or floating in front of a door.
	for si in 2:
		var data: Dictionary = side_data[si]
		for di in 2:
			var t := _asy_corridor_prop_t(si, di, data["doors"], data["bay"])
			if t > 90.0:
				continue
			var side: float = (-1.42 if si == 0 else 1.42)
			var pp := _wp(o, Vector3(t, 0, side), yw)
			var rr := _r(724 + si * 5 + di)
			var park_yaw := yw + PI / 2.0
			if rr < 0.18:
				_asy_gurney(pp, park_yaw + (_r(726 + di) - 0.5) * 0.18,
					728 + si * 3 + di)
			elif rr < 0.3:
				_asy_bed(pp, park_yaw + (_r(729 + di) - 0.5) * 0.14,
					730 + si * 3 + di)
			elif rr < 0.46:
				_asy_wheelchair(pp, _r(731 + si * 3 + di) * TAU)
			elif rr < 0.59:
				_asy_iv(pp)
			elif rr < 0.76:
				_asy_papers(pp, 733 + si * 7 + di, 5)
	if _r(740) < 0.4:
		_asy_sign(o, yw)


func _asy_corridor_doors(si: int, bay: Array) -> Array:
	var doors := []
	# Offset the two sides and perturb the end positions slightly: real old wards
	# accrete rooms, unlike the perfectly repeated office grid.
	var positions := [-3.65, -0.15, 3.42] if si == 0 else [-3.28, 0.3, 3.78]
	for di in positions.size():
		var t: float = positions[di] + (_r(700 + si * 7 + di) - 0.5) * 0.26
		if _r(704 + si * 7 + di) >= 0.78:
			continue
		if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + 0.9:
			continue
		doors.append(t)
	if doors.is_empty() and bay.is_empty():
		doors.append(float(positions[1]))
	return doors


func _asy_corridor_clear(t: float, doors: Array, bay: Array, clearance: float) -> bool:
	if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + clearance:
		return false
	for dt in doors:
		if absf(t - float(dt)) < 0.62 + clearance:
			return false
	return true


func _asy_corridor_prop_t(si: int, index: int, doors: Array, bay: Array) -> float:
	var raw := -4.45 + 8.9 * _r(720 + si * 9 + index)
	var candidates := [raw, -4.65, 4.65, -1.72, 1.72]
	if (si + index) % 2 == 1:
		candidates = [raw, 4.65, -4.65, 1.72, -1.72]
	for t in candidates:
		if _asy_corridor_clear(float(t), doors, bay, 0.82):
			return float(t)
	return 99.0


## One complete masonry side, cut only for a filled locked door or for a real
## cross-passage. Wall, tile and collider share the exact same segmentation.
func _asy_corridor_wall_side(o: Vector3, yw: float, side: float,
		doors: Array, bay: Array) -> void:
	var segs := [[-6.0, 6.0]]
	for dt in doors:
		segs = _cut_seg(segs, float(dt) - 0.61, float(dt) + 0.61)
	if not bay.is_empty():
		segs = _cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_asy_corridor_wall_run(o, yw, side, float(sg[0]), float(sg[1]))
	for di in doors.size():
		var dt := float(doors[di])
		_asy_corridor_header(o, yw, side, dt, 1.22)
		_asy_corridor_door(o, yw, dt, side,
			750 + (0 if side < 0.0 else 14) + di)
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_asy_corridor_header(o, yw, side, bt, bw)
		_asy_corridor_open_casing(o, yw, side, bt, bw)
		_asy_corridor_bay_returns(o, yw, side, bt, bw)


func _asy_corridor_wall_run(o: Vector3, yw: float, side: float,
		a: float, b: float) -> void:
	var ln := b - a
	if ln < 0.04:
		return
	var c := (a + b) * 0.5
	var wc := _wp(o, Vector3(c, ceil_h * 0.5, side), yw)
	var wall := _mbox(self, wc, Vector3(ln, ceil_h, 0.18), _asy_wall_mat())
	wall.rotation.y = yw
	_collider_yaw_box(wc, Vector3(ln, ceil_h, 0.18), yw)
	var inn := side - signf(side) * 0.115
	var tile := _mbox(self, _wp(o, Vector3(c, 0.69, inn), yw),
		Vector3(ln, 1.38, 0.05), Mats.asy_tile())
	tile.rotation.y = yw
	var rail := _mbox(self, _wp(o, Vector3(c, 1.39, inn - signf(side) * 0.018), yw),
		Vector3(ln, 0.07, 0.07), Mats.asy_metal_green())
	rail.rotation.y = yw


func _asy_corridor_header(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var hh := ceil_h - DOOR_TOP
	if hh <= 0.02:
		return
	var hp := _wp(o, Vector3(t, DOOR_TOP + hh * 0.5, side), yw)
	var head := _mbox(self, hp, Vector3(width, hh, 0.18), _asy_wall_mat())
	head.rotation.y = yw
	_collider_yaw_box(hp, Vector3(width, hh, 0.18), yw)


## These returns are the crucial illusion: they carry the corridor wall all the
## way to the real boundary opening and close both neighboring patient volumes.
func _asy_corridor_bay_returns(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var outer := signf(side) * (S * 0.5 - T)
	var depth := absf(outer - side)
	var dc := (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp := _wp(o, Vector3(edge, ceil_h * 0.5, dc), yw)
		var ret := _mbox(self, wp, Vector3(0.18, ceil_h, depth), _asy_wall_mat())
		ret.rotation.y = yw
		_collider_yaw_box(wp, Vector3(0.18, ceil_h, depth), yw)
		var tile_in := 0.115 if edge < t else -0.115
		var tile := _mbox(self, _wp(o, Vector3(edge + tile_in, 0.69, dc), yw),
			Vector3(0.05, 1.38, depth), Mats.asy_tile())
		tile.rotation.y = yw
		var rail := _mbox(self, _wp(o, Vector3(edge + tile_in, 1.39, dc), yw),
			Vector3(0.07, 0.07, depth), Mats.asy_metal_green())
		rail.rotation.y = yw
	var floor_strip := _mbox(self, _wp(o, Vector3(t, 0.013, dc), yw),
		Vector3(width, 0.026, depth), Mats.asy_checker())
	floor_strip.rotation.y = yw


func _asy_corridor_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn := side - signf(side) * 0.115
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb := _mbox(self, _wp(o, Vector3(edge, DOOR_TOP * 0.5, inn), yw),
			Vector3(0.12, DOOR_TOP, 0.3), Mats.asy_metal_green())
		jamb.rotation.y = yw
	var lintel := _mbox(self, _wp(o, Vector3(t, DOOR_TOP + 0.065, inn), yw),
		Vector3(width + 0.18, 0.13, 0.3), Mats.asy_metal_green())
	lintel.rotation.y = yw


## Heavy ward door installed into an actual wall opening. Most hang an authored
## hospital leaf, which brings its own vision panel, hatch and handle; the
## generated leaf below covers the remainder and any import failure. Either way
## the panel is backed by darkness, suggesting a lightless cell without
## exposing empty map.
func _asy_corridor_door(o: Vector3, yw: float, t: float,
		side: float, salt: int) -> void:
	var inn := side - signf(side) * 0.115
	var v := Node3D.new()
	v.position = _wp(o, Vector3(t, 0, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	add_child(v)
	# Casing first: it is the same whichever leaf hangs in it.
	_mbox(v, Vector3(-0.57, 1.09, 0), Vector3(0.12, 2.2, 0.3), Mats.asy_metal())
	_mbox(v, Vector3(0.57, 1.09, 0), Vector3(0.12, 2.2, 0.3), Mats.asy_metal())
	_mbox(v, Vector3(0, 2.22, 0), Vector3(1.26, 0.13, 0.3), Mats.asy_metal())
	# Darkness behind the leaf, so a vision panel reads as an unlit room.
	_mrbox(v, Vector3(0, 1.06, -0.02), Vector3(1.02, 2.12, 0.02),
		Mats.charcoal(), 0.004)
	if _asy_authored_leaf(v, salt):
		_collider_yaw_box(_wp(o, Vector3(t, 1.06, inn), yw),
			Vector3(1.02, 2.12, 0.16), yw)
		_asy_door_number(v, t, salt)
		return
	_mrbox(v, Vector3(0, 1.06, 0), Vector3(1.0, 2.12, 0.09),
		Mats.asy_metal_green(), 0.012)
	# Opaque backing first, then dirty glass and a welded cross-mesh.
	_mrbox(v, Vector3(0, 1.65, 0.047), Vector3(0.34, 0.42, 0.02),
		Mats.charcoal(), 0.006)
	_mrbox(v, Vector3(0, 1.65, 0.061), Vector3(0.3, 0.38, 0.012),
		Mats.glass_tint(), 0.005)
	for bx in [-0.075, 0.075]:
		_mbox(v, Vector3(bx, 1.65, 0.071), Vector3(0.014, 0.4, 0.01), Mats.iron_dark())
	for by in [1.54, 1.65, 1.76]:
		_mbox(v, Vector3(0, by, 0.072), Vector3(0.32, 0.012, 0.01), Mats.iron_dark())
	# Food hatch, hinges and a lock whose key has long since disappeared.
	_mrbox(v, Vector3(0, 0.68, 0.057), Vector3(0.4, 0.17, 0.025),
		Mats.asy_metal(), 0.006)
	_mbox(v, Vector3(0, 0.59, 0.074), Vector3(0.13, 0.03, 0.025), Mats.steel())
	for hy in [0.42, 1.12, 1.82]:
		_mbox(v, Vector3(-0.49, hy, 0.045), Vector3(0.045, 0.14, 0.055), Mats.iron_dark())
	_mrbox(v, Vector3(0.35, 1.02, 0.066), Vector3(0.13, 0.22, 0.03),
		Mats.iron_dark(), 0.006)
	_msphere(v, Vector3(0.35, 1.02, 0.102), 0.035, Mats.steel())
	_collider_yaw_box(_wp(o, Vector3(t, 1.06, inn), yw),
		Vector3(1.02, 2.12, 0.13), yw)
	_asy_door_number(v, t, salt)


## Hang one of the four authored hospital leaves in a casing already built at
## `v`. Returns false when the model is unavailable, leaving the caller to fall
## back to its generated leaf.
func _asy_authored_leaf(v: Node3D, salt: int) -> bool:
	if _r(salt + 17) >= 0.74:
		return false
	var pick := WorldGen.h(wseed, cell.x, cell.y, salt + 23) % ASY_DOOR_PATHS.size()
	var leaf := _attributed_prop_local(v, ASY_DOOR_PATHS[pick],
		Vector3(0, 0, 0.045), ASY_DOOR_FACE_YAW[pick],
		Vector3.ONE * ASY_LEAF_FIT)
	if leaf == null:
		return false
	leaf.set_meta("asylum_authored_leaf", pick)
	return true


## Room number stencilled on the wall beside the opening rather than on the leaf
## itself, which is where a ward actually put them — and which keeps it clear of
## the vision panels and hatches the authored leaves carry.
func _asy_door_number(v: Node3D, t: float, salt: int) -> void:
	var num := Label3D.new()
	num.text = "%02d" % (WorldGen.h(wseed, cell.x + int(t * 3.0), cell.y, salt) % 40 + 1)
	num.font_size = 42
	num.pixel_size = 0.0018
	num.modulate = Color(0.82, 0.86, 0.77)
	num.position = Vector3(-0.78, 1.86, 0.055)
	v.add_child(num)


func _asy_sign(o: Vector3, yw: float) -> void:
	var zone := WorldGen.macro_zone(wseed, cell, theme)
	var labels: Array = ASY_ZONE_SIGNS[zone]
	var txt: String = labels[WorldGen.h(wseed, cell.x, cell.y, 741) % labels.size()]
	var y := ceil_h - 0.55
	var v := Node3D.new()
	v.position = _wp(o, Vector3(0, y, 0), yw)
	v.rotation.y = yw
	add_child(v)
	_mbox(v, Vector3(0, 0.3, 0), Vector3(0.02, 0.3, 0.02), Mats.iron_dark())
	var plate := _mbox(v, Vector3(0, 0, 0), Vector3(1.5, 0.36, 0.05), Mats.asy_metal_green())
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sside in [-1.0, 1.0]:
		var lb := Label3D.new()
		lb.text = txt
		lb.font_size = 60
		lb.pixel_size = 0.0022
		lb.modulate = Color(0.88, 0.92, 0.84)
		lb.position = Vector3(0, 0, sside * 0.035)
		lb.rotation.y = 0.0 if sside > 0.0 else PI
		v.add_child(lb)


# --- school -------------------------------------------------------------------
# One building painted over every summer. Cream block above a red line, a floor
# ground until it mirrors the strip lights, and locker runs down every corridor.
# The rooms are all the ones you remember and none of them are in use.


func _sch_tiled_room() -> bool:
	return style == WorldGen.SCH_BATHROOM


func _sch_wall_mat() -> Material:
	if _sch_tiled_room():
		return Mats.sch_tile()
	return Mats.sch_wall_variant(_finish_variant())


func _sch_floor_mat() -> Material:
	match style:
		WorldGen.SCH_GYM, WorldGen.SCH_AUDITORIUM:
			return Mats.sch_gymfloor()
		WorldGen.SCH_BATHROOM:
			return Mats.sch_tile()
		WorldGen.SCH_CAFETERIA, WorldGen.SCH_ADMIN:
			return Mats.sch_terrazzo()
	return Mats.sch_floor()


## Which way the corridor runs, as a unit vector in cell space.
func _sch_corridor_axis() -> int:
	return WorldGen.corridor(wseed, cell)


## Surface-mounted twin tube: a steel channel with a lens under it. Nothing
## here casts — the room light would rake the housings into streaks.
func _sch_strip(at: Vector3, along_x: bool, ln: float, pmat: Material) -> void:
	var y := ceil_h - 0.06
	var body_size := Vector3(ln, 0.09, 0.24) if along_x else Vector3(0.24, 0.09, ln)
	var housing := _box(Vector3(at.x, y, at.z), body_size, Mats.sch_trim(), false)
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lens_size := Vector3(ln - 0.12, 0.03, 0.15) if along_x else Vector3(0.15, 0.03, ln - 0.12)
	var lens := _box(Vector3(at.x, y - 0.06, at.z), lens_size, pmat, false)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _sch_lighting() -> void:
	var is_spawn := cell == Vector2i.ZERO
	# A school is maintained — the asylum is the one that gets to be pitch
	# dark. A dead cell here left rooms with nothing but ambient, which on
	# this floor is not enough to see the far wall by.
	var dead := (not is_spawn) and _r(8) < 0.02
	var flicker := (not is_spawn) and (not dead) and _r(9) < 0.12
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.sch_panel().duplicate()
	else:
		pmat = Mats.sch_panel()
	var cdir := _sch_corridor_axis()
	if cdir != 0:
		# a single line of strips running the length of the passage, which is
		# what makes a school corridor read as endless
		var along_x := cdir == 1
		for t in [2.0, 6.0, 10.0]:
			var at := Vector3(t, 0, S / 2.0) if along_x else Vector3(S / 2.0, 0, t)
			_sch_strip(at, along_x, 2.6, pmat)
	elif style == WorldGen.SCH_GYM:
		for gx in [4.0, 12.0, 20.0]:
			for gz in [4.0, 12.0, 20.0]:
				_sch_strip(Vector3(gx, 0, gz), true, 3.2, pmat)
	else:
		for gx in [3.4, 8.6]:
			for gz in [3.0, 9.0]:
				_sch_strip(Vector3(gx, 0, gz), _r(60) < 0.5, 2.4, pmat)
	if dead:
		return
	var tall := ceil_h > 4.5
	var light := _make_main_light(flicker, pmat, 2.1 if tall else 1.5)
	light.light_color = Color(0.94, 0.97, 1.0)
	light.omni_range = 17.0 if tall else 12.0
	light.position = Vector3(S / 2.0, ceil_h - 0.5, S / 2.0)
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = 18.0
	add_child(light)


const SCH_ZONE_ROOMS := [
	["101", "103", "112", "204", "ART", "SCIENCE"],
	["MUSIC", "GYM", "CAFETERIA", "LIBRARY", "ART"],
	["FACULTY", "MAIN OFFICE", "COUNSELOR", "RECORDS"],
]


## The architectural contract for one side of a school hall. Coordinates are
## corridor-local: x follows the hall and z points toward its side rooms.
func _sch_corridor_side_data(si: int, along_x: bool) -> Dictionary:
	var side := -2.05 if si == 0 else 2.05
	var sdir := (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
	var info := WorldGen.edge_info(wseed, cell, sdir, theme)
	var bay := []
	if not info["wall"]:
		var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
		var bw := clampf(float(info["w"]) + 0.62, 2.25, 2.9)
		bay = [bt, bw]
	return {"side": side, "bay": bay, "doors": _sch_corridor_doors(si, bay)}


## Long enclosed stretches get evidence of classrooms behind them. A genuine
## connection owns its interval and suppresses any locked-door facade nearby.
func _sch_corridor_doors(si: int, bay: Array) -> Array:
	var doors := []
	var positions := [-3.25, 3.3] if si == 0 else [-3.55, 3.0]
	for di in positions.size():
		var t: float = positions[di] + (_r(330 + si * 7 + di) - 0.5) * 0.24
		if _r(334 + si * 7 + di) >= 0.72:
			continue
		if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + 0.95:
			continue
		doors.append(t)
	if doors.is_empty() and bay.is_empty():
		doors.append(float(positions[int(_r(348 + si) * 1.99)]))
	return doors


## A school corridor is about four metres across. The side strips are reserved
## classroom volume: continuous walls seal them, locked doors fill real cuts,
## and actual graph connections become cased, return-walled recesses.
func _sch_narrow() -> void:
	var along_x := _sch_corridor_axis() == 1
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	for si in 2:
		var data := _sch_corridor_side_data(si, along_x)
		_sch_corridor_wall_side(o, yw, float(data["side"]), data["doors"], data["bay"])


func _sch_corridor_wall_side(o: Vector3, yw: float, side: float,
		doors: Array, bay: Array) -> void:
	var segs := [[-6.0, 6.0]]
	for dt in doors:
		segs = _cut_seg(segs, float(dt) - 0.62, float(dt) + 0.62)
	if not bay.is_empty():
		segs = _cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_sch_corridor_wall_run(o, yw, side, float(sg[0]), float(sg[1]))
	for di in doors.size():
		var dt := float(doors[di])
		_sch_corridor_header(o, yw, side, dt, 1.24)
		_sch_corridor_door(o, yw, dt, side,
			360 + (0 if side < 0.0 else 12) + di)
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_sch_corridor_header(o, yw, side, bt, bw)
		_sch_corridor_open_casing(o, yw, side, bt, bw)
		_sch_corridor_bay_returns(o, yw, side, bt, bw)
		_sch_corridor_bay_light(o, yw, side, bt)


func _sch_corridor_wall_run(o: Vector3, yw: float, side: float,
		a: float, b: float) -> void:
	var ln := b - a
	if ln < 0.04:
		return
	var c := (a + b) * 0.5
	var wc := _wp(o, Vector3(c, ceil_h * 0.5, side), yw)
	var wall := _mbox(self, wc, Vector3(ln, ceil_h, T),
		Mats.sch_wall_variant(_finish_variant()))
	wall.rotation.y = yw
	_collider_yaw_box(wc, Vector3(ln, ceil_h, T), yw)
	var inn := side - signf(side) * (T * 0.5 + 0.025)
	var band := _mbox(self, _wp(o, Vector3(c, SCH_BAND, inn), yw),
		Vector3(ln, 0.17, 0.04), Mats.sch_red())
	band.rotation.y = yw
	var base := _mbox(self, _wp(o, Vector3(c, 0.06, inn), yw),
		Vector3(ln, 0.12, 0.05), Mats.charcoal())
	base.rotation.y = yw


func _sch_corridor_header(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var hh := ceil_h - DOOR_TOP
	if hh <= 0.02:
		return
	var hp := _wp(o, Vector3(t, DOOR_TOP + hh * 0.5, side), yw)
	var head := _mbox(self, hp, Vector3(width, hh, T),
		Mats.sch_wall_variant(_finish_variant()))
	head.rotation.y = yw
	_collider_yaw_box(hp, Vector3(width, hh, T), yw)


func _sch_corridor_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn := side - signf(side) * (T * 0.5 + 0.025)
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb := _mbox(self, _wp(o, Vector3(edge, DOOR_TOP * 0.5, inn), yw),
			Vector3(0.17, DOOR_TOP, T + 0.14), Mats.sch_red())
		jamb.rotation.y = yw
	var lintel := _mbox(self, _wp(o, Vector3(t, DOOR_TOP + 0.08, inn), yw),
		Vector3(width + 0.17, 0.16, T + 0.14), Mats.sch_red())
	lintel.rotation.y = yw


## Close the dead classroom strips on both sides of a real connection and carry
## the red datum line and cove base all the way to its boundary doorway.
func _sch_corridor_bay_returns(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var outer := signf(side) * (S * 0.5 - T)
	var depth := absf(outer - side)
	var dc := (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp := _wp(o, Vector3(edge, ceil_h * 0.5, dc), yw)
		var ret := _mbox(self, wp, Vector3(T, ceil_h, depth),
			Mats.sch_wall_variant(_finish_variant()))
		ret.rotation.y = yw
		_collider_yaw_box(wp, Vector3(T, ceil_h, depth), yw)
		var inward := T * 0.5 + 0.025 if edge < t else -(T * 0.5 + 0.025)
		var band := _mbox(self, _wp(o, Vector3(edge + inward, SCH_BAND, dc), yw),
			Vector3(0.04, 0.17, depth), Mats.sch_red())
		band.rotation.y = yw
		var base := _mbox(self, _wp(o, Vector3(edge + inward, 0.06, dc), yw),
			Vector3(0.05, 0.12, depth), Mats.charcoal())
		base.rotation.y = yw


func _sch_corridor_bay_light(o: Vector3, yw: float, side: float, t: float) -> void:
	var outer := signf(side) * (S * 0.5 - T)
	var dc := (outer + side) * 0.5
	var bl := OmniLight3D.new()
	bl.light_color = Color(0.94, 0.97, 1.0)
	bl.light_energy = 0.72
	bl.omni_range = 5.8
	bl.shadow_enabled = false
	bl.distance_fade_enabled = true
	bl.distance_fade_begin = 18.0
	bl.distance_fade_length = 6.0
	bl.position = _wp(o, Vector3(t, ceil_h - 0.5, dc), yw)
	add_child(bl)


## A closed classroom door in a genuine opening: deep painted-steel jambs,
## opaque wired safety glass, a closer, lever and room plate. Its collider seals
## the reserved classroom volume behind it.
func _sch_corridor_door(o: Vector3, yw: float, t: float,
		side: float, salt: int) -> void:
	var inn := side - signf(side) * (T * 0.5 + 0.025)
	var v := Node3D.new()
	v.position = _wp(o, Vector3(t, 0, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	add_child(v)
	_mrbox(v, Vector3(0, 1.08, 0), Vector3(1.03, 2.16, 0.075),
		Mats.sch_door(), 0.01)
	_mbox(v, Vector3(-0.575, 1.1, 0), Vector3(0.12, 2.22, 0.26), Mats.sch_red())
	_mbox(v, Vector3(0.575, 1.1, 0), Vector3(0.12, 2.22, 0.26), Mats.sch_red())
	_mbox(v, Vector3(0, 2.24, 0), Vector3(1.27, 0.13, 0.26), Mats.sch_red())
	# Narrow safety-glass panel and its embedded wire grid.
	_mrbox(v, Vector3(0, 1.55, 0.043), Vector3(0.3, 0.68, 0.018),
		Mats.sch_wired_glass(), 0.006)
	for wx in [-0.09, 0.0, 0.09]:
		_mbox(v, Vector3(wx, 1.55, 0.055), Vector3(0.008, 0.64, 0.008), Mats.sch_trim())
	for wy in [1.37, 1.55, 1.73]:
		_mbox(v, Vector3(0, wy, 0.056), Vector3(0.28, 0.008, 0.008), Mats.sch_trim())
	# Lever set and a surface closer with its articulated arm.
	_mrbox(v, Vector3(0.35, 1.01, 0.055), Vector3(0.13, 0.2, 0.025),
		Mats.sch_trim(), 0.006)
	_mbox(v, Vector3(0.24, 1.01, 0.08), Vector3(0.25, 0.035, 0.035), Mats.sch_trim())
	_mrbox(v, Vector3(-0.27, 2.02, 0.05), Vector3(0.4, 0.1, 0.07),
		Mats.sch_trim(), 0.008)
	_mbox(v, Vector3(0.03, 2.04, 0.084), Vector3(0.31, 0.025, 0.025), Mats.sch_trim())
	_collider_yaw_box(_wp(o, Vector3(t, 1.08, inn), yw),
		Vector3(1.05, 2.16, 0.12), yw)
	var plate := _mrbox(v, Vector3(0.79, 1.7, 0.045),
		Vector3(0.3, 0.22, 0.025), Mats.sch_white(), 0.005)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lb := Label3D.new()
	var zone := WorldGen.macro_zone(wseed, cell, theme)
	var labels: Array = SCH_ZONE_ROOMS[zone]
	lb.text = labels[WorldGen.h(wseed, cell.x + int(t * 4.0), cell.y, salt) % labels.size()]
	lb.font_size = 34
	lb.pixel_size = 0.00145
	lb.modulate = Color(0.16, 0.22, 0.24)
	lb.position = Vector3(0.79, 1.7, 0.061)
	v.add_child(lb)


func _sch_corridor_clear(t: float, doors: Array, bay: Array, clearance: float) -> bool:
	if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + clearance:
		return false
	for dt in doors:
		if absf(t - float(dt)) < 0.63 + clearance:
			return false
	return true


func _sch_corridor_prop_t(si: int, salt: int, doors: Array, bay: Array,
		clearance: float) -> float:
	var raw := -3.8 + 7.6 * _r(salt)
	var candidates := [raw, -4.65, 4.65, -1.7, 1.7]
	if si == 1:
		candidates = [raw, 4.65, -4.65, 1.7, -1.7]
	for t in candidates:
		if _sch_corridor_clear(float(t), doors, bay, clearance):
			return float(t)
	return 99.0


## Locker banks use the exact same cuts as the architecture, so they finish at
## jambs rather than covering doors or jutting into a real classroom recess.
func _sch_passage_lockers(salt: int) -> void:
	var along_x := _sch_corridor_axis() == 1
	var depth := 0.42
	var hgt := 1.83
	for si in 2:
		var data := _sch_corridor_side_data(si, along_x)
		var side: float = data["side"]
		var doors: Array = data["doors"]
		var bay: Array = data["bay"]
		var segs := [[-5.6, 5.6]]
		for dt in doors:
			segs = _cut_seg(segs, float(dt) - 0.86, float(dt) + 0.86)
		if not bay.is_empty():
			segs = _cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5 - 0.28,
				float(bay[0]) + float(bay[1]) * 0.5 + 0.28)
		var mat: Material = Mats.sch_locker() if _r(salt + si) < 0.68 \
			else Mats.sch_locker_blue()
		var lo_local := side - signf(side) * (T * 0.5 + depth * 0.5)
		for sg in segs:
			var a: float = sg[0]
			var b: float = sg[1]
			if b - a < 1.0:
				continue
			if along_x:
				_sch_locker_run(true, S * 0.5 + lo_local, a + S * 0.5,
					b + S * 0.5, -signf(side), mat, depth, hgt, salt + si * 19)
			else:
				_sch_locker_run(false, S * 0.5 + lo_local, S * 0.5 - b,
					S * 0.5 - a, -signf(side), mat, depth, hgt, salt + si * 19)


## The bank itself: carcass, kick plinth, and two tiers of doors with vents
## and latches. One collider for the whole run, not forty.
func _sch_locker_run(along_x: bool, off: float, from: float, to: float,
		facing: float, mat: Material, depth: float, hgt: float, salt: int) -> void:
	if _sch_locker_run_authored(along_x, off, from, to, facing, depth):
		return
	_sch_locker_run_generated(along_x, off, from, to, facing, mat, depth,
		hgt, salt)


## The authored bank is 1.97m of doors, so a corridor length is tiled with as
## many whole banks as fit and the remainder split evenly at both ends rather
## than stretching one bank to length — a stretched locker reads immediately as
## the wrong door proportion. Runs shorter than one bank fall back to single
## columns, and anything shorter than that is left to the generated run.
func _sch_locker_run_authored(along_x: bool, off: float, from: float,
		to: float, facing: float, gen_depth: float) -> bool:
	var ln := to - from
	if ln < GYM_LOCKER_W or _prop_scene(LOCKERS_PATH) == null:
		return false
	# `facing` is +1/-1 across the run's axis; turn it into the yaw that puts
	# the authored doors' local +Z out into the corridor.
	var yaw := 0.0
	if along_x:
		yaw = 0.0 if facing > 0.0 else PI
	else:
		yaw = PI / 2.0 if facing > 0.0 else -PI / 2.0
	var use_bank := ln >= LOCKERS_RUN_W
	var unit_w := LOCKERS_RUN_W if use_bank else GYM_LOCKER_W
	var path := LOCKERS_PATH if use_bank else GYM_LOCKER_PATH
	var scl := LOCKERS_SCALE if use_bank else GYM_LOCKER_SCALE
	var centre := LOCKERS_CENTRE if use_bank else GYM_LOCKER_CENTRE
	var kind := "school_locker_bank" if use_bank else "school_locker_column"
	var cnt := int(ln / unit_w)
	var pad := (ln - float(cnt) * unit_w) * 0.5
	# `off` is the centre of the generated carcass, so the wall face it stood
	# against is half its depth behind. The authored bank is 0.48m deep rather
	# than 0.42m; align the backs, not the centres, or the run floats.
	var depth := 0.48
	var mid := off - facing * gen_depth * 0.5 + facing * depth * 0.5
	var placed := 0
	for i in cnt:
		var t := from + pad + unit_w * (float(i) + 0.5)
		var p := Vector3(t, 0, mid) if along_x else Vector3(mid, 0, t)
		var bank_b0 := body.get_child_count()
		var bank := _attributed_floor_prop(path, p, yaw, scl, centre, kind,
			null, true)
		if bank == null:
			continue
		placed += 1
		var size := Vector3(unit_w, 1.85, depth) if along_x \
			else Vector3(depth, 1.85, unit_w)
		_collider_box(p + Vector3(0, 0.925, 0), size)
		_bind_furnishing_colliders(bank, bank_b0)
	return placed > 0


func _sch_locker_run_generated(along_x: bool, off: float, from: float,
		to: float, facing: float, mat: Material, depth: float, hgt: float,
		salt: int) -> void:
	var ln := to - from
	var plinth := 0.12
	var c := (from + to) * 0.5
	if along_x:
		_box(Vector3(c, plinth + (hgt - plinth) / 2.0, off), Vector3(ln, hgt - plinth, depth), mat, false)
		_box(Vector3(c, plinth / 2.0, off), Vector3(ln, plinth, depth - 0.06), Mats.charcoal(), false)
		_collider_box(Vector3(c, hgt / 2.0, off), Vector3(ln, hgt, depth))
	else:
		_box(Vector3(off, plinth + (hgt - plinth) / 2.0, c), Vector3(depth, hgt - plinth, ln), mat, false)
		_box(Vector3(off, plinth / 2.0, c), Vector3(depth - 0.06, plinth, ln), Mats.charcoal(), false)
		_collider_box(Vector3(off, hgt / 2.0, c), Vector3(depth, hgt, ln))
	var dw := 0.305
	var cnt := int(ln / dw)
	if cnt < 1:
		return
	var pad := (ln - float(cnt) * dw) * 0.5
	var face := off + facing * (depth * 0.5 + 0.012)
	for i in cnt:
		var t := from + pad + dw * (float(i) + 0.5)
		for tier in 2:
			var y := plinth + 0.44 + 0.85 * float(tier)
			var open := WorldGen.r01(wseed, cell.x * 61 + i, cell.y * 13 + tier, salt + 3) < 0.05
			var dm: Material = Mats.charcoal() if open else mat
			var fs := Vector3(dw - 0.018, 0.82, 0.024) if along_x else Vector3(0.024, 0.82, dw - 0.018)
			var fp := Vector3(t, y, face) if along_x else Vector3(face, y, t)
			_box(fp, fs, dm, false)
			if open:
				continue
			var vs := Vector3(dw * 0.5, 0.10, 0.012) if along_x else Vector3(0.012, 0.10, dw * 0.5)
			var vp := Vector3(t, y + 0.33, face + facing * 0.014) if along_x \
				else Vector3(face + facing * 0.014, y + 0.33, t)
			_box(vp, vs, Mats.charcoal(), false)
			var hs := Vector3(0.035, 0.13, 0.03) if along_x else Vector3(0.03, 0.13, 0.035)
			var hp := Vector3(t + dw * 0.3, y - 0.26, face + facing * 0.02) if along_x \
				else Vector3(face + facing * 0.02, y - 0.26, t + dw * 0.3)
			_box(hp, hs, Mats.sch_trim(), false)


func _sch_corridor() -> void:
	_sch_narrow()
	_sch_passage_lockers(300)
	var along_x := _sch_corridor_axis() == 1
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var side_data := [_sch_corridor_side_data(0, along_x),
		_sch_corridor_side_data(1, along_x)]
	if _r(309) < 0.36:
		var cam_si := 0 if _r(308) < 0.5 else 1
		var cam_side := float(side_data[cam_si]["side"])
		var cam_t := -4.55 if _r(307) < 0.5 else 4.55
		_security_camera(_wp(o, Vector3(cam_t, 2.48, cam_side), yw),
			yw + PI if cam_side > 0.0 else yw)
	# a bin, and sometimes something knocked over and left
	var si := 1 if _r(311) < 0.5 else 0
	var data: Dictionary = side_data[si]
	var t := _sch_corridor_prop_t(si, 310, data["doors"], data["bay"], 0.58)
	var side := -1.15 if si == 0 else 1.15
	var p := _wp(o, Vector3(t, 0, side), yw)
	if _r(312) < 0.62:
		if t < 90.0:
			_sch_bin(p)
	if _r(313) < 0.35:
		var si2 := 1 if _r(315) < 0.5 else 0
		var data2: Dictionary = side_data[si2]
		var t2 := _sch_corridor_prop_t(si2, 314, data2["doors"], data2["bay"], 0.92)
		if t2 < 90.0:
			var s2 := -1.1 if si2 == 0 else 1.1
			# The authored cart is 1.09m across, half again the generated one
			# it replaced, and the locker banks now stand 0.48m off these
			# walls. Walk it in from the wall until it genuinely fits, and
			# leave the corridor empty rather than park it inside a locker.
			var tp := _wp(o, Vector3(t2, 0, s2), yw)
			for pull in 4:
				if _floor_spot_clear(tp, 0.58):
					break
				s2 *= 0.6
				tp = _wp(o, Vector3(t2, 0, s2), yw)
			if _floor_spot_clear(tp, 0.58):
				_sch_trolley(tp, _r(316) * TAU)
	if _r(317) < 0.3:
		var si3 := 1 if _r(319) < 0.5 else 0
		var data3: Dictionary = side_data[si3]
		var t3 := _sch_corridor_prop_t(si3, 318, data3["doors"], data3["bay"], 0.78)
		if t3 < 90.0:
			var s3 := -1.0 if si3 == 0 else 1.0
			_sch_stack_chairs(_wp(o, Vector3(t3, 0, s3), yw), _r(320) * TAU, 321)


## Wheeled steel bin, the kind parked by the doors and never emptied.
func _sch_bin(p: Vector3) -> void:
	_waste_bin(p, _r(int(p.x * 11.0 + p.z * 5.0) + 288) * TAU, "school_bin")


## Stacked plastic chairs, shoved against a wall at the end of term.
func _sch_stack_chairs(p: Vector3, yaw: float, salt: int) -> void:
	# Use the real school-chair model here: its shaped seat, welded frame and
	# back cut-out are most noticeable when several silhouettes overlap.
	var n := 3 + int(_r(salt + 1) * 1.99)
	for i in n:
		var nested := Vector3(0, 0.065 * float(i), 0.035 * float(i)).rotated(Vector3.UP, yaw)
		_asy_model("SchoolChair_01", p + nested,
			yaw + (_r(salt + 4 + i) - 0.5) * 0.035)
	_collider_yaw_box(p + Vector3(0, 0.57, 0), Vector3(0.62, 1.14, 0.76), yaw)


## Janitor's trolley — mop bucket on castors, handle, a bag hanging off it.
## Janitor's cart. The authored model is the only noncommercial asset the
## school floor depends on, and this is its single entry point, so the
## dependency lifts out by deleting one branch.
func _sch_trolley(p: Vector3, yaw: float) -> void:
	var b0 := body.get_child_count()
	var pivot := _attributed_floor_prop(SCH_CLEANING_CART_PATH, p, yaw,
		SCH_CLEANING_CART_SCALE, SCH_CLEANING_CART_CENTRE,
		"school_janitor_trolley", null, true)
	if pivot != null:
		_collider_yaw_box(p + Vector3(0, 0.42, 0),
			Vector3(1.05, 0.84, 0.80), yaw)
		_bind_furnishing_colliders(pivot, b0)
		return
	_sch_trolley_generated(p, yaw)


func _sch_trolley_generated(p: Vector3, yaw: float) -> void:
	var b0 := body.get_child_count()
	var v := _furnishing_pivot(p, yaw, "school_janitor_trolley")
	var plastic := Mats.sch_cart_plastic()
	# Solid moulded bucket, rolled rim and a dark open well. The old body used
	# translucent water-jug plastic, exposing the wheels and wall behind it.
	var tub := _mrbox(v, Vector3(0, 0.35, 0), Vector3(0.62, 0.50, 0.46),
		plastic, 0.07)
	tub.set_meta("school_cart_opaque_body", true)
	_mrbox(v, Vector3(0, 0.61, 0), Vector3(0.68, 0.08, 0.52),
		plastic, 0.025)
	_mrbox(v, Vector3(0, 0.655, -0.02), Vector3(0.52, 0.018, 0.36),
		Mats.charcoal(), 0.015)
	# Rear wringer tower and roller.
	_mrbox(v, Vector3(0, 0.83, 0.18), Vector3(0.48, 0.36, 0.12),
		plastic, 0.025)
	var roller := _mcyl(v, Vector3(0, 0.86, 0.115), 0.065, 0.40,
		Mats.rubber_black())
	roller.rotation.z = PI / 2.0
	# A complete push handle, rather than one unexplained vertical pole.
	for sx in [-0.24, 0.24]:
		_mcyl(v, Vector3(sx, 1.02, 0.22), 0.018, 0.78, Mats.sch_trim())
	var grip := _mcyl(v, Vector3(0, 1.40, 0.22), 0.035, 0.52,
		Mats.rubber_black())
	grip.rotation.z = PI / 2.0
	for sx in [-0.2, 0.2]:
		for sz in [-0.14, 0.14]:
			_mcyl(v, Vector3(sx, 0.055, sz), 0.055, 0.05,
				Mats.rubber_black())
	_collider_yaw_box(p + Vector3(0, 0.4, 0), Vector3(0.55, 0.8, 0.45), yaw)
	_bind_furnishing_colliders(v, b0)


## Yaw that sits a student facing the given wall, so the class faces the board
## rather than the back of the room.
##
## The convention here is +Z, not the usual -Z forward: a chair's backrest is
## modelled at local -Z, so whoever is sitting in it looks along local +Z.
## That means (sin yaw, cos yaw) is the direction the class is facing, and
## everything else in the room is laid out from that vector.
func _sch_face_yaw(dir: int) -> float:
	match dir:
		0: return PI / 2.0        # faces +x
		1: return -PI / 2.0       # faces -x
		2: return 0.0             # faces +z
	return PI                     # faces -z


## A solid wall to hang the front of the room on, or -1 if the cell has none.
func _sch_front_wall(salt: int) -> int:
	return WorldGen.anchor_wall(wseed, cell, salt)


## Canonical student station: the authored model contains both desk and chair.
## Every classroom route uses this helper, including split classroom variants,
## so keeping the choice here singular prevents mixed furniture sets.
func _sch_desk(p: Vector3, yaw: float, _salt: int) -> void:
	var station := _attributed_floor_prop(SCH_DESK_PATH, p,
		yaw + SCH_DESK_YAW_FIX, SCH_DESK_SCALE, SCH_DESK_CENTRE, "school_desk")
	if station == null:
		return
	station.set_meta("school_student_station", true)
	station.set_meta("school_student_facing_yaw", yaw)
	_collider_yaw_box(p + Vector3(0, 0.42, 0),
		Vector3(0.80, 0.84, 0.96), yaw)


func _sch_desk_row(p: Vector3, yaw: float, n: int, salt: int) -> void:
	var rx := cos(yaw)
	var rz := -sin(yaw)
	for i in n:
		var d := (float(i) - float(n - 1) * 0.5) * SCH_DESK_COL_PITCH
		_sch_desk(p + Vector3(rx * d, 0, rz * d), yaw, salt + i * 5)


## The board, the tray of stubs under it, and the strip of pinned work above.
func _sch_chalkboard(dir: int) -> void:
	# A board is only valid on a genuinely solid classroom edge. In particular,
	# never invent one on the fallback facing used by an all-doorway classroom.
	var binfo := WorldGen.edge_info(wseed, cell, dir, theme)
	if not binfo["wall"]:
		return
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var ln := 4.2
	var y := 1.55
	var cen := S / 2.0
	# Board, frame, chalk, dust and pinned work are one furnishing pivot. If a
	# perpendicular doorway approach culls the board, all of its writing leaves
	# with it instead of surviving as text painted directly on the wall.
	var board_root := Node3D.new()
	board_root.set_meta("school_chalkboard", dir)
	add_child(board_root)
	var bm: Material = Mats.sch_board()
	var d0 := inner + n * 0.03
	if dir < 2:
		_mbox(board_root, Vector3(d0, y, cen), Vector3(0.05, 1.25, ln), bm)
		_mbox(board_root, Vector3(d0 + n * 0.02, y - 0.68, cen), Vector3(0.09, 0.05, ln), Mats.sch_trim())
		for edge in [-1.0, 1.0]:
			_mbox(board_root, Vector3(d0, y, cen + edge * ln / 2.0),
				Vector3(0.07, 1.33, 0.06), Mats.sch_trim())
	else:
		_mbox(board_root, Vector3(cen, y, d0), Vector3(ln, 1.25, 0.05), bm)
		_mbox(board_root, Vector3(cen, y - 0.68, d0 + n * 0.02),
			Vector3(ln, 0.05, 0.09), Mats.sch_trim())
		for edge in [-1.0, 1.0]:
			_mbox(board_root, Vector3(cen + edge * ln / 2.0, y, d0),
				Vector3(0.06, 1.33, 0.07), Mats.sch_trim())
	_sch_chalk(board_root, dir, cen, ln)
	# a row of work pinned above it, curling off the wall
	if _r(71) < 0.7:
		for i in 5:
			var t := cen - 1.7 + 0.85 * float(i)
			var py := 2.48
			var ps := Vector3(0.01, 0.3, 0.22) if dir < 2 else Vector3(0.22, 0.3, 0.01)
			var pp := Vector3(inner + n * 0.02, py, t) if dir < 2 else Vector3(t, py, inner + n * 0.02)
			_mbox(board_root, pp, ps, Mats.box_white())


func _sch_classroom() -> void:
	var fw := _sch_front_wall(72)
	var has_board_wall := fw >= 0
	if not has_board_wall:
		fw = 3
	else:
		_sch_chalkboard(fw)
	var yaw := _sch_face_yaw(fw)
	# the direction the class looks — toward the board
	var fx := sin(yaw)
	var fz := cos(yaw)
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# teacher's desk between the class and the board
	var td := c + Vector3(fx, 0, fz) * 3.5
	var teacher_b0 := body.get_child_count()
	var teacher := _furnishing_pivot(td, yaw, "school_teacher_station")
	# A genuinely modelled steel teacher's desk replaces the old slab-and-leg
	# primitive. Its worn drawers and overhang make the front of the room read
	# as a specific abandoned workplace rather than another student table. The
	# desk, supplies and chair are one atomic furnishing: a doorway can remove
	# the station, but can never leave its cup and pens hovering behind.
	var teacher_desk := _asy_model("metal_office_desk", td, yaw)
	_adopt_local(teacher, teacher_desk)
	_collider_yaw_box(td + Vector3(0, 0.4, 0), Vector3(2.0, 0.8, 0.95), yaw)
	var supplies := _cc0_prop("stationery_supplies",
		_wp(td, Vector3(-0.48, 0.86, 0.05), yaw),
		yaw + PI / 2.0 + (_r(73) - 0.5) * 0.12)
	supplies.set_meta("school_teacher_stationery", true)
	_adopt_local(teacher, supplies)
	var teacher_chair := _office_task_chair(
		td + Vector3(fx, 0, fz) * 1.0, yaw)
	_adopt_local(teacher, teacher_chair)
	_bind_furnishing_colliders(teacher, teacher_b0)
	# rows of desks, filling back from the front
	var rows := 4
	for row in rows:
		var back := 0.3 + SCH_DESK_ROW_PITCH * float(row)
		var origin := c + Vector3(fx, 0, fz) * (1.4 - back)
		_sch_desk_row(origin, yaw, 5, 80 + row * 20)
	if has_board_wall and _r(74) < 0.5:
		_sch_screen(fw)
	# the stuff that accumulates down the side of every classroom
	# Keep the arrival classroom's perimeter bare. Its only real exit can land
	# on either side wall, and a tall cupboard in that bay made a valid spawn
	# feel like a sealed pocket even when the capsule itself was clear.
	if room_root != Vector2i.ZERO:
		var side := Vector3(fz, 0, -fx)      # perpendicular to the class's facing
		_sch_cupboard(c + side * 4.7 + Vector3(fx, 0, fz) * 1.2,
			yaw + PI / 2.0, 88)
		if _r(89) < 0.7:
			_sch_stack(c - side * 4.9, yaw + PI / 2.0, 90)
		_sch_bin(c + Vector3(fx, 0, fz) * 3.0 + side * 3.4)


## Steel storage cupboard, the tall kind with the dented doors.
func _sch_cupboard(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var hgt := 1.95
	_mbox(v, Vector3(0, hgt / 2.0, 0), Vector3(1.0, hgt, 0.46), Mats.sch_trim())
	for sx in [-0.25, 0.25]:
		_mbox(v, Vector3(sx, hgt / 2.0, 0.235), Vector3(0.47, hgt - 0.08, 0.02),
			Mats.metal_gray())
		_mbox(v, Vector3(sx + 0.19, 1.0, 0.25), Vector3(0.05, 0.16, 0.02), Mats.charcoal())
	_collider_yaw_box(p + Vector3(0, hgt / 2.0, 0), Vector3(1.0, hgt, 0.5), yaw)
	if _r(salt) < 0.5:
		for i in 3:
			_mbox(v, Vector3(-0.3 + 0.3 * float(i), hgt + 0.09, 0),
				Vector3(0.26, 0.18, 0.3), Mats.box_white())


## Left up from a lesson that was interrupted, or that nobody sat. The hand
## is the same shaky marker the asylum walls are written in — a school board
## is chalk, so it is pale on green, and half rubbed out with the side of a
## fist.
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
]


func _sch_chalk(board_root: Node3D, dir: int, cen: float, ln: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var lb := Label3D.new()
	lb.set_meta("school_chalk", true)
	lb.text = SCH_CHALK[WorldGen.h(wseed, cell.x, cell.y, 77) % SCH_CHALK.size()]
	var hand := 0 if _r(78) < 0.6 else 1
	lb.font = _scrawl_font(hand)
	lb.font_size = 46 if hand == 0 else 86
	lb.pixel_size = 0.0030 * (1.0 + (_r(79) - 0.5) * 0.3)
	lb.width = 1000.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD
	lb.modulate = Color(0.88, 0.90, 0.85, 0.72)   # chalk, and a dusty board
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var y := 1.62
	var t := cen + (_r(80) - 0.5) * (ln * 0.25)
	if dir < 2:
		lb.position = Vector3(inner + n * 0.06, y, t)
		lb.rotation.y = PI / 2.0 * n
	else:
		lb.position = Vector3(t, y, inner + n * 0.06)
		lb.rotation.y = 0.0 if n > 0.0 else PI
	lb.rotation.z = (_r(81) - 0.5) * 0.05
	board_root.add_child(lb)
	# the ghost of the last lesson, wiped with the side of a hand
	for i in 3:
		var sy := 1.15 + 0.42 * float(i)
		var sw := lerpf(0.6, 1.5, _r(82 + i))
		var st := cen + (_r(85 + i) - 0.5) * (ln - sw)
		var ss := Vector3(0.008, 0.3, sw) if dir < 2 else Vector3(sw, 0.3, 0.008)
		var sp := Vector3(inner + n * 0.045, sy, st) if dir < 2 \
			else Vector3(st, sy, inner + n * 0.045)
		var sm := _mbox(board_root, sp, ss, Mats.sch_chalkdust())
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Audit hook: chalk must be a descendant of a board pivot, and every board
## pivot must belong to a solid generated edge.
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
		if not WorldGen.edge_info(wseed, cell, dir, theme)["wall"]:
			bad += 1
	if node.has_meta("school_chalk") and not seen:
		bad += 1
	for ch in node.get_children():
		bad += _school_chalkboard_violations_at(ch, seen)
	return bad


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
				or not bool(WorldGen.edge_info(wseed, cell, dir, theme)["wall"]):
			report["violations"] += 1
	return report


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
func exit_sign_fixture_audit() -> Dictionary:
	var report := {
		"housings": 0,
		"labels": 0,
		"lights": 0,
		"violations": 0,
	}
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("structural_exit_label"):
			report["labels"] += 1
		if node.has_meta("structural_exit_light"):
			report["lights"] += 1
		if not node.has_meta("structural_exit_housing"):
			continue
		report["housings"] += 1
		var sign_top := float(node.get_meta("sign_top", INF))
		var face_offset := float(node.get_meta("face_offset", 0.0))
		var normal_half := float(node.get_meta("normal_half_extent", 0.0))
		if sign_top >= ceil_h - 0.01 or face_offset <= normal_half:
			report["violations"] += 1
		if theme != 7:
			var sign_bottom := float(node.get_meta("sign_bottom", -INF))
			var opening_head := float(node.get_meta("opening_head", INF))
			if sign_bottom <= opening_head + 0.04 \
					or normal_half <= T * 0.5 + 0.02:
				report["violations"] += 1
	if int(report["labels"]) != int(report["housings"]) * 2 \
			or int(report["lights"]) != int(report["housings"]) * 2:
		report["violations"] += 1
	return report


## Pull-down projector screen, half unrolled above the board.
func _sch_screen(dir: int) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var drop := lerpf(0.3, 0.7, _r(75))
	var y := ceil_h - 0.35 - drop / 2.0
	var t := S / 2.0 + (_r(76) - 0.5) * 2.0
	# A compact, permanently wall-mounted roller screen. The imported portable
	# screen had asset-space poles several metres tall and could read as a
	# floating box with antennae. This assembly is attached to the same solid
	# wall as the classroom board and owns every one of its pieces.
	var screen := _furnishing_pivot(Vector3.ZERO, 0.0,
		"school_projector_screen", false)
	screen.set_meta("school_projector_screen", dir)
	if dir < 2:
		_mrbox(screen, Vector3(inner + n * 0.09, ceil_h - 0.3, t),
			Vector3(0.11, 0.13, 1.95), Mats.sch_trim(), 0.025)
		_mbox(screen, Vector3(inner + n * 0.09, y, t),
			Vector3(0.025, drop, 1.75), Mats.box_white())
		_mbox(screen, Vector3(inner + n * 0.105, y - drop * 0.5 - 0.035, t),
			Vector3(0.045, 0.055, 1.82), Mats.sch_trim())
		for side in [-1.0, 1.0]:
			_mbox(screen, Vector3(inner, ceil_h - 0.3, t + side * 0.86),
				Vector3(0.16, 0.22, 0.07), Mats.sch_trim())
	else:
		_mrbox(screen, Vector3(t, ceil_h - 0.3, inner + n * 0.09),
			Vector3(1.95, 0.13, 0.11), Mats.sch_trim(), 0.025)
		_mbox(screen, Vector3(t, y, inner + n * 0.09),
			Vector3(1.75, drop, 0.025), Mats.box_white())
		_mbox(screen, Vector3(t, y - drop * 0.5 - 0.035, inner + n * 0.105),
			Vector3(1.82, 0.055, 0.045), Mats.sch_trim())
		for side in [-1.0, 1.0]:
			_mbox(screen, Vector3(t + side * 0.86, ceil_h - 0.3, inner),
				Vector3(0.07, 0.22, 0.16), Mats.sch_trim())


## Folding table with the benches welded on — cafeteria, and nowhere else.
func _sch_caf_table(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var ln := 2.9
	_mbox(v, Vector3(0, 0.75, 0), Vector3(ln, 0.05, 0.76), Mats.sch_desk())
	for sz in [-0.72, 0.72]:
		_mbox(v, Vector3(0, 0.45, sz), Vector3(ln, 0.04, 0.28), Mats.sch_desk())
		for sx in [-ln * 0.32, ln * 0.32]:
			_mbox(v, Vector3(sx, 0.22, sz), Vector3(0.05, 0.44, 0.26), Mats.sch_trim())
	for sx in [-ln * 0.32, ln * 0.32]:
		_mbox(v, Vector3(sx, 0.37, 0), Vector3(0.07, 0.74, 0.1), Mats.sch_trim())
		_mbox(v, Vector3(sx, 0.06, 0), Vector3(0.09, 0.12, 1.5), Mats.sch_trim())
	_collider_yaw_box(p + Vector3(0, 0.4, 0), Vector3(ln, 0.8, 1.6), yaw)
	if _r(salt) < 0.4:
		_mbox(v, Vector3((_r(salt + 1) - 0.5) * 1.8, 0.785, (_r(salt + 2) - 0.5) * 0.4),
			Vector3(0.35, 0.03, 0.26), Mats.sch_chair(0.08))


func _sch_cafeteria() -> void:
	var span := _room_span()
	var big := span.x > 20.0 or span.y > 20.0
	var along_x := span.x >= span.y
	var yaw := 0.0 if along_x else PI / 2.0
	var cols := 3 if big else 2
	var rows := 3 if big else 2
	var pitch := 3.4
	for r in rows:
		for cc in cols:
			var u := (float(cc) - float(cols - 1) * 0.5) * pitch
			var w := (float(r) - float(rows - 1) * 0.5) * (pitch * 0.85)
			var p := Vector3(S / 2.0 + u, 0, S / 2.0 + w)
			_sch_caf_table(p, yaw, 400 + r * 30 + cc * 7)
	# the serving line against whichever wall is solid
	var sw := _sch_front_wall(410)
	if sw >= 0:
		_sch_servery(sw)


## Stainless serving counter with a sneeze guard and empty wells.
func _sch_servery(dir: int) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var ln := 5.0
	var d := inner + n * 0.5
	var c := S / 2.0
	if dir < 2:
		_box(Vector3(d, 0.45, c), Vector3(0.9, 0.9, ln), Mats.sch_trim())
		_box(Vector3(d, 0.93, c), Vector3(1.0, 0.06, ln + 0.1), Mats.steel(), false)
		_box(Vector3(d - n * 0.1, 1.55, c), Vector3(0.03, 0.5, ln), Mats.glass(), false)
		for i in 3:
			_box(Vector3(d, 0.97, c - 1.5 + 1.5 * float(i)), Vector3(0.55, 0.05, 0.9),
				Mats.charcoal(), false)
	else:
		_box(Vector3(c, 0.45, d), Vector3(ln, 0.9, 0.9), Mats.sch_trim())
		_box(Vector3(c, 0.93, d), Vector3(ln + 0.1, 0.06, 1.0), Mats.steel(), false)
		_box(Vector3(c, 1.55, d - n * 0.1), Vector3(ln, 0.5, 0.03), Mats.glass(), false)
		for i in 3:
			_box(Vector3(c - 1.5 + 1.5 * float(i), 0.97, d), Vector3(0.9, 0.05, 0.55),
				Mats.charcoal(), false)


func _sch_bathroom() -> void:
	var sw := _sch_front_wall(500)
	if sw < 0:
		sw = 3
	# stalls along the front wall, sinks on the one to its left, and a run of
	# urinals facing the stalls across the room
	_sch_stalls(sw)
	_sch_sinks((sw + 2) % 4)
	_sch_urinals((sw + 1) % 4)


## A run of cubicles: partitions, doors ajar, gap at the floor.
func _sch_stalls(dir: int) -> void:
	var yaw := _air_yaw_for(dir)
	var depth := 1.58
	var pm := Mats.sch_chair(0.35)
	var cnt := 3
	var w := 1.18
	var start := S / 2.0 - float(cnt) * w * 0.5
	for i in cnt:
		var t := start + w * (float(i) + 0.5)
		var stall_pos := _wall_pt(dir, t, 0.02)
		var b0 := body.get_child_count()
		var stall := _furnishing_pivot(stall_pos, yaw,
			"school_bathroom_stall")
		stall.set_meta("school_stall_complete", true)
		# Full-depth side partitions with a realistic floor gap.
		for sx in [-w * 0.5, w * 0.5]:
			_mbox(stall, Vector3(sx, 1.15, -depth * 0.5),
				Vector3(0.055, 1.78, depth), pm)
			_collider_yaw_box(_wp(stall_pos,
				Vector3(sx, 1.15, -depth * 0.5), yaw),
				Vector3(0.06, 1.82, depth), yaw)
			_mbox(stall, Vector3(sx, 1.02, -depth),
				Vector3(0.075, 2.04, 0.075), Mats.sch_trim())
		_mbox(stall, Vector3(0, 2.02, -depth),
			Vector3(w, 0.09, 0.08), Mats.sch_trim())
		# One restrained door angle per cubicle. The old panels used their long
		# axis as the hinge offset and fanned through one another.
		var extent := 1.0 if i % 2 == 0 else -1.0
		var angle := lerpf(0.10, 0.62,
			WorldGen.r01(wseed, cell.x + i, cell.y, 505))
		var door_w := w - 0.14
		var door := Node3D.new()
		door.position = Vector3(-extent * w * 0.5 + extent * 0.055,
			0, -depth)
		door.rotation.y = extent * angle
		door.set_meta("school_stall_door", true)
		stall.add_child(door)
		_mbox(door, Vector3(extent * door_w * 0.5, 1.10, 0),
			Vector3(door_w, 1.66, 0.055), pm)
		_mcyl(door, Vector3(extent * (door_w - 0.12), 1.10, -0.05),
			0.025, 0.05, Mats.sch_trim()).rotation.x = PI / 2.0
		var door_local := door.position + Vector3(extent * door_w * 0.5,
			1.10, 0).rotated(Vector3.UP, door.rotation.y)
		_collider_yaw_box(_wp(stall_pos, door_local, yaw),
			Vector3(door_w, 1.66, 0.06), yaw + door.rotation.y)
		# Authored porcelain. The stall runs from the wall at local z=0 out to
		# its door at -depth, so the pan turns to put its cistern against the
		# wall and its bowl toward the door. Six primitives used to fake it.
		var pan := _attributed_floor_prop(SCH_TOILET_PATH,
			Vector3(0, 0, -0.30), PI, SCH_TOILET_SCALE, SCH_TOILET_CENTRE,
			"school_stall_toilet", stall)
		if pan != null:
			pan.set_meta("school_stall_toilet", true)
		else:
			_mrbox(stall, Vector3(0, 0.26, -0.43),
				Vector3(0.38, 0.52, 0.48), Mats.sch_white(), 0.10)
			_mellipsoid(stall, Vector3(0, 0.48, -0.62),
				Vector3(0.54, 0.22, 0.68), Mats.sch_white())
			var seat := MeshInstance3D.new()
			seat.mesh = TOR
			seat.material_override = Mats.sch_trim()
			seat.position = Vector3(0, 0.57, -0.64)
			seat.scale = Vector3(0.27, 0.045, 0.34)
			seat.set_meta("school_stall_toilet", true)
			stall.add_child(seat)
			_mrbox(stall, Vector3(0, 0.78, -0.16),
				Vector3(0.48, 0.58, 0.24), Mats.sch_white(), 0.045)
			_mbox(stall, Vector3(0, 1.085, -0.16),
				Vector3(0.50, 0.045, 0.27), Mats.sch_white())
		_collider_yaw_box(_wp(stall_pos, Vector3(0, 0.37, -0.30), yaw),
			Vector3(0.52, 0.74, 0.64), yaw)
		_bind_furnishing_colliders(stall, b0)


## Sinks under a long mirror, one tap dripping somewhere in the building.
func _sch_sinks(dir: int) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var facing := _wall_facing(dir)
	var cnt := 3
	var w := 0.92
	var start := S / 2.0 - float(cnt) * w * 0.5
	var d := inner + n * 0.22
	# mirror band
	var mp := Vector3(inner + n * 0.02, 1.72, S / 2.0) if dir < 2 \
		else Vector3(S / 2.0, 1.72, inner + n * 0.02)
	_box(mp, Vector3(0.02, 0.9, float(cnt) * w) if dir < 2 else Vector3(float(cnt) * w, 0.9, 0.02),
		Mats.gold_mirror(), false)
	for i in cnt:
		var t := start + w * (float(i) + 0.5)
		# The authored basin is a pedestal unit with its own tap and trap, so
		# it takes a wall point directly rather than a box and a chrome stub.
		var sp := Vector3(inner + n * 0.30, 0, t) if dir < 2 \
			else Vector3(t, 0, inner + n * 0.30)
		var sink_b0 := body.get_child_count()
		var basin := _attributed_floor_prop(SCH_SINK_PATH, sp, facing,
			SCH_SINK_SCALE, SCH_SINK_CENTRE, "school_sink", null, true)
		if basin != null:
			_collider_yaw_box(sp + Vector3(0, 0.54, 0),
				Vector3(0.75, 1.07, 0.60), facing)
			_bind_furnishing_colliders(basin, sink_b0)
			continue
		var bp := Vector3(d, 0.86, t) if dir < 2 else Vector3(t, 0.86, d)
		_box(bp, Vector3(0.44, 0.16, 0.6) if dir < 2 else Vector3(0.6, 0.16, 0.44),
			Mats.sch_white(), true)
		var tp := Vector3(inner + n * 0.08, 1.06, t) if dir < 2 else Vector3(t, 1.06, inner + n * 0.08)
		_cyl(tp, 0.02, 0.16, Mats.chrome(), false)


## A run of wall-hung urinals on the wall opposite the stalls. The generated
## bathroom never had any. This is the one authored fixture that must not be
## floor-corrected: it is modelled already hanging, its lowest point 0.60m up
## its own mounting plane, so only X and Z are recentred.
func _sch_urinals(dir: int) -> void:
	var facing := _wall_facing(dir)
	var cnt := 3
	var w := 0.78
	var start := S / 2.0 - float(cnt) * w * 0.5
	for i in cnt:
		var t := start + w * (float(i) + 0.5)
		var p := _wall_pt(dir, t, 0.0)
		var b0 := body.get_child_count()
		var pivot := Node3D.new()
		pivot.position = p
		pivot.rotation.y = facing
		# Wall-hung, so no `floor_supported`: the support audit would otherwise
		# want its lowest mesh on the floor, which is the one thing it is not.
		pivot.set_meta("atomic_furnishing", "school_urinal")
		_furnishing_group_serial += 1
		pivot.set_meta("furnishing_group", _furnishing_group_serial)
		add_child(pivot)
		var unit := _attributed_prop_local(pivot, SCH_URINAL_PATH,
			Vector3(-SCH_URINAL_CENTRE.x, 0.0, -SCH_URINAL_CENTRE.z)
				* SCH_URINAL_SCALE, 0.0, Vector3.ONE * SCH_URINAL_SCALE)
		if unit == null:
			pivot.get_parent().remove_child(pivot)
			pivot.free()
			return
		pivot.set_meta("attributed_furnishing", "school_urinal")
		unit.set_meta("authored_model", "school_urinal")
		_collider_yaw_box(p + Vector3(0, 1.04, 0.20).rotated(Vector3.UP, facing),
			Vector3(0.36, 0.90, 0.40), facing)
		_bind_furnishing_colliders(pivot, b0)


func _sch_gym() -> void:
	var span := _room_span()
	var half := minf(span.x, span.y) * 0.5
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# painted court, laid on the boards
	var lm := Mats.sch_red()
	var cl := half - 1.6
	for sx in [-cl, cl]:
		_box(c + Vector3(sx, 0.004, 0), Vector3(0.06, 0.008, cl * 2.0), lm, false)
	for sz in [-cl, cl]:
		_box(c + Vector3(0, 0.004, sz), Vector3(cl * 2.0, 0.008, 0.06), lm, false)
	_box(c + Vector3(0, 0.004, 0), Vector3(cl * 2.0, 0.008, 0.06), lm, false)
	_cyl(c + Vector3(0, 0.004, 0), 1.8, 0.008, lm, false)
	_cyl(c + Vector3(0, 0.006, 0), 1.66, 0.008, Mats.sch_gymfloor(), false)
	# a hoop at each end, and bleachers down one side
	for sgn in [-1.0, 1.0]:
		_sch_hoop(c + Vector3(0, 0, sgn * (half - 0.7)), 0.0 if sgn < 0.0 else PI)
	_sch_bleachers(c + Vector3(-(half - 1.3), 0, 0), PI / 2.0, minf(half * 1.5, 9.0))
	if _r(600) < 0.6:
		_sch_bleachers(c + Vector3(half - 1.3, 0, 0), -PI / 2.0, minf(half * 1.5, 9.0))


## Landmark: the school auditorium. A real raised stage and two disciplined
## seating banks give the hall a remembered orientation, while one displaced
## modelled chair breaks the procedural rhythm near the centre aisle.
func _sch_auditorium() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var stage := c + Vector3(0, 0, -8.2)
	_rbox(stage + Vector3(0, 0.32, 0), Vector3(15.5, 0.64, 3.5), Mats.sch_desk(), 0.025)
	_collider_box(stage + Vector3(0, 0.34, 0), Vector3(15.6, 0.68, 3.6))
	# Heavy red curtains, closed except for an uneasy centre gap.
	for side: float in [-1.0, 1.0]:
		for i in 6:
			var x := side * (1.0 + 1.15 * float(i))
			_box(stage + Vector3(x, 3.1, -1.58), Vector3(0.72, 5.3, 0.10),
				Mats.velvet() if i % 2 == 0 else Mats.velvet2(), false)
	# Lectern and a microphone left facing the empty seats.
	_rbox(stage + Vector3(-2.0, 1.05, 0.35), Vector3(1.1, 1.45, 0.65), Mats.darkwood(), 0.035)
	var stem := _cyl(stage + Vector3(1.6, 1.35, 0.35), 0.025, 1.9, Mats.charcoal(), false)
	stem.rotation.z = -0.12
	_sphere(stage + Vector3(1.72, 2.28, 0.35), 0.06, Mats.charcoal())
	# Six rows, split by the centre aisle, using the same authored blue plastic
	# chair as classrooms instead of simplified procedural seat blocks.
	for row in 6:
		var z := -4.6 + 2.05 * float(row)
		for side in [-1.0, 1.0]:
			var row_c := c + Vector3(side * 4.2, 0, z)
			for col in 5:
				var x := (float(col) - 2.0) * 1.25
				var p := row_c + Vector3(x, 0, 0)
				var chair_yaw := PI + \
					(_r(1200 + row * 10 + col) - 0.5) * 0.05
				_asy_model("SchoolChair_01", p, chair_yaw)
			_collider_box(row_c + Vector3(0, 0.58, 0), Vector3(6.0, 1.16, 0.78))
	var loose := c + Vector3(0.25, 0, 5.8)
	_asy_model("SchoolChair_01", loose, PI + 0.48)
	_collider_yaw_box(loose + Vector3(0, 0.5, 0), Vector3(0.58, 1.02, 0.7), PI + 0.48)
	# Structural openings add their own housed EXIT cabinets. Decorative raw
	# words on this back wall looked like floating navigation markers and could
	# imply doors that do not exist, so the auditorium adds none of its own.


## Backboard, ring, and the folded arms holding it off the wall.
func _sch_hoop(p: Vector3, yaw: float) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mbox(v, Vector3(0, 3.05, 0), Vector3(1.8, 1.05, 0.05), Mats.sch_white())
	_mbox(v, Vector3(0, 2.86, 0), Vector3(0.59, 0.45, 0.02), Mats.sch_red())
	_mbox(v, Vector3(0, 2.62, 0.22), Vector3(0.45, 0.03, 0.45), Mats.sch_red())
	for sx in [-0.5, 0.5]:
		_mbox(v, Vector3(sx, 3.5, -0.5), Vector3(0.06, 0.06, 1.1), Mats.sch_trim())
	_mbox(v, Vector3(0, 3.05, -0.55), Vector3(0.08, 0.08, 1.1), Mats.sch_trim())
	# net, as a ring of short hanging strands
	for i in 8:
		var a := TAU * float(i) / 8.0
		_mcyl(v, Vector3(sin(a) * 0.2, 2.46, 0.22 + cos(a) * 0.2), 0.008, 0.3, Mats.box_white())


## Retractable bleachers, pulled out and left out.
func _sch_bleachers(p: Vector3, yaw: float, ln: float) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var tiers := 4
	for i in tiers:
		var y := 0.42 + 0.42 * float(i)
		var z := -0.4 - 0.62 * float(i)
		_mbox(v, Vector3(0, y, z), Vector3(ln, 0.06, 0.5), Mats.sch_desk())
		_mbox(v, Vector3(0, y - 0.21, z - 0.28), Vector3(ln, 0.42, 0.06), Mats.sch_trim())
	_collider_yaw_box(p + Vector3(-sin(yaw) * 1.5, 1.0, -cos(yaw) * 1.5),
		Vector3(ln, 2.0, 3.0), yaw)


func _sch_library() -> void:
	var span := _room_span()
	# Run stacks parallel to the dominant doorway flow and distribute them
	# across that flow. The old layout varied their position along the same axis
	# as their length, overlapping the runs into one solid barricade.
	var x_doors := 0
	var z_doors := 0
	for member in _room_members():
		for dir in 4:
			var edge := WorldGen.edge_info(wseed, member, dir, theme)
			if edge["wall"] or edge["full_open"]:
				continue
			if dir < 2:
				x_doors += 1
			else:
				z_doors += 1
	var along_x := x_doors >= z_doors if x_doors + z_doors > 0 else span.x >= span.y
	var large := maxf(span.x, span.y) > 20.0
	var runs := 3 if large else 2
	for i in runs:
		var pitch := 5.8 if large else 8.4
		var u := (float(i) - float(runs - 1) * 0.5) * pitch
		var p := Vector3(S / 2.0, 0, S / 2.0 + u) if along_x \
			else Vector3(S / 2.0 + u, 0, S / 2.0)
		_sch_stack(p, 0.0 if along_x else PI / 2.0, 620 + i * 9)
	# The small-room table sits between the end approaches; large libraries have
	# enough interior depth to move it out into a separate reading bay.
	var tp := Vector3(S / 2.0, 0, S / 2.0)
	if large:
		tp += Vector3(0, 0, 7.8) if along_x else Vector3(7.8, 0, 0)
	_sch_caf_table(tp, 0.0 if along_x else PI / 2.0, 640)


## A double-sided run of shelving, most of it still full.
func _sch_stack(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var ln := 4.4
	var hgt := 2.0
	var real_side := -0.17 if _r(salt + 20) < 0.5 else 0.17
	var real_sh := 1 + int(_r(salt + 21) * 2.99)
	var real_left := lerpf(-1.65, 0.95, _r(salt + 22))
	_mbox(v, Vector3(0, hgt / 2.0, 0), Vector3(ln, hgt, 0.06), Mats.sch_desk())
	for sz in [-0.17, 0.17]:
		for sh in 4:
			var y := 0.42 + 0.46 * float(sh)
			_mbox(v, Vector3(0, y, sz), Vector3(ln, 0.04, 0.34), Mats.sch_desk())
			# books, in blocks with gaps where a shelf has been raided
			var x := -ln * 0.5 + 0.2
			var k := 0
			while x < ln * 0.5 - 0.3:
				var bw := lerpf(0.25, 0.7, WorldGen.r01(wseed, cell.x + k, cell.y + sh, salt))
				if is_equal_approx(sz, real_side) and sh == real_sh \
						and x + bw > real_left - 0.03 and x < real_left + 0.62:
					x = real_left + 0.66
					k += 1
					continue
				if WorldGen.r01(wseed, cell.x + k * 3, cell.y + sh, salt + 1) < 0.28:
					x += bw
					k += 1
					continue
				var bh := lerpf(0.24, 0.34, WorldGen.r01(wseed, k, sh, salt + 2))
				var hue := WorldGen.r01(wseed, k * 7, sh, salt + 3)
				_mbox(v, Vector3(x + bw * 0.5, y + 0.02 + bh * 0.5, sz), Vector3(bw, bh, 0.26),
					Mats.sch_chair(hue))
				x += bw + 0.03
				k += 1
	_mbox(v, Vector3(0, hgt - 0.02, 0), Vector3(ln, 0.05, 0.42), Mats.sch_desk())
	var origin_x := real_left if real_side > 0.0 else real_left + 0.55
	var by := 0.42 + 0.46 * float(real_sh) + 0.025
	_cc0_prop("book_encyclopedia_set_01",
		_wp(p, Vector3(origin_x, by, real_side), yaw),
		yaw if real_side > 0.0 else yaw + PI)
	_collider_yaw_box(p + Vector3(0, hgt / 2.0, 0), Vector3(ln, hgt, 0.46), yaw)


func _sch_lab() -> void:
	var span := _room_span()
	var along_x := span.x >= span.y
	var yaw := 0.0 if along_x else PI / 2.0
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var table_positions: Array[Vector3] = [c]
	if maxf(span.x, span.y) > 18.0:
		var axis := Vector3.RIGHT if along_x else Vector3.FORWARD
		table_positions = [c - axis * 3.75, c + axis * 3.75]
	for ti in table_positions.size():
		var p: Vector3 = table_positions[ti]
		var salt := 700 + ti * 31
		if not _sch_chemistry_table(p, yaw, salt):
			continue
		# Tall lab stools line the two long working faces. Their assemblies and
		# colliders are atomic, so doorway clearance may remove an end stool
		# without leaving a floating seat or an invisible obstruction.
		for side in [-1.0, 1.0]:
			for si in 3:
				if _r(salt + 10 + si + (8 if side > 0.0 else 0)) < 0.14:
					continue
				var local := Vector3((float(si) - 1.0) * 1.35, 0,
					side * 2.68)
				_sch_stool(_wp(p, local, yaw),
					salt + 18 + si + (8 if side > 0.0 else 0))
	var fw := _sch_front_wall(710)
	if fw >= 0:
		_sch_chalkboard(fw)


## The authored island already includes its base cabinets, black worktop, sink,
## taps and plumbing. It replaces the former primitive bench completely rather
## than sitting on top of it. Individual glassware pieces use triangle-verified
## support slots on its L-shaped 0.862m work surface.
func _sch_chemistry_table(p: Vector3, yaw: float, salt: int) -> bool:
	var body0 := body.get_child_count()
	var table := _furnishing_pivot(p, yaw, "school_chemistry_table")
	table.set_meta("attributed_furnishing", "school_chemistry_table")
	table.set_meta("chemistry_surface_y", 0.862)
	var inst := _attributed_prop_local(table, SCH_CHEMISTRY_TABLE_PATH,
		-SCH_CHEMISTRY_TABLE_CENTRE * SCH_CHEMISTRY_TABLE_SCALE, 0.0,
		Vector3.ONE * SCH_CHEMISTRY_TABLE_SCALE)
	if inst == null:
		table.get_parent().remove_child(table)
		table.free()
		return false
	inst.set_meta("authored_model", "school_chemistry_table")
	var item_count := 3 + int(_r(salt + 2) * 3.99)
	var first_slot := int(_r(salt + 3) \
		* SCH_CHEMISTRY_COUNTER_POINTS.size())
	var stride := 3 if _r(salt + 4) < 0.5 else 7
	for item in item_count:
		var slot := (first_slot + item * stride) \
			% SCH_CHEMISTRY_COUNTER_POINTS.size()
		var point: Vector3 = SCH_CHEMISTRY_COUNTER_POINTS[slot]
		point.x += (_r(salt + 20 + item * 3) - 0.5) * 0.10
		point.z += (_r(salt + 21 + item * 3) - 0.5) * 0.10
		var glass := _chemistry_glassware(table, point,
			_r(salt + 22 + item * 3) * TAU, salt + 50 + item * 11,
			false, "school_lab")
		if glass != null:
			glass.set_meta("school_counter_slot", slot)
	_collider_yaw_box(p + Vector3(0, 0.44, 0),
		Vector3(4.46, 0.88, 3.86), yaw)
	_bind_furnishing_colliders(table, body0)
	return true


func _sch_stool(p: Vector3, salt: int) -> void:
	var body0 := body.get_child_count()
	var v := _furnishing_pivot(p,
		WorldGen.r01(wseed, cell.x, cell.y, salt) * TAU, "school_lab_stool")
	_mcyl(v, Vector3(0, 0.62, 0), 0.17, 0.05, Mats.sch_desk())
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI / 4.0
		_mcyl(v, Vector3(sin(a) * 0.13, 0.31, cos(a) * 0.13), 0.014, 0.62, Mats.sch_trim())
	_mcyl(v, Vector3(0, 0.28, 0), 0.15, 0.02, Mats.sch_trim())
	_collider_cyl(p + Vector3(0, 0.32, 0), 0.2, 0.64)
	_bind_furnishing_colliders(v, body0)


func _sch_admin() -> void:
	var fw := _sch_front_wall(800)
	# the counter you wait at, across the room
	var yaw := _sch_face_yaw(fw if fw >= 0 else 3)
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var v := Node3D.new()
	v.position = c
	v.rotation.y = yaw
	add_child(v)
	_mbox(v, Vector3(0, 0.52, 0), Vector3(4.4, 1.04, 0.5), Mats.sch_desk())
	_mbox(v, Vector3(0, 1.08, 0), Vector3(4.6, 0.07, 0.66), Mats.sch_desk())
	_collider_yaw_box(c + Vector3(0, 0.55, 0), Vector3(4.4, 1.1, 0.55), yaw)
	var back := c - Vector3(sin(yaw), 0, cos(yaw)) * 2.4
	_office_desk_small(back, yaw + PI)
	_shelf_unit(back + Vector3(cos(yaw) * 2.2, 0, -sin(yaw) * 2.2), absf(cos(yaw)) > 0.5, 810)


# --- school: things on the walls ----------------------------------------------

## Cork board behind glass, layered with notices for terms already over.
func _sch_noticeboard(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(900 + dir) - 0.5) * 3.4
	var w := lerpf(1.5, 2.4, _r(904 + dir))
	var y := 1.62
	var d0 := inner + n * 0.03
	var frame := Vector3(0.06, 1.25, w) if dir < 2 else Vector3(w, 1.25, 0.06)
	var fp := Vector3(d0, y, along) if dir < 2 else Vector3(along, y, d0)
	_box(fp, frame, Mats.sch_trim(), false)
	var cork := Vector3(0.02, 1.12, w - 0.1) if dir < 2 else Vector3(w - 0.1, 1.12, 0.02)
	var cp := Vector3(d0 + n * 0.03, y, along) if dir < 2 else Vector3(along, y, d0 + n * 0.03)
	_box(cp, cork, Mats.sch_cork(), false)
	for i in 6:
		var px := along + (WorldGen.r01(wseed, cell.x + i, cell.y, 908 + dir) - 0.5) * (w - 0.35)
		var py := y + (WorldGen.r01(wseed, cell.x, cell.y + i, 912 + dir) - 0.5) * 0.85
		var ps := Vector3(0.008, 0.26, 0.19) if dir < 2 else Vector3(0.19, 0.26, 0.008)
		var pp := Vector3(d0 + n * 0.05, py, px) if dir < 2 else Vector3(px, py, d0 + n * 0.05)
		_box(pp, ps, Mats.box_white(), false)


## Drinking fountain. Two of them, always, at the height of two different
## years of children.
func _sch_fountain(dir: int, plane: float) -> void:
	# A bathroom has its own plumbing and every wall already spoken for by
	# stalls, sinks or urinals. The old fountain was a 0.44m-deep pair of boxes
	# and could tuck in beside a stall run; the authored bubbler is 0.92m deep
	# and lands inside one.
	if style == WorldGen.SCH_BATHROOM:
		return
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(920 + dir) - 0.5) * 3.0
	var facing := _wall_facing(dir)
	# One authored bubbler with its own bowl, bubbler head and back panel,
	# where the pair of stacked boxes used to stand in for two.
	var fp := Vector3(inner + n * 0.44, 0, along) if dir < 2 \
		else Vector3(along, 0, inner + n * 0.44)
	# Corridor walls carry locker banks, and a bubbler that deep will sit
	# inside one. Slide along the wall for a gap before giving the wall up.
	if not _floor_spot_clear(fp, 0.46):
		var found := false
		for step in 6:
			var shift := (float(step) - 2.5) * 1.7
			var alt := fp + (Vector3(0, 0, shift) if dir < 2 \
				else Vector3(shift, 0, 0))
			if alt.x < 1.4 or alt.x > S - 1.4 or alt.z < 1.4 or alt.z > S - 1.4:
				continue
			if _floor_spot_clear(alt, 0.46):
				fp = alt
				found = true
				break
		if not found:
			return
	var fount_b0 := body.get_child_count()
	var bubbler := _attributed_floor_prop(SCH_FOUNTAIN_PATH, fp, facing,
		SCH_FOUNTAIN_SCALE, SCH_FOUNTAIN_CENTRE, "school_fountain", null, true)
	if bubbler != null:
		_collider_yaw_box(fp + Vector3(0, 0.53, 0),
			Vector3(0.88, 1.05, 0.92), facing)
		_bind_furnishing_colliders(bubbler, fount_b0)
		return
	for pair in 2:
		var t := along + (float(pair) - 0.5) * 0.72
		var y := 0.86 if pair == 0 else 0.72
		var d0 := inner + n * 0.19
		var bs := Vector3(0.38, 0.36, 0.44) if dir < 2 else Vector3(0.44, 0.36, 0.38)
		var bp := Vector3(d0, y, t) if dir < 2 else Vector3(t, y, d0)
		_box(bp, bs, Mats.sch_white(), true)
		var ss := Vector3(0.34, 0.05, 0.4) if dir < 2 else Vector3(0.4, 0.05, 0.34)
		var sp := Vector3(d0, y + 0.19, t) if dir < 2 else Vector3(t, y + 0.19, d0)
		_box(sp, ss, Mats.chrome(), false)


## The trophy case by the front doors, still lit, still full.
func _sch_case(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(930 + dir) - 0.5) * 2.6
	var w := 2.2
	var y := 1.5
	var depth := 0.34
	var d0 := inner + n * depth * 0.5
	var box := Vector3(depth, 1.9, w) if dir < 2 else Vector3(w, 1.9, depth)
	var bp := Vector3(d0, y, along) if dir < 2 else Vector3(along, y, d0)
	_box(bp, box, Mats.sch_trim(), true)
	var gs := Vector3(0.02, 1.7, w - 0.14) if dir < 2 else Vector3(w - 0.14, 1.7, 0.02)
	var gp := Vector3(inner + n * (depth + 0.01), y, along) if dir < 2 \
		else Vector3(along, y, inner + n * (depth + 0.01))
	_box(gp, gs, Mats.glass(), false)
	for sh in 3:
		var sy := 0.95 + 0.52 * float(sh)
		var ss := Vector3(depth - 0.08, 0.03, w - 0.16) if dir < 2 else Vector3(w - 0.16, 0.03, depth - 0.08)
		var sp := Vector3(d0, sy, along) if dir < 2 else Vector3(along, sy, d0)
		_box(sp, ss, Mats.sch_desk(), false)
		for i in 4:
			var tx := along + (float(i) - 1.5) * 0.48
			var hgt := lerpf(0.16, 0.3, WorldGen.r01(wseed, cell.x + i, cell.y + sh, 934))
			var tp := Vector3(d0, sy + 0.03 + hgt * 0.5, tx) if dir < 2 \
				else Vector3(tx, sy + 0.03 + hgt * 0.5, d0)
			_cyl(tp, 0.05, hgt, Mats.brass(), false)
			var cp2 := tp + Vector3(0, hgt * 0.5, 0)
			_sphere(cp2, 0.06, Mats.brass())


## A poster, curling at one corner: fire drill, periodic table, a motto.
func _sch_poster(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(940 + dir) - 0.5) * 4.0
	var y := lerpf(1.5, 2.0, _r(944 + dir))
	var w := lerpf(0.55, 0.9, _r(948 + dir))
	var h := w * 1.4
	var hue := _r(952 + dir)
	var ps := Vector3(0.012, h, w) if dir < 2 else Vector3(w, h, 0.012)
	var pp := Vector3(inner + n * 0.02, y, along) if dir < 2 else Vector3(along, y, inner + n * 0.02)
	var mi := _box(pp, ps, Mats.sch_chair(hue), false)
	mi.rotate_object_local(Vector3(1, 0, 0) if dir < 2 else Vector3(0, 0, 1),
		(_r(956 + dir) - 0.5) * 0.06)


# --- abandoned shopping mall -------------------------------------------------

const MALL_NAMES := ["ORCHARD", "ARCADE", "HOUSE & HOME", "PARADE",
	"LEVEL TWO", "FOOD GALLERY", "CLOSED", "COMING SOON",
	"RADIO HUT", "SHOE PALACE", "GOLDEN WOK", "PHOTO 1 HR",
	"CARD & PARTY", "PRETZEL TIME", "BOOKS & CO", "FASHION CITY",
	"TOY CHEST", "NAILS", "OPTICA", "GIFT GARDEN",
	"PET CORNER", "RECORD BAR", "LUGGAGE WORLD", "SUIT YOURSELF"]
const MALL_FOOD := ["GOLDEN WOK", "PRETZEL TIME", "BURGER BARN", "TACO FIESTA",
	"ORANGE JULIET", "PIZZA MIA", "DONUT DEN", "CHICKEN SHACK"]


func _mall_lighting() -> void:
	var dead := cell != Vector2i.ZERO and _r(1600) < 0.10
	var flicker := not dead and cell != Vector2i.ZERO and _r(1601) < 0.14
	var lens: StandardMaterial3D = Mats.panel_dead() if dead else Mats.mall_panel()
	if flicker:
		lens = Mats.mall_panel().duplicate()
	var cor := style == WorldGen.MALL_CORRIDOR
	var cdir := WorldGen.corridor(wseed, cell)
	if cor:
		var along_x := cdir != 2
		for t in [-4.2, -1.4, 1.4, 4.2]:
			var p := Vector3(6.0 + t, 0, 6.0) if along_x else Vector3(6.0, 0, 6.0 + t)
			_troffer(p, Vector2(1.65, 0.24) if along_x else Vector2(0.24, 1.65),
				lens, Mats.mall_trim())
	else:
		for p in [Vector2(3.0, 3.0), Vector2(9.0, 3.0),
				Vector2(3.0, 9.0), Vector2(9.0, 9.0)]:
			_troffer(Vector3(p.x, 0, p.y), Vector2(1.25, 0.3), lens, Mats.mall_trim())
	if dead:
		return
	var light := _make_main_light(flicker, lens, 1.08 if cor else 1.22)
	light.light_color = Color(1.0, 0.74, 0.48)
	light.omni_range = 13.5
	light.position = Vector3(6, ceil_h - 0.65, 6)
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 25.0
	light.distance_fade_length = 8.0
	add_child(light)


func _mall_poster_case(dir: int, plane: float) -> void:
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var inner := plane + n * (T * 0.5 + 0.04)
	var along := lerpf(3.3, 8.7, _r(1610 + dir))
	var pos := Vector3(inner, 1.65, along) if dir < 2 else Vector3(along, 1.65, inner)
	var frame_size := Vector3(0.10, 1.75, 1.14) if dir < 2 else Vector3(1.14, 1.75, 0.10)
	_box(pos, frame_size, Mats.mall_trim(), false)
	var paper_pos := pos + (Vector3(n * 0.06, 0, 0) if dir < 2 else Vector3(0, 0, n * 0.06))
	var paper_size := Vector3(0.012, 1.58, 0.97) if dir < 2 else Vector3(0.97, 1.58, 0.012)
	_box(paper_pos, paper_size,
		Mats.sch_chair(0.48 if _r(1614 + dir) < 0.5 else 0.08), false)
	var out := Vector3(n, 0, 0) if dir < 2 else Vector3(0, 0, n)
	var art_pos := paper_pos + out * 0.006
	var yaw := (PI / 2.0 if n > 0.0 else -PI / 2.0) if dir < 2 \
		else (0.0 if n > 0.0 else PI)
	_wall_art_mount(art_pos, yaw, dir, _wall_art_path(1622 + dir * 9),
		Vector2(0.91, 1.50), 0.0)
	var glass_pos := paper_pos + out * 0.035
	_box(glass_pos, paper_size, Mats.mall_glass(), false)


## A box on the room side of a wall. `off` is the distance from the wall's
## inner face to the box CENTRE, `along` the position down the wall, `w` its
## width along the wall, `h` height, `d` depth off the wall.
func _sfb(dir: int, plane: float, off: float, along: float, y: float,
		w: float, h: float, d: float, mat: Material, collide := false) -> MeshInstance3D:
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var p := plane + n * (T * 0.5 + off)
	if dir < 2:
		return _box(Vector3(p, y, along), Vector3(d, h, w), mat, collide)
	return _box(Vector3(along, y, p), Vector3(w, h, d), mat, collide)


## Real shopfronts where a blank gallery wall would be: two retail units under
## sign fascias, each shuttered, half-shuttered, or dead glass over a black
## interior. This is the thing that makes the gallery read as a mall.
func _mall_storefront(dir: int, plane: float) -> void:
	for ui in 2:
		_mall_unit(dir, plane, 3.15 if ui == 0 else 8.85, 4.8, 1700 + ui * 40 + dir)
	# masonry pier between the two units
	_sfb(dir, plane, 0.28, 6.0, 1.8, 0.9, 3.6, 0.56, Mats.mall_wall(), true)


func _mall_unit(dir: int, plane: float, uc: float, w: float, salt: int) -> void:
	var giv := WorldGen.h(wseed, cell.x, cell.y, salt)
	var rs := WorldGen.hr01(giv, 1)
	var state := 0          # 0 shutter down, 1 three-quarters, 2 dead glass
	if rs > 0.55: state = 1
	if rs > 0.80: state = 2
	var top := minf(3.6, ceil_h - 0.05)
	var gt := top - 0.62    # glass / shutter head height under the fascia
	# end piers and soffit lid
	for side in [-1.0, 1.0]:
		_sfb(dir, plane, 0.28, uc + side * (w / 2.0 - 0.10), top / 2.0,
			0.20, top, 0.56, Mats.mall_trim(), true)
	_sfb(dir, plane, 0.30, uc, top + 0.03, w, 0.06, 0.60, Mats.mall_trim())
	# Sign fascia with the store's name on it. A painted board needs a dark
	# backing: the lightbox face is pale and faintly emissive, so it shows past
	# the artwork's own edges as two lit strips.
	var painted := _mall_painted_sign_index(giv)
	_sfb(dir, plane, 0.28, uc, top - 0.29, w - 0.4, 0.50, 0.50,
		Mats.mall_sign_board() if painted >= 0 else Mats.mall_sign_face())
	_mall_unit_sign(dir, plane, uc, giv, top - 0.29, painted)
	# black interior behind whatever closes the front
	_sfb(dir, plane, 0.24, uc, gt / 2.0, w - 0.5, gt, 0.44, Mats.charcoal())
	# floor bulkhead riser
	_sfb(dir, plane, 0.47, uc, 0.175, w - 0.4, 0.35, 0.12, Mats.mall_trim())
	if state == 0:
		_sfb(dir, plane, 0.50, uc, (0.06 + gt) / 2.0, w - 0.5, gt - 0.06, 0.05,
			Mats.mall_shutter())
		_sfb(dir, plane, 0.50, uc, 0.10, w - 0.5, 0.08, 0.07, Mats.mall_trim())
	elif state == 1:
		# stuck three-quarters down: a black gap breathes underneath
		_sfb(dir, plane, 0.50, uc, (1.1 + gt) / 2.0, w - 0.5, gt - 1.1, 0.05,
			Mats.mall_shutter())
		_sfb(dir, plane, 0.50, uc, 1.06, w - 0.5, 0.08, 0.07, Mats.mall_trim())
	else:
		# dead glass over the dark: three bays, mullions, a push-bar door
		var bw := (w - 0.5) / 3.0
		for b in 3:
			var bc := uc - (w - 0.5) / 2.0 + bw * (float(b) + 0.5)
			_sfb(dir, plane, 0.50, bc, 0.35 + (gt - 0.35) / 2.0, bw - 0.06,
				gt - 0.35, 0.02, Mats.mall_glass())
		for mx in [-1.5, -0.5, 0.5, 1.5]:
			_sfb(dir, plane, 0.50, uc + mx * bw, gt / 2.0 + 0.175, 0.06,
				gt - 0.35, 0.07, Mats.mall_trim())
		_sfb(dir, plane, 0.53, uc, 1.05, bw - 0.3, 0.05, 0.03, Mats.brass())
	# shutter housing above the head
	_sfb(dir, plane, 0.44, uc, gt + 0.14, w - 0.4, 0.26, 0.30, Mats.charcoal())
	# one solid collider across the unit
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var p := plane + n * (T * 0.5 + 0.30)
	if dir < 2:
		_collider_box(Vector3(p, top / 2.0, uc), Vector3(0.60, top, w))
	else:
		_collider_box(Vector3(uc, top / 2.0, p), Vector3(w, top, 0.60))


## A painted fascia sign cropped from the CC BY-NC mall source, fitted to the
## generated fascia at the artwork's own aspect so it is never stretched.
##
## This is the single point where that noncommercial dependency enters the game.
## Delete this function and the `_mall_painted_sign` call in `_mall_unit_sign`
## and every storefront falls back to the generated MALL_NAMES lettering, with
## nothing else to unpick.
## Which painted fascia this unit gets, or -1 for generated lettering. Decided
## before the fascia is built, because the two want different backing — and the
## texture is confirmed present here so the dark board can never end up hosting
## the generated lettering, which would be unreadable on it.
func _mall_painted_sign_index(giv: int) -> int:
	if WorldGen.hr01(giv, 7) >= 0.55:
		return -1
	var index: int = giv % MALL_SIGN_FACES.size()
	if not ResourceLoader.exists(MALL_SIGN_DIR + "sign_%s.webp"
			% MALL_SIGN_FACES[index][0]):
		return -1
	return index


func _mall_painted_sign(dir: int, plane: float, uc: float, index: int,
		y: float) -> bool:
	var entry: Array = MALL_SIGN_FACES[index]
	var tex := load(MALL_SIGN_DIR + "sign_%s.webp" % entry[0]) as Texture2D
	if tex == null:
		return false
	var aspect: float = entry[1]
	# Fit to whichever bound binds first, never stretching the artwork.
	var h: float = minf(MALL_SIGN_MAX_H, MALL_SIGN_MAX_W / aspect)
	var w: float = h * aspect
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.86
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	# The shutter housing's front face stands 0.665m off the plane. Anything
	# shallower than that has its lower half swallowed by the housing, which is
	# exactly the bug the generated lettering was moved to 0.70 to escape.
	var p := plane + n * (T * 0.5 + 0.70)
	var quad := MeshInstance3D.new()
	quad.mesh = QUAD
	quad.material_override = mat
	quad.scale = Vector3(w, h, 1.0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if dir < 2:
		quad.position = Vector3(p, y, uc)
		quad.rotation.y = -PI / 2.0 if dir == 0 else PI / 2.0
	else:
		quad.position = Vector3(uc, y, p)
		quad.rotation.y = PI if dir == 2 else 0.0
	quad.set_meta("mall_painted_sign", entry[0])
	quad.set_meta("mall_sign_fit", Vector2(w, h))
	add_child(quad)
	return true


func _mall_unit_sign(dir: int, plane: float, uc: float, giv: int, y: float,
		painted := -1) -> void:
	if painted >= 0 and _mall_painted_sign(dir, plane, uc, painted, y):
		return
	var text: String = MALL_NAMES[giv % MALL_NAMES.size()]
	var lit := WorldGen.hr01(giv, 2) < 0.18
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	# The shutter housing projects 0.665m from the wall. The old lettering sat
	# at 0.620m, so its lower strokes were literally behind that geometry.
	# Bring it to the actual front face and fit the full name to the fascia.
	var p := plane + n * (T * 0.5 + 0.70)
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 84
	var sign_font := ThemeDB.fallback_font
	var text_px := sign_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, lab.font_size).x
	var safe_world_width := 3.95
	lab.pixel_size = minf(0.0026, safe_world_width / maxf(text_px + 20.0, 1.0))
	lab.width = ceili(text_px + 24.0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.modulate = Color(1.0, 0.62, 0.42) if lit else Color(0.30, 0.26, 0.22)
	lab.outline_size = 2
	lab.set_meta("mall_store_sign", true)
	lab.set_meta("safe_world_width", safe_world_width)
	if dir < 2:
		lab.position = Vector3(p, y, uc)
		lab.rotation.y = -PI / 2.0 if dir == 0 else PI / 2.0
	else:
		lab.position = Vector3(uc, y, p)
		lab.rotation.y = PI if dir == 2 else 0.0
	add_child(lab)
	if lit:
		# the one sign down the gallery that still runs
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.58, 0.36)
		l.light_energy = 0.55
		l.omni_range = 3.4
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 20.0
		l.distance_fade_length = 8.0
		l.position = lab.position + Vector3(n * 0.3, 0.1, 0) if dir < 2 \
			else lab.position + Vector3(0, 0.1, n * 0.3)
		add_child(l)


## Mall regression hook: storefront lettering must fit its fascia, and exit
## housings must overlap the solid wall above an opening rather than float
## below the lintel.
func mall_fixture_audit() -> Dictionary:
	var report := {
		"store_signs": 0,
		"painted_signs": 0,
		"payphones": 0,
		"directories": 0,
		"exit_signs": 0,
		"foodcourt_brands": 0,
		"violations": 0,
	}
	if theme != 7:
		return report
	# A downloaded model that fails to import falls back silently and would
	# otherwise just quietly stop appearing; count the real ones.
	for node in find_children("*", "Node3D", true, false):
		match str(node.get_meta("authored_model", "")):
			"payphone":
				report["payphones"] += 1
			"mall_directory":
				report["directories"] += 1
	for node in find_children("*", "MeshInstance3D", true, false):
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
	return report


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
		if path.is_empty() or absf(shown - source) > 0.002 \
				or dir < 0 or dir > 3 \
				or not bool(WorldGen.edge_info(wseed, cell, dir, theme)["wall"]) \
				or size.x <= 0.0 or size.y <= 0.0 \
				or p.y - size.y * 0.5 < 0.25 \
				or p.y + size.y * 0.5 > ceil_h - 0.12 \
				or along - size.x * 0.5 < 0.20 \
				or along + size.x * 0.5 > S - 0.20 \
				or partition_overlap:
			report["violations"] += 1
	return report


func _mall_sign(pos: Vector3, yaw: float, text: String, size := 0.12,
		suspended := true) -> Node3D:
	var v := _furnishing_pivot(pos, yaw, "mall_sign", false)
	var sign_w := maxf(1.25, text.length() * 0.13)
	_mrbox(v, Vector3.ZERO,
		Vector3(sign_w, 0.48, 0.08),
		Mats.mall_trim(), 0.03)
	# Directional signs are ceiling-hung in real malls. Two thin rods keep
	# these from reading as unexplained floating rectangles in tall galleries.
	var hanger_h := ceil_h - (pos.y + 0.24)
	if suspended and hanger_h > 0.10:
		for hx in [-sign_w * 0.34, sign_w * 0.34]:
			_mcyl(v, Vector3(hx, 0.24 + hanger_h * 0.5, 0),
				0.015, hanger_h, Mats.brass())
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 72
	lab.pixel_size = 0.002
	lab.modulate = Color(0.92, 0.75, 0.48)
	lab.outline_size = 3
	lab.position = Vector3(0, 0, 0.05)
	v.add_child(lab)
	return v


## Authored wire shopping cart. The source handle is on local -Z while the old
## generated cart's handle was on +Z, so the model turns inside the placement
## pivot. Existing room yaws and loaded-cart contents therefore keep exactly
## the same architectural facing.
func _mall_shopping_cart(p: Vector3, yaw: float, loaded := false) -> void:
	var b0 := body.get_child_count()
	var v := _furnishing_pivot(p, yaw, "mall_shopping_cart")
	v.set_meta("enrichment_prop", "shopping_cart")
	v.set_meta("mall_cart_loaded", loaded)
	var model_yaw := PI
	var source_centre := MALL_SHOPPING_CART_CENTRE.rotated(
		Vector3.UP, model_yaw)
	var authored := _attributed_prop_local(v, MALL_SHOPPING_CART_PATH,
		-source_centre * MALL_SHOPPING_CART_SCALE, model_yaw,
		Vector3.ONE * MALL_SHOPPING_CART_SCALE)
	if authored == null:
		v.get_parent().remove_child(v)
		v.free()
		return
	v.set_meta("attributed_furnishing", "mall_shopping_cart")
	authored.set_meta("authored_model", "mall_shopping_cart")
	if loaded:
		_cc0_prop_local(v, "long_life_food", Vector3(-0.10, 0.62, -0.04),
			0.18, 1.0)
		_mrbox(v, Vector3(0.24, 0.68, 0.12), Vector3(0.26, 0.18, 0.32),
			Mats.box_white(), 0.02)
	_collider_yaw_box(_wp(p, Vector3(0, 0.51, 0), yaw),
		Vector3(0.68, 1.02, 1.05), yaw)
	_bind_furnishing_colliders(v, b0)


## Slatted concourse bench. `yaw` is the direction the sitter faces, matching
## the authored model's local +Z.
func _mall_bench(p: Vector3, yaw: float) -> void:
	var b0 := body.get_child_count()
	var pivot := _attributed_floor_prop(CITY_BENCH_PATH, p, yaw,
		CITY_BENCH_SCALE, CITY_BENCH_CENTRE, "mall_bench", null, true)
	if pivot == null:
		_mrbox_bench_fallback(p, yaw)
		return
	# Collide the seat block only. The backrest is behind it and the cast-iron
	# ends are thin enough that a box around the whole footprint would read as
	# an invisible wall at the edges.
	_collider_yaw_box(p + Vector3(0, 0.42, -0.1), Vector3(1.89, 0.85, 0.5), yaw)
	_bind_furnishing_colliders(pivot, b0)


func _mrbox_bench_fallback(p: Vector3, yaw: float) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mrbox(v, Vector3(0, 0.49, 0), Vector3(2.1, 0.16, 0.58), Mats.sch_desk(), 0.06)
	_mrbox(v, Vector3(0, 0.92, -0.25), Vector3(2.1, 0.58, 0.12), Mats.sch_desk(), 0.04)
	for x in [-0.82, 0.82]:
		_mbox(v, Vector3(x, 0.23, 0), Vector3(0.09, 0.46, 0.50), Mats.mall_trim())
	_collider_yaw_box(p + Vector3(0, 0.52, 0), Vector3(2.1, 1.04, 0.62), yaw)


func _mall_corridor() -> void:
	var along_x := WorldGen.corridor(wseed, cell) != 2
	var yaw := 0.0 if along_x else PI / 2.0
	# seating island down the middle of the gallery: benches back-to-back
	_mall_bench(Vector3(6.0, 0, 7.35) if along_x else Vector3(7.35, 0, 6.0), yaw)
	if _r(1634) < 0.7:
		_mall_bench(Vector3(6.0, 0, 6.55) if along_x else Vector3(6.55, 0, 6.0), yaw + PI)
	if _r(1635) < 0.6:
		var bp := Vector3(3.6, 0, 6.95) if along_x else Vector3(6.95, 0, 3.6)
		if _waste_bin(bp, _r(1636) * TAU, "mall_bin") == null:
			# a mall bin: brick-red cylinder with a black swing lid
			var bin_b0 := body.get_child_count()
			var bin := _furnishing_pivot(bp, 0.0, "mall_bin")
			_mcyl(bin, Vector3(0, 0.42, 0), 0.30, 0.84, Mats.velvet_rust())
			_mcyl(bin, Vector3(0, 0.89, 0), 0.26, 0.10, Mats.charcoal())
			_collider_cyl(bp + Vector3(0, 0.45, 0), 0.32, 0.95)
			_bind_furnishing_colliders(bin, bin_b0)
	if _r(1630) < 0.72:
		var plant_pos := Vector3(2.1, 0, 4.4) if along_x else Vector3(4.4, 0, 2.1)
		_planter(plant_pos)
	if _r(1631) < 0.35:
		_cc0_prop("WetFloorSign_01",
			Vector3(9.4, 0, 5.0) if along_x else Vector3(5.0, 0, 9.4), yaw, 0.9)
	var sign_p := Vector3(6.0, minf(3.35, ceil_h - 0.5), 5.1) if along_x \
		else Vector3(5.1, minf(3.35, ceil_h - 0.5), 6.0)
	_mall_sign(sign_p, yaw, MALL_NAMES[WorldGen.h(wseed, cell.x, cell.y, 1632) % MALL_NAMES.size()])
	if _r(1636) < 0.58:
		var cart_p := Vector3(8.8, 0, 2.3) if along_x \
			else Vector3(2.3, 0, 8.8)
		_mall_shopping_cart(cart_p, yaw + (_r(1637) - 0.5) * 0.55,
			_r(1638) < 0.28)
	# A pair of payphones on a solid concourse wall. Atriums are barely 2% of
	# mall cells, so a bank placed only there was effectively never seen; the
	# gallery is where anyone actually walks past one.
	if _r(1639) < 0.42:
		for dir in 4:
			if _solid_wall(dir):
				_mall_payphone_bank(dir, 2)
				break


func _mall_display_table(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mrbox(v, Vector3(0, 0.76, 0), Vector3(2.2, 0.12, 0.9), Mats.sch_white(), 0.035)
	for x in [-0.87, 0.87]:
		_mbox(v, Vector3(x, 0.36, 0), Vector3(0.10, 0.72, 0.72), Mats.mall_trim())
	for i in 4:
		var x := -0.72 + float(i) * 0.48
		var col := Mats.sch_chair(WorldGen.r01(wseed, cell.x + i, cell.y, salt))
		_mrbox(v, Vector3(x, 0.88, 0), Vector3(0.30, 0.11, 0.48), col, 0.03)
	_collider_yaw_box(p + Vector3(0, 0.52, 0), Vector3(2.2, 1.04, 0.92), yaw)


func _solid_wall(dir: int) -> bool:
	return WorldGen.edge_info(wseed, cell, dir, theme)["wall"]


## Wall shelving for a raided retail unit: brackets, mostly-bare boards, the
## odd carton nobody wanted. Only on genuinely solid walls, so a run can
## never seal a doorway.
func _mall_shelves(dir: int, salt: int) -> void:
	if not _solid_wall(dir):
		return
	var v := Node3D.new()
	v.position = Vector3(6.0, 0, 6.0)
	v.rotation.y = _air_yaw_for(dir)
	add_child(v)
	# local +z faces the wall: boards hang at z 5.42, run 7m along x
	for ux in [-3.5, -1.75, 0.0, 1.75, 3.5]:
		_mbox(v, Vector3(ux, 1.1, 5.47), Vector3(0.05, 2.2, 0.05), Mats.mall_trim())
	for b in 4:
		var by := 0.42 + float(b) * 0.55
		_mbox(v, Vector3(0, by, 5.36), Vector3(7.1, 0.04, 0.34), Mats.sch_white())
	for b2 in 3:
		if WorldGen.hr01(WorldGen.h(wseed, cell.x, cell.y, salt + b2), 3) < 0.4:
			var bx := lerpf(-3.2, 3.2, WorldGen.hr01(WorldGen.h(wseed, cell.x, cell.y, salt + b2), 4))
			_mbox(v, Vector3(bx, 0.62 + float(b2) * 0.55, 5.36),
				Vector3(0.42, 0.30, 0.30), Mats.box_white())
	# A few recognisable pantry products among the anonymous cartons.
	for si in 2:
		if WorldGen.hr01(WorldGen.h(wseed, cell.x, cell.y, salt + 20 + si), 8) < 0.72:
			var sx := -2.1 + float(si) * 3.9
			_cc0_prop_local(v, "long_life_food",
				Vector3(sx, 0.99 + float(si) * 0.55, 5.15),
				PI + 0.08 * float(si), 0.9)
	_collider_yaw_box(_wp(Vector3(6, 0, 6), Vector3(0, 1.1, 5.42), _air_yaw_for(dir)),
		Vector3(7.1, 2.2, 0.45), _air_yaw_for(dir))


## A chrome garment rack, picked clean but for a few dark shapes.
func _mall_rack(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	for sx in [-0.7, 0.7]:
		_mcyl(v, Vector3(sx, 0.7, 0), 0.022, 1.4, Mats.chrome())
		_mbox(v, Vector3(sx, 0.02, 0), Vector3(0.5, 0.04, 0.5), Mats.chrome())
	_mcyl(v, Vector3(0, 1.38, 0), 0.018, 1.5, Mats.chrome()).rotation.z = PI / 2.0
	var ng := 1 + WorldGen.h(wseed, cell.x, cell.y, salt) % 3
	for g in ng:
		var gx := lerpf(-0.55, 0.55, WorldGen.hr01(WorldGen.h(wseed, cell.x, cell.y, salt + g), 5))
		_mbox(v, Vector3(gx, 0.98, 0), Vector3(0.34, 0.78, 0.06),
			Mats.fabric_charcoal())
	_collider_yaw_box(p + Vector3(0, 0.7, 0), Vector3(1.6, 1.4, 0.55), yaw)


## Checkout counter with a dead register.
func _mall_counter(p: Vector3, yaw: float) -> void:
	var b0 := body.get_child_count()
	var v := _furnishing_pivot(p, yaw, "mall_checkout_counter")
	v.set_meta("enrichment_prop", "CashRegister_01")
	_mrbox(v, Vector3(0, 0.5, 0), Vector3(2.2, 1.0, 0.75), Mats.mall_trim(), 0.05)
	_mrbox(v, Vector3(0, 1.02, 0), Vector3(2.35, 0.06, 0.9), Mats.sch_white(), 0.02)
	_cc0_prop_local(v, "CashRegister_01", Vector3(-0.58, 1.05, -0.02),
		PI, 0.78)
	# Receipt roll, card pad and a forgotten price gun.
	_mrbox(v, Vector3(0.28, 1.11, -0.10), Vector3(0.24, 0.09, 0.22),
		Mats.charcoal(), 0.02)
	_mbox(v, Vector3(0.69, 1.11, 0.05), Vector3(0.18, 0.12, 0.30),
		Mats.body_black())
	_collider_yaw_box(p + Vector3(0, 0.55, 0), Vector3(2.35, 1.1, 0.9), yaw)
	_bind_furnishing_colliders(v, b0)


func _mall_store() -> void:
	# a small unit stripped to the walls: shelving on every solid wall (up to
	# three), racks and a counter in the floor
	var runs := 0
	for d in 4:
		if runs >= 3:
			break
		if _solid_wall(d):
			_mall_shelves(d, 1644 + d)
			runs += 1
	_mall_display_table(Vector3(4.6, 0, 6.0), PI / 2.0, 1640)
	_mall_rack(Vector3(7.6, 0, 4.6), _r(1646) * 0.5, 1647)
	_mall_rack(Vector3(7.2, 0, 7.6), PI / 2.0 + _r(1648) * 0.5, 1649)
	_mall_counter(Vector3(3.4, 0, 9.6), PI)
	_mall_sign(Vector3(6.0, minf(3.15, ceil_h - 0.45), 1.0), PI,
		MALL_NAMES[WorldGen.h(wseed, cell.x, cell.y, 1641) % MALL_NAMES.size()])
	if _r(1642) < 0.55:
		_cc0_prop("potted_plant_02", Vector3(2.1, 0, 9.4), _r(1643) * TAU, 0.9)
	if _r(1651) < 0.4:
		_cc0_prop("wooden_crate_01", Vector3(9.6, 0, 9.3), _r(1652) * TAU, 0.85)
	_mall_shopping_cart(Vector3(9.1, 0, 2.3), PI / 2.0 + _r(1654) * 0.35,
		_r(1655) < 0.5)


## Long low double-sided gondola shelving, the spine of a dead department
## store floor.
func _mall_gondola(p: Vector3, yaw: float, ln: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mbox(v, Vector3(0, 0.07, 0), Vector3(ln, 0.14, 1.0), Mats.mall_trim())
	_mbox(v, Vector3(0, 0.75, 0), Vector3(ln, 1.36, 0.16), Mats.mall_trim())
	for side in [-1.0, 1.0]:
		for b in 3:
			_mbox(v, Vector3(0, 0.34 + float(b) * 0.44, side * 0.28),
				Vector3(ln, 0.035, 0.42), Mats.sch_white())
	var nb := WorldGen.h(wseed, cell.x, cell.y, salt) % 4
	for i in nb:
		var bx := lerpf(-ln * 0.4, ln * 0.4, WorldGen.hr01(WorldGen.h(wseed, cell.x, cell.y, salt + i), 6))
		var side2 := -1.0 if WorldGen.hr01(WorldGen.h(wseed, cell.x, cell.y, salt + i), 7) < 0.5 else 1.0
		_mbox(v, Vector3(bx, 0.52, side2 * 0.28), Vector3(0.4, 0.3, 0.3), Mats.box_white())
	for stock in 2:
		if WorldGen.hr01(WorldGen.h(wseed, cell.x, cell.y, salt + 30 + stock), 4) < 0.7:
			var sx := -ln * 0.24 + float(stock) * ln * 0.48
			var sz := -0.29 if stock == 0 else 0.29
			_cc0_prop_local(v, "long_life_food",
				Vector3(sx, 0.80 + float(stock) * 0.43, sz),
				0.0 if stock == 0 else PI, 0.78)
	_collider_yaw_box(p + Vector3(0, 0.72, 0), Vector3(ln, 1.44, 1.0), yaw)


func _mall_anchor() -> void:
	for p in [Vector3(3, 0, 3), Vector3(9, 0, 3), Vector3(3, 0, 9), Vector3(9, 0, 9)]:
		_cyl(p + Vector3(0, ceil_h * 0.5, 0), 0.26, ceil_h, Mats.mall_trim())
	# gondola rows down the sales floor, aisles between
	_mall_gondola(Vector3(6.0, 0, 4.3), 0, 5.2, 1660)
	_mall_gondola(Vector3(6.0, 0, 7.7), 0, 5.2, 1665)
	_mall_display_table(Vector3(6, 0, 1.9), 0, 1670)
	# checkout lane by one clear corner
	_mall_counter(Vector3(9.8, 0, 10.0), -PI / 2.0)
	_mall_sign(Vector3(6.0, minf(3.3, ceil_h - 0.4), 10.9), 0.0, "HOUSE & HOME")
	if _r(1661) < 0.7:
		_cc0_prop("sofa_03", Vector3(2.2, 0, 6.0), PI / 2.0, 0.85)
	if _r(1662) < 0.5:
		_mall_rack(Vector3(2.6, 0, 9.7), _r(1663) * TAU, 1664)
	# Keep the abandoned cart bank clear of the optional sofa grouping.
	_mall_shopping_cart(Vector3(9.8, 0, 2.0), PI - 0.18, true)
	if _r(1666) < 0.65:
		_mall_shopping_cart(Vector3(8.55, 0, 2.0), PI + 0.12, false)


func _mall_food_table(p: Vector3, salt: int) -> void:
	var b0 := body.get_child_count()
	var v := _furnishing_pivot(p, 0.0, "mall_food_table")
	# The authored set arrives as a pedestal table with its two chairs already
	# pulled up to it, so the generated top, column and ring of stools go with
	# it. Its chairs sit along local Z, hence the free yaw.
	var set_yaw := _r(salt + 3) * TAU
	# `v` already stands at `p`, so the set is placed at its origin. Passing
	# `p` again would put it at twice the distance from the chunk.
	var authored := _attributed_floor_prop(FOOD_COURT_SET_PATH, Vector3.ZERO,
		set_yaw, FOOD_COURT_SET_SCALE, FOOD_COURT_SET_CENTRE,
		"mall_food_table", v)
	if authored != null:
		# One box on the set's own footprint rather than a cylinder around it:
		# the pair is half again as long as it is wide, so a circle would put
		# an invisible bubble either side of the table.
		_collider_yaw_box(p + Vector3(0, 0.46, 0),
			Vector3(0.78, 0.92, 1.86), set_yaw)
	else:
		_mcyl(v, Vector3(0, 0.72, 0), 0.72, 0.08, Mats.sch_white())
		_mcyl(v, Vector3(0, 0.35, 0), 0.08, 0.7, Mats.mall_trim())
		_collider_cyl(p + Vector3(0, 0.45, 0), 0.74, 0.9)
		for i in 3:
			var a := TAU * float(i) / 3.0 + _r(salt) * 0.3
			var cp := p + Vector3(cos(a), 0, sin(a)) * 1.1
			var chair := _cc0_prop("bar_chair_round_01", cp, -a + PI / 2.0, 0.85)
			_adopt_local(v, chair)
			_collider_cyl(cp + Vector3(0, 0.42, 0), 0.30, 0.84)
	# Trays, wax cups and collapsed takeout cartons leave a human-scale trace.
	# Both tops land within a centimetre of 0.76m, so the clutter sits on
	# either version without moving.
	if _r(salt + 20) < 0.78:
		var tray_yaw := (_r(salt + 21) - 0.5) * 0.5
		var tray := _mrbox(v, Vector3(-0.12, 0.79, 0.10),
			Vector3(0.46, 0.035, 0.31), Mats.velvet_rust(), 0.018)
		tray.rotation.y = tray_yaw
		_mcyl(v, Vector3(0.09, 0.91, 0.03), 0.045, 0.22, Mats.box_white())
		_mrbox(v, Vector3(-0.16, 0.86, 0.12), Vector3(0.18, 0.10, 0.15),
			Mats.box_white(), 0.018)
	_bind_furnishing_colliders(v, b0)


func _mall_foodcourt() -> void:
	# six bolted tables in ranks, an aisle down the middle
	for i in 6:
		var p := Vector3(2.9 + 3.1 * float(i % 3), 0, 3.6 + 4.6 * float(i / 3))
		_mall_food_table(p, 1680 + i)
	# the serving line: counter run and dead menu boxes on the first solid wall
	for d in [3, 2, 1, 0]:
		if not _solid_wall(d):
			continue
		var yw := _air_yaw_for(d)
		var v := Node3D.new()
		v.position = Vector3(6.0, 0, 6.0)
		v.rotation.y = yw
		v.set_meta("mall_foodcourt_vendor", true)
		add_child(v)
		_mrbox(v, Vector3(0, 0.62, 4.65), Vector3(7.4, 1.24, 0.8), Mats.mall_trim(), 0.05)
		_mrbox(v, Vector3(0, 1.28, 4.65), Vector3(7.6, 0.08, 0.95), Mats.sch_white(), 0.02)
		# tray slide
		for tr in 3:
			_mcyl(v, Vector3(0, 0.98, 4.14 - float(tr) * 0.055), 0.016, 7.2,
				Mats.chrome()).rotation.z = PI / 2.0
		# One coherent abandoned vendor, not three unrelated restaurant names
		# pasted over whatever storefronts happened to generate behind it.
		# A continuous fascia is fixed to the wall by end brackets; the three
		# lower panels are menu boards belonging to that same business.
		_mrbox(v, Vector3(0, 2.72, 5.27),
			Vector3(7.05, 0.62, 0.16), Mats.mall_sign_face(), 0.035)
		for sx in [-3.42, 3.42]:
			_mbox(v, Vector3(sx, 2.16, 5.34),
				Vector3(0.12, 1.55, 0.34), Mats.mall_trim())
		var brand := Label3D.new()
		brand.text = MALL_FOOD[
			WorldGen.h(wseed, cell.x, cell.y, 1690) % MALL_FOOD.size()]
		brand.font_size = 78
		var brand_font := ThemeDB.fallback_font
		var brand_px := brand_font.get_string_size(brand.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, brand.font_size).x
		brand.pixel_size = minf(0.0027, 5.8 / maxf(brand_px + 24.0, 1.0))
		brand.width = ceili(brand_px + 28.0)
		brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		brand.autowrap_mode = TextServer.AUTOWRAP_OFF
		brand.modulate = Color(0.34, 0.29, 0.24)
		brand.position = Vector3(0, 2.72, 5.175)
		brand.rotation.y = PI
		brand.set_meta("mall_foodcourt_brand", true)
		v.add_child(brand)
		for si in 3:
			var sx := -2.35 + float(si) * 2.35
			_mrbox(v, Vector3(sx, 2.05, 5.25),
				Vector3(1.92, 0.72, 0.12), Mats.charcoal(), 0.025)
			for line_idx in 4:
				var line_w := lerpf(0.72, 1.45,
					WorldGen.hr01(WorldGen.h(wseed, cell.x + si,
						cell.y + line_idx, 1694), 2))
				_mbox(v, Vector3(sx - 0.18, 2.25 - float(line_idx) * 0.14,
					5.178), Vector3(line_w, 0.025, 0.012),
					Mats.mall_sign_face())
				_mbox(v, Vector3(sx + 0.68, 2.25 - float(line_idx) * 0.14,
					5.176), Vector3(0.16, 0.025, 0.012), Mats.brass())
		_cc0_prop_local(v, "CashRegister_01",
			Vector3(2.85, 1.32, 4.40), PI, 0.68)
		v.set_meta("enrichment_prop", "CashRegister_01")
		_collider_yaw_box(_wp(Vector3(6, 0, 6), Vector3(0, 0.65, 4.65), yw),
			Vector3(7.6, 1.3, 0.95), yw)
		break
	# A stranded cart out on the seating floor, wheeled away from the line it
	# was never part of. Its awning clears the 4m gallery ceiling comfortably.
	if _r(1696) < 0.55:
		var hp := Vector3(9.4, 0, 9.6)
		var hyaw := _r(1697) * TAU
		if _attributed_floor_prop(MALL_HOTDOG_PATH, hp, hyaw,
				MALL_HOTDOG_SCALE, MALL_HOTDOG_CENTRE, "hotdog_stand") != null:
			_collider_yaw_box(hp + Vector3(0, 0.55, 0),
				Vector3(1.95, 1.10, 0.85), hyaw)
	if _r(1688) < 0.65:
		_cc0_prop("CoffeeCart_01", Vector3(10.1, 0, 2.3), PI * 0.5, 1.0)
		_collider_yaw_box(Vector3(10.1, 0.65, 2.3), Vector3(1.8, 1.3, 0.85), PI * 0.5)
	# stacked chairs someone left in a corner
	if _r(1689) < 0.5:
		for st in 3:
			_cc0_prop("bar_chair_round_01", Vector3(1.5 + float(st) * 0.32, 0, 10.4),
				0.3 * float(st), 0.85)
	if _r(1694) < 0.55:
		_mall_shopping_cart(Vector3(10.3, 0, 6.0),
			PI + (_r(1695) - 0.5) * 0.45, false)


func _mall_atrium() -> void:
	# Spawn and portals own the centre. The dead fountain sits off-axis so the
	# first movement in this floor is always possible.
	var fc := Vector3(8.25, 0, 7.85)
	var fountain_b0 := body.get_child_count()
	var fountain := _furnishing_pivot(fc, 0.0, "mall_fountain")
	_mcyl(fountain, Vector3(0, 0.25, 0), 1.65, 0.50, Mats.marble_photo())
	_mcyl(fountain, Vector3(0, 0.49, 0), 1.38, 0.08, Mats.mall_glass())
	_mcyl(fountain, Vector3(0, 0.67, 0), 0.20, 0.36, Mats.brass())
	_collider_cyl(fc + Vector3(0, 0.28, 0), 1.65, 0.56)
	# pennies still in the bottom
	_mcyl(fountain, Vector3(0, 0.505, 0), 1.30, 0.01, Mats.puddle())
	_bind_furnishing_colliders(fountain, fountain_b0)
	_planter(Vector3(2.2, 0, 8.8))
	_mall_bench(Vector3(3.2, 0, 3.0), PI / 4.0)
	_mall_bench(Vector3(8.25, 0, 5.3), PI)
	_mall_directory_pylon(Vector3(3.6, 0, 6.4), _r(1710) * TAU)
	if _solid_wall(1):
		_mall_payphone_bank(1, 3)
	if ceil_h > 5.5:
		# False mezzanine: visible high above, deliberately not traversable.
		for side in [-1.0, 1.0]:
			_box(Vector3(6, 3.45, 6 + side * 5.25), Vector3(11, 0.18, 0.70),
				Mats.mall_trim(), false)
			for i in 9:
				_box(Vector3(1.6 + float(i) * 1.1, 3.9, 6 + side * 4.95),
					Vector3(0.045, 0.9, 0.045), Mats.brass(), false)
	if _r(1718) < 0.72:
		_mall_shopping_cart(Vector3(9.8, 0, 2.2),
			-PI / 2.0 + (_r(1719) - 0.5) * 0.35, _r(1720) < 0.3)


func _mall_service() -> void:
	_cc0_prop("steel_frame_shelves_01", Vector3(9.4, 0, 6.0), -PI / 2.0, 0.1)
	_collider_yaw_box(Vector3(9.4, 0.9, 6), Vector3(2.0, 1.8, 0.7), -PI / 2.0)
	for i in 4:
		var p := Vector3(2.2 + float(i % 2) * 1.1, 0, 7.5 + float(i / 2) * 1.0)
		_cc0_prop("wooden_crate_01" if i % 2 == 0 else "plastic_crate_03",
			p, _r(1690 + i) * TAU, 0.8)
	if _r(1698) < 0.4:
		_cc0_prop("trashbag", Vector3(8.8, 0, 2.0), _r(1699) * TAU)
	_cc0_floor_prop("hand_truck", Vector3(2.0, 0, 3.0),
		0.22, 0.92, "mall_service_hand_truck",
		Vector3(0.62, 1.32, 0.62), Vector3(0, 0.66, 0))
	_cc0_floor_prop("industrial_storage_cart", Vector3(6.1, 0, 9.7),
		PI, 0.72, "mall_service_storage_cart",
		Vector3(1.18, 1.0, 0.82), Vector3(0, 0.5, 0))
	if _r(1701) < 0.75:
		_cc0_floor_prop("metal_trash_can", Vector3(9.6, 0, 2.1),
			PI / 2.0, 0.68, "mall_service_refuse",
			Vector3(1.28, 0.64, 0.44), Vector3(-0.06, 0.32, 0))
	if _r(1702) < 0.65:
		_mall_shopping_cart(Vector3(3.6, 0, 9.4), PI - 0.24, true)


## One island kiosk: counter ring, canopy on poles, a small name sign.
func _mall_kiosk(p: Vector3, yaw: float, salt: int) -> void:
	var b0 := body.get_child_count()
	var v := _furnishing_pivot(p, yaw, "mall_kiosk")
	_mrbox(v, Vector3(0, 0.62, 0), Vector3(2.6, 1.24, 1.5), Mats.mall_trim(), 0.08)
	_mrbox(v, Vector3(0, 1.28, 0), Vector3(2.85, 0.12, 1.75), Mats.sch_white(), 0.035)
	for cx in [-1.25, 1.25]:
		for cz in [-0.72, 0.72]:
			_mcyl(v, Vector3(cx, 2.0, cz), 0.03, 1.5, Mats.brass())
	_mrbox(v, Vector3(0, 2.82, 0), Vector3(3.1, 0.28, 2.0), Mats.mall_trim(), 0.06)
	var nm: String = MALL_NAMES[WorldGen.h(wseed, cell.x, cell.y, salt) % MALL_NAMES.size()]
	for sside in [-1.0, 1.0]:
		var lab := Label3D.new()
		lab.text = nm
		lab.font_size = 56
		lab.pixel_size = 0.0022
		lab.modulate = Color(0.34, 0.30, 0.25)
		lab.position = Vector3(0, 2.82, sside * 1.02)
		lab.rotation.y = 0.0 if sside > 0.0 else PI
		v.add_child(lab)
	_cc0_prop_local(v, "CashRegister_01", Vector3(0.68, 1.34, -0.18),
		PI, 0.66)
	v.set_meta("enrichment_prop", "CashRegister_01")
	# A handful of boxed impulse items beneath the dead canopy.
	for pi in 4:
		var px := -0.82 + float(pi) * 0.42
		_mrbox(v, Vector3(px, 1.43, 0.34), Vector3(0.26, 0.22, 0.18),
			Mats.sch_chair(_r(salt + 10 + pi)), 0.025)
	_collider_yaw_box(p + Vector3(0, 0.72, 0), Vector3(2.9, 1.44, 1.8), yaw)
	_bind_furnishing_colliders(v, b0)


func _mall_kiosks() -> void:
	# abandoned islands strung down the concourse
	_mall_kiosk(Vector3(3.4, 0, 3.8), _r(1720) * 0.4, 1721)
	_mall_kiosk(Vector3(8.4, 0, 8.2), PI / 2.0 + _r(1722) * 0.4, 1723)
	if _r(1724) < 0.5:
		_mall_kiosk(Vector3(8.8, 0, 3.0), _r(1725) * TAU, 1726)
	_mall_bench(Vector3(2.8, 0, 8.6), PI / 2.0)
	if _r(1727) < 0.5:
		_planter(Vector3(5.9, 0, 10.2))


func _mall_cinema() -> void:
	var counter := Vector3(6, 0, 8.9)
	var counter_b0 := body.get_child_count()
	var cv := _furnishing_pivot(counter, 0.0, "mall_cinema_counter")
	_mrbox(cv, Vector3(0, 0.68, 0), Vector3(5.8, 1.36, 0.72),
		Mats.mall_trim(), 0.06)
	_mbox(cv, Vector3(0, 1.1, -0.39), Vector3(5.4, 0.34, 0.035),
		Mats.mall_glass())
	for rx in [-1.65, 1.65]:
		_cc0_prop_local(cv, "CashRegister_01", Vector3(rx, 1.39, -0.12),
			PI, 0.68)
	cv.set_meta("enrichment_prop", "CashRegister_01")
	_collider_yaw_box(counter + Vector3(0, 0.7, 0), Vector3(5.8, 1.4, 0.78), 0)
	_bind_furnishing_colliders(cv, counter_b0)
	# the marquee: navy brick surround, bulb rows, one bulb still blinking
	var marquee := _furnishing_pivot(Vector3.ZERO, 0.0, "mall_cinema_marquee", false)
	var surround := _box(Vector3(6, 2.9, 9.55), Vector3(7.0, 1.7, 0.25),
		Mats.mall_brick(), false)
	_adopt_local(marquee, surround)
	# Narrow pilasters bridge the concession counter to the heavy masonry
	# marquee. Without them the entire blue surround reads as a floating slab.
	for mx in [3.0, 9.0]:
		var pier := _box(Vector3(mx, 1.70, 9.55), Vector3(0.22, 0.72, 0.25),
			Mats.mall_trim(), false)
		_adopt_local(marquee, pier)
	var cinema_sign := _mall_sign(Vector3(6, 2.9, 9.38), PI,
		"CINEMAS  1-6", 0.16, false)
	_adopt_local(marquee, cinema_sign)
	for bi in 14:
		var bx := 2.9 + float(bi % 7) * 1.05
		var by := 2.28 if bi < 7 else 3.52
		var bulb := _sphere(Vector3(bx, by, 9.40), 0.045,
			Mats.bulb() if bi == 3 else Mats.chrome())
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_adopt_local(marquee, bulb)
	# red carpet approach between velvet queue ropes
	_box(Vector3(6, 0.015, 5.4), Vector3(2.2, 0.02, 6.4), Mats.carpet_red(), false)
	var queue_b0 := body.get_child_count()
	var queue := _furnishing_pivot(Vector3.ZERO, 0.0, "mall_cinema_queue")
	for i in 2:
		var rz := 3.2 + ROPE_BARRIER_PITCH * (float(i) + 0.5)
		for rx in [4.6, 7.4]:
			var barrier := _rope_barrier(Vector3(rx, 0, rz), PI / 2.0,
				"mall_cinema_rope")
			if barrier != null:
				_adopt_local(queue, barrier)
	_bind_furnishing_colliders(queue, queue_b0)
	for x in [2.4, 9.6]:
		_mall_poster_stand(Vector3(x, 0, 2.0))
	if _r(1734) < 0.72:
		_cc0_floor_prop("metal_trash_can", Vector3(10.0, 0, 8.1),
			PI / 2.0, 0.64, "mall_cinema_refuse",
			Vector3(1.20, 0.60, 0.42), Vector3(-0.06, 0.30, 0))


func _mall_poster_stand(p: Vector3) -> void:
	var b0 := body.get_child_count()
	var v := _furnishing_pivot(p, 0.0, "mall_poster_stand")
	_mrbox(v, Vector3(0, 1.2, 0), Vector3(1.2, 2.1, 0.15),
		Mats.mall_trim(), 0.04)
	_mbox(v, Vector3(0, 1.2, -0.09), Vector3(1.03, 1.9, 0.025),
		Mats.sch_chair(0.04 + _r(1704) * 0.48))
	_mrbox(v, Vector3(0, 0.05, 0), Vector3(1.38, 0.10, 0.52),
		Mats.mall_trim(), 0.025)
	_collider_yaw_box(p + Vector3(0, 1.1, 0), Vector3(1.2, 2.2, 0.22), 0)
	_bind_furnishing_colliders(v, b0)


# --- island prison -----------------------------------------------------------

func _prison_lighting() -> void:
	# The friend of the dark is the reader of nothing: this floor was crushed
	# to black. Fewer dead fixtures, twice the energy, and a second fill light
	# in the big set-piece rooms — still the coldest floor, but readable.
	var dead := cell != Vector2i.ZERO and _r(1800) < 0.08
	var flicker := not dead and cell != Vector2i.ZERO and _r(1801) < 0.16
	var lens: StandardMaterial3D = Mats.panel_dead() if dead else Mats.prison_panel()
	if flicker:
		lens = Mats.prison_panel().duplicate()
	var along_x := WorldGen.corridor(wseed, cell) != 2
	for t in [-3.6, 0.0, 3.6]:
		var p := Vector3(6 + t, 0, 6) if along_x else Vector3(6, 0, 6 + t)
		_troffer(p, Vector2(1.25, 0.20) if along_x else Vector2(0.20, 1.25),
			lens, Mats.prison_iron())
	if dead:
		return
	var big := style == WorldGen.PRISON_CELLBLOCK or style == WorldGen.PRISON_ROTUNDA
	var light := _make_main_light(flicker, lens, 2.1 if big else 1.8)
	light.light_color = Color(0.78, 0.87, 0.79)
	light.omni_range = 14.5
	light.position = Vector3(6, ceil_h - 0.55, 6)
	light.shadow_enabled = big
	light.distance_fade_enabled = true
	light.distance_fade_begin = 23.0
	light.distance_fade_length = 8.0
	add_child(light)
	if big and ceil_h > 5.0:
		# high fill washing the range so the tall volume does not eat the light
		var fill := OmniLight3D.new()
		fill.light_color = Color(0.72, 0.80, 0.74)
		fill.light_energy = 0.8
		fill.omni_range = 11.0
		fill.position = Vector3(6, ceil_h * 0.55, 6)
		fill.shadow_enabled = false
		fill.distance_fade_enabled = true
		fill.distance_fade_begin = 20.0
		fill.distance_fade_length = 8.0
		add_child(fill)


func _prison_number_wall(dir: int, plane: float) -> void:
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var inner := plane + n * (T * 0.5 + 0.025)
	var along := lerpf(3.0, 9.0, _r(1810 + dir))
	var lab := Label3D.new()
	lab.text = "%s-%02d" % [char(65 + posmod(cell.x + cell.y, 6)),
		WorldGen.h(wseed, cell.x, cell.y, 1812 + dir) % 40 + 1]
	lab.font_size = 96
	lab.pixel_size = 0.0025
	lab.modulate = Color(0.20, 0.24, 0.20)
	lab.position = Vector3(inner, 1.75, along) if dir < 2 else Vector3(along, 1.75, inner)
	if dir == 0: lab.rotation.y = -PI / 2.0
	elif dir == 1: lab.rotation.y = PI / 2.0
	elif dir == 2: lab.rotation.y = PI
	add_child(lab)


## A sealed, non-interactive steel door on a genuinely solid prison wall. The
## source GLB contains two complete door arrangements several metres apart;
## retain only its coherent near-origin assembly so no duplicate geometry can
## materialise elsewhere in the room. The structural wall remains the collider,
## making the façade unmistakably locked without adding an invisible barrier.
func _prison_locked_door_wall(dir: int, plane: float) -> void:
	var n := -1.0 if dir == 0 or dir == 2 else 1.0
	var inner := plane + n * (T * 0.5)
	var along := lerpf(3.1, 8.9, _r(1816 + dir))
	var yaw := PI if dir == 0 else (0.0 if dir == 1 \
		else (PI / 2.0 if dir == 2 else -PI / 2.0))
	var pos := Vector3(inner + n * 0.035, 0, along) if dir < 2 \
		else Vector3(along, 0, inner + n * 0.035)
	var inst := _attributed_prop_local(self, PRISON_DOOR_OLD_PATH, pos, yaw,
		Vector3.ONE * (2.16 / 2.78388))
	if inst == null:
		return
	var distant_variant := inst.find_child("Null_1", true, false)
	if distant_variant != null:
		var variant_parent := distant_variant.get_parent()
		variant_parent.remove_child(distant_variant)
		distant_variant.free()
	inst.set_meta("wall_mounted_prison_door", true)
	inst.set_meta("locked_facade", true)


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


func _prison_bars(origin: Vector3, yaw: float, width: float, height: float,
		with_gate := true, solid := true) -> void:
	var v := Node3D.new()
	v.position = origin
	v.rotation.y = yaw
	add_child(v)
	var gate_half := 0.55 if with_gate else 0.0
	for i in range(int(width / 0.25) + 1):
		var x := -width * 0.5 + float(i) * 0.25
		if with_gate and absf(x) < gate_half:
			continue
		_mcyl(v, Vector3(x, height * 0.5, 0), 0.025, height, Mats.prison_iron())
	for y in [0.18, height - 0.18]:
		_mbox(v, Vector3(0, y, 0), Vector3(width, 0.08, 0.08), Mats.prison_iron())
	if with_gate:
		for x in [-gate_half, gate_half]:
			_mbox(v, Vector3(x, height * 0.5, 0), Vector3(0.08, height, 0.08),
				Mats.prison_iron())
		_mbox(v, Vector3(0, height - 0.18, 0), Vector3(gate_half * 2.0, 0.08, 0.08),
			Mats.prison_iron())
	if solid:
		if with_gate:
			var side_w := width * 0.5 - gate_half
			for side in [-1.0, 1.0]:
				var local_x := float(side) * (gate_half + side_w * 0.5)
				var cp := origin + Vector3(cos(yaw), 0, -sin(yaw)) * local_x
				_collider_yaw_box(cp + Vector3(0, height * 0.5, 0),
					Vector3(side_w, height, 0.12), yaw)
		else:
			_collider_yaw_box(origin + Vector3(0, height * 0.5, 0),
				Vector3(width, height, 0.12), yaw)


func _prison_bunk(p: Vector3, yaw: float, cell_context := false) -> void:
	var b0 := body.get_child_count()
	var v := _furnishing_pivot(p, yaw, "prison_bunk")
	v.set_meta("enrichment_prop", "double_bunk")
	v.set_meta("prison_cell_context", cell_context)
	# The source bed's long axis is X and its modelling origin sits 0.29716m
	# below the lowest foot. Turn that axis into the cell's local Z and lift the
	# complete authored frame onto the floor. This replaces every procedural
	# rail, mattress, pillow and ladder with one internally coherent model.
	var model_scale := 0.96
	var authored := _attributed_prop_local(v, PRISON_BUNK_PATH,
		Vector3(0, 0.29716 * model_scale, 0), PI / 2.0,
		Vector3.ONE * model_scale)
	if authored == null:
		# Import failure is intentionally obvious but still structurally safe:
		# retain a compact welded silhouette rather than leaving floating cell
		# effects where the bunk should have supported the composition.
		for x in [-0.48, 0.48]:
			for z in [-0.96, 0.96]:
				_mcyl(v, Vector3(x, 0.76, z), 0.035, 1.52,
					Mats.prison_iron())
		for level in [0.34, 1.18]:
			_mrbox(v, Vector3(0, level, 0),
				Vector3(0.96, 0.12, 1.92), Mats.asy_cloth(), 0.025)
	else:
		authored.set_meta("prison_cell_model", "bunk_bed")
	_collider_yaw_box(_wp(p, Vector3(0, 0.73, 0), yaw),
		Vector3(1.10, 1.46, 2.08), yaw)
	_bind_furnishing_colliders(v, b0)


func _prison_toilet(p: Vector3, yaw: float, cell_context := false) -> void:
	var b0 := body.get_child_count()
	var v := _furnishing_pivot(p, yaw, "prison_toilet_combo")
	v.set_meta("enrichment_prop", "detention_toilet_sink")
	v.set_meta("prison_cell_context", cell_context)
	# The authored bowl is floor-aligned and faces local +Z; turn it toward the
	# cell interior (-Z) and keep its baked grime, seat, tank and plumbing
	# together. The small steel basin behind it is generated as a separate,
	# wall-supported detention fixture, never as part of the bowl itself.
	var authored := _attributed_prop_local(v, PRISON_TOILET_PATH,
		Vector3.ZERO, PI, Vector3.ONE * 0.96)
	if authored != null:
		authored.set_meta("prison_cell_model", "toilet")
	else:
		_mrbox(v, Vector3(0, 0.30, -0.25), Vector3(0.48, 0.60, 0.58),
			Mats.steel(), 0.10)
	# Compact vandal-resistant wall basin and backsplash.
	_mrbox(v, Vector3(0, 0.96, 0.18), Vector3(0.54, 0.54, 0.13),
		Mats.steel(), 0.035)
	_mellipsoid(v, Vector3(0, 0.91, 0.02), Vector3(0.27, 0.09, 0.20),
		Mats.steel())
	var basin := _mcyl(v, Vector3(0, 0.965, -0.005), 0.16, 0.014,
		Mats.charcoal())
	basin.scale.z *= 0.70
	for bx in [-0.12, 0.12]:
		var button := _mcyl(v, Vector3(bx, 1.12, 0.105), 0.030, 0.025,
			Mats.prison_green())
		button.rotation.x = PI / 2.0
	_mbox(v, Vector3(0, 1.12, 0.01), Vector3(0.05, 0.13, 0.05),
		Mats.chrome())
	_mbox(v, Vector3(0, 1.065, -0.035), Vector3(0.05, 0.05, 0.11),
		Mats.chrome())
	_mrbox(v, Vector3(-0.39, 0.72, 0.18), Vector3(0.18, 0.20, 0.12),
		Mats.prison_iron(), 0.018)
	_collider_yaw_box(_wp(p, Vector3(0, 0.60, -0.10), yaw),
		Vector3(0.62, 1.20, 0.96), yaw)
	_bind_furnishing_colliders(v, b0)


## Cell-only context audit. Bunks and detention toilet/sink units are allowed
## only inside actual barred cell strips, never as generic room enrichment.
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


func _prison_corridor() -> void:
	var along_x := WorldGen.corridor(wseed, cell) != 2
	var yaw := 0.0 if along_x else PI / 2.0
	# shakedown table mid-gallery: the slab was floating with no legs and no
	# collider — a proper fixed steel table now
	var table_b0 := body.get_child_count()
	var table := _furnishing_pivot(Vector3(6, 0, 6), 0.0, "prison_shakedown_table")
	_mbox(table, Vector3(0, 1.02, 0), Vector3(1.1, 0.08, 1.1), Mats.prison_iron())
	for lx in [-0.42, 0.42]:
		for lz in [-0.42, 0.42]:
			_mbox(table, Vector3(lx, 0.49, lz), Vector3(0.09, 0.98, 0.09),
				Mats.prison_iron())
	_collider_box(Vector3(6, 0.55, 6), Vector3(1.1, 1.1, 1.1))
	_bind_furnishing_colliders(table, table_b0)
	if _r(1830) < 0.45:
		_security_camera(Vector3(6, minf(2.85, ceil_h - 0.28), 6),
			_r(1831) * TAU)
	if _r(1832) < 0.42:
		var refuse_pos := Vector3(2.0, 0, 2.1) if along_x \
			else Vector3(9.9, 0, 2.0)
		_cc0_floor_prop("metal_trash_can", refuse_pos, yaw, 0.72,
			"prison_refuse_can", Vector3(1.36, 0.68, 0.46),
			Vector3(-0.08, 0.34, 0))


## Yaw for a prop standing against wall `dir` and facing the room.
func _wall_facing(dir: int) -> float:
	match dir:
		0: return -PI / 2.0
		1: return PI / 2.0
		2: return PI
	return 0.0


## World point on the room side of wall `dir`: `along` down the wall, `off`
## in from the inner face.
func _wall_pt(dir: int, along: float, off: float, y := 0.0) -> Vector3:
	match dir:
		0: return Vector3(S - T - off, y, along)
		1: return Vector3(T + off, y, along)
		2: return Vector3(along, y, S - T - off)
	return Vector3(along, y, T + off)


## A strip of real cells along one wall: masonry fins split it into 2.4m
## bays, each fronted floor-to-header with square bars and a slid-open or
## shut gate — bunk, toilet and shelf inside, number plate over the door.
## Bays never cross a doorway lane, so a strip can never seal a room.
func _prison_cell_strip(dir: int, salt: int) -> void:
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var info := WorldGen.edge_info(wseed, cell, dir, theme)
	var clear_a := 99.0
	var clear_b := -99.0
	if not info["wall"]:
		if info["full_open"]:
			return
		clear_a = float(info["t"]) - float(info["w"]) / 2.0 - 0.7
		clear_b = float(info["t"]) + float(info["w"]) / 2.0 + 0.7
	var bh := 2.55
	var deep := 2.6
	var byaw := 0.0 if dir >= 2 else PI / 2.0   # bunk long axis into the cell
	# masonry fins at every bay boundary that stays clear of the door lane
	for fi in 5:
		var fx := 1.2 + float(fi) * 2.4
		if fx > clear_a and fx < clear_b:
			continue
		_sfb(dir, plane, deep / 2.0, fx, bh / 2.0, 0.14, bh, deep,
			Mats.prison_wall(), true)
	for bay in 4:
		var bc := 2.4 + float(bay) * 2.4
		if bc + 1.2 > clear_a and bc - 1.2 < clear_b:
			continue
		var giv := WorldGen.h(wseed, cell.x, cell.y, salt + bay)
		var open_gate := WorldGen.hr01(giv, 1) < 0.6
		# header beam, and masonry carrying on above it
		_sfb(dir, plane, deep, bc, bh + 0.11, 2.4, 0.22, 0.16, Mats.prison_iron())
		if ceil_h > bh + 0.45:
			_sfb(dir, plane, deep, bc, (bh + 0.22 + ceil_h) / 2.0, 2.4,
				ceil_h - bh - 0.22, 0.12, Mats.prison_wall())
		# the bar front: gate bay on the fin side the hash picks
		var gside := -1.0 if WorldGen.hr01(giv, 2) < 0.5 else 1.0
		var gc := bc + gside * 0.62
		var b0 := bc - 1.08
		var nb := 10
		for bi in nb:
			var bx := b0 + (2.16 / float(nb - 1)) * float(bi)
			if open_gate and absf(bx - gc) < 0.40:
				continue
			_sfb(dir, plane, deep, bx, bh / 2.0, 0.045, bh, 0.045, Mats.prison_iron())
		if open_gate:
			# the gate itself, slid aside and left there for thirty years
			for gi in 4:
				_sfb(dir, plane, deep + 0.09, bc - gside * (0.35 + float(gi) * 0.11),
					bh / 2.0, 0.045, bh - 0.1, 0.045, Mats.prison_green())
		else:
			for gi2 in 3:
				_sfb(dir, plane, deep + 0.09, gc - 0.26 + float(gi2) * 0.26,
					bh / 2.0, 0.05, bh - 0.1, 0.05, Mats.prison_green())
		# what a man's whole world was: bunk, toilet, shelf
		_prison_bunk(_wall_pt(dir, bc - 0.58, 1.30), byaw, true)
		_prison_toilet(_wall_pt(dir, bc + 0.74, 0.62),
			_air_yaw_for(dir), true)
		var effects := _furnishing_pivot(Vector3.ZERO, 0.0,
			"prison_cell_personal_effects", false)
		effects.set_meta("enrichment_prop", "cell_personal_effects")
		var shelf := _sfb(dir, plane, 0.16, bc + 0.7, 1.5,
			0.9, 0.05, 0.28, Mats.prison_green())
		_adopt_local(effects, shelf)
		# One or two recognizable remnants per cell: a battered book set or a
		# rusted food tin. They are grouped with the shelf, so neither can ever
		# survive as unsupported floating clutter.
		var effect_pos := _wall_pt(dir, bc + 0.7, 0.16, 1.535)
		if WorldGen.hr01(giv, 8) < 0.58:
			var books := _cc0_prop("book_encyclopedia_set_01", effect_pos,
				_air_yaw_for(dir), 0.72)
			_adopt_local(effects, books)
		if WorldGen.hr01(giv, 9) < 0.48:
			var tin_offset := Vector3(0.25, 0, 0).rotated(
				Vector3.UP, _air_yaw_for(dir))
			var tin := _cc0_prop("can_rusted", effect_pos + tin_offset,
				_air_yaw_for(dir) + 0.25, 0.86)
			_adopt_local(effects, tin)
		# number plate over the door
		var lab := Label3D.new()
		lab.text = "%s %02d" % [char(65 + posmod(cell.x + cell.y, 4)),
			(WorldGen.h(wseed, cell.x, cell.y, salt + 20 + bay) % 48) + 1]
		lab.font_size = 60
		lab.pixel_size = 0.0022
		lab.modulate = Color(0.72, 0.74, 0.68)
		lab.position = _wall_pt(dir, bc, deep + 0.11, bh + 0.11)
		lab.rotation.y = (-PI / 2.0 if dir == 0 else PI / 2.0) if dir < 2 \
			else (PI if dir == 2 else 0.0)
		add_child(lab)
		# collider along the bar line, split at an open gate
		var n := -1.0 if dir == 0 or dir == 2 else 1.0
		var bp := plane + n * (T * 0.5 + deep)
		if open_gate:
			for seg in [[bc - 1.2, gc - 0.40], [gc + 0.40, bc + 1.2]]:
				var sc: float = (seg[0] + seg[1]) / 2.0
				var sw: float = seg[1] - seg[0]
				if sw < 0.1:
					continue
				if dir < 2:
					_collider_box(Vector3(bp, bh / 2.0, sc), Vector3(0.12, bh, sw))
				else:
					_collider_box(Vector3(sc, bh / 2.0, bp), Vector3(sw, bh, 0.12))
		else:
			if dir < 2:
				_collider_box(Vector3(bp, bh / 2.0, bc), Vector3(0.12, bh, 2.4))
			else:
				_collider_box(Vector3(bc, bh / 2.0, bp), Vector3(2.4, bh, 0.12))


func _prison_cellblock() -> void:
	# strips down both long walls; the whole block agrees on the axis
	var ax := WorldGen.r01(wseed, room_root.x, room_root.y, 1840) < 0.5
	# NOTE: a ternary of two array literals loses the Array[int] type at
	# runtime — assign the literals directly
	var dirs: Array[int] = [2, 3]
	if not ax:
		dirs = [0, 1]
	for d in dirs:
		_prison_cell_strip(d, 1842 + d * 30)
	# painted circulation lanes down the central range
	var lane_r := 2.55
	for side in [-1.0, 1.0]:
		var lp := Vector3(6.0 + (0.0 if ax else side * lane_r), 0.012,
			6.0 + (side * lane_r if ax else 0.0))
		var ls := Vector3(S - 1.0, 0.015, 0.07) if ax else Vector3(0.07, 0.015, S - 1.0)
		_box(lp, ls, Mats.caution_yellow(), false)
	# catwalk over each strip when the block is tall — the Alcatraz register
	if ceil_h > 5.4:
		for d2 in dirs:
			var plane := (S - T / 2.0) if (d2 == 0 or d2 == 2) else (T / 2.0)
			var deck := _sfb(d2, plane, 1.25, 6.0, 3.26, S - 1.6, 0.14, 2.5, Mats.prison_iron())
			deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for i in 11:
				var rx := 1.3 + float(i) * 0.94
				var rp := _sfb(d2, plane, 2.42, rx, 3.82, 0.045, 1.0, 0.045, Mats.prison_iron())
				rp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var tr := _sfb(d2, plane, 2.42, 6.0, 4.3, S - 1.6, 0.06, 0.06, Mats.prison_iron())
			tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _prison_cells() -> void:
	# a small room of close cells: one strip along the first solid wall
	for d in 4:
		if _solid_wall(d):
			_prison_cell_strip(d, 1870 + d * 25)
			break
	# Bolted writing shelf with two real supports. The previous single leg made
	# the slab read as a floating or half-deleted table from most approaches.
	var desk_b0 := body.get_child_count()
	var desk := _furnishing_pivot(Vector3(8.8, 0, 6.4), 0.0, "prison_writing_table")
	_mrbox(desk, Vector3(0, 0.72, 0), Vector3(1.35, 0.08, 0.62),
		Mats.prison_green(), 0.02)
	for lx in [-0.55, 0.55]:
		_mbox(desk, Vector3(lx, 0.36, 0), Vector3(0.07, 0.72, 0.55),
			Mats.prison_iron())
	_mbox(desk, Vector3(0, 0.20, 0), Vector3(1.12, 0.06, 0.08),
		Mats.prison_iron())
	_collider_yaw_box(Vector3(8.8, 0.42, 6.4), Vector3(1.35, 0.84, 0.64), 0)
	_bind_furnishing_colliders(desk, desk_b0)
	if _r(1877) < 0.5:
		_cc0_prop("wooden_crate_02", Vector3(2.3, 0, 2.4), _r(1878) * TAU, 0.8)


func _prison_mess_table(p: Vector3, yaw: float) -> void:
	var b0 := body.get_child_count()
	var v := _furnishing_pivot(p, yaw, "prison_mess_table")
	_mrbox(v, Vector3(0, 0.78, 0), Vector3(3.5, 0.10, 0.82), Mats.prison_green(), 0.025)
	for z in [-0.88, 0.88]:
		_mbox(v, Vector3(0, 0.48, z), Vector3(3.2, 0.09, 0.35), Mats.prison_green())
		for x in [-1.35, 1.35]:
			_mbox(v, Vector3(x, 0.27, z), Vector3(0.08, 0.54, 0.08), Mats.prison_iron())
	# A few abandoned stainless trays, cups and one dented food tin stop the
	# room reading as four pristine geometry blocks.
	for ti in 2:
		var tx := -0.82 + float(ti) * 1.55
		var tz := -0.14 if ti == 0 else 0.16
		_mrbox(v, Vector3(tx, 0.86, tz), Vector3(0.48, 0.035, 0.30),
			Mats.steel(), 0.02)
		_mcyl(v, Vector3(tx + 0.16, 0.96, tz - 0.05), 0.045, 0.18,
			Mats.prison_iron())
	if _r(1880 + int(p.x + p.z)) < 0.48:
		_cc0_prop_local(v, "can_rusted", Vector3(0.28, 0.84, 0.0),
			_r(1881 + int(p.x)) * TAU, 0.85)
	_collider_yaw_box(p + Vector3(0, 0.5, 0), Vector3(3.5, 1.0, 2.0), yaw)
	_bind_furnishing_colliders(v, b0)


func _prison_mess() -> void:
	# ranks of fixed tables under the lamps, and the serving line that fed
	# eight hundred men in twenty minutes
	_prison_mess_table(Vector3(3.4, 0, 3.6), PI / 2.0)
	_prison_mess_table(Vector3(3.4, 0, 8.4), PI / 2.0)
	_prison_mess_table(Vector3(8.6, 0, 3.6), PI / 2.0)
	_prison_mess_table(Vector3(8.6, 0, 8.4), PI / 2.0)
	var service_dir := -1
	for d in 4:
		if not _solid_wall(d):
			continue
		service_dir = d
		var plane := (S - T / 2.0) if (d == 0 or d == 2) else (T / 2.0)
		var service_b0 := body.get_child_count()
		var service := _furnishing_pivot(Vector3.ZERO, 0.0, "prison_serving_line")
		var base := _sfb(d, plane, 0.55, 6.0, 0.62, 6.8, 1.24, 0.9,
			Mats.prison_green(), true)
		_adopt_local(service, base)
		var top := _sfb(d, plane, 0.55, 6.0, 1.28, 7.0, 0.07, 1.05, Mats.steel())
		_adopt_local(service, top)
		# tray rail
		var rail := _sfb(d, plane, 1.12, 6.0, 0.98, 6.8, 0.035, 0.035, Mats.chrome())
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_adopt_local(service, rail)
		# pass-through shelf and the cold well behind
		var well_a := _sfb(d, plane, 0.30, 4.2, 1.05, 2.2, 0.24, 0.35, Mats.steel())
		var well_b := _sfb(d, plane, 0.30, 7.6, 1.05, 2.2, 0.24, 0.35, Mats.steel())
		_adopt_local(service, well_a)
		_adopt_local(service, well_b)
		_bind_furnishing_colliders(service, service_b0)
		break
	# Put the clock on the same real wall as the serving line. The old fixed
	# north-wall transform left it suspended in space whenever another wall
	# was selected.
	if service_dir >= 0:
		var clock_plane := (S - T / 2.0) if (service_dir == 0 or service_dir == 2) \
			else (T / 2.0)
		_office_clock(service_dir, clock_plane)
	if _r(1883) < 0.75:
		_cc0_floor_prop("industrial_storage_cart", Vector3(10.5, 0, 6.0),
			-PI / 2.0, 0.72, "prison_mess_service_cart",
			Vector3(1.18, 1.0, 0.82), Vector3(0, 0.5, 0))


func _prison_shower_station(wall: int, along: float) -> void:
	var mount := _wall_pt(wall, along, 0.02)
	var v := _furnishing_pivot(mount, _air_yaw_for(wall),
		"prison_shower_fixture", false)
	v.set_meta("enrichment_prop", "detention_shower_head")
	# Exposed riser, wall flange and vandal-resistant cross valve.
	var pipe_bottom := 1.24
	var pipe_top := ceil_h - 0.42
	_mbox(v, Vector3(0, (pipe_bottom + pipe_top) * 0.5, 0),
		Vector3(0.045, pipe_top - pipe_bottom, 0.045), Mats.pipe_rust())
	var flange := MeshInstance3D.new()
	flange.mesh = TOR
	flange.material_override = Mats.prison_iron()
	flange.position = Vector3(0, 1.25, -0.035)
	flange.rotation.x = PI / 2.0
	flange.scale = Vector3(0.09, 0.035, 0.09)
	v.add_child(flange)
	_mbox(v, Vector3(0, 1.25, -0.07), Vector3(0.30, 0.035, 0.035),
		Mats.prison_green())
	_mbox(v, Vector3(0, 1.25, -0.07), Vector3(0.035, 0.30, 0.035),
		Mats.prison_green())
	_mcyl(v, Vector3(0, 1.25, -0.11), 0.035, 0.04, Mats.chrome()).rotation.x = PI / 2.0
	# Bent arm and a thick shower rose aimed down into the room.
	var arm_y := ceil_h - 1.02
	_mbeam(v, Vector3(0, arm_y, 0), Vector3(0, arm_y, -0.52),
		0.038, Mats.pipe_rust())
	_mbeam(v, Vector3(0, arm_y, -0.52), Vector3(0, arm_y - 0.13, -0.66),
		0.038, Mats.pipe_rust())
	var rose := _mcyl(v, Vector3(0, arm_y - 0.18, -0.70), 0.17, 0.09,
		Mats.prison_iron())
	rose.rotation.x = 0.60
	var face := _mcyl(v, Vector3(0, arm_y - 0.215, -0.725), 0.135, 0.012,
		Mats.charcoal())
	face.rotation.x = 0.60
	# Soap dish and drain-cleaning hose hook at waist height.
	_mrbox(v, Vector3(0.28, 0.92, -0.10), Vector3(0.34, 0.045, 0.24),
		Mats.prison_iron(), 0.018)
	_mbox(v, Vector3(0.28, 1.02, 0), Vector3(0.04, 0.22, 0.04),
		Mats.prison_iron())


func _prison_shower() -> void:
	# Tiled block: pick a genuinely solid edge first. The former hard-coded
	# north wall could be an internal opening in a merged shower room, leaving
	# a row of shower heads and valves hanging across open space.
	var wall := -1
	for d in 4:
		if _solid_wall(d):
			wall = d
			break
	if wall < 0:
		return
	var plane := (S - T / 2.0) if (wall == 0 or wall == 2) else (T / 2.0)
	# Five detailed institutional shower stations on the selected solid wall.
	for i in 5:
		var along := 2.0 + float(i) * 2.0
		_prison_shower_station(wall, along)
	# drain channel along the shower lane
	_sfb(wall, plane, 1.85, 6.0, 0.006, 9.6, 0.012, 0.22, Mats.charcoal())
	_sfb(wall, plane, 3.25, 6.0, 0.02, 10.0, 0.04, 0.10, Mats.prison_tile())
	# slat benches by the entrance
	var bench_b0 := body.get_child_count()
	var bench_pos := _wall_pt(wall, 6.0, 9.75)
	var bench := _furnishing_pivot(bench_pos, _air_yaw_for(wall),
		"prison_shower_bench")
	_mbox(bench, Vector3(0, 0.72, 0), Vector3(5.8, 0.10, 0.45), Mats.prison_green())
	for bx in [-2.7, 0.0, 2.7]:
		_mbox(bench, Vector3(bx, 0.36, 0), Vector3(0.08, 0.72, 0.38),
			Mats.prison_iron())
	_collider_yaw_box(bench_pos + Vector3(0, 0.42, 0),
		Vector3(5.8, 0.84, 0.48), _air_yaw_for(wall))
	_bind_furnishing_colliders(bench, bench_b0)
	if _r(1885) < 0.5:
		_cc0_prop("WetFloorSign_01", Vector3(4.4, 0, 6.6), _r(1886) * TAU, 0.9)
	# A coherent sanitation cluster: the downloaded props are small enough not
	# to need collision, but share one floor-supported pivot so they cannot
	# survive without their placement context.
	var sanitation_pos := _wall_pt(wall, 9.15, 1.05)
	var sanitation := _furnishing_pivot(sanitation_pos,
		_air_yaw_for(wall), "prison_sanitation_clutter")
	sanitation.set_meta("enrichment_prop", "sanitation_clutter")
	_cc0_prop_local(sanitation, "plunger", Vector3(0, 0, 0), -0.18, 1.0)
	_cc0_prop_local(sanitation, "drain_cleaner", Vector3(0.23, 0, 0.10), 0.25, 1.0)
	_cc0_prop_local(sanitation, "can_rusted", Vector3(-0.22, 0, 0.08), -0.2, 0.9)


## A guard station should look like prison furniture, not two bright office
## panels seen edge-on. The real battered steel desk, CRT, keyboard, papers,
## and chair are one atomic workstation with matching collision.
func _prison_guard_desk(p: Vector3, yaw: float) -> void:
	var b0 := body.get_child_count()
	var station := _furnishing_pivot(p, yaw, "prison_guard_desk")
	station.set_meta("office_workstation", true)
	var desk := _asy_model("metal_office_desk", p, yaw)
	_adopt_local(station, desk)
	_collider_yaw_box(p + Vector3(0, 0.42, 0), Vector3(2.05, 0.84, 1.0), yaw)
	var terminal := _vt100(p, yaw)
	_adopt_local(station, terminal)
	var forward := Vector3(sin(yaw), 0, cos(yaw))
	var keyboard := _vt100_keyboard(p + forward * 0.34, yaw)
	_adopt_local(station, keyboard)
	var side := Vector3(cos(yaw), 0, -sin(yaw)) * 0.62
	var papers := _cc0_prop("office_notepads",
		p + side + Vector3(0, 0.80, 0), yaw + 0.08, 0.45)
	_adopt_local(station, papers)
	# The desk phone the block was run from. The booths down the corridor keep
	# their own wall-mounted handsets; this is the station's outside line.
	var phone := _attributed_floor_prop(DESK_PHONE_PATH,
		p - side * 0.72 + Vector3(0, 0.795, 0), yaw + PI + 0.22,
		DESK_PHONE_SCALE, Vector3.ZERO, "desk_phone", station)
	if phone != null:
		_set_model_material(phone, Mats.prison_handset())
	var chair := _office_task_chair(p + forward * 1.02, yaw + PI)
	_adopt_local(station, chair)
	_bind_furnishing_colliders(station, b0)


func _prison_guard() -> void:
	var c := Vector3(8.2, 0, 7.0) if portal_dest < 0 else Vector3(9.2, 0, 9.2)
	_prison_bars(c + Vector3(0, 0, -1.65), 0, 4.1, 2.75, true)
	_prison_bars(c + Vector3(-2.05, 0, 0), PI / 2.0, 3.3, 2.75, false)
	_prison_guard_desk(c, PI)
	# Cameras use their actual wall plate. The previous room-centre placement
	# left this visibly hovering above the desk.
	for d in 4:
		if _solid_wall(d):
			var plane := (S - T / 2.0) if (d == 0 or d == 2) else (T / 2.0)
			_security_camera_wall(d, plane)
			break
	# A floor-standing key cabinet and a stack of monitors showing empty ranges.
	# The original was a shallow box more than a metre above any support.
	var key_b0 := body.get_child_count()
	var key_pos := c + Vector3(1.35, 0, 0.9)
	var keys := _furnishing_pivot(key_pos, 0.0, "prison_key_cabinet")
	_mrbox(keys, Vector3(0, 0.95, 0), Vector3(0.72, 1.90, 0.42),
		Mats.prison_green(), 0.025)
	_mbox(keys, Vector3(0, 1.18, -0.22), Vector3(0.54, 0.84, 0.025),
		Mats.charcoal())
	for ky in 3:
		for kx in 3:
			_mbox(keys, Vector3(-0.17 + float(kx) * 0.17,
				0.92 + float(ky) * 0.22, -0.245), Vector3(0.025, 0.05, 0.015),
				Mats.brass())
	_collider_yaw_box(key_pos + Vector3(0, 0.95, 0), Vector3(0.74, 1.9, 0.44), 0)
	_bind_furnishing_colliders(keys, key_b0)
	var monitor_b0 := body.get_child_count()
	var mv := _furnishing_pivot(c + Vector3(0.9, 0, -0.9),
		PI * 0.75, "prison_monitor_console")
	# A solid dark rack and intermediate shelf make the four CRTs read as a
	# monitor console from every side, not as pale cubes hovering behind bars.
	_mrbox(mv, Vector3(0, 0.38, 0), Vector3(1.28, 0.76, 0.58),
		Mats.prison_green(), 0.025)
	_mbox(mv, Vector3(0, 1.18, 0.18), Vector3(1.24, 1.18, 0.08),
		Mats.prison_green())
	_mbox(mv, Vector3(0, 1.19, 0), Vector3(1.22, 0.055, 0.54),
		Mats.prison_iron())
	for mi in 4:
		var mp := Vector3(-0.28 + 0.56 * float(mi % 2),
			0.94 + 0.49 * float(mi / 2), 0)
		_mrbox(mv, mp, Vector3(0.5, 0.42, 0.42), Mats.iron_dark(), 0.025)
		_mbox(mv, mp + Vector3(0, 0, -0.215),
			Vector3(0.38, 0.30, 0.01), Mats.screen_glow() if mi == 2 else Mats.screen_dark())
	_collider_yaw_box(mv.position + Vector3(0, 0.9, 0), Vector3(1.25, 1.9, 0.55), mv.rotation.y)
	_bind_furnishing_colliders(mv, monitor_b0)


func _prison_industry() -> void:
	for z in [3.6, 8.2]:
		var p := Vector3(6, 0, z)
		var bench_b0 := body.get_child_count()
		var bench := _furnishing_pivot(p, 0.0, "prison_industry_bench")
		_mrbox(bench, Vector3(0, 0.78, 0), Vector3(4.6, 0.12, 1.15),
			Mats.prison_green(), 0.025)
		for x in [-2.0, 2.0]:
			_mbox(bench, Vector3(x, 0.38, 0), Vector3(0.09, 0.76, 0.92),
				Mats.prison_iron())
		_collider_yaw_box(p + Vector3(0, 0.5, 0), Vector3(4.6, 1.0, 1.2), 0)
		# a vice and left-behind work on each bench
		_mbox(bench, Vector3(-1.2, 0.95, 0.2), Vector3(0.24, 0.22, 0.18),
			Mats.iron_dark())
		if _r(1893 + int(z)) < 0.6:
			_mbox(bench, Vector3(1.1, 0.90, -0.15), Vector3(0.5, 0.12, 0.35),
				Mats.box_white())
		_bind_furnishing_colliders(bench, bench_b0)
	_cc0_prop("steel_frame_shelves_01", Vector3(10.7, 0, 6), -PI / 2.0, 0.1)
	_collider_yaw_box(Vector3(10.7, 0.9, 6), Vector3(2.0, 1.8, 0.75), -PI / 2.0)
	# work lamps low over the benches
	for lz in [3.6, 8.2]:
		var lamp := _cc0_prop("hanging_industrial_lamp", Vector3(6, ceil_h - 0.06, lz),
			0.0, 0.85)
		_asy_no_shadows(lamp)
	if _r(1897) < 0.6:
		_cc0_prop("wooden_crate_02", Vector3(1.8, 0, 9.6), _r(1898) * TAU, 0.9)
	if _r(1899) < 0.4:
		# ships as an upright wheel — lay it flat
		var tyre := _cc0_prop("old_tyre", Vector3(2.2, 0.085, 2.1), _r(1900) * TAU)
		tyre.rotation.x = PI / 2.0
	# A battered rolling job cart and its detached refuse lid create the
	# maintenance-shop density the bare benches were missing.
	_cc0_floor_prop("industrial_storage_cart", Vector3(2.0, 0, 6.0),
		PI / 2.0, 0.72, "prison_industry_cart",
		Vector3(1.18, 1.0, 0.82), Vector3(0, 0.5, 0))
	if _r(1901) < 0.72:
		_cc0_floor_prop("metal_trash_can", Vector3(9.8, 0, 2.0),
			0.0, 0.68, "prison_industry_refuse",
			Vector3(1.28, 0.64, 0.44), Vector3(-0.06, 0.32, 0))


func _prison_visitation_phone(parent: Node3D, side_z: float) -> void:
	var phone := Node3D.new()
	phone.position = Vector3(0, 0, side_z * 0.08)
	phone.set_meta("prison_visitation_phone", true)
	phone.set_meta("enrichment_prop", "visitation_phone")
	parent.add_child(phone)
	# The authored handset carries its own body, cradle and coiled cord. It
	# hangs on the divider facing whichever side of the glass this booth is,
	# which is what `side_z` selects. Its centre is corrected under a pivot
	# rather than in the offset, so the turn cannot get the sign wrong.
	var mount := Node3D.new()
	mount.position = Vector3(0.42, 1.28, 0.0)
	mount.rotation.y = 0.0 if side_z > 0.0 else PI
	phone.add_child(mount)
	var hung := _attributed_prop_local(mount, PRISON_WALL_PHONE_PATH,
		Vector3(-PRISON_WALL_PHONE_CENTRE.x, -PRISON_WALL_PHONE_CENTRE.y,
			-PRISON_WALL_PHONE_CENTRE.z) * PRISON_WALL_PHONE_SCALE,
		0.0, Vector3.ONE * PRISON_WALL_PHONE_SCALE)
	if hung != null:
		hung.set_meta("authored_model", "visitation_phone")
		return
	mount.get_parent().remove_child(mount)
	mount.free()
	# Wall plate and keypad on the occupant's side of the glass.
	_mrbox(phone, Vector3(0.33, 1.35, 0),
		Vector3(0.34, 0.46, 0.09), Mats.prison_green(), 0.025)
	for row in 3:
		for col in 2:
			var key := _mcyl(phone, Vector3(0.25 + float(col) * 0.085,
				1.25 + float(row) * 0.085, side_z * 0.052),
				0.018, 0.018, Mats.metal_gray())
			key.rotation.x = PI / 2.0
	# A heavy vertical receiver with distinct ear and mouth caps.
	_mrbox(phone, Vector3(0.51, 1.37, side_z * 0.075),
		Vector3(0.085, 0.34, 0.085), Mats.charcoal(), 0.025)
	for py in [1.18, 1.56]:
		var cap := _mcyl(phone, Vector3(0.51, py, side_z * 0.075),
			0.075, 0.11, Mats.rubber_black())
		cap.rotation.x = PI / 2.0
	for py in [1.22, 1.52]:
		_mbox(phone, Vector3(0.45, py, side_z * 0.04),
			Vector3(0.08, 0.045, 0.09), Mats.prison_iron())
	# Slack cord drops to the counter in a crooked, readable loop.
	var cord := [
		Vector3(0.50, 1.15, side_z * 0.09),
		Vector3(0.55, 1.06, side_z * 0.11),
		Vector3(0.48, 0.98, side_z * 0.12),
		Vector3(0.56, 0.91, side_z * 0.12),
		Vector3(0.45, 0.86, side_z * 0.10),
	]
	for i in cord.size() - 1:
		_mbeam(phone, cord[i], cord[i + 1], 0.012, Mats.rubber_black())


func _prison_visitation_booth(p: Vector3) -> void:
	var b0 := body.get_child_count()
	var booth := _furnishing_pivot(p, 0.0, "prison_visitation_booth")
	booth.set_meta("visitation_counter", true)
	booth.set_meta("visitation_stool_count", 2)
	# Each bay is a complete little booth: counter, floor base, glass, handset
	# and two bolted stools. Doorway clearance may remove one bay, but cannot
	# separate a row of stools from the furniture they face.
	_mrbox(booth, Vector3(0, 0.82, 0), Vector3(1.34, 0.16, 1.1),
		Mats.prison_green(), 0.025)
	_mbox(booth, Vector3(0, 0.375, 0), Vector3(1.26, 0.75, 0.85),
		Mats.prison_green())
	_mbox(booth, Vector3(0, 1.75, 0), Vector3(1.34, 1.7, 0.055),
		Mats.mall_glass())
	for side_x in [-1.0, 1.0]:
		_mbox(booth, Vector3(side_x * 0.65, 1.28, 0),
			Vector3(0.055, 1.95, 1.1), Mats.prison_iron())
	for side_z: float in [-1.0, 1.0]:
		_prison_visitation_phone(booth, side_z)
		var stool_z: float = side_z * 1.15
		_mcyl(booth, Vector3(0, 0.30, stool_z), 0.05, 0.60,
			Mats.prison_iron())
		_mcyl(booth, Vector3(0, 0.63, stool_z), 0.19, 0.06,
			Mats.prison_green())
		_collider_cyl(p + Vector3(0, 0.35, stool_z), 0.20, 0.70)
	_collider_yaw_box(p + Vector3(0, 0.75, 0), Vector3(1.34, 1.5, 1.2), 0)
	_bind_furnishing_colliders(booth, b0)


func _prison_visitation() -> void:
	for i in 4:
		_prison_visitation_booth(Vector3(3.75 + float(i) * 1.5, 0, 6.4))


func _prison_rotunda() -> void:
	var c := Vector3(6, 0, 6)
	var radius := 2.45
	# Raised masonry plinth and a roof plate make the hub a small building
	# inside the block, not a ring of arbitrary posts.
	_cyl(c + Vector3(0, 0.36, 0), radius, 0.72, Mats.prison_green(), false)
	_cyl(c + Vector3(0, 3.18, 0), radius + 0.16, 0.16, Mats.prison_iron(), false)
	# Dense iron cage: three polygonal rings and twenty-four verticals.
	var sides := 24
	for i in sides:
		var a := TAU * float(i) / float(sides)
		var b := TAU * float(i + 1) / float(sides)
		var p0 := c + Vector3(cos(a), 0, sin(a)) * radius
		var p1 := c + Vector3(cos(b), 0, sin(b)) * radius
		_beam(p0 + Vector3(0, 0.74, 0), p1 + Vector3(0, 0.74, 0),
			0.055, Mats.prison_iron())
		_beam(p0 + Vector3(0, 1.92, 0), p1 + Vector3(0, 1.92, 0),
			0.035, Mats.prison_iron())
		_beam(p0 + Vector3(0, 3.08, 0), p1 + Vector3(0, 3.08, 0),
			0.055, Mats.prison_iron())
		_beam(p0 + Vector3(0, 0.74, 0), p0 + Vector3(0, 3.08, 0),
			0.035, Mats.prison_iron())
	# A circular control desk, instrument blocks and a cold lamp are visible
	# through the bars from every branch of the rotunda.
	_cyl(c + Vector3(0, 1.02, 0), 1.55, 0.16, Mats.prison_iron(), false)
	_cyl(c + Vector3(0, 0.80, 0), 1.18, 0.44, Mats.prison_green(), false)
	for i in 6:
		var a := TAU * float(i) / 6.0
		var p := c + Vector3(cos(a), 1.18, sin(a)) * 1.23
		var panel := _box(p, Vector3(0.54, 0.30, 0.12), Mats.charcoal(), false)
		panel.rotation.y = -a + PI / 2.0
		var lamp := _box(p + Vector3(0, 0.02, 0), Vector3(0.20, 0.08, 0.13),
			Mats.prison_panel(), false)
		lamp.rotation.y = panel.rotation.y
	_collider_cyl(c + Vector3(0, 1.5, 0), radius, 3.0)
	# Roof-hung camera on an actual pendant, rather than a housing suspended in
	# the middle of the rotunda with nothing behind its wall plate.
	var cam_yaw := _r(1899) * TAU
	var cam_forward := Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var cam_mount := c + cam_forward * 0.62 + Vector3(0, 2.78, 0)
	_box(cam_mount - cam_forward * 0.08 + Vector3(0, 0.20, 0),
		Vector3(0.14, 0.54, 0.14), Mats.prison_iron(), false)
	_security_camera(cam_mount, cam_yaw)
	var guard_light := OmniLight3D.new()
	guard_light.position = c + Vector3(0, 2.75, 0)
	guard_light.light_color = Color(0.68, 0.88, 0.72)
	guard_light.light_energy = 2.4
	guard_light.omni_range = 9.5
	guard_light.shadow_enabled = true
	guard_light.distance_fade_enabled = true
	guard_light.distance_fade_begin = 24.0
	guard_light.distance_fade_length = 8.0
	add_child(guard_light)
	# radial walkway lanes painted out from the hub to every branch
	for i in 4:
		var a := TAU * float(i) / 4.0 + TAU / 8.0
		var dirv := Vector3(cos(a), 0, sin(a))
		var lp := c + dirv * (radius + 1.75)
		var lane := _box(lp + Vector3(0, 0.012, 0), Vector3(0.07, 0.015, 2.6),
			Mats.caution_yellow(), false)
		lane.rotation.y = -a + PI / 2.0

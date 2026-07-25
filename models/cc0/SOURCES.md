# Shared CC0 prop pool — sources

All CC0 (public domain), downloaded from [Poly Haven](https://polyhaven.com)
as glTF with 1k textures (polyhaven.com/a/<folder-name>). No attribution
required; listed for provenance. Loaded through `Chunk._cc0_prop`.

**Casino:** sofa_03, ArmChair_01, Ottoman_01, CoffeeTable_01, Chandelier_03,
fancy_picture_frame_01, fancy_picture_frame_02, bar_chair_round_01,
vintage_grandfather_clock_01, potted_plant_01.

**Office:** television_02, CoffeeCart_01, drawer_cabinet, clipboard,
wall_clock, steel_frame_shelves_01 (ships ~10x life size — used at scale
0.1), potted_plant_02, WetFloorSign_01, coffee_table_round_01,
office_notepads, stationery_supplies, security_camera_01. The office task
chair is the CC0 `Office Chair` by nisu/3DModelsCC0, mirrored by
[OpenGameArt](https://opengameart.org/content/office-chair-1); its supplied
PBR maps are bound explicitly because the FBX retains a stale TIFF reference.

**Sewer:** industrial_caged_sconce, hanging_industrial_lamp (hangs 1.34m
below its origin), Barrel_01, barrel_03, wooden_crate_02, old_tyre (upright
wheel — rotate x 90° and sit at y 0.085 to lay flat), rusted_wheel_rim_01,
power_box_01, wooden_ladder, trashbag, plastic_crate_03.

**Sewer machinery:** old_military_compressor (its authored origin is 4.22m
behind its mesh centre, compensated in `Chunk._sewer_compressor`).

**Park:** street_lamp_01 (3.87m), wooden_picnic_table (2.2×3.0 incl.
benches), Lantern_01, wooden_barrels_01 (a 4.4×3.3m barrel cluster — use
scaled ~0.75), barrel_stove, tree_stump_01 (roots start 0.19 below origin),
rusted_wheel_rim_02, wooden_crate_01.

**Airport:** the former `vintage_suitcase` placement has been superseded by
Niels Philipsen's attributed luggage set; the CC0 source remains in the bundled
library but is no longer instantiated or preloaded by the airport.

**School:** SchoolDesk_01 (modelled adjustable student desk with storage
shelf; retained in the source library but superseded in classroom layouts by
the combined attributed desk-and-chair model). Downloaded at 1K glTF from
`polyhaven.com/a/SchoolDesk_01`. Additional school-specific models:
book_encyclopedia_set_01, bunsen_burner, chemistry_set, projector_screen,
stationery_supplies, and security_camera_01.

**Abandoned mall:** CashRegister_01, hand_truck, industrial_storage_cart,
metal_trash_can, and long_life_food. These are used selectively at checkout
counters, shuttered kiosks, stockrooms, food-court service areas and maintenance
rooms. The authored wear and age fit the abandoned late-century mall; none are
used as generic decoration where their function would not make sense.

**Island prison:** industrial_storage_cart and metal_trash_can in work/service
areas; plunger, drain_cleaner and can_rusted in cell, sanitation and shower
contexts. Prison bunks are purpose-built welded detention assemblies; the
ornate Poly Haven old_bed_frame remains exclusive to the asylum, where its
domestic/institutional silhouette belongs.

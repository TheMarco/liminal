# Third-party assets and licenses

It wants you to stay combines original procedural work with openly licensed art. This
file is the canonical attribution record; the in-game Credits screen provides
the compact presentation appropriate to the game.

## Asset policy

New assets must have a recorded author, original source URL, license URL and a
note describing any modifications. The project accepts:

- CC0 / public-domain work.
- CC BY 2.0, 3.0 or 4.0 work with complete attribution.
- CC BY-NC 2.0, 3.0 or 4.0 work with complete attribution when the asset is
  explicitly marked noncommercial in this record. Builds containing those
  assets may not be sold, monetized or otherwise used commercially.
- Purchased royalty-free work whose license permits redistribution as an
  embedded game asset, with the purchase record retained outside the repo.
- Sketchfab Standard assets supplied by the project owner, used only as
  embedded game content under the platform's standard license.

The project does **not** accept assets marked no-derivatives, editorial-only,
personal-use-only, AI-generated with unclear provenance, or with no explicit
license. Any future commercial release must first replace every CC BY-NC asset
and remove it from the distributed build.

## Attributed work

### `old_school_vcr.glb`

- **Title:** `Old School VCR`
- **Creator:** [William Burke](https://sketchfab.com/William.Burke)
- **Source:** <https://sketchfab.com/3d-models/old-school-vcr-c8ff5be11ad94215bec40e3350264023>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Retained unchanged; runtime instances are re-centred,
  scaled and rotated when placed as the VHS player in Descent elevator rooms.
- **Local record:** [`models/cc_by/old_school_vcr/SOURCE.md`](models/cc_by/old_school_vcr/SOURCE.md)

### `retro_television.glb`

- **Title:** `Retro Television`
- **Creator:** [Tom Seddon](https://sketchfab.com/bloodmeat08)
- **Source:** <https://sketchfab.com/3d-models/retro-television-e938241a182a4229ad48a1fc589e676e>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Retained unchanged; runtime instances are re-centred,
  scaled and rotated when placed as the CRT television in Descent elevator
  rooms, and the screen surface is intended to be replaced by the game's VHS
  playback material.
- **Local record:** [`models/cc_by/retro_television/SOURCE.md`](models/cc_by/retro_television/SOURCE.md)

### `tv_table.glb`

- **Title:** `Tv Table`
- **Creator:** [Parth](https://sketchfab.com/khatriparth)
- **Source:** <https://sketchfab.com/3d-models/tv-table-ffc3c739a0894e20881de2c81be2e59d>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Retained unchanged; runtime instances are re-centred,
  scaled and rotated when placed as the media table under the CRT television
  in Descent elevator rooms.
- **Local record:** [`models/cc_by/tv_table/SOURCE.md`](models/cc_by/tv_table/SOURCE.md)

### `modular_vines.glb`

- **Title:** `Modular Vines`
- **Creator:** [Somersby](https://sketchfab.com/Somersby)
- **Source:** <https://sketchfab.com/3d-models/modular-vines-eccf0e6839954dca8eabfb504d572394>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Re-centred, scaled and rotated into selective thorn
  canopies and wound borders in the Bloom. Its source material is replaced at
  runtime by the animated black vascular shader; geometry is unchanged and
  carries no gameplay collision.
- **Local record:** [`models/cc_by/modular_vines/SOURCE.md`](models/cc_by/modular_vines/SOURCE.md)

### `flesh_blob.glb`

- **Title:** `Flesh Blob`
- **Creator:** [ChopperManiac](https://sketchfab.com/ChopperManiac)
- **Source:** <https://sketchfab.com/3d-models/flesh-blob-b3f5bb51f8144a30b6fa6b22f5d44bf7>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Only the organic mesh is shown; the source demonstration
  floor and wall are hidden. Runtime placement preserves the PBR materials and
  loops the authored six-second morph animation with an additional subtle
  asynchronous scale pulse.
- **Local record:** [`models/cc_by/flesh_blob/SOURCE.md`](models/cc_by/flesh_blob/SOURCE.md)

### `fluorescent_light_fixtures.glb`

- **Title:** `Fluorescent Light Fixtures - 4x 4096px²`
- **Creator:** [Mark Peters](https://sketchfab.com/mark-peters)
- **Source:** <https://sketchfab.com/3d-models/fluorescent-light-fixtures-4x-4096px2-2a05034d61dc49bf81b33de44add7aa8>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** The four authored designs are selected individually,
  centred and ceiling-mounted throughout the Monolith. Their PBR/emissive
  materials are retained and paired with deterministic room lights; dead and
  flickering cells isolate emission state per instance.
- **Local record:** [`models/cc_by/fluorescent_light_fixtures/SOURCE.md`](models/cc_by/fluorescent_light_fixtures/SOURCE.md)

### `hovercar_charging_station.glb`

- **Title:** `Hovercar Charging Station`
- **Creator:** [Archer Sterling](https://sketchfab.com/archersterling)
- **Source:** <https://sketchfab.com/3d-models/hovercar-charging-station-125c81972ef94d8da063cf9d7c7ff245>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Uniformly scaled and floor-centred as the interactive
  flashlight charger, with conservative collision and a runtime status light.
- **Local record:** [`models/cc_by/hovercar_charging_station/SOURCE.md`](models/cc_by/hovercar_charging_station/SOURCE.md)

### Extracted exit door from `backrooms_vr.glb`

- **Title:** `Backrooms VR`
- **Creator:** [carlcapu9](https://sketchfab.com/carlcapu9)
- **Source:** <https://sketchfab.com/3d-models/backrooms-vr-d9b98eca8d064d0eafcd7f5484bb61ed>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** One complete double-door assembly was spatially extracted
  from the supplied 81-metre, material-merged environment, including its frame,
  leaves, handles and EXIT sign. It was rebased to a floor-centred origin and
  its opaque surfaces were restored to dynamic per-pixel lighting. The rest of
  the source environment is not distributed or instantiated.
- **Local record:** [`models/cc_by/backrooms_vr_exit_door/SOURCE.md`](models/cc_by/backrooms_vr_exit_door/SOURCE.md)

### `light_switch.glb`

- **Title:** `Light Switch`
- **Creator:** [Avot](https://sketchfab.com/avot)
- **Source:** <https://sketchfab.com/3d-models/light-switch-808c3de4dd874fc1b67ff15cd2645555>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Re-oriented and mounted flush at realistic switch height
  on deterministic Annex and office walls, usually beside openings.
- **Local record:** [`models/cc_by/light_switch/SOURCE.md`](models/cc_by/light_switch/SOURCE.md)

### `outlet.glb`

- **Title:** `Outlet`
- **Creator:** [Drake](https://sketchfab.com/dlp14c)
- **Source:** <https://sketchfab.com/3d-models/outlet-192d0b1de17f4fcdbfeca3fe873c7bdf>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Mounted flush at normal receptacle height with restrained,
  deterministic spacing on Annex and office walls.
- **Local record:** [`models/cc_by/outlet/SOURCE.md`](models/cc_by/outlet/SOURCE.md)

### `stainless_steel_shelving.glb`

- **Title:** `Stainless Steel Shelving Restaurant Equipment`
- **Creator:** [jimbogies](https://sketchfab.com/jimbogies)
- **Source:** <https://sketchfab.com/3d-models/stainless-steel-shelving-restaurant-equipment-01addf6c21304a26a9634cbf725230ef>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Uniformly scaled and floor-centred as sparse Annex storage
  shelving, with individually selected attributed cardboard boxes placed on
  supported shelves. Source staging camera nodes are not used.
- **Local record:** [`models/cc_by/stainless_steel_shelving/SOURCE.md`](models/cc_by/stainless_steel_shelving/SOURCE.md)

### `wood_dining_chair.glb`

- **Title:** `Wood Dining Chair`
- **Creator:** [Doverlock](https://sketchfab.com/Doverlock)
- **Source:** <https://sketchfab.com/3d-models/wood-dining-chair-dd63d6eb1d8d452786b9afd4555a8d2e>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Uniformly scaled and floor-centred into isolated chairs,
  small groups, and rare supported chair piles in large Annex spaces.
- **Local record:** [`models/cc_by/wood_dining_chair/SOURCE.md`](models/cc_by/wood_dining_chair/SOURCE.md)

### `chemistry_lab_table.glb`

- **Title:** `Chemistry Lab Table`
- **Creator:** [Jawahar Yokesh](https://sketchfab.com/Jawahar_Yokesh)
- **Source:** <https://sketchfab.com/3d-models/chemistry-lab-table-fc5951d8af674da4bf55aef0693ff1d0>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Uniformly scaled and floor-centred as the central island in
  every school chemistry lab. The black granite and nickel are given physically
  plausible roughness/metallic values for readable fluorescent-lit surfaces.
- **Local record:** [`models/cc_by/chemistry_lab_table/SOURCE.md`](models/cc_by/chemistry_lab_table/SOURCE.md)

### `chemistry_bottles.glb`

- **Title:** `Chemistry Bottles`
- **Creator:** [dercruz926](https://sketchfab.com/dercruz926)
- **Source:** <https://sketchfab.com/3d-models/chemistry-bottles-12b838f10b07406f837b14d326039b36>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Uniformly scaled and bottom-aligned on supported surfaces.
  School and asylum rooms independently select authored vessels and test-tube
  assemblies; school items are distributed among triangle-verified points on
  the table's L-shaped worktop. Glass is corrected from metallic to dielectric
  and made slightly more legible in low light.
- **Local record:** [`models/cc_by/chemistry_bottles/SOURCE.md`](models/cc_by/chemistry_bottles/SOURCE.md)

### `luggage.glb`

- **Title:** `Luggage`
- **Creator:** [Niels Philipsen / n.philipsen](https://sketchfab.com/n.philipsen)
- **Source:** <https://sketchfab.com/3d-models/luggage-9b266e1dcb7f430597a8689e5602ad7e>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** The staged set is separated at runtime into its backpack
  and two rolling cases, uniformly scaled to carry-on size and floor-centred.
  Deterministic muted variants recolor only shell and fabric materials; handles,
  wheels, zippers and metal hardware retain their source finishes. These pieces
  replace all former generated airport luggage, including trolley and baggage
  carousel loads.
- **Local record:** [`models/cc_by/luggage/SOURCE.md`](models/cc_by/luggage/SOURCE.md)

### `shopping_cart.glb`

- **Title:** `Shopping Cart`
- **Creator:** [AdrianXY](https://sketchfab.com/AdrianXY)
- **Source:** <https://sketchfab.com/3d-models/shopping-cart-b96f896453b240ae804d0399f1faf027>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Uniformly scaled to a 1.01m handle height, floor-centred
  and rotated 180 degrees inside its placement pivot to preserve the generated
  mall layouts' original cart facing. It replaces every generated shopping
  cart; loaded variants retain their existing deterministic contents and loose
  carts receive conservative collision.
- **Local record:** [`models/cc_by/shopping_cart/SOURCE.md`](models/cc_by/shopping_cart/SOURCE.md)

### `indoor_air_conditioner_unit.glb`

- **Title:** `Indoor air conditioner unit`
- **Creator:** [Rylae Shylna](https://sketchfab.com/risteralline)
- **Source:** <https://sketchfab.com/3d-models/indoor-air-conditioner-unit-d93c5557a9ba46afbb00e35f48343077>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Uniformly scaled to an approximately 1.25 m-wide indoor
  unit, re-centred on its housing, and mounted high on office-room walls. Every
  non-corridor office room receives one unit, with larger rooms and a
  deterministic minority of smaller rooms receiving two. Solid undecorated
  walls are preferred; high doorway headers provide a safe fallback. Rare
  wall-less open-plan rooms use a generated ceiling-suspended backing plate so
  the authored housing remains visibly supported. The source mesh and embedded
  PBR materials are otherwise unchanged.
- **Local record:** [`models/cc_by/indoor_air_conditioner/SOURCE.md`](models/cc_by/indoor_air_conditioner/SOURCE.md)

### `ceiling_tiles_texture.glb`

- **Title:** `Ceiling Tiles Texture`
- **Creator:** [AquaEquinox](https://sketchfab.com/ohno9119)
- **Source:** <https://sketchfab.com/3d-models/ceiling-tiles-texture-d56374c2680e44af9849f43f6ae3206e>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** The embedded albedo, metallic-roughness and normal maps are
  extracted by Godot and mapped world-space across the existing office ceiling
  with a tightened acoustic-tile repeat appropriate to the three-metre rooms.
  The source demonstration slab is not instantiated; existing ceiling geometry,
  collision and fluorescent fixtures remain unchanged. No other level uses
  these maps.
- **Local record:** [`models/cc_by/ceiling_tiles_texture/SOURCE.md`](models/cc_by/ceiling_tiles_texture/SOURCE.md)

### `airport_departure_board.glb`

- **Title:** `Airport Departure Board`
- **Creator:** [Ellis Fossett](https://sketchfab.com/ellisfossett504)
- **Source:** <https://sketchfab.com/3d-models/airport-departure-board-82849aebd85c4c3c85b455c1e9f41037>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Uniformly scaled into large hanging and compact wall-mounted
  variants, re-centred on each existing FIDS placement, and supplemented with
  deterministic destination, time, gate and status text on the three authored
  black display panels. Geometry and embedded materials are otherwise
  unchanged.
- **Local record:** [`models/cc_by/airport_departure_board/SOURCE.md`](models/cc_by/airport_departure_board/SOURCE.md)

### `airport_seats.glb`

- **Title:** `Airport Seats`
- **Creator:** [Bucks / Its_Bucks](https://sketchfab.com/Its_Bucks)
- **Source:** <https://sketchfab.com/3d-models/airport-seats-abf141b715274340bef239a1a9930641>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Uniformly scaled to a 2.10 m-wide four-seat bank,
  floor-centred and rotated to preserve the generated rows' facing direction.
  Source camera and light staging nodes are removed at instantiation. The
  authored four-seat proportions replace all previous 3–5-seat airport rows.
- **Local record:** [`models/cc_by/airport_seats/SOURCE.md`](models/cc_by/airport_seats/SOURCE.md)

### `cardboard_boxes.glb`

- **Title:** `Set of Cardboard Boxes`
- **Creator:** [NotAnotherApocalypticCo.](https://sketchfab.com/notanotherapocalypticco)
- **Source:** <https://sketchfab.com/3d-models/set-of-cardboard-boxes-8986ba512f704ac5b253286a0d1ad8bb>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** The four real-world box sizes are selected individually
  from the supplied staged set, centred and bottom-aligned on generated office
  shelves. Occupancy and slight yaw remain deterministic; school shelves retain
  their existing procedural boxes.
- **Local record:** [`models/cc_by/cardboard_boxes/SOURCE.md`](models/cc_by/cardboard_boxes/SOURCE.md)

### `mfp_office_printer.glb`

- **Title:** `MFP Office Printer`
- **Creator:** [Red Fox / nokillnando](https://sketchfab.com/nokillnando)
- **Source:** <https://sketchfab.com/3d-models/mfp-office-printer-d55f6fca7c3d45c883bbff770672970d>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Uniformly scaled to 1% of authored size, floor-centred,
  preloaded with the office fixtures and given conservative gameplay collision.
  It replaces the generated copier in all office placements; mesh and embedded
  materials are otherwise unchanged.
- **Local record:** [`models/cc_by/mfp_office_printer/SOURCE.md`](models/cc_by/mfp_office_printer/SOURCE.md)

### `water_cooler.glb`

- **Title:** `Water Cooler`
- **Creator:** [小林 団那紀 / dannaki_](https://sketchfab.com/dannaki_)
- **Source:** <https://sketchfab.com/3d-models/water-cooler-c2176d7cabb6444f9f04734f3fb1ab43>
- **License:** [Sketchfab Standard](https://sketchfab.com/licenses)
- **Modifications:** Uniformly scaled to 10% of authored size, floor-centred in
  the office break-room corner, preloaded with the other authored fixtures and
  given conservative gameplay collision. Mesh and embedded materials are
  otherwise unchanged.
- **Local record:** [`models/sketchfab/water_cooler/SOURCE.md`](models/sketchfab/water_cooler/SOURCE.md)

### `slot_machine.glb`

- **Title:** `Slot_machine`
- **Creator:** [morrrtu1o](https://sketchfab.com/morrrtu1o)
- **Source:** <https://sketchfab.com/3d-models/slot-machine-d58181162e154af2ab73e8667db2e81d>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** The 1K GLB is scaled and floor-aligned in Godot, receives
  conservative gameplay collision and a small live status lamp, and is mixed
  with a minority of original procedural cabinets for visual variety. Its
  embedded PBR mesh and textures are otherwise unchanged.
- **Local record:** [`models/cc_by/slot_machine/SOURCE.md`](models/cc_by/slot_machine/SOURCE.md)

### Abandoned hospital — extracted props

- **Title:** `Abandoned Hospital: part two`
- **Creator:** [Veterock](https://sketchfab.com/windofglass)
- **Source:** <https://sketchfab.com/3d-models/abandoned-hospital-part-two-c4c2546533fd4ee2a87ddd642f33f446>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** The source is a whole multi-storey hospital whose
  architecture is batched per material, so only its separately-modelled objects
  are used: four door leaves, a steel scrub trough, one hydrotherapy tub cut
  from a row of three, and a sheet of paper still pinned to a wall. Each carries
  its source node's ancestor transform, is re-origined to its own floor and
  centre, and keeps only the geometry and images it references. The building
  itself is not redistributed. Doors hang at authored height as sealed façades
  on solid walls and at 0.867 inside a generated corridor casing; the tub is
  placed at 0.80, which brings its rim to a real 0.68m.
- **Local record:** [`models/cc_by/abandoned_hospital/SOURCE.md`](models/cc_by/abandoned_hospital/SOURCE.md)

### `hospital_bed.glb`

- **Title:** `Hospital Bed`
- **Creator:** [loxfear](https://sketchfab.com/loxfear)
- **Source:** <https://sketchfab.com/3d-models/hospital-bed-f8c13a19e84343e7b644c19f7b9488d3>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled from centimetres, turned onto the ward's bed rows
  and given conservative collision. It arrives already made up, so it replaces
  both the CC0 frame and the generated bedding on most beds.
- **Local record:** [`models/cc_by/hospital_bed/SOURCE.md`](models/cc_by/hospital_bed/SOURCE.md)

### `asylum_gurney.glb`

- **Title:** `Game Prop: Mental Asylum Gurney`
- **Creator:** [Ellie](https://sketchfab.com/eymori)
- **Source:** <https://sketchfab.com/3d-models/game-prop-mental-asylum-gurney-43736bb6a0b64fe8a824542bdbace6bc>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Placed at authored scale with conservative collision. Its
  frame material shipped a metallic-roughness map pinning roughness to zero,
  which renders as a black cut-out under the game's practicals; a roughness
  floor is applied once to that shared material at load. Albedo and normal maps
  are untouched.
- **Local record:** [`models/cc_by/asylum_gurney/SOURCE.md`](models/cc_by/asylum_gurney/SOURCE.md)

### `hospital_trolley.glb`

- **Title:** `Hospital Trolley`
- **Creator:** [creative_beast](https://sketchfab.com/creative_beast)
- **Source:** <https://sketchfab.com/3d-models/hospital-trolley-6fa14ba57e324d288b5a42632f19d97f>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Placed at authored scale, floor-aligned and given
  conservative collision in asylum wards, treatment and hydrotherapy rooms.
- **Local record:** [`models/cc_by/hospital_trolley/SOURCE.md`](models/cc_by/hospital_trolley/SOURCE.md)

### `ibm_3278_terminal.glb`

- **Title:** `IBM 3278 terminal`
- **Creator:** [maxdragonn](https://sketchfab.com/maxdragon)
- **Source:** <https://sketchfab.com/3d-models/ibm-3278-terminal-b0470478089a4462afb4d5c4dd827b22>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled to desk size and turned so its screen faces whoever
  sat there. It arrives as display and keyboard together, so it replaces both
  generated pieces on the desks that take it. A stray `Lamp` node from the
  authoring scene is removed at instantiation.
- **Local record:** [`models/cc_by/ibm_3278_terminal/SOURCE.md`](models/cc_by/ibm_3278_terminal/SOURCE.md)

### `payphone.glb`

- **Title:** `Payphone`
- **Creator:** [mtaesiri](https://sketchfab.com/mtaesiri)
- **Source:** <https://sketchfab.com/3d-models/payphone-ec3a176820074776a3632c6feb0b8327>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** The source scans the payphone together with the tiled wall
  behind it. The mesh is clipped to the phone housing alone — 88,025 triangles
  down to 19,716 — and re-origined so its open back sits on the wall contact
  plane. Its material and baked texture are otherwise unchanged.
- **Local record:** [`models/cc_by/payphone/SOURCE.md`](models/cc_by/payphone/SOURCE.md)

### `mall_directories.glb`

- **Title:** `Mall Directories`
- **Creator:** [kapookkt](https://sketchfab.com/kapookkt)
- **Source:** <https://sketchfab.com/3d-models/mall-directories-f33eda5033e44b18a74bb0493d0ba952>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled from centimetres. The source models a readable front
  face only, with no base and blank sides, so an original plinth and edge frame
  are generated around it and carry the collision.
- **Local record:** [`models/cc_by/mall_directories/SOURCE.md`](models/cc_by/mall_directories/SOURCE.md)

### `corded_phone.glb`

- **Title:** `Corded Phone No Buttons`
- **Creator:** [dudecon](https://sketchfab.com/dudecon)
- **Source:** <https://sketchfab.com/3d-models/corded-phone-no-buttons-77376f2347964e8d9632321bcdd89536>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled up to a 0.21m desk phone and assigned a generated
  institutional plastic, since the source ships no textures at all. It sits on
  prison guard-station desks; the visitation booths keep their own generated
  wall handsets.
- **Local record:** [`models/cc_by/corded_phone/SOURCE.md`](models/cc_by/corded_phone/SOURCE.md)

### Mall storefront signs — noncommercial

- **Title:** `Abandoned shopping mall`
- **Creator:** [Katydid](https://sketchfab.com/Katydid.)
- **Source:** <https://sketchfab.com/3d-models/abandoned-shopping-mall-e23793e82dec4d779268229d4a0429a9>
- **License:** [Creative Commons Attribution-NonCommercial 4.0 International](https://creativecommons.org/licenses/by-nc/4.0/)
- **Commercial-use status:** **Not permitted.** Builds containing these textures
  are noncommercial and must not be sold or monetized.
- **Modifications:** The source geometry is a three-storey octagonal atrium and
  is not used — its storey height and bay spacing do not fit this project's grid,
  and its surfaces are batched across the whole ring. Only the painted fascia
  signs are taken: nine cropped, unaltered, from its storefront atlas and mounted
  on the project's own generated fascias at the artwork's authored aspect. Every
  use goes through one function in `scripts/chunk.gd`, so the dependency can be
  removed in a single edit, and the generated lettering it replaces remains as
  the fallback.
- **Local record:** [`textures/cc_by_nc/mall_signs/SOURCE.md`](textures/cc_by_nc/mall_signs/SOURCE.md)

### `blackjack_table.glb`

- **Title:** `Blackjack table`
- **Creator:** [nermin](https://sketchfab.com/nermin)
- **Source:** <https://sketchfab.com/3d-models/blackjack-table-b2b0974f06ee4623b882c76378a59483>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** The source is 500,000 triangles, 84% of it a group of 40
  casino chips modelled at 10,500 triangles each. That group is removed, leaving
  the table, felt and six matching stools at 80,000 triangles. The remainder is
  scaled, floor-aligned and given collision on the table body only, so the
  player can still walk between the stools.
- **Local record:** [`models/cc_by/blackjack_table/SOURCE.md`](models/cc_by/blackjack_table/SOURCE.md)

### `roulette_table.glb`

- **Title:** `Roulette table 2`
- **Creator:** [Dudzy](https://sketchfab.com/Dudzy)
- **Source:** <https://sketchfab.com/3d-models/roulette-table-2-downloadable-b1d33eebb4f54b8aa250be2f49e87fbb>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled to a 3.00m table, floor-aligned and given
  conservative collision. Restricted to grand halls, the only casino rooms with
  the floor area for it.
- **Local record:** [`models/cc_by/roulette_table/SOURCE.md`](models/cc_by/roulette_table/SOURCE.md)

### `hotdog_stand.glb`

- **Title:** `Hotdog stand`
- **Creator:** [shirlanne](https://sketchfab.com/shirlanne)
- **Source:** <https://sketchfab.com/3d-models/hotdog-stand-3be1662c3f5b4752a9bdda0a081e608e>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled to a 1.91m cart, floor-aligned and given
  conservative collision, stranded on the food-court seating floor rather than
  joined to the generated serving line.
- **Local record:** [`models/cc_by/hotdog_stand/SOURCE.md`](models/cc_by/hotdog_stand/SOURCE.md)

### `medical_table.glb`

- **Title:** `Medical table`
- **Creator:** [Mehdi Shahsavan](https://sketchfab.com/ahmagh2e)
- **Source:** <https://sketchfab.com/3d-models/medical-table-17mb-819e5e6825bf4587aeda1a7103ebfa20>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Placed at authored scale, floor-aligned with conservative
  collision. It is an autopsy table rather than the examination table its name
  suggests, so it is restricted to asylum treatment rooms.
- **Local record:** [`models/cc_by/medical_table/SOURCE.md`](models/cc_by/medical_table/SOURCE.md)

### `mfp_office_printer.glb`

- **Title:** `MFP office printer`
- **Creator:** [Red Fox / nokillnando](https://sketchfab.com/nokillnando)
- **Source:** <https://sketchfab.com/3d-models/mfp-office-printer-d55f6fca7c3d45c883bbff770672970d>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled from centimetres, re-origined to its own footprint
  and turned to face the room from the first solid storage wall.
- **Local record:** [`models/cc_by/mfp_office_printer/SOURCE.md`](models/cc_by/mfp_office_printer/SOURCE.md)

### `school_desk.glb`

- **Title:** `School desk`
- **Creator:** [barism09](https://sketchfab.com/barism09)
- **Source:** <https://sketchfab.com/3d-models/school-desk-a74180ee97bb4917b24cd48580663b44>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Desk and chair are one unit, so it replaces both halves of
  a generated pair. The source's baked 136.9088° presentation turn is removed
  so every chair faces through its writing surface toward the board. Scaled to
  0.007 and spaced from the model's corrected footprint. Used as the canonical
  student station throughout classroom rows.
- **Local record:** [`models/cc_by/school_desk/SOURCE.md`](models/cc_by/school_desk/SOURCE.md)

### `office_phone.glb`

- **Title:** `Office Phone`
- **Creator:** [maxdragonn](https://sketchfab.com/maxdragon)
- **Source:** <https://sketchfab.com/3d-models/office-phone-4176a01b6d0b4d13ad165c0df278a6b5>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **NoAI notice:** Used only as embedded game content, never as generative-AI
  training data or input.
- **Modifications:** Scaled, centred and floor-aligned on office desktops from
  measured imported bounds. Geometry and embedded texture are unchanged.
- **Local record:** [`models/cc_by/office_phone/SOURCE.md`](models/cc_by/office_phone/SOURCE.md)

### `bunk_bed.glb`

- **Title:** `Bunk Bed`
- **Creator:** [neverfollow81](https://sketchfab.com/neverfollow81)
- **Source:** <https://sketchfab.com/3d-models/bunk-bed-3ddab7a93381496eba3c36677e777912>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled to a 1.76 m frame, rotated and floor-aligned from
  measured bounds; supplied with conservative cell-only gameplay collision.
- **Local record:** [`models/cc_by/bunk_bed/SOURCE.md`](models/cc_by/bunk_bed/SOURCE.md)

### `prison_toilet.glb`

- **Title:** `Filthy Prison Toilet - 4096px²`
- **Creator:** [Mark Peters](https://sketchfab.com/mark-peters)
- **Source:** <https://sketchfab.com/3d-models/filthy-prison-toilet-4096px2-b8bdb85f59a44a8ea4b0783c8d22f373>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Uniformly scaled and turned toward the cell interior;
  paired with an original generated wall basin and conservative collision.
- **Local record:** [`models/cc_by/prison_toilet/SOURCE.md`](models/cc_by/prison_toilet/SOURCE.md)

### `prison_door_old.glb`

- **Title:** `door _Prison Door_metal_old -12MB`
- **Creator:** [Mehdi Shahsavan / adventurer](https://sketchfab.com/ahmagh2e)
- **Source:** <https://sketchfab.com/3d-models/door--prison-door-metal-old-12mb-45306a46c95b44ca8369f89c6648648c>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** The distant duplicate arrangement in the source scene is
  removed at runtime; the remaining complete closed door and frame are scaled
  and mounted only against solid prison walls.
- **Local record:** [`models/cc_by/prison_door_old/SOURCE.md`](models/cc_by/prison_door_old/SOURCE.md)

### `solitary_cell_door.glb`

- **Title:** `Door Of The Solitary Cell Of The Prison 14MB`
- **Creator:** [Mehdi Shahsavan / adventurer](https://sketchfab.com/ahmagh2e)
- **Source:** <https://sketchfab.com/3d-models/door-of-the-solitary-cell-of-the-prison-14mb-23db3362debb4d98a56856416e1e9c58>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Height-normalized, width-fitted and aligned to the
  interactive hinge so it opens away from the player from either side.
- **Local record:** [`models/cc_by/solitary_cell_door/SOURCE.md`](models/cc_by/solitary_cell_door/SOURCE.md)

### Authored replacements for generated furniture

Sixteen models that each took over a function which used to assemble the same
object out of boxes and cylinders. The two Sketchfab Standard assets were
supplied by the project owner and are used only as embedded game content.

#### `slot_machine_alt.glb`

- **Title:** `Slot Machine With Abstract Design`
- **Creator:** [Audrey Gonçalves](https://sketchfab.com/audreyfv10)
- **Source:** <https://sketchfab.com/3d-models/slot-machine-with-abstract-design-29e199a16098408abb48b3e04d243af6>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** The 5.2 m ground plane baked into the source scene is
  removed. Scaled to a 1.75 m cabinet and placed as the one-in-five casino
  machine that used to be assembled from forty-two primitives.
- **Local record:** [`models/cc_by/slot_machine_alt/SOURCE.md`](models/cc_by/slot_machine_alt/SOURCE.md)

#### `change_machine.glb`

- **Title:** `change machine`
- **Creator:** [juliegraham178](https://sketchfab.com/juliegraham178)
- **Source:** <https://sketchfab.com/3d-models/change-machine-68f395358c8d43c2b94e816d1c68a70d>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled to 1.75 m and stood against a casino wall. It
  carries its own branding, coin tray and bill slot, replacing a generated
  panel stack and a Label3D marquee.
- **Local record:** [`models/cc_by/change_machine/SOURCE.md`](models/cc_by/change_machine/SOURCE.md)

#### `city_bench.glb`

- **Title:** `City Bench`
- **Creator:** [matejbiskup97](https://sketchfab.com/matejbiskup97)
- **Source:** <https://sketchfab.com/3d-models/city-bench-973507d6b4e44265887f8feffa6de13e>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Authored in centimetres; scaled to a 1.89 m bench and
  floor-aligned, with collision on the seat block so the thin cast-iron
  ends are not an invisible wall.
- **Local record:** [`models/cc_by/city_bench/SOURCE.md`](models/cc_by/city_bench/SOURCE.md)

#### `iv_drip.glb`

- **Title:** `Crutch and IV Drip`
- **Creator:** [Matt LeMoine](https://sketchfab.com/Matt_LeMoine)
- **Source:** <https://sketchfab.com/3d-models/crutch-and-iv-drip-5cc65c6aed374220b67f7d60e679153e>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Re-origined from an authored 31.8-unit offset and
  scaled to a 1.95 m stand. Collision follows the pole rather than the
  castor base.
- **Local record:** [`models/cc_by/iv_drip/SOURCE.md`](models/cc_by/iv_drip/SOURCE.md)

#### `drinking_fountain.glb`

- **Title:** `Drinking Fountain`
- **Creator:** [FLUXIUM3D](https://sketchfab.com/fluxium3d)
- **Source:** <https://sketchfab.com/3d-models/drinking-fountain-69f0147a64354ba9aaf2f63e86169322>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled to 1.05 m and wall-mounted facing the room.
  Textures re-encoded at 512 px. Kept out of bathrooms, whose walls are
  already spoken for.
- **Local record:** [`models/cc_by/drinking_fountain/SOURCE.md`](models/cc_by/drinking_fountain/SOURCE.md)

#### `lockers.glb`

- **Title:** `Locker`
- **Creator:** [neverfollow81](https://sketchfab.com/neverfollow81)
- **Source:** <https://sketchfab.com/3d-models/locker-41f55ae53fca41c3b861cebe5244b5dd>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Authored in centimetres; scaled to a 1.97 x 1.85 m
  bank. Corridor runs are tiled with whole banks rather than one bank
  stretched to length.
- **Local record:** [`models/cc_by/lockers/SOURCE.md`](models/cc_by/lockers/SOURCE.md)

#### `gym_locker.glb`

- **Title:** `Metal Gym/Boxing Locker`
- **Creator:** [CAL21](https://sketchfab.com/CAL21)
- **Source:** <https://sketchfab.com/3d-models/metal-gymboxing-locker-975fe97634ad4812bc3b7450e7de6efb>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled to a 0.48 x 1.85 m single column, used where a
  corridor run is too short for a full bank.
- **Local record:** [`models/cc_by/gym_locker/SOURCE.md`](models/cc_by/gym_locker/SOURCE.md)

#### `wall_telephone.glb`

- **Title:** `Old Wall Mounted Telephone.`
- **Creator:** [ShepDes](https://sketchfab.com/ShepDes)
- **Source:** <https://sketchfab.com/3d-models/old-wall-mounted-telephone-d7efe01f8f51469c821407c9e248c519>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Authored in centimetres; scaled to 0.38 m and hung on
  a prison visitation divider, replacing a generated plate, keypad,
  receiver and cord.
- **Local record:** [`models/cc_by/wall_telephone/SOURCE.md`](models/cc_by/wall_telephone/SOURCE.md)

#### `sink.glb`

- **Title:** `Sink`
- **Creator:** [Osian CG](https://sketchfab.com/OsianOHM)
- **Source:** <https://sketchfab.com/3d-models/sink-83baa951f3b34ab3a5fd40478516ba3f>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Placed at authored scale in school bathrooms.
  Supplies its own tap and trap; the mirror band above it stays generated.
- **Local record:** [`models/cc_by/sink/SOURCE.md`](models/cc_by/sink/SOURCE.md)

#### `toilet.glb`

- **Title:** `Toilet`
- **Creator:** [HippoStance](https://sketchfab.com/hippostance)
- **Source:** <https://sketchfab.com/3d-models/toilet-132a8ee2af3a40d39d270fbed3d3666c>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Placed at authored scale and turned to put its
  cistern against the cubicle wall, replacing a generated pedestal, bowl,
  torus seat and tank.
- **Local record:** [`models/cc_by/toilet/SOURCE.md`](models/cc_by/toilet/SOURCE.md)

#### `urinal.glb`

- **Title:** `Urinal`
- **Creator:** [Dun](https://sketchfab.com/DundeeA)
- **Source:** <https://sketchfab.com/3d-models/urinal-caf807491633470784cb81990825d09d>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Placed at authored scale. Modelled already hanging,
  so only X and Z are recentred. Runs of three face the stalls in school
  bathrooms, which previously had none.
- **Local record:** [`models/cc_by/urinal/SOURCE.md`](models/cc_by/urinal/SOURCE.md)

#### `garbage_bin.glb`

- **Title:** `Stylized Garbage Bin`
- **Creator:** [WillowBoxArt](https://sketchfab.com/willowboxart)
- **Source:** <https://sketchfab.com/3d-models/stylized-garbage-bin-439e6a809caa4a9c80baa42f5d305f4f>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Placed at authored scale with a hashed yaw. One model
  now serves the airport, school and mall bins, which each used to be two
  cylinders in slightly different greys.
- **Local record:** [`models/cc_by/garbage_bin/SOURCE.md`](models/cc_by/garbage_bin/SOURCE.md)

#### `food_court_set.glb`

- **Title:** `Valley View Mall Food Court Dining Set`
- **Creator:** [Some Random Mall Modeller](https://sketchfab.com/NotUsingMyRealName)
- **Source:** <https://sketchfab.com/3d-models/valley-view-mall-food-court-dining-set-7259e5c692ac416690fc793dfddcda79>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled so the tabletop lands at 0.75 m — fitted on
  the working surface, not total height, since the chairs' spindle backs
  run 0.4 m above it. Textures re-encoded at 512 px.
- **Local record:** [`models/cc_by/food_court_set/SOURCE.md`](models/cc_by/food_court_set/SOURCE.md)

#### `cleaning_cart.glb`

- **Title:** `cleaning_cart`
- **Creator:** [ap-school](https://sketchfab.com/ap-school)
- **Source:** <https://sketchfab.com/3d-models/cleaning-cart-3a494d6aa0bf4f278a90041a41bc46b0>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Scaled to 1.24 m high, centred and floor-aligned in school
  corridors from measured imported bounds; supplied with conservative collision.
- **Local record:** [`models/cc_by/cleaning_cart/SOURCE.md`](models/cc_by/cleaning_cart/SOURCE.md)

#### `rope_barrier.glb`

- **Title:** `Rope Barrier`
- **Creator:** [MaX3Dd](https://sketchfab.com/MaX3Dd)
- **Source:** <https://sketchfab.com/3d-models/rope-barrier-72f49afbd0a2408690874f3bd8f9ef05>
- **License:** [Sketchfab Standard](https://sketchfab.com/licenses)
- **Modifications:** Scaled to a 1.02 m stanchion pair 1.891 m apart.
  Casino and cinema queue lines are laid out on that pitch rather than the
  unit being stretched to a chosen one. Only the posts collide.
- **Local record:** [`models/sketchfab/rope_barrier/SOURCE.md`](models/sketchfab/rope_barrier/SOURCE.md)

#### `checkin_desk.glb`

- **Title:** `Airport Check In Desk`
- **Creator:** [assetfactory](https://sketchfab.com/assetfactory)
- **Source:** <https://sketchfab.com/3d-models/airport-check-in-desk-d5efee1fedff4dfab4a89357b7bacb61>
- **License:** [Sketchfab Standard](https://sketchfab.com/licenses)
- **Modifications:** Authored in metres and used at 1:1. The source is a
  double-sided island 6.23 m deep; it is clipped to a single 3.20 m
  position, and a coincident collider proxy mesh that shipped with it is
  removed.
- **Local record:** [`models/sketchfab/checkin_desk/SOURCE.md`](models/sketchfab/checkin_desk/SOURCE.md)

## Public-domain and attribution-optional work

These sources do not require attribution, but are included for provenance and
to recognize the artists.

### `soulmate_jacuzzi.glb`

- **Title:** `Soulmate Jacuzzi`
- **Creator:** [NXTLVLPLY](https://sketchfab.com/NXTLVLPLY)
- **Source:** <https://sketchfab.com/3d-models/soulmate-jacuzzi-ae75ae3e7dd24652b008e95e8b4b93d5>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Embedded model retained as supplied; placement and scale are
  controlled by the Poolrooms scene.
- **Local record:** [`models/cc_by/soulmate_jacuzzi/SOURCE.md`](models/cc_by/soulmate_jacuzzi/SOURCE.md)

### `pool_lounge_chair.glb`

- **Title:** `Pool Lounge Chair`
- **Creator:** [CadmiumCoffee (bsishir)](https://sketchfab.com/bsishir)
- **Source:** <https://sketchfab.com/3d-models/pool-lounge-chair-2ab5992a50404cd6a7bc33ef346a7be4>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Embedded model retained as supplied; placement and scale are
  controlled by the Poolrooms scene.
- **Local record:** [`models/cc_by/pool_lounge_chair/SOURCE.md`](models/cc_by/pool_lounge_chair/SOURCE.md)

### `alarm.glb`

- **Title:** `Alarm`
- **Creator:** [JackFarrand](https://sketchfab.com/JackFarrand)
- **Source:** <https://sketchfab.com/3d-models/alarm-c9e3be8efe5e4b0da4e9526b71822441>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Embedded model retained as supplied; placement and scale are
  controlled by the scene.
- **Local record:** [`models/cc_by/alarm/SOURCE.md`](models/cc_by/alarm/SOURCE.md)

### `alarm_light.glb`

- **Title:** `Alarm Light`
- **Creator:** [5CNG5](https://sketchfab.com/5CNG5)
- **Source:** <https://sketchfab.com/3d-models/alarm-light-0e009c47066d4ab4b4329fdd4820f141>
- **License:** [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
- **Modifications:** Embedded model retained as supplied; runtime placement
  centres and wall-aligns the imported hierarchy and explicitly enables the
  red lamp material's emissive factor.
- **Local record:** [`models/cc_by/alarm_light/SOURCE.md`](models/cc_by/alarm_light/SOURCE.md)

### Poly Haven

- **Creator/source:** [Poly Haven](https://polyhaven.com)
- **License:** [CC0](https://creativecommons.org/publicdomain/zero/1.0/)
- **Use:** Furniture, fixtures and environmental props across the game;
  board-formed, structural and damaged-floor concrete PBR surfaces in the
  Monolith; and Pine Roots, wet mud, and wrinkled leather-derived tissue in
  the Bloom.
- **Per-asset inventory:** [`models/cc0/SOURCES.md`](models/cc0/SOURCES.md) and
  [`models/asylum/SOURCES.md`](models/asylum/SOURCES.md), plus
  [`textures/brutalist/SOURCES.md`](textures/brutalist/SOURCES.md),
  [`textures/bloom/SOURCES.md`](textures/bloom/SOURCES.md), and
  [`models/cc0/pine_roots/SOURCE.md`](models/cc0/pine_roots/SOURCE.md).
- **Modifications:** Imported at game-ready texture resolutions; individual
  props are scaled, rotated and selectively material-adjusted for their rooms.

### TextureCan

- **Creator/source:** [TextureCan](https://www.texturecan.com)
- **License:** [CC0 1.0](https://www.texturecan.com/terms/)
- **Use:** `Others 0001`, a seamless 2K organ/flesh PBR set, supplies color,
  OpenGL normal, roughness and ambient-occlusion detail for the Bloom's
  membranes, cysts, incubator sacs, vines and root shader.
- **Per-asset inventory:** [`textures/bloom/SOURCES.md`](textures/bloom/SOURCES.md)
- **Modifications:** Source maps are unchanged; runtime materials add triplanar
  projection, bruise tinting, wet clearcoat and animated vascular emission.

### ambientCG

- **Creator/source:** [ambientCG](https://ambientcg.com)
- **License:** [CC0](https://creativecommons.org/publicdomain/zero/1.0/)
- **Use:** Physically based architectural and environment surfaces.
- **Per-asset inventories:** [`textures/cc0/SOURCES.md`](textures/cc0/SOURCES.md),
  [`textures/asylum/SOURCES.md`](textures/asylum/SOURCES.md),
  [`textures/mall/SOURCES.md`](textures/mall/SOURCES.md) and
  [`textures/prison/SOURCES.md`](textures/prison/SOURCES.md).
- **Modifications:** Resolution reduction, channel packing where appropriate,
  tiling and material tuning for Godot.

### Office Chair

- **Title:** `Office Chair`
- **Creator:** nisu / 3DModelsCC0
- **Source:** <https://opengameart.org/content/office-chair-1>
- **License:** [CC0](https://creativecommons.org/publicdomain/zero/1.0/)
- **Modifications:** PBR maps rebound in Godot because the source FBX retained
  an unavailable authoring-time TIFF reference.

### Ghost figures

Every apparition is generated for this project with Magnific and carries no
third-party attribution requirement. Seven looping videos of dark hooded
figures on white were converted into 24-frame sprite sheets by
`tools/build_flipbook.py`; Godot 4's only video codec is Theora, which carries
no alpha, so an animated silhouette has to be a flipbook rather than a video.

The photo-traced Wikimedia silhouettes that were previously used here —
`man_bald.png` (Mette Aumala, CC0), `man_shirt.png` (Madeleine Price Ball,
CC0), `girl.png` (OpenClipart-Vectors, CC0) and `woman_walk.png` (Phil
Bronnery, CC BY 2.0) — were retired along with the still painted cutouts when
the roster became wholly animated. None of those files ship any more.

Per-sheet provenance and the conversion settings are recorded in
[`textures/ghosts/SOURCES.md`](textures/ghosts/SOURCES.md).

## Fonts

Font licenses and upstream links are recorded in
[`fonts/SOURCES.md`](fonts/SOURCES.md). In particular, Peter Hull's VT323
terminal typeface is distributed under the SIL Open Font License 1.1.

## Portal panoramas (`textures/portals/`)

- Author: Poly Haven contributors (https://polyhaven.com).
- Files: `abandoned_parking_2k.hdr`, `kloppenheim_06_puresky_2k.hdr`,
  `drackenstein_quarry_puresky_2k.hdr` — 360° equirectangular HDRIs.
- License: CC0.
- Use: sampled by view ray through the PORTAL anomaly's wall tear
  (`shaders/portal_glimpse.gdshader`), so the tear is a geometrically
  correct window into a photographed place. Per-file provenance in
  `textures/portals/SOURCE.md`.

## Shaders

### CRT post filter (`shaders/post.gdshader`)

- Author: @c64cosmin (godotshaders.com), combining pend00's
  "VHS and CRT monitor effect" (warp, vignette) and Timothy Lottes'
  Shadertoy scanline filter as ported by AHOPNESS
  (https://www.shadertoy.com/view/MsjXzh).
- Source: https://godotshaders.com (c64cosmin's combined CRT shader,
  supplied by the project owner 2026-08-16).
- License: CC0.
- Modifications: emulated grid defaulted to 720x320; the authored noise dial
  renamed `noise_level` with `noise_amount` reserved as the controller's
  runtime multiplier; `bright_boost` uniform added for
  PostProcessController's setup hook.

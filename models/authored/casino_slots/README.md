# Original casino slot machines

Four original Blender cabinets replace the two downloaded slot-machine models on the Level 1 casino floor. Every room retains its existing ten-machine layout, deterministic placement, stools, audio and bank lighting, with a room-seeded rotation through all four families.

| Model | Design | Triangles | Meshes / surfaces |
|---|---|---:|---:|
| slot_classic | Royal Sevens: chrome mechanical cabinet, arched topglass, lever | 2,620 | 5 |
| slot_wheel | Fortune Wheel: gold drum, art-deco fins, multicolor bonus wheel | 5,030 | 5 |
| slot_dual | Buffalo Sunset: two wide screens, sloping controls, RGB bezel | 3,056 | 4 |
| slot_triple | Sapphire Palace: three screens, slant touchscreen, RGB bezel | 3,430 | 4 |

Authored front is +Z; feet sit at Y=0. Cabinets fit within 0.94 m width and 0.86 m depth, with heights from 2.24–2.64 m. A simple box collider is bound to each furnishing group so doorway culling removes both together. Repeated cabinets reuse imported meshes and materials. Displays are opaque; bodies have closed front and rear volume. Height scales uniformly only for low ceilings.

Illustrated display textures are 1024×1024 at export; classic/wheel additionally use a 1024×2048 deterministic printed atlas. Metal/enamel use vertex colors. The shared casino_slot_lights shader preserves colored light guides and adds a slow per-cabinet attract pulse without new point lights. Displays and lamps are ambient prop decoration, not playable gambling interfaces.

## Sources and rebuild

Editable packed .blend files, original illustration images and front/rear renders: art/casino_slots/. The generated art and all original procedural ornament are authored for this project; reference photos are not embedded.

Run python3 tools/blender/draw_casino_slot_art.py to reproduce the printed wheel/paytable atlas, then Blender --background --factory-startup --python tools/blender/build_casino_slots.py. The committed illustrated source PNGs are consumed by that build. The Blender file contains the exported merged game geometry plus a non-exported camera/light studio.

Import via Godot --headless --editor --path . --quit. Validate with tools/audit_casino_slots.gd and tools/audit_slots.gd. Capture real casino lighting with tools/capture_casino_slots.gd, or individual front/rear comparison cases with tools/capture_procedural_props.gd -- --filter=vegas-slot --both-sides.

## Illustration provenance and prompts

Generated using the built-in image-generation tool on 2026-09-05. Full original images are saved in art/casino_slots/{classic,wheel,dual,triple}_illustrated.png and packed into the Blender sources. All four used this common brief: square flat slot-machine screen texture, two equal horizontal panels; upper illustrated jackpot marquee and lower reel screen; no cabinet, room, perspective, margins or watermarks; saturated, intricate commercial casino illustration with metallic lettering and original fictional branding.

### ROYAL SEVENS

Classic 1990s mechanical slot artwork, spectacular oversized ruby-red triple 7s with beveled gold edges, jewel encrusted royal crown, polished gold coins bursting around the crown, rich crimson damask and black enamel background, engraved gold flourishes. Lower panel THREE mechanical white reel strips showing detailed realistic cherries, golden bells, BAR symbols and crimson sevens, framed in chrome and gold. Title must read ROYAL SEVENS.

### FORTUNE WHEEL

Spectacular bonus-wheel jackpot game artwork, gleaming large gold FORTUNE WHEEL lettering over brilliant royal-blue electric starbursts, gold coin fountain, small multicolored radial wheel motif, lavish embossed golden ornament. Lower panel THREE mechanical white reels with large rich red and blue sevens, jeweled golden bells, metallic BAR symbols; deep royal blue payline surround, gold decoration. Title must read FORTUNE WHEEL.

### BUFFALO SUNSET

Spectacular high-end modern casino game. Magnificent photorealistically painted American bison head with rich detailed brown fur and horns, two smaller bison flanking it, orange-gold blazing sunset over a dramatic prairie, flying eagles and falling golden coins. Huge embossed red-and-gold BUFFALO SUNSET lettering. Lower panel FIVE by THREE reels filled with vividly illustrated bison, eagle, wolf, sunset icons plus gold-outlined J Q K A 10 in bright purple green and red, cream reel backgrounds and ornate gold framing. Title must read BUFFALO SUNSET.

### SAPPHIRE PALACE

Spectacular premium modern casino fantasy game, lavish royal queen portrait wearing sapphire crown, cut blue gemstones, brilliant silver and gold filigree, a distant nighttime palace, deep saturated sapphire and violet background, bright cyan sparkle. Oversized embossed jeweled gold SAPPHIRE PALACE lettering. Lower panel FIVE by THREE reels filled with jewel-encrusted crowns, blue gemstones, queens, golden chalices, plus gold outlined purple red green J Q K A 10, ivory reel backgrounds, lavish ornate gold borders. Title must read SAPPHIRE PALACE.

## Validation

- Godot import and script checks completed without errors.
- Authored asset audit: all four meshes share resources across repeated placements; 16 facing/ceiling combinations pass geometry, display-normal, collision and budget checks.
- Existing slot-room audit: 12 seeds, 83 rooms, 819 machines; no missing front or rear shells.
- Generated-room placement audit: 38 surviving cabinets across four rooms, all four families represented, no doorway obstruction.
- Front/rear Godot renders and a real casino bank with production lighting were visually inspected. The updated gallery contains 82 comparisons.

## Casino availability

Slot banks now appear in ordinary 12×12 rooms as well as large halls, across all three casino districts. Nearby non-corridor/non-landmark rooms within two lattice steps of the arrival lounge favor slots; the lounge and Descent arrival car remain clear. Slot layouts are exempt from the generic interior partitions that replace furnishing recipes.

Measured over 64 seeds and 23,872 non-corridor room anchors, slot-room share increased from 5.4% to 43.9%: gaming 63.1%, hotel 37.8%, convention 31.3%. The nearest slot room was 1–2 connected cell transitions from the origin across that matrix, and at most two from the eight sampled Descent arrivals. The distribution audit also builds nearby rooms to check actual cabinets and doorway clearance.

Validation: tools/audit_casino_distribution.gd, tools/audit_casino_slots.gd (138 rooms / 1,221 cabinets), tools/audit_zones.gd and tools/audit_descent_routes.gd.

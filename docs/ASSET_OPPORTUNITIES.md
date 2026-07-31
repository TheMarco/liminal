# Attributed asset opportunities

The project may use **CC0/public-domain**, **CC BY 2.0/3.0/4.0**,
**CC BY-NC 2.0/3.0/4.0**, and appropriately purchased royalty-free assets that
permit redistribution inside a game build. Attribution belongs both on the
in-game Credits screen and in `THIRD_PARTY_ASSETS.md`.

CC BY-NC assets must be explicitly identified in the canonical record and make
the containing build noncommercial. Do not import assets carrying **ND**,
editorial-only, personal-use-only, or unclear terms. Avoid recognizable
trademarks and branded art unless the license and intended use are unambiguous.
Every candidate still has to pass a visual-fit, scale, collision, performance,
and provenance review.

## Status

Of the 54 props that were assembled from primitives when this list was drawn
up, **27 now instance a model** — 162 of 309 primitive shapes retired. Sixteen
of those came from one batch: the alternate slot cabinet (42 primitives, the
single largest generated build in the game), the check-in position, bathroom
stalls, the janitor cart, the change machine, the visitation phone, the food
court set, the IV stand, queue barriers, sinks, the mall bench, the drinking
fountain, urinals in a bathroom that never had any, lockers, and one waste bin
now shared by the airport, school and mall.

Two models from that batch were measured and rejected rather than forced:

- **A jetway.** With its ground stand dropped the tunnel is still 18.8 × 3.2 ×
  4.0 m, and the gate apron is a deliberately sealed 2.14 m diorama strip.
  Anything wider shows through the neighbouring cell's walls — the bug
  `_air_docked_plane` documents — and fitting the depth leaves a 1.6 m jetway.
  A jetway can only work here if it is authored as a shallow façade.
- **A 4 ft overhead fixture.** It is 3.9:1, and five of the six ceiling runs
  need between 2.1:1 and 11.8:1. Worse, the lens has to stay a separate
  emissive quad in every case, because the flicker system drives that material
  and the model's own lens is baked — so the model would only ever contribute
  a frame around a quad five boxes already draw.

Largest remaining generated props, by primitive count: `_vt100` (10),
`_prison_shower_station` (10), `_asy_ect` (9),
`_sch_servery` (8), `_air_gate_desk` (7), `_asy_restraint_table` (7).

## Highest-value replacements by level

### Las Vegas hotel and casino

- One or two realistic cabinet families with authored LODs, used as occasional
  variants among the project's original procedural machines
- Casino-specific upholstered player chairs
- Credible table-game chip racks, card shoes and dealer equipment
- Hotel luggage carts, ice machines and service-room equipment

### Office

- Period-correct copier/printer variants
- Modular filing and records-storage systems
- Desk phones, fax machines and late-CRT-era peripherals
- Break-room appliances and commercial water coolers

### Annex

- No furniture replacements. The almost empty floor is intentional.
- A second period CCTV housing could be used as an extremely rare variant.

Annex wall art is limited to the Liminal Inc. guest-services poster set; the
remaining walls stay deliberately sparse and retain the rare camera motif.

### Airport

- Linked gate-seating systems
- Check-in kiosks, baggage scales and queue posts
- Baggage carts and maintenance tugs
- Security trays, scanners and inspection tables

Airport advertisements may reuse the mall advertisement pool.

### Insane asylum

- Institutional gurneys, examination beds and bedside cabinets
- Medical storage, privacy screens and vintage diagnostic equipment
- Period-correct wheelchairs and restraint hardware used sparingly

### School

- Teacher and student desk families with reliable forward orientation
- Trophy cases, lab storage, AV carts and library furniture
- Classroom-specific props that are always anchored to suitable furniture

### Abandoned shopping mall

- Retail racks, mannequins and abandoned point-of-sale hardware
- Shopping carts, directory kiosks and benches
- Food-court service equipment and trash/recycling stations
- Closed-store security gates and loading/service props

### Abandoned prison

- Wall-mounted steel bunks, combination toilet/sink units and cell shelves
- Visitation phones and complete phone-booth hardware
- Guard-station consoles, institutional tables and bolted seating
- Shower controls, heads, drains and laundry/service equipment

Cell furniture must remain cell-scoped; it is not general room dressing.

## Acquisition order

1. Fix obvious procedural stand-ins seen repeatedly at player eye level.
2. Replace silhouette-defining hero props.
3. Add secondary variants only where they improve plausibility.
4. Prefer coherent families over one-off high-detail models.
5. Audit each imported asset across many generated seeds before it ships.

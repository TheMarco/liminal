# Airport gate desk

Original Blender replacement for the former procedural gate podium, based on
the supplied white solid-surface counter reference. The sculpted passenger
fascia wraps into side returns above real closely spaced aluminium flutes.
The staff side has a recessed graphite worktop, two agent-facing displays,
keyboards, boarding readers, drawer cabinets and open shelf/knee bays.

2.44m wide, 1.16m deep; counter top 1.16m and monitors 1.418m high.
3,904 triangles, two shared surfaces, a baked 1K PBR atlas and a shared original
768 × 448 staff display. Godot generates LODs. No additional lights or particles.
Passenger front is -Z; agent-facing screens are +Z.

Runtime placement preserves the gate-lounge layout, shifts the counter 5cm
toward the glass, and retains the overhead gate/flight-status sign. Nine simple
colliders follow the fascia, side returns, worktop, cabinets and monitors, bound
to the desk as one atomic furnishing. Neither the mesh nor its colliders can
remain as orphan pieces if a doorway requires removal.

Sources: `art/airport_gate_desk/airport_gate_desk.blend` with packed textures.
Run `python3 tools/blender/draw_gate_desk_screen.py`, then Blender background mode
with `tools/blender/build_airport_gate_desk.py`. All geometry and screen graphics
are original; no reference-photo pixels or watermarks are embedded.

Checks: `tools/audit_airport_gate_desk.gd`, `tools/audit_authored_hero_meshes.py`,
airport collision and furnishing overlap audits. Gallery case:
`airport-gate-desk`; actual-room capture filter: `gate-desk`.

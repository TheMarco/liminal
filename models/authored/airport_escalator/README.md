# Airport Escalator

Original Blender model based on the user-supplied shape reference; no reference-image pixels used.

Single flight, X width, ascend +Z. Rise 2.25m, twelve treads. Existing walkable slope and mezzanine retained.

- Source: `art/airport_escalator/airport_escalator.blend`
- Builder: `tools/blender/build_escalator_trophy.py`
- Runtime: `airport_escalator.glb` with packed PBR textures
- Export: 4,600 triangles, 2 material surfaces
- Handrails use bounded corner fillets and welded cyclic rings to prevent spikes and open seams at both landings.
- Finite vertex attributes, triangle degeneracy and budgets checked by `tools/audit_authored_hero_meshes.py`.

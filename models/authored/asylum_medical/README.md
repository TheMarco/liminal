# Asylum medical props

Original low-poly Blender models authored from the supplied visual references.
`ect_machine.glb` is a wooden carrying-case ECT unit on a slim two-shelf trolley,
with a sloped analog fascia, Bakelite controls, rubber leads and cloth electrodes.
`restraint_table.glb` is an upholstered rolling gurney with leather restraints,
short chain runs and a hydraulic scissor undercarriage.

Units are metres, +Y up, +Z front, origin on the floor at the centre. The ECT
instrument face keeps its own original 1024×800 texture for close inspection;
the remaining surfaces share a baked 1K base-colour/normal/ORM atlas per model.
No text, scratches, grain or woven fabric are represented by dense geometry.
Exact measured triangles and bounds are in `mesh_stats.json`.

Editable packed Blender sources and front/reverse previews:
`art/asylum_medical/ect/` and `art/asylum_medical/restraint/`.
Rebuild: Blender --background --factory-startup --python tools/blender/build_asylum_medical.py
Optional `-- --filter=ect` or `-- --filter=restraint` rebuilds only one prop.

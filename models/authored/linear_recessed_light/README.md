# Recessed linear light fixture

Original low-poly Blender model based on the supplied product reference: a
1.22 × 0.19m olive-grey powder-coated recessed fixture with a mitered trim
flange, 0.11m sheet-steel housing with folded end plates, Phillips pan-head
screws and one empty fixing hole per end, and a recessed 1.166 × 0.136m
prismatic diffuser.

The origin is the ceiling plane. The trim hangs 12mm below Y=0, the housing
rises into the ceiling void above it, and the diffuser faces -Y, so the model
installs at `(x, ceiling_height, z)` with no rotation; its length runs along X.
The diffuser is its own `DiffuserLens` mesh (the same node name the office
troffer uses), so `material_override` can swap in a flicker or dead material.
Its default material is emissive at energy 2.4, matching `Mats.office_panel()`,
and its texture paints a twin-tube PL-L lamp showing through the lens: the gap
line between the legs, the U bridge at +X and the lampholder shadow at -X.

1,302 triangles, two meshes/surfaces: the body with an embedded 1K PBR atlas and
the diffuser with a 2048 × 256 emissive texture. Not yet placed by any level
builder.

Source: `art/linear_recessed_light/linear_recessed_light.blend`, the diffuser
texture and three studio renders. Rebuild with
`Blender -b --factory-startup -P tools/blender/build_linear_recessed_light.py`,
then `godot --headless --path . --import`. Validate with
`tools/audit_authored_hero_meshes.py`. No third-party mesh or photograph pixels
embedded.

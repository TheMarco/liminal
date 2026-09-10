# Bloom containment incubator

Original Blender machine based on the supplied industrial containment reference:
asymmetric armored spine, circular inspection hatch, external plumbing, captive
lid clamps, layered cylinder seals, console and original Lazarus Bio graphics.
A veined organic egg floats fully submerged in cloudy green preservation fluid.

6,346 triangles and six surfaces: baked opaque machinery, printed graphics,
glass, liquid, egg, bubbles. The 1K machinery PBR atlas, 512px membrane map and
shared graphics are packed into the GLB. Godot generates mesh LODs on import.
Overall bounds are 1.479 × 2.243 × 1.023m (X/Y/Z); room variants keep their scale.

`incubator_visual.gd` applies shared transparent materials to the named meshes.
Fluid clouds and rising bubbles use cheap shaders; no particle emitters, added
lights, per-bubble nodes or shadow-casting transparent shells. Only the egg
pulses around its center; the frame, glass and simple collider stay rigid.

Source: `art/bloom_incubator/bloom_incubator.blend`, packed textures and studio
renders. Rebuild labels with `python3 tools/blender/draw_hero_labels.py`, then
run Blender in background with `tools/blender/build_bloom_incubator.py`.
Validate with `tools/audit_authored_hero_meshes.py`, `audit_authored_hero_props.gd`
and `audit_bloom.gd`. No third-party mesh or photograph pixels embedded.

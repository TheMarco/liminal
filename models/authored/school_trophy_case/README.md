# School Trophy Case

Original Blender model based on the user-supplied shape reference; no reference-image pixels used.

Back at Z=0, faces +Z, floor origin. Glass and display lamps remain separate surfaces. No bathroom placement.

- Source: `art/school_trophy_case/school_trophy_case.blend`
- Builder: `tools/blender/build_escalator_trophy.py -- --trophy`
- Runtime: `school_trophy_case.glb` with packed PBR textures
- Export: 4,964 triangles, 3 material surfaces
- Finite vertex attributes, triangle degeneracy and budgets checked by `tools/audit_authored_hero_meshes.py`.

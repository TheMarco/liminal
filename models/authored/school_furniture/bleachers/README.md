# School Bleachers

Original Blender model based on the user-supplied shape reference; no reference-image pixels used.

Four-tier 4m section, front +Z, rear Z=-2.5. Runtime tiles sections with slight X adjustment to room width.

- Source: `art/school_furniture/bleachers/school_bleachers.blend`
- Builder: `tools/blender/build_school_furniture.py`
- Runtime: `school_bleachers.glb` with packed PBR textures
- Export: 2,656 triangles, 1 material surfaces
- Finite vertex attributes, triangle degeneracy and budgets checked by `tools/audit_authored_hero_meshes.py`.

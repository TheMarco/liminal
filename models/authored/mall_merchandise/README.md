# ZEON merchandise furniture

Original Blender-authored retail furniture inspired by the supplied checkout/display reference. Both variants use pale ash cabinets, warm illuminated fascia, open shelving and shaped folded garments with tucked sleeves, layered fabric edges and collars. No reference image pixels are used.

- `mall_merchandise_station.glb`: 2.80 m wide × 1.72 m deep × 1.85 m tall. U-shaped, open rear staff entrance and open interior well; working counter 1.15 m high; original ZEON branding and POS facing -X into the staff well.
- `mall_merchandise_display.glb`: 2.20 m wide × 0.90 m deep × 1.04 m tall. Double-sided three-tier merchandise shelving, no high brand panel or POS.

Coordinates: metres, Y up, +Z customer/front. Origin floor centre. Mesh statistics and exact bounds are in `mesh_stats.json`. Static furniture meshes carry no generated colliders: runtime should use the existing furnishing footprint or three U-shaped boxes when staff access is needed. All parts in each opaque variant share one baked 1K PBR atlas; fascia uses one emissive surface and the large station one shared artwork surface.

Rebuild with `/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/build_mall_merchandise.py`. Optional final argument `-- station` or `-- display` rebuilds one variant. Editable packed Blender files, original atlas maps and front/reverse review renders live under `art/mall_merchandise/`.

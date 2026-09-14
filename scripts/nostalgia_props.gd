extends RefCounted
## Reference-authored period fixtures; all floor units are placed against the
## finalized room geometry, with their operating space kept clear.
const IDS := [
    "mall_photo_booth", "mall_rocket_ride", "vegas_ice_machine",
    "vegas_bellhop_cart", "vegas_cigarette_machine", "office_coffee_machine",
    "school_overhead_projector",
]
const THEMES := [7, 7, 0, 0, 0, 1, 6]
# Envelopes include trim, projecting controls and the caster footprint.
const BOUNDS := [
    AABB(Vector3(-.731, 0, -.480), Vector3(1.462, 2.054, .980)),
    AABB(Vector3(-.587, 0, -.736), Vector3(1.174, 1.458, 1.472)),
    AABB(Vector3(-.40, 0, -.36), Vector3(.80, 1.96, .74)),
    AABB(Vector3(-.62, 0, -.41), Vector3(1.24, 1.94, .82)),
    AABB(Vector3(-.465, 0, -.311), Vector3(.93, 1.813, .741)),
    AABB(Vector3(-.473, 0, -.302), Vector3(.946, 1.835, .688)),
    AABB(Vector3(-.207, 0, -.226), Vector3(.498, .766, .472)),
]

static func path_for(id: int) -> String:
    return "res://models/authored/%s/%s.glb" % [IDS[id], IDS[id]]

static func paths(theme := -1) -> Array[String]:
    var result: Array[String] = []
    for i in IDS.size():
        if theme < 0 or THEMES[i] == theme:
            result.append(path_for(i))
    return result

static func add(scene: ChunkSceneWriter, id: int, at: Vector3, yaw: float) -> Node3D:
    var first := scene.collider_mark()
    var pivot := scene.attributed_floor_prop(path_for(id), at, yaw, 1.0,
        Vector3.ZERO, IDS[id], null, true)
    if pivot == null:
        return null
    pivot.set_meta("nostalgia_prop", id)
    var box: AABB = BOUNDS[id]
    if id == 0:
        # Keep the photo-booth opening enterable; the curtain is fabric, not a wall.
        for piece in [
            AABB(Vector3(-.731, 0, -.480), Vector3(.38, 2.054, .960)),
            AABB(Vector3(.681, 0, -.480), Vector3(.05, 2.054, .960)),
            AABB(Vector3(-.351, 0, -.480), Vector3(1.032, 2.054, .05)),
            AABB(Vector3(-.725, 0, -.47), Vector3(1.45, .078, .94)),
            AABB(Vector3(.15, .49, -.42), Vector3(.48, .08, .38)),
        ]:
            scene.collider_yaw_box(at + piece.get_center().rotated(Vector3.UP, yaw),
                piece.size, yaw)
    else:
        scene.collider_yaw_box(at + box.get_center().rotated(Vector3.UP, yaw), box.size, yaw)
    scene.bind_furnishing_colliders(pivot, first)
    return pivot

static func candidates(chunk) -> Array[int]:
    var result: Array[int] = []
    match chunk.theme:
        0:
            if not chunk.casino_landmark.is_empty():
                return result
            if chunk.style in [WorldGen.STYLE_HALLWAY, WorldGen.STYLE_EMPTY]:
                result.append(2)
                if chunk._r(9051) < .60: result.append(3)
            elif chunk.style in [WorldGen.STYLE_LOUNGE, WorldGen.STYLE_GRAND]:
                result.append(4)
                if chunk.style == WorldGen.STYLE_GRAND: result.append(3)
        1:
            if chunk.style == WorldGen.OFFICE_BREAK: result.append(5)
        7:
            if chunk.style in [WorldGen.MALL_CINEMA, WorldGen.MALL_KIOSKS, WorldGen.MALL_ATRIUM]:
                result.append(0)
            if chunk.style in [WorldGen.MALL_FOODCOURT, WorldGen.MALL_ATRIUM]:
                result.append(1)
    return result

static func dress(chunk) -> void:
    if not chunk.is_room_anchor or chunk.descent_target or chunk.descent_arrival or chunk.portal_dest >= 0:
        return
    for id in candidates(chunk):
        var site := find_site(chunk, id)
        if not site.is_empty():
            add(chunk._scene_writer, id, site.at, site.yaw)

static func find_site(chunk, id: int) -> Dictionary:
    if id in [4, 5]:
        return machine_site(chunk, BOUNDS[id])
    var geometry := ChargingStationPlacement.new(chunk)
    var doors: Array[Rect2] = chunk._doorway_clearance_rects()
    var box: AABB = BOUNDS[id].grow(.035)
    box.size.y -= .095
    box.position.y = .06
    var approach := AABB(Vector3(box.position.x, .06, box.end.z),
        Vector3(box.size.x, minf(1.8, box.size.y), .90))
    if id in [0, 2]:
        return wall_site(chunk, geometry, doors, box, approach)
    var inset: float = .34 - box.position.z
    var start: int = posmod(WorldGen.h(chunk.wseed, chunk.cell.x, chunk.cell.y, 9020 + id), 4)
    # Try different walls per fixture, rather than always stacking the first corner.
    for offset in 4:
        var dir: int = (start + offset) % 4
        var yaw: float = chunk._wall_facing(dir)
        for step in range(3, 22):
            var along: float = 1.5 + float((step - 3 + id * 4) % 19) * .5
            var at: Vector3 = chunk._wall_pt(dir, along, inset, 0.0)
            if geometry.clear(at, yaw, false, doors, box, approach):
                return {"at":at, "yaw":yaw}
    # Large mall rooms can use a clear island beside existing attractions.
    if id in [1, 3]:
        for x in range(2, 11):
            for z in range(2, 11):
                for turn in 4:
                    var at := Vector3(x, 0, z)
                    var yaw: float = float((start + turn) % 4) * PI * .5
                    if geometry.clear(at, yaw, false, doors, box, approach):
                        return {"at":at, "yaw":yaw}
    return {}

## Cabinets have a +Z customer-facing front. Keep their actual rear against
## structural geometry, not a nominal cell edge which may be an open doorway.
static func machine_clearance_bounds(bounds: AABB) -> AABB:
    var box := bounds.grow(.035)
    # Side/front clearance is useful, but rear padding would force an air gap.
    box.size.z -= .035
    box.position.z = bounds.position.z
    box.size.y -= .095
    box.position.y = .06
    return box

static func machine_site(chunk, bounds: AABB) -> Dictionary:
    var box := machine_clearance_bounds(bounds)
    var approach := AABB(Vector3(box.position.x, .06, box.end.z),
        Vector3(box.size.x, minf(1.8, box.size.y), .90))
    # Casino skirting projects 5.55cm; office walls have no baseboard.
    var rear_gap := .057 if chunk.theme == 0 else .002
    return wall_site(chunk, ChargingStationPlacement.new(chunk),
        chunk._doorway_clearance_rects(), box, approach, rear_gap, 0.0)

# Explicit architectural tags prevent cabinets, glass storefronts, doors and
# tall furniture from being mistaken for a wall. Door headers fail the height test.
static func backing_walls(chunk) -> Array[AABB]:
    var walls: Array[AABB] = []
    for node in chunk.find_children("*", "MeshInstance3D", true, false):
        if not node.get_meta("fixture_backing_wall", false): continue
        var xf := Transform3D.IDENTITY
        var current: Node3D = node
        while current != chunk:
            xf = current.transform * xf
            current = current.get_parent()
        walls.append(xf * node.mesh.get_aabb())
    return walls

static func wall_site(chunk, geometry: ChargingStationPlacement, doors: Array[Rect2],
        box: AABB, approach: AABB, rear_gap := .09, cell_inset := .30) -> Dictionary:
    for wall in backing_walls(chunk):
        if wall.position.y > .06 or wall.end.y < box.end.y: continue
        var thin_x := wall.size.x < wall.size.z
        var lo: float = wall.position.z if thin_x else wall.position.x
        var hi: float = wall.end.z if thin_x else wall.end.x
        var half_width := box.size.x * .5
        if hi - lo < box.size.x + .10: continue
        for side in [-1.0, 1.0]:
            var normal := Vector3(side, 0, 0) if thin_x else Vector3(0, 0, side)
            var face: float = (wall.end.x if side > 0 else wall.position.x) if thin_x else (wall.end.z if side > 0 else wall.position.z)
            var yaw := atan2(normal.x, normal.z)
            var along := lo + half_width + .05
            while along <= hi - half_width - .05:
                var at := Vector3(face, 0, along) if thin_x else Vector3(along, 0, face)
                # Clear baseboards/trim, while keeping the rear close to the wall.
                at += normal * (rear_gap - box.position.z)
                if cell_inset > 0.0:
                    if thin_x: at.x = clampf(at.x, cell_inset - box.position.z, WorldGen.CELL_SIZE - cell_inset + box.position.z)
                    else: at.z = clampf(at.z, cell_inset - box.position.z, WorldGen.CELL_SIZE - cell_inset + box.position.z)
                if geometry.clear(at, yaw, false, doors, box, approach, cell_inset):
                    return {"at": at, "yaw": yaw}
                along += .25
    return {}

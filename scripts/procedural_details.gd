class_name ProceduralDetails
extends RefCounted
## Small, static construction details, baked once per design into one mesh per
## material. Never traverses imported models or changes physics/interaction.
## Cache keys must include every parameter affecting geometry and materials.

static var _cache: Dictionary = {}
## Finite structural modules survive eviction of dimension-specific dressing.
static var _floor_templates: Dictionary = {}
const MAX_CACHED_DESIGNS := 192
var _parts: Array[Dictionary] = []


static func attach(parent: Node3D, key: String, builder: Callable,
		floor_template := false) -> void:
	for entry in _design(key, builder, floor_template):
		var instance := MeshInstance3D.new()
		instance.mesh = entry.mesh
		instance.material_override = entry.material
		instance.set_meta("procedural_detail", key)
		parent.add_child(instance)


## Repeated panel/hanger modules retain one draw per material, not per part.
static func attach_instances(parent: Node3D, key: String, builder: Callable,
		transforms: Array[Transform3D]) -> void:
	for entry in _design(key, builder, true):
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = entry.mesh
		multi.instance_count = transforms.size()
		for i in transforms.size(): multi.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = entry.material
		instance.set_meta("procedural_detail", key)
		parent.add_child(instance)


static func _design(key: String, builder: Callable, floor_template: bool) -> Array:
	var cache := _floor_templates if floor_template else _cache
	if not cache.has(key):
		var detail := ProceduralDetails.new()
		builder.call(detail)
		if not floor_template and cache.size() >= MAX_CACHED_DESIGNS:
			cache.erase(cache.keys()[0])
		cache[key] = detail._bake()
	return cache[key]


static func clear_runtime_cache() -> void:
	_cache.clear()
	_floor_templates.clear()


func box(pos: Vector3, size: Vector3, material: Material,
		bevel := 0.0, rotation := Vector3.ZERO) -> void:
	var mesh: Mesh
	if bevel > 0.0:
		mesh = RoundedBox.mesh(size, bevel)
	else:
		var primitive := BoxMesh.new()
		primitive.size = size
		mesh = primitive
	_add(mesh, Transform3D(Basis.from_euler(rotation), pos), material)


func tube(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var direction := b - a
	if direction.length_squared() < 0.0000001:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = direction.length()
	mesh.radial_segments = 12
	mesh.rings = 1
	_add(mesh, Transform3D(Basis(Quaternion(Vector3.UP,
		direction.normalized())), (a + b) * 0.5), material)


## A flat annulus or narrow round-section ring. Axis is the ring normal.
func ring(pos: Vector3, radius: float, thickness: float,
		material: Material, axis := Vector3.UP) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(0.001, radius - thickness)
	mesh.outer_radius = radius + thickness
	mesh.rings = 24
	mesh.ring_segments = 6
	_add(mesh, Transform3D(Basis(Quaternion(Vector3.UP,
		axis.normalized())), pos), material)


func _add(mesh: Mesh, transform: Transform3D, material: Material) -> void:
	_parts.append({"mesh": mesh, "transform": transform, "material": material})


func _bake() -> Array[Dictionary]:
	var buckets: Dictionary = {}
	for part in _parts:
		var material: Material = part.material
		if not buckets.has(material):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			buckets[material] = surface
		var surface: SurfaceTool = buckets[material]
		surface.append_from(part.mesh, 0, part.transform)
	var output: Array[Dictionary] = []
	for material in buckets:
		var surface: SurfaceTool = buckets[material]
		output.append({"mesh": surface.commit(), "material": material})
	return output

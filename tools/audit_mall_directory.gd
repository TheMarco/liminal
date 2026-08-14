extends SceneTree
## Focused regression for the freestanding directory's mirrored header.

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	failures += 1


func _run() -> void:
	var chunk := Chunk.new(WorldGen.level_seed(4242, 7), Vector2i.ZERO, 7)
	var builder: Object = chunk._level_builder
	if builder == null or not builder.has_method("_mall_directory_pylon"):
		_fail("mall builder lacks its directory recipe")
	else:
		builder.call("_mall_directory_pylon", Vector3(6.0, 0.0, 6.0), 0.0)
	var labels: Array[Node] = []
	var listings: Array[Node] = []
	for node in chunk.find_children("*", "Label3D", true, false):
		if node.has_meta("mall_directory_label"):
			labels.append(node)
		if node.has_meta("mall_directory_listing"):
			listings.append(node)
	if labels.is_empty():
		_fail("directory did not create an identified header")
	for node in labels:
		var label := node as Label3D
		if label.text != "DIRECTORY":
			_fail("directory header copy changed")
		if label.double_sided:
			_fail("directory header still exposes mirrored back-face text")
		if absf(absf(label.rotation.y) - PI) > 0.001:
			_fail("directory header does not face the authored local -Z panel")
	if listings.size() != labels.size() * 5:
		_fail("directory reverse is missing its five readable floor rows")
	for node in listings:
		var listing := node as Label3D
		if listing.double_sided \
				or absf(absf(listing.rotation.y) - PI) > 0.001:
			_fail("directory reverse row exposes mirrored text")
			break
	var report := chunk.mall_fixture_audit()
	if int(report.get("violations", 0)) != 0:
		_fail("directory violates the mall fixture contract")
	chunk.free()
	if failures == 0:
		print("mall directory audit pass")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(1 if failures > 0 else 0)

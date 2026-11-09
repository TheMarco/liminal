class_name LocalizedArt
extends RefCounted
## Authored images keep their art direction. Looking at their readable face
## exposes the complete translated inscription at window resolution.

static var _texts: Dictionary = {}

static func inscription(path: String) -> String:
	if _texts.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/art_text.json"))
		if parsed is Dictionary: _texts = parsed
	return str(_texts.get(path.get_file().get_basename(), ""))

static func mark(node: Node3D, source: String, at := Vector3.ZERO, normal := Vector3.BACK) -> void:
	if source.is_empty(): return
	var face := Marker3D.new()
	face.name = "LocalizedInscription"
	face.position = at
	face.set_meta("inscription", source)
	face.set_meta("face_normal", normal)
	face.add_to_group("localized_inscriptions")
	node.add_child(face)

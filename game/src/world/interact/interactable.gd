class_name Interactable
extends Node3D
## Base for everything the player can use. Subclasses override get_prompt / interact.

@export var prompt := "Utiliser"
@export var interact_range := 2.2
var enabled := true


func _ready() -> void:
	add_to_group("interactable")
	_build()


func _build() -> void:
	pass


func can_interact(_p: Node) -> bool:
	return enabled


func get_prompt(_p: Node) -> String:
	return prompt


func interact(_p: Node) -> void:
	pass


static func box_mesh(size: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Mats.toon(color, emission)
	return mi


static func static_box(parent: Node3D, size: Vector3, pos := Vector3.ZERO, surface := "metal") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = Combat.LAYER_WORLD
	b.collision_mask = 0
	b.set_meta("surface", surface)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	b.position = pos
	parent.add_child(b)
	return b

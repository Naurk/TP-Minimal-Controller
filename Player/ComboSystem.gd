extends Node

onready var combomod = 0
onready var combo = 0
onready var CanHit = false
onready var hit = 0
var next_anim

func _ready():
	pass 
	
func begin_combo_window():
	combomod = 1 
	print("enter combo")
	get_parent().IsAttacking = true
	
func end_combo_window():
	print("end combo window:::", combo, combomod)
	if combo > 1:
		##!!THIS IS JUST AN EXAMPLE, if you want a 2 hit combo cycle!!##
		if next_anim == "great sword slash 3":
			combo = 1
			
		combo_blend()
	combomod = 0
	combo = 0
	get_parent().IsAttacking = false
	
	
func combo_blend():
	var animation_tree = get_parent().animation_tree
	animation_tree.set("parameters/combo_hit1/active", true)
	animation_tree.set("parameters/step_seek/seek_position", 0)
	animation_tree.set("parameters/up_seek/seek_position", 0)
	if combo == 1:
		var anim_tree_root = animation_tree.get_tree_root()
		var anim_node1 = anim_tree_root.get_node("up_attack")
		var step_anim = anim_tree_root.get_node("step_attack")
		next_anim = "great sword slash"
		anim_node1.set_animation(next_anim)
		step_anim.set_animation("step_R")
		return
	if combo == 2:
		print("HIT 2 begin")
		var anim_tree_root = animation_tree.get_tree_root()
		var anim_node1 = anim_tree_root.get_node("up_attack")
		var step_anim = anim_tree_root.get_node("step_attack")
		next_anim = "great sword slash 3"
		anim_node1.set_animation(next_anim)
		step_anim.set_animation("step_L3")
		return
	else:
		pass

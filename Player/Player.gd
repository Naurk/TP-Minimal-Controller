extends KinematicBody

const CAMERA_MOUSE_ROTATION_SPEED = 0.001
const CAMERA_CONTROLLER_ROTATION_SPEED = 3.0
const CAMERA_X_ROT_MIN = -70
const CAMERA_X_ROT_MAX = 40

const DIRECTION_INTERPOLATE_SPEED = 1
const MOTION_INTERPOLATE_SPEED = 10
const ROTATION_INTERPOLATE_SPEED = 10

const MIN_AIRBORNE_TIME = 0.5
var airborne_time = 100

var orientation = Transform()
var root_motion = Transform()
var motion = Vector2()
var velocity = Vector3()
var camera_x_rot = 0.0
var roll_quat = Quat()
onready var null_state = false

onready var current_weapon = 0
onready var initial_position = transform.origin
onready var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * ProjectSettings.get_setting("physics/3d/default_gravity_vector")

onready var animation_tree = $AnimationTree2
onready var player_model = $PlayerModel2
onready var camera_base = $CameraBase
onready var camera_rot = camera_base.get_node(@"CameraRot")
onready var camera_spring_arm = camera_rot.get_node(@"SpringArm")
onready var camera_camera = camera_spring_arm.get_node(@"Camera")

## Actions variables
var IsAttacking
var IsRolling

func _init():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _ready():
	# Pre-initialize orientation transform.
	orientation = player_model.global_transform
	orientation.origin = Vector3()
	
func _input(event):
	if event is InputEventMouseMotion:
		var camera_speed_this_frame = CAMERA_MOUSE_ROTATION_SPEED
		rotate_camera(event.relative * camera_speed_this_frame)
	if !animation_tree.get("parameters/roll/active"):
		#!!!ROLL SYSTEM!!! 
		if event.is_action_pressed("sprint"): 
			if $roll_window.is_stopped():
				$roll_window.start()
		if event.is_action_released("sprint"):
			if !$roll_window.is_stopped() and !animation_tree.get("parameters/sheath_r/active") and !animation_tree.get("parameters/draw_r/active"): #and is_on_floor()
				$roll_window.stop()
				animation_tree.set("parameters/roll/active", true)
				var camera_basis = camera_rot.global_transform.basis
				var camera_z = camera_basis.z
				var camera_x = camera_basis.x
				var target = camera_x * motion.x + Vector3(camera_z[0],0,camera_z[2]) * motion.y
				var q_to = Transform().looking_at(target, Vector3.UP).basis.get_rotation_quat()
				roll_quat = q_to
				return roll_quat 
				
#func null_state_ON():
#	null_state = true
	
#func null_state_OFF():
#	null_state = false
	
func CanHit_ON():
	get_node("PlayerModel2/Armature/Skeleton/right_hand/position_in_hand").get_child(0).get_child(0).trailEnabled = true
func CanHit_OFF():
	get_node("PlayerModel2/Armature/Skeleton/right_hand/position_in_hand").get_child(0).get_child(0).trailEnabled = false
	

func reparent(child: Node, new_parent: Node):
	var old_parent = child.get_parent()
	old_parent.remove_child(child)
	new_parent.add_child(child)
	
func sheat_stick():
	reparent(get_node("PlayerModel2/Armature/Skeleton/right_hand/position_in_hand").get_child(0), get_node("PlayerModel2/Armature/Skeleton/spine_sheat/position_back_sheat"))
	
	
func check_weapon_stance(delta):
	if current_weapon == 1:
		$PlayerModel2/Armature/Skeleton/lefthand_IK.start(false)
		animation_tree.set("parameters/stance/blend_amount", 1)
		if $PlayerModel2/Armature/Skeleton/lefthand_IK.get_interpolation() != 1:
			$PlayerModel2/Armature/Skeleton/lefthand_IK.set_interpolation(lerp($PlayerModel2/Armature/Skeleton/lefthand_IK.get_interpolation(), 1, delta))
	if current_weapon == 0:
		animation_tree.set("parameters/stance/blend_amount", 0)
		if $PlayerModel2/Armature/Skeleton/lefthand_IK.get_interpolation() != 0:
			$PlayerModel2/Armature/Skeleton/lefthand_IK.set_interpolation(lerp($PlayerModel2/Armature/Skeleton/lefthand_IK.get_interpolation(), 0, delta * 6))
		else:
			$PlayerModel2/Armature/Skeleton/lefthand_IK.stop()
			
func _physics_process(delta):
	#IsAttacking = animation_tree.get("parameters/combo_hit1/active")
	IsRolling = animation_tree.get("parameters/roll/active")
	###__________CAMERA SYSTEM____________###
	var camera_move = Vector2(
			Input.get_action_strength("view_right") - Input.get_action_strength("view_left"),
			Input.get_action_strength("view_down") - Input.get_action_strength("view_up"))
	var camera_speed_this_frame = delta * CAMERA_CONTROLLER_ROTATION_SPEED
	rotate_camera(camera_move * camera_speed_this_frame)
	var motion_target = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward"))
	motion = motion.linear_interpolate(motion_target, MOTION_INTERPOLATE_SPEED * delta)
	
	var camera_basis = camera_rot.global_transform.basis
	var camera_z = camera_basis.z
	var camera_x = camera_basis.x
	
	camera_z.y = 0
	camera_z = camera_z.normalized()
	camera_x.y = 0
	camera_x = camera_x.normalized()
	
	# Jump/in-air logic.
	airborne_time += delta
	if is_on_floor():
		if airborne_time > 0.5:
			animation_tree.set("parameters/landing/active", true)
		airborne_time = 0	
	var on_air = airborne_time > MIN_AIRBORNE_TIME
	#JUMP? TODO
	if not on_air and animation_tree.get("parameters/dash/blend_amount") >= 1 and Input.is_action_just_pressed("jump"):
		velocity.y = 5
		on_air = true
		animation_tree["parameters/state/current"] = 2
		animation_tree.set("parameters/jump/active", true)
	if on_air:
		animation_tree["parameters/state/current"] = 2
		
	#ATTACK INPUT#
	elif Input.is_action_just_pressed("light_attack") and current_weapon == 1 and !IsRolling and !animation_tree.get("draw_r"):
		#LightAttack = true
		#HeavyAttack = false
		if $ComboSystem.combomod == 0 and $ComboSystem.combo == 0  and !animation_tree.get("parameters/combo_hit1/active"):#!IsAttacking:
			$ComboSystem.combo = 1
			print("BEGIN ATTACK")
			$ComboSystem.combo_blend()
			return $ComboSystem.combo
		elif $ComboSystem.combomod == 1: 
			$ComboSystem.combo = 2
			print("BUTTON PRESSED in combowindow:::::", $ComboSystem.combo)
			return $ComboSystem.combo
		else:
			$ComboSystem.combo = 0
			return $ComboSystem.combo
				
	elif IsAttacking:
		animation_tree.set("parameters/ls_dash/blend_amount", lerp(animation_tree.get("parameters/ls_dash/blend_amount"), 0, delta * 3))
		animation_tree.set("parameters/blocking/blend_amount", 0)
		animation_tree.set("parameters/walk/blend_position", 0)
		animation_tree.set("parameters/strafe/blend_position", Vector2(0, 0))
		animation_tree.set("parameters/dash/blend_amount", 0)
		root_motion = animation_tree.get_root_motion_transform()
		orientation *= root_motion
		
	elif IsRolling:
		animation_tree.set("parameters/ls_dash/blend_amount", lerp(animation_tree.get("parameters/ls_dash/blend_amount"), 0, delta * 3))
		animation_tree.set("parameters/blocking/blend_amount", 0)
		animation_tree.set("parameters/walk/blend_position", 0)
		animation_tree.set("parameters/strafe/blend_position", Vector2(0, 0))
		animation_tree.set("parameters/dash/blend_amount", 0)
		animation_tree.set("parameters/stance/blend_amount", 0)
		orientation.basis = Basis(roll_quat)
		root_motion = animation_tree.get_root_motion_transform()
		orientation *= root_motion
		
	#CHANGE WEAPON#
	elif Input.is_action_just_released("change_weapon")  and !animation_tree.get("parameters/roll/active") and animation_tree.get("parameters/blocking/blend_amount") != 1:
		if !animation_tree.get("parameters/sheath_r/active") and !animation_tree.get("parameters/draw_r/active"):
			if current_weapon == 0:
				animation_tree.set("parameters/draw_r/active", true)
				reparent(get_node("PlayerModel2/Armature/Skeleton/spine_sheat/position_back_sheat").get_child(0), get_node("PlayerModel2/Armature/Skeleton/right_hand/position_in_hand"))
				current_weapon = 1
			else:
				animation_tree.set("parameters/sheath_r/active", true)
				current_weapon = 0
				animation_tree.set("parameters/ls_dash/blend_amount", lerp(animation_tree.get("parameters/ls_dash/blend_amount"), 0, delta * 3))
	
		
	#AIMING STATE#
	elif Input.is_action_pressed("aim"):
		animation_tree["parameters/state/current"] = 1
		animation_tree.set("parameters/rotate/add_amount", 0)
		animation_tree.set("parameters/dash/blend_amount", 0)
		animation_tree.set("parameters/ls_dash/blend_amount", 0)
		
		var q_from = orientation.basis.get_rotation_quat()
		var q_to = camera_base.global_transform.basis.get_rotation_quat()
		orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))
		animation_tree.set("parameters/strafe/blend_position", Vector2(-motion.x, -motion.y).normalized())
		root_motion = animation_tree.get_root_motion_transform()
		orientation *= root_motion
		if motion.length() <= 0.2:
			animation_tree.set("parameters/rotate/add_amount", (camera_move[0]))
		
		if Input.is_action_pressed("sprint"):
			animation_tree.set("parameters/strafe/blend_position", (Vector2(-motion.x, -motion.y)*2.5))
		else:
			animation_tree.set("parameters/strafe/blend_position", lerp(Vector2(-motion.x, -motion.y), animation_tree.get("parameters/strafe/blend_position"), 0.01))#lerp(animation_tree.get("parameters/strafe/blend_position"), 0, 0.5))
		if current_weapon == 1:
			if Input.is_action_pressed('block'):
				animation_tree.set("parameters/blocking/blend_amount", lerp(animation_tree.get("parameters/blocking/blend_amount"), 1, delta * 6))
			else:
				animation_tree.set("parameters/blocking/blend_amount", lerp(animation_tree.get("parameters/blocking/blend_amount"), 0, delta * 6))
		
		
	else:
	# WALKING STATE#
	# Convert orientation to quaternions for interpolating rotation.
		var target = camera_x * motion.x + camera_z * motion.y
		if target.length() > 0.2:
			var q_from = orientation.basis.get_rotation_quat()
			var q_to = Transform().looking_at(target, Vector3.UP).basis.get_rotation_quat()
		# Interpolate current rotation with desired one.
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))
		animation_tree["parameters/state/current"] = 0
		animation_tree["parameters/walk/blend_position"] = motion.length()#Vector2(motion.length(), 0)
		root_motion = animation_tree.get_root_motion_transform()
	# Apply root motion to orientation.
		orientation *= root_motion
		
		#SPRINT and STANCE (animation) INTERPOLATION#
		if animation_tree.get("parameters/walk/blend_position") > 0.5 and Input.is_action_pressed("sprint"):
			animation_tree.set("parameters/dash/blend_amount", lerp(animation_tree.get("parameters/dash/blend_amount"), 1.5, delta * 2))
		else:
			animation_tree.set("parameters/ls_dash/blend_amount", lerp(animation_tree.get("parameters/ls_dash/blend_amount"), 0, delta * 3))
			animation_tree.set("parameters/dash/blend_amount", lerp(animation_tree.get("parameters/dash/blend_amount"), 0, delta * 2))#motion.length()))
		if current_weapon == 1:
			if animation_tree.get("parameters/walk/blend_position") > 0.5 and Input.is_action_pressed("sprint"):
				animation_tree.set("parameters/ls_dash/blend_amount", lerp(animation_tree.get("parameters/ls_dash/blend_amount"), 2, delta * 3))
			if Input.is_action_pressed('block'):
				animation_tree.set("parameters/blocking/blend_amount", lerp(animation_tree.get("parameters/blocking/blend_amount"), 1, delta * 6))
			else:
				animation_tree.set("parameters/blocking/blend_amount", lerp(animation_tree.get("parameters/blocking/blend_amount"), 0, delta * 6))
				animation_tree.set("parameters/ls_dash/blend_amount", lerp(animation_tree.get("parameters/ls_dash/blend_amount"), 0, delta * 3))
			

	var h_velocity = orientation.origin / delta
	velocity.x = h_velocity.x
	velocity.z = h_velocity.z
	velocity += gravity * delta
	velocity = move_and_slide(velocity, Vector3.UP)

	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # Orthonormalize orientation.
	
	player_model.global_transform.basis = orientation.basis
	
	# Check current weapon
	check_weapon_stance(delta)
	

func rotate_camera(move):
	camera_base.rotate_y(-move.x)
	# After relative transforms, camera needs to be renormalized.
	camera_base.orthonormalize()
	camera_x_rot += move.y
	camera_x_rot = clamp(camera_x_rot, deg2rad(CAMERA_X_ROT_MIN), deg2rad(CAMERA_X_ROT_MAX))
	camera_rot.rotation.x = camera_x_rot

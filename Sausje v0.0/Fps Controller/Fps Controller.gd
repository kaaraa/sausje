extends CharacterBody3D

@export var look_sensitivity : float = 0.0007
@export var jump_velocity := 9.1
@export var auto_bhop := false

const HEADBOB_MOVE_AMOUNT = 0.05
const HEADBOB_FREQUENCY = 2.5
var headbob_time := 0.0




@export var walk_speed : = 6.8
@export var sprint_speed := 8.6
@export var ground_accel := 12.0
@export var ground_decel := 2.0
@export var ground_friction := 6.0

@export var air_cap:= .90
@export var air_accel := 1200
@export var air_decel := .08
@export var air_move_speed := 450.0


@export var coyotetimer: float = 0.2

@export var jumplurchtimer: float =0.05
@export var jumplurchaccel = 90
@export var jumplurchdecel = 8
@export var lurch = false



@onready var head = $Head
@onready var camera = $Head/Camera3D

@onready var gun_shoot = $Head/Camera3D/flatty/Shoot
@onready var gun_raycast = $Head/Camera3D/flatty/RayCast3D


var jump_count = 0
var max_jumps = 2

#Bulleters
var bullet = load("res://Bullet/bullet.tscn")
var instance

var wish_dir := Vector3.ZERO
var horizontalvel = Vector3.ZERO


func _get_move_speed() -> float:
	return sprint_speed if Input.is_action_pressed("sprint") && Input.is_action_pressed("up") else walk_speed
	
func _ready():
	for child in %WorldModel.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false)
		child.set_layer_mask_value(2, true)
		
func _unhandled_input(event):
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * look_sensitivity)
			%Camera3D.rotate_x(-event.relative.y * -look_sensitivity)
			%Camera3D.rotation.x = clamp(%Camera3D .rotation.x, deg_to_rad(-105), deg_to_rad(105))
			
			
func _headbob_effect(delta):
	headbob_time += delta * self.velocity.length()
	%Camera3D.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUENCY * 0.5) * HEADBOB_MOVE_AMOUNT,
		sin(headbob_time * HEADBOB_FREQUENCY) * HEADBOB_MOVE_AMOUNT,
		0
	)
	
func _process(delta):
	pass
	
#surf stuff
func clip_velocity(normal: Vector3, overbounce : float, delta : float) -> void:	
	var backoff := self.velocity.dot(normal) * overbounce
	if backoff >= 0: return
	
	var change := normal * backoff 
	self.velocity -= change
	
	var adjust := self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity -= normal * adjust
	
func is_surface_too_steep(normal : Vector3) -> bool:
	var max_slope_ang_dot = Vector3(0, 1, 0).rotated(Vector3(1.0,0,0), self.floor_max_angle).dot(Vector3(0,1,0))
	if normal.dot(Vector3(0,1,0)) < max_slope_ang_dot:
		return true
	return false
	
func _handle_air_physics(delta) -> void:
	self.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	# source air magic
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	_get_current_speed(delta)
	var negativeproj = cur_speed_in_wish_dir < 0 #add bool for wish dir against current direction
	var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)
	
	
	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	var add_spabs = - capped_speed + cur_speed_in_wish_dir
	
	if is_on_wall():
		if add_speed_till_cap > 0:
			var accel_speed = air_accel * air_move_speed * delta
			accel_speed = min(accel_speed, add_speed_till_cap)
			self.velocity += accel_speed * wish_dir 
		clip_velocity(get_wall_normal(), 1, delta) #allows surfing
		
	elif lurch: #give extra directional speed when double jump jets used
		var jumplurchspeed = jumplurchaccel * delta  
		self.velocity += jumplurchspeed * wish_dir
		#add velocity cap/ half velocity like in tf1 when jets used!
		horizontalvel = Vector3(self.velocity.x, 0, self.velocity.z)
		var control = max(horizontalvel.length(), jumplurchdecel)
		var drop = control * ground_friction * delta #use ground friction here to slow player if too fast like tf1
		var new_speed = max(horizontalvel.length() - drop, 0.0)
		if horizontalvel.length() > 0:
			new_speed /= horizontalvel.length()
		self.velocity.x *= new_speed
		self.velocity.z *= new_speed
		
	elif negativeproj:  #fix decel in opposite direction of movement bug from source
		var decel_speed = air_decel * air_move_speed * delta
		#decel_speed = min(decel_speed, -add_spabs)
		self.velocity +=  decel_speed * wish_dir 
		
	elif add_speed_till_cap > 0:
		var accel_speed = air_accel * air_move_speed * delta 
		accel_speed = min(accel_speed, add_speed_till_cap) 
		#^this is dumb? potentially always will be add_speed_till_cap cause of values used 
		self.velocity += accel_speed * wish_dir 
	
	
		 
		
		
		
	
func _handle_ground_physics(delta) -> void:
	#bhop air stuff
	var cur_speed_in_wish_dir = self.velocity.dot(wish_dir)
	_get_current_speed(delta)
	var add_speed_till_cap = _get_move_speed() - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = ground_accel * delta * _get_move_speed()
		accel_speed = min(accel_speed, add_speed_till_cap)
		self.velocity += accel_speed * wish_dir
		
	#drop speed of above max allowed ground speed? possibly friction
	var control = max(self.velocity.length(), ground_decel)
	var drop = control * ground_friction * delta
	var new_speed = max(self.velocity.length() - drop, 0.0)
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length()
	self.velocity *= new_speed
	
	
	_headbob_effect(delta)
	
func _physics_process(delta):
	var input_dir = Input.get_vector("left", "right", "up", "down").normalized()
	
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	
	if Input.is_action_pressed("shoot"):
		if !gun_shoot.is_playing():
			gun_shoot.play("Shooting")
			instance = bullet.instantiate()
			instance.position = gun_raycast.global_position
			instance.transform.basis = gun_raycast.global_transform.basis
			get_parent().add_child(instance)
	
	if is_on_floor():
		
		lurch = false
		global.air_move = lurch
		jump_count = 0
		global.jumpcount = jump_count 
		if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
			self.velocity.y = jump_velocity
			jump_count += 1
			global.jumpcount = jump_count
			_handle_air_physics(delta) 
		_handle_ground_physics(delta)
	else: 
		if jump_count == 0:
			get_tree().create_timer(coyotetimer).timeout.connect(coyote_timeout)
		if Input.is_action_just_pressed("jump") and jump_count < max_jumps:
			if jump_count == 1: #make sure to only lurch if we're double jumping
				get_tree().create_timer(jumplurchtimer).timeout.connect(jump_lurchtimeout) #start lurch timer
				lurch = true
				global.air_move = lurch
				
			self.velocity.y = 0.8 * jump_velocity
			jump_count += 1
			global.jumpcount = jump_count 
			
			
		_handle_air_physics(delta)
		
		
	
	
	
	
	move_and_slide()
	
	
func _get_current_speed(delta):    # Compute the magnitude of the velocity vector (overall speed)
	var curspeed = sqrt( self.velocity.x ** 2 + self.velocity.z ** 2)
	global.speed = curspeed;
	
func coyote_timeout():
	jump_count = 1
	global.jumpcount = jump_count
	
func jump_lurchtimeout(): 
	lurch = false
	global.air_move = lurch
	
	





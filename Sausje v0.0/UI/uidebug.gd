extends Label
@onready var coyotetimer = $coyotetimer

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var fps = Engine.get_frames_per_second()
	var vel = global.speed
	var jumpc = global.jumpcount
	text = ("fps:" + str(fps) + "\n" + "Velocity:" + str(vel) + "\n" + "Jumpcount:" 
	+ str(jumpc) + "\n" + str(global.air_move))
	
	
	#var vel = global.speed
	#text = "Velocity: " + str(round(vel*30))




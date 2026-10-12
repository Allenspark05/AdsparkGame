extends CharacterBody2D

const GRAVITY : int = 1000
const MAX_VEL : int = 600
const FLAP_SPEED : int = -500
var flying : bool = false
var falling : bool = false
const START_POS = Vector2(100, 400)
const TRAIL_COLORS = {"boy": Color(0.4, 0.7, 1.0), "girl": Color(1.0, 0.5, 0.7)}

# Called when the node enters the scene tree for the first time.
func _ready():
	apply_hero()
	reset()

# Swap the flying frames for the hero picked on the select screen.
func apply_hero():
	var frames = $AnimatedSprite2D.sprite_frames.duplicate()
	for i in frames.get_frame_count("flying"):
		var tex = load("res://assets/bird_%s%d.png" % [GameState.hero, i + 1])
		frames.set_frame("flying", i, tex)
	$AnimatedSprite2D.sprite_frames = frames
	$Trail.color = TRAIL_COLORS[GameState.hero]

func reset():
	falling = false
	flying = false
	position = START_POS
	set_rotation(0)
	
	# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	$Trail.emitting = flying  # spark trail only while flying
	if flying or falling:
		velocity.y += GRAVITY * delta
		#terminal velocity
		if velocity.y > MAX_VEL:
			velocity.y = MAX_VEL
		if flying:
			set_rotation(deg_to_rad(velocity.y * 0.05))
			$AnimatedSprite2D.play()
		elif falling:
			set_rotation(PI/2)
			$AnimatedSprite2D.stop()
		move_and_collide(velocity * delta)
	else:
		$AnimatedSprite2D.stop()
		
func flap():
	velocity.y = FLAP_SPEED

extends Camera3D

var player : Node3D
var swivel : Node3D
var offsetXZVector : Vector3
var offsetXZAngle : float
var tilt = Vector3.ZERO
var tiltBasis : Basis
const tiltAmount := 15 * PI / 180

# Called when the node enters the scene tree for the first time.
func _ready():
	swivel = get_parent()
	swivel.top_level = true
	player = swivel.get_parent()
	offsetXZVector = Vector3(position.x, 0, position.z)
	offsetXZAngle = atan2(position.x, position.z)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# Compute tiltTarget based on input
	var tiltTarget = Vector3.ZERO
	var tilted = false
	if Input.is_action_pressed("tilt_forward"):
		tiltTarget.z += 1.0
		tilted = true
	elif Input.is_action_pressed("tilt_backward"):
		tiltTarget.z -= 1.0
		tilted = true
	if Input.is_action_pressed("tilt_left"):
		tiltTarget.x += 1.0
		tilted = true
	elif Input.is_action_pressed("tilt_right"):
		tiltTarget.x -= 1.0
		tilted = true
	if tilted:
		tiltTarget = tiltTarget.normalized()

	# Smoothly push tilt toward the current target
	tilt = tilt * 0.9 + tiltTarget * 0.1

	# Get an axis of rotation that can give us the desired tilt,
	# and update tiltBasis accordinly
	var tiltAxis = tilt.cross(Vector3.UP)
	var tiltLength = tiltAxis.length()
	if tiltLength > 0.00001:
		tiltAxis = tiltAxis * (1 / tiltLength)
		tiltBasis = Basis(tiltAxis, tiltAmount * tiltLength)
	else:
		tiltBasis = Basis()

	# Set gravity according to the current tilt
	PhysicsServer3D.area_set_param(
		get_world_3d().space,
		PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR,
		swivel.global_basis * -Vector3.UP)	

func _physics_process(_delta):
	var lastCamOffset = (
		(swivel.global_transform * offsetXZVector)
		- player.global_position)
	swivel.global_position = player.global_position
	var angle = atan2(lastCamOffset.x, lastCamOffset.z)
	swivel.global_basis = (
		Basis(Vector3.UP, angle - offsetXZAngle) *
		tiltBasis)

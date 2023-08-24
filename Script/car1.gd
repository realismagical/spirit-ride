extends VehicleBody

export var MAX_ENGINE_FORCE = 200.0
export var MAX_STEER_ANGLE = 0.5
var steer_target = 0.0
var steer_angle = 0.0
var steer_val = 0
export (NodePath) var road_path
var road_points
var penultimate_point
var second_point
var last_point
var random_point
var new_point
var control_point_in
var game_over_threshold = 0
var throttle_val = 0.3
var m
var inclination_y
var accelerometer
var left_front_wheel
var right_front_wheel
var left_rear_wheel
var right_rear_wheel
var _timer = Timer.new()
var _timer_section = Timer.new()
var total_distance = 0
var road_height = 0
var restart_switch = true
var timer_period
var _callback = JavaScript.create_callback(self, "_on_gesture")

func _ready():
	set_process_input(true)
	transform.origin = Vector3(0.0,0.0,0.0)
	if road_path:
		get_node(road_path).curve.clear_points()
		get_node(road_path).curve.add_point(Vector3(-10.0,0.0,0.0))
		get_node(road_path).curve.add_point(Vector3(10.0,0.0,0.0))
		get_node(road_path).curve.add_point(Vector3(50.0,0.0,0.0))
	get_node("gameover").hide()
	get_node("restart").hide()
	restart_switch = true
	randomize()
	_timer = Timer.new()
	add_child(_timer)
	_timer.connect("timeout", self, "_on_Timer_timeout")
	_timer.set_wait_time(5.0)
	_timer.set_one_shot(false) # Make sure it loops
	_timer.start()
	setup_section_timer()
	JavaScript.get_interface("window").addEventListener('message', _callback)
	$CarSound.play()

func setup_section_timer():
	_timer_section = Timer.new()
	add_child(_timer_section)
	_timer_section.connect("timeout", self, "evaluate_section")
	_timer_section.set_wait_time(3.0)
	_timer_section.set_one_shot(false) # Make sure it loops
	_timer_section.start()

func _on_Timer_timeout():
	throttle_val = throttle_val + 0.01
	timer_period = 2.0+throttle_val/2
	timer_period = stepify(timer_period, 0.01)
	if timer_period <= 0:
		timer_period = 0.1
	_timer_section.set_wait_time(timer_period)	

func evaluate_section():
	if road_path:
		road_points = get_node(road_path).curve.get_point_count()
		if road_points <= 5:
			add_section()
		second_point = get_node(road_path).curve.get_point_position(1)
		if road_points > 3 && translation.abs().distance_to(second_point) > 100:
			get_node(road_path).curve.remove_point(0)

func add_section():
	if road_path:
		road_points = get_node(road_path).curve.get_point_count()
		penultimate_point = get_node(road_path).curve.get_point_position(road_points-2)
		last_point = get_node(road_path).curve.get_point_position(road_points-1)
		road_height = penultimate_point.y
		
		if game_over_threshold <= 100:
			total_distance = total_distance + abs(last_point.x - penultimate_point.x)
		control_point_in = last_point + get_node(road_path).curve.get_point_in(road_points-1)
		if last_point.x - control_point_in.x == 0:
			m = 0
		else:
			m = (last_point.z - control_point_in.z) / (last_point.x - control_point_in.x)
		random_point = Vector3(rand_range(30.0, 100.0),
			rand_range(-2.0, 2.0),
			rand_range(-10.0, 10.0))
		new_point = Vector3(last_point.x + random_point.x,
			random_point.y,
			last_point.z + random_point.z)
		inclination_y = -1
		if last_point.y > penultimate_point.y:
			inclination_y = 1
		if m > 0:
			control_point_in = Vector3(-abs(new_point.x - last_point.x) / 2, inclination_y*random_point.y, abs(random_point.z))
		else:
			control_point_in = Vector3(-abs(new_point.x - last_point.x) / 2, inclination_y*random_point.y, -abs(random_point.z))
		get_node(road_path).curve.add_point(new_point, control_point_in)

func _on_gesture(args):
	var message = String(args[0].data)
	if message == "l":
		steer_val = 0.3
	elif message == "r":
		steer_val = -0.3
	else:
		steer_val = 0

func _input(event):
	steer_val = 0
	if event is InputEventMouseButton or event is InputEventScreenDrag:
		if event.position.x < (get_viewport().size.x / 2):
			steer_val = 1.0
		else:
			steer_val = -1.0

func _physics_process(_delta):	
	if road_path:
		road_points = get_node(road_path).curve.get_point_count()
		penultimate_point = get_node(road_path).curve.get_point_position(road_points-2)
		last_point = get_node(road_path).curve.get_point_position(road_points-1)
		if translation.abs().distance_to(penultimate_point) < 10.0:
			add_section()
			get_node(road_path).curve.remove_point(0)
		elif translation.abs().distance_to(last_point) < translation.abs().distance_to(penultimate_point):
			add_section()
			add_section()
			get_node(road_path).curve.remove_point(0)
	
	if Input.is_action_pressed("ui_left"):
		steer_val = 1.0
	elif Input.is_action_pressed("ui_right"):
		steer_val = -1.0
	
	left_front_wheel = !get_node("left_front").is_in_contact()
	right_front_wheel = !get_node("right_front").is_in_contact()
	left_rear_wheel = !get_node("left_rear").is_in_contact()
	right_rear_wheel = !get_node("right_rear").is_in_contact()
	if left_front_wheel && right_front_wheel && left_rear_wheel && right_rear_wheel && translation.y < road_height:
		game_over_threshold = game_over_threshold + 1
		if game_over_threshold > 100:
			get_node("score").text = String(floor(total_distance))+'m'
			get_node("gameover").show()
			get_node("score").show()
			if restart_switch:
				$CarSound.stop()
				var window = JavaScript.get_interface("window")
				window.parent.postMessage(floor(total_distance/100))
				get_node("restart").show()
				restart_switch = false
	else:
		game_over_threshold = 0
	
	engine_force = throttle_val * MAX_ENGINE_FORCE
	
	steer_target = steer_val * MAX_STEER_ANGLE
	steer_angle = steer_target
	steering = steer_angle
	$manubrio.rotate_z(steer_angle)

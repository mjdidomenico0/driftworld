extends Node3D

signal bioluminescence_changed(active: bool)

@onready var day_night_timer: Timer = $DayNightTimer
@onready var world_environment: Environment = $WorldEnvironment.environment
@onready var sun: DirectionalLight3D = $Sun

var is_night: bool = false
var day_duration: float = 120.0  # seconds per full cycle (twilight + night + twilight)
var transition_duration: float = 10.0  # seconds for dawn/dusk transitions

var night_target_energy: float = 0.2
var night_target_ambient: float = 0.3
var day_target_energy: float = 0.8
var day_target_ambient: float = 0.6

var current_energy: float = 0.8
var current_ambient: float = 0.6

func _ready() -> void:
	day_night_timer.wait_time = day_duration / 2.0  # Half cycle to flip between states
	day_night_timer.start()
	_update_lighting(false)  # Start in twilight (day)

func _on_day_night_timer_timeout() -> void:
	is_night = !is_night
	_update_lighting(is_night)

func _update_lighting(night: bool) -> void:
	if night:
		# Night: Bioluminescent mode
		world_environment.background_color = Color(0.02, 0.02, 0.06, 1.0)
		world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world_environment.ambient_light_color = Color(0.1, 0.2, 0.4, 1.0)
		sun.light_color = Color(0.4, 0.5, 0.8, 1.0)
		sun.rotation.x = PI / 4  # Moon-like angle
		night_target_energy = 0.2
		night_target_ambient = 0.3
	else:
		# Twilight (day): Soft warm glow
		world_environment.background_color = Color(0.1, 0.05, 0.15, 1.0)
		world_environment.ambient_light_color = Color(0.3, 0.25, 0.4, 1.0)
		sun.light_color = Color(0.9, 0.7, 0.5, 1.0)
		sun.rotation.x = PI / 6  # Low sun angle for twilight feel
		night_target_energy = 0.8
		night_target_ambient = 0.6
	
	# Signal all bioluminescent objects
	bioluminescence_changed.emit(night)

func _process(delta: float) -> void:
	# Smooth transition for lighting values
	var target_energy := night_target_energy if is_night else day_target_energy
	var target_ambient := night_target_ambient if is_night else day_target_ambient
	
	current_energy = lerp(current_energy, target_energy, delta / transition_duration)
	current_ambient = lerp(current_ambient, target_ambient, delta / transition_duration)
	
	world_environment.ambient_light_energy = current_ambient
	sun.light_energy = current_energy
	
	# Subtle sun/moon rotation for atmosphere
	if not is_night:
		sun.rotation.y += delta * 0.02
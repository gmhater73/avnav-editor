extends Camera2D

@export var MIN_ZOOM_LEVEL: float = 0.5
@export var MAX_ZOOM_LEVEL: float = 12
@export var ZOOM_INCREMENT: float = 0.1

@export var PAN_GESTURE_SENSITIVITY: float = 10.0

var current_offset: Vector2 = Vector2()
var current_zoom: float = 1
var dragging: bool = false

@onready var node_manager: Control = get_node("/root/Root/GUI/NodeManager")
@onready var bounds: Rect2 = ProjectSettings.get_setting("Project/Bounds")
@onready var map_rect: Rect2 = get_node("/root/Root/Map").get_rect()

# map_to_canvas_coords_fast
@onready var bpxy: Vector2 = bounds.position
@onready var bexymbpxy: Vector2 = bounds.size
@onready var mpxy: Vector2 = map_rect.position
@onready var mexymmpxy: Vector2 = map_rect.size
@onready var nmrp: Vector2 = node_manager.get_rect().position
@onready var cvt: Transform2D = get_viewport().get_canvas_transform()
func _update_map_to_canvas_coords_fast() -> void: cvt = get_viewport().get_canvas_transform()
func _process(_delta: float) -> void: _update_map_to_canvas_coords_fast()
func map_to_canvas_coords_fast(c: Vector2) -> Vector2: return cvt * ((c - bpxy) / bexymbpxy * mexymmpxy + mpxy) - nmrp

var t_zoom: Vector2 = zoom:
	set(value):
		zoom = value
		t_zoom = value
		_update_map_to_canvas_coords_fast()
		node_manager.redraw()

var allow_tween_set_offset: bool = true
var t_offset: Vector2 = offset:
	set(value):
		t_offset = value
		_update_map_to_canvas_coords_fast()
		node_manager.redraw()
		if not allow_tween_set_offset: return
		offset = value

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_drag"):
		dragging = true
	elif event.is_action_released("cam_drag"):
		dragging = false
		
	elif dragging and event is InputEventMouseMotion:
		allow_tween_set_offset = false
		current_offset -= event.relative * (1 / current_zoom)
		offset = current_offset
		t_offset = offset
	elif event is InputEventPanGesture:
		allow_tween_set_offset = false
		current_offset += event.delta * (1 / current_zoom) * PAN_GESTURE_SENSITIVITY
		offset = current_offset
		t_offset = offset
		
	elif event.is_action("cam_zoom_in"):
		update_zoom(ZOOM_INCREMENT, get_local_mouse_position())
	elif event.is_action("cam_zoom_out"):
		update_zoom(-ZOOM_INCREMENT, get_local_mouse_position())

func update_zoom(increment: float, zoom_anchor: Vector2) -> void:
	var old_zoom: float = current_zoom
	
	current_zoom = clamp(current_zoom + increment * current_zoom, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)
	current_offset += (zoom_anchor - current_offset) * (1 - (1 / current_zoom) * old_zoom)
	
	allow_tween_set_offset = true
	create_tween().tween_property(self, "t_offset", current_offset, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	create_tween().tween_property(self, "t_zoom", Vector2(current_zoom, current_zoom), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)

func _map(number: float, start: float, end: float, new_start: float, new_end: float) -> float:
	return ((number - start) / (end - start)) * (new_end - new_start) + new_start

func world_to_map_coords(world_coords: Vector2) -> Vector2:
	return Vector2(_map(world_coords.x, map_rect.position.x, map_rect.end.x, bounds.position.x, bounds.end.x), _map(world_coords.y, map_rect.position.y, map_rect.end.y, bounds.position.y, bounds.end.y))

func map_to_world_coords(map_coords: Vector2) -> Vector2:
	return Vector2(_map(map_coords.x, bounds.position.x, bounds.end.x, map_rect.position.x, map_rect.end.x), _map(map_coords.y, bounds.position.y, bounds.end.y, map_rect.position.y, map_rect.end.y))

func screen_to_map_coords(screen_coords: Vector2) -> Vector2:
	return world_to_map_coords(screen_to_world_coords(screen_coords))

func map_to_screen_coords(map_coords: Vector2) -> Vector2:
	return world_to_screen_coords(map_to_world_coords(map_coords))

func world_to_screen_coords(world_coords: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * (world_coords)

func screen_to_world_coords(screen_coords: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * (screen_coords)

func map_to_canvas_coords(map_coords: Vector2) -> Vector2:
	return screen_to_canvas_coords(map_to_screen_coords(map_coords))

func canvas_to_map_coords(canvas_coords: Vector2) -> Vector2:
	return screen_to_map_coords(canvas_to_screen_coords(canvas_coords))

func world_to_canvas_coords(world_coords: Vector2) -> Vector2:
	return screen_to_canvas_coords(world_to_screen_coords(world_coords))

func canvas_to_world_coords(canvas_coords: Vector2) -> Vector2:
	return screen_to_world_coords(canvas_to_screen_coords(canvas_coords))

func screen_to_canvas_coords(screen_coords: Vector2) -> Vector2:
	return screen_coords - node_manager.get_rect().position

func canvas_to_screen_coords(canvas_coords: Vector2) -> Vector2:
	return canvas_coords + node_manager.get_rect().position

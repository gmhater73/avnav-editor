extends Control

@export var NODE_VISUAL_SIZE: int = 5
@export var NODE_VISUAL_BORDER_WIDTH: int = 1

@export var WAY_VISUAL_WIDTH: int = 3
@export var WAY_VISUAL_BORDER_WIDTH: int = 1

@export var NODE_VISUAL_COLOR: Color = Color.CRIMSON
@export var NODE_VISUAL_COLOR_HOVER: Color = Color.DARK_RED

@export var WAY_VISUAL_COLOR: Color = Color.YELLOW

@export var VISUAL_COLOR_SELECTED: Color = Color.PURPLE
@export var VISUAL_COLOR_SELECTED_HOVER: Color = Color.BLUE_VIOLET

@export var VISUAL_COLOR_BORDER: Color = Color.BLACK

@export var SELECT_RECTANGLE_COLOR: Color = Color.CORNFLOWER_BLUE

@export var TOOLS_BUTTON_GROUP: ButtonGroup

@onready var camera: Camera2D = get_node("/root/Root/Camera2D")

@onready var toolbar_project_menu: PopupMenu = get_node("/root/Root/GUI/TopBar/MarginContainer/ToolbarLeft/Project").get_popup()

@onready var screen_dim: Panel = get_node("/root/Root/GUI/ScreenDim")

var nodes: Array = []
var ways: Array = []

var updated_this_frame: bool = false

var mouse_over_node = null

var creating_way_from_node_front: bool = false
var creating_way_from_node = null

signal update_ways_view

var select_rect = null

var selected: PackedInt32Array = PackedInt32Array()
var selected_type = null
signal update_inspector
func selection_updated() -> void:
	if selected.size() == 0: selected_type = null
	emit_signal("update_ways_view", ways)
	emit_signal("update_inspector", selected, selected_type)
	toolbar_project_menu.set_item_text(4, str(len(nodes)) + " nodes")
	toolbar_project_menu.set_item_text(5, str(len(ways)) + " ways")
	redraw()

var history: Array = []
var history_index: int = -1
func update_history() -> void:
	history.resize(history_index + 2)
	history[history.size() - 1] = {
		"nodes": nodes.duplicate(true),
		"ways": ways.duplicate(true),
		"selected": selected.duplicate(),
		"selected_type": selected_type,
		"creating_way_from_node_front": creating_way_from_node_front,
		"creating_way_from_node": creating_way_from_node
	}
	history = history.slice(-100)
	history_index = history.size() - 1
func navigate_history(index: int) -> void:
	if index > history.size() - 1: return
	if index < 0: return
	history_index = index
	var data = history[history_index]
	nodes = data.nodes.duplicate(true)
	ways = data.ways.duplicate(true)
	selected = data.selected.duplicate()
	selected_type = data.selected_type
	creating_way_from_node_front = data.creating_way_from_node_front
	creating_way_from_node = data.creating_way_from_node
	selection_updated()

func _ready() -> void:
	PhysicsServer2D.set_active(false)
	update_history()
	#for i in range(3000000): nodes.append({ "position": Vector2(randi_range(ProjectSettings.get_setting("Project/Bounds").position.x, ProjectSettings.get_setting("Project/Bounds").end.x), randi_range(ProjectSettings.get_setting("Project/Bounds").position.y, ProjectSettings.get_setting("Project/Bounds").end.y)), "tags": {} })
	#var new_ways: Array = []
	#for i in range(500): new_ways.append({ "nodes": range(randi_range(2, 50000)), "tags": {"name": "someway", "the": "ass"} })
	#set_ways(new_ways)

func _process(delta: float) -> void: updated_this_frame = screen_dim.visible
func redraw() -> void:
	if updated_this_frame: return
	queue_redraw()
	updated_this_frame = true

func _draw() -> void:
	var draw_time: float = Time.get_ticks_usec()
	
	var cull_rect: Rect2 = Rect2(Vector2.ZERO, size)
	
	var way_visual_width: int = max(WAY_VISUAL_WIDTH * (1 - (1 / camera.current_zoom) + 1), 1)
	var way_border_width: int = way_visual_width + WAY_VISUAL_BORDER_WIDTH * 2
	
	for i in range(0, ways.size()):
		var way: Dictionary = ways[i]
		
		var way_line_points: PackedVector2Array = PackedVector2Array()
		way_line_points.resize((way.nodes.size() - 1) * 2)
		
		for way_node_index in range(0, way.nodes.size() - 1):
			var node_1: Dictionary = nodes[way.nodes[way_node_index]]
			var node_2: Dictionary = nodes[way.nodes[way_node_index + 1]]
			
			var canvas_position_1: Vector2 = camera.map_to_canvas_coords_fast(node_1.position)
			var canvas_position_2: Vector2 = camera.map_to_canvas_coords_fast(node_2.position)
			
			way_line_points.set(way_node_index * 2, canvas_position_1)
			way_line_points.set(way_node_index * 2 + 1, canvas_position_2)
		
		draw_polyline(way_line_points, VISUAL_COLOR_BORDER, way_border_width, true)
		draw_polyline(way_line_points, VISUAL_COLOR_SELECTED if selected_type == "Way" and selected.size() > 0 and i == selected[0] else way._color, way_visual_width, true)
	
	# todo implement mouse_over_way
	"""var mouse_position: Vector2 = get_local_mouse_position()
	for i in range(0, len(ways)):
		var way: Dictionary = ways[i]
		
		for way_node_index in range(0, len(way.nodes) - 1):
			var node_1: Dictionary = nodes[way.nodes[way_node_index]]
			var node_2: Dictionary = nodes[way.nodes[way_node_index + 1]]
			
			var canvas_position_1: Vector2 = camera.map_to_canvas_coords_fast(node_1.position)
			var canvas_position_2: Vector2 = camera.map_to_canvas_coords_fast(node_2.position)
			
			var x: int = mouse_position.x
			var y: int = mouse_position.y
			
			var distance: float = abs((canvas_position_2.y - canvas_position_1.y) * x - (canvas_position_2.x - canvas_position_1.x) * y + canvas_position_2.x * canvas_position_1.y - canvas_position_2.y * canvas_position_1.x) / sqrt(pow(canvas_position_2.y - canvas_position_1.y, 2) + pow(canvas_position_2.x - canvas_position_1.x, 2))
			
			var length: float = sqrt(pow(canvas_position_2.y - canvas_position_1.y, 2) + pow(canvas_position_2.x - canvas_position_1.x, 2))
			var dotProduct: float = ((x - canvas_position_1.x) * (canvas_position_2.x - canvas_position_1.x)) + ((y - canvas_position_1.y) * (canvas_position_2.y - canvas_position_1.y))
			var angle: float = acos(dotProduct / (length * length))
			
			if distance <= way_border_width / 2 and angle < PI / 2:
				draw_line(canvas_position_1, canvas_position_2, NODE_VISUAL_COLOR_HOVER, way_visual_width, true)
	"""
	var node_visual_size: Vector2 = (Vector2(NODE_VISUAL_SIZE, NODE_VISUAL_SIZE) * (Vector2.ONE - (Vector2.ONE / camera.zoom) + Vector2.ONE)).round()
	if not Input.is_action_pressed("map_alt"):
		var node_border_width: Vector2 = Vector2(NODE_VISUAL_BORDER_WIDTH, NODE_VISUAL_BORDER_WIDTH)
		var border_rect_size: Vector2 = node_visual_size + node_border_width * 2
		var node_visual_size_div_2: Vector2 = node_visual_size / 2
		for i in range(0, nodes.size()):
			var node = nodes[i]
			if node:
				var canvas_position: Vector2 = camera.map_to_canvas_coords_fast(node.position)
				var border_rect: Rect2 = Rect2(canvas_position - node_visual_size_div_2 - node_border_width, border_rect_size)
				if cull_rect.intersects(border_rect, true):
					draw_rect(border_rect, VISUAL_COLOR_BORDER)
					if mouse_over_node == i:
						draw_rect(Rect2(canvas_position - node_visual_size_div_2, node_visual_size), VISUAL_COLOR_SELECTED_HOVER if (selected_type == "Node" and i in selected) or (selected_type == "Way" and i in ways[selected[0]].nodes) else NODE_VISUAL_COLOR_HOVER)
					else:
						draw_rect(Rect2(canvas_position - node_visual_size_div_2, node_visual_size), VISUAL_COLOR_SELECTED if (selected_type == "Node" and i in selected) or (selected_type == "Way" and i in ways[selected[0]].nodes) else NODE_VISUAL_COLOR)
	
	var mouse_position: Vector2 = get_local_mouse_position()
	var pressed_button: Button = TOOLS_BUTTON_GROUP.get_pressed_button()
	
	if pressed_button.name != "WayButton":
		creating_way_from_node = null
	
	if mouse_over_node == null and (pressed_button.name == "NodeButton" or (pressed_button.name == "WayButton" and Input.is_action_pressed("map_special"))):
		draw_rect(Rect2(mouse_position - node_visual_size / 2, node_visual_size), Color(NODE_VISUAL_COLOR.r, NODE_VISUAL_COLOR.g, NODE_VISUAL_COLOR.b, 0.5))
	
	if creating_way_from_node != null and pressed_button.name == "WayButton":
		var node = nodes[creating_way_from_node]
		var node_canvas_position: Vector2 = camera.map_to_canvas_coords_fast(node.position)
		draw_line(node_canvas_position, mouse_position, Color(VISUAL_COLOR_SELECTED.r, VISUAL_COLOR_SELECTED.g, VISUAL_COLOR_SELECTED.b, 0.5), way_visual_width, true)
	
	if select_rect:
		select_rect = Rect2(select_rect.position, camera.canvas_to_map_coords(mouse_position) - select_rect.position)
		draw_rect(Rect2(camera.map_to_canvas_coords_fast(select_rect.position), camera.map_to_canvas_coords_fast(select_rect.end) - camera.map_to_canvas_coords_fast(select_rect.position)), SELECT_RECTANGLE_COLOR)
	
	get_node("Debug").text = "Draw " + ("%.2f" % ((Time.get_ticks_usec() - draw_time) / 1000)) + " ms" + "\nHistory index: " + str(history_index) + " / " + str(history.size()) + "\nMouse over node: " + str(mouse_over_node) + "\nSelected: " + str(selected) + "\nSelected type: " + str(selected_type) + "\nCreating way from node: " + str(creating_way_from_node) + "\nCreating way from node front: " + str(creating_way_from_node_front) + "\n" + str(len(nodes)) + " nodes\n" + str(len(ways)) + " ways"

func _mouse_over_node_is_exclusive_and_last_or_first_node_of_a_way():
	var ways_with_node: Array = []
	for i in range(0, ways.size()): if ways[i].nodes.has(mouse_over_node): ways_with_node.append(i)
	if ways_with_node.size() == 1:
		if ways[ways_with_node[0]].nodes.find(mouse_over_node) != ways[ways_with_node[0]].nodes.rfind(mouse_over_node): return null
		elif ways[ways_with_node[0]].nodes.back() == mouse_over_node: return [ways_with_node[0], false]
		elif ways[ways_with_node[0]].nodes.front() == mouse_over_node: return [ways_with_node[0], true]
	else: return null
func _not_trying_to_connect_way_to_neighbor_node_or_self_node():
	var way: Dictionary = ways[selected[0]]
	var node_index = way.nodes.find(creating_way_from_node)
	return mouse_over_node != way.nodes[node_index] and mouse_over_node != (way.nodes[node_index - 1] if node_index > 0 and len(way.nodes) > 1 else null) and mouse_over_node != (way.nodes[node_index + 1] if node_index < len(way.nodes) - 1 else null)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("command_undo"):
		navigate_history(history_index - 1)
		return
	elif event.is_action_pressed("command_redo"):
		navigate_history(history_index + 1)
		return
	
	mouse_over_node = null
	var mouse_position: Vector2 = get_local_mouse_position()
	
	if select_rect and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if selected_type == "Way" or not Input.is_action_pressed("map_option"):
			selected.clear()
		var test_rect = select_rect.abs()
		for i in range(0, len(nodes)):
			var node = nodes[i]
			if node and test_rect.has_point(node.position) and not i in selected:
				selected.append(i)
		selected_type = "Node" if selected.size() > 0 else null
		selection_updated()
		select_rect = null
	
	var node_visual_size: Vector2 = (Vector2(NODE_VISUAL_SIZE, NODE_VISUAL_SIZE) * (Vector2.ONE - (Vector2.ONE / camera.zoom) + Vector2.ONE)).round()
	var node_border_width: Vector2 = Vector2(NODE_VISUAL_BORDER_WIDTH, NODE_VISUAL_BORDER_WIDTH)
	var border_rect_size: Vector2 = node_visual_size + node_border_width * 2
	var node_half_point: Vector2 = node_visual_size / 2 + node_border_width
	for i in range(0, len(nodes)):
		var node = nodes[i]
		if node and Rect2(camera.map_to_canvas_coords_fast(node.position) - node_half_point, border_rect_size).has_point(mouse_position):
			mouse_over_node = i
			break
	
	# handle map action
	if event.is_action_pressed("map_action"):
		var pressed_button: Button = TOOLS_BUTTON_GROUP.get_pressed_button()
		match pressed_button.name:
			"WayButton":
				if creating_way_from_node != null:
					if mouse_over_node != null and _not_trying_to_connect_way_to_neighbor_node_or_self_node():
						if creating_way_from_node_front:
							ways[selected[0]].nodes.push_front(mouse_over_node)
						else:
							ways[selected[0]].nodes.append(mouse_over_node)
						if ways[selected[0]].nodes.front() == ways[selected[0]].nodes.back():
							ways.append({ "nodes": [mouse_over_node], "tags": {}, "_color": WAY_VISUAL_COLOR.lerp(Color(randf(), randf(), randf()), 0.35) })
							selected.resize(1)
							selected[0] = len(ways) - 1
							selection_updated()
							creating_way_from_node_front = false
						creating_way_from_node = mouse_over_node
						update_history()
					elif Input.is_action_pressed("map_special"):
						nodes.append({ "position": camera.screen_to_map_coords(event.position).round(), "tags": {} })
						if creating_way_from_node_front:
							ways[selected[0]].nodes.push_front(len(nodes) - 1)
						else:
							ways[selected[0]].nodes.append(len(nodes) - 1)
						creating_way_from_node = len(nodes) - 1
						update_history()
					else:
						if len(ways[selected[0]].nodes) < 2:
							ways.remove_at(selected[0])
							selected.clear()
							selected_type = null
							selection_updated()
							creating_way_from_node = null
							update_history()
						else: creating_way_from_node = null
				else:
					if mouse_over_node != null and not Input.is_action_pressed("map_option") and _mouse_over_node_is_exclusive_and_last_or_first_node_of_a_way() != null:
						var value: Array = _mouse_over_node_is_exclusive_and_last_or_first_node_of_a_way()
						selected.resize(1)
						selected[0] = value[0]
						selected_type = "Way"
						selection_updated()
						creating_way_from_node = mouse_over_node
						creating_way_from_node_front = value[1]
					elif mouse_over_node != null and selected.size() > 0 and Input.is_action_pressed("map_option") and _mouse_over_node_is_exclusive_and_last_or_first_node_of_a_way() == null and (ways[selected[0]].nodes.front() == mouse_over_node or ways[selected[0]].nodes.back() == mouse_over_node) and ways[selected[0]].nodes.front() != ways[selected[0]].nodes.back():
						creating_way_from_node = mouse_over_node
						creating_way_from_node_front = true if ways[selected[0]].nodes.front() == mouse_over_node else false
					elif mouse_over_node != null:
						ways.append({ "nodes": [mouse_over_node], "tags": {}, "_color": WAY_VISUAL_COLOR.lerp(Color(randf(), randf(), randf()), 0.35) })
						selected.resize(1)
						selected[0] = len(ways) - 1
						selected_type = "Way"
						selection_updated()
						creating_way_from_node = mouse_over_node
						creating_way_from_node_front = false
						update_history()
					elif Input.is_action_pressed("map_special"):
						nodes.append({ "position": camera.screen_to_map_coords(event.position).round(), "tags": {} })
						creating_way_from_node = len(nodes) - 1
						creating_way_from_node_front = false
						ways.append({ "nodes": [creating_way_from_node], "tags": {}, "_color": WAY_VISUAL_COLOR.lerp(Color(randf(), randf(), randf()), 0.35) })
						selected.resize(1)
						selected[0] = len(ways) - 1
						selected_type = "Way"
						selection_updated()
						update_history()
			
			"NodeButton":
				if mouse_over_node == null:
					nodes.append({ "position": camera.screen_to_map_coords(event.position).round(), "tags": {} })
					selected.resize(1)
					selected[0] = len(nodes) - 1
					selected_type = "Node"
					selection_updated()
					update_history()
			
			"DeleteButton":
				if mouse_over_node != null:
					var ways_to_remove: Array = []
					for i in range(0, len(ways)):
						var way: Dictionary = ways[i]
						while way.nodes.has(mouse_over_node):
							way.nodes.erase(mouse_over_node)
						if len(way.nodes) < 2:
							ways_to_remove.append(i)
					for i in ways_to_remove:
						ways.remove_at(i)
						if selected_type == "Way" and i in selected: selected.remove_at(selected.find(i))
					if selected_type == "Node" and mouse_over_node in selected: selected.remove_at(selected.find(mouse_over_node))
					if selected.size() == 0: selected_type = null
					selection_updated()
					nodes[mouse_over_node] = null
					update_history()
			
			"SelectButton":
				if mouse_over_node == null:
					select_rect = Rect2(camera.canvas_to_map_coords(mouse_position), Vector2.ZERO)
				else:
					if Input.is_action_pressed("map_option"):
						if mouse_over_node in selected:
							selected.remove_at(selected.find(mouse_over_node))
						else:
							selected.append(mouse_over_node)
					else:
						selected.resize(1)
						selected[0] = mouse_over_node
					selected_type = "Node"
					selection_updated()
			
			_:
				selected.clear()
				selected_type = null
				selection_updated()
	
	redraw()

func set_selected(index: int, type: String) -> void:
	selected.resize(1)
	selected[0] = index
	selected_type = type
	selection_updated()

func set_nodes(new_nodes: Array) -> void:
	nodes = new_nodes
	selected.clear()
	selected_type = null
	creating_way_from_node = null
	creating_way_from_node_front = false
	selection_updated()
	updated_this_frame = false

func add_nodes_and_ways(new_nodes: Array, new_ways: Array) -> void:
	var last_node_id = nodes.size()
	nodes.append_array(new_nodes)
	for way in new_ways:
		way._color = WAY_VISUAL_COLOR.lerp(Color(randf(), randf(), randf()), 0.35)
		for index in way.nodes.size():
			way.nodes[index] += last_node_id
	ways.append_array(new_ways)
	selected.clear()
	selected_type = null
	selection_updated()
	updated_this_frame = false

func set_ways(new_ways: Array) -> void:
	for way in new_ways: way._color = WAY_VISUAL_COLOR.lerp(Color(randf(), randf(), randf()), 0.35)
	ways = new_ways
	selected.clear()
	selected_type = null
	selection_updated()
	updated_this_frame = false

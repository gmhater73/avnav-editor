extends Window

@onready var node_manager: Control = get_node("/root/Root/GUI/NodeManager")

@onready var nodes_file_dialog: FileDialog = get_node("/root/Root/GUI/NodesFileDialog")
@onready var ways_file_dialog: FileDialog = get_node("/root/Root/GUI/WaysFileDialog")

@onready var progress_dialog: Popup = get_node("/root/Root/GUI/ImportProgressDialog")
@onready var progress_dialog_progress_bar: ProgressBar = progress_dialog.get_node("MarginContainer/VBoxContainer/ProgressBar")
@onready var progress_dialog_status: Label = progress_dialog.get_node("MarginContainer/VBoxContainer/Status")

@onready var screen_dim: Panel = get_node("%ScreenDim")

@onready var toolbar_project_menu: PopupMenu = get_node("/root/Root/GUI/TopBar/MarginContainer/ToolbarLeft/Project").get_popup()

func _ready() -> void:
	toolbar_project_menu.connect("index_pressed", Callable(self, "_on_Project_menu_index_pressed"))
	$MarginContainer/VBoxContainer/NodesFilePath/HBoxContainer/LineEdit.text = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/nodes.nodes.avn.txt"
	$MarginContainer/VBoxContainer/WaysFilePath/HBoxContainer/LineEdit.text = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/ways.ways.avn.txt"

func _on_Project_menu_index_pressed(index: int) -> void:
	if index == 1:
		popup_centered()

func _on_import_pressed() -> void:
	visible = false
	
	progress_dialog.popup_centered()
	screen_dim.visible = true
	
	var node_file_path: String = $MarginContainer/VBoxContainer/NodesFilePath/HBoxContainer/LineEdit.text
	var way_file_path: String = $MarginContainer/VBoxContainer/WaysFilePath/HBoxContainer/LineEdit.text
	
	var overwrite: bool = $MarginContainer/VBoxContainer/Overwrite/HBoxContainer/CheckBox.button_pressed
	
	var nodes: Array = []
	var ways: Array = []
	
	if node_file_path != "":
		# read nodes
		progress_dialog_status.text = "Reading Nodes"
		progress_dialog_progress_bar.value = 0
		await get_tree().process_frame
		await get_tree().process_frame
		
		var node_file: FileAccess = FileAccess.open(node_file_path, FileAccess.READ)
		var node_strings: PackedStringArray = node_file.get_as_text().replace("{", "~-").replace("}", "*-").split("~", false)
		node_file.close()
		
		# import nodes
		progress_dialog_status.text = "Importing Nodes"
		await get_tree().process_frame
		
		nodes.resize(node_strings.size())
		
		var last_position_x: int = 0
		var last_position_y: int = 0
		
		var start_time: float = Time.get_ticks_msec()
		var time_since_yield: int = Time.get_ticks_msec()
		
		for i in range(0, node_strings.size()):
			var data: PackedStringArray = node_strings[i].split(";", false)
			
			var init_data: PackedStringArray = data[0].split("*", false)
			last_position_x += int(init_data[0])
			last_position_y += int(init_data[1])
			
			var node: Dictionary = { "position": Vector2(last_position_x, last_position_y), "tags": {} }
			
			for tag_string in data.slice(1):
				var tag_data: PackedStringArray = tag_string.split("*", false)
				node.tags[tag_data[0]] = tag_data[1]
			
			nodes[i] = node
			
			if Time.get_ticks_msec() - time_since_yield > 33:
				progress_dialog_status.text = "Importing Nodes (" + str(i) + " / " + str(node_strings.size()) + ") " + str(ceil(i / (Time.get_ticks_msec() - start_time) * 1000)) + " / sec"
				progress_dialog_progress_bar.value = (i / float(node_strings.size())) * (50 if way_file_path != "" else 100)
				await get_tree().process_frame
				time_since_yield = Time.get_ticks_msec()
	
	if way_file_path != "":
		# read ways
		progress_dialog_status.text = "Reading Ways"
		await get_tree().process_frame
		await get_tree().process_frame
		
		var way_file: FileAccess = FileAccess.open(way_file_path, FileAccess.READ)
		var way_strings: PackedStringArray = way_file.get_as_text().split("~", false)
		way_file.close()
		
		# import nodes
		progress_dialog_status.text = "Importing Ways"
		await get_tree().process_frame
		
		var start_time: float = Time.get_ticks_msec()
		var time_since_yield: int = Time.get_ticks_msec()
		
		for i in range(0, len(way_strings)):
			var data: Array = Array(way_strings[i].split(";", false))
			
			var way_nodes: Array = []
			var last_node_id: int = 0
			for node_id in data.pop_front().split("*", false):
				if node_id.substr(0, 1) == "f":
					for j in range(int(node_id.substr(1))):
						last_node_id += 1
						way_nodes.append(last_node_id)
				elif node_id.substr(0, 1) == "b":
					for j in range(int(node_id.substr(1))):
						last_node_id -= 1
						way_nodes.append(last_node_id)
				else:
					last_node_id += int(node_id)
					way_nodes.append(last_node_id)
			
			var way_tags: Dictionary = {}
			for tag_string in data:
				var tag_data: PackedStringArray = tag_string.split("*", false)
				way_tags[tag_data[0]] = tag_data[1]
			
			ways.append({ "nodes": way_nodes, "tags": way_tags })
			
			if Time.get_ticks_msec() - time_since_yield > 33:
				progress_dialog_status.text = "Importing Ways (" + str(i) + " / " + str(len(way_strings)) + ") " + str(ceil(i / (Time.get_ticks_msec() - start_time) * 1000)) + " / sec"
				progress_dialog_progress_bar.value = (50 if node_file_path != "" else 0) + (i / float(len(way_strings))) * (50 if node_file_path != "" else 100)
				await get_tree().process_frame
				time_since_yield = Time.get_ticks_msec()
	
	# finish
	progress_dialog_status.text = "Applying"
	await get_tree().process_frame
	
	if overwrite:
		node_manager.set_nodes(nodes)
		node_manager.set_ways(ways)
	else: node_manager.add_nodes_and_ways(nodes, ways)
	
	node_manager.update_history()
	
	progress_dialog.visible = false
	screen_dim.visible = false

func _on_visibility_changed() -> void:
	screen_dim.visible = visible

func _on_cancel_pressed() -> void:
	visible = false

func _on_ChoosePathToNodesFile_pressed() -> void:
	nodes_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	nodes_file_dialog.popup_centered()

func _on_ChoosePathToWaysFile_pressed() -> void:
	ways_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	ways_file_dialog.popup_centered()

func _on_NodesFileDialog_file_selected(path: String) -> void:
	$MarginContainer/VBoxContainer/NodesFilePath/HBoxContainer/LineEdit.text = path

func _on_WaysFileDialog_file_selected(path: String) -> void:
	$MarginContainer/VBoxContainer/WaysFilePath/HBoxContainer/LineEdit.text = path

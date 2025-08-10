extends Window

@onready var node_manager: Control = get_node("/root/Root/GUI/NodeManager")

@onready var nodes_file_dialog: FileDialog = get_node("/root/Root/GUI/NodesFileDialog")
@onready var ways_file_dialog: FileDialog = get_node("/root/Root/GUI/WaysFileDialog")

@onready var progress_dialog: Popup = get_node("/root/Root/GUI/ExportProgressDialog")
@onready var progress_dialog_progress_bar: ProgressBar = progress_dialog.get_node("MarginContainer/VBoxContainer/ProgressBar")
@onready var progress_dialog_status: Label = progress_dialog.get_node("MarginContainer/VBoxContainer/Status")

@onready var screen_dim: Panel = get_node("%ScreenDim")

@onready var toolbar_project_menu: PopupMenu = get_node("/root/Root/GUI/TopBar/MarginContainer/ToolbarLeft/Project").get_popup()

func _ready() -> void:
	toolbar_project_menu.connect("index_pressed", Callable(self, "_on_Project_menu_index_pressed"))
	$MarginContainer/VBoxContainer/NodesFilePath/HBoxContainer/LineEdit.text = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/nodes.nodes.avn.txt"
	$MarginContainer/VBoxContainer/WaysFilePath/HBoxContainer/LineEdit.text = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP) + "/ways.ways.avn.txt"

func _on_Project_menu_index_pressed(index: int) -> void:
	if index == 2:
		popup_centered()

func _on_export_pressed() -> void:
	visible = false
	
	progress_dialog.popup_centered()
	screen_dim.visible = true
	
	var node_file_path: String = $MarginContainer/VBoxContainer/NodesFilePath/HBoxContainer/LineEdit.text
	var way_file_path: String = $MarginContainer/VBoxContainer/WaysFilePath/HBoxContainer/LineEdit.text
	
	var current_nodes: Array = node_manager.nodes
	var node_old_to_new: Dictionary = {}
	
	var nodes: Array = []
	var ways: Array = node_manager.ways
	
	var processing_nodes: bool = $MarginContainer/VBoxContainer/NodesFilePath/HBoxContainer/ChoosePathButton.disabled == false and node_file_path != ""
	var processing_ways: bool = $MarginContainer/VBoxContainer/WaysFilePath/HBoxContainer/ChoosePathButton.disabled == false and way_file_path != ""
	
	var separate_parts_by_line_break: bool = $MarginContainer/VBoxContainer/SeparatePartsByLineBreak/HBoxContainer/CheckBox.button_pressed
	var compress: bool = $MarginContainer/VBoxContainer/Compress/HBoxContainer/CheckBox.button_pressed
	
	progress_dialog_status.text = "Processing Nodes"
	progress_dialog_progress_bar.value = 0
	await get_tree().process_frame
	await get_tree().process_frame
	
	if processing_nodes:
		var start_time: float = Time.get_ticks_msec()
		var time_since_yield: int = Time.get_ticks_msec()
		
		var node_file: FileAccess = FileAccess.open(node_file_path, FileAccess.WRITE)
		
		var string_length: int = 0
		
		var last_position_x: int = 0
		var last_position_y: int = 0
		
		for i in range(0, current_nodes.size()):
			var node = current_nodes[i]
			if node:
				nodes.append(node)
				node_old_to_new[i] = nodes.size() - 1
				
				var string: String = str("~", node.position.x - last_position_x, "*", node.position.y - last_position_y)
				
				if separate_parts_by_line_break:
					for tag in node.tags: string += str(";", tag, "*", node.tags[tag])
					if compress: string = string.replace("~-", "{").replace("*-", "}")
					string_length += string.length()
					if string_length > 4000:
						string_length = 0
						node_file.store_string("\n")
					node_file.store_string(string)
				else:
					node_file.store_string(string.replace("~-", "{").replace("*-", "}") if compress else string)
					for tag in node.tags: node_file.store_string(str(";", tag, "*", node.tags[tag]))
				
				last_position_x = node.position.x
				last_position_y = node.position.y
			
			if Time.get_ticks_msec() - time_since_yield > 33:
				progress_dialog_status.text = "Processing Nodes (" + str(i) + " / " + str(len(current_nodes)) + ") " + str(ceil(i / (Time.get_ticks_msec() - start_time) * 1000)) + " / sec"
				progress_dialog_progress_bar.value = (i / float(len(current_nodes))) * (50 if processing_ways else 100)
				await get_tree().process_frame
				time_since_yield = Time.get_ticks_msec()
		
		node_file.close()
	else:
		for i in range(0, len(current_nodes)):
			var node = current_nodes[i]
			if node:
				nodes.append(node)
				node_old_to_new[i] = len(nodes) - 1
	
	if processing_ways:
		progress_dialog_status.text = "Processing Ways"
		await get_tree().process_frame
		await get_tree().process_frame
		
		var start_time: float = Time.get_ticks_msec()
		var time_since_yield: int = Time.get_ticks_msec()
		
		var way_file: FileAccess = FileAccess.open(way_file_path, FileAccess.WRITE)
		
		var string_length: int = 0
		
		for i in range(0, len(ways)):
			var way: Dictionary = ways[i]
			
			var way_nodes: PackedInt32Array = PackedInt32Array(way.nodes)
			var last_node_id: int = 0
			for node_index in range(0, len(way_nodes)):
				way_nodes.set(node_index, node_old_to_new[way_nodes[node_index]] - last_node_id)
				last_node_id += way_nodes[node_index]
			
			# possible compression:
			#"""
			var way_nodes_strings: PackedStringArray = PackedStringArray()
			var j: int = 0
			while j < way_nodes.size():
				var index: int = way_nodes[j]
				if index == 1:
					var k: int = j
					while k < way_nodes.size() and way_nodes[k] == 1: k += 1
					way_nodes_strings.append(str("f", k - j))
					j = k
				elif index == -1:
					var k: int = j
					while k < way_nodes.size() and way_nodes[k] == -1: k += 1
					way_nodes_strings.append(str("b", k - j))
					j = k
				else:
					way_nodes_strings.append(str(index))
					j += 1
			#"""
			#var way_nodes_strings: PackedStringArray = PackedStringArray(Array(way_nodes))
			var string: String = "~" + "*".join(way_nodes_strings)
			
			if separate_parts_by_line_break:
				for tag in way.tags: string += str(";", tag, "*", way.tags[tag])
				string_length += string.length()
				if string_length > 4000:
					string_length = 0
					way_file.store_string("\n")
				way_file.store_string(string)
			else:
				way_file.store_string(string)
				for tag in way.tags: way_file.store_string(str(";", tag, "*", way.tags[tag]))
			
			if Time.get_ticks_msec() - time_since_yield > 33:
				progress_dialog_status.text = "Processing Ways (" + str(i) + " / " + str(len(ways)) + ") " + str(ceil(i / (Time.get_ticks_msec() - start_time) * 1000)) + " / sec"
				progress_dialog_progress_bar.value = (50 if processing_nodes else 0) + (i / float(len(ways))) * (50 if processing_nodes else 100)
				await get_tree().process_frame
				time_since_yield = Time.get_ticks_msec()
		
		way_file.close()
	
	# finish
	progress_dialog.visible = false
	screen_dim.visible = false

func _on_visibility_changed() -> void:
	screen_dim.visible = visible

func _on_cancel_pressed() -> void:
	visible = false

func _on_ChoosePathToNodesFile_pressed() -> void:
	nodes_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	nodes_file_dialog.popup_centered()

func _on_ChoosePathToWaysFile_pressed() -> void:
	ways_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	ways_file_dialog.popup_centered()

func _on_NodesFileDialog_file_selected(path: String) -> void:
	$MarginContainer/VBoxContainer/NodesFilePath/HBoxContainer/LineEdit.text = path

func _on_WaysFileDialog_file_selected(path: String) -> void:
	$MarginContainer/VBoxContainer/WaysFilePath/HBoxContainer/LineEdit.text = path

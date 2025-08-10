extends VBoxContainer

@onready var node_manager: Control = get_node("%NodeManager")

@onready var properties_container: VBoxContainer = $PropertiesScrollContainer/VBoxContainer
@onready var name_label: Label = $HBoxContainer/Name

var properties: Array[Dictionary] = []
"""{
	"text": "Suggested Speed",
	"key": "speed",
	"type": "option",
	"options": [
		{
			"text": "Low speed",
			"value": "-1"
		},
		{
			"text": "No change",
			"value": null
		},
		{
			"text": "High speed",
			"value": "1"
		}
	]
}"""

func _ready():
	for property in properties:
		var container: HBoxContainer = HBoxContainer.new()
		container.size_flags_horizontal += SIZE_EXPAND
		properties_container.add_child(container)
		
		var label: Label = Label.new()
		label.size_flags_horizontal += SIZE_EXPAND
		label.text = property.text
		container.add_child(label)
		
		match property.type:
			"option":
				var button: OptionButton = OptionButton.new()
				property.control = button
				
				for item in property.options:
					if item.get("separator"):
						button.add_separator(item.get("text", ""))
					else:
						button.add_item(item.get("text", ""))
						button.set_item_metadata(button.item_count - 1, item.value)
						button.set_item_disabled(button.item_count - 1, item.get("disabled", false))
						button.set_item_tooltip(button.item_count - 1, item.get("tooltip", ""))
				
				"""if property.default:
					var i: int = 0
					for item in property.options:
						if item.value == property.default:
							button.select(i)
							break
						i += 1"""
				
				button.connect("item_selected", func(item_index: int) -> void:
					var value = button.get_item_metadata(item_index)
					if node_manager.selected_type == "Node":
						for index in node_manager.selected:
							if value == null:
								node_manager.nodes[index].tags.erase(property.key)
							else:
								node_manager.nodes[index].tags[property.key] = value
					node_manager.update_history()
					node_manager.redraw()
				)
				
				button.size_flags_horizontal += SIZE_EXPAND
				container.add_child(button)

func _on_update_inspector(selected: PackedInt32Array, selected_type) -> void:
	visible = selected_type == "Node"
	
	if selected_type != "Node": return
	
	if selected.size() == 1:
		var index: int = selected[0]
		var node = node_manager.nodes[index]
		name_label.text = "Node " + str(index)
		properties_container.get_node("Position/X").editable = true
		properties_container.get_node("Position/X").set_value_no_signal(node.position.x)
		properties_container.get_node("Position/X").get_line_edit().text = str(node.position.x)
		properties_container.get_node("Position/Y").editable = true
		properties_container.get_node("Position/Y").set_value_no_signal(node.position.y)
		properties_container.get_node("Position/Y").get_line_edit().text = str(node.position.y)
	elif selected.size() > 1:
		name_label.text = str(selected.size()) + " nodes"
		properties_container.get_node("Position/X").editable = false
		properties_container.get_node("Position/X").set_value_no_signal(0)
		properties_container.get_node("Position/X").get_line_edit().text = "*"
		properties_container.get_node("Position/Y").editable = false
		properties_container.get_node("Position/Y").set_value_no_signal(0)
		properties_container.get_node("Position/Y").get_line_edit().text = "*"
	
	for property in properties:
		var value = node_manager.nodes[selected[0]].tags.get(property.key)
		var diff: bool = false
		for index in selected:
			var node = node_manager.nodes[index]
			if node.tags.get(property.key) != value:
				diff = true
				break
		match property.type:
			"option":
				if diff:
					property.control.select(-1)
					property.control.text = "*"
				else:
					var i: int = 0
					for item in property.options:
						if item.value == value:
							property.control.select(i)
							break
						i += 1

func _on_position_x_value_changed(value: float) -> void:
	node_manager.nodes[node_manager.selected[0]].position.x = value
	node_manager.update_history()
	node_manager.redraw()

func _on_position_y_value_changed(value: float) -> void:
	node_manager.nodes[node_manager.selected[0]].position.y = value
	node_manager.update_history()
	node_manager.redraw()

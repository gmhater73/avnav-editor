extends Node

@export var port: int = 28628

var server: TCPServer = TCPServer.new()
var clients: Array[StreamPeerTCP] = []

var method_regex: RegEx = RegEx.new()
var header_regex: RegEx = RegEx.new()

signal incoming_request(request: Request)

func _ready() -> void:
	set_process(false)
	method_regex.compile("^(?<method>GET|POST|HEAD|PUT|PATCH|DELETE|OPTIONS) (?<path>[^ ]+) HTTP/1.1$")
	header_regex.compile("^(?<key>[\\w-]+): (?<value>(.*))$")

class Request:
	var client: StreamPeerTCP
	var method: String
	var path: String
	var query: Dictionary
	var headers: Dictionary
	var body: String
	
	func send(data: String = "") -> void:
		client.put_data("HTTP/1.1 200 OK\r\n".to_ascii_buffer())
		client.put_data("Server: AVNAV\r\n".to_ascii_buffer())
		client.put_data("Connection: close\r\n".to_ascii_buffer())
		client.put_data(("Content-Length: " + str(data.length()) + "\r\n").to_ascii_buffer())
		client.put_data("\r\n".to_ascii_buffer())
		client.put_data(data.to_ascii_buffer())

func _process(_delta: float) -> void:
	if server:
		var new_client: StreamPeerTCP = server.take_connection()
		if new_client:
			clients.append(new_client)
		for client in clients:
			if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
				var bytes: int = client.get_available_bytes()
				if bytes > 0:
					var request_string: String = client.get_string(bytes)
					var request: Request = Request.new()
					request.client = client
					for line in request_string.split("\r\n"):
						var method_matches = method_regex.search(line)
						var header_matches = header_regex.search(line)
						if method_matches:
							request.method = method_matches.get_string("method")
							var request_path: String = method_matches.get_string("path")
							if not "?" in request_path:
								request.path = request_path
							else:
								var path_query: PackedStringArray = request_path.split("?")
								request.path = path_query[0]
								var query: Dictionary = {}
								var parameters: Array = path_query[1].split("&")
								for param in parameters:
									if not "=" in param: continue
									var kv: PackedStringArray = param.split("=")
									var value: String = kv[1]
									if value.is_valid_int():
										query[kv[0]] = int(value)
									elif value.is_valid_float():
										query[kv[0]] = float(value)
									else:
										query[kv[0]] = value
								request.query = query
							request.headers = {}
							request.body = ""
						elif header_matches:
							request.headers[header_matches.get_string("key")] = \
							header_matches.get_string("value")
						else:
							request.body += line
					incoming_request.emit(request)

func start() -> int:
	set_process(true)
	var error: int = server.listen(port, "127.0.0.1")
	match error:
		22:
			print("Port ", port, " in use")
			stop()
		_:
			print("Server started on port ", port)
	return error

func stop():
	for client in clients: client.disconnect_from_host()
	clients.clear()
	server.stop()
	set_process(false)
	print("Server stopped")

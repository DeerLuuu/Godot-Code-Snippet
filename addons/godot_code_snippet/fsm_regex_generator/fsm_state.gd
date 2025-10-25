class_name FSMState
var id: int
var transitions: Dictionary  # Char -> Array[FSMState]
var is_final: bool

func _init(state_id: int):
	id = state_id
	transitions = {}
	is_final = false

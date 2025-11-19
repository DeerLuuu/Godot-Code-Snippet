class_name TrieNode
var char: String
var children: Dictionary
var is_end: bool

func _init(c: String = ""):
	char = c
	children = {}
	is_end = false

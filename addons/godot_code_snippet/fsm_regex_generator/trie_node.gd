class_name TrieNode
var char: String
var children: Dictionary
var is_end: bool
var type: String

func _init(c: String = ""):
	char = c
	children = {}
	is_end = false
	type = _get_char_type(c)

func _get_char_type(c: String) -> String:
	if c.is_empty():  return "root"
	if c.unicode_at(0)  >= 48 and c.unicode_at(0)  <= 57:
		return "digit"
	if c.unicode_at(0)  >= 65 and c.unicode_at(0)  <= 90:
		return "alpha"
	if c.unicode_at(0)  >= 97 and c.unicode_at(0)  <= 122:
		return "alpha"
	return "other"

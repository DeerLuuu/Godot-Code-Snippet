@tool
extends EditorPlugin

# NOTE 代码编辑器
var script_editor: ScriptEditor
var snippets : Dictionary

func _enter_tree() -> void:
	update_code_block_dic()
	script_editor = EditorInterface.get_script_editor()
	script_editor.editor_script_changed.connect(_on_script_changed)
	script_editor.editor_script_changed.emit(script_editor.get_current_script())

func _exit_tree() -> void:
	pass

# FUNC 更新自定义代码片段
func update_code_block_dic() -> void:
	snippets = preload("res://custom_codes/my_code.json").data

func _on_script_changed(script : Script) -> void:
	update_code_block_dic()
	var current_editor = script_editor.get_current_editor()
	if not current_editor: return
	var code_edit = _find_code_edit(current_editor)
	if not code_edit: return
	# 自定义代码段的补全相关信号链接
	if code_edit.code_completion_requested.is_connected(_on_code_completion_requested):
		code_edit.code_completion_requested.disconnect(_on_code_completion_requested)
	code_edit.code_completion_requested.connect(_on_code_completion_requested.bind(code_edit))

# FUNC 激活自动补全时的信号方法
func _on_code_completion_requested(code_edit : CodeEdit):
	var line_text : String = get_current_line_text(code_edit)
	if line_text.contains("\"") or line_text.contains("\'"): return
	var prefix = _get_selected_text(code_edit)
	for keyword in snippets:
		if keyword.begins_with(prefix):
			# 添加自定义补全项
			code_edit.add_code_completion_option(
				CodeEdit.KIND_FUNCTION,
				keyword,
				snippets[keyword],
				Color.AQUA
				)

# FUNC 获取当前行代码
func get_current_line_text(_code_edit: CodeEdit) -> String:
	return _code_edit.get_line(_code_edit.get_caret_line())

# FUNC 获取光标所在的字段
func get_word_under_cursor(code_edit: CodeEdit) -> String:
	var caret_line = code_edit.get_caret_line()
	var caret_column = code_edit.get_caret_column()
	var line_text = code_edit.get_line(caret_line)

	var start = caret_column
	while start > 0 and line_text[start - 1].is_subsequence_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"):
		start -= 1

	var end = caret_column
	while end < line_text.length() and line_text[end].is_subsequence_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"):
		end += 1

	return line_text.substr(start, end - start)

# FUNC 获取选择的字段
func _get_selected_text(_code_edit: CodeEdit) -> String:
	var selected_text : String = _code_edit.get_selected_text().strip_edges()
	if selected_text.is_empty():
		selected_text = get_word_under_cursor(_code_edit)
	return selected_text

# FUNC 查找代码编辑器
func _find_code_edit(node: Node) -> CodeEdit:
	if node is CodeEdit: return node
	for child in node.get_children():
		var result = _find_code_edit(child)
		if result: return result
	return null

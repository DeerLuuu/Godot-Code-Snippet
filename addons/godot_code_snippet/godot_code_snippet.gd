@tool
extends EditorPlugin

# NOTE 代码编辑器
var script_editor: ScriptEditor
var config : Dictionary
var default : Dictionary
var snippets : Dictionary

func _enter_tree() -> void:
	update_code_block_dic()
	script_editor = EditorInterface.get_script_editor()
	script_editor.editor_script_changed.connect(_on_script_file_changed)
	script_editor.editor_script_changed.emit(script_editor.get_current_script())
	var fl = EditorInterface.get_resource_filesystem()
	fl.filesystem_changed.connect(fs_update)

func _exit_tree() -> void:
	script_editor = null
	default = {}
	snippets = {}
	config = {}

func fs_update() -> void:
	var all_script_path : Array[String] = get_all_script_path()
	for i in all_script_path:
		var file = FileAccess.open(i, FileAccess.READ)
		var script_lines : Array = file.get_as_text().split("\n")
		for line in script_lines:
			check_script_has_auto_tip(line)

# FUNC 更新自定义代码片段
func update_code_block_dic() -> void:
	default = preload("res://addons/godot_code_snippet/config.json").data["my_custom_codes"]

func _on_script_file_changed(script : Script) -> void:
	update_code_block_dic()
	var current_editor = script_editor.get_current_editor()
	if not current_editor: return
	var code_edit : CodeEdit = _find_code_edit(current_editor)
	if not code_edit: return
	# 自定义代码段的补全相关信号链接
	if code_edit.code_completion_requested.is_connected(_on_code_completion_requested):
		code_edit.code_completion_requested.disconnect(_on_code_completion_requested)
	code_edit.code_completion_requested.connect(_on_code_completion_requested.bind(code_edit))

# FUNC 激活自动补全时的信号方法
func _on_code_completion_requested(code_edit : CodeEdit):
	var line_text : String = get_current_line_text(code_edit)
	var prefix = _get_selected_text(code_edit)
	if line_text.contains("\"") or line_text.contains("\'"):
		if not line_text.contains("subscribe("): return
		if snippets.is_empty(): return
		for keyword in snippets:
			code_edit.add_code_completion_option(
				CodeEdit.KIND_FUNCTION,
				keyword,
				snippets[keyword],
				Color.AQUA
				)
		return
	if default.is_empty(): return
	for keyword in default:
		# 添加自定义补全项
		code_edit.add_code_completion_option(
			CodeEdit.KIND_FUNCTION,
			keyword,
			default[keyword],
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

# FUNC 获取所有脚本路径
func get_all_script_path() -> Array[String]:
	var r : Array[String]
	var fs = get_editor_interface().get_resource_filesystem()
	var fs_path = fs.get_filesystem()
	r = _traverse_fs(fs_path)
	return r

# FUNC 遍历文件系统的文件夹以获取路径
func _traverse_fs(dir : EditorFileSystemDirectory) -> Array[String]:
	var r : Array[String] = []
	for i in dir.get_file_count():
		var path = dir.get_file_path(i)
		if path.get_extension() in ["gd"]:
			r.append(path)
	for i in dir.get_subdir_count():
		r.append_array(_traverse_fs(dir.get_subdir(i)))
	return r

# FUNC 根据特定格式将一些关键词添加到自动提示中
func check_script_has_auto_tip(line : String) -> void:
	config = preload("res://addons/godot_code_snippet/config.json").data["config"]
	if not config["auto_add_reg_ex_enabled"]: return
	var regex : RegEx = RegEx.new()
	for rule in config["auto_add_reg_ex"].values():
		regex.compile(rule[0])
		var result = regex.search(line)
		if result:
			var str : String = result.get_string().remove_chars(" ").trim_prefix(rule[1])
			snippets[str] = "event:" + str
			print(str)

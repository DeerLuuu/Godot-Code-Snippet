class_name FSMRegexGenerator

var _trie_root: TrieNode
var _state_counter: int = 0
var _fsm_states: Array = []

# 主入口：生成正则表达式
func generate(strings: Array) -> String:
	if strings.is_empty():
		return ""

	# 去重并过滤空字符串
	var clean_strings: Array = []
	for s in strings:
		if typeof(s) == TYPE_STRING and not s.is_empty() and not clean_strings.has(s):
			clean_strings.append(s)

	if clean_strings.is_empty():
		return ""
	if clean_strings.size() == 1:
		return _escape_regex(clean_strings[0])

	# === 启发式规则 1：固定前缀 + 尾部 \w+ ===
	var lcp: String = _compute_longest_common_prefix(clean_strings)
	if lcp.length() > 0:
		var all_suffixes_valid := true
		var has_nonempty_suffix := false
		for s in clean_strings:
			if not s.begins_with(lcp):
				all_suffixes_valid = false
				break
			var suffix: String = s.substr(lcp.length())
			if suffix.is_empty():
				continue
			has_nonempty_suffix = true
			if not _is_word_string(suffix):
				all_suffixes_valid = false
				break

		# 只有当所有非空前缀都符合 \w+，且至少有一个非空，才使用 \w+
		if all_suffixes_valid and has_nonempty_suffix:
			# 检查是否所有后缀都非空？或者允许混合？
			# 为安全：仅当**所有后缀都非空**才用 \w+
			var all_nonempty := true
			for s in clean_strings:
				if s.substr(lcp.length()).is_empty():
					all_nonempty = false
					break
			if all_nonempty:
				return _escape_regex(lcp) + "\\w+"
			else:
				# 混合情况：如 ["item:", "item:abc"] → item:(?:|\w+)
				return _escape_regex(lcp) + "(?:|\\w+)"

	# === 启发式规则 2：固定前缀 + 尾部 \d+ （可选扩展）===
	# 可类似实现，此处略

	# === 回退到 Trie 方法 ===
	_build_trie(clean_strings)
	_convert_trie_to_fsm()
	return _generate_regex_from_fsm()


# 构建Trie树
func _build_trie(strings: Array) -> void:
	_trie_root = TrieNode.new()
	for s in strings:
		var node: TrieNode = _trie_root
		for i in range(s.length()):
			var c: String = s.substr(i, 1)
			if not node.children.has(c):
				node.children[c] = TrieNode.new(c)
			node = node.children[c]
		node.is_end = true


# 转换Trie为FSM
func _convert_trie_to_fsm() -> void:
	_state_counter = 0
	_fsm_states = []
	_add_fsm_state(_trie_root)


func _add_fsm_state(trie_node: TrieNode) -> FSMState:
	var state: FSMState = FSMState.new(_state_counter)
	_state_counter += 1
	_fsm_states.append(state)
	state.is_final = trie_node.is_end

	for c in trie_node.children:
		var child_node: TrieNode = trie_node.children[c]
		var child_state: FSMState = _add_fsm_state(child_node)
		var trans_key: String = _generalize_char(c)

		if not state.transitions.has(trans_key):
			state.transitions[trans_key] = []
		state.transitions[trans_key].append(child_state)

	return state


func _generalize_char(c: String) -> String:
	if c.length() != 1:
		return _escape_regex(c)
	var ch = c.unicode_at(0)
	if ch >= 48 and ch <= 57:  # '0'-'9'
		return "\\d"
	elif (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch == 95:  # A-Z, a-z, _
		return "\\w"
	else:
		return _escape_regex(c)


func _generate_regex_from_fsm() -> String:
	if _fsm_states.is_empty():
		return ""
	return _visit_state(_fsm_states[0], [])


func _visit_state(state: FSMState, visited: Array) -> String:
	if state.id in visited:
		return ""  # Trie 无环，安全返回

	visited.append(state.id)
	var expressions: Array = []

	for trans_key in state.transitions:
		var paths: Array = []
		for target in state.transitions[trans_key]:
			var sub = _visit_state(target, visited.duplicate())
			if sub == "":
				paths.append(trans_key)
			else:
				paths.append(trans_key + sub)

		if paths.size() == 1:
			expressions.append(paths[0])
		else:
			expressions.append("(?:%s)" % "|".join(paths))

	var result: String
	if expressions.size() == 0:
		result = ""
	elif expressions.size() == 1:
		result = expressions[0]
	else:
		result = "(?:%s)" % "|".join(expressions)

	if state.is_final:
		if result == "":
			return ""
		else:
			return "(?:%s)?" % result  # 使用 ? 表示可选（比 |ε 更标准）
	else:
		return result


# ====== 工具函数 ======

func _compute_longest_common_prefix(strings: Array) -> String:
	if strings.size() == 0:
		return ""
	var prefix: String = strings[0]
	for i in range(1, strings.size()):
		var s: String = strings[i]
		var common_len: int = 0
		var min_len: int = min(prefix.length(), s.length())
		for j in range(min_len):
			if prefix[j] == s[j]:
				common_len += 1
			else:
				break
		prefix = prefix.substr(0, common_len)
		if prefix.is_empty():
			break
	return prefix


func _is_word_string(s: String) -> bool:
	if s.is_empty():
		return false
	for i in range(s.length()):
		var c: String = s.substr(i, 1)
		var ch = c.unicode_at(0)
		if not ((ch >= 48 and ch <= 57) or (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch == 95):
			return false
	return true


func _escape_regex(s: String) -> String:
	if s.is_empty():
		return ""
	var result: String = ""
	for i in range(s.length()):
		var c: String = s.substr(i, 1)
		if ".?*+[](){}|^$\\".find(c) != -1:
			result += "\\" + c
		else:
			result += c
	return result

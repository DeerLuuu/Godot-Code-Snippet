class_name FSMRegexGenerator

var _trie_root: TrieNode
var _state_counter: int = 0
var _fsm_states: Array = []

# 生成正则表达式
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

	# 计算最长公共前缀
	var lcp: String = _compute_longest_common_prefix(clean_strings)

	# 特殊处理 event: 前缀
	if lcp == "event:":
		var suffixes = []
		for s in clean_strings:
			suffixes.append(s.substr(5))  # 跳过"event:"

		# 检查是否都符合 event:word(:word)* 模式
		var all_valid_suffixes = true
		for suffix in suffixes:
			if not _is_valid_event_suffix(suffix):
				all_valid_suffixes = false
				break

		if all_valid_suffixes:
			return "event:\\w+(?::\\w+)*"

		# 否则生成交替模式
		return "event:" + _generate_alternatives(suffixes)

	# 检查最长公共前缀后的模式
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
			# 检查是否所有后缀都非空
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

	# 检查最长公共后缀
	var lcs = _compute_longest_common_suffix(clean_strings)
	if lcs.length() > 0 and lcp.length() == 0:
		var prefixes = []
		for s in clean_strings:
			prefixes.append(s.substr(0, s.length() - lcs.length()))
		return _generate_alternatives(prefixes) + _escape_regex(lcs)

	# 检查 word_number 模式（针对示例3）
	var has_word_number_pattern = true
	var digit_lengths = []
	var word_prefixes = []
	for s in clean_strings:
		var underscore_pos = s.find("_")
		if underscore_pos <= 0 or underscore_pos == s.length() - 1:
			has_word_number_pattern = false
			break

		var prefix = s.substr(0, underscore_pos)
		if not _is_word_string(prefix):
			has_word_number_pattern = false
			break

		var suffix = s.substr(underscore_pos + 1)
		if suffix.is_empty():
			has_word_number_pattern = false
			break

		var is_all_digits = true
		for i in range(suffix.length()):
			if not _is_valid_digit(suffix.substr(i, 1)):
				is_all_digits = false
				break

		if not is_all_digits:
			has_word_number_pattern = false
			break

		word_prefixes.append(prefix)
		digit_lengths.append(suffix.length())

	if has_word_number_pattern:
		# 检查数字部分是否长度相同
		var same_digit_length = true
		var first_len = digit_lengths[0]
		for l in digit_lengths:
			if l != first_len:
				same_digit_length = false
				break

		var prefix_regex = _generate_alternatives(word_prefixes)
		if same_digit_length:
			return prefix_regex + "_\\d{" + str(first_len) + "}"
		else:
			return prefix_regex + "_\\d+"

	# 检查数字前缀模式
	var has_number_suffix_pattern = true
	var prefixes = []
	var num_lengths = []
	for s in clean_strings:
		var num_suffix = ""
		var i = s.length() - 1
		while i >= 0 and _is_valid_digit(s.substr(i, 1)):
			num_suffix = s.substr(i, 1) + num_suffix
			i -= 1

		if num_suffix.is_empty() or i < 0:
			has_number_suffix_pattern = false
			break

		prefixes.append(s.substr(0, i + 1))
		num_lengths.append(num_suffix.length())

	if has_number_suffix_pattern:
		var same_num_length = true
		var first_len = num_lengths[0]
		for l in num_lengths:
			if l != first_len:
				same_num_length = false
				break

		var prefix_regex = _generate_alternatives(prefixes)
		if same_num_length:
			return prefix_regex + "\\d{" + str(first_len) + "}"
		else:
			return prefix_regex + "\\d+"

	# 通用情况：构建Trie
	_build_trie(clean_strings)
	_convert_trie_to_fsm()
	var regex = _generate_regex_from_fsm()
	return _optimize_regex(regex)


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
			return "(?:%s)?" % result
	else:
		return result


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


func _compute_longest_common_suffix(strings: Array) -> String:
	if strings.size() == 0:
		return ""
	var suffix: String = strings[0]
	for i in range(1, strings.size()):
		var s: String = strings[i]
		var common_len: int = 0
		var min_len: int = min(suffix.length(), s.length())
		for j in range(1, min_len + 1):
			if suffix[suffix.length() - j] == s[s.length() - j]:
				common_len += 1
			else:
				break
		suffix = suffix.substr(suffix.length() - common_len, common_len)
		if suffix.is_empty():
			break
	return suffix


func _is_word_string(s: String) -> bool:
	if s.is_empty():
		return false
	for i in range(s.length()):
		var c: String = s.substr(i, 1)
		var ch = c.unicode_at(0)
		if not ((ch >= 48 and ch <= 57) or (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch == 95):
			return false
	return true


func _is_valid_digit(char: String) -> bool:
	var code = char.unicode_at(0)
	return code >= 48 and code <= 57  # '0' to '9'


func _is_valid_event_suffix(s: String) -> bool:
	if s.is_empty():
		return false

	# 允许的字符: 字母、数字、下划线、冒号
	for i in range(s.length()):
		var c = s.substr(i, 1)
		var ch = c.unicode_at(0)
		if not ((ch >= 48 and ch <= 57) or  # 0-9
				(ch >= 65 and ch <= 90) or  # A-Z
				(ch >= 97 and ch <= 122) or  # a-z
				ch == 95 or  # _
				ch == 58):   # :
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


func _generate_alternatives(strings: Array) -> String:
	if strings.size() == 1:
		return _escape_regex(strings[0])

	# 去重
	var unique_strings = []
	for s in strings:
		if not unique_strings.has(s):
			unique_strings.append(s)

	# 如果只有少量短字符串，直接使用交替
	if unique_strings.size() <= 3 and _max_string_length(unique_strings) <= 5:
		var escaped = []
		for s in unique_strings:
			escaped.append(_escape_regex(s))
		return "(?:" + "|".join(escaped) + ")"

	# 否则构建子trie
	_build_trie(unique_strings)
	_convert_trie_to_fsm()
	return _generate_regex_from_fsm()


func _max_string_length(strings: Array) -> int:
	var max_len = 0
	for s in strings:
		if s.length() > max_len:
			max_len = s.length()
	return max_len


func _optimize_regex(regex: String) -> String:
	if regex.is_empty():
		return regex

	# 1. 优化重复的字符类
	regex = _optimize_repetitions(regex)

	# 2. 简化冗余分组
	regex = _simplify_redundant_groups(regex)

	# 3. 合并相邻的相同字符类
	regex = _merge_adjacent_classes(regex)

	return regex


func _optimize_repetitions(regex: String) -> String:
	if regex.is_empty():
		return regex

	var result = regex

	# 优化 \w 重复
	var match = RegEx.new()
	if match.compile("(\\\\w)(\\\\1)+") == OK:
		var matches = match.search_all(result)
		# 从后往前替换，避免索引偏移
		for i in range(matches.size() - 1, -1, -1):
			var m = matches[i]
			var full_match = m.get_string()
			var count = full_match.length() / 2  # 每个\w占2个字符
			if count >= 2:  # 只优化2次或以上的重复
				var replacement = "\\w{" + str(count) + "}"
				result = result.substr(0, m.get_start()) + replacement + result.substr(m.get_end())

	# 优化 \d 重复
	if match.compile("(\\\\d)(\\\\1)+") == OK:
		var matches = match.search_all(result)
		for i in range(matches.size() - 1, -1, -1):
			var m = matches[i]
			var full_match = m.get_string()
			var count = full_match.length() / 2
			if count >= 2:
				var replacement = "\\d{" + str(count) + "}"
				result = result.substr(0, m.get_start()) + replacement + result.substr(m.get_end())

	# 优化 [a-z] 重复等（简化版）
	if match.compile("(\\[a-z\\])(\\1)+") == OK:
		var matches = match.search_all(result)
		for i in range(matches.size() - 1, -1, -1):
			var m = matches[i]
			var full_match = m.get_string()
			var count = (full_match.length() + 1) / 5  # 每个[a-z]占5个字符
			if count >= 2:
				var replacement = "[a-z]{" + str(count) + "}"
				result = result.substr(0, m.get_start()) + replacement + result.substr(m.get_end())

	return result


func _simplify_redundant_groups(regex: String) -> String:
	var match = RegEx.new()
	# 简化 (?:x) -> x 当x不含|?*+等特殊字符时
	if match.compile("\\(\\?:([^()|*+?]+)\\)") == OK:
		var result = regex
		var matches = match.search_all(result)
		for i in range(matches.size() - 1, -1, -1):
			var m = matches[i]
			var content = m.get_string(1)
			result = result.substr(0, m.get_start()) + content + result.substr(m.get_end())
		return result
	return regex


func _merge_adjacent_classes(regex: String) -> String:
	# 合并相邻的 \w 和 [a-zA-Z0-9_]
	var match = RegEx.new()
	if match.compile("\\\\w\\\\w") == OK:
		var result = regex
		var matches = match.search_all(result)
		while not matches.is_empty():
			result = result.replace("\\w\\w", "\\w{2}")
			matches = match.search_all(result)
		return result
	return regex

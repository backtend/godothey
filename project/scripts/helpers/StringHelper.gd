class_name StringHelper
extends RefCounted

## 判断字符串是否为空或只有空白字符
static func is_blank(text: String) -> bool:
	return text.strip_edges().is_empty()


## 判断字符串是否不为空
static func is_not_blank(text: String) -> bool:
	return not is_blank(text)


## 安全截取字符串，超出长度时加省略号
## 示例：truncate("星露谷物语", 4) → "星露谷..."
static func truncate(text: String, max_length: int, ellipsis := "...") -> String:
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length) + ellipsis


## 首字母大写（只处理第一个字符）
static func capitalize_first(text: String) -> String:
	if text.is_empty():
		return text
	return text[0].to_upper() + text.substr(1)


## 每个单词首字母大写（Title Case）
static func to_title_case(text: String) -> String:
	var words := text.split(" ", false)
	for i in words.size():
		if not words[i].is_empty():
			words[i] = capitalize_first(words[i].to_lower())
	return " ".join(words)


## 转成蛇形命名（snake_case）
## 示例：to_snake_case("HelloWorld") → "hello_world"
static func to_snake_case(text: String) -> String:
	var result := ""
	for i in text.length():
		var c := text[i]
		if c >= "A" and c <= "Z":
			if i > 0:
				result += "_"
			result += c.to_lower()
		else:
			result += c
	return result


## 转成小驼峰（camelCase）
## 示例：to_camel_case("hello_world") → "helloWorld"
static func to_camel_case(text: String) -> String:
	var parts := text.split("_", false)
	if parts.is_empty():
		return text
	var result := parts[0].to_lower()
	for i in range(1, parts.size()):
		result += capitalize_first(parts[i].to_lower())
	return result


## 转成大驼峰（PascalCase）
static func to_pascal_case(text: String) -> String:
	return capitalize_first(to_camel_case(text))


## 左侧补齐
## 示例：pad_left("42", 5, "0") → "00042"
static func pad_left(text: String, length: int, pad_char := " ") -> String:
	if text.length() >= length:
		return text
	return pad_char.repeat(length - text.length()) + text


## 右侧补齐
static func pad_right(text: String, length: int, pad_char := " ") -> String:
	if text.length() >= length:
		return text
	return text + pad_char.repeat(length - text.length())


## 移除前缀（如果存在）
static func remove_prefix(text: String, prefix: String) -> String:
	if text.begins_with(prefix):
		return text.substr(prefix.length())
	return text


## 移除后缀（如果存在）
static func remove_suffix(text: String, suffix: String) -> String:
	if text.ends_with(suffix):
		return text.substr(0, text.length() - suffix.length())
	return text


## 批量替换
## 示例：replace_many("Hello {name}", {"{name}": "Grok"})
static func replace_many(text: String, replacements: Dictionary) -> String:
	var result := text
	for key in replacements:
		result = result.replace(str(key), str(replacements[key]))
	return result


## 生成指定长度的随机字符串
static func random_string(length: int, chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") -> String:
	if length <= 0 or chars.is_empty():
		return ""
	var result := ""
	for i in length:
		result += chars[randi() % chars.length()]
	return result


## 简单判断是否像邮箱格式
static func is_email(text: String) -> bool:
	var regex := RegEx.new()
	regex.compile(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
	return regex.search(text) != null


## 把多行文本统一缩进
static func indent(text: String, spaces: int = 4) -> String:
	var prefix := " ".repeat(spaces)
	var lines := text.split("\n")
	for i in lines.size():
		if not lines[i].is_empty():
			lines[i] = prefix + lines[i]
	return "\n".join(lines)


## 安全获取字符串，null 或空时返回默认值
static func default_if_blank(text: String, default_value: String = "") -> String:
	return default_value if is_blank(text) else text
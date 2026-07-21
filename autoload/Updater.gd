extends Node

var upgrade_mode: int = 0
var title: String = ""
var intro: String = ""
var version_name: String = ""
var version_code: int = 0
var zip_url: String = ""
var zip_name: String = ""
var zip_hash: String = ""
var dist_name: String = ""

func set_from_data(data: Dictionary) -> void:
    upgrade_mode = data.get("upgrade_mode", 0)
    title = data.get("title", "")
    intro = data.get("intro", "")
    version_name = data.get("version_name", "")
    version_code = data.get("version_code", 0)
    zip_url = data.get("zip_url", "")
    zip_name = data.get("zip_name", "")
    zip_hash = data.get("zip_hash", "")
    dist_name = data.get("dist_name", "")
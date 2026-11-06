extends RefCounted
# Loaded by gameplay AFTER Bootstrap mounts local PCKs. No gameplay Autoload:
# new and changed gameplay scripts must remain patchable on existing APKs.
static func ensure_session(tree: SceneTree) -> Node:
	var session := tree.root.get_node_or_null("GameSession")
	if session == null:
		var script: Script = load("res://scripts/game/GameSession.gd")
		session = script.new()
		session.name = "GameSession"
		tree.root.add_child(session)
	return session

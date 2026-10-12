class_name LiveBridge
extends Node

## Local command bridge: lets a separate Python process (TikTok LIVE
## connector or the simulator) trigger existing gameplay systems.
##
## Transport: plain TCP on 127.0.0.1 (loopback only), newline-delimited
## JSON, one message per line. Godot 4 ships no WebSocket-server class,
## so TCP keeps this dependency-free on both ends.
##
## Accepted inbound messages:
##   {"type":"ping"}
##   {"type":"status"}
##   {"type":"gift","gift_name":"Rose","username":"viewer123","count":1}
##   {"type":"command","command":"rapid_fire","username":"viewer123","count":1}
##
## Boss summons ("galaxy"/"lion" gifts, summon_boss command): exactly one
## completed gift creates exactly one queue entry (message `count` is
## ignored). Entries spawn sequentially while fewer than 3 bosses live
## (max boss_queue_max); replies carry status queued/summoned or an
## explicit queue_full error. Optional `event_id` values deduplicate
## retried deliveries.
##
## Replies (best effort, same framing): {"type":"pong",...} or
## {"type":"result","ok":true/false,...}.
##
## Safety: explicit command allowlist, per-command cooldowns, 4 KB message
## cap, 20 commands/sec rate limit, loopback bind only. Incoming data is
## only ever matched against the allowlist — never executed.

signal command_accepted(command: String, username: String)
signal command_rejected(reason: String)

const MAX_MESSAGE_BYTES := 4096
const MAX_BUFFER_BYTES := 65536
const MAX_COMMANDS_PER_SECOND := 20

const MESSAGE_TYPES: Array[String] = ["ping", "status", "gift", "command"]

const COMMAND_ALLOWLIST: Array[String] = [
	"rapid_fire", "giant_gun",
	"weapon_minigun", "weapon_rocket", "weapon_machinegun", "weapon_default",
	"mega_laser", "spawn_wave", "summon_boss", "debug_kill_boss", "debug_heal",
]

# Recently processed gift/command IDs for exactly-once handling of retried
# bridge messages. Bounded + TTL-expired so it cannot grow forever.
const MAX_SEEN_IDS := 500
const SEEN_ID_TTL_MSEC := 600000
const MAX_EVENT_ID_CHARS := 128

@export var bridge_enabled: bool = true
@export var port: int = 8765
## Gift name (lowercase) -> game command. Edit in the Inspector or, for
## LIVE use, in tools/tiktok_bridge/gift_mapping.json (same keys).
@export var gift_map: Dictionary = {
	"rose": "rapid_fire",
	"gg": "giant_gun",
	"tiktok": "spawn_wave",
	"money gun": "weapon_minigun",
	"sports car": "weapon_rocket",
	"galaxy": "summon_boss",
	"lion": "summon_boss",
	"universe": "mega_laser",
}
## Per-command cooldowns in seconds (anti gift-spam). Inspector-editable.
@export var command_cooldowns: Dictionary = {
	"rapid_fire": 8.0,
	"giant_gun": 20.0,
	"weapon_minigun": 5.0,
	"weapon_rocket": 5.0,
	"weapon_machinegun": 5.0,
	"weapon_default": 5.0,
	"mega_laser": 10.0,
	"spawn_wave": 5.0,
}
## summon_boss has no bridge cooldown: Galaxy gifts queue instead of being
## discarded (the game's boss-cap rules still apply).
@export var boss_queue_max: int = 100
@export var wave_enemies_per_gift: int = 2
@export var wave_max_enemies: int = 10

var _server := TCPServer.new()
var _listening: bool = false
var _peer: StreamPeerTCP = null
var _buffer := PackedByteArray()
var _recent_cmd_msec: Array[int] = []
var _cooldowns: Dictionary = {}
# Queued boss summons: each entry is {"username": String}. Entries are only
# removed after spawn_boss() succeeds, so no accepted gift is ever lost.
var _boss_queue: Array[Dictionary] = []
var _pump_retry: float = 0.0
var _just_spawned: bool = false
var _shown_active: int = -1
var _shown_queued: int = -1
var _seen_ids: Dictionary = {}
var _pump_wait_logged: bool = false
var _was_running: bool = false
var _last_boss_count: int = -1

func _ready() -> void:
	add_to_group("live_bridge")

func _process(delta: float) -> void:
	_tick_cooldowns(delta)
	if _pump_retry > 0.0:
		_pump_retry -= delta
	_watch_game_running()
	if not _boss_queue.is_empty():
		_pump_boss_queue()
	_update_boss_hud()
	if not bridge_enabled:
		return
	if not _listening:
		var err := _server.listen(port, "127.0.0.1")
		if err == OK:
			_listening = true
			print("[LiveBridge] listening on 127.0.0.1:%d" % port)
		else:
			print("[LiveBridge] listen failed on port %d (err %d), retrying..." % [port, err])
			return
	if _server.is_connection_available():
		_accept_peer()
	_poll_peer()

# ------------------------------------------------------------- networking --

func _accept_peer() -> void:
	var fresh := _server.take_connection()
	if fresh == null:
		return
	if _peer != null and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		print("[LiveBridge] replacing stale connector connection")
		_peer.disconnect_from_host()
	_peer = fresh
	_buffer.clear()
	print("[LiveBridge] connector connected")

func _poll_peer() -> void:
	if _peer == null:
		return
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		print("[LiveBridge] connector disconnected")
		_peer = null
		_buffer.clear()
		return
	var available := _peer.get_available_bytes()
	if available <= 0:
		return
	if _buffer.size() + available > MAX_BUFFER_BYTES:
		print("[LiveBridge] buffer overflow, dropping connector")
		_peer.disconnect_from_host()
		_peer = null
		_buffer.clear()
		return
	var res := _peer.get_data(available)
	if res[0] != OK:
		return
	_buffer.append_array(res[1])
	_drain_lines()

func _drain_lines() -> void:
	while true:
		var nl := _buffer.find(10)  # '\n'
		if nl < 0:
			return
		var line := _buffer.slice(0, nl)
		_buffer = _buffer.slice(nl + 1)
		_handle_line(line)

func _send(obj: Dictionary) -> void:
	if _peer == null or _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var err := _peer.put_data((JSON.stringify(obj) + "\n").to_utf8_buffer())
	if err != OK:
		print("[LiveBridge] reply send failed (err %d)" % err)

# ----------------------------------------------------------------- intake --

func _handle_line(line: PackedByteArray) -> void:
	if line.size() > MAX_MESSAGE_BYTES:
		_reject("message_too_large")
		return
	var parsed: Variant = JSON.parse_string(line.get_string_from_utf8())
	if not (parsed is Dictionary):
		_reject("malformed_json")
		return
	var msg: Dictionary = parsed
	var mtype := str(msg.get("type", ""))
	if mtype == "":
		_reject("missing_type")
		return
	if not (mtype in MESSAGE_TYPES):
		_reject("unknown_type")
		return
	if mtype == "ping":
		_send({"type": "pong", "game_running": _is_game_running()})
		return
	if mtype == "status":
		_send(_status_obj())
		return
	if not _check_rate():
		_reject("rate_limited")
		return
	var username := str(msg.get("username", "viewer"))
	var count := clampi(int(msg.get("count", 1)), 1, 99)
	var event_id := str(msg.get("event_id", "")).strip_edges().left(MAX_EVENT_ID_CHARS)
	# Retried deliveries reuse the sender's event_id: reject repeats before
	# any rate budget, cooldown, or game effect is consumed.
	if event_id != "" and _is_duplicate(event_id):
		_send({"type": "result", "ok": false, "error": "duplicate_event"})
		print("[LiveBridge] duplicate event ignored: %s" % event_id)
		return
	if mtype == "gift":
		_handle_gift(str(msg.get("gift_name", "")), username, count, event_id)
	else:
		_handle_command(str(msg.get("command", "")), username, count, event_id)

func _check_rate() -> bool:
	var now := Time.get_ticks_msec()
	while not _recent_cmd_msec.is_empty() and now - _recent_cmd_msec[0] > 1000:
		_recent_cmd_msec.pop_front()
	if _recent_cmd_msec.size() >= MAX_COMMANDS_PER_SECOND:
		return false
	_recent_cmd_msec.append(now)
	return true

func _handle_gift(gift_name: String, username: String, count: int, event_id: String = "") -> void:
	var key := gift_name.strip_edges().to_lower()
	if key == "" or not gift_map.has(key):
		_send({"type": "result", "ok": false, "error": "unmapped_gift", "gift_name": gift_name})
		print("[LiveBridge] unmapped gift ignored: '%s' from %s" % [gift_name, username])
		return
	_handle_command(str(gift_map[key]), username, count, event_id)

func _is_duplicate(event_id: String) -> bool:
	if not _seen_ids.has(event_id):
		return false
	if Time.get_ticks_msec() - int(_seen_ids[event_id]) < SEEN_ID_TTL_MSEC:
		return true
	_seen_ids.erase(event_id)
	return false

func _mark_seen(event_id: String) -> void:
	# Only accepted requests are recorded: rejections (full queue, cooldown,
	# unknown command) stay retryable, accepted ones become exactly-once.
	if event_id == "":
		return
	_seen_ids[event_id] = Time.get_ticks_msec()
	while _seen_ids.size() > MAX_SEEN_IDS:
		_seen_ids.erase(_seen_ids.keys()[0])

func _handle_command(command: String, username: String, count: int, event_id: String = "") -> void:
	if not (command in COMMAND_ALLOWLIST):
		_reject("unknown_command")
		return
	if command == "debug_kill_boss":
		_handle_debug_kill_boss(event_id)
		return
	if command == "debug_heal":
		_handle_debug_heal(event_id)
		return
	if not _is_game_running():
		_send({"type": "result", "ok": false, "error": "game_not_running", "command": command})
		return
	# Boss summons queue instead of hitting the generic cooldown path, so no
	# accepted Galaxy gift is discarded. Game-level guards still apply.
	if command == "summon_boss":
		_handle_summon_boss(username, count, event_id)
		return
	if float(_cooldowns.get(command, 0.0)) > 0.0:
		_send({"type": "result", "ok": false, "error": "on_cooldown",
			"command": command, "retry_in": _cooldowns[command]})
		return
	if not _dispatch(command, username, count):
		return
	_mark_seen(event_id)
	_cooldowns[command] = float(command_cooldowns.get(command, 5.0))
	command_accepted.emit(command, username)
	_send({"type": "result", "ok": true, "command": command})
	print("[LiveBridge] %s <- %s x%d" % [command, username, count])

func _handle_debug_kill_boss(event_id: String) -> void:
	# TEST-ONLY mechanism: lets the simulator drive real boss deaths through
	# the genuine take_damage -> died path. Refused in release/export builds.
	if not OS.has_feature("debug"):
		_send({"type": "result", "ok": false, "error": "disabled",
			"command": "debug_kill_boss"})
		return
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm == null or gm.spawn_manager == null:
		_send({"type": "result", "ok": false, "error": "no_game_manager",
			"command": "debug_kill_boss"})
		return
	var boss := gm.spawn_manager.get_boss()
	if boss == null:
		_send({"type": "result", "ok": false, "error": "no_boss",
			"command": "debug_kill_boss"})
		return
	_mark_seen(event_id)
	boss.take_damage(999999)
	_send({"type": "result", "ok": true, "command": "debug_kill_boss"})
	print("[LiveBridge] test boss kill executed")

func _handle_debug_heal(event_id: String) -> void:
	# TEST-ONLY: keeps the cat alive during long simulator drain runs.
	# Refused in release/export builds, like debug_kill_boss.
	if not OS.has_feature("debug"):
		_send({"type": "result", "ok": false, "error": "disabled",
			"command": "debug_heal"})
		return
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm == null or gm.player == null:
		_send({"type": "result", "ok": false, "error": "no_game_manager",
			"command": "debug_heal"})
		return
	_mark_seen(event_id)
	gm.player.heal(gm.player.max_health)
	_send({"type": "result", "ok": true, "command": "debug_heal"})

func _tick_cooldowns(delta: float) -> void:
	for key in _cooldowns.keys():
		_cooldowns[key] = maxf(0.0, float(_cooldowns[key]) - delta)

func _watch_game_running() -> void:
	# Restart and game-over cleanup: an over screen must not leave queued
	# requests or pending pump state behind (scene reload recreates us).
	var running := _is_game_running()
	if _was_running and not running and (not _boss_queue.is_empty() or _just_spawned):
		_boss_queue.clear()
		_just_spawned = false
		_pump_retry = 0.0
		_pump_wait_logged = false
		print("[BossQueue] Game over: queue cleared")
	if running:
		_was_running = true

# ------------------------------------------------------------ boss queue --

func _status_obj() -> Dictionary:
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	var boss_active := false
	var active_count := 0
	var cd_left := 0.0
	var php := -1
	var pmax := -1
	if gm != null:
		if gm.spawn_manager != null:
			boss_active = gm.spawn_manager.has_boss()
			active_count = gm.spawn_manager.boss_count()
			cd_left = gm.spawn_manager.get_boss_cooldown_left()
		if gm.player != null and is_instance_valid(gm.player):
			php = int(gm.player.get("health"))
			pmax = int(gm.player.get("max_health"))
	return {"type": "status", "game_running": _is_game_running(),
		"boss_active": boss_active, "active_bosses": active_count,
		"max_bosses": SpawnManager.MAX_ACTIVE_BOSSES,
		"queue_size": _boss_queue.size(), "queue_max": boss_queue_max,
		"boss_cooldown_left": cd_left, "player_hp": php, "player_max_hp": pmax}

func _handle_summon_boss(username: String, count: int, event_id: String = "") -> void:
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm == null or gm.spawn_manager == null:
		_send({"type": "result", "ok": false, "error": "no_game_manager", "command": "summon_boss"})
		return
	if _boss_queue.size() >= boss_queue_max:
		_send({"type": "result", "ok": false, "error": "queue_full",
			"command": "summon_boss", "queue_size": _boss_queue.size(),
			"queue_max": boss_queue_max})
		print("[LiveBridge] boss queue FULL (%d/%d), gift from %s NOT queued" % [_boss_queue.size(), boss_queue_max, username])
		return
	# Exactly one completed gift event creates exactly one summon request.
	# The message `count` (streak totals, retries) is intentionally ignored:
	# default Galaxy mapping is one gift = one boss.
	_boss_queue.append({"username": username})
	_mark_seen(event_id)
	print("[BossQueue] Gift accepted: +1 request")
	command_accepted.emit("summon_boss", username)
	var spawned_here := _pump_boss_queue()
	var size := _boss_queue.size()
	if spawned_here == 0 and size > 0:
		var sm := gm.spawn_manager
		print("[BossQueue] Queued one boss. Active: %d/%d, queued: %d/%d" % [sm.boss_count(), SpawnManager.MAX_ACTIVE_BOSSES, size, boss_queue_max])
	var base := {"type": "result", "ok": true, "command": "summon_boss",
		"queued": 1, "queue_size": size, "queue_max": boss_queue_max}
	if size == 0:
		base["status"] = "summoned"
	else:
		base["status"] = "queued"
	_send(base)

func _pump_boss_queue() -> int:
	# Spawns only from existing queued entries when a slot is free.
	# Never fabricates requests: timers, reconnects, and this loop only
	# consume the queue. Returns the number spawned.
	if _boss_queue.is_empty():
		return 0
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm == null or not gm.running:
		return 0
	if gm.spawn_manager == null:
		return 0
	var sm := gm.spawn_manager
	if _just_spawned:
		# spawn_boss() adds the node deferred: wait until it is visible
		# before processing the next entry, so bosses never overlap.
		if sm.boss_count() > 0:
			_just_spawned = false
		else:
			return 0
	if _pump_retry > 0.0:
		return 0
	# Fill spawn slots sequentially until MAX_ACTIVE_BOSSES or queue empty.
	# Deferred adds are invisible to boss_count() this frame, so a local
	# counter bounds this pass: never more than 3 living bosses.
	var spawned := 0
	while not _boss_queue.is_empty():
		if sm.boss_count() + spawned >= SpawnManager.MAX_ACTIVE_BOSSES:
			break
		var boss := sm.spawn_boss()
		if boss == null:
			# Enemy cap or missing scene: keep entries, retry shortly.
			_pump_retry = 0.5
			if not _pump_wait_logged:
				_pump_wait_logged = true
				print("[LiveBridge] boss spawn deferred (enemy cap?), retrying")
			break
		# Only removed after a successful spawn: no accepted gift is lost.
		_boss_queue.pop_front()
		spawned += 1
		print("[BossQueue] Spawned boss. Active: %d/%d, queued: %d/%d" % [sm.boss_count() + spawned, SpawnManager.MAX_ACTIVE_BOSSES, _boss_queue.size(), boss_queue_max])
	if spawned > 0:
		_just_spawned = true
		_pump_wait_logged = false
		if gm.hud != null:
			gm.hud.show_powerup_message("BOSS INCOMING! x%d (%d queued)" % [spawned, _boss_queue.size()], 4.0)
	return spawned

func _update_boss_hud() -> void:
	var active := 0
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm != null and gm.spawn_manager != null:
		active = gm.spawn_manager.boss_count()
	var queued := _boss_queue.size()
	# Deaths are observed as count transitions (bosses leave only via _die).
	# This logs actual deaths; it never fabricates summon requests.
	if _last_boss_count >= 0 and gm != null and gm.running and active < _last_boss_count:
		print("[BossQueue] Boss died. Active: %d/%d, queued: %d/%d" % [active, SpawnManager.MAX_ACTIVE_BOSSES, queued, boss_queue_max])
	_last_boss_count = active
	if active == _shown_active and queued == _shown_queued:
		return
	_shown_active = active
	_shown_queued = queued
	if gm != null and gm.hud != null and gm.hud.has_method("set_boss_status"):
		gm.hud.set_boss_status(active, queued, SpawnManager.MAX_ACTIVE_BOSSES, boss_queue_max)

func _reject(reason: String) -> void:
	command_rejected.emit(reason)
	_send({"type": "result", "ok": false, "error": reason})
	print("[LiveBridge] rejected: %s" % reason)

func _is_game_running() -> bool:
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	return gm != null and gm.running

# ---------------------------------------------------------------- dispatch --
# Every branch reuses the exact game-manager/player/spawner paths the
# keyboard debug controls use, so LIVE gifts behave identically to keys.

func _dispatch(command: String, username: String, count: int) -> bool:
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm == null:
		_send({"type": "result", "ok": false, "error": "no_game_manager"})
		return false
	match command:
		"rapid_fire":
			gm._trigger_rapid_fire()
		"giant_gun":
			if gm.player == null:
				return false
			gm.player.activate_giant_gun()
			if gm.hud != null:
				gm.hud.show_powerup_message("GIANT GUN! (%s)" % username)
		"weapon_minigun":
			gm._switch_weapon("minigun")
		"weapon_rocket":
			gm._switch_weapon("rocket")
		"weapon_machinegun":
			gm._switch_weapon("machinegun")
		"weapon_default":
			gm._switch_weapon("default")
		"mega_laser":
			gm._trigger_laser()
		"spawn_wave":
			_spawn_wave(gm, count)
		"summon_boss":
			gm._trigger_boss()
		_:
			_reject("unknown_command")
			return false
	return true

func _spawn_wave(gm: GameManager, count: int) -> void:
	var total := clampi(count * wave_enemies_per_gift, 1, wave_max_enemies)
	var spawned := 0
	for i in range(total):
		if gm.spawn_manager == null:
			break
		if gm.spawn_manager.spawn_enemy() != null:
			spawned += 1
	if gm.hud != null:
		gm.hud.show_powerup_message("GIFT WAVE! +%d" % spawned)

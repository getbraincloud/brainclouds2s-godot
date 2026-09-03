# Copyright 2026 bitHeads, Inc. All Rights Reserved.
class_name S2STestHelper
extends Node

## Test scaffolding for the godot-s2s test suite: loads test/ids.cfg, creates
## S2SContexts from it, and provides pass/fail assertion helpers. Mirrors the
## conventions of braincloud-gdscript's own BCTest.gd.

var ids: Dictionary = {}

var _pass_count: int = 0
var _fail_count: int = 0
var _current_suite: String = ""
var _current_test: String = ""
var _failed_tests: Array = []

func load_ids(path: String = "res://test/ids.cfg") -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("S2STestHelper: cannot open ids file: %s" % path)
		return false
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var kv := line.split("=", true, 1)
		if kv.size() == 2:
			ids[kv[0].strip_edges()] = kv[1].strip_edges()
	file.close()
	return true

## Creates (and adds to the tree) a fresh S2SContext using ids.cfg credentials.
## Verbose S2S/RTT wire logging is on by default for every context the test suite
## creates (see set_log_enabled below) — pass log_enabled=false to quiet one down.
func create_context(auto_auth: bool = false, log_enabled: bool = true) -> S2SContext:
	var ctx := S2SContext.create(
		ids.get("appId", ""),
		ids.get("serverName", ""),
		ids.get("serverSecret", ""),
		ids.get("s2sUrl", ""),
		auto_auth,
		self
	)
	ctx.set_log_enabled(log_enabled)
	return ctx

# ── Assertion helpers ───────────────────────────────────────────────────────

func begin_suite(suite_name: String) -> void:
	_current_suite = suite_name

func begin_test(test_name: String) -> void:
	_current_test = test_name
	print("  [TEST] %s" % test_name)

func _fail_key() -> String:
	return "[%s] %s" % [_current_suite, _current_test]

func expect_true(condition: bool, msg: String = "") -> void:
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
		var key := _fail_key()
		if not _failed_tests.has(key):
			_failed_tests.append(key)
		push_error("  FAIL [%s]: expected true. %s" % [_current_test, msg])

func expect_false(condition: bool, msg: String = "") -> void:
	expect_true(not condition, msg)

func expect_eq(actual, expected, msg: String = "") -> void:
	expect_true(actual == expected, "expected %s == %s. %s" % [str(actual), str(expected), msg])

func expect_status_ok(response: Dictionary) -> void:
	var status: int = response.get("status", -1)
	expect_true(status == 200 or status == 202, "Expected status 200 or 202, got %d%s" % [status, _response_detail(response, status)])

func expect_status(response: Dictionary, expected_status: int) -> void:
	expect_eq(response.get("status", -1), expected_status, "Expected status %d" % expected_status)

func expect_has_key(response: Dictionary, key: String) -> void:
	expect_true(response.has(key), "response missing key '%s'" % key)

func _response_detail(response: Dictionary, status: int) -> String:
	if status == 200 or status == 202:
		return ""
	var msg: String = String(response.get("status_message", ""))
	var reason: int = int(response.get("reason_code", 0))
	if msg.is_empty():
		return ""
	return "\n    [reason_code=%d] %s" % [reason, msg.left(120).replace("\n", " ")]

func print_summary() -> void:
	print("\n=== Test Summary: %d passed, %d failed ===" % [_pass_count, _fail_count])
	if _failed_tests.size() > 0:
		print("\nFailed tests:")
		for t in _failed_tests:
			print("  - %s" % t)

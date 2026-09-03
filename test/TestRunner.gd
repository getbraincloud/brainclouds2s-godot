# Copyright 2026 bitHeads, Inc. All Rights Reserved.
# Run with: godot --headless --script test/TestRunner.gd
extends SceneTree

const TEST_FILES := [
	"res://test/bad_requests_test.gd",
	"res://test/bad_server_secret_test.gd",
	"res://test/valid_context_test.gd",
	"res://test/sync_test.gd",
	"res://test/run_with_timeout_test.gd",
	"res://test/global_file_v3_test.gd",
	"res://test/prl_test.gd",
	"res://test/rtt_test.gd",
]

var _helper: S2STestHelper = null

func _init() -> void:
	print("=== brainCloud GDScript S2S Tests ===\n")
	_helper = S2STestHelper.new()
	root.add_child(_helper)
	_run_tests.call_deferred()

func _run_tests() -> void:
	if not _helper.load_ids():
		push_error("S2STestHelper setup failed — check test/ids.cfg")
		quit(1)
		return

	# Optional: --suite valid_context,sync (comma-separated, no .gd extension needed)
	var filter := ""
	var args := OS.get_cmdline_user_args()
	var suite_idx := args.find("--suite")
	if suite_idx >= 0 and suite_idx + 1 < args.size():
		filter = args[suite_idx + 1]

	for test_path in TEST_FILES:
		var matches := filter.is_empty()
		if not matches:
			for f in filter.split(","):
				if test_path.contains(f.strip_edges()):
					matches = true
					break
		if matches:
			await _run_file(test_path)

	_helper.print_summary()
	var total_fail: int = _helper._fail_count

	print("\n=== TOTAL: %d passed, %d failed ===" % [_helper._pass_count, total_fail])
	quit(1 if total_fail > 0 else 0)

func _run_file(path: String) -> void:
	var script: GDScript = load(path)
	if script == null:
		push_error("Could not load test script: %s" % path)
		return

	var test_instance = script.new()
	if not test_instance:
		return

	var suite_name := path.get_file().get_basename()
	print("\n[SUITE] %s" % suite_name)
	_helper.begin_suite(suite_name)
	if test_instance.has_method("run"):
		await test_instance.run(_helper)

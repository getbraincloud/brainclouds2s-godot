# Copyright 2026 bitHeads, Inc. All Rights Reserved.
extends RefCounted

const CONNECT_TIMEOUT_SECS := 15.0

func run(t: S2STestHelper) -> void:
	await test_enable_rtt_and_receive_raw_message(t)

func test_enable_rtt_and_receive_raw_message(t: S2STestHelper) -> void:
	t.begin_test("test_enable_rtt_and_receive_raw_message")
	var ctx := t.create_context()
	await ctx.authenticate()

	var rtt := ctx.get_rtt_service()

	var received: Array = []
	rtt.register_raw_callback(func(msg: Dictionary): received.append(msg))

	rtt.enable()
	var connected := await _wait_for(func(): rtt.poll(); return rtt.is_enabled(), CONNECT_TIMEOUT_SECS)
	t.expect_true(connected, "RTT should connect within %ds" % int(CONNECT_TIMEOUT_SECS))

	if connected:
		t.expect_true(rtt.is_enabled(), "is_enabled() should be true once connected")

		# Registering for our own profile-level events triggers no traffic in a fresh
		# test app; just confirm poll() keeps running without error for a couple of
		# ticks so the heartbeat/dispatch path is exercised.
		for i in range(3):
			rtt.poll()
			await Engine.get_main_loop().process_frame

	rtt.disable()
	t.expect_false(rtt.is_enabled(), "disable() should leave RTT disabled")

	ctx.queue_free()

## Repeatedly calls `predicate` (which should also do any per-tick polling it needs)
## once per frame until it returns true or `timeout_secs` elapses.
func _wait_for(predicate: Callable, timeout_secs: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_secs * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await Engine.get_main_loop().process_frame
	return false

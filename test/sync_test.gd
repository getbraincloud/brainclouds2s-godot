# Copyright 2026 bitHeads, Inc. All Rights Reserved.
# The other S2S SDKs offer a blocking requestSync() alongside their callback-based
# request(). GDScript has no equivalent of a thread-blocking call that doesn't stall
# the engine — but `await` already gives every call site the same "get the result
# directly, right here" ergonomics requestSync() exists for, with none of the
# thread-blocking downsides. This suite exercises that: no callback anywhere, just
# `var result := await ctx.request(...)`.
extends RefCounted

func run(t: S2STestHelper) -> void:
	await test_await_returns_result_directly(t)

func test_await_returns_result_directly(t: S2STestHelper) -> void:
	t.begin_test("test_await_returns_result_directly")
	var ctx := t.create_context()

	var auth_result := await ctx.authenticate()
	t.expect_status_ok(auth_result)

	var result := await ctx.request({"service": "time", "operation": "READ", "data": {}})

	t.expect_true(not result.is_empty(), "result should not be empty")
	t.expect_status_ok(result)

	ctx.queue_free()

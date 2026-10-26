# Copyright 2026 bitHeads, Inc. All Rights Reserved.
# Mirrors cpp-s2s testsS2S.cpp / testsS2SAutoAuth.cpp "RunCallbacks with nullptr
# callback". There the risk is dereferencing a null callback pointer; here the same
# hazard is an invalid Callable, which GDScript will happily let you construct and
# which throws at call time if the SDK doesn't guard it (S2SContext._invoke checks
# is_valid()). sync_test.gd covers the await-only style — this covers the callback
# style, and proves both forms deliver the same result.
extends RefCounted

func run(t: S2STestHelper) -> void:
	await test_authenticate_invokes_callback(t)
	await test_request_invokes_callback(t)
	await test_request_without_callback_returns_result(t)
	await test_explicit_empty_callable_is_ignored(t)

func test_authenticate_invokes_callback(t: S2STestHelper) -> void:
	t.begin_test("test_authenticate_invokes_callback")
	var ctx := t.create_context()

	var called := [false]
	var captured := [{}]
	var result := await ctx.authenticate(func(r: Dictionary) -> void:
		called[0] = true
		captured[0] = r
	)

	t.expect_true(called[0], "authenticate() should invoke the callback")
	t.expect_status_ok(captured[0])
	t.expect_eq(captured[0], result, "callback should receive the same result await returns")

	ctx.queue_free()

func test_request_invokes_callback(t: S2STestHelper) -> void:
	t.begin_test("test_request_invokes_callback")
	var ctx := t.create_context()
	await ctx.authenticate()

	var called := [false]
	var captured := [{}]
	var result := await ctx.request({"service": "time", "operation": "READ", "data": {}},
		func(r: Dictionary) -> void:
			called[0] = true
			captured[0] = r
	)

	t.expect_true(called[0], "request() should invoke the callback")
	t.expect_status_ok(captured[0])
	t.expect_eq(captured[0], result, "callback should receive the same result await returns")

	ctx.queue_free()

## The common case — no callback argument at all. Must not throw on the internal
## _invoke(), and must still resolve.
func test_request_without_callback_returns_result(t: S2STestHelper) -> void:
	t.begin_test("test_request_without_callback_returns_result")
	var ctx := t.create_context()
	await ctx.authenticate()

	var result := await ctx.request({"service": "time", "operation": "READ", "data": {}})

	t.expect_status_ok(result)

	ctx.queue_free()

## The direct analogue of the C++ "nullptr callback" case: an explicitly empty
## Callable must be ignored, not called.
func test_explicit_empty_callable_is_ignored(t: S2STestHelper) -> void:
	t.begin_test("test_explicit_empty_callable_is_ignored")
	var ctx := t.create_context()

	var auth_result := await ctx.authenticate(Callable())
	t.expect_status_ok(auth_result)

	var result := await ctx.request({"service": "time", "operation": "READ", "data": {}}, Callable())
	t.expect_status_ok(result)

	ctx.queue_free()

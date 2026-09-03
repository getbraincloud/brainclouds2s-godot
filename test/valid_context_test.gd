# Copyright 2026 bitHeads, Inc. All Rights Reserved.
extends RefCounted

func run(t: S2STestHelper) -> void:
	await test_authenticate_succeeds(t)
	await test_run_script(t)
	await test_successive_calls(t)
	await test_empty_request_fails(t)

func test_authenticate_succeeds(t: S2STestHelper) -> void:
	t.begin_test("test_authenticate_succeeds")
	var ctx := t.create_context()

	var result := await ctx.authenticate()

	t.expect_status_ok(result)
	t.expect_true(ctx.is_authenticated(), "context should report as authenticated")
	t.expect_true(not ctx.get_session_id().is_empty(), "sessionId should be set")

	ctx.queue_free()

func test_run_script(t: S2STestHelper) -> void:
	t.begin_test("test_run_script")
	var ctx := t.create_context()
	await ctx.authenticate()

	var result := await ctx.request({
		"service": "script",
		"operation": "RUN",
		"data": {"scriptName": "testScript2"},
	})
	t.expect_status_ok(result)

	ctx.queue_free()

## Five sequential requests on the same context should all resolve, in order,
## and all succeed — confirms the single-flight request gate doesn't drop or
## reorder anything.
func test_successive_calls(t: S2STestHelper) -> void:
	t.begin_test("test_successive_calls")
	var ctx := t.create_context()
	await ctx.authenticate()

	var request := {"service": "time", "operation": "READ", "data": {}}
	var success_count := 0
	for i in range(5):
		var result := await ctx.request(request)
		if int(result.get("status", 0)) == 200:
			success_count += 1

	t.expect_eq(success_count, 5, "all 5 successive requests should succeed")

	ctx.queue_free()

func test_empty_request_fails(t: S2STestHelper) -> void:
	t.begin_test("test_empty_request_fails")
	var ctx := t.create_context()
	await ctx.authenticate()

	var result := await ctx.request({})
	t.expect_true(int(result.get("status", -1)) != 200, "an empty request dict should fail")

	ctx.queue_free()

# Copyright 2026 bitHeads, Inc. All Rights Reserved.
extends RefCounted

func run(t: S2STestHelper) -> void:
	await test_single_bad_request(t)
	await test_bad_request_does_not_wedge_the_context(t)

func test_single_bad_request(t: S2STestHelper) -> void:
	t.begin_test("test_single_bad_request")
	var ctx := t.create_context()
	await ctx.authenticate()

	var result := await ctx.request({"service": "timey", "operation": "READ_MUH_TIME", "data": {}})
	t.expect_true(int(result.get("status", -1)) != 200, "unknown service/operation should fail")

	ctx.queue_free()

## A bad-but-valid-JSON request shouldn't desync the context — good requests before
## and after it must still succeed.
func test_bad_request_does_not_wedge_the_context(t: S2STestHelper) -> void:
	t.begin_test("test_bad_request_does_not_wedge_the_context")
	var ctx := t.create_context()
	await ctx.authenticate()

	var good := {"service": "time", "operation": "READ", "data": {}}
	var bad := {"service": "timey", "operation": "READ_MUH_TIME", "data": {}}

	var r1 := await ctx.request(good)
	var r2 := await ctx.request(bad)
	var r3 := await ctx.request(good)

	t.expect_status_ok(r1)
	t.expect_true(int(r2.get("status", -1)) != 200, "bad request should fail")
	t.expect_status_ok(r3)

	ctx.queue_free()

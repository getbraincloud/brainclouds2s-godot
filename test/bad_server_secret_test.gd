# Copyright 2026 bitHeads, Inc. All Rights Reserved.
extends RefCounted

func run(t: S2STestHelper) -> void:
	await test_auth_fails_with_wrong_secret(t)
	await test_request_fails_when_not_authenticated(t)

func _create_bad_secret_context(t: S2STestHelper) -> S2SContext:
	var ctx := S2SContext.create(
		t.ids.get("appId", ""),
		t.ids.get("serverName", ""),
		"not-the-real-secret",
		t.ids.get("s2sUrl", ""),
		false,
		t
	)
	ctx.set_log_enabled(true)
	return ctx

func test_auth_fails_with_wrong_secret(t: S2STestHelper) -> void:
	t.begin_test("test_auth_fails_with_wrong_secret")
	var ctx := _create_bad_secret_context(t)

	var result := await ctx.authenticate()

	t.expect_true(int(result.get("status", -1)) != 200, "authenticate() with a wrong secret should fail")
	t.expect_false(ctx.is_authenticated(), "context should not report as authenticated")

	ctx.queue_free()

func test_request_fails_when_not_authenticated(t: S2STestHelper) -> void:
	t.begin_test("test_request_fails_when_not_authenticated")
	var ctx := _create_bad_secret_context(t)
	await ctx.authenticate()

	var results: Array = []
	for i in range(5):
		results.append(await ctx.request({"service": "time", "operation": "READ", "data": {}}))

	var success_count := 0
	for r in results:
		if int(r.get("status", 0)) == 200:
			success_count += 1

	t.expect_eq(success_count, 0, "no request should succeed on an unauthenticated context")

	ctx.queue_free()

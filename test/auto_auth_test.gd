# Copyright 2026 bitHeads, Inc. All Rights Reserved.
# Mirrors cpp-s2s testsS2SAutoAuth.cpp. That whole file exists because auto-auth is a
# separate code path: the context authenticates itself on the first request() instead
# of the caller doing it. Everything the non-auto-auth suites cover has to hold there
# too, so this re-runs the same shapes with auto_auth=true and pins the one behaviour
# that differs — who calls authenticate().
extends RefCounted

func run(t: S2STestHelper) -> void:
	await test_first_request_authenticates_implicitly(t)
	await test_manual_context_does_not_preemptively_authenticate(t)
	await test_explicit_authenticate_still_works(t)
	await test_successive_calls(t)
	await test_bad_request_does_not_wedge_the_context(t)
	await test_auto_auth_with_bad_secret_fails(t)

func _create_bad_secret_context(t: S2STestHelper) -> S2SContext:
	var ctx := S2SContext.create(
		String(t.ids.get("appId", "")),
		String(t.ids.get("serverName", "")),
		"not-the-real-secret",
		String(t.ids.get("s2sUrl", "")),
		true,
		t
	)
	ctx.set_log_enabled(true)
	return ctx

## The defining behaviour of auto-auth: no authenticate() call anywhere, yet the
## request succeeds and the context ends up authenticated.
func test_first_request_authenticates_implicitly(t: S2STestHelper) -> void:
	t.begin_test("test_first_request_authenticates_implicitly")
	var ctx := t.create_context(true)

	t.expect_false(ctx.is_authenticated(), "an auto-auth context still starts unauthenticated")

	var result := await ctx.request({"service": "time", "operation": "READ", "data": {}})

	t.expect_status_ok(result)
	t.expect_true(ctx.is_authenticated(), "the first request should have authenticated the context")
	t.expect_true(not ctx.get_session_id().is_empty(), "sessionId should be set after implicit auth")

	ctx.queue_free()

## The contrast case, and the reason the C++ suite is split in two. Note this pins a
## real divergence from cpp-s2s rather than matching it:
##
##   cpp-s2s authenticates only through `m_state == Disconnected && m_autoAuth`. It
##   declares SERVER_SESSION_EXPIRED (40365) but never acts on it, so there a request
##   on a non-auto-auth context simply fails.
##
##   GDScript has the same pre-emptive gate, but request() ALSO recovers reactively:
##   a response with reason_code 40365 triggers an authenticate() and a retry, and that
##   path is not gated on _auto_auth. So the first request on a manual context goes out
##   with an empty sessionId, comes back 403/40365, and is then transparently retried
##   after authenticating — it succeeds, and the context ends up authenticated.
##
## What still holds either way, and what this actually asserts: a manual context does
## not authenticate *pre-emptively*. If auto_auth=false is meant to mean "never
## authenticate on my behalf", the recovery path needs the same _auto_auth gate and this
## test flips to expecting failure — see the note raised with this suite.
func test_manual_context_does_not_preemptively_authenticate(t: S2STestHelper) -> void:
	t.begin_test("test_manual_context_does_not_preemptively_authenticate")
	var ctx := t.create_context(false)

	t.expect_false(ctx.is_authenticated(), "a manual context should not authenticate before its first request")

	var result := await ctx.request({"service": "time", "operation": "READ", "data": {}})

	# Succeeds via the 40365 recovery path, not via pre-emptive auth.
	t.expect_status_ok(result)
	t.expect_true(ctx.is_authenticated(), "the session-expiry recovery path should have authenticated it")

	ctx.queue_free()
## Calling authenticate() yourself on an auto-auth context is allowed; the following
## request must reuse that session rather than authenticating a second time.
func test_explicit_authenticate_still_works(t: S2STestHelper) -> void:
	t.begin_test("test_explicit_authenticate_still_works")
	var ctx := t.create_context(true)

	var auth_result := await ctx.authenticate()
	t.expect_status_ok(auth_result)
	var session_after_auth := ctx.get_session_id()

	var result := await ctx.request({"service": "time", "operation": "READ", "data": {}})
	t.expect_status_ok(result)
	t.expect_eq(ctx.get_session_id(), session_after_auth,
		"an explicit authenticate() should not be followed by a second implicit one")

	ctx.queue_free()

func test_successive_calls(t: S2STestHelper) -> void:
	t.begin_test("test_successive_calls")
	var ctx := t.create_context(true)

	var request := {"service": "time", "operation": "READ", "data": {}}
	var success_count := 0
	for i in range(5):
		var result := await ctx.request(request)
		if int(result.get("status", 0)) == 200:
			success_count += 1

	t.expect_eq(success_count, 5, "all 5 successive auto-auth requests should succeed")

	ctx.queue_free()

func test_bad_request_does_not_wedge_the_context(t: S2STestHelper) -> void:
	t.begin_test("test_bad_request_does_not_wedge_the_context")
	var ctx := t.create_context(true)

	var good := {"service": "time", "operation": "READ", "data": {}}
	var bad := {"service": "timey", "operation": "READ_MUH_TIME", "data": {}}

	var r1 := await ctx.request(good)
	var r2 := await ctx.request(bad)
	var r3 := await ctx.request(good)

	t.expect_status_ok(r1)
	t.expect_true(int(r2.get("status", -1)) != 200, "bad request should fail")
	t.expect_status_ok(r3)

	ctx.queue_free()

## Auto-auth must not paper over bad credentials: the implicit authenticate() fails,
## so the request fails, and the context never reports itself as authenticated.
func test_auto_auth_with_bad_secret_fails(t: S2STestHelper) -> void:
	t.begin_test("test_auto_auth_with_bad_secret_fails")
	var ctx := _create_bad_secret_context(t)

	var result := await ctx.request({"service": "time", "operation": "READ", "data": {}})

	t.expect_true(int(result.get("status", -1)) != 200, "request should fail with a bad server secret")
	t.expect_false(ctx.is_authenticated(), "context should not report as authenticated")

	ctx.queue_free()

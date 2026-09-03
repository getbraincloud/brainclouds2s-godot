# Copyright 2026 bitHeads, Inc. All Rights Reserved.
# The C++/Java/JS S2S SDKs use this suite to prove runCallbacks(timeoutMS) doesn't
# hang past when it should. GDScript's await model has no such manual pump to test —
# await always resolves as soon as the underlying HTTPRequest signal fires, with no
# polling loop of our own to get wrong — so this instead proves the property that
# actually matters here: a request resolves promptly (never hangs indefinitely), on
# a context that was never authenticate()'d.
extends RefCounted

const MAX_WAIT_MS := 30 * 1000

func run(t: S2STestHelper) -> void:
	await test_unauthenticated_request_does_not_hang(t)

func test_unauthenticated_request_does_not_hang(t: S2STestHelper) -> void:
	t.begin_test("test_unauthenticated_request_does_not_hang")
	var ctx := t.create_context()  # auto_auth defaults to false; authenticate() deliberately not called

	var start := Time.get_ticks_msec()
	var result := await ctx.request({"service": "script", "operation": "RUN", "data": {"scriptName": "testScript2"}})
	var elapsed := Time.get_ticks_msec() - start

	t.expect_true(elapsed < MAX_WAIT_MS, "request should resolve well under %ds, took %dms" % [MAX_WAIT_MS / 1000, elapsed])
	t.expect_true(not result.is_empty(), "request should still resolve to a parsed response")

	ctx.queue_free()

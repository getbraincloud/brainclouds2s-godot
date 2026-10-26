# Copyright 2026 bitHeads, Inc. All Rights Reserved.
# Mirrors cpp-s2s testsS2S.cpp "Create context" and testsS2SAutoAuth.cpp
# "Create context - Auto auth": every S2SContext.create() must hand back its own
# independent context, and the accessors must report exactly what it was built with.
#
# Pure unit tests — nothing here talks to the server.
extends RefCounted

func run(t: S2STestHelper) -> void:
	test_create_returns_independent_contexts(t)
	test_accessors_report_creation_values(t)
	test_empty_url_falls_back_to_default(t)
	test_fresh_context_is_unauthenticated(t)
	test_s2s_version_is_reported(t)

## The C++ suite asserts `pContext != pAnotherContext`. The GDScript equivalent is
## worth a little more than pointer inequality: two contexts must not share state, so
## this also proves a setting changed on one doesn't bleed into the other.
func test_create_returns_independent_contexts(t: S2STestHelper) -> void:
	t.begin_test("test_create_returns_independent_contexts")
	var a := t.create_context()
	var b := t.create_context()

	t.expect_true(a != b, "each create() call should return a distinct context")
	t.expect_true(a.get_instance_id() != b.get_instance_id(), "contexts should be separate objects")

	a.set_log_enabled(false)
	b.set_log_enabled(true)
	t.expect_false(a.get_log_enabled(), "settings on one context must not leak to the other")
	t.expect_true(b.get_log_enabled(), "settings on one context must not leak to the other")

	a.queue_free()
	b.queue_free()

func test_accessors_report_creation_values(t: S2STestHelper) -> void:
	t.begin_test("test_accessors_report_creation_values")
	var ctx := t.create_context()

	t.expect_eq(ctx.get_app_id(), String(t.ids.get("appId", "")), "appId should round-trip")
	t.expect_eq(ctx.get_server_name(), String(t.ids.get("serverName", "")), "serverName should round-trip")
	t.expect_eq(ctx.get_server_secret(), String(t.ids.get("serverSecret", "")), "serverSecret should round-trip")

	# An empty s2sUrl in ids.cfg is legal and means "use the default", so resolve the
	# expectation the same way create() does rather than comparing against the raw id.
	var expected_url := String(t.ids.get("s2sUrl", ""))
	if expected_url.is_empty():
		expected_url = S2SContext.DEFAULT_S2S_URL
	t.expect_eq(ctx.get_server_url(), expected_url, "server url should round-trip")

	ctx.queue_free()

func test_empty_url_falls_back_to_default(t: S2STestHelper) -> void:
	t.begin_test("test_empty_url_falls_back_to_default")
	var ctx := S2SContext.create("20001", "test-server", "test-secret", "", false, t)

	t.expect_eq(ctx.get_server_url(), S2SContext.DEFAULT_S2S_URL,
		"an empty url should fall back to DEFAULT_S2S_URL")

	ctx.queue_free()

func test_fresh_context_is_unauthenticated(t: S2STestHelper) -> void:
	t.begin_test("test_fresh_context_is_unauthenticated")
	var ctx := t.create_context()

	t.expect_false(ctx.is_authenticated(), "a context should not be authenticated before authenticate()")
	t.expect_true(ctx.get_session_id().is_empty(), "a fresh context should have no session id")

	ctx.queue_free()

func test_s2s_version_is_reported(t: S2STestHelper) -> void:
	t.begin_test("test_s2s_version_is_reported")
	var ctx := t.create_context()

	t.expect_true(not ctx.get_s2s_version().is_empty(), "s2s version should not be empty")
	t.expect_eq(ctx.get_s2s_version(), S2SContext.S2S_VERSION, "version should match the S2S_VERSION const")

	ctx.queue_free()

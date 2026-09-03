# Copyright 2026 bitHeads, Inc. All Rights Reserved.
# Pure unit tests — no network, no S2SContext. BrainCloudS2SPRL's override params let
# these run without forking a process with different environment variables.
extends RefCounted

func run(t: S2STestHelper) -> void:
	test_is_pre_ready_launch(t)
	test_get_timeout_secs(t)
	test_parse_server_context(t)

func test_is_pre_ready_launch(t: S2STestHelper) -> void:
	t.begin_test("test_is_pre_ready_launch")
	t.expect_true(BrainCloudS2SPRL.is_pre_ready_launch("true"), "\"true\" should be pre-ready-launch")
	t.expect_true(BrainCloudS2SPRL.is_pre_ready_launch("TRUE"), "case-insensitive match")
	t.expect_false(BrainCloudS2SPRL.is_pre_ready_launch("false"), "\"false\" should not be pre-ready-launch")
	t.expect_false(BrainCloudS2SPRL.is_pre_ready_launch("garbage"), "unrecognized value should not be pre-ready-launch")

func test_get_timeout_secs(t: S2STestHelper) -> void:
	t.begin_test("test_get_timeout_secs")
	t.expect_eq(BrainCloudS2SPRL.get_timeout_secs(45), 45, "override should win")
	t.expect_eq(BrainCloudS2SPRL.get_timeout_secs(0), 0, "a zero override should still win (not treated as unset)")

func test_parse_server_context(t: S2STestHelper) -> void:
	t.begin_test("test_parse_server_context")

	var plain := BrainCloudS2SPRL.parse_server_context('{"lobbyId":"abc123"}')
	t.expect_eq(String(plain.get("lobbyId", "")), "abc123", "plain JSON should parse")

	var single_quoted := BrainCloudS2SPRL.parse_server_context("'{\"lobbyId\":\"abc123\"}'")
	t.expect_eq(String(single_quoted.get("lobbyId", "")), "abc123", "single-quote-wrapped JSON should parse")

	var garbage := BrainCloudS2SPRL.parse_server_context("not json")
	t.expect_eq(garbage, {}, "unparseable input should return an empty Dictionary")

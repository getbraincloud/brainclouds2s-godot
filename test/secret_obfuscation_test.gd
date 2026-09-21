# Copyright 2026 bitHeads, Inc. All Rights Reserved.
# Mirrors cpp-s2s testsLogs.cpp "Secret Obfuscation" and "Logs LogToFile".
#
# The C++ suite drives obfuscation through the log file it writes and then greps that
# file. GDScript has no file-logging mode — set_log_enabled() only toggles print() —
# so there is no artifact to grep. The property that actually matters is the same one
# either way, and it is directly reachable here: S2SContext.redact() must strip every
# sensitive value before anything reaches the log. These test redact() itself, which
# is stricter than grepping a log, plus the log/obfuscation toggles around it.
#
# Pure unit tests — nothing here talks to the server.
extends RefCounted

func run(t: S2STestHelper) -> void:
	test_show_secret_logs_defaults_off(t)
	test_show_secret_logs_round_trips(t)
	test_log_enabled_round_trips(t)
	test_redact_hides_every_sensitive_key(t)
	test_redact_leaves_ordinary_values_alone(t)
	test_redact_hides_every_occurrence(t)

func test_show_secret_logs_defaults_off(t: S2STestHelper) -> void:
	t.begin_test("test_show_secret_logs_defaults_off")
	var ctx := t.create_context()

	# Secrets must be hidden unless someone deliberately asks for them — a default of
	# "on" would leak the server secret into every CI log.
	t.expect_false(ctx.get_show_secret_logs(), "secret logging should be off by default")

	ctx.queue_free()

func test_show_secret_logs_round_trips(t: S2STestHelper) -> void:
	t.begin_test("test_show_secret_logs_round_trips")
	var ctx := t.create_context()

	ctx.set_show_secret_logs(true)
	t.expect_true(ctx.get_show_secret_logs(), "secret logging should report as enabled")
	ctx.set_show_secret_logs(false)
	t.expect_false(ctx.get_show_secret_logs(), "secret logging should report as disabled")

	ctx.queue_free()

func test_log_enabled_round_trips(t: S2STestHelper) -> void:
	t.begin_test("test_log_enabled_round_trips")
	var ctx := t.create_context(false, false)

	t.expect_false(ctx.get_log_enabled(), "logging should be off when created with log_enabled=false")
	ctx.set_log_enabled(true)
	t.expect_true(ctx.get_log_enabled(), "logging should report as enabled")
	ctx.set_log_enabled(false)
	t.expect_false(ctx.get_log_enabled(), "logging should report as disabled")

	ctx.queue_free()

## Every key in SENSITIVE_KEYS must have its value replaced. Driving the loop off the
## const rather than a hardcoded list means adding a key to the SDK without teaching
## redact() about it can't silently pass.
func test_redact_hides_every_sensitive_key(t: S2STestHelper) -> void:
	t.begin_test("test_redact_hides_every_sensitive_key")

	for key in S2SContext.SENSITIVE_KEYS:
		var json := '{"%s":"leaked-value-here"}' % key
		var redacted := S2SContext.redact(json)
		t.expect_true(not redacted.contains("leaked-value-here"),
			"redact() should hide the value of '%s' (got: %s)" % [key, redacted])
		t.expect_true(redacted.contains("[REDACTED]"),
			"redact() should mark '%s' as redacted (got: %s)" % [key, redacted])

func test_redact_leaves_ordinary_values_alone(t: S2STestHelper) -> void:
	t.begin_test("test_redact_leaves_ordinary_values_alone")

	var json := '{"serverName":"bitheads","appId":"20001","operation":"AUTHENTICATE"}'
	t.expect_eq(S2SContext.redact(json), json, "redact() should not touch non-sensitive JSON")

	# A realistic auth packet: the secret goes, everything around it stays.
	var packet := '{"appId":"20001","serverName":"bitheads","serverSecret":"super-secret"}'
	var redacted := S2SContext.redact(packet)
	t.expect_true(not redacted.contains("super-secret"), "the secret should be gone")
	t.expect_true(redacted.contains("bitheads"), "the server name should survive redaction")
	t.expect_true(redacted.contains("20001"), "the app id should survive redaction")

func test_redact_hides_every_occurrence(t: S2STestHelper) -> void:
	t.begin_test("test_redact_hides_every_occurrence")

	# Stopping after the first match would leak the rest — nested/repeated tokens are
	# normal in RTT packets.
	var json := '{"token":"first-one","nested":{"token":"second-one"}}'
	var redacted := S2SContext.redact(json)

	t.expect_true(not redacted.contains("first-one"), "the first occurrence should be redacted")
	t.expect_true(not redacted.contains("second-one"), "the second occurrence should be redacted too")

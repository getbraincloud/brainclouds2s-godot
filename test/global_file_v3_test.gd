# Copyright 2026 bitHeads, Inc. All Rights Reserved.
extends RefCounted

func run(t: S2STestHelper) -> void:
	await test_get_global_file_list(t)
	await test_upload_get_info_and_delete(t)

func test_get_global_file_list(t: S2STestHelper) -> void:
	t.begin_test("test_get_global_file_list")
	var ctx := t.create_context()
	await ctx.authenticate()

	var result := await ctx.get_global_file_v3().sys_get_global_file_list("", true)

	t.expect_status_ok(result)
	t.expect_has_key(result.get("data", {}), "fileList")

	ctx.queue_free()

## Round-trips a small in-memory file through upload -> get info -> delete.
func test_upload_get_info_and_delete(t: S2STestHelper) -> void:
	t.begin_test("test_upload_get_info_and_delete")
	var ctx := t.create_context()
	await ctx.authenticate()
	var gfv3 := ctx.get_global_file_v3()

	var filename := "godot_s2s_test_%d.txt" % Time.get_ticks_usec()
	var file_data := "brainCloud GDScript S2S upload test".to_utf8_buffer()

	var upload_result := await gfv3.upload_global_file("_root_", filename, true, file_data)
	t.expect_status_ok(upload_result)

	# The upload confirmation response nests fileDetails twice: the outer wraps the
	# whole confirmation payload, the inner carries the actual file fields.
	var uploaded_details: Dictionary = upload_result.get("data", {}).get("fileDetails", {}).get("fileDetails", {})
	var file_id := String(uploaded_details.get("fileId", ""))
	t.expect_true(not file_id.is_empty(), "upload response should include a fileId")

	if not file_id.is_empty():
		var info_result := await gfv3.sys_get_file_info(file_id)
		t.expect_status_ok(info_result)
		t.expect_eq(String(info_result.get("data", {}).get("fileDetails", {}).get("fileName", "")), filename, "file info fileName should match")

		var delete_result := await gfv3.sys_delete_global_file(file_id, -1, filename)
		t.expect_status_ok(delete_result)

	ctx.queue_free()

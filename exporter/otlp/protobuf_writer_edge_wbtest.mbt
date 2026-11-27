///|
fn clear_encoder_pool() -> Unit {
  while encoder_pool.pop() is Some(_) {
    ()
  }
}

///|
test "proto writer grows small buffers for varints and tags" {
  let writer = ProtoWriter::with_capacity(0)
  assert_eq(writer.buf.length(), 1)
  writer.write_varint(0x7FUL)
  assert_eq(writer.to_bytes(), b"\x7f")
  writer.write_varint(0x80UL)
  assert_eq(writer.to_bytes(), b"\x7f\x80\x01")
  writer.write_tag(1, 0)
  writer.write_tag(16, 0)
  assert_eq(writer.to_bytes(), b"\x7f\x80\x01\x08\x80\x01")
}

///|
test "proto writer encodes ten byte varints" {
  let writer = ProtoWriter::with_capacity(1)
  writer.write_varint(0xFFFFFFFFFFFFFFFFUL)
  assert_eq(writer.to_bytes(), b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01")
}

///|
test "proto writer field helpers cover short and long tags" {
  let writer = ProtoWriter::with_capacity(1)
  writer.write_varint_field(1, 1UL)
  writer.write_varint_field(1, 0x80UL)
  writer.write_varint_field(16, 1UL)
  writer.write_bool_field(2, true)
  writer.write_fixed32_field(3, 0x04030201U)
  writer.write_fixed32_field(16, 0x08070605U)
  writer.write_fixed64_field(4, 0x0807060504030201UL)
  writer.write_fixed64_field(16, 0x100F0E0D0C0B0A09UL)
  writer.write_double_field(9, 1.0)
  assert_eq(
    writer.to_bytes(),
    b"\x08\x01\x08\x80\x01\x80\x01\x01\x10\x01\x1d\x01\x02\x03\x04\x85\x01\x05\x06\x07\x08\x21\x01\x02\x03\x04\x05\x06\x07\x08\x81\x01\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x49\x00\x00\x00\x00\x00\x00\xf0\x3f",
  )
}

///|
test "proto writer fixed fields grow tight buffers" {
  let fixed32 = ProtoWriter::with_capacity(1)
  fixed32.write_fixed32_field(3, 0x04030201U)
  assert_eq(fixed32.to_bytes(), b"\x1d\x01\x02\x03\x04")
  let fixed64 = ProtoWriter::with_capacity(1)
  fixed64.write_fixed64_field(4, 0x0807060504030201UL)
  assert_eq(fixed64.to_bytes(), b"\x21\x01\x02\x03\x04\x05\x06\x07\x08")
}

///|
test "proto writer fixed fields grow tight buffers for long tags" {
  let fixed32 = ProtoWriter::with_capacity(1)
  fixed32.write_fixed32_field(16, 0x04030201U)
  assert_eq(fixed32.to_bytes(), b"\x85\x01\x01\x02\x03\x04")
  let fixed64 = ProtoWriter::with_capacity(1)
  fixed64.write_fixed64_field(16, 0x0807060504030201UL)
  assert_eq(
    fixed64.to_bytes(),
    b"\x81\x01\x01\x02\x03\x04\x05\x06\x07\x08",
  )
}

///|
test "proto writer byte arrays cover fast and fallback element paths" {
  let writer = ProtoWriter::with_capacity(1)
  writer.write_bytes(b"")
  writer.write_bytes(b"abc")
  assert_eq(writer.to_bytes(), b"\x00\x03abc")
  let arrays = ProtoWriter::with_capacity(1)
  arrays.write_bytes_from_int_array(1, [])
  arrays.write_bytes_from_int_array(1, [1, 2])
  arrays.write_bytes_from_int_array(1, [0x1234, -1, 256, 3, 4])
  arrays.write_bytes_from_int_array(16, [5, 6, 7])
  assert_eq(
    arrays.to_bytes(),
    b"\x0a\x00\x0a\x02\x01\x02\x0a\x05\x04\x0f\x00\x03\x04\x82\x01\x03\x05\x06\x07",
  )
}

///|
test "proto writer strings cover ASCII, UTF-8 and long lengths" {
  let writer = ProtoWriter::with_capacity(1)
  writer.write_string_field(1, "")
  writer.write_string_field(1, "hi")
  writer.write_string_field(1, "é")
  writer.write_string_field(1, "aé")
  assert_eq(
    writer.to_bytes(),
    b"\x0a\x00\x0a\x02hi\x0a\x02\xc3\xa9\x0a\x03a\xc3\xa9",
  )
  let long = StringBuilder()
  let mut i = 0
  while i < 130 {
    long.write_char('a')
    i = i + 1
  }
  let long_text = long.to_string()
  writer.write_string_field(1, long_text)
  writer.write_string_field(2, long_text + "é")
  let bytes = writer.to_bytes()
  assert_eq(bytes.length(), 283)
  assert_eq(bytes[148], b'\x12')
  assert_eq(bytes[149], b'\x84')
  assert_eq(bytes[150], b'\x01')
  assert_eq(bytes[151], b'a')
  assert_eq(bytes[281], b'\xc3')
  assert_eq(bytes[282], b'\xa9')
}

///|
test "proto writer raw ASCII writer leaves the length unchanged on failure" {
  let writer = ProtoWriter::with_capacity(1)
  assert_true(writer.try_write_ascii_raw("abcd"))
  assert_eq(writer.to_bytes(), b"abcd")
  assert_false(writer.try_write_ascii_raw("aébc"))
  assert_eq(writer.to_bytes(), b"abcd")
  assert_false(writer.try_write_ascii_raw("abcdefé"))
  assert_eq(writer.to_bytes(), b"abcd")
}

///|
test "proto writer messages pad, shift and grow length prefixes" {
  let small = ProtoWriter::with_capacity(1)
  let small_pos = small.begin_message(1)
  small.write_string_field(1, "x")
  small.end_message(small_pos)
  assert_eq(small.to_bytes(), b"\x0a\x03\x0a\x01x")
  let medium = ProtoWriter::with_capacity(1)
  let medium_pos = medium.begin_message(1)
  let medium_text = StringBuilder()
  let mut i = 0
  while i < 126 {
    medium_text.write_char('a')
    i = i + 1
  }
  medium.write_string_field(2, medium_text.to_string())
  medium.end_message(medium_pos)
  let medium_bytes = medium.to_bytes()
  assert_eq(medium_bytes.length(), 131)
  assert_eq(medium_bytes[0], b'\x0a')
  assert_eq(medium_bytes[1], b'\x80')
  assert_eq(medium_bytes[2], b'\x01')
  assert_eq(medium_bytes[3], b'\x12')
  assert_eq(medium_bytes[4], b'\x7e')
  let exact = ProtoWriter::with_capacity(1)
  let exact_pos = exact.begin_message(1)
  let exact_text = StringBuilder()
  i = 0
  while i < 16381 {
    exact_text.write_char('b')
    i = i + 1
  }
  exact.write_string_field(2, exact_text.to_string())
  exact.end_message(exact_pos)
  let exact_bytes = exact.to_bytes()
  assert_eq(exact_bytes.length(), 16388)
  assert_eq(exact_bytes[0], b'\x0a')
  assert_eq(exact_bytes[1], b'\x80')
  assert_eq(exact_bytes[2], b'\x80')
  assert_eq(exact_bytes[3], b'\x01')
  assert_eq(exact_bytes[4], b'\x12')
  let large = ProtoWriter::with_capacity(1)
  let large_pos = large.begin_message(1)
  let body = FixedArray::make(2097153, b'\xab')
  large.write_bytes(Bytes::from_array(body))
  large.end_message(large_pos)
  let large_bytes = large.to_bytes()
  assert_eq(large_bytes.length(), 2097162)
  assert_eq(large_bytes[0], b'\x0a')
  assert_eq(large_bytes[1], b'\x85')
  assert_eq(large_bytes[2], b'\x80')
  assert_eq(large_bytes[3], b'\x80')
  assert_eq(large_bytes[4], b'\x01')
  assert_eq(large_bytes[5], b'\x81')
  assert_eq(large_bytes[6], b'\x80')
  assert_eq(large_bytes[7], b'\x80')
  assert_eq(large_bytes[8], b'\x01')
  assert_eq(large_bytes[9], b'\xab')
  assert_eq(large_bytes[large_bytes.length() - 1], b'\xab')
}

///|
test "proto writer scratch buffers are reused, resized and trimmed" {
  let root = ProtoWriter::with_capacity(1)
  let fresh = root.take_scratch()
  assert_eq(fresh.buf.length(), 128)
  fresh.write_varint(1UL)
  root.release_scratch(fresh)
  let reused = root.take_scratch()
  assert_eq(reused.len, 0)
  assert_eq(reused.buf.length(), 128)
  root.release_scratch(reused)
  let resized = root.take_scratch_with_capacity(300)
  assert_eq(resized.buf.length(), 300)
  root.release_scratch(resized)
  let large_enough = root.take_scratch_with_capacity(200)
  assert_eq(large_enough.buf.length(), 300)
  large_enough.buf = FixedArray::make(MAX_SCRATCH_BUFFER_BYTES + 1, b'\x00')
  root.release_scratch(large_enough)
  let trimmed = root.take_scratch()
  assert_eq(trimmed.buf.length(), 128)
  let empty_root = ProtoWriter::with_capacity(1)
  let capacity_root = empty_root.take_scratch_with_capacity(0)
  assert_eq(capacity_root.buf.length(), 1)
}

///|
test "proto writer root pool reuses writers and trims oversized buffers" {
  clear_encoder_pool()
  let initial = take_root_writer(0)
  assert_eq(initial.buf.length(), 1)
  initial.write_varint(1UL)
  release_root_writer(initial)
  assert_eq(encoder_pool.length(), 1)
  let reused = take_root_writer(10)
  assert_eq(reused.len, 0)
  assert_eq(reused.buf.length(), 1)
  let scratch = reused.take_scratch_with_capacity(POOLED_BUFFER_BYTES + 1)
  reused.release_scratch(scratch)
  reused.buf = FixedArray::make(POOLED_BUFFER_BYTES + 1, b'\x00')
  release_root_writer(reused)
  assert_eq(encoder_pool.length(), 1)
  let pooled = encoder_pool[0]
  assert_eq(pooled.buf.length(), POOLED_BUFFER_BYTES)
  assert_eq(pooled.scratch.length(), 1)
  assert_eq(pooled.scratch[0].buf.length(), POOLED_BUFFER_BYTES)
  clear_encoder_pool()
}

///|
test "proto writer root pool resets buffers above the root limit" {
  clear_encoder_pool()
  encoder_pool.push({
    buf: FixedArray::make(MAX_ROOT_BUFFER_BYTES + 1, b'\x00'),
    len: 17,
    scratch: [],
  })
  let empty_hint = take_root_writer(0)
  assert_eq(empty_hint.len, 0)
  assert_eq(empty_hint.buf.length(), 1)
  encoder_pool.push({
    buf: FixedArray::make(MAX_ROOT_BUFFER_BYTES + 1, b'\x00'),
    len: 17,
    scratch: [],
  })
  let writer = take_root_writer(3)
  assert_eq(writer.len, 0)
  assert_eq(writer.buf.length(), 3)
  clear_encoder_pool()
}

///|
test "proto writer root pool caps retention" {
  clear_encoder_pool()
  let mut i : Int32 = 0
  while i < MAX_ENCODER_POOL_SIZE {
    encoder_pool.push(ProtoWriter::with_capacity(1))
    i = i + 1
  }
  let extra = ProtoWriter::with_capacity(1)
  extra.write_varint(1UL)
  release_root_writer(extra)
  assert_eq(encoder_pool.length(), MAX_ENCODER_POOL_SIZE)
  clear_encoder_pool()
}

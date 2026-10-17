///|
fn probe_vs(value : UInt64) -> Int {
  if value < 0x80 {
    1
  } else if value < 0x4000 {
    2
  } else if value < 0x200000 {
    3
  } else if value < 0x10000000 {
    4
  } else if value < 0x800000000 {
    5
  } else if value < 0x40000000000 {
    6
  } else if value < 0x2000000000000 {
    7
  } else if value < 0x100000000000000 {
    8
  } else if value < 0x8000000000000000 {
    9
  } else {
    10
  }
}

///|
fn probe_ascii_len(value : String) -> Int {
  let len = value.length()
  let mut i = 0
  while i < len {
    if value.unsafe_get(i).to_int() >= 0x80 {
      return -1
    }
    i = i + 1
  }
  len
}

///|
fn probe_write_ascii_chars(
  writer : ProtoWriter,
  value : String,
  len : Int
) -> Unit {
  let buf = writer.buf
  let mut pos = writer.len
  let mut i = 0
  while i < len {
    buf.unsafe_set(pos, value.unsafe_get(i).to_int().to_byte())
    pos = pos + 1
    i = i + 1
  }
  writer.len = pos
}

///|
fn probe_write_string_known(
  writer : ProtoWriter,
  field : Int,
  value : String,
  len : Int
) -> Unit {
  writer.write_tag(field, 2)
  writer.write_varint(len.to_uint64())
  probe_write_ascii_chars(writer, value, len)
}

///|
fn probe_attr_fast(
  writer : ProtoWriter,
  field : Int,
  key : String,
  value : @sdk.AttributeValue
) -> Bool {
  let klen = probe_ascii_len(key)
  if klen < 0 {
    return false
  }
  let klenv = klen.to_uint64()
  let key_field = 1 + probe_vs(klenv) + klen
  match value {
    StringValue(text) => {
      let slen = probe_ascii_len(text)
      if slen < 0 {
        return false
      }
      let slenv = slen.to_uint64()
      let any_content = 1 + probe_vs(slenv) + slen
      let any_field = 1 + probe_vs(any_content.to_uint64()) +
        any_content
      let kv_len = key_field + any_field
      let kv_lenv = kv_len.to_uint64()
      let total = 1 + probe_vs(kv_lenv) + kv_len
      if writer.len + total > writer.buf.length() {
        writer.reserve(total)
      }
      writer.write_tag(field, 2)
      writer.write_varint(kv_lenv)
      writer.write_tag(1, 2)
      writer.write_varint(klenv)
      probe_write_ascii_chars(writer, key, klen)
      writer.write_tag(2, 2)
      writer.write_varint(any_content.to_uint64())
      writer.write_tag(1, 2)
      writer.write_varint(slenv)
      probe_write_ascii_chars(writer, text, slen)
      true
    }
    BoolValue(flag) => {
      let any_content = 2
      let any_field = 1 + 1 + any_content
      let kv_len = key_field + any_field
      let kv_lenv = kv_len.to_uint64()
      let total = 1 + probe_vs(kv_lenv) + kv_len
      if writer.len + total > writer.buf.length() {
        writer.reserve(total)
      }
      writer.write_tag(field, 2)
      writer.write_varint(kv_lenv)
      writer.write_tag(1, 2)
      writer.write_varint(klenv)
      probe_write_ascii_chars(writer, key, klen)
      writer.write_tag(2, 2)
      writer.write_varint(2)
      writer.write_bool_field(2, flag)
      true
    }
    IntValue(number) => {
      let nv = number.reinterpret_as_uint64()
      let any_content = 1 + probe_vs(nv)
      let any_field = 1 + probe_vs(any_content.to_uint64()) +
        any_content
      let kv_len = key_field + any_field
      let kv_lenv = kv_len.to_uint64()
      let total = 1 + probe_vs(kv_lenv) + kv_len
      if writer.len + total > writer.buf.length() {
        writer.reserve(total)
      }
      writer.write_tag(field, 2)
      writer.write_varint(kv_lenv)
      writer.write_tag(1, 2)
      writer.write_varint(klenv)
      probe_write_ascii_chars(writer, key, klen)
      writer.write_tag(2, 2)
      writer.write_varint(any_content.to_uint64())
      writer.write_varint_field(3, nv)
      true
    }
    DoubleValue(number) => {
      let any_content = 9
      let any_field = 1 + 1 + any_content
      let kv_len = key_field + any_field
      let kv_lenv = kv_len.to_uint64()
      let total = 1 + probe_vs(kv_lenv) + kv_len
      if writer.len + total > writer.buf.length() {
        writer.reserve(total)
      }
      writer.write_tag(field, 2)
      writer.write_varint(kv_lenv)
      writer.write_tag(1, 2)
      writer.write_varint(klenv)
      probe_write_ascii_chars(writer, key, klen)
      writer.write_tag(2, 2)
      writer.write_varint(9)
      writer.write_double_field(4, number)
      true
    }
    _ => false
  }
}

///|
fn probe_encode_attributes_fast(
  writer : ProtoWriter,
  field : Int,
  attributes : Map[String, @sdk.AttributeValue]
) -> Unit {
  attributes.each(fn(key, value) {
    if !probe_attr_fast(writer, field, key, value) {
      let kv = writer.take_scratch()
      kv.write_string_field(1, key)
      let any_value = kv.take_scratch()
      encode_any_value(any_value, value)
      kv.append_message(2, any_value)
      writer.append_message(field, kv)
    }
  })
}

///|
test "zz_myprobe_encode_wb3" (b : @bench.T) {
  let attributes : Map[String, @sdk.AttributeValue] = Map([
    ("http.request.method", StringValue("GET")),
    ("url.full", StringValue("http://example.com/path?q=1")),
    ("server.address", StringValue("example.com")),
    ("server.port", IntValue(80L)),
    ("http.response.status_code", IntValue(200L)),
  ])
  b.bench(fn() {
    let w = ProtoWriter::with_capacity(448)
    encode_attributes(w, 9, attributes)
    let _ = w.to_bytes()
  })
  b.bench(fn() {
    let w = ProtoWriter::with_capacity(448)
    probe_encode_attributes_fast(w, 9, attributes)
    let _ = w.to_bytes()
  })
}

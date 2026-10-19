// Minimal protobuf wire-format writer used by the OTLP encoder.
// Only the wire types needed by the OTLP trace service are implemented.

///|
priv struct ProtoWriter {
  mut buf : FixedArray[Byte]
  mut len : Int32
  // Scratch writers for nested message encodings, used like a call stack: a
  // nested message takes one and releases it after appending its bytes.
  scratch : Array[ProtoWriter]
}

///|
fn ProtoWriter::with_capacity(size_hint : Int32) -> ProtoWriter {
  let capacity = if size_hint < 1 { 1 } else { size_hint }
  { buf: FixedArray::make(capacity, b'\x00'), len: 0, scratch: [], }
}

// Root writers used by `encode_trace_request`. Writers are taken from a
// bounded pool while encoding and released when their bytes have been
// produced, so concurrent encodings never share a buffer.

///|
let encoder_pool : Array[ProtoWriter] = []

// Capacity limits above which recycled buffers are not pooled.
const MAX_ROOT_BUFFER_BYTES : Int32 = 4 * 1024 * 1024

///|
const MAX_SCRATCH_BUFFER_BYTES : Int32 = 1024 * 1024

///|
const MAX_ENCODER_POOL_SIZE : Int = 8

// Buffers above this size are trimmed before a writer goes back into the pool.

///|
const POOLED_BUFFER_BYTES : Int32 = 64 * 1024

///|
fn take_root_writer(size_hint : Int32) -> ProtoWriter {
  match encoder_pool.pop() {
    Some(writer) => {
      writer.len = 0
      if writer.buf.length() > MAX_ROOT_BUFFER_BYTES {
        writer.buf = FixedArray::make(if size_hint < 1 { 1 } else { size_hint }, b'\x00')
      }
      writer
    }
    None => ProtoWriter::with_capacity(size_hint)
  }
}

///|
fn release_root_writer(writer : ProtoWriter) -> Unit {
  if encoder_pool.length() < MAX_ENCODER_POOL_SIZE {
    writer.len = 0
    if writer.buf.length() > POOLED_BUFFER_BYTES {
      writer.buf = FixedArray::make(POOLED_BUFFER_BYTES, b'\x00')
    }
    // The nested writers retained on the scratch stack are trimmed as well.
    for buffer in writer.scratch {
      buffer.len = 0
      if buffer.buf.length() > POOLED_BUFFER_BYTES {
        buffer.buf = FixedArray::make(POOLED_BUFFER_BYTES, b'\x00')
      }
    }
    encoder_pool.push(writer)
  }
}

// Grow the buffer to fit `extra` more bytes, doubling the capacity as needed.
// Call sites check `len + extra <= buf.length()` inline before calling this.

///|
fn ProtoWriter::reserve(self : ProtoWriter, extra : Int32) -> Unit {
  let required = self.len + extra
  let current = self.buf.length()
  let doubled = if current > 0x3FFFFFFF { required } else { current * 2 }
  let capacity = if doubled > required { doubled } else { required }
  let grown : FixedArray[Byte] = FixedArray::make(capacity, b'\x00')
  grown.unsafe_blit(0, self.buf, 0, self.len)
  self.buf = grown
}

///|
fn ProtoWriter::take_scratch(self : ProtoWriter) -> ProtoWriter {
  match self.scratch.pop() {
    Some(buffer) => buffer
    None => ProtoWriter::with_capacity(128)
  }
}

// Like `take_scratch`, but ensures the returned writer's buffer can hold at
// least `hint` bytes.

///|
fn ProtoWriter::take_scratch_with_capacity(
  self : ProtoWriter,
  hint : Int32,
) -> ProtoWriter {
  match self.scratch.pop() {
    Some(buffer) => {
      if buffer.buf.length() < hint {
        buffer.buf = FixedArray::make(hint, b'\x00')
      }
      buffer
    }
    None => ProtoWriter::with_capacity(hint)
  }
}

///|
fn ProtoWriter::release_scratch(
  self : ProtoWriter,
  buffer : ProtoWriter,
) -> Unit {
  buffer.len = 0
  if buffer.buf.length() > MAX_SCRATCH_BUFFER_BYTES {
    buffer.buf = FixedArray::make(128, b'\x00')
  }
  self.scratch.push(buffer)
}

///|
fn ProtoWriter::to_bytes(self : ProtoWriter) -> Bytes {
  Bytes::from_array(self.buf[:self.len])
}

///|
fn ProtoWriter::write_varint(self : ProtoWriter, value : UInt64) -> Unit {
  if value < 0x80 {
    if self.len + 1 > self.buf.length() {
      self.reserve(1)
    }
    self.buf.unsafe_set(self.len, value.to_byte())
    self.len = self.len + 1
    return
  }
  // A 64-bit varint is at most 10 bytes.
  if self.len + 10 > self.buf.length() {
    self.reserve(10)
  }
  let buf = self.buf
  let mut v = value
  let mut i = self.len
  while v >= 0x80 {
    buf.unsafe_set(i, ((v & 0x7F) | 0x80).to_int().to_byte())
    v = v >> 7
    i = i + 1
  }
  buf.unsafe_set(i, v.to_int().to_byte())
  self.len = i + 1
}

///|
fn ProtoWriter::write_tag(
  self : ProtoWriter,
  field : Int32,
  wire_type : Int32,
) -> Unit {
  let tag = (field << 3) | wire_type
  if tag >= 0 && tag < 0x80 {
    if self.len + 1 > self.buf.length() {
      self.reserve(1)
    }
    self.buf.unsafe_set(self.len, tag.to_byte())
    self.len = self.len + 1
    return
  }
  self.write_varint(tag.to_uint64())
}

// Begin a length-delimited message field whose body is written directly into
// this writer: writes the tag and three reserved length bytes, then returns
// the position of the length field. `field` must be below 16 so that the tag
// is a single byte. The caller writes the body and then calls `end_message`
// with the returned position.

///|
fn ProtoWriter::begin_message(self : ProtoWriter, field : Int32) -> Int32 {
  if self.len + 4 > self.buf.length() {
    self.reserve(4)
  }
  let start = self.len
  self.buf.unsafe_set(start, ((field << 3) | 2).to_byte())
  self.len = start + 4
  start + 1
}

// Close a message opened by `begin_message`: pads the length varint to its
// exact width by moving the body, or shrinks the reserved space when the body
// needs fewer bytes.

///|
fn ProtoWriter::end_message(self : ProtoWriter, len_pos : Int32) -> Unit {
  let body_start = len_pos + 3
  let body_len = self.len - body_start
  let needed = varint_size(body_len.to_uint64())
  if needed < 3 {
    self.buf.unsafe_blit(len_pos + needed, self.buf, body_start, body_len)
  } else if needed > 3 {
    // The reserved room was too small for the length varint: make room by
    // moving the body to the right.
    let extra = needed - 3
    if self.len + extra > self.buf.length() {
      self.reserve(extra)
    }
    self.buf.unsafe_blit(body_start + extra, self.buf, body_start, body_len)
  }
  let mut value = body_len.to_uint64()
  let mut pos = len_pos
  while value >= 0x80 {
    self.buf.unsafe_set(pos, ((value & 0x7F) | 0x80).to_int().to_byte())
    value = value >> 7
    pos = pos + 1
  }
  self.buf.unsafe_set(pos, value.to_int().to_byte())
  self.len = len_pos + needed + body_len
}

// Write the tag and length prefix of a length-delimited field.

///|
fn ProtoWriter::write_message_header(
  self : ProtoWriter,
  field : Int32,
  len : Int32,
) -> Unit {
  let tag = (field << 3) | 2
  if tag >= 0 && tag < 0x80 && len < 0x80 {
    if self.len + 2 > self.buf.length() {
      self.reserve(2)
    }
    self.buf.unsafe_write_uint16_le(
      self.len,
      tag.to_uint16() | (len.to_uint16() << 8),
    )
    self.len = self.len + 2
    return
  }
  self.write_tag(field, 2)
  self.write_varint(len.to_uint64())
}

///|
fn ProtoWriter::write_varint_field(
  self : ProtoWriter,
  field : Int32,
  value : UInt64,
) -> Unit {
  let tag = field << 3
  if tag >= 0 && tag < 0x80 && value < 0x80 {
    if self.len + 2 > self.buf.length() {
      self.reserve(2)
    }
    self.buf.unsafe_write_uint16_le(
      self.len,
      tag.to_uint16() | (value.to_uint16() << 8),
    )
    self.len = self.len + 2
    return
  }
  self.write_tag(field, 0)
  self.write_varint(value)
}

///|
fn ProtoWriter::write_bool_field(
  self : ProtoWriter,
  field : Int32,
  value : Bool,
) -> Unit {
  self.write_varint_field(field, if value { 1 } else { 0 })
}

///|
fn ProtoWriter::write_fixed64_field(
  self : ProtoWriter,
  field : Int32,
  value : UInt64,
) -> Unit {
  let tag = (field << 3) | 1
  if tag >= 0 && tag < 0x80 {
    if self.len + 9 > self.buf.length() {
      self.reserve(9)
    }
    let buf = self.buf
    let pos = self.len
    buf.unsafe_set(pos, tag.to_byte())
    buf.unsafe_write_uint64_le(pos + 1, value)
    self.len = pos + 9
    return
  }
  self.write_tag(field, 1)
  if self.len + 8 > self.buf.length() {
    self.reserve(8)
  }
  self.buf.unsafe_write_uint64_le(self.len, value)
  self.len = self.len + 8
}

///|
fn ProtoWriter::write_double_field(
  self : ProtoWriter,
  field : Int32,
  value : Double,
) -> Unit {
  self.write_fixed64_field(field, value.reinterpret_as_uint64())
}

///|
fn ProtoWriter::write_fixed32_field(
  self : ProtoWriter,
  field : Int32,
  value : UInt32,
) -> Unit {
  let tag = (field << 3) | 5
  if tag >= 0 && tag < 0x80 {
    if self.len + 5 > self.buf.length() {
      self.reserve(5)
    }
    let buf = self.buf
    let pos = self.len
    buf.unsafe_set(pos, tag.to_byte())
    buf.unsafe_write_uint32_le(pos + 1, value)
    self.len = pos + 5
    return
  }
  self.write_tag(field, 5)
  if self.len + 4 > self.buf.length() {
    self.reserve(4)
  }
  self.buf.unsafe_write_uint32_le(self.len, value)
  self.len = self.len + 4
}

///|
fn ProtoWriter::write_bytes(self : ProtoWriter, value : Bytes) -> Unit {
  let len = value.length()
  self.write_varint(len.to_uint64())
  if self.len + len > self.buf.length() {
    self.reserve(len)
  }
  self.buf.blit_from_bytes(self.len, value, 0, len)
  self.len = self.len + len
}

// Write a length-delimited bytes field from an array of byte values, masking
// each element to 8 bits.

///|
fn ProtoWriter::write_bytes_from_int_array(
  self : ProtoWriter,
  field : Int32,
  values : Array[Int32],
) -> Unit {
  let len = values.length()
  self.write_message_header(field, len)
  if self.len + len > self.buf.length() {
    self.reserve(len)
  }
  let buf = self.buf
  let mut pos = self.len
  let mut i = 0
  while i + 4 <= len {
    let v0 = values.unsafe_get(i) & 0xFF
    let v1 = values.unsafe_get(i + 1) & 0xFF
    let v2 = values.unsafe_get(i + 2) & 0xFF
    let v3 = values.unsafe_get(i + 3) & 0xFF
    buf.unsafe_write_uint32_le(
      pos,
      (v0 | (v1 << 8) | (v2 << 16) | (v3 << 24)).reinterpret_as_uint(),
    )
    pos = pos + 4
    i = i + 4
  }
  while i < len {
    buf.unsafe_set(pos, (values.unsafe_get(i) & 0xFF).to_byte())
    pos = pos + 1
    i = i + 1
  }
  self.len = pos
}

// Write a length-delimited string field, encoding non-ASCII text as UTF-8.

///|
fn ProtoWriter::write_string_field(
  self : ProtoWriter,
  field : Int32,
  value : String,
) -> Unit {
  let len = value.length()
  let tag = (field << 3) | 2
  let start = if tag >= 0 && tag < 0x80 && len < 0x80 {
    if self.len + 2 > self.buf.length() {
      self.reserve(2)
    }
    let pos = self.len
    self.buf.unsafe_write_uint16_le(
      pos,
      tag.to_uint16() | (len.to_uint16() << 8),
    )
    self.len = pos + 2
    // Rollback keeps the tag: non-ASCII text is re-encoded as UTF-8 with a
    // fresh length below.
    pos + 1
  } else {
    self.write_tag(field, 2)
    let header_start = self.len
    self.write_varint(len.to_uint64())
    header_start
  }
  if self.len + len > self.buf.length() {
    self.reserve(len)
  }
  let buf = self.buf
  let mut pos = self.len
  let mut i = 0
  // Write ASCII code units until a non-ASCII code unit shows up.
  while i + 4 <= len {
    let c0 = value.unsafe_get(i).to_int()
    let c1 = value.unsafe_get(i + 1).to_int()
    let c2 = value.unsafe_get(i + 2).to_int()
    let c3 = value.unsafe_get(i + 3).to_int()
    if (c0 | c1 | c2 | c3) >= 0x80 {
      break
    }
    buf.unsafe_write_uint32_le(
      pos,
      (c0 | (c1 << 8) | (c2 << 16) | (c3 << 24)).reinterpret_as_uint(),
    )
    pos = pos + 4
    i = i + 4
  }
  while i < len {
    let code = value.unsafe_get(i).to_int()
    if code >= 0x80 {
      self.len = start
      let encoded = @utf8.encode(value)
      self.write_bytes(encoded)
      return
    }
    buf.unsafe_set(pos, code.to_byte())
    pos = pos + 1
    i = i + 1
  }
  self.len = pos
}

// Write the bytes of an ASCII string without a tag or length prefix. On the
// first non-ASCII code unit nothing is committed (`len` is left unchanged)
// and `false` is returned, so the caller can fall back to UTF-8 encoding.

///|
fn ProtoWriter::try_write_ascii_raw(self : ProtoWriter, value : String) -> Bool {
  let len = value.length()
  if self.len + len > self.buf.length() {
    self.reserve(len)
  }
  let buf = self.buf
  let mut pos = self.len
  let mut i = 0
  while i + 4 <= len {
    let c0 = value.unsafe_get(i).to_int()
    let c1 = value.unsafe_get(i + 1).to_int()
    let c2 = value.unsafe_get(i + 2).to_int()
    let c3 = value.unsafe_get(i + 3).to_int()
    if (c0 | c1 | c2 | c3) >= 0x80 {
      return false
    }
    buf.unsafe_write_uint32_le(
      pos,
      (c0 | (c1 << 8) | (c2 << 16) | (c3 << 24)).reinterpret_as_uint(),
    )
    pos = pos + 4
    i = i + 4
  }
  while i < len {
    let code = value.unsafe_get(i).to_int()
    if code >= 0x80 {
      return false
    }
    buf.unsafe_set(pos, code.to_byte())
    pos = pos + 1
    i = i + 1
  }
  self.len = pos
  true
}

// Append an already encoded nested message with a length prefix, releasing
// the writer that produced it.

///|
fn ProtoWriter::append_message(
  self : ProtoWriter,
  field : Int32,
  inner : ProtoWriter,
) -> Unit {
  let len = inner.len
  self.write_message_header(field, len)
  if self.len + len > self.buf.length() {
    self.reserve(len)
  }
  self.buf.unsafe_blit(self.len, inner.buf, 0, len)
  self.len = self.len + len
  self.release_scratch(inner)
}

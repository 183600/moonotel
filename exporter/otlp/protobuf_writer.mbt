// Minimal protobuf wire-format writer used by the OTLP encoder.
// Only the wire types needed by the OTLP trace service are implemented.

priv struct ProtoWriter {
  mut buf : FixedArray[Byte]
  mut len : Int
  // Scratch writers for nested message encodings, used like a call stack: a
  // nested message takes one and releases it after appending its bytes.
  scratch : Array[ProtoWriter]
}

fn ProtoWriter::with_capacity(size_hint : Int) -> ProtoWriter {
  let capacity = if size_hint < 1 { 1 } else { size_hint }
  { buf: FixedArray::make(capacity, b'\x00'), len: 0, scratch: [] }
}

// Reusable root writer for `encode_trace_request`. Its buffer and the pool of
// nested-message scratch writers are kept between calls, so repeated encoding
// allocates only the returned `Bytes`. Encoding never re-enters itself, so the
// pool is safe to share process-wide.
let encoder_pool : Ref[ProtoWriter?] = Ref(None)

fn take_root_writer(size_hint : Int) -> ProtoWriter {
  match encoder_pool.val {
    Some(writer) => {
      writer.len = 0
      writer
    }
    None => {
      let writer = ProtoWriter::with_capacity(size_hint)
      encoder_pool.val = Some(writer)
      writer
    }
  }
}

// Grow the buffer to fit `extra` more bytes, doubling the capacity as needed.
// Call sites check `len + extra <= buf.length()` inline before calling this.
fn ProtoWriter::reserve(self : ProtoWriter, extra : Int) -> Unit {
  let required = self.len + extra
  let doubled = self.buf.length() * 2
  let capacity = if doubled > required { doubled } else { required }
  let grown : FixedArray[Byte] = FixedArray::make(capacity, b'\x00')
  grown.unsafe_blit(0, self.buf, 0, self.len)
  self.buf = grown
}



fn ProtoWriter::take_scratch(self : ProtoWriter) -> ProtoWriter {
  match self.scratch.pop() {
    Some(buffer) => buffer
    None => ProtoWriter::with_capacity(128)
  }
}

// Like `take_scratch`, but ensures the returned writer's buffer can hold at
// least `hint` bytes. A recycled writer carries no data: its length is reset
// when it is released.
fn ProtoWriter::take_scratch_with_capacity(
  self : ProtoWriter,
  hint : Int
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

fn ProtoWriter::release_scratch(self : ProtoWriter, buffer : ProtoWriter) -> Unit {
  buffer.len = 0
  self.scratch.push(buffer)
}

fn ProtoWriter::to_bytes(self : ProtoWriter) -> Bytes {
  Bytes::from_array(self.buf[:self.len])
}

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

fn ProtoWriter::write_tag(self : ProtoWriter, field : Int, wire_type : Int) -> Unit {
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

// Write the tag and length prefix of a length-delimited field. The fast path
// covers the common case of a one-byte tag and a one-byte length, which is
// what most OTLP fields need.
fn ProtoWriter::write_message_header(self : ProtoWriter, field : Int, len : Int) -> Unit {
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

fn ProtoWriter::write_varint_field(self : ProtoWriter, field : Int, value : UInt64) -> Unit {
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

fn ProtoWriter::write_bool_field(self : ProtoWriter, field : Int, value : Bool) -> Unit {
  self.write_varint_field(field, if value { 1 } else { 0 })
}

fn ProtoWriter::write_fixed64_field(self : ProtoWriter, field : Int, value : UInt64) -> Unit {
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

fn ProtoWriter::write_double_field(self : ProtoWriter, field : Int, value : Double) -> Unit {
  self.write_fixed64_field(field, value.reinterpret_as_uint64())
}

fn ProtoWriter::write_fixed32_field(self : ProtoWriter, field : Int, value : UInt) -> Unit {
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
fn ProtoWriter::write_bytes_from_int_array(
  self : ProtoWriter,
  field : Int,
  values : Array[Int]
) -> Unit {
  let len = values.length()
  self.write_message_header(field, len)
  if self.len + len > self.buf.length() {
    self.reserve(len)
  }
  let buf = self.buf
  let mut pos = self.len
  let mut i = 0
  // Trace and span IDs are 8 or 16 bytes; storing byte by byte beats packing
  // words for these short lengths.
  while i < len {
    buf.unsafe_set(pos, (values.unsafe_get(i) & 0xFF).to_byte())
    pos = pos + 1
    i = i + 1
  }
  self.len = pos
}

// Write a length-delimited string field, encoding non-ASCII text as UTF-8.
fn ProtoWriter::write_string_field(self : ProtoWriter, field : Int, value : String) -> Unit {
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
fn ProtoWriter::append_message(self : ProtoWriter, field : Int, inner : ProtoWriter) -> Unit {
  let len = inner.len
  self.write_message_header(field, len)
  if self.len + len > self.buf.length() {
    self.reserve(len)
  }
  self.buf.unsafe_blit(self.len, inner.buf, 0, len)
  self.len = self.len + len
  self.release_scratch(inner)
}


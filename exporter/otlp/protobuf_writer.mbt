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

// Ensure room for `extra` more bytes, doubling the capacity as needed.
fn ProtoWriter::reserve(self : ProtoWriter, extra : Int) -> Unit {
  let required = self.len + extra
  if required <= self.buf.length() {
    return
  }
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

fn ProtoWriter::release_scratch(self : ProtoWriter, buffer : ProtoWriter) -> Unit {
  buffer.len = 0
  self.scratch.push(buffer)
}

fn ProtoWriter::to_bytes(self : ProtoWriter) -> Bytes {
  Bytes::from_array(self.buf[:self.len])
}

fn ProtoWriter::write_varint(self : ProtoWriter, value : UInt64) -> Unit {
  // A 64-bit varint is at most 10 bytes.
  self.reserve(10)
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
  self.write_varint(((field << 3) | wire_type).to_uint64())
}

fn ProtoWriter::write_varint_field(self : ProtoWriter, field : Int, value : UInt64) -> Unit {
  self.write_tag(field, 0)
  self.write_varint(value)
}

fn ProtoWriter::write_bool_field(self : ProtoWriter, field : Int, value : Bool) -> Unit {
  self.write_varint_field(field, if value { 1 } else { 0 })
}

fn ProtoWriter::write_fixed64_field(self : ProtoWriter, field : Int, value : UInt64) -> Unit {
  self.write_tag(field, 1)
  self.reserve(8)
  self.buf.unsafe_write_uint64_le(self.len, value)
  self.len = self.len + 8
}

fn ProtoWriter::write_double_field(self : ProtoWriter, field : Int, value : Double) -> Unit {
  self.write_fixed64_field(field, value.reinterpret_as_uint64())
}

fn ProtoWriter::write_fixed32_field(self : ProtoWriter, field : Int, value : UInt) -> Unit {
  self.write_tag(field, 5)
  self.reserve(4)
  self.buf.unsafe_write_uint32_le(self.len, value)
  self.len = self.len + 4
}

fn ProtoWriter::write_bytes(self : ProtoWriter, value : Bytes) -> Unit {
  self.write_varint(value.length().to_uint64())
  self.reserve(value.length())
  self.buf.blit_from_bytes(self.len, value, 0, value.length())
  self.len = self.len + value.length()
}

// Write a length-delimited bytes field from an array of byte values, masking
// each element to 8 bits.
fn ProtoWriter::write_bytes_from_int_array(
  self : ProtoWriter,
  field : Int,
  values : Array[Int]
) -> Unit {
  self.write_tag(field, 2)
  let len = values.length()
  self.write_varint(len.to_uint64())
  self.reserve(len)
  let buf = self.buf
  let mut pos = self.len
  let mut i = 0
  while i < len {
    buf.unsafe_set(pos, (values.unsafe_get(i) & 0xFF).to_byte())
    pos = pos + 1
    i = i + 1
  }
  self.len = pos
}

// Write a length-delimited string field, encoding non-ASCII text as UTF-8.
fn ProtoWriter::write_string_field(self : ProtoWriter, field : Int, value : String) -> Unit {
  self.write_tag(field, 2)
  let len = value.length()
  let start = self.len
  self.write_varint(len.to_uint64())
  self.reserve(len)
  let buf = self.buf
  let mut pos = self.len
  let mut i = 0
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

// Append an already encoded nested message with a length prefix, releasing
// the writer that produced it.
fn ProtoWriter::append_message(self : ProtoWriter, field : Int, inner : ProtoWriter) -> Unit {
  self.write_tag(field, 2)
  self.write_varint(inner.len.to_uint64())
  self.reserve(inner.len)
  self.buf.unsafe_blit(self.len, inner.buf, 0, inner.len)
  self.len = self.len + inner.len
  self.release_scratch(inner)
}


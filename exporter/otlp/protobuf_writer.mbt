// Minimal protobuf wire-format writer used by the OTLP encoder.
// Only the wire types needed by the OTLP trace service are implemented.

priv struct ProtoWriter {
  mut buf : FixedArray[Byte]
  mut len : Int
  // Scratch writers recycled across nested message encodings. Encoding is
  // depth-first, so the writers behave like a call stack: a nested message
  // pops one, and the enclosing message pushes it back after appending it.
  scratch : Array[ProtoWriter]
}

fn ProtoWriter::with_capacity(size_hint : Int) -> ProtoWriter {
  let capacity = if size_hint < 1 { 1 } else { size_hint }
  { buf: FixedArray::make(capacity, b'\x00'), len: 0, scratch: [] }
}

// Ensure room for `extra` more bytes, doubling the capacity as needed so
// appends are amortized constant time.
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
    None => ProtoWriter::with_capacity(32)
  }
}

fn ProtoWriter::release_scratch(self : ProtoWriter, buffer : ProtoWriter) -> Unit {
  buffer.len = 0
  self.scratch.push(buffer)
}

fn ProtoWriter::to_bytes(self : ProtoWriter) -> Bytes {
  Bytes::from_array(self.buf[:self.len])
}

fn ProtoWriter::write_byte(self : ProtoWriter, value : Byte) -> Unit {
  self.reserve(1)
  self.buf[self.len] = value
  self.len = self.len + 1
}

fn ProtoWriter::write_varint(self : ProtoWriter, value : UInt64) -> Unit {
  let mut v = value
  while v >= 0x80 {
    self.write_byte(((v & 0x7F) | 0x80).to_int().to_byte())
    v = v >> 7
  }
  self.write_byte(v.to_int().to_byte())
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

fn ProtoWriter::write_bytes_field(self : ProtoWriter, field : Int, value : Bytes) -> Unit {
  self.write_tag(field, 2)
  self.write_bytes(value)
}

// Whether every UTF-16 code unit of the string is ASCII. For such strings the
// UTF-8 byte length equals the code-unit length and the string can be written
// without materializing an intermediate encoded byte array.
fn is_ascii_string(value : String) -> Bool {
  let len = value.length()
  let mut i = 0
  while i < len {
    if value.unsafe_get(i).to_int() >= 0x80 {
      return false
    }
    i = i + 1
  }
  true
}

fn ProtoWriter::write_ascii_string(self : ProtoWriter, value : String) -> Unit {
  let len = value.length()
  self.reserve(len)
  let mut i = 0
  while i < len {
    self.buf[self.len + i] = value.unsafe_get(i).to_int().to_byte()
    i = i + 1
  }
  self.len = self.len + len
}

fn ProtoWriter::write_string_field(self : ProtoWriter, field : Int, value : String) -> Unit {
  self.write_tag(field, 2)
  if is_ascii_string(value) {
    self.write_varint(value.length().to_uint64())
    self.write_ascii_string(value)
  } else {
    let encoded = @utf8.encode(value)
    self.write_bytes(encoded)
  }
}

// Append an already encoded nested message with a length prefix, recycling
// the writer that produced it. Callers that can fill a scratch writer directly
// use this to avoid allocating a closure per nested message.
fn ProtoWriter::append_message(self : ProtoWriter, field : Int, inner : ProtoWriter) -> Unit {
  self.write_tag(field, 2)
  self.write_varint(inner.len.to_uint64())
  self.reserve(inner.len)
  self.buf.unsafe_blit(self.len, inner.buf, 0, inner.len)
  self.len = self.len + inner.len
  self.release_scratch(inner)
}

// Helper: convert a byte array (values are masked to 8 bits) to Bytes.
fn bytes_from_bytes_array(values : Array[Int]) -> Bytes {
  Bytes::makei(values.length(), fn(i) { (values[i] & 0xFF).to_byte() })
}

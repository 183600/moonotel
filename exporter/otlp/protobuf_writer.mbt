// Minimal protobuf wire-format writer used by the OTLP encoder.
// Only the wire types needed by the OTLP trace service are implemented.

priv struct ProtoWriter {
  buf : Buffer
  // Scratch buffers recycled across nested message encodings. Encoding is
  // depth-first, so the buffers behave like a call stack: a nested message
  // pops one, and the enclosing message pushes it back after appending it.
  scratch : Array[Buffer]
}

fn ProtoWriter::with_capacity(size_hint : Int) -> ProtoWriter {
  { buf: Buffer(size_hint=size_hint), scratch: [] }
}

fn ProtoWriter::take_scratch(self : ProtoWriter) -> Buffer {
  match self.scratch.pop() {
    Some(buffer) => buffer
    None => Buffer(size_hint=32)
  }
}

fn ProtoWriter::release_scratch(self : ProtoWriter, buffer : Buffer) -> Unit {
  buffer.reset()
  self.scratch.push(buffer)
}

fn ProtoWriter::to_bytes(self : ProtoWriter) -> Bytes {
  self.buf.to_bytes()
}

fn ProtoWriter::write_varint(self : ProtoWriter, value : UInt64) -> Unit {
  let mut v = value
  while v >= 0x80 {
    self.buf.write_byte(((v & 0x7F) | 0x80).to_int().to_byte())
    v = v >> 7
  }
  self.buf.write_byte(v.to_int().to_byte())
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
  self.buf.write_uint64_le(value)
}

fn ProtoWriter::write_double_field(self : ProtoWriter, field : Int, value : Double) -> Unit {
  self.write_tag(field, 1)
  self.buf.write_double_le(value)
}

fn ProtoWriter::write_fixed32_field(self : ProtoWriter, field : Int, value : UInt) -> Unit {
  self.write_tag(field, 5)
  self.buf.write_uint_le(value)
}

fn ProtoWriter::write_bytes_field(self : ProtoWriter, field : Int, value : Bytes) -> Unit {
  self.write_tag(field, 2)
  self.write_varint(value.length().to_uint64())
  self.buf.write_bytes(value)
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

fn ProtoWriter::write_string_field(self : ProtoWriter, field : Int, value : String) -> Unit {
  self.write_tag(field, 2)
  if is_ascii_string(value) {
    self.write_varint(value.length().to_uint64())
    self.buf.write_string_utf8(value)
  } else {
    let encoded = @utf8.encode(value)
    self.write_varint(encoded.length().to_uint64())
    self.buf.write_bytes(encoded)
  }
}

// Encode a nested message with a length prefix.
fn ProtoWriter::write_message_field(
  self : ProtoWriter,
  field : Int,
  encode : (ProtoWriter) -> Unit
) -> Unit {
  let inner_buf = self.take_scratch()
  let inner : ProtoWriter = { buf: inner_buf, scratch: self.scratch }
  encode(inner)
  self.write_tag(field, 2)
  self.write_varint(inner_buf.length().to_uint64())
  self.buf.write_bytes(inner_buf.to_bytes())
  self.release_scratch(inner_buf)
}

// Helper: convert a byte array (values are masked to 8 bits) to Bytes.
fn bytes_from_bytes_array(values : Array[Int]) -> Bytes {
  Bytes::makei(values.length(), fn(i) { (values[i] & 0xFF).to_byte() })
}

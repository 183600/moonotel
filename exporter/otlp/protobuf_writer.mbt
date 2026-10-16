// Minimal protobuf wire-format writer used by the OTLP encoder.
// Only the wire types needed by the OTLP trace service are implemented.

priv struct ProtoWriter {
  buf : Buffer
}

fn ProtoWriter::new() -> ProtoWriter {
  { buf: Buffer() }
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

fn ProtoWriter::write_string_field(self : ProtoWriter, field : Int, value : String) -> Unit {
  self.write_tag(field, 2)
  let encoded = @utf8.encode(value)
  self.write_varint(encoded.length().to_uint64())
  self.buf.write_bytes(encoded)
}

// Encode a nested message with a length prefix.
fn ProtoWriter::write_message_field(
  self : ProtoWriter,
  field : Int,
  encode : (ProtoWriter) -> Unit
) -> Unit {
  let inner = ProtoWriter::new()
  encode(inner)
  self.write_bytes_field(field, inner.to_bytes())
}

// Helper: convert a byte array (values are masked to 8 bits) to Bytes.
fn bytes_from_bytes_array(values : Array[Int]) -> Bytes {
  let buffer = Buffer(size_hint=values.length())
  for value in values {
    buffer.write_byte((value & 0xFF).to_byte())
  }
  buffer.to_bytes()
}

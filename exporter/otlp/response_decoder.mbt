// Decodes `ExportTraceServiceResponse` bodies. An empty body is a full
// success. A `partial_success` field reports rejected spans; per the OTLP
// spec a partial success must not be retried.

fn read_response_varint(data : BytesView, offset : Int) -> (UInt64, Int) {
  let mut result : UInt64 = 0
  let mut shift = 0
  let mut pos = offset
  let mut done = false
  while !done {
    let byte = data.at(pos).to_int() & 0xFF
    result = result | ((byte & 0x7F).to_uint64() << shift)
    pos = pos + 1
    if byte < 0x80 {
      done = true
    } else {
      shift = shift + 7
    }
  }
  (result, pos)
}

// Interpret an `ExportTraceServiceResponse` protobuf body.
pub fn decode_export_response(body : Bytes) -> @sdk.ExportResult {
  let data = body.exact_view()
  let length = data.length()
  let mut pos = 0
  while pos < length {
    let (tag, after_tag) = read_response_varint(data, pos)
    pos = after_tag
    let field = (tag >> 3).to_int()
    let wire = (tag & 7).to_int()
    if wire == 2 {
      let (size, after_size) = read_response_varint(data, pos)
      let end = after_size + size.to_int()
      if field == 1 {
        // partial_success { int64 rejected_spans = 2; string error_message = 3; }
        let partial = data.exact_view(start=after_size, end=end)
        let mut inner = 0
        let mut rejected : UInt64 = 0
        let mut error_message = ""
        while inner < partial.length() {
          let (inner_tag, inner_after) = read_response_varint(partial, inner)
          inner = inner_after
          let inner_field = (inner_tag >> 3).to_int()
          let inner_wire = (inner_tag & 7).to_int()
          if inner_wire == 0 {
            let (value, value_after) = read_response_varint(partial, inner)
            inner = value_after
            if inner_field == 2 {
              rejected = value
            }
          } else if inner_wire == 2 {
            let (size2, after2) = read_response_varint(partial, inner)
            let end2 = after2 + size2.to_int()
            if inner_field == 3 {
              error_message = @utf8.decode_lossy(partial.exact_view(start=after2, end=end2))
            }
            inner = end2
          } else {
            break
          }
        }
        if rejected > 0 || error_message != "" {
          return @sdk.ExportFailure(
            "partial success: rejected " +
            rejected.to_string() +
            " span(s) " +
            error_message,
          )
        }
      }
      pos = end
    } else if wire == 0 {
      let (_value, after) = read_response_varint(data, pos)
      pos = after
    } else if wire == 1 {
      pos = pos + 8
    } else if wire == 5 {
      pos = pos + 4
    } else {
      break
    }
  }
  @sdk.ExportSuccess
}

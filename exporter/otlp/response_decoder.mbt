// Decodes `ExportTraceServiceResponse` bodies. An empty body is a full
// success. A `partial_success` field reports rejected spans; per the OTLP
// spec a partial success must not be retried.

// The OTLP specification requires clients to limit the size of a response
// body before parsing it and recommends 4 MiB as the default limit. A body
// over the limit is treated as a non-retryable failure.

///|
const OTLP_MAX_RESPONSE_BODY_BYTES : Int = 4194304

///|
fn oversized_response() -> @sdk.ExportResult {
  @sdk.ExportFailure("OTLP response body exceeds the 4 MiB limit")
}

///|
fn malformed_response() -> @sdk.ExportResult {
  @sdk.ExportFailure("malformed OTLP response body")
}

///|
fn partial_success_message_suffix(message : String) -> String {
  if message == "" {
    ""
  } else {
    " " + message
  }
}

// Read a protobuf varint. Returns `None` when the body ends in the middle of a
// varint or the varint is longer than 64 bits.

///|
fn read_response_varint(data : BytesView, offset : Int32) -> (UInt64, Int32)? {
  let length = data.length()
  // A single-byte varint is complete on its own.
  if offset < length {
    let first = data.unsafe_get(offset).to_int() & 0xFF
    if first < 0x80 {
      return Some((first.to_uint64(), offset + 1))
    }
  }
  let mut result : UInt64 = 0
  let mut shift = 0
  let mut pos = offset
  while pos < length {
    // SAFETY: `pos < length` is checked by the loop condition.
    let byte = data.unsafe_get(pos).to_int() & 0xFF
    if shift >= 64 {
      return None
    }
    if shift == 63 && byte > 1 {
      // The tenth byte only has room for bit 63; anything above it (or a
      // continuation that would make the varint longer) overflows 64 bits.
      return None
    }
    result = result | ((byte & 0x7F).to_uint64() << shift)
    pos = pos + 1
    if byte < 0x80 {
      return Some((result, pos))
    }
    shift = shift + 7
  }
  None
}

// Interpret an `ExportTraceServiceResponse` protobuf body.
// Well-formed bodies decode exactly as prescribed by the OTLP trace service
// proto; truncated or otherwise malformed bodies are reported as failures.

///|
pub fn decode_export_response(body : Bytes) -> @sdk.ExportResult {
  if body.length() > OTLP_MAX_RESPONSE_BODY_BYTES {
    return oversized_response()
  }
  let data = body.exact_view()
  let length = data.length()
  let mut pos = 0
  // Repeated occurrences of a message field are merged, so a later
  // `partial_success` may overwrite (including with zero values) fields set by
  // an earlier occurrence. Evaluate only after the whole body is parsed.
  let mut rejected : UInt64 = 0
  let mut error_message = ""
  while pos < length {
    let (tag, after_tag) = match read_response_varint(data, pos) {
      Some(pair) => pair
      None => return malformed_response()
    }
    pos = after_tag
    let field_number = tag >> 3
    // Protobuf field numbers are 1-based and must fit in 29 bits.
    if field_number == 0UL || field_number > 536870911UL {
      return malformed_response()
    }
    let field = field_number.to_int()
    let wire = (tag & 7).to_int()
    if wire == 2 {
      let (size, after_size) = match read_response_varint(data, pos) {
        Some(pair) => pair
        None => return malformed_response()
      }
      if size > (length - after_size).to_uint64() {
        return malformed_response()
      }
      let end = after_size + size.to_int()
      if field == 1 {
        // partial_success { int64 rejected_spans = 1; string error_message = 2; }
        let partial = data.exact_view(start=after_size, end~)
        let mut inner = 0
        while inner < partial.length() {
          let (inner_tag, inner_after) = match
            read_response_varint(partial, inner) {
            Some(pair) => pair
            None => return malformed_response()
          }
          inner = inner_after
          let inner_field_number = inner_tag >> 3
          // Protobuf field numbers are 1-based and must fit in 29 bits.
          if inner_field_number == 0UL || inner_field_number > 536870911UL {
            return malformed_response()
          }
          let inner_field = inner_field_number.to_int()
          let inner_wire = (inner_tag & 7).to_int()
          if inner_wire == 0 {
            let (value, value_after) = match
              read_response_varint(partial, inner) {
              Some(pair) => pair
              None => return malformed_response()
            }
            inner = value_after
            if inner_field == 1 {
              rejected = value
            }
          } else if inner_wire == 2 {
            let (size2, after2) = match read_response_varint(partial, inner) {
              Some(pair) => pair
              None => return malformed_response()
            }
            if size2 > (partial.length() - after2).to_uint64() {
              return malformed_response()
            }
            let end2 = after2 + size2.to_int()
            if inner_field == 2 {
              error_message = @utf8.decode(
                partial.exact_view(start=after2, end=end2),
              ) catch {
                _ => return malformed_response()
              }
            }
            inner = end2
          } else if inner_wire == 1 {
            if partial.length() - inner < 8 {
              return malformed_response()
            }
            inner = inner + 8
          } else if inner_wire == 5 {
            if partial.length() - inner < 4 {
              return malformed_response()
            }
            inner = inner + 4
          } else {
            // Wire types 3/4 (groups) and 6/7 cannot occur in this message.
            return malformed_response()
          }
        }
      }
      pos = end
    } else if wire == 0 {
      let (_value, after) = match read_response_varint(data, pos) {
        Some(pair) => pair
        None => return malformed_response()
      }
      pos = after
    } else if wire == 1 {
      if length - pos < 8 {
        return malformed_response()
      }
      pos = pos + 8
    } else if wire == 5 {
      if length - pos < 4 {
        return malformed_response()
      }
      pos = pos + 4
    } else {
      // Wire types 3/4 (groups) and 6/7 cannot occur in this message.
      return malformed_response()
    }
  }
  if rejected > 0 || error_message != "" {
    @sdk.ExportFailure(
      "partial success: rejected " +
      rejected.to_string() +
      " span(s)" +
      partial_success_message_suffix(error_message),
    )
  } else {
    @sdk.ExportSuccess
  }
}

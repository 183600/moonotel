// Randomized tests for the OTLP response decoders.
//
// A response body arrives from the network: it may be truncated, corrupted or
// simply not what the exporter expects. The decoders must always answer with
// an export result, must never panic and must agree with the JSON grammar
// about which bodies can be a partial success at all.

///|
struct RdRng {
  state : Ref[Int64]
}

///|
fn RdRng::new(seed : Int64) -> RdRng {
  { state: Ref(seed) }
}

///|
fn RdRng::next(self : RdRng) -> Int64 {
  // xorshift64
  let mut x = self.state.val
  x = x ^ (x >> 12)
  x = x ^ (x << 25)
  x = x ^ (x >> 27)
  self.state.val = x
  x
}

///|
fn RdRng::below(self : RdRng, bound : Int) -> Int {
  let value = self.next() & 0x7FFFFFFFFFFFFFFFL
  (value % bound.to_int64()).to_int()
}

// Fragments that stress the JSON grammar the decoder implements.

///|
let rd_json_fragments : Array[String] = [
  "{", "}", "[", "]", "\"", ":", ",", " ", "\n", "\t", "partialSuccess",
  "partial_success", "rejectedSpans", "rejected_spans", "errorMessage",
  "error_message", "0", "1", "-1", "1e5", "\"0\"", "true", "false", "null",
  "\\", "\\u0041", "\"", "e", "+", ".", "\u{0}", "é", "9999999999999999999",
]

///|
fn rd_random_text(rng : RdRng, max_fragments : Int) -> String {
  let sb = StringBuilder()
  let count = rng.below(max_fragments + 1)
  let mut i = 0
  while i < count {
    let fragment = rd_json_fragments[rng.below(rd_json_fragments.length())]
    sb.write_view(fragment[:])
    i = i + 1
  }
  sb.to_string()
}

///|
fn rd_random_bytes(rng : RdRng, count : Int) -> Bytes {
  let bytes : Array[Byte] = Array(capacity=count)
  let mut i = 0
  while i < count {
    bytes.push(rng.below(256).to_byte())
    i = i + 1
  }
  Bytes::from_array(bytes)
}

// Whether the body is blank, which the decoder reports as a full success.

///|
fn rd_is_blank(text : String) -> Bool {
  for c in text {
    if c != ' ' && c != '\n' && c != '\t' && c != '\r' {
      return false
    }
  }
  true
}

///|
fn rd_is_valid_json(text : String) -> Bool {
  let result = @json.parse(text) catch { _ => return false }
  let _ = result
  true
}

///|
fn rd_decode_json(text : String) -> @sdk.ExportResult {
  @otlp.decode_export_response_json(@utf8.encode(text))
}

// Escape a text so that it can be used as the content of a JSON string.

///|
fn rd_json_escape(text : String) -> String {
  let sb = StringBuilder()
  for c in text {
    let code = c.to_int()
    if c == '"' {
      sb.write_string("\\\"")
    } else if c == '\\' {
      sb.write_string("\\\\")
    } else if code < 0x20 {
      sb.write_string("\\u")
      let hex = "0123456789abcdef"
      sb.write_char(hex[(code >> 12) & 0xF].unsafe_to_char())
      sb.write_char(hex[(code >> 8) & 0xF].unsafe_to_char())
      sb.write_char(hex[(code >> 4) & 0xF].unsafe_to_char())
      sb.write_char(hex[code & 0xF].unsafe_to_char())
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
test "fuzz_json_response_decoder_never_panics" {
  let rng = RdRng::new(0x0BAD_C0DE_1234_5678L)
  let mut i = 0
  while i < 3000 {
    let text = rd_random_text(rng, 8)
    // A body that is not valid JSON at all can never be a partial success,
    // so it must be reported as a failure.
    if !rd_is_blank(text) && !rd_is_valid_json(text) {
      match rd_decode_json(text) {
        @sdk.ExportSuccess =>
          abort("invalid JSON was accepted as a success: " + text)
        @sdk.ExportFailure(_) => ()
      }
    }
    i = i + 1
  }
}

///|
test "fuzz_json_response_decoder_reports_partial_success" {
  let rng = RdRng::new(0x0BAD_C0DE_8765_4321L)
  let mut i = 0
  while i < 2000 {
    let rejected = rng.below(1000)
    let message = rd_random_text(rng, 2)
    let body = "{\"partialSuccess\":{\"rejectedSpans\":" +
      rejected.to_string() +
      ",\"errorMessage\":\"" +
      rd_json_escape(message) +
      "\"}}"
    let result = rd_decode_json(body)
    if rejected > 0 || message != "" {
      match result {
        @sdk.ExportSuccess =>
          abort("a partial success was reported as a success: " + body)
        @sdk.ExportFailure(text) => {
          if !(text.contains("rejected " + rejected.to_string())) {
            assert_true(text.contains("rejected " + rejected.to_string()))
          }
        }
      }
    } else {
      assert_eq(result, @sdk.ExportSuccess)
    }
    i = i + 1
  }
}

///|
test "fuzz_json_response_decoder_ignores_unknown_fields" {
  let rng = RdRng::new(0x0BAD_C0DE_0000_0001L)
  let mut i = 0
  while i < 1000 {
    let value = rd_random_text(rng, 3)
    let body = "{\"unknown\":" + value + "}"
    // A body that only holds unknown fields carries no partial success.
    if rd_is_valid_json(body) {
      assert_eq(rd_decode_json(body), @sdk.ExportSuccess)
    }
    i = i + 1
  }
}

///|
test "fuzz_protobuf_response_decoder_never_panics" {
  let rng = RdRng::new(0x0BAD_C0DE_0000_0002L)
  let mut i = 0
  while i < 3000 {
    let bytes = rd_random_bytes(rng, rng.below(24))
    // Random bytes are never a valid response, but they must be reported as a
    // failure instead of crashing the exporter.
    match @otlp.decode_export_response(bytes) {
      @sdk.ExportSuccess => ()
      @sdk.ExportFailure(_) => ()
    }
    i = i + 1
  }
}

///|
test "fuzz_protobuf_response_decoder_accepts_prefixes" {
  let rng = RdRng::new(0x0BAD_C0DE_0000_0003L)
  // A `partial_success` message with 5 rejected spans and a message.
  let body : Array[Byte] = [
    0x0A, 0x0B, 0x08, 0x05, 0x12, 0x05, 0x61, 0x62, 0x63, 0x64, 0x65,
  ].map(fn(v) { v.to_byte() })
  let mut i = 0
  while i < 500 {
    // Every prefix of a valid body is truncated in some way and must decode
    // without panicking.
    let len = rng.below(body.length() + 1)
    let bytes = Bytes::from_array(body[:len])
    match @otlp.decode_export_response(bytes) {
      @sdk.ExportSuccess => ()
      @sdk.ExportFailure(_) => ()
    }
    i = i + 1
  }
}

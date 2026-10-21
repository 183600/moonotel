///|
test "protobuf partial success without a message has no trailing space" {
  let body : Bytes = b"\x0a\x02\x08\x03"
  match @otlp.decode_export_response(body) {
    @sdk.ExportFailure(message) => {
      assert_eq(message, "partial success: rejected 3 span(s)")
    }
    @sdk.ExportSuccess => abort("expected a partial success failure")
  }
}

///|
test "json partial success without a message has no trailing space" {
  let body : Bytes = b"{\"partialSuccess\":{\"rejectedSpans\":\"3\"}}"
  match @otlp.decode_export_response_json(body) {
    @sdk.ExportFailure(message) => {
      assert_eq(message, "partial success: rejected 3 span(s)")
    }
    @sdk.ExportSuccess => abort("expected a partial success failure")
  }
}

///|
test "partial success message follows the rejected span count" {
  let body : Bytes = b"\x0a\x07\x08\x03\x12\x03bad"
  match @otlp.decode_export_response(body) {
    @sdk.ExportFailure(message) => {
      assert_eq(message, "partial success: rejected 3 span(s) bad")
    }
    @sdk.ExportSuccess => abort("expected a partial success failure")
  }
}

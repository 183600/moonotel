// Live-ID checks shared by the protobuf and JSON encoders.
//
// `SpanContext::is_valid` snapshots validity at construction, while the public
// ID views expose the backing arrays. An exporter can therefore receive a span
// whose IDs were zeroed or shortened after construction. OTLP requires exactly
// 16 nonzero trace-ID bytes and 8 nonzero span-ID bytes for a span; malformed
// spans are skipped rather than serialized, and a link whose IDs are no longer
// representable is emitted without IDs but keeps its attributes and tracestate.

///|
fn serialized_id_byte(value : Int32) -> Int32 {
  if value >= 0 && value < 256 {
    value
  } else {
    // The hex/OTLP serializers keep the low nibble of an out-of-range element.
    value & 0x0F
  }
}

///|
fn has_nonzero_id_byte(bytes : Array[Int32], count : Int32) -> Bool {
  let mut i = 0
  while i < count {
    if serialized_id_byte(bytes.unsafe_get(i)) != 0 {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn has_encodable_link_ids(context : @api.SpanContext) -> Bool {
  if !context.is_valid() {
    return false
  }
  let trace_id = context.trace_id_view()
  let span_id = context.span_id_view()
  trace_id.length() == 16 &&
  span_id.length() == 8 &&
  has_nonzero_id_byte(trace_id, 16) &&
  has_nonzero_id_byte(span_id, 8)
}

///|
fn has_encodable_span_ids(context : @api.SpanContext) -> Bool {
  has_encodable_link_ids(context)
}

///|
fn filter_encodable_spans(
  spans : Array[@sdk.SpanData],
) -> Array[@sdk.SpanData] {
  let valid : Array[@sdk.SpanData] = Array(capacity=spans.length())
  for data in spans {
    if has_encodable_span_ids(data.span_context) {
      valid.push(data)
    }
  }
  valid
}

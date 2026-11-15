// Live-ID validation for a SpanContext used as a parent.
//
// `SpanContext::is_valid` snapshots the validity of the IDs at construction so
// that mutating the backing arrays cannot silently change it. The public
// `trace_id_view`/`span_id_view` accessors still expose those arrays, so a
// caller can zero an ID after construction while the snapshot stays `true`.
// Starting a child from such a parent would produce a context with an
// all-zero trace ID and an exported span with an all-zero parent span ID.
// Code that consumes a parent therefore revalidates the live serialized bytes
// as well, just like the W3C injector does.

// The byte produced by the hex and OTLP serializers for one ID element.
// In-range values are used as-is; out-of-range values keep only the low
// nibble, matching `@api.bytes_to_hex`.

///|
fn serialized_id_byte(value : Int32) -> Int32 {
  if value >= 0 && value < 256 {
    value
  } else {
    value & 0x0F
  }
}

// Whether the first `count` elements of `bytes` serialize to a nonzero byte.
// Out-of-range values must be interpreted like the serializer does, so they
// are not mistaken for a nonzero wire byte.

///|
fn has_live_nonzero_byte(bytes : Array[Int32], count : Int32) -> Bool {
  let mut i = 0
  while i < count {
    if serialized_id_byte(bytes.unsafe_get(i)) != 0 {
      return true
    }
    i = i + 1
  }
  false
}

// Whether `context` still has valid live IDs and can be used as a parent.

///|
fn has_live_valid_ids(context : @api.SpanContext) -> Bool {
  if !context.is_valid() {
    return false
  }
  let trace_id = context.trace_id_view()
  let span_id = context.span_id_view()
  trace_id.length() >= 16 &&
  span_id.length() >= 8 &&
  has_live_nonzero_byte(trace_id, 16) &&
  has_live_nonzero_byte(span_id, 8)
}

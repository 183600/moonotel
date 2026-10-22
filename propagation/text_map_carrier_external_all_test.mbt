// A carrier can combine local writes with a read-through getter. `get_all`
// must report both sources so duplicate traceparent fields are detected and
// repeated tracestate/baggage fields are combined.

///|
let external_duplicate_traceparent : String = "00-4bf92f359d1e75b7618a2d1f3c4e5a6b-00f067aa0ba902b7-01"

///|
let local_duplicate_traceparent : String = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"

///|
test "get_all_combines_external_and_local_values" {
  let external : Map[String, String] = Map([
    ("traceparent", external_duplicate_traceparent),
    ("tracestate", "env=2"),
    ("baggage", "env=2"),
  ])
  let carrier = @propagation.TextMapCarrier::from_getter(fn(key) {
    external.get(key)
  })
  assert_eq(
    carrier.get_all("traceparent"),
    [external_duplicate_traceparent],
  )
  carrier.set("TraceParent", local_duplicate_traceparent)
  carrier.set("TraceState", "local=1")
  carrier.set("Baggage", "local=1")
  assert_eq(
    carrier.get_all("traceparent"),
    [local_duplicate_traceparent, external_duplicate_traceparent],
  )
  // Two traceparent fields under different casings are ambiguous.
  assert_true(@propagation.extract(carrier) is None)
  assert_eq(
    @propagation.extract_tracestate(carrier),
    Some("local=1, env=2"),
  )
  assert_eq(
    @propagation.extract_baggage(carrier),
    [("local", "1"), ("env", "2")],
  )
}

///|
test "get_all_still_returns_the_external_value_for_a_local_miss" {
  let carrier = @propagation.TextMapCarrier::from_getter(fn(key) {
    if key == "traceparent" {
      Some(external_duplicate_traceparent)
    } else {
      None
    }
  })
  assert_eq(
    carrier.get_all("traceparent"),
    [external_duplicate_traceparent],
  )
  assert_eq(carrier.get_all("tracestate"), [])
}

// Facade tests for the re-exported `Tracestate` operations.

///|
test "facade_tracestate_round_trip" {
  let ts = @moonotel.Tracestate::parse("a=1,b=2").unwrap()
  assert_eq(ts.length(), 2)
  let ts = ts.add("c", "3").update("a", "9").remove("b")
  assert_eq(ts.to_header(), "a=9,c=3")
  assert_eq(@moonotel.Tracestate::parse(ts.to_header()).unwrap().length(), 2)
}

///|
test "facade_tracestate_max_members_constant" {
  assert_eq(@moonotel.TRACESTATE_MAX_MEMBERS, 32)
}

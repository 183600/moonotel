///|
fn probe_next(state : Ref[UInt64]) -> Int32 {
  let mut x = state.val
  x = x ^ (x << 13)
  x = x ^ (x >> 7)
  x = x ^ (x << 17)
  state.val = x
  (x % 1000000007UL).to_int()
}

///|
test "probe tracestate differential random" {
  let alphabet : Array[Char] = [
    'a', 'b', 'c', 'z', '0', '1', '9', '_', '-', '*', '/', '@', '=', ' ', ',', '\t',
    ';', 'A', 'Z', '.', '%', '[', ']', '\\', '"', '\n', '\r', 'é',
  ]
  let state : Ref[UInt64] = Ref(88172645463325252UL)
  let mut round = 0
  while round < 20000 {
    let n = probe_next(state) % 700
    let sb = StringBuilder()
    let mut i = 0
    while i < n {
      let idx = probe_next(state) % alphabet.length()
      sb.write_char(alphabet.unsafe_get(idx))
      i = i + 1
    }
    let s = sb.to_string()
    let a = parse_tracestate(s)
    let b = match Tracestate::parse(s) {
      Some(state) => Some(state.to_header())
      None => None
    }
    if a != b {
      abort(
        "mismatch: " +
        s +
        " fast=" +
        a.unwrap_or("<None>") +
        " object=" +
        b.unwrap_or("<None>"),
      )
    }
    round = round + 1
  }
}

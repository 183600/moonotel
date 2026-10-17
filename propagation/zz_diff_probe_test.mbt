// Differential probes for the recent performance rewrites:
// - the `percent_decode` public path (ASCII fast path in
//   `percent_decode_escaped`) vs a straightforward reference decoder
// - `@propagation.context_baggage_header` first-key fast path vs the original
//   dedup-map implementation

fn diff_rand(state : Ref[Int], bound : Int) -> Int {
  state.val = (state.val * 25173 + 13849) & 0xFFFF
  state.val % bound
}

fn diff_is_baggage_value_char(code : Int) -> Bool {
  (code == 0x21) ||
  (code >= 0x23 && code <= 0x2B && code != 0x25) ||
  (code >= 0x2D && code <= 0x3A) ||
  (code >= 0x3C && code <= 0x5B) ||
  (code >= 0x5D && code <= 0x7E)
}

fn diff_hex_digit(c : Char) -> Int {
  if c >= '0' && c <= '9' {
    c.to_int() - 48
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 87
  } else if c >= 'A' && c <= 'F' {
    c.to_int() - 55
  } else {
    -1
  }
}

fn diff_reference_percent_decode(value : StringView) -> String? {
  let len = value.length()
  let bytes : Array[Byte] = Array(capacity=len)
  let mut j = 0
  while j < len {
    let c = value.unsafe_get(j).unsafe_to_char()
    if c == '%' {
      if j + 2 >= len {
        return None
      }
      let hi = diff_hex_digit(value.unsafe_get(j + 1).unsafe_to_char())
      let lo = diff_hex_digit(value.unsafe_get(j + 2).unsafe_to_char())
      if hi < 0 || lo < 0 {
        return None
      }
      bytes.push((hi * 16 + lo).to_byte())
      j = j + 3
    } else {
      let code = c.to_int()
      if !diff_is_baggage_value_char(code) {
        return None
      }
      bytes.push(code.to_byte())
      j = j + 1
    }
  }
  Some(@utf8.decode_lossy(Bytes::from_array(bytes).exact_view()))
}

fn diff_old_context_baggage_header(context : @context.Context) -> String? {
  let mut entries : Array[(String, String)]? = None
  let mut seen : Map[String, Bool]? = None
  let mut cursor : @context.Context? = Some(context)
  while true {
    match cursor {
      Some(node) => {
        match node.key {
          Some(key) =>
            match seen {
              Some(keys) =>
                if keys.get(key) is None {
                  keys.set(key, true)
                  match node.value {
                    Some(value) =>
                      match entries {
                        Some(list) => list.push((key, value))
                        None => entries = Some([(key, value)])
                      }
                    None => ()
                  }
                }
              None => {
                let keys : Map[String, Bool] = Map([])
                keys.set(key, true)
                seen = Some(keys)
                match node.value {
                  Some(value) => entries = Some([(key, value)])
                  None => ()
                }
              }
            }
          None => ()
        }
        cursor = node.parent
      }
      None => break
    }
  }
  let entries = match entries {
    Some(list) => list
    None => return None
  }
  entries.sort_by(fn(a, b) { a.0.compare(b.0) })
  let formatted = @propagation.format_baggage(entries)
  if formatted == "" {
    None
  } else {
    Some(formatted)
  }
}

///|
test "percent_decode_fast_path_matches_reference" {
  let literals = "abZ09-_.~!*'()+;=,/:@#$&"
  let hex = "0123456789ABCDEF"
  let state = Ref(12345)
  let mut round = 0
  while round < 6000 {
    round = round + 1
    let len = diff_rand(state, 14)
    let sb = StringBuilder()
    let mut i = 0
    while i < len {
      i = i + 1
      let pick = diff_rand(state, 10)
      if pick < 6 {
        let index = diff_rand(state, 24)
        sb.write_char(literals.unsafe_get(index).unsafe_to_char())
      } else {
        sb.write_char('%')
        let a = diff_rand(state, 16)
        let b = diff_rand(state, 16)
        sb.write_char(hex.unsafe_get(a).unsafe_to_char())
        sb.write_char(hex.unsafe_get(b).unsafe_to_char())
      }
    }
    let value = sb.to_string()
    let old_result = diff_reference_percent_decode(value[:])
    let new_result = @propagation.percent_decode(value)
    assert_eq(new_result, old_result)
  }
  // Explicit byte-boundary and malformed cases.
  let cases : Array[String] = [
    "%00", "%7F", "%80", "%C3%A9", "a%20b", "%FF%FE", "%25", "%2B", "plain",
    "", "a%2", "%2G", "%GG", "~%7e", "%0A", "%0D",
  ]
  for value in cases {
    assert_eq(
      @propagation.percent_decode(value),
      diff_reference_percent_decode(value[:]),
    )
  }
}

///|
test "context_baggage_header_fast_path_matches_original" {
  let keys = ["a", "b", "c", "d"]
  let state = Ref(999)
  let mut round = 0
  while round < 5000 {
    round = round + 1
    let depth = diff_rand(state, 10)
    let mut context = @context.Context::root()
    let mut i = 0
    while i < depth {
      i = i + 1
      let key = keys.unsafe_get(diff_rand(state, 4))
      if diff_rand(state, 3) != 0 {
        let value = "v" + diff_rand(state, 100).to_string()
        context = context.with_value(key, value)
      } else {
        context = context.without_value(key)
      }
    }
    let old_result = diff_old_context_baggage_header(context)
    let new_result = @propagation.context_baggage_header(context)
    assert_eq(new_result, old_result)
  }
}

